--#region Localizations ---------------------------------------------------------------------

local ceil = math.ceil
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_get_screen_width = djui_hud_get_screen_width
local djui_hud_measure_text = djui_hud_measure_text
local djui_hud_print_text = djui_hud_print_text
local djui_hud_set_color = djui_hud_set_color
local djui_hud_set_font = djui_hud_set_font
local hook_event = hook_event
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local hook_mod_menu_slider = hook_mod_menu_slider
local le_set_ambient_color = le_set_ambient_color
local lerp = math.lerp
local network_is_server = network_is_server
local play_sound = play_sound

--#endregion --------------------------------------------------------------------------------

local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

ambientTimer = -1

function on_hud_render()

    local team = playerTable[0].team
    djui_hud_set_font(FONT_RECOLOR_HUD)

    if globalTable.timeStopSeconds > 0 then
        if globalTable.timeStopSeconds % 30 == 0 then
            play_sound(SOUND_GENERAL_BIG_CLOCK, gGlobalSoundSource)
        end

        if not allowJJBAEffects and team ~= globalTable.timeStopTeam then
            djui_hud_print_text('STOPPED', 5, djui_hud_get_screen_height() / 2 - 27, 1.5)
        end
    else
        if globalTable.timeStopTeam == team then
            local seconds = globalTable.timeStopCooldown
            local text = ''
            if seconds > 0 then
                djui_hud_set_color(46, 204, 228, 240)
                text = 'Timestop Cooldown: ' .. ceil(seconds / 30) .. 's'
            else
                djui_hud_set_color(TEAM_COLORS[team].r, TEAM_COLORS[team].g, TEAM_COLORS[team].b, TEAM_COLORS[team].a)
                text = 'Press X To Stop Time'
            end
            djui_hud_print_text(text, 5, djui_hud_get_screen_height() / 2 - 27, 1.5)
        end
    end

    if ambientTimer >= 0 then

        local start, target
        if globalTable.timeStopSeconds > 0 then
            start, target = 255, 0
        else
            start, target = 0, 255
        end

        ambientTimer = ambientTimer + 1
        le_set_ambient_color(lerp(start, target, ambientTimer / 25), 255, 255)

        if ambientTimer == 25 then
            ambientTimer = -1
        end
    end

    if not mhExists then
        djui_hud_set_color(TEAM_COLORS[team].r, TEAM_COLORS[team].g, TEAM_COLORS[team].b, TEAM_COLORS[team].a)
        local text = TEAM_NAMES[team][1] .. ' Team'
        djui_hud_print_text(text, djui_hud_get_screen_width() / 2 - djui_hud_measure_text(text), 5, 2)
    end
end

hook_event(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)

hook_mod_menu_checkbox('JJBA Effects', true, function (_, val)
    allowJJBAEffects = val
end)

if network_is_server() then
    hook_mod_menu_slider('Timestop Seconds', 5, 1, 15, function(_, val)
        globalTable.timeStopStartingSeconds = val * 30
    end)

    hook_mod_menu_slider('Timestop Cooldown', 10, 5, 60, function(_, val)
        globalTable.timeStopStartingCooldown = val * 30
    end)
end
