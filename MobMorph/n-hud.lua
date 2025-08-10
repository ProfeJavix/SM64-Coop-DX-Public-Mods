local networkIsServer = network_is_server
local hookMMCheck = hook_mod_menu_checkbox
local hookMMInput = hook_mod_menu_inputbox
local drawRect = djui_hud_render_rect
local drawTile = djui_hud_render_texture_tile
local drawText = djui_hud_print_text
local measure = djui_hud_measure_text
local setFont = djui_hud_set_font
local setColor = djui_hud_set_color
local resetColor = djui_hud_reset_color
local screenWdth = djui_hud_get_screen_width
local screenHght = djui_hud_get_screen_height
local djui_hud_get_fov_coeff = djui_hud_get_fov_coeff
local network_get_player_text_color_string = network_get_player_text_color_string
local hookEvent = hook_event
local find_object_with_behavior = find_object_with_behavior
local get_behavior_from_id = get_behavior_from_id
local clamp = clampf
local ceil = math.ceil
local floor = math.floor
local getTex = get_texture_info

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

--#region Draw Variables -----------------------------------------------------------------------------------------------------------------------
local curX = 0
local curY = 0
local curText = ""
local hudAlpha = 0
local listColor = { r = 0, g = 0, b = 0 }

--list rendering
local listItemsOnScreen = 0
local curItem = 1
local renderedItems = 0
local curItemsTotal = 0
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

showMobControls = true

local MOB_CONTROLS = {
    [id_bhvCustomBigBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomBigBully] = {
        "B - Charge"
    },
    [id_bhvCustomBobomb] = {
        "B - Go Faster",
        "Z - Detonate"
    },
    [id_bhvCustomBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomBowser] = {
        "A - Jump",
        "B - Rush",
        "Z - Teleport",
        "D-PAD UP - Fire Rain",
        "D-PAD DOWN - Single Fireball",
        "D-PAD RIGHT - Flame Thrower"
    },
    [id_bhvCustomChainChomp] = {
        "A - Jump",
        "B - Lunge"
    },
    [id_bhvCustomChuckya] = {
        "(Touch a Player To Grab and Throw)"
    },
    [id_bhvCustomEnemyLakitu] = {
        "A - Ascend",
        "Z - Descend",
        "B - Throw Spiny"
    },
    [id_bhvCustomFlyGuy] = {
        "A - Ascend",
        "Z - Descend",
        "B - Fly Faster",
        "D-PAD RIGHT - Spit Flame"
    },
    [id_bhvCustomGoomba] = {
        "A - Jump",
        "B - Run"
    },
    [id_bhvCustomKingBobomb] = {
        "A - Jump",
        "B - Walk Faster",
        "(Touch A Player To Grab)",
        "Spam Z (While Holding A Player) - Throw"
    },
    [id_bhvCustomKoopa] = {
        "B - Run (With Shell)",
        "B - Dive (Without Shell)",
        "(Dive To An Empty Shell To Equip It)"
    },
    [id_bhvCustomMadPiano] = {
        "A - MAD JUMP",
        "B - RUN & KILL'EM ALL"
    },
    [id_bhvCustomScuttlebug] = {
        "A - Jump",
        "B - Run"
    },
    [id_bhvCustomSkeeter] = {
        "B (On Ground) - Walk Faster",
        "B (On Water) - Lunge"
    },
    [id_bhvCustomSmallBully] = {
        "B - Charge"
    },
    [id_bhvCustomSmallPenguin] = {
        "B - Run & Kick Some Butts"
    },
    [id_bhvCustomSmallWhomp] = {
        "B - Walk Faster",
        "Z - Pound"
    },
    [id_bhvCustomSpindrift] = {
        "B - Hover Faster"
    },
    [id_bhvCustomToadMessage] = {
        "A - Jump"
    },
    [id_bhvCustomUkiki] = {
        "A - Jump",
        "B - Run"
    },
    [id_bhvCustomWhompKingBoss] = {
        "B - Walk Faster",
        "Z - Pound"
    },
    [id_bhvCustomWigglerHead] = {
        "A - Jump",
        "B - Run"
    }
}
local uiListTex = getTex("ui-list") --scale: 5

---@return string
function getMobName()
    local mobData = findMobDataBySelection()
    if mobData ~= nil then
        return mobData[2]
    end
    return "?"
end

---@return integer
function getOnScreenAmount()
    local total = getTotalMobs()
    return clamp(selectedMobPos - 1, 0, 2) + clamp(total - selectedMobPos, 0, 2)
end

--adapting nametags_render from nametags.c to avoid visual bugs
---@param playerIdx integer
function render_mob_nametag(playerIdx)

    local np = nps[playerIdx]
    local m = states[playerIdx]

    if (playerIdx == 0 and not gNametagsSettings.showSelfTag) or
    not playersInSameArea(0, playerIdx) or
    not is_player_active(m) or
    not nps[playerIdx].currAreaSyncValid or
    m.usedObj == nil or
    playerTable[playerIdx].morphedBhvId == -1 or
    (m.action == ACT_MORPHED and not globalTable.allowNametagsInMobs) or
    find_object_with_behavior(get_behavior_from_id(id_bhvActSelector)) ~= nil then return end

    local o = m.usedObj
    local mobPos = {x = o.oPosX, y = o.oPosY - o.hitboxDownOffset + o.hitboxHeight + 100, z = o.oPosZ}
    local tagPos = {x = 0, y = 0, z = 0}

    if djui_hud_world_pos_to_screen_pos(mobPos, tagPos) then

        curText = stringWithoutHex(np.name)

        local scale = -400 / tagPos.z * djui_hud_get_fov_coeff()
        local offset = scale * 2
        
        local wdth = measure(curText) * scale / 2

        tagPos.x = tagPos.x - wdth
        tagPos.y = tagPos.y - 16 * scale

        local color = colorHexToRGB(network_get_player_text_color_string(playerIdx))

        setColor(color.r * 0.25, color.g * 0.25, color.b * 0.25, 255)
        drawText(curText, tagPos.x - offset, tagPos.y, scale)
        drawText(curText, tagPos.x + offset, tagPos.y, scale)
        drawText(curText, tagPos.x, tagPos.y - offset, scale)
        drawText(curText, tagPos.x, tagPos.y + offset, scale)

        setColor(color.r, color.g, color.b, 255)
        drawText(curText, tagPos.x, tagPos.y, scale)
    end
end

---@param list table
function renderItemsInList(list)
    setColor(listColor.r, listColor.g, listColor.b, hudAlpha)

    local start = curItem - curItemsTotal
    curItemsTotal = curItemsTotal + #list

    for i = start, #list do
        if renderedItems > listItemsOnScreen then
            break
        end

        curText = list[i][2]
        curX = 5 + 125 - measure(curText) / 2

        if curItem == selectedMobPos then
            setColor(25, 25, 25, max(hudAlpha - 190, 0))
            drawRect(curX - 5, curY - 5, measure(curText) + 10, 42)
            setColor(listColor.r, listColor.g, listColor.b, hudAlpha)
        end

        drawText(curText, curX, curY, 1)

        curY = curY + 42
        renderedItems = renderedItems + 1
        curItem = curItem + 1
    end
end

function renderMorphSelection()
    curX = 5
    curY = screenHght() / 2 - 120
    hudAlpha = 240

    local cooldownSeconds = ceil(playerTable[0].morphCooldown / 30)
    if cooldownSeconds > 0 then
        hudAlpha = 50
    end

    setColor(255, 255, 255, hudAlpha)
    drawTile(uiListTex, curX, curY, 5, 5, 1, 1, 50, 48)

    setFont(FONT_RECOLOR_HUD)
    setColor(230, 50, 0, hudAlpha)
    curText = "MOBS"
    drawText(curText, curX + 125 - measure(curText), curY - 42, 2)
    setFont(FONT_NORMAL)

    curY = screenHght() / 2 - 16 - clamp(selectedMobPos - 1, 0, 2) * 42

    listItemsOnScreen = getOnScreenAmount()
    curItem = max(selectedMobPos - 2, 1)
    renderedItems = 0
    curItemsTotal = 0

    listColor = { r = 105, g = 105, b = 105 }
    renderItemsInList(ALLOWED_MOBS)

    if globalTable.allowBosses then
        listColor = { r = 205, g = 1, b = 1 }
        renderItemsInList(ALLOWED_BOSSES)
    end

    if globalTable.allowNpcs then
        listColor = { r = 153, g = 148, b = 44 }
        renderItemsInList(ALLOWED_NPCS)
    end

    if cooldownSeconds > 0 then
        setFont(FONT_RECOLOR_HUD)
        setColor(122, 85, 184, 240)
        curText = "COOLDOWN: " .. cooldownSeconds .. "s"
        drawText(curText, 130 - measure(curText) * 1.5 / 2, screenHght() / 2 - 32 * 1.5 / 2, 1.5)
        setFont(FONT_NORMAL)
    end
end

function renderMobHud()
    if showMobControls then
        local bhv = playerTable[0].morphedBhvId
        local mobName = getMobName()

        curText = "Press X to quit " .. mobName .. " form."
        setColor(200, 0, 0, 240)
        drawText(curText, 5, screenHght() - 69, 2)

        local controls = MOB_CONTROLS[bhv]
        if controls and #controls > 0 then

            local lineCount = #controls

            local hght = 10 + ((lineCount - 1) * 10) + (lineCount * 32)
            curY = screenHght() / 2 - hght / 2
            curX = screenWdth() - 405
            local center = curX + 200
            setColor(45, 45, 45, 150)
            drawRect(curX, curY, 400, hght)

            setFont(FONT_CUSTOM_HUD)
            resetColor()
            curText = "CONTROLS"
            drawText(curText, center - measure(curText), curY - 48, 2)
            setFont(FONT_NORMAL)

            curY = curY + 5
            setColor(240, 240, 240, 200)
            for i = 1, lineCount do
                curText = controls[i]
                drawText(curText, center - measure(curText) / 2, curY, 1)
                curY = curY + 42
            end
        end
    end

    if not globalTable.morphedCooldown then return end

    local leaveSeconds = ceil(playerTable[0].leaveMobCooldown / 30)
    if leaveSeconds > 0 then
        setFont(FONT_RECOLOR_HUD)
        setColor(255, 29, 0, 240)

        curText = "TIME TO LEAVE: " .. leaveSeconds .. "s"
        curX = 5
        curY = screenHght() / 2 - 36

        drawText(curText, curX, curY, 2)
        setFont(FONT_NORMAL)
    end
end

function on_hud_render()

    if gServerSettings.nametags == 1 and globalTable.allowNametagsInMobs and not cnOn then
        djui_hud_set_resolution(RESOLUTION_N64)
        for i = 0, MAX_PLAYERS - 1 do
            render_mob_nametag(i)
        end
        djui_hud_set_resolution(RESOLUTION_DJUI)
    end

    if playerTable[0].morphedBhvId == -1 then
        if not mhExists or not globalTable.mhMorphOnlyForHunters or getMHTeam(0) == 0 then
            renderMorphSelection()
        end
    else
        renderMobHud()
    end
end

hookEvent(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)

--#region Mod Menu -----------------------------------------------------------------------------------------------------------------------------
hookMMCheck("Show Mob Controls", true, function(_, val)
    showMobControls = val
end)
if networkIsServer() then
    hookMMInput("Morph Seconds [0-60]", "10", 8, function(_, val)
        globalTable.startingMorphCooldown = clamp(floor(tonumber(val) or 10), 0, 60) * 30
    end)
    hookMMCheck("Allow Nametags In Mobs", true, function (_, val)
        globalTable.allowNametagsInMobs = val
    end)
    hookMMCheck("Allow Boss Morphing", true, function(_, val)
        globalTable.allowBosses = val
    end)
    hookMMCheck("Allow NPC Morphing", true, function(_, val)
        globalTable.allowNpcs = val
    end)
    hookMMCheck("Enable Morphed Cooldown", true, function (_, val)
        globalTable.morphedCooldown = val
    end)
    if mhExists then
        hookMMCheck("(MH) Only Hunters Can Morph", true, function(_, val)
            globalTable.mhMorphOnlyForHunters = val
        end)
        hookMMCheck("(MH) Hunters Can Only Attack With Mobs", false, function(_, val)
            globalTable.mhHunterOnlyAttackWithMobs = val
        end)
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------
