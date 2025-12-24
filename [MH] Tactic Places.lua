-- name: [MH] Tactic Places v1.0
-- description: MH extension that allows a team to select one of many checkpoints from the Star Select screen of a level. Use D-PAD to select an option and select a star normally to start in the desired position.\n\nMade by \\#333\\Profe\\#ff0\\Javix

---@class _G
---@field mhExists? boolean
---@field mhApi? table

local find_object_with_behavior = find_object_with_behavior
local get_behavior_from_id = get_behavior_from_id
local play_sound = play_sound
local smlua_level_util_change_area = smlua_level_util_change_area
local vec3f_copy = vec3f_copy
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_set_color = djui_hud_set_color
local djui_hud_render_rect = djui_hud_render_rect
local djui_hud_set_font = djui_hud_set_font
local djui_hud_reset_color = djui_hud_reset_color
local djui_hud_print_text = djui_hud_print_text
local djui_hud_measure_text = djui_hud_measure_text
local hook_event = hook_event
local network_is_server = network_is_server
local hook_mod_menu_checkbox = hook_mod_menu_checkbox

if not _G.mhExists then return end

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable

globalTable.placesTeam = 0

local renderMenu = false
local levelNum = LEVEL_NONE
local placeSelection = 0

local targetLocation = nil
local isExiting = false

local LEVEL_PLACES = {
    [LEVEL_BOB] = {
        { text = 'Floating Island', area = 1, pos = { x = 4640, y = 3910, z = 1000 } },
        { text = 'Tunnel', area = 1, pos = { x = -2750, y = 410, z = -4440 } },
        { text = "King Bob-Omb's Arena", area = 1, pos = { x = 4640, y = 4870, z = -5400 } }
    },
    [LEVEL_WF] = {
        { text = 'Large Pole', area = 1, pos = { x = -2870, y = 3020, z = -255 } },
        { text = 'Near Metal Cap', area = 1, pos = { x = 2660, y = 1730, z = -3904 } }
    },
    [LEVEL_JRB] = {
        { text = 'Near Ship', area = 1, pos = { x = 3570, y = 2000, z = 5050 } },
        { text = 'Underwater Chests', area = 1, pos = { x = -1750, y = -2176, z = -1600 } }
    },
    [LEVEL_CCM] = {
        { text = "Tuxie's Mom", area = 1, pos = {x = 4300, y = -4210, z = 4770} },
        { text = 'Wall Kick Area', area = 1, pos = { x = 920, y = -4200, z = -3140 } },
        { text = "Race Penguin's Shack", area = 2, pos = { x = -6430, y = -4180, z = -7520 } }
    },
    [LEVEL_BBH] = {
        { text = 'Roof', area = 1, pos = { x = 680, y = 3710, z = 220 } },
        { text = 'Basement', area = 1, pos = { x = 1010, y = -2000, z = 1820 }}
    },
    [LEVEL_HMC] = {
        { text = 'Elevators Area', area = 1, pos = { x = 1090, y = 1700, z = 6870 } },
        { text = 'Above Falling Rocks', area = 1, pos = { x = -5160, y = 2700, z = -20 } },
        { text = "Dorrie's Cavern", area = 1, pos = { x = -860, y = -3890, z = 6200 } }
    },
    [LEVEL_LLL] = {
        { text = 'Bullies Arena', area = 1, pos = { x = 3800, y = 1200, z = -5600 } },
        { text = 'Volcano Ruins', area = 2, pos = { x = 2100, y = 4070, z = -1590 } },
    },
    [LEVEL_SSL] = {
        { text = 'Oasis', area = 1, pos = { x = -6500, y = 660, z = -5000 } },
        { text = 'Top of Pyramid', area = 2, pos = { x = -1350, y = 4380, z = 1260} }
    },
    [LEVEL_DDD] = {
        { text = 'Submarine Hangar', area = 2, pos = { x = 6210, y = 690, z = 4340 } }
    },
    [LEVEL_WDW] = {
        { text = 'Cannon', area = 1, pos = { x = -2700, y = 3750, z = 3010 } },
        { text = 'Town Top', area = 2, pos = { x = -770, y = 85, z = 1400} }
    },
    [LEVEL_SL] = {
        { text = "Snowman's Head", area = 1, pos = { x = -150, y = 5290, z = 150 } },
        { text = 'Near Shell', area = 1, pos = { x = -5920, y = 1600, z = 6050 } },
        { text = 'Igloo', area = 2, pos = { x = 90, y = 5, z = 2070 } }
    },
    [LEVEL_TTM] = {
        { text = 'Tall Tall Top', area = 1, pos = { x = 700, y = 3000, z = 580 } },
        { text = 'Slide End', area = 4, pos = { x = -7300, y = -1420, z = -4410 } }
    },
    [LEVEL_THI] = {
        { text = 'Huge Mountain Top', area = 1, pos = { x = 1260, y = 4760, z = -1600 } },
        { text = 'Tiny Mountain Top', area = 2, pos = { x = 30, y = 1500, z = -430 } },
        { text = 'Below Wiggler', area = 3, pos = { x = -1870, y = 1630, z = -1150 } }
    },
    [LEVEL_TTC] = {
        { text = "Above Amp's Pole", area = 1, pos = { x = -930, y = 0, z = 1720 } },
        { text = 'Below Big Twhomp', area = 1, pos = { x = 1560, y = 5670, z = 1550 } }
    },
    [LEVEL_RR] = {
        { text = "Fliying Ship", area = 1, pos = { x = 4600, y = 3000, z = -2300 } },
        { text = "Near Falling Platforms", area = 1, pos = { x = -5130, y = -1600, z = 6620 } },
        { text = "Big House Roof", area = 1, pos = { x = -4190, y = 6900, z = -5630 } }
    },
    [LEVEL_BITDW] = {
        { text = "Amp's Spike", area = 1, pos = { x = -4160, y = 1490, z = 150 } },
        { text = 'Near Bowser Pipe', area = 1, pos = { x = 5850, y = 3120, z = -20 } }
    },
    [LEVEL_BITFS] = {
        { text = 'Above Elevator', area = 1, pos = { x = 2550, y = 840, z = 320 } },
        { text = 'Near Falling Bridge', area = 1, pos = { x = 3710, y = 4660, z = 120 } },
    }
}

function update()

    if find_object_with_behavior(get_behavior_from_id(id_bhvActSelector)) ~= nil and _G.mhApi.getTeam(0) == globalTable.placesTeam then
        levelNum = nps[0].currLevelNum
    else
        levelNum = LEVEL_NONE
    end
    renderMenu = LEVEL_PLACES[levelNum] ~= nil

    local m = states[0]
    if renderMenu then
        if m.controller.buttonPressed & (U_JPAD | D_JPAD) ~= 0 then
            local increment = 0
            if m.controller.buttonPressed & U_JPAD ~= 0 then
                increment = increment - 1
            else
                increment = increment + 1
            end

            placeSelection = placeSelection + increment

            if placeSelection < 0 then
                placeSelection = #LEVEL_PLACES[levelNum]
            elseif placeSelection > #LEVEL_PLACES[levelNum] then
                placeSelection = 0
            end

            if placeSelection == 0 then
                targetLocation = nil
            else
                local targetInfo = LEVEL_PLACES[levelNum][placeSelection]
                targetLocation = { area = targetInfo.area, pos = targetInfo.pos, timer = 10 }
            end
            play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
        end
    else
        placeSelection = 0
    end
end

---@param m MarioState
function mario_update(m)
    if m.playerIndex ~= 0 then return end

    if nps[0].currActNum ~= 1 and (nps[0].currLevelNum == LEVEL_BITDW or nps[0].currLevelNum == LEVEL_BITFS) then
        warp_to_level(nps[0].currLevelNum, 1, 1)
    end

    if targetLocation ~= nil then
        if nps[0].currAreaIndex ~= targetLocation.area then

            if targetLocation.timer > 0 then
                targetLocation.timer = targetLocation.timer - 1
                return
            end

            smlua_level_util_change_area(targetLocation.area)
        end
        vec3f_copy(m.pos, targetLocation.pos)
        targetLocation = nil
    end
end

function on_hud_render()
    if renderMenu then
        local places = LEVEL_PLACES[levelNum]
        if not places then return end

        local hght = 20 + #places * 10 + (#places + 1) * 32
        local y = (djui_hud_get_screen_height() / 2) - (hght / 2)
        local text = 'LEVEL PLACES'

        djui_hud_set_color(50, 50, 50, 170)
        djui_hud_render_rect(5, y, 400, hght)

        djui_hud_set_font(FONT_HUD)
        djui_hud_reset_color()
        djui_hud_print_text(text, 205 - djui_hud_measure_text(text), y - 32, 2)

        djui_hud_set_font(FONT_NORMAL)
        y = y + 10

        for i = 0, #places do
            text = 'Spawn'
            if i > 0 then
                text = places[i].text or 'Unknown'
            end

            if i == placeSelection then
                djui_hud_set_color(180, 180, 180, 200)
                djui_hud_render_rect(5, y - 5, 400, 42)
                djui_hud_set_color(20, 20, 20, 200)
            else
                djui_hud_set_color(200, 200, 200, 200)
            end

            djui_hud_print_text(text, 205 - djui_hud_measure_text(text) / 2, y, 1)
            y = y + 42
        end
    elseif targetLocation then
        djui_hud_set_color(0, 0, 0, 255)
        djui_hud_render_rect(0, 0, djui_hud_get_screen_width(), djui_hud_get_screen_height())
    end
end

function on_pause_exit()
    isExiting = true
end

---@param lvl LevelNum
function on_use_act_select(lvl)

    local show = nil

    if lvl == LEVEL_BITDW or lvl == LEVEL_BITFS and _G.mhApi.getTeam(0) == globalTable.placesTeam then
        if not isExiting then
            show = true
        end
    end

    isExiting = false

    if show then
        return true
    end
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_HUD_RENDER, on_hud_render)
hook_event(HOOK_ON_PAUSE_EXIT, on_pause_exit)
hook_event(HOOK_USE_ACT_SELECT, on_use_act_select)

if network_is_server() then
    hook_mod_menu_checkbox('Places Team [OFF - RUNNERS | ON - HUNTERS]', true, function(_, val)
        globalTable.placesTeam = val and 0 or 1
    end)
end
