-- name: Growing Up 1.0
-- description: Mario will be bigger over time. Try to beat the game without getting stuck!
-- pausable: false

--#region Localization -------------------------------------------------------------------------------------------------------------------------
local chatMsg = djui_chat_message_create
local popup = djui_popup_create
local globalPopup = djui_popup_create_global
local tonumber = tonumber
local floor = math.floor
local format = string.format
local gsub = string.gsub
local networkIsServer = network_is_server
local serverPlayerCount = network_player_connected_count
local set_mario_action = set_mario_action
local obj_set_gfx_scale = obj_set_gfx_scale
local vec3f_set = vec3f_set
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

local cam = gLakituState
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Globals ------------------------------------------------------------------------------------------------------------------------------
globalTable.startTimer = 0
globalTable.timer = 0
globalTable.timerRunning = false
globalTable.resetOnJoin = true
globalTable.multStart = 1

globalTable.multTop = 5
globalTable.increseAmount = 0.1
globalTable.incresePeriod = 20
globalTable.forceAffected = false


playerTable[0].mult = globalTable.multStart
playerTable[0].affected = false
playerTable[0].maxReached = false
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Constants ----------------------------------------------------------------------------------------------------------------------------
local TIMER_WDTH = measure("000:00") * 3 + 30
local MULT_WDTH = measure("Size: x00.00") * 1.5

local LAND_ACTIONS = {
    [ACT_JUMP_LAND] = true,
    [ACT_HOLD_JUMP_LAND] = true,
    [ACT_LONG_JUMP_LAND] = true,
    [ACT_DOUBLE_JUMP_LAND] = true,
    [ACT_TRIPLE_JUMP_LAND] = true,
    [ACT_LAVA_BOOST_LAND] = true,
    [ACT_DEATH_EXIT_LAND] = true,
    [ACT_AIR_THROW_LAND] = true,
    [ACT_BACKFLIP_LAND] = true,
    [ACT_FREEFALL_LAND] = true,
    [ACT_HOLD_FREEFALL_LAND] = true,
    [ACT_METAL_WATER_FALL_LAND] = true,
    [ACT_METAL_WATER_JUMP_LAND] = true,
    [ACT_WATER_JUMP] = true,
    [ACT_HOLD_WATER_JUMP] = true,
    [ACT_TOP_OF_POLE_JUMP] = true,
    [ACT_SIDE_FLIP_LAND] = true,
    [ACT_QUICKSAND_JUMP_LAND] = true,
    [ACT_SOFT_BONK] = true,
    [ACT_GROUND_BONK] = true
}

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
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Variables ----------------------------------------------------------------------------------------------------------------------------
local showTimer = true
local showMult = false
local timerText = "00:00"
local startingText = ""
local playerCount = 0
local glowTimer = 0
local curPeak = 0
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

---@param m MarioState
function setSwimOffset(m)

    local mult = playerTable[0].mult
    return m.pos.y - 160 * mult / 2 > m.floorHeight or m.pos.y > m.waterLevel - 140
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

    local idx = m.playerIndex

    if not playerTable[idx].affected or not globalTable.timerRunning then
        m.marioObj.hitboxRadius = 37
        m.marioObj.hurtboxRadius = 0
        return
    end
    
    local mult = playerTable[idx].mult
    obj_set_gfx_scale(m.marioObj, mult, mult, mult)

    if m.action & ACT_FLAG_SWIMMING ~= 0 and setSwimOffset(m) then
        if mult > 1.3 then
            m.marioObj.header.gfx.pos.y = m.marioObj.header.gfx.pos.y - 160 * mult / 2
        elseif mult < 0.7 then
            m.marioObj.header.gfx.pos.y = m.marioObj.header.gfx.pos.y + 160 * mult / 2
        end
    end

    if m.action & ACT_FLAG_HANGING ~= 0 then
        m.marioObj.header.gfx.pos.y = m.marioObj.header.gfx.pos.y + 160 - mult * 160
    end

    if idx == 0  then
        mario_update_local(m)
    end
end

---@param m MarioState
function mario_update_local(m)

    local mult = playerTable[0].mult

    if m.action & ACT_FLAG_AIR == 0 then
        curPeak = m.floorHeight
    end

    local newHitboxheight = m.marioObj.hitboxHeight * mult
    if m.action & ACT_CROUCHING ~= 0 then
        newHitboxheight = newHitboxheight / 2
    end
    m.marioObj.hitboxHeight = newHitboxheight
    m.marioObj.hitboxRadius = 20 * mult
    m.marioObj.hurtboxRadius = 15 * mult

    if mult > 3 and m.action & ACT_FLAG_HANGING == 0 then
        vec3f_set(cam.curFocus, m.pos.x, m.pos.y + 160 * mult * 0.9, m.pos.z)

        if m.action == ACT_GROUND_POUND or m.action == ACT_DIVE then
            curPeak = m.pos.y - 100
        else
            m.peakHeight = curPeak
        end
    end

    if m.action & ACT_FLAG_ON_POLE ~= 0 then
        if m.usedObj.hitboxHeight < m.marioObj.hitboxHeight * 2 then
            set_mario_action(m, ACT_SOFT_BONK, 0)
        end
    end

    if m.controller.buttonDown & X_BUTTON ~= 0 then
        m.marioObj.hitboxHeight = 160
    end
end

---@param m MarioState
---@param obj Object
---@param intType integer
function on_allow_interact(m, obj, intType)

    if m.playerIndex ~= 0 or not playerTable[0].affected or not globalTable.timerRunning then return end

    if intType & INTERACT_POLE ~= 0 then
        if m.marioObj.hitboxHeight >= obj.hitboxHeight then
            return false
        end
    end
    if intType == INTERACT_CANNON_BASE and playerTable[0].mult >= 3 then
        return false
    end
    if m.marioObj.hitboxHeight >= obj.hitboxHeight * 3 then
        m.hurtCounter = 0
    end

    return true
end

---@param m MarioState
function before_phys_step(m)
    if m.playerIndex ~= 0 
    or not playerTable[0].affected 
    or not globalTable.timerRunning 
    or LAND_ACTIONS[m.action] 
    or (m.prevAction & ACT_FLAG_ON_POLE ~= 0 and m.action & ACT_FLAG_AIR ~= 0)
    then return end

    m.vel.x = m.vel.x * clamp(playerTable[0].mult * 0.30, 1, 4)
    m.vel.z = m.vel.z * clamp(playerTable[0].mult * 0.30, 1, 4)
    
end

---@param m MarioState
function on_set_action(m)
    if m.playerIndex ~= 0 
    or not playerTable[0].affected 
    or not globalTable.timerRunning
    or not JUMP_ACTIONS[m.action]
    then return end

    curPeak = m.floorHeight + m.vel.y * 6
    m.vel.y = m.vel.y * clamp(playerTable[0].mult * 0.27, 1, 4)
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
            setColor(119, 205, 228, 240)
        end
        local mult = 1
        if playerTable[0].affected and globalTable.timerRunning then
            mult = playerTable[0].mult
        end
        local text = "Size: x"..formatMultiplier(mult)
        drawText(text, x + MULT_WDTH / 2 - measure(text) * 1.5 / 2, 110, 1.5)
    end
    resetColor()
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
        popup("You are now affected by the size multiplier.", 1)
    else
        popup("You are no longer affected by the size multiplier.", 1)
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
hookEvent(HOOK_ALLOW_INTERACT, on_allow_interact)
hookEvent(HOOK_BEFORE_PHYS_STEP, before_phys_step)
hookEvent(HOOK_ON_SET_MARIO_ACTION, on_set_action)

hookCommand("gu-toggle", "- Toggle if the size multiplier affects you or not.", toggle)
if networkIsServer() then
    hookCommand("gu-start", "- Start a Growing Up match.", start)
    hookCommand("gu-stop", "- Stop the current Growing Up match.", stop)
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
        globalTable.multStart = clamp(tonumber(val) or 1, 0.1, globalTable.multTop - 1)
    elseif idx == 4 then
        globalTable.multTop = clamp(tonumber(val) or 4, globalTable.multStart + 1, 100)
    elseif idx == 5 then
        globalTable.increseAmount = clamp(tonumber(val) or 0.1, 0.1, 10)
    elseif idx == 6 then
        globalTable.incresePeriod = clamp(floor(tonumber(val) or 20), 1, 100)
    end

    if idx ~= 0 and idx ~= 1 and idx ~= 2 then
        resetValues()
    end
end

hookMMCheck("Show Timer", true, mmFunc) --0
hookMMCheck("Show Multiplier", false, mmFunc) --1
if networkIsServer() then
    hookMMCheck("Reset On Join", true, mmFunc) --2
    hookMMInput("Starting Multiplier", "1", 8, mmFunc) --3
    hookMMInput("Multiplier Limit", "5", 8, mmFunc) --4
    hookMMInput("Increase Amount", "0.1", 8, mmFunc) --5
    hookMMInput("Increase Period (Seconds)", "20", 8, mmFunc) --6
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------