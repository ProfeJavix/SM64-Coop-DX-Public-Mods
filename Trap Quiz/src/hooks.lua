--#region Localizations ---------------------------------------------------------------------

local abs = math.abs
local abs_angle_diff = abs_angle_diff
local atan2s = atan2s
local clamp = math.clamp
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_get_screen_width = djui_hud_get_screen_width
local djui_hud_measure_text = djui_hud_measure_text
local djui_hud_print_text = djui_hud_print_text
local djui_hud_render_rect = djui_hud_render_rect
local djui_hud_reset_color = djui_hud_reset_color
local djui_hud_set_color = djui_hud_set_color
local djui_hud_set_font = djui_hud_set_font
local get_id_from_behavior = get_id_from_behavior
local hud_get_value = hud_get_value
local hud_set_value = hud_set_value
local ipairs = ipairs
local is_game_paused = is_game_paused
local network_is_server = network_is_server
local network_player_connected_count = network_player_connected_count
local object_pos_to_vec3f = object_pos_to_vec3f
local play_sound = play_sound
local set_mario_action = set_mario_action
local vec3s_to_vec3f = vec3s_to_vec3f
local warp_to_level = warp_to_level

--#endregion --------------------------------------------------------------------------------

local hooks = {}

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

local showContestantSelect = false
local hudContestantFocus = 0
local selContestant = {[0] = {sel = 1, increment = 0}, [1] = {sel = 1, increment = 0}}

---@param m MarioState
function hooks.mario_update(m)

    m.health = 0x880
    m.peakHeight = m.pos.y

    if nps[m.playerIndex].globalIndex == 0 and
    m.wall and m.wall.object and
    get_id_from_behavior(m.wall.object.behavior) == id_bhvButton then
        local btn = m.wall.object
        local wallAngleDiff = abs_angle_diff(m.faceAngle.y, atan2s(m.wall.normal.z, m.wall.normal.x))

        if m.action & ACT_FLAG_ATTACKING ~= 0 and btn.oAction == 1 and wallAngleDiff >= 0x6000 then
            btn.oAction = 2
            play_sound(SOUND_GENERAL_WALL_EXPLOSION, m.pos)
            set_mario_particle_flags(m, PARTICLE_VERTICAL_STAR, 0)
        end
    end

    if m.playerIndex ~= 0 then return end

    if m.action ~= ACT_SPECTATING and m.action ~= ACT_SINK_IN_LAVA and
    m.floor and m.floor.type == SURFACE_QUIZ_DEATH and m.pos.y == m.floorHeight then
        set_mario_action(m, ACT_SINK_IN_LAVA, 0)
    end

    if nps[0].currLevelNum ~= LEVEL_QUIZ_ROOM then
        warp_to_level(LEVEL_QUIZ_ROOM, 1, 0)
    end

    if network_player_connected_count() <= 2 then
        showContestantSelect = false
        globalTable.contestantA = -1
        globalTable.contestantB = -1
    end

    if globalTable.contestantA ~= -1 and globalTable.contestantB ~= -1 then

        if playerTable[0].inContestantSpot then
            m.wallKickTimer = 0
            return
        end

        local spot = getContestantSpot(0)
        if spot then
            object_pos_to_vec3f(m.pos, spot)
            playerTable[0].inContestantSpot = true
        end

    else
        if playerTable[0].inContestantSpot then
            vec3s_to_vec3f(m.pos, m.spawnInfo.startPos)
            playerTable[0].inContestantSpot = false
        end

        if not network_is_server() or network_player_connected_count() <= 2 then return end

        if m.controller.buttonPressed & X_BUTTON ~= 0 then
            showContestantSelect = not showContestantSelect
            play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
        end

        if showContestantSelect then
            if m.controller.buttonPressed & (L_JPAD | R_JPAD) ~= 0 then

                hudContestantFocus = abs(hudContestantFocus - 1)
                play_sound(SOUND_MENU_CLICK_FILE_SELECT, gGlobalSoundSource)

            elseif m.controller.buttonPressed & (U_JPAD | D_JPAD) ~= 0 then

                selContestant[hudContestantFocus].increment = ternary(m.controller.buttonPressed & U_JPAD ~= 0, -1, 1)
                play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)

            elseif m.controller.buttonPressed & Y_BUTTON ~= 0 then

                local sel = getNonHostAndNotSelPlayers()[hudContestantFocus][(selContestant[hudContestantFocus].sel)]
                local cTarget = getTargetContestant(hudContestantFocus)

                if globalTable[cTarget] == nps[sel].globalIndex then
                    globalTable[cTarget] = -1
                    play_sound(SOUND_MENU_CAMERA_ZOOM_OUT, gGlobalSoundSource)
                else
                    globalTable[cTarget] = nps[sel].globalIndex
                    play_sound(SOUND_MENU_STAR_SOUND, gGlobalSoundSource)
                end
            end
        end
    end
end

---@param m MarioState
function hooks.before_set_mario_action(m)
    if m.action == ACT_SPECTATING then
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
        m.flags = m.flags & ~MARIO_VANISH_CAP
    end
end

---@param idx integer
function hooks.on_nametags_render(idx)
    if states[idx].action == ACT_SPECTATING then
        return ''
    end
end

function hooks.on_hud_render()

    hud_set_value(
        HUD_DISPLAY_FLAGS,
        hud_get_value(HUD_DISPLAY_FLAGS) & ~(HUD_DISPLAY_FLAG_CAMERA | HUD_DISPLAY_FLAG_LIVES | HUD_DISPLAY_FLAG_STAR_COUNT)
    )

    if is_game_paused() then return end

    if states[0].action == ACT_SPECTATING then
        local text = 'SPECTATING'
        djui_hud_set_color(80, 80, 80, 255)
        djui_hud_print_text(text, (djui_hud_get_screen_width() / 2) - djui_hud_measure_text(text), (djui_hud_get_screen_height() / 2) - 32, 2)
        return
    end

    if network_is_server() and (globalTable.contestantA == -1 or globalTable.contestantB == -1) then
        if showContestantSelect then

            local players = getNonHostAndNotSelPlayers()

            if network_player_connected_count() <= 2 then return end

            local y = djui_hud_get_screen_height() / 2 - 74

            local x = {[0] = 5, [1] = djui_hud_get_screen_width() - 405}
            local xCenter = {[0] = x[0] + 200, [1] = x[1] + 200}

            local curY = {[0] = y - 32, [1] = y - 32}

            local text = {[0] = 'CONTESTANT A', [1] = 'CONTESTANT B'}

            for i = 0, 1 do
                djui_hud_set_color(40, 40, 40, 100)
                djui_hud_render_rect(x[i], y, 400, 136)

                djui_hud_reset_color()
                djui_hud_set_font(FONT_HUD)
                djui_hud_print_text(text[i], xCenter[i] - djui_hud_measure_text(text[i]), curY[i], 2)

                selContestant[i].sel = selContestant[i].sel + selContestant[i].increment
                if selContestant[i].sel < 1 then
                    selContestant[i].sel = #players[i]
                elseif selContestant[i].sel > #players[i] then
                    selContestant[i].sel = 1
                end
                selContestant[i].increment = 0
                selContestant[i].sel = clamp(selContestant[i].sel, 1, #players[i])

                djui_hud_set_font(FONT_NORMAL)
                curY[i] = curY[i] + 42
                for selIdx, idx in ipairs(players[i]) do
                    if selIdx >= selContestant[i].sel - 1 and selIdx <= selContestant[i].sel + 1 then
                        text[i] = stringWithoutHex(nps[idx].name)

                        if selIdx == selContestant[i].sel then
                            curY[i] = djui_hud_get_screen_height() / 2 - 16

                            if i == hudContestantFocus then
                                djui_hud_set_color(150, 150, 150, 150)
                                djui_hud_render_rect(x[i], curY[i] - 5, 400, 42)
                                djui_hud_set_color(30, 30, 30, 240)
                            else
                                djui_hud_set_color(230, 230, 230, 240)
                            end
                        else
                            djui_hud_set_color(230, 230, 230, 240)
                        end

                        if idx == getLocalFromGlobalIndex(globalTable.contestantA) or
                        idx == getLocalFromGlobalIndex(globalTable.contestantB) then
                            djui_hud_set_color(247, 236, 0, 240)
                        end

                        djui_hud_print_text(text[i], xCenter[i] - djui_hud_measure_text(text[i]) / 2, curY[i], 1)

                        curY[i] = curY[i] + 42
                    end
                end
            end
        else
            djui_hud_set_font(FONT_RECOLOR_HUD)
            djui_hud_set_color(67, 181, 255, 255)
            djui_hud_print_text('PRESS X TO SELECT THE CONTESTANTS', 5, djui_hud_get_screen_height() - 37, 2)
        end
    end
end

return hooks