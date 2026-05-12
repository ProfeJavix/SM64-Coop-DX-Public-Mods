--#region Localizations ---------------------------------------------------------------------

local ceil = math.ceil
local clamp = math.clamp
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_get_screen_width = djui_hud_get_screen_width
local djui_hud_measure_text = djui_hud_measure_text
local djui_hud_print_text = djui_hud_print_text
local djui_hud_render_rect = djui_hud_render_rect
local djui_hud_set_color = djui_hud_set_color
local djui_hud_set_font = djui_hud_set_font
local djui_popup_create_global = djui_popup_create_global
local hook_event = hook_event
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local hook_mod_menu_inputbox = hook_mod_menu_inputbox
local network_is_server = network_is_server
local tonumber = tonumber
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

local showControls = true

local POWERUP_HUD_DATA = {
    {
        color = {r = 209, g = 219, b = 0},
        text = "HAMMER",
        controls = {
            {action = ACT_HAMMER_SWING, text = 'Y (ON GROUND) - SWING'},
            {action = ACT_HAMMER_360, text = 'X (ON GROUND) - 360 SWING'},
            {action = ACT_HAMMER_GROUND_POUND, text = 'X (ON AIR) - GROUND POUND'},
            {action = ACT_HAMMER_DIVE_GROUND_POUND, text = 'Y (ON AIR) - HAMMER DIVE'}
        }
    },
    {
        color = {r = 255, g = 44, b = 0},
        text = "FIRE FLOWER",
        controls = {
            {action = ACT_FIREBALL_SHOOT, text = 'Y - SINGLE FIREBALL'},
            {action = ACT_FIREBALL_TRIPLE_SHOOT, text = 'X (ON GROUND) - TRIPLE FIREBALL'},
            {action = ACT_FIREBALL_TWIRL_SHOOTING, text = 'X (ON AIR) - TWIRL FIREBALL SHOOTING'}
        }
    },
    {
        color = {r = 45, g = 45, b = 45},
        text = "CANNON",
        controls = {
            {action = ACT_CANNON_SHOOT, text = 'Y - QUICK SHOOT'},
            {action = ACT_CANNON_FIRST_PERSON, text = 'D-PAD UP - TOGGLE FIRST PERSON'}
        }
    },
    {
        color = {r = 6, g = 99, b = 219},
        text = "BOOMERANG",
        controls = {
            {action = ACT_BOOMERANG_THROW, text = 'Y (ON GROUND) - THROW'},
            {action = ACT_BOOMERANG_360_THROW, text = 'X (ON GROUND) - SPIN ATTACK'},
            {action = ACT_BOOMERANG_FIRST_PERSON, text = 'D-PAD UP - TOGGLE FIRST PERSON'}
        }
    }
}

function on_hud_render()

    local m = states[0]
    local pt = playerTable[0]

    if pt.powerUp ~= 0 and m.action & ACT_GROUP_CUTSCENE == 0 then

        local seconds = ceil((pt.powerUpTimer or 0) / 30)
        if seconds > 0 then

            local pu = pt.powerUp
            local hudData = POWERUP_HUD_DATA[pu]

            djui_hud_set_font(FONT_RECOLOR_HUD)
            djui_hud_set_color(hudData.color.r, hudData.color.g, hudData.color.b, 240)
            
            local text = hudData.text .. " (" .. tostring(seconds) .. "s)"
            djui_hud_print_text(text, 5, djui_hud_get_screen_height() / 2 - 36, 2)

            if showControls then

                local controls = hudData.controls

                local hght = 20 + (#controls * 32) + (#controls * 10)
                local x = djui_hud_get_screen_width() - 405
                local y = djui_hud_get_screen_height() / 2 - hght / 2

                djui_hud_set_color(25, 25, 25, 150)
                djui_hud_render_rect(x, y, 400, hght)

                djui_hud_set_color(158, 0, 228, 240)
                djui_hud_print_text('CONTROLS', x + 200 - djui_hud_measure_text('CONTROLS'), y - 48, 2)

                djui_hud_set_font(FONT_NORMAL)
                y = y + 10
                

                for i = 1, #controls do
                    local text = controls[i].text
                    local action = controls[i].action

                    if action == m.action then
                        djui_hud_set_color(237, 228, 38, 240)
                    else
                        djui_hud_set_color(220, 220, 220, 240)
                    end

                    djui_hud_print_text(text, x + 200 - djui_hud_measure_text(text) / 2, y, 1)
                    y = y + 42
                end
            end

        end
    end
end

hook_event(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)

    hook_mod_menu_checkbox('Show Controls', true, function (_, val)
        showControls = val
    end)
if network_is_server() then
    hook_mod_menu_inputbox('Powerup Seconds [5-60]', '10', 8, function (_, val)
        globalTable.powerUpStartTimer = clamp(ceil(tonumber(val) or 10), 5, 60) * 30
    end)
    hook_mod_menu_checkbox('Randomized Powerups', false, function(_, val)
        globalTable.randomPowerups = val
        for i = 0, MAX_PLAYERS - 1 do
            if nps[i].connected then
                playerTable[i].toggleRandomPowerups = true
            end
        end
        djui_popup_create_global(ternary(val, "Powerups have been randomized.", "Powerups are no longer randomized."), 1)
    end)

    if _G.mhExists then
        hook_mod_menu_checkbox('Powerups for hunters', true, function (_, val)
            globalTable.powerUpsForHunters = val
        end)
    end
end