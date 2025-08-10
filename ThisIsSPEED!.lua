-- name: This Is SPEED! v1.0
-- description: Mario's speed will be incremented over time. Try to collect the stars in a vertiginous way!\n\nAuthor: ProfeJavix
-- pausable: false

--#region Localization -------------------------------------------------------------------------------------------------------------------------
local floor = math.floor
local tostring = tostring
local tonumber = tonumber
local format = string.format
local abs = absf_2

local networkIsServer = network_is_server
local popup = djui_popup_create
local chatMsg = djui_chat_message_create
local globalPopup = djui_popup_create_global
local serverPlayerCount = network_player_connected_count
local hookEvent = hook_event
local hookCommand = hook_chat_command
local hookMMCheckbox = hook_mod_menu_checkbox
local hookMMInput = hook_mod_menu_inputbox
local hookMMSlider = hook_mod_menu_slider
local getScreenWidth = djui_hud_get_screen_width
local setColor = djui_hud_set_color
local resetColor = djui_hud_reset_color
local drawRect = djui_hud_render_rect
local drawText = djui_hud_print_text
local measureText = djui_hud_measure_text

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Globals ------------------------------------------------------------------------------------------------------------------------------

globalTable.timer = 0
globalTable.timerRunning = false
globalTable.resetOnJoin = true
globalTable.startingSpeedMult = 1
globalTable.maxSpeedMult = 10
globalTable.speedIncrementAmount = 0.5
globalTable.secondsForIncrement = 10


playerTable[0].affectedBySpeed = false
playerTable[0].speedMult = globalTable.startingSpeedMult
playerTable[0].maxReached = false
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Constants ----------------------------------------------------------------------------------------------------------------------------
local notAffectedActions = {
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
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Variables ----------------------------------------------------------------------------------------------------------------------------
local showTimer = true
local showCurrSpeed = false
local currentTimerText = "00:00"
local glowTimer = 0
local playerCount = 1
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Utils --------------------------------------------------------------------------------------------------------------------------------
function updateTimerText()
    local minutes = 0
    local seconds = floor(globalTable.timer / 30)
    while seconds >= 60 do
        minutes = minutes + 1
        seconds = seconds - 60
    end
    local text = tostring(minutes)
    if minutes < 10 then
        text = "0" .. text
    end
    text = text .. ":"

    if seconds < 10 then
        text = text .. "0" .. tostring(seconds)
    else
        text = text .. tostring(seconds)
    end

    currentTimerText = text
end

function adjustCurrentSpeed()
    if not globalTable.timerRunning or not playerTable[0].affectedBySpeed then return end

    local seconds = globalTable.timer / 30
    if seconds % globalTable.secondsForIncrement == 0 then
        if playerTable[0].speedMult + globalTable.speedIncrementAmount <= globalTable.maxSpeedMult then
            glowTimer = 25
            play_sound(SOUND_GENERAL_BIG_CLOCK, states[0].pos)
            playerTable[0].speedMult = playerTable[0].speedMult + globalTable.speedIncrementAmount
        elseif playerTable[0].speedMult < globalTable.maxSpeedMult then
            glowTimer = 25
            play_sound(SOUND_GENERAL_BIG_CLOCK, states[0].pos)
            playerTable[0].speedMult = globalTable.maxSpeedMult
        end

        if playerTable[0].speedMult == globalTable.maxSpeedMult and not playerTable[0].maxReached then
            playerTable[0].maxReached = true
            popup("Reached max speed.", 1)
        end
    end
end

function resetMatchValues()
    globalTable.timerRunning = false
    globalTable.timer = 0

    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected then
            playerTable[i].speedMult = globalTable.startingSpeedMult
            playerTable[i].maxReached = false
        end
    end
end

---@param val number
---@param minVal number
---@param maxVal number
---@return number
function clamp(val, minVal, maxVal)
    if val < minVal then
        return minVal
    elseif val > maxVal then
        return maxVal
    end
    return val
end

--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hook Functions -----------------------------------------------------------------------------------------------------------------------
function update()
    if networkIsServer() then
        if globalTable.timerRunning then
            globalTable.timer = globalTable.timer + 1
        end
        if playerCount ~= serverPlayerCount() then
            if globalTable.resetOnJoin and globalTable.timerRunning then
                resetMatchValues()
                globalPopup("The server player count changed. Stopping match", 1)
            end
            playerCount = serverPlayerCount()
        end
    end

    if glowTimer > 0 then
        glowTimer = glowTimer - 1
    end

    if globalTable.timer % 30 == 0 and globalTable.timer > 0 then
        adjustCurrentSpeed()
        updateTimerText()
    end
end

---@param m MarioState
function before_phys_step(m)
    if m.playerIndex ~= 0
        or not nps[0].connected
        or not playerTable[0].affectedBySpeed
        or not globalTable.timerRunning
        or notAffectedActions[m.action]
        or (m.prevAction & ACT_FLAG_ON_POLE ~= 0 and m.action & ACT_FLAG_AIR ~= 0) then
        return
    end

    m.vel.x = m.vel.x * playerTable[0].speedMult
    m.vel.z = m.vel.z * playerTable[0].speedMult
end

function render_hud()
    local wdth = measureText("000:00") * 3
    local x = getScreenWidth() / 2 - wdth / 2
    local y = 5
    if showTimer then
        setColor(0, 0, 0, 150)
        drawRect(x - 10, y, wdth + 20, 96)

        if glowTimer > 0 then
            setColor(240, 240, 57, 170)
        else
            setColor(240, 240, 240, 170)
        end
        drawText(currentTimerText, x + wdth / 2 - measureText(currentTimerText) * 3 / 2, y, 3)
    end

    if showCurrSpeed then
        wdth = measureText("SPEED: x0000.00")
        x = getScreenWidth() / 2 - wdth / 2
        y = 106
        setColor(0, 0, 0, 150)
        drawRect(x - 10, y, wdth + 20, 32)

        if glowTimer > 0 then
            setColor(223, 113, 0, 170)
        else
            setColor(255, 0, 0, 170)
        end


        text = "SPEED: x" .. format("%.2f", playerTable[0].speedMult)
        drawText(text, x + wdth / 2 - measureText(text) / 2, y, 1)
    end

    resetColor()
end

--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Command Functions --------------------------------------------------------------------------------------------------------------------
---@param msg string
---@return boolean
function startMatch(msg)
    if msg ~= "" then
        return false
    end

    if globalTable.timerRunning then
        popup("The match already started.", 1)
        return true
    end

    local count = 0
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and playerTable[i].affectedBySpeed then
            count = count + 1
        end
    end
    if count == 0 then
        popup("There must be at least one player affected by the speed multiplier to start the match", 2)
        return true
    end

    globalTable.timerRunning = true
    globalPopup("The match has started. RUN!", 1)

    return true
end

---@param msg string
---@return boolean
function stopMatch(msg)
    if msg ~= "" then
        return false
    end
    if not globalTable.timerRunning then
        popup("There is no match in progress.", 1)
        return true
    end
    resetMatchValues()
    globalPopup("The match has been interrupted.", 1)

    return true
end

---@param msg string
---@return boolean
function toggleAffectedBySpeed(msg)
    if msg ~= "" then
        return false
    end

    playerTable[0].affectedBySpeed = not playerTable[0].affectedBySpeed

    if playerTable[0].affectedBySpeed then
        popup("Applying speed multiplier on you.", 1)
    else
        popup("You are now at normal speed.", 1)
    end

    return true
end

--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_UPDATE, update)
hookEvent(HOOK_BEFORE_PHYS_STEP, before_phys_step)
hookEvent(HOOK_ON_HUD_RENDER, render_hud)

if networkIsServer() then
    hookCommand("speed-start", "- Start a match.", startMatch)
    hookCommand("speed-stop", "- Stop the current match", stopMatch)
end
hookCommand("speed-toggle", "- Toggles whether if you are affected or not by the speed mechanics.", toggleAffectedBySpeed)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Mod Menu -----------------------------------------------------------------------------------------------------------------------------
function mm_toggle_show_timer(_, val)
    showTimer = val
end
hookMMCheckbox("Show Timer", true, mm_toggle_show_timer)

function mm_toggle_show_speed(_, val)
    showCurrSpeed = val
end
hookMMCheckbox("Show Speed", false, mm_toggle_show_speed)

if networkIsServer() then
    function mm_toggle_reset_on_join(_, val)
        globalTable.resetOnJoin = val
    end
    hookMMCheckbox("Reset Match When Someone Joins", true, mm_toggle_reset_on_join)

    function mm_set_starting_speed_mult(_, val)
        globalTable.startingSpeedMult = clamp(tonumber(val) or globalTable.startingSpeedMult, 0.1,
            globalTable.maxSpeedMult - 1)
        resetMatchValues()
    end
    hookMMInput("Starting Speed Multiplier", "1", 8, mm_set_starting_speed_mult)

    function mm_set_max_speed_mult(_, val)
        resetMatchValues()
        globalTable.maxSpeedMult = clamp(tonumber(val) or globalTable.maxSpeedMult, globalTable.startingSpeedMult + 1,
            1000)
    end
    hookMMInput("Max Speed Multiplier", "10", 8, mm_set_max_speed_mult)

    function mm_set_increment_amount(_, val)
        resetMatchValues()
        globalTable.speedIncrementAmount = clamp(tonumber(val) or globalTable.speedIncrementAmount, 0.1,
            (globalTable.maxSpeedMult - globalTable.startingSpeedMult) / 2)
    end
    hookMMInput("Mult. Increment Amount", "0.5", 8, mm_set_increment_amount)

    function mm_set_increment_time(_, val)
        resetMatchValues()
        chatMsg("Seconds to increment speed: " .. tostring(val))
        globalTable.secondsForIncrement = val
    end
    hookMMSlider("Increment Interval (s)", 10, 1, 60, mm_set_increment_time)
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------
