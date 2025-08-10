local networkIsServer = network_is_server
local hookMMCheck = hook_mod_menu_checkbox
local hookMMInput = hook_mod_menu_inputbox
local drawRect = djui_hud_render_rect
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
local ceil = math.ceil
local floor = math.floor
local clamp = clampf

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

showMobControls = true
showPowers = true

local MOB_NAMES = {
    [id_bhvCustomBalconyBigBoo] = "Big Boo",
    [id_bhvCustomBigBully] = "Big Bully",
    [id_bhvCustomBigBullyWithMinions] = "Big Bully",
    [id_bhvCustomBigChillBully] = "Big Chill Bully",
    [id_bhvCustomBobomb] = "Bob-Omb",
    [id_bhvCustomBoo] = "Boo",
    [id_bhvCustomBooWithCage] = "Boo With Cage",
    [id_bhvCustomBowser] = "Bowser",
    [id_bhvCustomChainChomp] = "Chain Chomp",
    [id_bhvCustomChuckya] = "Chuckya",
    [id_bhvCustomEnemyLakitu] = "Lakitu",
    [id_bhvCustomFlyGuy] = "Fly Guy",
    [id_bhvCustomGhostHuntBigBoo] = "Big Boo",
    [id_bhvCustomGhostHuntBoo] = "Boo",
    [id_bhvCustomGoomba] = "Goomba",
    [id_bhvCustomKingBobomb] = "King Bob-Omb",
    [id_bhvCustomKoopa] = "Koopa",
    [id_bhvCustomMadPiano] = "Mad Piano",
    [id_bhvCustomMerryGoRoundBigBoo] = "Big Boo",
    [id_bhvCustomMerryGoRoundBoo] = "Boo",
    [id_bhvCustomScuttlebug] = "Scuttlebug",
    [id_bhvCustomSkeeter] = "Skeeter",
    [id_bhvCustomSmallBully] = "Bully",
    [id_bhvCustomSmallChillBully] = "Chill Bully",
    [id_bhvCustomSmallPenguin] = "Lil' Penguin",
    [id_bhvCustomSmallWhomp] = "Whomp",
    [id_bhvCustomSpindrift] = "Spindrift",
    [id_bhvCustomSpiny] = "Spiny",
    [id_bhvCustomToadMessage] = "Toad",
    [id_bhvCustomUkiki] = "Ukiki",
    [id_bhvCustomWhompKingBoss] = "King Whomp",
    [id_bhvCustomWigglerHead] = "Wiggler"
}

local MOB_CONTROLS = {
    [id_bhvCustomBalconyBigBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomBigBully] = {
        "B - Charge"
    },
    [id_bhvCustomBigBullyWithMinions] = {
        "B - Charge"
    },
    [id_bhvCustomBigChillBully] = {
        "B - Charge"
    },
    [id_bhvCustomBobomb] = {
        "B - Lit Bomb"
    },
    [id_bhvCustomBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomBooWithCage] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomBowser] = {
        {
            "A - Jump",
            "B - Flame Thrower",
            "Z - Swipe Claws (Taunt)"
        },
        {
            "A - Jump (Move Floor)",
            "B - Rush",
            "Z - Teleport",
            "D-PAD DOWN - Single Fireball"
        },
        {
            "A - Jump (Shockwaves)",
            "B - Rush",
            "Z - Swipe Claws (Taunt)",
            "D-PAD UP - Fire Rain",
            "D-PAD DOWN - Single Fireball",
            "D-PAD RIGHT - Flame Thrower"
        }
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
    [id_bhvCustomGhostHuntBigBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomGhostHuntBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomGoomba] = {
        "A - Jump",
        "B - Run"
    },
    [id_bhvCustomKingBobomb] = {
        "(Touch A Player To Grab)",
        "Spam B (While Holding A Player) - Throw"
    },
    [id_bhvCustomKoopa] = {
        "B - Run (With Shell)",
        "B - Dive (Without Shell)",
        "(Dive To An Empty Shell To Equip It)"
    },
    [id_bhvCustomMadPiano] = {
        "B - RUN & KILL'EM ALL"
    },
    [id_bhvCustomMerryGoRoundBigBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
    },
    [id_bhvCustomMerryGoRoundBoo] = {
        "A - Ascend",
        "Z - Descend",
        "Hold B - Vanish"
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
    [id_bhvCustomSmallChillBully] = {
        "B - Charge"
    },
    [id_bhvCustomSmallPenguin] = {
        "B - Run For Ur Life!"
    },
    [id_bhvCustomSmallWhomp] = {
        "B - Walk Faster",
        "Z - Pound"
    },
    [id_bhvCustomSpindrift] = {
        "Not much to do here..."
    },
    [id_bhvCustomSpiny] = {
        "Really?"
    },
    [id_bhvCustomToadMessage] = {
        "A - Jump"
    },
    [id_bhvCustomUkiki] = {
        "A - Jump"
    },
    [id_bhvCustomWhompKingBoss] = {
        "B - Walk Faster",
        "Z - Pound"
    },
    [id_bhvCustomWigglerHead] = {
        "A - Jump"
    }
}

local POWERS_TEXTS = {
    "D-PAD LEFT: Tweester",
    "D-PAD RIGHT: Electro-Shock",
    "D-PAD UP: Vertical Wind",
    "D-PAD DOWN: Stuck Butt"
}

--adapting nametags_render from nametags.c to avoid visual bugs
---@param playerIdx integer
function common_render_mob_nametag(playerIdx)

    local np = nps[playerIdx]
    local m = states[playerIdx]

    if (playerIdx == 0 and not gNametagsSettings.showSelfTag) or
    not is_player_active(m) or
    not nps[playerIdx].currAreaSyncValid or
    m.usedObj == nil or
    playerTable[playerIdx].controlledBhvId == -1 or
	(m.action == ACT_CONTROLLING_MOB and not globalTable.allowNametagsInMobs) or
    find_object_with_behavior(get_behavior_from_id(id_bhvActSelector)) ~= nil then return end
    
    local o = m.usedObj
    local mobPos = {x = o.oPosX, y = o.oPosY - o.hitboxDownOffset + o.hitboxHeight + 100, z = o.oPosZ}
    local tagPos = {x = 0, y = 0, z = 0}

    if djui_hud_world_pos_to_screen_pos(mobPos, tagPos) then

        local text = stringWithoutHex(np.name)

        local scale = -400 / tagPos.z * djui_hud_get_fov_coeff()
        local offset = scale * 2
        
        local wdth = measure(text) * scale / 2

        tagPos.x = tagPos.x - wdth
        tagPos.y = tagPos.y - 16 * scale

        local color = colorHexToRGB(network_get_player_text_color_string(playerIdx))

        setColor(color.r * 0.25, color.g * 0.25, color.b * 0.25, 255)
        drawText(text, tagPos.x - offset, tagPos.y, scale)
        drawText(text, tagPos.x + offset, tagPos.y, scale)
        drawText(text, tagPos.x, tagPos.y - offset, scale)
        drawText(text, tagPos.x, tagPos.y + offset, scale)

        setColor(color.r, color.g, color.b, 255)
        drawText(text, tagPos.x, tagPos.y, scale)
    end
end

function renderControlPrompt()
    if nearMobDetected then
        setColor(200, 0, 0, 240)
        local text = "Press X to control "
        if MOB_NAMES[nearMobBhvId] then
            text = text .. MOB_NAMES[nearMobBhvId]
        else
            text = text .. "?"
        end
        drawText(text, 5, screenHght() - 69, 2)
    end
end

function renderPowersControls()

    if globalTable.allowPowers and showPowers then
        setColor(25, 25, 25, 150)
        local hght = 10 + 32 * #POWERS_TEXTS + 10 * (#POWERS_TEXTS - 1)
        local curY = screenHght() / 2 - hght / 2
        drawRect(5, curY, 310, hght)

        setFont(FONT_CUSTOM_HUD)
        resetColor()
        local text = "POWERS"
        drawText(text, 160 - measure(text), curY - 48, 2)
        setFont(FONT_NORMAL)

        curY = curY + 5
        local seconds = ceil(playerTable[0].powersCooldown / 30)

        if seconds > 0 then 
            setColor(100, 100, 100, 160)
        else
            setColor(240, 240, 240, 200)
        end

        for i = 1, #POWERS_TEXTS do
            text = POWERS_TEXTS[i]
            drawText(text, 160 - measure(text) / 2, curY, 1)
            curY = curY + 42
        end

        if seconds > 0 then
            setColor(95, 223, 242, 240)
            text = "COOLDOWN: " .. seconds .. "s"
            drawText(text, 160 - measure(text) * 1.5 / 2, screenHght() / 2 - 32 * 1.5 / 2, 1.5)
        end
    end

end

function renderMobControls()

    if showMobControls then
        local bhv = playerTable[0].controlledBhvId
        local text = "Press X to stop controlling "
        if MOB_NAMES[bhv] then
            text = text .. MOB_NAMES[bhv]
        else
            text = text .. "?"
        end
        setColor(200, 0, 0, 240)
        drawText(text, 5, screenHght() - 69, 2)

        local controls = MOB_CONTROLS[bhv]
        if controls and #controls > 0 then

            if bhv == id_bhvCustomBowser then
                if nps[0].currLevelNum == LEVEL_BOWSER_2 then
                    controls = controls[2]
                elseif nps[0].currLevelNum == LEVEL_BOWSER_3 then
                    controls = controls[3]
                else
                    controls = controls[1]
                end
            end

            local lineCount = #controls

            local hght = 10 + ((lineCount - 1) * 10) + (lineCount * 32)
            local curY = screenHght() / 2 - hght / 2
            local x = screenWdth() - 405
            local center = x + 200
            setColor(45, 45, 45, 150)
            drawRect(x, curY, 400, hght)

            setFont(FONT_CUSTOM_HUD)
            resetColor()
            text = "CONTROLS"
            drawText(text, center - measure(text), curY - 48, 2)
            setFont(FONT_NORMAL)

            curY = curY + 5
            setColor(240, 240, 240, 200)
            for i = 1, lineCount do
                text = controls[i]
                drawText(text, center - measure(text) / 2, curY, 1)
                curY = curY + 42
            end
        end
    end

end

function on_hud_render()

	if gServerSettings.nametags == 1 and globalTable.allowNametagsInMobs and not cnOn then
        djui_hud_set_resolution(RESOLUTION_N64)
        for i = 0, MAX_PLAYERS - 1 do
            common_render_mob_nametag(i)
        end
        djui_hud_set_resolution(RESOLUTION_DJUI)
    end

    if playerTable[0].controlledBhvId == -1 then

        if not mhExists or not globalTable.mhControlOnlyForHunters or getMHTeam(0) == 0 then
            renderControlPrompt()
        end
        if not mhExists or not globalTable.mhPowersOnlyForHunters or getMHTeam(0) == 0 then
            renderPowersControls()
        end
    else
        renderMobControls()
    end
end

hookEvent(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)

--#region Mod Menu -----------------------------------------------------------------------------------------------------------------------------
hookMMCheck("Show Mob Controls", true, function (_, val)
    showMobControls = val
end)
hookMMCheck("Show Powers (If Enabled)", true, function (_, val)
    showPowers = val
end)
if networkIsServer() then
	hookMMCheck("Allow Nametags In Mobs", true, function (_, val)
        globalTable.allowNametagsInMobs = val
    end)
    hookMMCheck("Allow Powers", true, function (_, val)
        globalTable.allowPowers = val
    end)
    hookMMInput("Powers Cooldown (Seconds)[5-60]", "10", 8, function (_, val)
        globalTable.powersCooldownStart = clamp(floor(tonumber(val) or 10), 5, 60) * 30
    end)
    hookMMInput("Powers Range[800-5000]", "1500", 8, function (_, val)
        globalTable.powersRange = clamp(tonumber(val) or 1500, 800, 5000)
    end)
    hookMMInput("Control Range[500-2000]", "800", 8, function (_, val)
        globalTable.controlRange = clamp(tonumber(val) or 800, 500, 2000)
    end)
    if mhExists then
        hookMMCheck("(MH) Only Hunters Can Control Mobs", true, function (_, val)
            globalTable.mhControlOnlyForHunters = val
        end)
        hookMMCheck("(MH) Only Hunters Can Use Powers", true, function (_, val)
            globalTable.mhPowersOnlyForHunters = val
        end)
        hookMMCheck("(MH) Hunters Only Attack With Mobs", false, function (_, val)
            globalTable.mhHunterOnlyAttackWithMobs = val
        end)
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------