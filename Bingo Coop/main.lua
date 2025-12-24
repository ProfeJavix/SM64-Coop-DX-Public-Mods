-- name: \\#d81d20\\Bingo \\#1067d8\\Coop \\#d1c918\\v1.2
-- description: This mod adds a Bingo/Lockout table and every player will have to complete a row in order to win the match.\n\nThere are three modes:\n-Free For All\n-Team Match\n-MarioHunt Match (if MH is enabled).\n\nMade by \\#333\\Profe\\#ff0\\Javix

local popup = djui_popup_create
local lower = string.lower
local floor = math.floor
local play_sound = play_sound
local ipairs = ipairs
local network_is_server = network_is_server
local hook_event = hook_event
local hook_chat_command = hook_chat_command
local network_player_set_description = network_player_set_description
local play_dialog_sound = play_dialog_sound
local play_character_sound = play_character_sound

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

globalTable.giveBuffsOnCompleted = true
globalTable.buffStartCooldown = 1800

globalTable.bingoSeed = nil
globalTable.bingoMode = MODE_FFA
globalTable.bingoState = STATE_WAIT
globalTable.bingoStateTimer = -1
globalTable.packetTimer = 0
globalTable.winner = -1

globalTable.markCompletedCells = false
globalTable.markCompletedCellsTimer = 0

for i = 0, MAX_PLAYERS - 1 do
    playerTable[i].bingoTeam = TEAM_NONE
    playerTable[i].wonBingo = false
    playerTable[i].markAllAsLine = false
    playerTable[i].rewardId = BUFF_NONE
    playerTable[i].rewardCooldown = 0
    playerTable[i].punishmentId = BUFF_NONE
    playerTable[i].punishmentCooldown = 0
    playerTable[i].forceKill = false
end

seedSet = false
selRow = 0
selCol = 0
playedFinishMusic = false

---@param buttonPressed integer
function handleSelection(buttonPressed)
    if not initedTable or globalTable.bingoState < STATE_RUNNING then return end

    if buttonPressed & (D_JPAD | U_JPAD | L_JPAD | R_JPAD) ~= 0 then
        local newRow, newCol = selRow, selCol

        if buttonPressed & D_JPAD ~= 0 then
            newRow = newRow + 1
        end
        if buttonPressed & U_JPAD ~= 0 then
            newRow = newRow - 1
        end
        if buttonPressed & L_JPAD ~= 0 then
            newCol = newCol - 1
        end
        if buttonPressed & R_JPAD ~= 0 then
            newCol = newCol + 1
        end

        selRow = clampSelection(newRow, LINE_COUNT)
        selCol = clampSelection(newCol, LINE_COUNT)

        play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
    end
end

--#region Hook Funcs---------------------------------------------------------------------------------------------------

function update()

    for i = 0, MAX_PLAYERS - 1 do
        for _, val in ipairs(interactedObjs[i]) do
            if val.timer > 0 then
                val.timer = val.timer - 1
            end
        end
        for _, val in ipairs(miscCompletedIds[i]) do
            if val.timer > 0 then
                val.timer = val.timer - 1
            end
        end
    end

    if playerTable[0].rewardCooldown > 0 then
        playerTable[0].rewardCooldown = playerTable[0].rewardCooldown - 1
    end

    if playerTable[0].punishmentCooldown > 0 then
        playerTable[0].punishmentCooldown = playerTable[0].punishmentCooldown - 1
    end

    if globalTable.bingoMode == MODE_MH and getTeam(0) ~= playerTable[0].bingoTeam and
    globalTable.bingoState ~= STATE_FINISH and getMHState() < 3 then
        playerTable[0].bingoTeam = getTeam(0)
    end

    if not network_is_server() then return end

    if mhExists and globalTable.bingoMode ~= MODE_MH then
        globalTable.bingoMode = MODE_MH
        globalTable.giveBuffsOnCompleted = false
    end

    if globalTable.bingoStateTimer > 0 then
        globalTable.bingoStateTimer = globalTable.bingoStateTimer - 1
    end
    
    if globalTable.bingoMode == MODE_MH then
        handleMHState()
    else
        if globalTable.bingoStateTimer == 0 then
            changeBingoState()
        end
    end

    if not seedSet and globalTable.bingoState == STATE_WAIT then
        globalTable.bingoSeed = generateSeed()
        seedSet = true
    end

    if globalTable.markCompletedCellsTimer > 0 then
        globalTable.markCompletedCellsTimer = globalTable.markCompletedCellsTimer - 1
    end

    if globalTable.packetTimer > 0 then
        globalTable.packetTimer = globalTable.packetTimer - 1
    end

    handleBuffs()
    handleMatchEnd()
end

---@param m MarioState
function before_mario_update(m)

    local idx = m.playerIndex

    if globalTable.bingoMode == MODE_TEAM then
        local np = nps[idx]

        if np.connected then
            if playerTable[idx].bingoTeam == TEAM_RED then
                network_player_set_description(np, 'RED', 216, 39, 22, 240)
            elseif playerTable[idx].bingoTeam == TEAM_BLUE then
                network_player_set_description(np, 'BLUE', 16, 103, 216, 240)
            end
        end
    end

    if initedTable and sendTableToPlayer[idx] and nps[idx].connected then
        sendTableToPlayer[idx] = false
        sendTableTo(idx)
    end

    if idx ~= 0 then return end

    local state = globalTable.bingoState
    if state == STATE_WAIT then
        resetMatchValues()
    elseif state == STATE_INIT or state == STATE_RUNNING then

        if not nps[0].currAreaSyncValid then return end

        if initedTable then

            if m.heldObj then
                markObjAsInteracted(m.heldObj)
            end

            updateTableFromOthers()
            handleTableProgress(m)
        else
            initBingoTable()
        end

        handlePlayerBuff(m, HOOK_BEFORE_MARIO_UPDATE)

    elseif state == STATE_FINISH then

        updateTableFromOthers()

        if not playedFinishMusic then
            local winner = globalTable.winner
            if winner == TEAM_NONE then
                play_character_sound(m, CHAR_SOUND_MAMA_MIA)
            else
                local team = ternary(globalTable.bingoMode == MODE_FFA, nps[0].globalIndex, playerTable[0].bingoTeam)

                if team == winner then
                    play_music(SEQ_PLAYER_ENV, (15 << 8) | SEQ_EVENT_CUTSCENE_COLLECT_STAR, 0)
                else
                    play_dialog_sound(21)
                end
            end

            playedFinishMusic = true
        end

        if playerTable[0].markAllAsLine then
            local bt = bingoTables[0]

            for i = 1, LINE_COUNT do
                for j = 1, LINE_COUNT do
                    local cell = bt[i][j]
                    if globalTable.markCompletedCells and cell.completed == COMPLETED_SUCCESS then
                        cell.completed = COMPLETED_LINE
                    end
                end
            end
            playerTable[0].markAllAsLine = false
        end

        if network_is_server() and seedSet then
            globalTable.bingoSeed = nil
            seedSet = false
        end
    end
end


---@param m MarioState
function mario_update(m)

    if m.playerIndex ~= 0 then return end

    if playerTable[0].forceKill then
        m.hurtCounter = 32
        playerTable[0].forceKill = false
    end

    handleSelection(m.controller.buttonPressed)

    if globalTable.bingoState >= STATE_RUNNING and m.controller.buttonPressed & Y_BUTTON ~= 0 then
        fullScreenTable = not fullScreenTable
        play_sound(SOUND_MENU_CLICK_FILE_SELECT, gGlobalSoundSource)
    end
end

function on_set_mario_action(m)
    handlePlayerBuff(m, HOOK_ON_SET_MARIO_ACTION)
end

---@param m MarioState
---@param o Object
---@param intType integer
function on_interact(m, o, intType)

    if m.playerIndex ~= 0 then return end

    if (o.oInteractStatus & INT_ANY_ATTACK ~= 0 and o.oAction < 100) or
    intType == INTERACT_STAR_OR_KEY or intType == INTERACT_COIN or
    (intType == INTERACT_TEXT and o.oInteractStatus & INT_STATUS_INTERACTED ~= 0) then
        markObjAsInteracted(o)
    end
end

---@param attacker MarioState
---@param victim MarioState
---@return boolean
function on_allow_pvp_attack(attacker, victim)

    if attacker.playerIndex == 0 and allowPvpAttack(attacker, victim) then
        markObjAsInteracted(victim.marioObj)
    end

    return true
end

---@param attacker MarioState
---@param victim MarioState
function on_pvp_attack(attacker, victim)

    if victim.playerIndex == 0 then
        local ar, ap = playerTable[attacker.playerIndex].rewardId, playerTable[attacker.playerIndex].punishmentId
        local dmg = victim.hurtCounter

        if ar == BUFF_DEAL_MORE_DAMAGE then
            dmg = dmg * 2
        end

        if ap == BUFF_DEAL_LESS_DAMAGE then
            dmg = dmg / 2
        end
        victim.hurtCounter = floor(dmg)
    end
end

---@param m MarioState
function on_death(m)
    if globalTable.giveBuffsOnCompleted then
        playerTable[m.playerIndex].rewardCooldown = 0
        playerTable[m.playerIndex].punishmentCooldown = 0
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Hooks -------------------------------------------------------------------------------------------------------

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_SET_MARIO_ACTION, on_set_mario_action)
hook_event(HOOK_ON_INTERACT, on_interact)
hook_event(HOOK_ALLOW_PVP_ATTACK, on_allow_pvp_attack)
hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)
hook_event(HOOK_ON_DEATH, on_death)
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Chat Commands -----------------------------------------------------------------------------------------------

if mhExists then return end

hook_chat_command('bingo-team', '[red|blue] Change your bingo team', function (msg)
    if globalTable.bingoMode == MODE_TEAM then
        local team = ternary(playerTable[0].bingoTeam == TEAM_RED, 'RED', 'BLUE')
        local teamId = playerTable[0].bingoTeam

        if msg == 'red' then
            teamId = TEAM_RED
            team = 'RED'
        elseif msg == 'blue' then
            teamId = TEAM_BLUE
            team = 'BLUE'
        end

        if #getTeamMembers(playerTable[0].bingoTeam) == 1 and teamId ~= playerTable[0].bingoTeam then
            popup('You cannot change your current team while being the only member.', 1)
        else
            playerTable[0].bingoTeam = teamId
            popup('Current team: ' .. team, 1)
        end
    else
        popup('The match mode must be set to Team.', 1)
    end

    return true
end)

if network_is_server() then
    hook_chat_command('bingo-start', 'Starts the bingo match (host only)', function (msg)
        if globalTable.bingoState == STATE_WAIT then
            changeBingoState()
        else
            popup('A bingo match has already started.', 1)
        end
        return true
    end)
    hook_chat_command('bingo-stop', 'Stops the bingo match (host only)', function (msg)
        if globalTable.bingoState ~= STATE_WAIT then
            changeBingoState(true)
        else
            popup('There is no bingo match running.', 1)
        end
        return true
    end)
    hook_chat_command('bingo-mode', '[ffa|team] Select the bingo match mode (host only)', function (msg)
        if globalTable.bingoState == STATE_WAIT then
            msg = lower(msg)
            if msg == 'ffa' then
                globalTable.bingoMode = MODE_FFA
            elseif msg == 'team' then
                globalTable.bingoMode = MODE_TEAM
            end

            local putInRed = true
            for i = 0, MAX_PLAYERS - 1 do
                if globalTable.bingoMode == MODE_FFA then
                    playerTable[i].bingoTeam = TEAM_NONE
                elseif globalTable.bingoMode == MODE_TEAM then
                    playerTable[i].bingoTeam = ternary(putInRed, TEAM_RED, TEAM_BLUE)
                    if nps[i].connected then
                        putInRed = not putInRed
                    end
                end
            end

            popup('Current Bingo Mode: ' .. globalTable.bingoMode, 1)
        else
            popup('Bingo Mode cannot be changed during a match.', 1)
        end
        return true
    end)
end
--#endregion ----------------------------------------------------------------------------------------------------------