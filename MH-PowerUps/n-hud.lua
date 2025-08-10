if not _G.mhExists then return end

local network_is_server = network_is_server
local globalPopup = djui_popup_create_global
local hookEvent = hook_event
local hookMMInput = hook_mod_menu_inputbox
local hookMMCheckbox = hook_mod_menu_checkbox
local setColor = djui_hud_set_color
local measure = djui_hud_measure_text
local setFont = djui_hud_set_font
local drawText = djui_hud_print_text
local drawRect = djui_hud_render_rect
local screenWidth = djui_hud_get_screen_width
local screenHeight = djui_hud_get_screen_height
local ceil = math.ceil
local clamp = clampf

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

            setFont(FONT_RECOLOR_HUD)
            setColor(hudData.color.r, hudData.color.g, hudData.color.b, 240)

            local text = hudData.text .. " (" .. tostring(seconds) .. "s)"
            drawText(text, 5, screenHeight() / 2 - 36, 2)

            if showControls then

                local controls = hudData.controls

                local hght = 20 + (#controls * 32) + (#controls * 10)
                local x = screenWidth() - 405
                local y = screenHeight() / 2 - hght / 2

                setColor(25, 25, 25, 150)
                drawRect(x, y, 400, hght)

                setColor(158, 0, 228, 240)
                drawText('CONTROLS', x + 200 - measure('CONTROLS'), y - 48, 2)

                setFont(FONT_NORMAL)
                y = y + 10
                

                for i = 1, #controls do
                    local text = controls[i].text
                    local action = controls[i].action

                    if action == m.action then
                        setColor(237, 228, 38, 240)
                    else
                        setColor(220, 220, 220, 240)
                    end

                    drawText(text, x + 200 - measure(text) / 2, y, 1)
                    y = y + 42
                end
            end

        end
    end
end

hookEvent(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)

    hookMMCheckbox('Show Controls', true, function (_, val)
        showControls = val
    end)
if network_is_server() then
    hookMMInput('Powerup Seconds [5-60]', '10', 8, function (_, val)
        globalTable.powerUpStartTimer = clamp(ceil(tonumber(val) or 10), 5, 60) * 30
    end)
    hookMMCheckbox('Randomized Powerups', false, function(_, val)
        globalTable.randomPowerups = val
        for i = 0, MAX_PLAYERS - 1 do
            if nps[i].connected then
                playerTable[i].toggleRandomPowerups = true
            end
        end
        globalPopup(ternary(val, "Powerups have been randomized.", "Powerups are no longer randomized."), 1)
    end)
    hookMMCheckbox('Powerups for hunters', true, function (_, val)
        globalTable.powerUpsForHunters = val
    end)
end