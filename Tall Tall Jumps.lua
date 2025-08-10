-- name: Tall tall Jumps 1.0
-- description: Mario's jump height will be increased over time. Be careful not to reach the sky too often!
-- pausable: false

--#region Localization -------------------------------------------------------------------------------------------------------------------------
local chatMsg = djui_chat_message_create
local popup = djui_popup_create
local globalPopup = djui_popup_create_global
local tostring = tostring
local tonumber = tonumber
local floor = math.floor
local format = string.format
local gsub = string.gsub
local networkIsServer = network_is_server
local serverPlayerCount = network_player_connected_count
local setColor = djui_hud_set_color
local setFont = djui_hud_set_font
local resetColor = djui_hud_reset_color
local drawRect = djui_hud_render_rect
local drawText = djui_hud_print_text
local screenWdth = djui_hud_get_screen_width
local screenHght = djui_hud_get_screen_height
local measure = djui_hud_measure_text
local playSound = play_sound
local hookEvent = hook_event
local hookCommand = hook_chat_command
local hookMMCheck = hook_mod_menu_checkbox
local hookMMInput = hook_mod_menu_inputbox

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Globals ------------------------------------------------------------------------------------------------------------------------------
globalTable.startTimer = 0
globalTable.timer = 0
globalTable.timerRunning = false
globalTable.resetOnJoin = true
globalTable.fallDamage = true
globalTable.multStart = 1

globalTable.multTop = 5
globalTable.increseAmount = 0.1
globalTable.incresePeriod = 20
globalTable.forceAffected = false


playerTable[0].mult = globalTable.multStart
playerTable[0].affected = false
playerTable[0].maxReached = false
playerTable[0].init = false
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Constants ----------------------------------------------------------------------------------------------------------------------------
local JUMP_ACTIONS = {
    [ACT_JUMP] = true,
    [ACT_HOLD_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_STEEP_JUMP] = true,
    [ACT_SIDE_FLIP] = true,
    [ACT_BACKFLIP] = true,
    [ACT_BURNING_JUMP] = true,
    [ACT_WATER_JUMP] = true,
    [ACT_HOLD_WATER_JUMP] = true,
    [ACT_METAL_WATER_JUMP] = true,
    [ACT_TOP_OF_POLE_JUMP] = true,
    [ACT_SPECIAL_TRIPLE_JUMP] = true,
    [ACT_RIDING_SHELL_JUMP] = true,
    [ACT_WALL_KICK_AIR] = true
}
local TIMER_WDTH = measure("000:00") * 3 + 30
local MULT_WDTH = measure("Multiplier: x00.00") * 1.5
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Variables ----------------------------------------------------------------------------------------------------------------------------
local showTimer = true
local showMult = false
local timerText = "00:00"
local startingText = ""
local playerCount = 0
local glowTimer = 0
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Utils --------------------------------------------------------------------------------------------------------------------------------
---@param val number
---@param minVal number
---@param maxVal number
---@return number
function clamp(val, minVal, maxVal)
    if val < minVal then
        return minVal
    elseif val > maxVal then
        return maxVal
    else
        return val
    end
end

---@param mult number
---@return string
function formatMultiplier(mult)
    return (gsub(format("%.2f", mult), "%.?0+$", ""))
end

function resetValues()
    globalTable.startTimer = 0
    globalTable.timerRunning = false
    globalTable.timer = 0
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected then
            playerTable[i].mult = globalTable.multStart
            playerTable[i].maxReached = false
        end
    end
end

function updateTimerText()
    local seconds = globalTable.timer / 30
    local minutes = 0
    while seconds >= 60 do
        seconds = seconds - 60
        minutes = minutes + 1
    end
    timerText = format("%02d:%02d", minutes, seconds)
end

function updateMult()
    if playerTable[0].affected then
        local seconds = globalTable.timer / 30
        if seconds % globalTable.incresePeriod == 0 then
            if playerTable[0].mult + globalTable.increseAmount <= globalTable.multTop then
                glowTimer = 25
                playSound(SOUND_GENERAL_BIG_CLOCK, states[0].pos)
                playerTable[0].mult = playerTable[0].mult + globalTable.increseAmount
            elseif playerTable[0].mult < globalTable.multTop then
                glowTimer = 25
                playSound(SOUND_GENERAL_BIG_CLOCK, states[0].pos)
                playerTable[0].mult = globalTable.multTop
            end
        end

        if playerTable[0].mult == globalTable.multTop and not playerTable[0].maxReached then
            playerTable[0].maxReached = true
            popup("Your multiplier has reached the top.", 1)
        end
    end
end

---@return boolean
function atLeastOneAffected()
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and playerTable[i].affected then
            return true
        end
    end
    return false
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hook Functions -----------------------------------------------------------------------------------------------------------------------
function update()

    if globalTable.startTimer % 30 == 0 then
        local seconds = globalTable.startTimer / 30
        if globalTable.startTimer / 30 > 0 then
            if seconds - 1 > 0 then
                startingText = format("%d", seconds - 1)
                playSound(SOUND_GENERAL_COIN_DROP, states[0].pos)
            else
                startingText = "JUMP!"
                playSound(SOUND_GENERAL_RACE_GUN_SHOT, states[0].pos)
            end
        else
            startingText = ""
        end
    end

    if networkIsServer() then
        if globalTable.timerRunning then
            globalTable.timer = globalTable.timer + 1
        end
        if globalTable.startTimer > 0 then
            globalTable.startTimer = globalTable.startTimer - 1
            if globalTable.startTimer == 0 then
                globalTable.timerRunning = true
            end
        end
        if playerCount ~= serverPlayerCount() then
            if globalTable.resetOnJoin and (globalTable.timerRunning or globalTable.startTimer > 0) then
                resetValues()
                globalPopup("The server player count changed. Stopping match", 1)
            end

            playerCount = serverPlayerCount()
        end
    end

    if glowTimer > 0 then
        glowTimer = glowTimer - 1
    end

    if globalTable.timer > 0 and globalTable.timer % 30 == 0 then
        updateTimerText()
        updateMult()
    elseif globalTable.timer == 0 then
        timerText = "00:00"
    end
end

---@param m MarioState
function mario_update(m)
    if m.playerIndex ~= 0 or not playerTable[0].affected or not globalTable.timerRunning then return end

    if not globalTable.fallDamage then
        m.peakHeight = m.pos.y
    end
end

function on_hud_render()

    if startingText ~= "" then
        setFont(FONT_CUSTOM_HUD)
        drawText(startingText, screenWdth() / 2 - measure(startingText) * 5 / 2, screenHght() / 2 - 18 * 5, 5)
        setFont(FONT_NORMAL)
    end

    if showTimer then
        local x = screenWdth()/2 - TIMER_WDTH/2

        if glowTimer > 0 then
            setColor(100, 100, 100, 150)
        else
            setColor(46, 46, 46, 150)
        end
        drawRect(x, 5, TIMER_WDTH, 96)

        if glowTimer > 0 then
            setColor(236, 217, 0, 200)
        else
            setColor(232, 232, 232, 200)
        end
        drawText(timerText, x + TIMER_WDTH / 2 - measure(timerText) * 3 / 2, 5, 3)
    end

    if showMult then
        local x = screenWdth() / 2 - MULT_WDTH / 2
        
        if glowTimer > 0 then
            setColor(100, 100, 100, 150)
        else
            setColor(46, 46, 46, 150)
        end
        drawRect(x, 110, MULT_WDTH, 32 * 1.5)

        if glowTimer > 0 then
            setColor(230, 255, 0, 240)
        else
            setColor(0, 208, 0, 240)
        end
        local mult = 1
        if playerTable[0].affected and globalTable.timerRunning then
            mult = playerTable[0].mult
        end
        local text = "Multiplier: x"..formatMultiplier(mult)
        drawText(text, x + MULT_WDTH / 2 - measure(text) * 1.5 / 2, 110, 1.5)
    end
    resetColor()
end

---@param m MarioState
function on_set_action(m)
    if m.playerIndex ~= 0 or not playerTable[0].affected or not globalTable.timerRunning then return end
    if JUMP_ACTIONS[m.action] then
        m.vel.y = m.vel.y * playerTable[0].mult
    end
    
end

function on_sync_valid()
    if globalTable.forceAffected then
        playerTable[0].affected = true
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Command Functions --------------------------------------------------------------------------------------------------------------------
function toggle(_)
    if globalTable.timerRunning or globalTable.startTimer > 0 then
        chatMsg("A match is currently running. You can only use this command before it starts.")
        return true
    end

    if globalTable.forceAffected then
        chatMsg("The multiplier is forced for every player.")
        return true
    end

    playerTable[0].affected = not playerTable[0].affected
    if playerTable[0].affected then
        popup("You are now affected by the TTJ Multiplier.", 1)
    else
        popup("You are no longer affected by the TTJ Multiplier.", 1)
    end
    return true
end

function start(_)
    if globalTable.timerRunning or globalTable.startTimer > 0 then
        chatMsg("The match is already started.")
        return true
    end
    if not atLeastOneAffected() then
        chatMsg("There must be at least one player affected by the multiplier to start a match")
        return true
    end
    resetValues()
    globalTable.startTimer = 120
    globalPopup("Starting Match!", 1)

    return true
end

function stop(_)
    if not globalTable.timerRunning and globalTable.startTimer == 0 then
        chatMsg("The match has not started.")
        return true
    end

    resetValues()
    globalPopup("The match has been interrupted", 1)

    return true
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_UPDATE, update)
hookEvent(HOOK_MARIO_UPDATE, mario_update)
hookEvent(HOOK_ON_HUD_RENDER, on_hud_render)
hookEvent(HOOK_ON_SET_MARIO_ACTION, on_set_action)
hookEvent(HOOK_JOINED_GAME, on_sync_valid)

hookCommand("ttj-toggle", "- Toggle if the jump height multiplier affects you or not.", toggle)
if networkIsServer() then
    hookCommand("ttj-start", "- Start a Tall Tall Jump match.", start)
    hookCommand("ttj-stop", "- Stop the current Tall Tall Jump match.", stop)
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Mod Menu -----------------------------------------------------------------------------------------------------------------------------
function mmFunc(idx, val)
    if idx == 0 then
        showTimer = val
    elseif idx == 1 then
        showMult = val
    elseif idx == 2 then
        globalTable.resetOnJoin = val
    elseif idx == 3 then
        globalTable.fallDamage = val
    elseif idx == 4 then
        globalTable.multStart = clamp(tonumber(val) or 1, 0.1, globalTable.multTop - 1)
    elseif idx == 5 then
        globalTable.multTop = clamp(tonumber(val) or 4, globalTable.multStart + 1, 100)
    elseif idx == 6 then
        globalTable.increseAmount = clamp(tonumber(val) or 0.1, 0.1, 10)
    elseif idx == 7 then
        globalTable.incresePeriod = clamp(floor(tonumber(val) or 20), 1, 100)
    elseif idx == 8 then
        globalTable.forceAffected = val
        if val then
            for i = 0, MAX_PLAYERS - 1 do
                if nps[i].connected then
                    playerTable[i].affected = true
                end
            end
        end
    end

    if idx ~= 0 and idx ~= 1 and idx ~= 2 and idx ~= 3 then
        resetValues()
    end
end

hookMMCheck("Show Timer", true, mmFunc) --0
hookMMCheck("Show Multiplier", false, mmFunc) --1
if networkIsServer() then
    hookMMCheck("Reset On Join", true, mmFunc) --2
    hookMMCheck("Fall Damage", true, mmFunc) --3
    hookMMInput("Starting Multiplier", "1", 8, mmFunc) --4
    hookMMInput("Multiplier Limit", "5", 8, mmFunc) --5
    hookMMInput("Increase Amount", "0.1", 8, mmFunc) --6
    hookMMInput("Increase Period (Seconds)", "20", 8, mmFunc) --7
    hookMMCheck("Force Multiplier For All", false, mmFunc) --8
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------