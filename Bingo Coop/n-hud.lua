local gsub = string.gsub
local ceil = math.ceil
local clamp = math.clamp
local getTex = get_texture_info
local screenWidth = djui_hud_get_screen_width
local screenHeight = djui_hud_get_screen_height
local drawRect = djui_hud_render_rect
local setColor = djui_hud_set_color
local setFont = djui_hud_set_font
local drawText = djui_hud_print_text
local measure = djui_hud_measure_text
local drawTile = djui_hud_render_texture_tile
local tostring = tostring
local tonumber = tonumber
local hook_event = hook_event
local network_is_server = network_is_server
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local hook_mod_menu_inputbox = hook_mod_menu_inputbox

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

fullScreenTable = false

local teamColor, rivalColor = { r = 16, g = 103, b = 216 }, { r = 216, g = 39, b = 22 }
local showControls = true

local ICONS = getTex('bingo-icons')

local TABLE_CONTROLS = {
    'Y - TOGGLE TABLE SIZE',
    'D-PAD - NAVIGATE TABLE'
}

local CELL_TYPE_ICONS = {
    ['kill'] = {x = 64, y = 96},
    ['boss'] = {x = 80, y = 96},
    ['collect'] = {x = 96, y = 96},
    ['timer'] = {x = 112, y = 0},
    ['race'] = {x = 112, y = 16}
}

local CELLS_TILE_POS = {
    ['kill_goombas'] = { x = 0, y = 0, type = 'kill' },
    ['kill_koopas'] = { x = 16, y = 0, type = 'kill' },
    ['kill_bobombs'] = { x = 0, y = 16, type = 'kill' },
    ['kill_bullies'] = { x = 16, y = 16, type = 'kill' },
    ['kill_boos'] = { x = 32, y = 0, type = 'kill' },
    ['kill_chuckyas'] = { x = 32, y = 16, type = 'kill' },
    ['kill_whomps'] = { x = 16, y = 32, type = 'kill' },
    ['kill_king_bobomb'] = { x = 0, y = 32, type = 'boss' },
    ['kill_king_whomp'] = { x = 16, y = 32, type = 'boss' },
    ['kill_big_boo'] = { x = 32, y = 32, type = 'boss' },
    ['kill_big_bully'] = { x = 48, y = 0, type = 'boss' },
    ['kill_eyerok'] = { x = 48, y = 16, type = 'boss' },
    ['kill_wiggler'] = { x = 48, y = 32, type = 'boss' },
    ['kill_bowser1'] = { x = 0, y = 48, type = 'boss' },
    ['kill_bowser2'] = { x = 16, y = 48, type = 'boss' },
    ['kill_bowser3'] = { x = 32, y = 48, type = 'boss' },
    ['kick_klepto'] = { x = 48, y = 48 },
    ['collect_yellow_coins'] = { x = 64, y = 0, type = 'collect'},
    ['collect_red_coins'] = { x = 64, y = 16, type = 'collect' },
    ['collect_blue_coins'] = { x = 64, y = 32, type = 'collect' },
    ['collect_stars'] = { x = 64, y = 48, type = 'collect' },
    ['kill_player'] = { x = 0, y = 64, type = 'kill' },
    ['open_cannons'] = { x = 16, y = 64 },
    ['beat_ktq1'] = { x = 32, y = 64, type = 'race' },
    ['beat_ktq2'] = { x = 48, y = 64, type = 'race' },
    ['beat_race_penguin'] = { x = 64, y = 64, type = 'race' },
    ['seconds_in_air'] = { x = 80, y = 0, type = 'timer' },
    ['seconds_in_ground'] = { x = 80, y = 16, type = 'timer' },
    ['seconds_in_shell'] = { x = 16, y = 0, type = 'timer' },
    ['collect_stars_in_course' .. tostring(LEVEL_BOB)] = { x = 80, y = 32 },
    ['collect_stars_in_course' .. tostring(LEVEL_WF)] = { x = 80, y = 48 },
    ['collect_stars_in_course' .. tostring(LEVEL_JRB)] = { x = 80, y = 64 },
    ['collect_stars_in_course' .. tostring(LEVEL_CCM)] = { x = 0, y = 80 },
    ['collect_stars_in_course' .. tostring(LEVEL_BBH)] = { x = 16, y = 80 },
    ['collect_stars_in_course' .. tostring(LEVEL_HMC)] = { x = 32, y = 80 },
    ['collect_stars_in_course' .. tostring(LEVEL_LLL)] = { x = 48, y = 80 },
    ['collect_stars_in_course' .. tostring(LEVEL_SSL)] = { x = 64, y = 80 },
    ['collect_stars_in_course' .. tostring(LEVEL_DDD)] = { x = 80, y = 80 },
    ['collect_stars_in_course' .. tostring(LEVEL_SL)] = { x = 96, y = 0 },
    ['collect_stars_in_course' .. tostring(LEVEL_WDW)] = { x = 96, y = 16 },
    ['collect_stars_in_course' .. tostring(LEVEL_TTM)] = { x = 96, y = 32 },
    ['collect_stars_in_course' .. tostring(LEVEL_THI)] = { x = 96, y = 48 },
    ['collect_stars_in_course' .. tostring(LEVEL_TTC)] = { x = 96, y = 64 },
    ['collect_stars_in_course' .. tostring(LEVEL_RR)] = { x = 96, y = 80 }
}

local CELLS_DESCRIPTIONS = {
    ['kill_goombas'] = 'Kill &count& Goombas',
    ['kill_koopas'] = 'Kill &count& Koopas',
    ['kill_bobombs'] = 'Kill &count& Bob-Ombs',
    ['kill_bullies'] = 'Kill &count& Bullies',
    ['kill_boos'] = 'Kill &count& Boos',
    ['kill_chuckyas'] = 'Kill &count& Chuckyas',
    ['kill_whomps'] = 'Kill &count& Whomps',
    ['kill_king_bobomb'] = 'Kill King Bob-Omb',
    ['kill_king_whomp'] = 'Kill King Whomp',
    ['kill_big_boo'] = 'Kill a Big Boo',
    ['kill_big_bully'] = 'Kill a Big Bully',
    ['kill_eyerok'] = 'Kill Eyerok',
    ['kill_wiggler'] = 'Kill Wiggler',
    ['kill_bowser1'] = 'Kill Bowser in BITDW',
    ['kill_bowser2'] = 'Kill Bowser in BITFS',
    ['kill_bowser3'] = 'Kill Bowser in BITS',
    ['kick_klepto'] = 'Beat the sh** out of Klepto',
    ['collect_yellow_coins'] = 'Collect &count& yellow coins',
    ['collect_red_coins'] = 'Collect &count& red coins',
    ['collect_blue_coins'] = 'Collect &count& blue coins',
    ['collect_stars'] = 'Collect &count& stars',
    ['collect_stars_in_course' .. tostring(LEVEL_BOB)] = 'Collect &count& stars in BOB',
    ['collect_stars_in_course' .. tostring(LEVEL_WF)] = 'Collect &count& stars in WF',
    ['collect_stars_in_course' .. tostring(LEVEL_JRB)] = 'Collect &count& stars in JRB',
    ['collect_stars_in_course' .. tostring(LEVEL_CCM)] = 'Collect &count& stars in CCM',
    ['collect_stars_in_course' .. tostring(LEVEL_BBH)] = 'Collect &count& stars in BBH',
    ['collect_stars_in_course' .. tostring(LEVEL_HMC)] = 'Collect &count& stars in HMC',
    ['collect_stars_in_course' .. tostring(LEVEL_LLL)] = 'Collect &count& stars in LLL',
    ['collect_stars_in_course' .. tostring(LEVEL_SSL)] = 'Collect &count& stars in SSL',
    ['collect_stars_in_course' .. tostring(LEVEL_DDD)] = 'Collect &count& stars in DDD',
    ['collect_stars_in_course' .. tostring(LEVEL_SL)] = 'Collect &count& stars in SL',
    ['collect_stars_in_course' .. tostring(LEVEL_WDW)] = 'Collect &count& stars in WDW',
    ['collect_stars_in_course' .. tostring(LEVEL_TTM)] = 'Collect &count& stars in TTM',
    ['collect_stars_in_course' .. tostring(LEVEL_THI)] = 'Collect &count& stars in THI',
    ['collect_stars_in_course' .. tostring(LEVEL_TTC)] = 'Collect &count& stars in TTC',
    ['collect_stars_in_course' .. tostring(LEVEL_RR)] = 'Collect &count& stars in RR',
    ['kill_player'] = 'Kill &playerName&',
    ['open_cannons'] = 'Open &count& cannons',
    ['beat_ktq1'] = 'Beat Koopa the Quick in BOB',
    ['beat_ktq2'] = 'Beat Koopa the Quick in THI',
    ['beat_race_penguin'] = 'Beat Race Penguin in CCM',
    ['seconds_in_air'] = 'Stay for &seconds& seconds in the air',
    ['seconds_in_ground'] = 'Stay for &seconds& seconds on the ground',
    ['seconds_in_shell'] = 'Stay for &seconds& seconds in a shell'
}

local PUNISHMENTS_TEXTS = {
    [BUFF_TOXIC_POISON] = 'POISONED: ',
    [BUFF_LESS_JUMP_HEIGHT] = 'LOWER JUMPS: ',
    [BUFF_PAINFUL_JUMPS] = 'PAINFUL JUMPS: ',
    [BUFF_BLINDED] = 'BLINDED: ',
    [BUFF_DEAL_LESS_DAMAGE] = 'DEAL LESS DAMAGE: '
}

local REWARDS_TEXTS = {
    [BUFF_MORE_JUMP_HEIGHT] = 'HIGHER JUMPS: ',
    [BUFF_INVINCIBLE] = 'INVINCIBLE: ',
    [BUFF_DEAL_MORE_DAMAGE] = 'DEAL MORE DAMAGE: '
}

function defineProgressColors()
    if globalTable.bingoMode == MODE_FFA then
        teamColor, rivalColor = { r = 16, g = 103, b = 216 }, { r = 216, g = 39, b = 22 }
    else
        if playerTable[0].bingoTeam == TEAM_RED then
            teamColor, rivalColor = { r = 216, g = 39, b = 22 }, { r = 16, g = 103, b = 216 }
        else
            teamColor, rivalColor = { r = 16, g = 103, b = 216 }, { r = 216, g = 39, b = 22 }
        end
    end
end

---@param cellData table
---@return string
function getCellDescription(cellData)
    local text = CELLS_DESCRIPTIONS[cellData.id]

    if not text then
        text = ''
    else
        text = gsub(text, '&count&', tostring(cellData.goalCount or 0))
        text = gsub(text, '&seconds&', tostring(ceil((cellData.goalTime or 0) / 30)))
        text = gsub(text, '&playerName&', getPlayerName(cellData.targetPlayerIdx))
    end

    return text
end

---@param selRow integer
---@param selCol integer
function drawBingoTable(selRow, selCol)
    local bt = bingoTables[0]

    local scale = ternary(fullScreenTable, 4, 2)

    local lineSize = 2.5 * scale
    local tileSize = 16 * scale

    local size = (LINE_COUNT + 1) * lineSize + LINE_COUNT * tileSize

    local x = ternary(fullScreenTable, screenWidth() / 2 - size / 2, screenWidth() - 5 - lineSize - size)
    local y = screenHeight() / 2 - size / 2

    drawText('BINGO', (x + size / 2) - measure('BINGO') * 0.75 * scale / 2, y - 15 * scale, 0.75 * scale)

    setColor(102, 57, 49, 230)
    drawRect(x - lineSize, y - lineSize, size + 2 * lineSize, size + 2 * lineSize)

    setColor(219, 170, 124, 230)
    drawRect(x, y, size, size)

    x = x + lineSize
    y = y + lineSize
    setColor(255, 255, 255, 230)

    for i = 1, LINE_COUNT do
        local curY = y + (tileSize + lineSize) * (i - 1)
        for j = 1, LINE_COUNT do
            local curCell = bt[i][j]
            local curX = x + (tileSize + lineSize) * (j - 1)
            local tileInfo = CELLS_TILE_POS[curCell.id]

            if tileInfo then
                drawTile(ICONS, curX, curY, scale, scale, tileInfo.x, tileInfo.y, 16, 16)

                if tileInfo.type then
                    local typeIcon = CELL_TYPE_ICONS[tileInfo.type]
                    if typeIcon then
                        drawTile(ICONS, curX, curY, scale * 0.4, scale * 0.4, typeIcon.x, typeIcon.y, 16, 16)
                    end
                end
            end

            if curCell.completed ~= 0 then
                if curCell.completed == COMPLETED_SUCCESS then
                    setColor(teamColor.r, teamColor.g, teamColor.b, 230)
                    drawTile(ICONS, curX, curY, scale, scale, 0, 96, 16, 16)
                elseif curCell.completed == COMPLETED_LINE then
                    drawTile(ICONS, curX, curY, scale, scale, 32, 96, 16, 16)
                elseif curCell.completed == COMPLETED_FAILED then
                    setColor(rivalColor.r, rivalColor.g, rivalColor.b, 230)
                    drawTile(ICONS, curX, curY, scale, scale, 16, 96, 16, 16)
                end
                setColor(255, 255, 255, 230)
            elseif globalTable.giveBuffsOnCompleted and curCell.givesBuff then
                drawTile(ICONS, curX + tileSize - 16 * scale * 0.3, curY, scale * 0.3, scale * 0.3, 48, 96, 16, 16)
            end

            if selRow == i and selCol == j then
                setColor(50, 50, 50, 150)
                drawRect(curX, curY, tileSize, tileSize)
                setColor(255, 255, 255, 230)
            end
        end
    end

    if showControls then
        x = x + size / 2
        y = y + size + lineSize + 3 * scale
        local controlScale = 0.4 * scale

        setFont(FONT_NORMAL)
        setColor(27, 27, 27, 240)

        for _, text in ipairs(TABLE_CONTROLS) do
            drawText(text, x - measure(text) * controlScale / 2, y, controlScale)
            y = y + 32 * controlScale + 3 * scale
        end
        setFont(FONT_HUD)
    end
end

function drawBuff()
    local y = screenHeight() - 59

    local r = playerTable[0].rewardId
    local seconds = 0
    local text

    if r > BUFF_GIVE then
        seconds = ceil(playerTable[0].rewardCooldown / 30)
        text = REWARDS_TEXTS[r]

        if text and seconds > 0 then
            setColor(teamColor.r, teamColor.g, teamColor.b, 240)
            text = text .. tostring(seconds) .. 's'
            drawText(text, 5, y, 1.5)
        end
    end

    y = y - 64

    local p = playerTable[0].punishmentId
    if p > BUFF_GIVE then
        seconds = ceil(playerTable[0].punishmentCooldown / 30)
        text = PUNISHMENTS_TEXTS[p]

        if text and seconds > 0 then
            setColor(rivalColor.r, rivalColor.g, rivalColor.b, 240)
            text = text .. tostring(seconds) .. 's'
            drawText(text, 5, y, 1.5)
        end
    end
end

function on_hud_render()

    local text = ''
    local state = globalTable.bingoState
    defineProgressColors()

    if state == STATE_WAIT then
        if globalTable.bingoMode == MODE_MH then return end

        text = ternary(network_is_server(), 'Enter /bingo-start to start the bingo match.',
            'Waiting for host to start a bingo match.')

        setColor(0, 0, 0, 240)
        drawText(text, 5, screenHeight() / 2 - 48, 1.5)
    elseif state == STATE_INIT then
        local seconds = ceil(globalTable.bingoStateTimer / 30)
        setFont(FONT_HUD)
        text = 'Starting in ' .. seconds .. 's'
        drawText(text, screenWidth() / 2 - measure(text), screenHeight() / 2 - 36, 2)
    elseif initedTable then
        if state == STATE_RUNNING and playerTable[0].punishmentId == BUFF_BLINDED then
            setColor(0, 0, 0, 255)
            drawRect(0, 0, screenWidth(), screenHeight())
        end

        local bt = bingoTables[0]

        setFont(FONT_HUD)

        drawBingoTable(selRow, selCol)

        if state == STATE_RUNNING then
            local selCell = bt[selRow][selCol]

            local cellDescription = getCellDescription(selCell)
            if cellDescription ~= '' then
                setColor(255, 255, 255, 230)
                local wdth = measure(cellDescription)
                curX = screenWidth() / 2 - wdth
                curY = screenHeight() - 72
                drawText(cellDescription, curX, curY, 2)

                if selCell.completed ~= 0 then
                    curX = curX + 2 * wdth + 10
                    if selCell.completed == COMPLETED_FAILED then
                        setColor(rivalColor.r, rivalColor.g, rivalColor.b, 230)
                    end
                    drawTile(ICONS, curX, curY, 2, 2, ternary(selCell.completed == COMPLETED_FAILED, 16, 32), 96, 16, 16)
                end
            end

            setFont(FONT_RECOLOR_HUD)
            drawBuff()

            if selCell.completed ~= 0 or (globalTable.bingoMode == MODE_MH and getTeam(0) == TEAM_RED) then return end

            local curX, curY = 5, screenHeight() / 2 - 27
            if selCell.curCount then
                setColor(199, 29, 29, 240)
                drawText('Current Count: ' .. selCell.curCount, curX, curY, 1.5)
                curY = curY + 64
            end

            if globalTable.bingoMode == MODE_MH then return end

            if selCell.curTime then
                setColor(9, 153, 216, 240)
                drawText('Current Seconds: ' .. ceil(selCell.curTime / 30), curX, curY, 1.5)
                curY = curY + 64
            end
        elseif globalTable.bingoState == STATE_FINISH then
            if globalTable.bingoStateTimer > 0 then
                
                setFont(FONT_RECOLOR_HUD)
                local winner = globalTable.winner

                if winner == TEAM_NONE then
                    setColor(209, 201, 24, 240)
                    text = 'THERE WAS A DRAW IN BINGO... SAD'
                elseif globalTable.bingoMode == MODE_FFA then
                    if nps[0].globalIndex == winner then
                        setColor(teamColor.r, teamColor.g, teamColor.b, 240)
                        text = 'BINGO! YOU WIN!'
                    else
                        setColor(rivalColor.r, rivalColor.g, rivalColor.b, 240)
                        text = 'BAD LUCK. YOU LOSE...'
                    end
                elseif globalTable.bingoMode == MODE_TEAM then
                    if playerTable[0].bingoTeam == winner then
                        setColor(teamColor.r, teamColor.g, teamColor.b, 240)
                        text = 'BINGO! YOUR TEAM WINS!'
                    else
                        setColor(rivalColor.r, rivalColor.g, rivalColor.b, 240)
                        text = 'BAD LUCK. YOUR TEAM LOSES...'
                    end
                elseif globalTable.bingoMode == MODE_MH then
                    if playerTable[0].bingoTeam == winner then
                        setColor(teamColor.r, teamColor.g, teamColor.b, 240)
                        text = ternary(winner == TEAM_RED, 'YAY! RUNNERS CANNOT GET BINGO!', 'BINGO! RUNNERS WIN!')
                    else
                        setColor(rivalColor.r, rivalColor.g, rivalColor.b, 240)
                        text = ternary(winner == TEAM_RED, 'SEEMS LIKE BINGO IS IMPOSSIBLE NOW...',
                            'SEEMS LIKE RUNNERS GOT BINGO...')
                    end
                end

                drawText(text, screenWidth() / 2 - measure(text), screenHeight() / 2 - 36, 2)
            end
        end
    end

    if globalTable.bingoMode == MODE_TEAM then
        setFont(FONT_RECOLOR_HUD)
        setColor(teamColor.r, teamColor.g, teamColor.b, 240)
        text = ternary(playerTable[0].bingoTeam == TEAM_RED, 'RED', 'BLUE') .. ' TEAM'
        drawText(text, screenWidth() / 2 - measure(text), 5, 2)
    end
end

hook_event(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)

hook_mod_menu_checkbox('Show Table Controls', true, function (_, val)
    showControls = val
end)

if network_is_server() and not mhExists then
    hook_mod_menu_checkbox('Give Buffs On Cell Completion', true, function(_, val)
        globalTable.giveBuffsOnCompleted = val
    end)

    hook_mod_menu_inputbox('Buff Seconds [10-90]', '60', 8, function(_, val)
        globalTable.buffStartCooldown = clamp((tonumber(val) or 60), 10, 90) * 30
    end)
end
