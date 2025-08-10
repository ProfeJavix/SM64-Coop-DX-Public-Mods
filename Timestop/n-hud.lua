local ceil = math.ceil
local clamp = clamp
local min = math.min
local screenWidth = djui_hud_get_screen_width
local screenHeight = djui_hud_get_screen_height
local drawRect = djui_hud_render_rect_interpolated
local setColor = djui_hud_set_color
local setFont = djui_hud_set_font
local play_sound = play_sound
local drawText = djui_hud_print_text
local measure = djui_hud_measure_text
local hook_event = hook_event
local network_is_server = network_is_server
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local hook_mod_menu_slider = hook_mod_menu_slider

local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

local prevRect = {x = screenWidth() / 2, y = screenHeight() / 2, wdth = 0, hght = 0}
local RESIZE_SPEED = 200

function drawTimestopRect()

    if not allowJJBAEffects then return end

    local screenWdth, screenHght = screenWidth() , screenHeight()
    local x, y, wdth, hght = prevRect.x, prevRect.y, prevRect.wdth, prevRect.hght

    wdth = clamp(min(wdth + ternary(globalTable.timeStopSeconds > 0, RESIZE_SPEED, -RESIZE_SPEED), screenWdth), 0, screenWdth)
    hght = clamp(wdth / (screenWdth / screenHght), 0, screenHght)

    x = screenWdth / 2 - wdth/2
    y = screenHght / 2 - hght/2

    setColor(30, 30, 30, 150)
    drawRect(prevRect.x, prevRect.y, prevRect.wdth, prevRect.hght, x, y, wdth, hght)

    prevRect = {x = x, y = y, wdth = wdth, hght = hght}
end

function on_hud_render()

    local team = playerTable[0].team
    setFont(FONT_RECOLOR_HUD)

    if globalTable.timeStopSeconds > 0 then
        if globalTable.timeStopSeconds % 30 == 0 then
            play_sound(SOUND_GENERAL_BIG_CLOCK, gGlobalSoundSource)
        end

        if not allowJJBAEffects and team ~= globalTable.timeStopTeam then
            drawText('STOPPED', 5, screenHeight() / 2 - 27, 1.5)
        end

    else
        if globalTable.timeStopTeam == team then
            local seconds = globalTable.timeStopCooldown
            local text = ''
            if seconds > 0 then
                setColor(46, 204, 228, 240)
                text = 'Timestop Cooldown: ' .. ceil(seconds / 30) .. 's'
            else
                setColor(TEAM_COLORS[team].r, TEAM_COLORS[team].g, TEAM_COLORS[team].b, TEAM_COLORS[team].a)
                text = 'Press X To Stop Time'
            end
            drawText(text, 5, screenHeight() / 2 - 27, 1.5)
        end
    end

    drawTimestopRect()

    if not mhExists then
        setColor(TEAM_COLORS[team].r, TEAM_COLORS[team].g, TEAM_COLORS[team].b, TEAM_COLORS[team].a)
        local text = TEAM_NAMES[team][1] .. ' Team'
        drawText(text, screenWidth() / 2 - measure(text), 5, 2)
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
