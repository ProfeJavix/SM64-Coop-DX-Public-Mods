-- name: [MH] Secret Helpers v1.1
-- description: There are hidden players out there. Look out!\n\nMade by \\#333\\Profe\\#ff0\\Javix

---@class _G
---@field mhExists? boolean
---@field mhApi? table

if not _G.mhExists then return end

--#region Localization ---------------------------------------------------------------------------------------------------------------------


local djui_chat_message_create = djui_chat_message_create
local obj_scale = obj_scale
local network_is_server = network_is_server
local network_player_connected_count = network_player_connected_count
local play_sound = play_sound
local is_game_paused = is_game_paused
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_set_color = djui_hud_set_color
local djui_hud_render_rect = djui_hud_render_rect
local djui_hud_set_font = djui_hud_set_font
local djui_hud_print_text = djui_hud_print_text
local djui_hud_measure_text = djui_hud_measure_text
local hook_event = hook_event
local hook_chat_command = hook_chat_command
local djui_set_popup_disabled_override = djui_set_popup_disabled_override
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local ipairs = ipairs
local sub = string.sub
local clamp = math.clamp

local nps = gNetworkPlayers
local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

globalTable.popupBlockTimer = 0
globalTable.visibleRivalHelpers = false
globalTable.shCanExitAnytime = true
for i = 0, MAX_PLAYERS - 1 do
    playerTable[i].isSecretHelper = false
    playerTable[i].helperTeam = -1
end

gServerSettings.enablePlayerList = 0
gServerSettings.enablePlayersInLevelDisplay = 0

local getTeam = _G.mhApi.getTeam
local becomeTeam = function (idx, team)
    if team == 0 then
        _G.mhApi.become_hunter(idx)
    else
        _G.mhApi.become_runner(idx)
    end
end

--#endregion -------------------------------------------------------------------------------------------------------------------------------

--#region Vars and Consts ------------------------------------------------------------------------------------------------------------------
local PARTICLE_FLAGS = {
    PARTICLE_19,
    PARTICLE_2,
    PARTICLE_BREATH,
    PARTICLE_BUBBLE,
    PARTICLE_DIRT,
    PARTICLE_DUST,
    PARTICLE_FIRE,
    PARTICLE_HORIZONTAL_STAR,
    PARTICLE_IDLE_WATER_WAVE,
    PARTICLE_LEAF,
    PARTICLE_MIST_CIRCLE,
    PARTICLE_PLUNGE_BUBBLE,
    PARTICLE_SHALLOW_WATER_SPLASH,
    PARTICLE_SHALLOW_WATER_WAVE,
    PARTICLE_SNOW,
    PARTICLE_SPARKLES,
    PARTICLE_TRIANGLE,
    PARTICLE_VERTICAL_STAR,
    PARTICLE_WATER_SPLASH,
    PARTICLE_WAVE_TRAIL
}

local toggleMenuOpen = false
local selectedListPos = -1
local selectedListIdx = 0
--#endregion -------------------------------------------------------------------------------------------------------------------------------

--#region Utils ----------------------------------------------------------------------------------------------------------------------------

---@param cond boolean
function ternary(cond, ifTrue, ifFalse)
    return cond and ifTrue or ifFalse
end

---@param idx integer
---@return boolean
function localCanSeePlayer(idx)
    return idx == 0 or
    getTeam(0) == getTeam(idx) or
    not playerTable[idx].isSecretHelper or
    (globalTable.visibleRivalHelpers and playerTable[0].isSecretHelper)
end

---@param text string
---@return string
function stringWithoutHex(text)
    local aux = ""
    local inSlash = false
    for i = 1, #text do
        local c = sub(text, i, i)
        if c == '\\' then
            inSlash = not inSlash
        elseif not inSlash then
            aux = aux .. c
        end
    end
    return aux
end

---@param curPos integer
---@param top integer
---@return integer
function adjustSelectedIdx(curPos, top, moveAmount)
    local newPos = curPos + moveAmount
    if top ~= 0 then
        if curPos == top and newPos > top then
            newPos = 1
        elseif curPos == 1 and newPos < 1 then
            newPos = top
        end
        curPos = clamp(newPos, 1, top)
    else
        curPos = 1
    end
    return curPos
end

---@return integer
function getNonHelperRunnerCount()
    local count = 0
    for i = 0, MAX_PLAYERS - 1 do
        if getTeam(i) == 1 and not playerTable[i].isSecretHelper then
            count = count + 1
        end
    end
    return count
end

function log(msg)
    djui_chat_message_create(tostring(msg))
end
--#endregion -------------------------------------------------------------------------------------------------------------------------------

--#region Hook Funcs -----------------------------------------------------------------------------------------------------------------------

function update()
    --[[ if not djui_is_popup_disabled() then
        djui_set_popup_disabled_override(true)
    end ]]

    if globalTable.popupBlockTimer > 0 then
        djui_set_popup_disabled_override(true)
    elseif djui_is_popup_disabled() then
        djui_reset_popup_disabled_override()
    end

    if network_is_server() and globalTable.popupBlockTimer > 0 then
        globalTable.popupBlockTimer = globalTable.popupBlockTimer - 1
    end
end

---@param m MarioState
function mario_update(m)
    local idx = m.playerIndex
    if playerTable[idx].isSecretHelper then
        if localCanSeePlayer(idx) then
            m.marioBodyState.modelState = m.marioBodyState.modelState | MODEL_STATE_NOISE_ALPHA
        else
            obj_scale(m.marioObj, 0)
        end

        local team = getTeam(idx)

        if team == 1 and getNonHelperRunnerCount() == 0 then
            playerTable[idx].helperTeam = 0
        end

        if team ~= playerTable[idx].helperTeam then
            becomeTeam(idx, playerTable[idx].helperTeam)
        end
    end

    if idx == 0 and network_is_server() then

        local amount = 0
        if m.controller.buttonPressed & U_JPAD ~= 0 or m.controller.buttonPressed & L_JPAD ~= 0 or
            m.controller.buttonPressed & D_JPAD ~= 0 or m.controller.buttonPressed & R_JPAD ~= 0 then
            if m.controller.buttonPressed & U_JPAD ~= 0 then
                amount = -1
            elseif m.controller.buttonPressed & L_JPAD ~= 0 then
                amount = -5
            elseif m.controller.buttonPressed & D_JPAD ~= 0 then
                amount = 1
            else
                amount = 5
            end

            play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
        end
        selectedListPos = adjustSelectedIdx(selectedListPos, network_player_connected_count(), amount)

        if toggleMenuOpen and nps[selectedListIdx].connected then
            
            if m.controller.buttonPressed & Y_BUTTON ~= 0  then

                play_sound(SOUND_MENU_STAR_SOUND, gGlobalSoundSource)
                playerTable[selectedListIdx].isSecretHelper = not playerTable[selectedListIdx].isSecretHelper

                playerTable[selectedListIdx].helperTeam = ternary(playerTable[selectedListIdx].isSecretHelper, getTeam(selectedListIdx), -1)

            elseif m.controller.buttonPressed & X_BUTTON ~= 0 then

                play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
                toggleMenuOpen = false

            end
        end
    end
end

---@param m MarioState
function before_mario_update(m)
    if not localCanSeePlayer(m.playerIndex) then
        for _, p in ipairs(PARTICLE_FLAGS) do
            m.particleFlags = m.particleFlags & ~p
        end
        m.flags = m.flags | MARIO_ACTION_SOUND_PLAYED
    end
end

---@param m MarioState
---@param intType InteractionType
function allow_interact(m, _, intType)
    if playerTable[m.playerIndex].isSecretHelper and (intType == INTERACT_STAR_OR_KEY or intType == INTERACT_COIN or intType == INTERACT_GRABBABLE) then
        return false
    end
end

---@param m MarioState
---@return CharacterSound | nil
function on_char_sound(m)
    if not localCanSeePlayer(m.playerIndex) then
        return CHAR_SOUND_YAH_WAH_HOO
    end
end

function on_seq_load(idx)
    if not localCanSeePlayer(idx) then
        return SEQ_SOUND_PLAYER
    end
end

function on_nametags_render(idx)

    if not localCanSeePlayer(idx) then
        return ''
    end
end

function on_hud_render()

    if not network_is_server() or is_game_paused() or not toggleMenuOpen then return end

    local curY = djui_hud_get_screen_height() / 2 - 68
    local curText = "PLAYERS"
    local count = 0

    djui_hud_set_color(45, 45, 45, 150)
    djui_hud_render_rect(5, curY, 300, 136)

    djui_hud_set_font(FONT_CUSTOM_HUD)
    djui_hud_set_color(255, 255, 255, 200)
    djui_hud_print_text(curText, 155 - djui_hud_measure_text(curText), curY - 48, 2)
    djui_hud_set_font(FONT_NORMAL)

    curY = curY + 10

    for i = 1, MAX_PLAYERS do
        local np = nps[i - 1]
        if np.connected then
            if count > 2 then break end

            if i >= selectedListPos - 1 and i <= selectedListPos + 1 then
                curText = stringWithoutHex(np.name) .. ternary(playerTable[np.localIndex].isSecretHelper, ' (helper)', '')

                if i == selectedListPos then
                    curY = djui_hud_get_screen_height() / 2 - 16
                    djui_hud_set_color(150, 150, 150, 150)
                    djui_hud_render_rect(5, curY - 5, 300, 42)
                    selectedListIdx = np.localIndex
                end

                djui_hud_set_color(230, 230, 230, ternary(playerTable[np.localIndex].isSecretHelper, 100, 200))
                djui_hud_print_text(curText, 155 - djui_hud_measure_text(curText) / 2, curY, 1)

                curY = curY + 42
                count = count + 1
            end
        end
    end

    djui_hud_set_font(FONT_RECOLOR_HUD)

    djui_hud_set_color(230, 0, 0, 200)
    curY = djui_hud_get_screen_height() / 2 + 68
    curText = "PRESS Y TO TOGGLE"
    djui_hud_print_text(curText, 155 - djui_hud_measure_text(curText) * 1.5 / 2, curY, 1.5)

    djui_hud_set_color(0, 0, 230, 200)
    curY = curY + 45
    curText = "PRESS X TO CLOSE"
    djui_hud_print_text(curText, 155 - djui_hud_measure_text(curText) * 1.5 / 2, curY, 1.5)
end

function avoid_helper_popup()
    if playerTable[0].isSecretHelper then
        globalTable.popupBlockTimer = 15
    end
end

function on_pause_exit(_)
	avoid_helper_popup()
	
	if getTeam(0) == 1 and globalTable.shCanExitAnytime and playerTable[0].isSecretHelper then
		djui_chat_message_create("RUNNER HELPER DETECTED: \\#0f0\\EXIT GRANTED")
		return true
	end
end

--#endregion -------------------------------------------------------------------------------------------------------------------------------

--#region Hooks ----------------------------------------------------------------------------------------------------------------------------

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_ALLOW_INTERACT, allow_interact)
hook_event(HOOK_CHARACTER_SOUND, on_char_sound)
hook_event(HOOK_ON_SEQ_LOAD, on_seq_load)
hook_event(HOOK_ON_NAMETAGS_RENDER, on_nametags_render)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)
hook_event(HOOK_USE_ACT_SELECT, avoid_helper_popup)
hook_event(HOOK_ON_PAUSE_EXIT, on_pause_exit)

if network_is_server() then
    hook_chat_command('sh-toggle', " - Opens the toggle menu.", function (_)

        if toggleMenuOpen then
            djui_chat_message_create('The toggle menu is already open')
        else
            toggleMenuOpen = true
            play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
        end

        return true
    end)
	
	hook_mod_menu_checkbox('Rival helpers can see each other', false, function(_, val)
		globalTable.visibleRivalHelpers = val
	end)
	
	hook_mod_menu_checkbox('Runner helpers can exit level anytime', true, function(_, val)
		globalTable.shCanExitAnytime = val
	end)
end
--#endregion -------------------------------------------------------------------------------------------------------------------------------