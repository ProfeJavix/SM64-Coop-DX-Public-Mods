local network_is_server = network_is_server
local hookEvent = hook_event
local hookMMInput = hook_mod_menu_inputbox
local hookMMCheckbox = hook_mod_menu_checkbox
local getTex = get_texture_info
local drawTexture = djui_hud_render_texture
local drawTextureInterpolated = djui_hud_render_texture_interpolated
local setColor = djui_hud_set_color
local resetColor = djui_hud_reset_color
local drawText = djui_hud_print_text
local drawRect = djui_hud_render_rect_interpolated
local getWorldPos = djui_hud_world_pos_to_screen_pos
local screenHeight = djui_hud_get_screen_height
local measure = djui_hud_measure_text
local ceil = math.ceil
local tonumber = tonumber
local min = minf
local abs = absf_2
local clamp = clamp
local tostring = tostring
local play_sound = play_sound
local is_game_paused = is_game_paused
local update_mod_menu_element_inputbox = update_mod_menu_element_inputbox
local mod_storage_save_number = mod_storage_save_number
local mod_storage_save_bool = mod_storage_save_bool
local globalPopup = djui_popup_create_global

local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

local crosshairTex = getTex('crosshair')
local reloadTex = getTex('shells')
local chPrevX = nil
local chPrevY = nil
local chargePrevWdth = 0
local curChargeColor = 0 --0: white | 1: red

local reloadCurAlpha = 240
local reloadFading = true

function adjustReloadAlpha()
    local inc = ternary(reloadFading, -10, 10)
    reloadCurAlpha = reloadCurAlpha + inc
    if reloadCurAlpha < 0 then
        reloadFading = false
        reloadCurAlpha = 0
    elseif reloadCurAlpha > 240 then
        reloadFading = true
        reloadCurAlpha = 240
    end
    setColor(255,255,255, reloadCurAlpha)
end


function on_hud_render()

    local sgObj = shotgunObjs[0]
    if not sgObj or is_game_paused() then return end

    local seconds = ceil(reloadTimer / 30)
    if seconds > 0 then
        local wdth = 48
        local text = seconds .. 's'
        local curY = screenHeight() - 37
        setColor(0,0,0,240)
        drawText(text, 5 + wdth / 2 - measure(text) / 2, curY, 1)

        adjustReloadAlpha()
        curY = curY - wdth
        drawTexture(reloadTex, 5, curY, 1.5, 1.5)
        resetColor()
    else
        reloadCurAlpha = 240
        reloadFading = true
    end

    local m = states[0]
    
    if reloadTimer > 0 or m.action & ACT_FLAG_SG_NOT_ALLOWED ~= 0 or SG_ACTIONS[m.action] then return end

    local chPos = {x = 0, y = 0, z = 0}
    local sgPos = getSGPos(sgObj, 500)

    if not getWorldPos(sgPos, chPos) then return end

    chPos.x = chPos.x - 24
    chPos.y = chPos.y - 24

    chPrevX = chPrevX or chPos.x
    chPrevY = chPrevY or chPos.y

    drawTextureInterpolated(crosshairTex, chPrevX, chPrevY, 1.5, 1.5, chPos.x, chPos.y, 1.5, 1.5)

    if isHoldingShootButton then

        local holdProgress = playerTable[0].holdingYTimer / globalTable.boostShootTimer

        local wdth = lerp(0, 48 , min(holdProgress, 1))

        if holdProgress >= 1 then
            if playerTable[0].holdingYTimer % 10 == 0 then
                curChargeColor = abs(curChargeColor - 1)

                if curChargeColor == 1 then
                    play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
                end
            end
        else
            curChargeColor = 0
        end

        if curChargeColor == 0 then
            resetColor()
        else
            setColor(240, 0, 0, 255)
        end

        drawRect(chPrevX, chPrevY + 48, chargePrevWdth, 10, chPos.x, chPos.y + 48, wdth, 10)
        chargePrevWdth = wdth
    else
        chargePrevWdth = 0
    end

    chPrevX = chPos.x
    chPrevY = chPos.y
end

hookEvent(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)

if network_is_server() then
    hookMMInput('Reload Seconds [0-10]', tostring(globalTable.reloadStartTimer / 30), 8, function (idx, val)
        globalTable.reloadStartTimer = clamp(ceil(tonumber(val) or 5), 0, 10) * 30
        mod_storage_save_number('sgReloadTimer', globalTable.reloadStartTimer)
        update_mod_menu_element_inputbox(idx, tostring(globalTable.reloadStartTimer / 30))
    end)
    hookMMInput('Boost Shoot Seconds [1-10]', tostring(globalTable.boostShootTimer / 30), 8, function (idx, val)
        globalTable.boostShootTimer = clamp(ceil(tonumber(val) or 3), 1, 10) * 30
        mod_storage_save_number('sgBoostShootTimer', globalTable.boostShootTimer)
        update_mod_menu_element_inputbox(idx, tostring(globalTable.boostShootTimer / 30))
    end)
    hookMMCheckbox("Shotgun Damages Mobs", globalTable.sgDamagesMobs, function (_, val)
        globalTable.sgDamagesMobs = val
        mod_storage_save_bool('sgDamagesMobs', globalTable.sgDamagesMobs)
        if val then
            globalPopup('Now mobs can be shot.', 1)
        else
            globalPopup('Now mobs cannot be shot.', 1)
        end
    end)
    hookMMCheckbox('Allow Flying Glitch', globalTable.allowFlyingGlitch, function (_, val)
        globalTable.allowFlyingGlitch = val
        mod_storage_save_bool('allowFlyingGlitch', globalTable.allowFlyingGlitch)
    end)
end