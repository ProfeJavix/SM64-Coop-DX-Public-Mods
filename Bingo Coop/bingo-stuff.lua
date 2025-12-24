local random = math.random
local insert = table.insert
local remove = table.remove
local randomseed = math.randomseed
local popup = djui_popup_create
local ceil = math.ceil
local tostring = tostring
local sort = table.sort
local ipairs = ipairs
local play_sound = play_sound
local get_id_from_behavior = get_id_from_behavior
local network_send = network_send
local network_send_to = network_send_to
local obj_get_nearest_object_with_behavior_id = obj_get_nearest_object_with_behavior_id
local hook_event = hook_event
local network_is_server = network_is_server

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

initedTable = false
bingoTables = {}

local STAR_COURSES = {
    LEVEL_BOB,
    LEVEL_WF,
    LEVEL_JRB,
    LEVEL_CCM,
    LEVEL_BBH,
    LEVEL_HMC,--6
    LEVEL_LLL,
    LEVEL_SSL,
    LEVEL_DDD,
    LEVEL_SL,--10
    LEVEL_WDW,
    LEVEL_TTM,
    LEVEL_THI,
    LEVEL_TTC,--14
    LEVEL_RR
}
--#region Init Bingo Table --------------------------------------------------------------------------------------------

function resetTables()
    for i = 0, MAX_PLAYERS - 1 do
        bingoTables[i] = {}
    end
    initedTable = false
end
resetTables()

local usedStarCourses = {}
local starCourseCount = 0

---@param data table
---@return table | nil
function initCellData(data)

    local initedCell = {}

    initedCell.completed = COMPLETED_NONE
    initedCell.givesBuff = random() < 0.3

    local suffix = ''
    if data.id == 'collect_stars_in_course' then
        local index
        repeat
            index = random(#STAR_COURSES)
        until not usedStarCourses[index]

        usedStarCourses[index] = true
        starCourseCount = starCourseCount + 1
        suffix = tostring(STAR_COURSES[index])
    end
    initedCell.id = data.id .. suffix

    if data.min and data.max then
        initedCell.curCount = 0
        initedCell.goalCount = random(data.min, data.max)
    end

    if data.minTime and data.maxTime then
        initedCell.curTime = 0
        initedCell.goalTime = random(data.minTime, data.maxTime)
    end

    if data.pickPlayerIdx then
        local indexes = {}
        for i = 0, MAX_PLAYERS - 1 do

            if nps[i].connected and
            ((globalTable.bingoMode == MODE_FFA and i ~= 0) or
            (globalTable.bingoMode == MODE_TEAM and playerTable[0].bingoTeam ~= playerTable[i].bingoTeam) or
            (globalTable.bingoMode == MODE_MH and playerTable[i].bingoTeam == TEAM_RED)) then
                insert(indexes, nps[i].globalIndex)
            end
        end

        if #indexes == 0 then return nil end

        sort(indexes)
        initedCell.targetPlayerIdx = indexes[random(#indexes)]
    end

    return initedCell
end

function initBingoTable()

    local bt = bingoTables[0]
    if globalTable.bingoSeed then
        randomseed(globalTable.bingoSeed)
    else
        return
    end

    local usedIndexes = {}

    for i = 1, LINE_COUNT do
        bt[i] = {}
        for j = 1, LINE_COUNT do

            repeat
                local index
                repeat
                    index = random(#CELL_DATA)
                until not usedIndexes[index]

                if index ~= 21 or starCourseCount >= 2 then
                    usedIndexes[index] = true
                end

                bt[i][j] = initCellData(CELL_DATA[index])
            until bt[i][j]

            bt[i][j].row = i
            bt[i][j].col = j
            sendTableCell(i, j)
        end
    end

    selRow = 1
    selCol = 1

    usedStarCourses = {}
    randomseed(generateSeed())
    initedTable = true
end

---@param cells table
function setCellsAsLine(cells)
    local bt = bingoTables[0]
    for _, val in ipairs(cells) do
        local i, j = val.row, val.col
        bt[i][j].completed = COMPLETED_LINE
        sendTableCell(i, j)
    end
end

---@return boolean, table | nil
function hasCompletedRow()

    local bt = bingoTables[0]

    for i = 1, LINE_COUNT do
        local cells = {}

        for j = 1, LINE_COUNT do
            local cell = bt[i][j]
            if cell.completed == COMPLETED_SUCCESS then
                insert(cells, {row = i, col = j})
            else
                goto continue
            end
        end

        if #cells == LINE_COUNT then
            setCellsAsLine(cells)
            return true
        end
        ::continue::
    end
    
    return false
end

---@return boolean
function hasCompletedColumn()

    local bt = bingoTables[0]

    for j = 1, LINE_COUNT do
        local cells = {}

        for i = 1, LINE_COUNT do
            local cell = bt[i][j]
            if cell.completed == COMPLETED_SUCCESS then
                insert(cells, {row = i, col = j})
            else
                goto continue
            end
            
        end

        if #cells == LINE_COUNT then
            setCellsAsLine(cells)
            return true
        end
        ::continue::
    end
    
    return false
end

---@return boolean
function hasCompletedDiagonal()

    local bt = bingoTables[0]
    local mCells = {} --main diagonal
    local sCells = {} --secondary diagonal

    for i = 1, LINE_COUNT do

        local mCell = bt[i][i]
        local sCell = bt[LINE_COUNT - i + 1][i]

        if mCell.completed == COMPLETED_SUCCESS then
            insert(mCells, {row = i, col = i})
        end

        if sCell.completed == COMPLETED_SUCCESS then
            insert(sCells, {row = LINE_COUNT - i + 1, col = i})
        end
    end

    if #mCells == LINE_COUNT then
        setCellsAsLine(mCells)
        return true
    elseif #sCells == LINE_COUNT then
        setCellsAsLine(sCells)
        return true
    end
    
    return false
end

---@return boolean
function hasCompletedLine()
    return hasCompletedRow() or hasCompletedColumn() or hasCompletedDiagonal()
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Cell Progress -----------------------------------------------------------------------------------------------

interactedObjs = {}
miscCompletedIds = {}
for i = 0, MAX_PLAYERS - 1 do
    interactedObjs[i] = {}
    miscCompletedIds[i] = {}
end

---@param cell table
function completeCell(cell)
    if not initedTable then return end

    cell.completed = COMPLETED_SUCCESS
    play_sound(SOUND_MENU_STAR_SOUND, gGlobalSoundSource)
    if hasCompletedLine() then
        playerTable[0].wonBingo = true
    end
    sendTableCell(cell.row, cell.col)

    if globalTable.giveBuffsOnCompleted and cell.givesBuff then
        local givePunishment = random() < 0.5

        if givePunishment then
            local indexes = {}
            local team = playerTable[0].bingoTeam
            for i = 1, MAX_PLAYERS - 1 do
                if nps[i].connected and (globalTable.bingoMode == MODE_FFA or playerTable[i].bingoTeam ~= team) then
                    insert(indexes, i)
                end
            end

            local count = ceil(#indexes / 2)
            while count > 0 do

                local i = random(1, #indexes)
                playerTable[indexes[i]].punishmentId = BUFF_GIVE
                remove(indexes, i)

                count = count - 1
            end
        else
            playerTable[0].rewardId = BUFF_GIVE
        end
    end
end

---@param cell table
function incrementCellCount(cell)
    if cell.curCount then
        cell.curCount = cell.curCount + 1
        if cell.curCount >= cell.goalCount then
            completeCell(cell)
        else
            play_sound(SOUND_MENU_POWER_METER, gGlobalSoundSource)
            sendTableCell(cell.row, cell.col)
        end
    else
        completeCell(cell)
    end
end

--#region Interact Task -----------------------------------------------------------------------------------------------

local CELL_ID_BHVS = {
    ['kill_goombas'] = { id_bhvGoomba },
    ['kill_koopas'] = { id_bhvCustomKoopa },
    ['kill_bobombs'] = { id_bhvBobomb },
    ['kill_bullies'] = { id_bhvSmallBully, id_bhvSmallChillBully },
    ['kill_boos'] = { id_bhvBoo, id_bhvBooWithCage, id_bhvGhostHuntBoo, id_bhvMerryGoRoundBoo },
    ['kill_chuckyas'] = { id_bhvChuckya },
    ['kill_whomps'] = { id_bhvCustomSmallWhomp },
    ['kill_king_bobomb'] = { id_bhvKingBobomb },
    ['kill_king_whomp'] = { id_bhvCustomWhompKingBoss },
    ['kill_big_boo'] = { id_bhvBalconyBigBoo, id_bhvMerryGoRoundBigBoo, id_bhvGhostHuntBigBoo },
    ['kill_big_bully'] = { id_bhvBigBully, id_bhvBigBullyWithMinions, id_bhvBigChillBully },
    ['kill_eyerok'] = { id_bhvEyerokBoss },
    ['kill_wiggler'] = { id_bhvWigglerHead },
    ['kill_bowser1'] = { id_bhvBowser },
    ['kill_bowser2'] = { id_bhvBowser },
    ['kill_bowser3'] = { id_bhvBowser },
    ['collect_yellow_coins'] = { id_bhvYellowCoin, id_bhvMovingYellowCoin },
    ['collect_red_coins'] = { id_bhvRedCoin },
    ['collect_blue_coins'] = { id_bhvBlueCoinJumping, id_bhvBlueCoinSliding, id_bhvMovingBlueCoin, id_bhvHiddenBlueCoin, id_bhvMrIBlueCoin },
    ['collect_stars'] = { id_bhvSpawnedStar, id_bhvSpawnedStarNoLevelExit, id_bhvStar, id_bhvStarSpawnCoordinates },
    ['collect_stars_in_course'] = { id_bhvSpawnedStar, id_bhvSpawnedStarNoLevelExit, id_bhvStar, id_bhvStarSpawnCoordinates },
    ['open_cannons'] = { id_bhvBobombBuddyOpensCannon },
    ['kick_klepto'] = { id_bhvKlepto }
}

---@param isMario boolean
---@param id integer
---@return boolean
function objNotMarked(isMario, id)
    for i = 1, MAX_PLAYERS - 1 do
        for _, val in ipairs(interactedObjs[i]) do
            if (isMario and val.o.globalPlayerIndex == id) or
            (id ~= 0 and not isMario and val.o.oSyncID == id) then
                return false
            end
        end
    end

    return true
end

---@param o Object
function markObjAsInteracted(o)

    if not o or not initedTable then return end

    local isMario = get_id_from_behavior(o.behavior) == id_bhvMario
    local id = ternary(isMario, o.globalPlayerIndex, o.oSyncID)

    local shouldInsert = objNotMarked(isMario, id)
    
    if shouldInsert then
        for _, val in ipairs(interactedObjs[0]) do
            if (isMario and val.o.globalPlayerIndex == id) or
            (not isMario and val.o.oSyncID == id) then
                val.timer = 150
                shouldInsert = false
                break
            end
        end
    end

    if shouldInsert then
        insert(interactedObjs[0], { o = o, timer = 600 })
        network_send(true, {
            bingoPacketType = PTYPE_INTERACT,
            globalIdx = nps[0].globalIndex,
            oIsPlayer = isMario,
            id = id
        })
    end
end

---@param cellId string
---@param o Object
---@return boolean
function isMobValidForCount(cellId, o)

    local isLevelStar, suffix = isIdLevelStar(cellId)
    return (o.activeFlags == ACTIVE_FLAG_DEACTIVATED and not isLevelStar) or
    (cellId == 'kill_goombas' and (o.oGoombaSize ~= GOOMBA_SIZE_HUGE or o.oAction == OBJ_ACT_SQUISHED)) or
    (cellId == 'kill_boos' and o.oAction == 4) or
    ((cellId == 'kill_bullies' or cellId == 'kill_big_bully') and o.oAction >= 100) or
    (cellId == 'kill_whomps' and o.oAction == 8 and o.oBehParams2ndByte == 0) or
    (cellId == 'kill_king_bobomb' and o.oAction == 7) or
    (cellId == 'kill_king_whomp' and o.oAction == 8 and o.oBehParams2ndByte ~= 0) or
    (cellId == 'kill_big_boo' and o.oHealth <= 0) or
    (cellId == 'kill_eyerok' and o.oAction == EYEROK_BOSS_ACT_DIE) or
    (cellId == 'kill_wiggler' and (o.oHealth <= 1 or (o.oAction == WIGGLER_ACT_JUMPED_ON and o.oHealth == 2))) or
    (cellId == 'kill_bowser1' and o.oBehParams2ndByte == 0 and o.oHealth == 0) or
    (cellId == 'kill_bowser2' and o.oBehParams2ndByte == 1 and o.oHealth == 0) or
    (cellId == 'kill_bowser3' and o.oBehParams2ndByte == 2 and o.oHealth == 0) or
    suffix == tostring(nps[0].currLevelNum) or
    (cellId == 'open_cannons' and obj_get_nearest_object_with_behavior_id(o, id_bhvCannonClosed) ~= nil) or
    cellId == 'kick_klepto'
end

---@param cell table
function handleInteractTask(cell)
    if not initedTable then
        interactedObjs[0] = {}
        return
    end
    local bhvIds = CELL_ID_BHVS[ternary(isIdLevelStar(cell.id), 'collect_stars_in_course', cell.id)]
    for _, oData in ipairs(interactedObjs[0]) do
        local o = oData.o
        local shouldRemove = false
        if o and cell.completed == COMPLETED_NONE then
            local oBhvId = get_id_from_behavior(o.behavior)
            if oBhvId == id_bhvMario then
                local m = states[getLocalFromGlobalIdx(o.globalPlayerIndex)]
                if m then
                    if cell.targetPlayerIdx == o.globalPlayerIndex and
                    playerTable[m.playerIndex].rewardId ~= BUFF_INVINCIBLE then
                        playerTable[m.playerIndex].forceKill = true
                        completeCell(cell)
                    end
                end
                shouldRemove = true
            else
                if oBhvId == id_bhvYellowCoin and o.oDamageOrCoinValue == 5 then
                    oBhvId = id_bhvMovingBlueCoin --blue coins from enemies are glorified yellow coins
                end
                for _, val in ipairs(bhvIds or {}) do
                    if val == oBhvId then
                        if isMobValidForCount(cell.id, o) then
                            incrementCellCount(cell)
                            shouldRemove = true
                        end
                        break
                    end
                end
            end
        end

        if shouldRemove then
            oData.remove = true
        end
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Misc Task ---------------------------------------------------------------------------------------------------

---@param id string
function markIdForLocal(id)

    if not initedTable then return end

    local dataTable = {
        bingoPacketType = PTYPE_MISC,
        globalIdx = nps[0].globalIndex,
        id = id
    }

    for i = 0, MAX_PLAYERS - 1 do
        local mci = miscCompletedIds[i]
        for _, val in ipairs(mci) do
            if val.id == id then
                if i == 0 then
                    network_send(true, dataTable)
                end
                return
            end
        end
    end

    insert(miscCompletedIds[0], {id = id, timer = 90})
    network_send(true, dataTable)
end

---@param cell table
function handleMiscTask(cell)

    if findTaskTypeById(cell.id) ~= TASK_MISC or cell.completed ~= 0 then return end

    for _, val in ipairs(miscCompletedIds[0]) do
        if val.id == cell.id and val.timer > 85 then
            incrementCellCount(cell)
        end
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Timer Task --------------------------------------------------------------------------------------------------

local ACT_FLAGS_BY_ID = {
    ['seconds_in_air'] = {flag = ACT_FLAG_AIR},
    ['seconds_in_ground'] = {flag = (ACT_FLAG_AIR | ACT_FLAG_SWIMMING | ACT_FLAG_ON_POLE), avoid = true},
    ['seconds_in_shell'] = {flag = ACT_FLAG_RIDING_SHELL}
}

---@param m MarioState
function handleTimerTask(m, cell)
    local id = cell.id

    if cell.completed ~= 0 then return end

    local flagInfo = ACT_FLAGS_BY_ID[id]

    if not flagInfo then return end

    local actFlag = flagInfo.flag

    if (not flagInfo.avoid and m.action & actFlag ~= 0) or (flagInfo.avoid and m.action & actFlag == 0) then
        cell.curTime = cell.curTime + 1

        if selRow == cell.row and selCol == cell.col and cell.curTime % 30 == 0 then
            play_sound(SOUND_GENERAL_BIG_CLOCK, gGlobalSoundSource)
        end
    elseif cell.curTime ~= 0 then
        cell.curTime = 0

        if selRow == cell.row and selCol == cell.col then
            play_sound(SOUND_MENU_CAMERA_BUZZ, gGlobalSoundSource)
        end
    end

    if cell.curTime >= cell.goalTime then
        completeCell(cell)
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

---@param m MarioState
function handleTableProgress(m)
    if globalTable.bingoState ~= STATE_RUNNING or
    (globalTable.bingoMode == MODE_MH and playerTable[m.playerIndex].bingoTeam == TEAM_RED) then return end

    local table = bingoTables[0]

    for i = 1, LINE_COUNT do
        for j = 1, LINE_COUNT do
            local cell = table[i][j]
            local type = findTaskTypeById(cell.id)
            if type == TASK_INTERACT then
                handleInteractTask(cell)
            elseif type == TASK_TIMER then
                handleTimerTask(m, cell)
            elseif type == TASK_MISC then
                handleMiscTask(cell)
            end
        end
    end

    for i = 0, MAX_PLAYERS - 1 do
        tableRemoveOnTimer(interactedObjs[i])
        tableRemoveOnTimer(miscCompletedIds[i])
    end
end

function updateCell(cell)
    local send = false
    for i = 1, MAX_PLAYERS - 1 do
        if nps[i].connected and bingoTables[i] and bingoTables[i][cell.row] and bingoTables[i][cell.row][cell.col] then
            local cell2 = bingoTables[i][cell.row][cell.col]
            local sameTeam = globalTable.bingoMode ~= MODE_FFA and playerTable[i].bingoTeam == playerTable[0].bingoTeam

            if cell2.completed > 0 and not sameTeam then
                cell.completed = COMPLETED_FAILED
                return true
            elseif sameTeam then
                if cell.targetPlayerIdx and cell2.targetPlayerIdx and cell.targetPlayerIdx ~= cell2.targetPlayerIdx then
                    cell.targetPlayerIdx = cell2.targetPlayerIdx
                    send = true
                end

                if cell.curCount and cell2.curCount and cell2.curCount > cell.curCount then
                    cell.curCount = cell2.curCount
                    send = true
                end

                if cell.completed ~= cell2.completed and (cell.completed < cell2.completed or cell2.completed == COMPLETED_FAILED) then
                    cell.completed = cell2.completed
                    send = true
                end
            end
        end
    end

    return send
end

function updateTableFromOthers()

    if not initedTable or globalTable.packetTimer > 0 then return end

    local bt = bingoTables[0]

    for i = 1, LINE_COUNT do
        for j = 1, LINE_COUNT do
            local cell = bt[i][j]

            if updateCell(cell) then
                sendTableCell(i, j)
            end
        end
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Buffs and Debuffs -------------------------------------------------------------------------------------------

function handleBuffs()
    if not globalTable.giveBuffsOnCompleted or globalTable.bingoState ~= STATE_RUNNING or globalTable.bingoMode == MODE_MH then return end

    for i = 0, MAX_PLAYERS - 1 do
        local r, p = playerTable[i].rewardId, playerTable[i].punishmentId
        if nps[i].connected then
            if r == BUFF_GIVE then
                playerTable[i].rewardId = random(MAX_REWARDS - 1)
                playerTable[i].rewardCooldown = globalTable.buffStartCooldown
            end
            if p == BUFF_GIVE then
                playerTable[i].punishmentId = random(MAX_PUNISHMENTS - 1)
                playerTable[i].punishmentCooldown = globalTable.buffStartCooldown
            end
        end
    end
end

---@param m MarioState
---@param hook LuaHookedEventType
function handlePlayerBuff(m, hook)

    local r, p = playerTable[m.playerIndex].rewardId, playerTable[m.playerIndex].punishmentId

    if not globalTable.giveBuffsOnCompleted or globalTable.bingoMode == MODE_MH then
        if r ~= BUFF_NONE then
            playerTable[m.playerIndex].rewardId = BUFF_NONE
        end
        if p ~= BUFF_NONE then
            playerTable[m.playerIndex].punishmentId = BUFF_NONE
        end
        return
    end

    if r > BUFF_GIVE then
        local dataR = REWARD_DATA[r]

        if dataR and dataR.hook == hook then
            dataR.func(m, r, false)
        end

        if playerTable[m.playerIndex].rewardCooldown == 0 then
            playerTable[m.playerIndex].rewardId = BUFF_NONE
        end
    end

    if p > BUFF_GIVE then
        local dataP = PUNISHMENT_DATA[p]

        if dataP and dataP.hook == hook then
            dataP.func(m, p, true)
        end

        if playerTable[m.playerIndex].punishmentCooldown == 0 then
            playerTable[m.playerIndex].punishmentId = BUFF_NONE
        end
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Match -------------------------------------------------------------------------------------------------------

---@param endMatch boolean | nil
function changeBingoState(endMatch)
    local newState, timer = STATE_WAIT, -1

    if endMatch then
        newState, timer = STATE_FINISH, 300
    else
        if globalTable.bingoState == STATE_WAIT then
            if globalTable.bingoMode == MODE_TEAM and getTeamAmount() < 2 then
                popup('There must be 2 or more teams to start a team match.', 1)
                return
            end
            newState = STATE_INIT
            timer = 150
        elseif globalTable.bingoState == STATE_INIT then
            newState = STATE_RUNNING
            timer = -1
        elseif globalTable.bingoState == STATE_RUNNING then
            newState = STATE_FINISH
            timer = 300
        end
    end
    globalTable.bingoState = newState
    globalTable.bingoStateTimer = timer
end

function setWinnerFromCompletedCount()

    local winnersIndexes = {}
    local higherCount = 0

    for idx = 0, MAX_PLAYERS - 1 do
        if nps[idx].connected then
            local count = 0
            for i = 1, LINE_COUNT - 1 do
                for j = 1, LINE_COUNT - 1 do
                    if bingoTables[idx][i][j].completed > 0 then
                        count = count + 1
                    end
                end
            end

            if count > higherCount then
                higherCount = count
                winnersIndexes = { idx }
            elseif count == higherCount then
                insert(winnersIndexes, idx)
            end
        end
    end

    for _, idx in ipairs(winnersIndexes) do
        playerTable[idx].wonBingo = true
        playerTable[idx].markAllAsLine = true
    end
end

---@param bt table
---@return boolean
function canDoLine(bt)
    
    if not bt or #bt == 0 then return true end

    for i = 1, LINE_COUNT do --rows and cols
        local rowCount, colCount = 0, 0
        for j = 1, LINE_COUNT do
            if bt[i][j].completed ~= -1 then
                rowCount = rowCount + 1
            end

            if bt[j][i].completed ~= -1 then
                colCount = colCount + 1
            end
        end

        if rowCount == LINE_COUNT or colCount == LINE_COUNT then return true end
    end

    local mainCount, secCount = 0, 0
    for i = 1, LINE_COUNT do --diagonals
        
        if bt[i][i].completed ~= -1 then
            mainCount = mainCount + 1
        end
        if bt[LINE_COUNT - i + 1][i].completed ~= -1 then
            secCount = secCount + 1
        end

        if mainCount == LINE_COUNT or secCount == LINE_COUNT then return true end
    end

    return false
end

function someoneCanDoLine()

    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected then
            if canDoLine(bingoTables[i]) then
                return true
            end
        end
    end

    return false
end

function handleMatchEnd()

    if globalTable.bingoState ~= STATE_RUNNING then return end

    if not globalTable.markCompletedCells and not someoneCanDoLine() then

        globalTable.markCompletedCells = true
        globalTable.markCompletedCellsTimer = 5
        return
    elseif globalTable.markCompletedCells and globalTable.markCompletedCellsTimer == 0 then
        globalTable.markCompletedCells = false
        setWinnerFromCompletedCount()
        return
    end

    local teams = {}

    if globalTable.bingoMode == MODE_MH and globalTable.winner == TEAM_RED then
        insert(teams, TEAM_RED)
    else
        for i = 0, MAX_PLAYERS - 1 do
            if playerTable[i].wonBingo then
                local team = nps[i].globalIndex

                if globalTable.bingoMode == MODE_FFA then
                    insert(teams, team)
                else
                    team = playerTable[i].bingoTeam
                    local strTeam = tostring(team)
                    if not teams[strTeam] then
                        teams[strTeam] = true
                        insert(teams, team)
                    end
                end
            end
        end
    end

    if #teams > 0 then
        globalTable.winner = ternary(#teams > 1, TEAM_NONE, teams[1])
        changeBingoState()
    end
end

local bingoFinishedFirst = false
local shouldForceResetMatch = false
function handleMHState()
    if not globalTable.bingoMode == MODE_MH then return end

    local mhState = getMHState()

    if globalTable.bingoState == STATE_FINISH and mhState == 2 and not shouldForceResetMatch then
        bingoFinishedFirst = true
        if globalTable.bingoStateTimer <= 0 then
            mhState = 0
        end
    end

    if mhState == 0 then
        if globalTable.bingoState ~= STATE_WAIT then
            globalTable.bingoState = STATE_WAIT
        end
    elseif mhState == 2 then

        if bingoFinishedFirst then return end

        if globalTable.bingoState ~= STATE_RUNNING then
            globalTable.bingoState = ternary(shouldForceResetMatch, STATE_WAIT, STATE_RUNNING)
            shouldForceResetMatch = false
        end
    elseif mhState >= 3 then

        bingoFinishedFirst = false
        shouldForceResetMatch = true

        if globalTable.bingoState == STATE_WAIT then return end

        if globalTable.bingoState ~= STATE_FINISH then

            changeBingoState(true)

            if mhState ~= 3 then
                return
            end

            globalTable.winner = TEAM_RED
            for i = 0, MAX_PLAYERS - 1 do
                if TEAM_RED == playerTable[i].bingoTeam then
                    playerTable[i].wonBingo = true
                end
            end
        elseif globalTable.bingoStateTimer <= 0 then
            globalTable.bingoState = STATE_WAIT
        end
    end
end

function resetMatchValues()

    for i = 0, MAX_PLAYERS - 1 do
        interactedObjs[i] = {}
        miscCompletedIds[i] = {}
    end

    if network_is_server() then
        globalTable.winner = TEAM_NONE
    end

    resetTables()
    playerTable[0].rewardId = BUFF_NONE
    playerTable[0].rewardCooldown = 0
    playerTable[0].punishmentId = BUFF_NONE
    playerTable[0].punishmentCooldown = 0
    playerTable[0].wonBingo = false
    playedFinishMusic = false
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Syncing -----------------------------------------------------------------------------------------------------

---@param row integer
---@param col integer
---@param idx integer | nil
function sendTableCell(row, col, idx)
    local networkCell = {}

    networkCell.bingoPacketType = PTYPE_CELL
    networkCell.globalIdx = nps[0].globalIndex
    networkCell.row = row
    networkCell.col = col

    local bt = bingoTables[0]
    local cellData = bt[row][col]
    networkCell.id = cellData.id
    networkCell.completed = cellData.completed
    networkCell.curCount = cellData.curCount
    networkCell.goalCount = cellData.goalCount
    networkCell.curTime = cellData.curTime
    networkCell.goalTime = cellData.goalTime
    networkCell.targetPlayerIdx = cellData.targetPlayerIdx

    if idx then
        network_send_to(idx, true, networkCell)
    else
        network_send(true, networkCell)
    end

    globalTable.packetTimer = 5
end

---@param idx integer
function sendTableTo(idx)

    for i = 1, LINE_COUNT do
        for j = 1, LINE_COUNT do
            sendTableCell(i, j)
        end
    end
end

function on_packet_receive(dataTable)

    local type = dataTable.bingoPacketType
    local idx = getLocalFromGlobalIdx(dataTable.globalIdx)

    if idx == -1 then return end

    if type == PTYPE_CELL then

        local bt = bingoTables[idx]
        local row, col = dataTable.row, dataTable.col

        if not bt[row] then
            bt[row] = {}
        end

        if not bt[row][col] then
            bt[row][col] = {}
        end
        bt[row][col].row = row
        bt[row][col].col = col
        bt[row][col].id = dataTable.id
        bt[row][col].completed = dataTable.completed
        bt[row][col].curCount = dataTable.curCount
        bt[row][col].goalCount = dataTable.goalCount
        bt[row][col].curTime = dataTable.curTime
        bt[row][col].goalTime = dataTable.goalTime
        bt[row][col].targetPlayerIdx = dataTable.targetPlayerIdx

    elseif type == PTYPE_INTERACT then
        local o = {}
        if dataTable.oIsPlayer then
            o.globalPlayerIndex = dataTable.id --fake marioObj
        else
            o.oSyncID = dataTable.id --fake Object
        end
        insert(interactedObjs[idx], { o = o, timer = 600 })
    elseif type == PTYPE_MISC then
        insert(miscCompletedIds[idx], { id = dataTable.id, timer = 90 })
    end
end

sendTableToPlayer = {}
for i = 0, MAX_PLAYERS - 1 do
    sendTableToPlayer[i] = false
end

---@param m MarioState
function on_player_connected(m)
    sendTableToPlayer[m.playerIndex] = true

    if network_is_server() then
        if globalTable.bingoMode == MODE_TEAM then
            playerTable[m.playerIndex].bingoTeam = ternary(#getTeamMembers(TEAM_RED) > #getTeamMembers(TEAM_BLUE), TEAM_BLUE, TEAM_RED)
        end
    end
end

---@param m MarioState
function on_player_disconnected(m)
    bingoTables[m.playerIndex] = {}
end

hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_disconnected)
--#endregion ----------------------------------------------------------------------------------------------------------