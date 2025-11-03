if not _G.mhExists then return end

local network_is_server = network_is_server
local hookEvent = hook_event
local hookMMInput = hook_mod_menu_inputbox
local setColor = djui_hud_set_color
local setFont = djui_hud_set_font
local drawText = djui_hud_print_text
local drawRect = djui_hud_render_rect
local measure = djui_hud_measure_text
local screenWidth = djui_hud_get_screen_width
local screenHeight = djui_hud_get_screen_height
local ceil = math.ceil
local min = math.min
local clamp = math.clamp

local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

selectedListPos = 1

function on_hud_render()
    local m = states[0]
    if m.action == ACT_HUNTER_CONTROLLED then
        local text = "You're being controlled by " .. nameWithoutHex(getLocalIdxFromGlobal(m.actionArg))
        setColor(30, 30, 30, 180)
        drawText(text, screenWidth() / 2 - measure(text) * 3 / 2, screenHeight() / 2 - 48, 3)
    else
    
        local timer = ceil(ternary(not playerTable[0].isControlling, controlCooldown, playerTable[0].controlTimer) / 30)

        if not playerTable[0].isControlling then

            if getTeam(0) ~= 1 then return end

            local hunters = getHuntersList()
            local alpha = ternary(timer > 0, 100, 200)

            if #hunters > 0 then
                local curY = screenHeight() / 2 - 68
                setColor(45, 45, 45, min(150, alpha))
                drawRect(5, curY, 400, 136)

                setFont(FONT_CUSTOM_HUD)
                setColor(255, 255, 255, alpha)
                local curText = "PLAYERS"
                drawText(curText, 205 - measure(curText), curY - 48, 2)
                setFont(FONT_NORMAL)

                curY = curY + 10
                local count = 0

                for i = 1, #hunters do
                    if count > 2 then break end

                    if i >= selectedListPos - 1 and i <= selectedListPos + 1 then
                        curText = fitText(nameWithoutHex(hunters[i]), 400, 1)

                        if i == selectedListPos then
                            curY = screenHeight() / 2 - 16
                            setColor(150, 150, 150, min(150, alpha))
                            drawRect(5, curY - 5, 400, 42)
                            setColor(30, 30, 30, alpha)
                        else
                            setColor(230, 230, 230, alpha)
                        end

                        drawText(curText, 205 - measure(curText) / 2, curY, 1)
                        curY = curY + 42
                        count = count + 1
                    end
                end

                if timer > 0 then
                    curText = 'COOLDOWN: ' .. tostring(timer) .. 's'
                    setFont(FONT_RECOLOR_HUD)
                    setColor(5, 66, 152, 200)
                    drawText(curText, 205 - measure(curText) * 1.5 / 2, screenHeight() / 2 - 27, 1.5)
                end
            end
        else
            local text = 'LEAVING IN ' .. tostring(timer) .. 's'
            setFont(FONT_RECOLOR_HUD)
            setColor(255, 3, 3, 200)
            drawText(text, 5, screenHeight() / 2 - 36, 2)
        end
    end
end

hookEvent(HOOK_ON_HUD_RENDER, on_hud_render)

if network_is_server() then
    hookMMInput('Control Seconds [5-60]', '20', 8, function (_, val)
        globalTable.controlStartTimer = clamp(ceil(tonumber(val) or 20), 5, 60) * 30
    end)
    hookMMInput('Cooldown Seconds [0-30]', '10', 8, function (_, val)
        globalTable.controlStartCooldown = clamp(ceil(tonumber(val) or 10), 0, 30) * 30
    end)
end
