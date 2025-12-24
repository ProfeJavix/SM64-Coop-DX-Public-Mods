--#region Localizations ---------------------------------------------------------------------

local ceil = math.ceil
local djui_hud_get_fov_coeff = djui_hud_get_fov_coeff
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_get_screen_width = djui_hud_get_screen_width
local djui_hud_measure_text = djui_hud_measure_text
local djui_hud_set_color = djui_hud_set_color
local djui_hud_set_font = djui_hud_set_font
local djui_hud_set_resolution = djui_hud_set_resolution
local djui_hud_world_pos_to_screen_pos = djui_hud_world_pos_to_screen_pos
local djui_popup_create = djui_popup_create
local hook_mod_menu_slider = hook_mod_menu_slider
local is_game_paused = is_game_paused
local is_player_active = is_player_active
local mod_storage_save_number = mod_storage_save_number
local network_is_server = network_is_server
local play_sound = play_sound
local set_mario_action = set_mario_action
local spawn_non_sync_object = spawn_non_sync_object
local spawn_sync_object = spawn_sync_object
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

local hooks = {}

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

function hooks.update()
    if playerTable[0].cooldown > 0 then
        playerTable[0].cooldown = playerTable[0].cooldown - 1
    end
end

local nm = nil ---@type MarioState | nil
local fbIcons = {} ---@type Object[]

---@param m MarioState
function hooks.mario_update(m)

    local idx = m.playerIndex
    if idx ~= 0 then
        if is_player_active(m) ~= 0 and (not fbIcons[idx] or fbIcons[idx].activeFlags == ACTIVE_FLAG_DEACTIVATED) then
            fbIcons[idx] = spawn_non_sync_object(id_bhvFrostbiteIcon, E_MODEL_FB_ICON, m.pos.x, m.pos.y, m.pos.z, function(o)
                o.oOwner = idx
            end)
        end
        return
    elseif playerTable[0].cooldown > 0 then
        return
    end

    nm = nearestFreezeTarget(m)

    if getMHTeam(0) ~= 1 then
        if playerTable[0].freeze then
            set_mario_action(m, ACT_FROZEN, 0)
            playerTable[0].freeze = false
        end
        return
    end

    if not playerTable[0].hasFrostbite and playerTable[0].coins >= globalTable.coinsToFreeze then
        playerTable[0].hasFrostbite = true
        play_sound(SOUND_MENU_STAR_SOUND_OKEY_DOKEY, gGlobalSoundSource)
    end

    if m.controller.buttonPressed & Y_BUTTON ~= 0 then
        if playerTable[0].hasFrostbite and nm then
            playerTable[nm.playerIndex].freeze = true
            spawn_sync_object(id_bhvTagIce, E_MODEL_TAG_ICE, nm.pos.x, nm.pos.y, nm.pos.z, function(o)
                o.oOwner = nps[nm.playerIndex].globalIndex
            end)

            playerTable[0].hasFrostbite = false
            playerTable[0].cooldown = globalTable.freezeCooldown
            playerTable[0].coins = 0
        else
            play_sound(SOUND_MENU_CAMERA_BUZZ, gGlobalSoundSource)
        end
    end
end

---@param m MarioState
function hooks.allow_force_water_action(m)
    if m.action == ACT_FROZEN then
        return false
    end
end

---@param m MarioState
---@param o Object
---@param intType InteractionType
function hooks.on_interact(m, o, intType)
    if m.playerIndex ~= 0 or intType ~= INTERACT_COIN or playerTable[0].hasFrostbite or playerTable[0].cooldown > 0 then
        return
    end

    playerTable[0].coins = playerTable[0].coins + 1
end

local prevPos = nil
function hooks.on_hud_render()
    if is_game_paused() then return end

    djui_hud_set_font(FONT_RECOLOR_HUD)
    djui_hud_set_color(37, 208, 255, 240)

    local x, y = 0, 0
    local text = ''

    if getMHTeam(0) == 0 then
        local m = states[0]
        if m.action == ACT_FROZEN then
            local frozenSeconds = ceil((globalTable.frozenTimer - m.actionTimer) / 30)

			text = "YOU'VE BEEN FROZEN (" .. tostring(frozenSeconds) .. 's)'
            x = djui_hud_get_screen_width() / 2 - djui_hud_measure_text(text)
            y = djui_hud_get_screen_height() / 2 - 16

            drawTextWithBorder(text, x, y, 2)
        end
    elseif playerTable[0].cooldown == 0 and playerTable[0].hasFrostbite then

        if not nm then
            text = 'FROSTBITE READY'
            drawTextWithBorder(text, 5, djui_hud_get_screen_height() / 2 - 16, 2)
            return
        end

        djui_hud_set_resolution(RESOLUTION_N64)

        text = 'PRESS Y TO USE FROSTBITE'

        local pos = { x = nm.pos.x, y = nm.pos.y - 20, z = nm.pos.z }
        local out = { x = 0, y = 0, z = 0 }

        djui_hud_world_pos_to_screen_pos(pos, out)

        if isPosInScreen(out.x, out.y) then
            local scale = -400 / out.z * djui_hud_get_fov_coeff()
            out.x = out.x - djui_hud_measure_text(text) * scale / 2

            if not prevPos then
                prevPos = { x = out.x, y = out.y, scale = scale}
            end

            drawTextWithBorder(text, out.x, out.y, scale, prevPos)

            prevPos = {x = out.x, y = out.y, scale = scale}
        else
            djui_hud_set_resolution(RESOLUTION_DJUI)
            drawTextWithBorder(text, 5, djui_hud_get_screen_height() / 2 - 16, 2)
        end
    else
        if playerTable[0].cooldown > 0 then
            djui_hud_set_color(40, 70, 210, 240)
            text = 'FROSTBITE COOLDOWN: ' .. tostring(ceil(playerTable[0].cooldown / 30))
        else
            djui_hud_set_color(255, 240, 20, 240)
            text = 'COINS FOR FROSTBITE: ' .. tostring(globalTable.coinsToFreeze - playerTable[0].coins)
        end

        drawTextWithBorder(text, 5, djui_hud_get_screen_height() / 2 - 16, 2)
    end
end

if network_is_server() then
    hook_mod_menu_slider('Frozen Timer', ceil(globalTable.frozenTimer / 30), 3, 30, function(_, val)
        if val * 30 ~= globalTable.frozenTimer then
            djui_popup_create('Frozen Timer: ' .. tostring(val) .. 's', 1)
        end
        globalTable.frozenTimer = val * 30
        mod_storage_save_number('frozenTimer', globalTable.frozenTimer)
    end)

    hook_mod_menu_slider('Frostbite Cooldown', ceil(globalTable.freezeCooldown / 30), 5, 60, function(_, val)
        if val * 30 ~= globalTable.freezeCooldown then
            djui_popup_create('Frostbite Cooldown: ' .. tostring(val) .. 's', 1)
        end
        globalTable.freezeCooldown = val * 30
        mod_storage_save_number('freezeCooldown', globalTable.freezeCooldown)
    end)

    hook_mod_menu_slider('Coins For Frostbite', globalTable.coinsToFreeze, 10, 100, function(_, val)
        if val ~= globalTable.coinsToFreeze then
            djui_popup_create('Coins For Frostbite: ' .. tostring(val), 1)
        end
        globalTable.coinsToFreeze = val
        mod_storage_save_number('coinsToFreeze', globalTable.coinsToFreeze)
    end)
end

return hooks