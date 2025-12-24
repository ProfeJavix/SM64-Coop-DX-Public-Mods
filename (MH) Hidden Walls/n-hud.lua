--#region Localizations ---------------------------------------------------------------------

local ceil = math.ceil
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_print_text = djui_hud_print_text
local djui_hud_set_color = djui_hud_set_color
local djui_hud_set_font = djui_hud_set_font
local djui_popup_create = djui_popup_create
local floor = math.floor
local hook_event = hook_event
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local hook_mod_menu_slider = hook_mod_menu_slider
local is_game_paused = is_game_paused
local mod_storage_save_bool = mod_storage_save_bool
local mod_storage_save_number = mod_storage_save_number
local network_is_server = network_is_server
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

if not _G.mhExists then return end

local states = gMarioStates
local globalTable = gGlobalSyncTable

function on_hud_render()
    if is_game_paused() or not canSeeWalls(states[0]) then return end

    djui_hud_set_font(FONT_RECOLOR_HUD)

    if cooldown > 0 then
        local seconds = ceil(cooldown / 30)
        djui_hud_set_color(160, 90, 180, 240)
        djui_hud_print_text('COOLDOWN: ' .. tostring(seconds) .. 's', 5, djui_hud_get_screen_height() / 2 - 23, 1.5)
        return
    end

    local curY = djui_hud_get_screen_height() - 50 - ternary(showWallPH, 128, 0)
    djui_hud_set_color(90, 200, 220, 240)
    djui_hud_print_text('PRESS X TO TOGGLE WALL PREVIEW', 5, curY, 1.5)

    if showWallPH then
        curY = curY + 55
        djui_hud_set_color(240, 0, 0, 240)
        djui_hud_print_text('PRESS Y TO PLACE WALL', 5, curY, 1.5)

        curY = curY + 55
        djui_hud_set_color(0, 240, 0, 240)
        djui_hud_print_text('PRESS L TO RESET PREVIEW', 5, curY, 1.5)
    end
end

hook_event(HOOK_ON_HUD_RENDER, on_hud_render)

if network_is_server() then

    hook_mod_menu_checkbox('Wall Team [OFF - HUNTERS | ON - RUNNERS]', globalTable.wallTeam == TEAM_RUNNERS, function (_, val)
        globalTable.wallTeam = ternary(val, TEAM_RUNNERS, TEAM_HUNTERS)
        mod_storage_save_number('wallTeam', globalTable.wallTeam)
    end)

    hook_mod_menu_checkbox('Wall I-Frames', globalTable.wallIFrames, function (_, val)
        globalTable.wallIFrames = val
        mod_storage_save_bool('wallIFrames', globalTable.wallIFrames)
    end)

    hook_mod_menu_slider('Wall Cooldown', floor(globalTable.wallPlacementCooldown / 30), 2, 60, function (_, val)

        if val * 30 ~= globalTable.wallPlacementCooldown then
            djui_popup_create('Wall Cooldown: ' .. tostring(val) .. 's', 1)
        end

        globalTable.wallPlacementCooldown = val * 30
        mod_storage_save_number('wallPlacementCooldown', globalTable.wallPlacementCooldown)
    end)

    hook_mod_menu_slider('Wall Despawn', floor(globalTable.wallDespawnTime / 30), 5, 120, function (_, val)
        if val * 30 ~= globalTable.wallDespawnTime then
            djui_popup_create('Wall Despawn: ' .. tostring(val) .. 's', 1)
        end

        globalTable.wallDespawnTime = val * 30
        mod_storage_save_number('wallDespawnTime', globalTable.wallDespawnTime)
    end)

    hook_mod_menu_slider('Wall Width', globalTable.wallXScale * 10, 2, 30, function(_, val)
        globalTable.wallXScale = val / 10
        mod_storage_save_number('wallXScale', globalTable.wallXScale)
    end)

    hook_mod_menu_slider('Wall Height', globalTable.wallYScale * 10, 2, 30, function(_, val)
        globalTable.wallYScale = val / 10
        mod_storage_save_number('wallYScale', globalTable.wallYScale)
    end)

    hook_mod_menu_slider('Wall Thickness', globalTable.wallZScale * 10, 2, 100, function(_, val)
        globalTable.wallZScale = val / 10
        mod_storage_save_number('wallZScale', globalTable.wallZScale)
    end)
end