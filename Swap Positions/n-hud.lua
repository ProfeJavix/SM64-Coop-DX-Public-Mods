local network_is_server = network_is_server
local hookEvent = hook_event
local hookMMInput = hook_mod_menu_inputbox
local hookMMCheckbox = hook_mod_menu_checkbox
local setColor = djui_hud_set_color
local setFont = djui_hud_set_font
local drawText = djui_hud_print_text
local drawRect = djui_hud_render_rect
local measure = djui_hud_measure_text
local screenHeight = djui_hud_get_screen_height
local ceil = math.ceil
local min = math.min
local clamp = clampf

local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

selectedListPos = 1

---@param idx integer
---@param alpha integer
function setTeamColor(idx, alpha)
    local _, _, color = getRoleNameAndColor(idx)
    setColor(color.r, color.g, color.b, alpha)
end

function on_hud_render()

    if (mhExists and getTeam(0) == 0 and not globalTable.everyoneCanSwap) or states[0].action & ACT_GROUP_CUTSCENE ~= 0 or
    playerTable[0].warping or playerTable[0].targetedCooldown > 30 then return end

    local timer = ceil(swapCooldown / 30)

    local players = getSwappablePlayers()
    local alpha = ternary(timer > 0, 100, 200)

    if #players > 0 then
        local curY = screenHeight() / 2 - 68
        setColor(45, 45, 45, min(150, alpha))
        drawRect(5, curY, 300, 136)

        setFont(FONT_CUSTOM_HUD)
        setColor(255, 255, 255, alpha)
        local curText = "PLAYERS"
        drawText(curText, 155 - measure(curText), curY - 48, 2)
        setFont(FONT_NORMAL)

        curY = curY + 10
        local count = 0

        for i = 1, #players do
            if count > 2 then break end

            if i >= selectedListPos - 1 and i <= selectedListPos + 1 then
                curText = fitText(nameWithoutHex(players[i]), 300, 1)

                if i == selectedListPos then
                    curY = screenHeight() / 2 - 16
                    setColor(150, 150, 150, min(150, alpha))
                    drawRect(5, curY - 5, 300, 42)
                end

                setTeamColor(i, alpha)

                drawText(curText, 155 - measure(curText) / 2, curY, 1)
                curY = curY + 42
                count = count + 1
            end
        end

        setFont(FONT_RECOLOR_HUD)
        setColor(230, 0, 0, alpha)
        curText = "PRESS X TO SWAP"
        drawText(curText, 155 - measure(curText) * 1.5 / 2, screenHeight() / 2 + 55, 1.5)

        if timer > 0 then
            curText = 'COOLDOWN: ' .. tostring(timer) .. 's'
            setColor(5, 66, 152, 200)
            drawText(curText, 155 - measure(curText) * 1.5 / 2, screenHeight() / 2 - 27, 1.5)
        end

    end
end

hookEvent(HOOK_ON_HUD_RENDER, on_hud_render)

if network_is_server() then
    hookMMInput('Cooldown Seconds [0-60]', '10', 8, function(_, val)
        globalTable.startSwapCooldown = clamp(ceil(tonumber(val) or 10), 0, 30) * 30
    end)
    
    if mhExists then
        hookMMCheckbox('(MH) Allow Hunters To Swap', false, function (_, val)
            globalTable.everyoneCanSwap = val
        end)
        hookMMCheckbox('(MH) Allow Team Swap', false, function (_, val)
            globalTable.teamSwap = val
        end)
    end
end
