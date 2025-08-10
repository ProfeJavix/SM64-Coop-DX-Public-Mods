-- name: Super Chained Bros v1.4.2
-- description: This mod adds mechanics consisting of chaining players together to limit their movements and they have to cooperate when doing parkour.\nAuthor: ProfeJavix
-- pausable: false

-- #region Localize Functions ------------------------------------------------------------------------------------------------------------------
local tableInsert, networkIsServer, hookChatCommand, hookEvent, hookBhv, hookMMButton, hookMMInput, hookMMCheckbox, network_player_connected_count, delObj, set_mario_action, allocate_mario_action, set_character_animation, chatMsg, popup, spawnObj, vec3f_dist, vec3f_dif, vec3f_dot, vec3f_normalize, vec3f_mul, vec3f_copy, vec3f_add, min, abs, approach_f32_asymptotic, djui_hud_set_color, djui_hud_get_screen_width, djui_hud_get_screen_height, djui_hud_print_text, djui_hud_measure_text, warp_to_level, hud_is_hidden, hud_hide, hud_show, playerActive =
    table.insert, network_is_server, hook_chat_command, hook_event, hook_behavior, hook_mod_menu_button, hook_mod_menu_inputbox,
    hook_mod_menu_checkbox, network_player_connected_count, obj_mark_for_deletion, set_mario_action, allocate_mario_action,
    set_character_animation, djui_chat_message_create, djui_popup_create,
    spawn_non_sync_object, vec3f_dist, vec3f_dif, vec3f_dot, vec3f_normalize, vec3f_mul, vec3f_copy, vec3f_add, math.min,
    math.abs, approach_f32_asymptotic, djui_hud_set_color, djui_hud_get_screen_width, djui_hud_get_screen_height,
    djui_hud_print_text, djui_hud_measure_text, warp_to_level, hud_is_hidden, hud_hide, hud_show, is_player_active
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Constants ----------------------------------------------------------------------------------------------------------------------------
local PART_SPACING = 50
local PLAYER_Y_POS = 50
local CHAIN_KB = 10
local SPECT_TEXT = "Press L Button to exit Spectator Mode"
local ACT_SPECTATE = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)

local actionWeights = {
    --[ACT_SHOT_FROM_CANNON] = 4294967295,
    --[ACT_CRAZY_BOX_BOUNCE] = 4294967295,
    [ACT_BUBBLED] = 0.25,
    [ACT_GROUND_POUND] = 3.5,
    [ACT_THROWN_BACKWARD] = 6,
    [ACT_THROWN_FORWARD] = 6,
    [ACT_WATER_IDLE] = 0.8,
    [ACT_FLYING] = 5,
    [ACT_SLEEPING] = 0,
    [ACT_RIDING_SHELL_GROUND] = 5,
    [ACT_RIDING_SHELL_JUMP] = 4,
    [ACT_RIDING_SHELL_FALL] = 4,
    [ACT_GETTING_BLOWN] = 8,
    [ACT_WATER_PUNCH] = 3,
    [ACT_PUNCHING] = 3,
}
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Globals ------------------------------------------------------------------------------------------------------------------------------
if networkIsServer() then
    gGlobalSyncTable.forceChain = false
    gGlobalSyncTable.enableLeaders = true
    gGlobalSyncTable.groupCount = 1
    gGlobalSyncTable.maxGroupCount = 3
    gGlobalSyncTable.maxDistFromCenter = 350
    gGlobalSyncTable.recoveryJumpHeight = 50
    gGlobalSyncTable.weightEnabled = false
    gGlobalSyncTable.rubberBandingSlack = 100
    gGlobalSyncTable.minPullMultiplier = 0.1 -- The minimum pull back force when the player is barely at the max distance
    gGlobalSyncTable.maxPullMultiplier = 1   -- The maximum pull back force when the player is far from the max distance
end

gPlayerSyncTable[0].chained = false
gPlayerSyncTable[0].group = -1
gPlayerSyncTable[0].ignoreTimer = 0
gPlayerSyncTable[0].isLeader = false
gPlayerSyncTable[0].prevLeader = -1
gPlayerSyncTable[0].warpToLeader = false
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Variables ----------------------------------------------------------------------------------------------------------------------------
local gettingUp = false
local renderingSpectatingMsg = false
local spectating = false
local chainCenter = { x = 0, y = 0, z = 0 } ---@type Vec3f
local visualCenters = {} ---@type Vec3f[]
local allowWarps = true
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Utilities ----------------------------------------------------------------------------------------------------------------------------
---@param mPos Vec3f
---@param center Vec3f
---@return Vec3f
function getDirToCenter(mPos, center)
    local mag = math.sqrt((mPos.x - center.x) ^ 2 + (mPos.y - center.y) ^ 2 + (mPos.z - center.z) ^ 2)
    return {
        x = (mPos.x - center.x) / mag,
        y = (mPos.y - center.y) / mag,
        z = (mPos.z - center.z) / mag
    }
end

---@param mPos Vec3f
---@param velocity Vec3f
---@return boolean
function isMarioMovingAway(mPos, velocity)
    local betVect = {
        x = chainCenter.x - mPos.x,
        y = chainCenter.y - mPos.y,
        z = chainCenter.z - mPos.z
    }
    return vec3f_dot(betVect, velocity) < 0
end

---@param m MarioState
---@return boolean
function isPlayerIgnoredForChainRender(m)
    local np = gNetworkPlayers[m.playerIndex]
    local ignore = m.action == ACT_SPECTATE or m.action & ACT_GROUP_MASK == ACT_GROUP_CUTSCENE or m.action == ACT_UNINITIALIZED or m.action == ACT_DISAPPEARED
    return ignore
end

---@param m MarioState
---@return boolean
function isPlayerIgnored(m)
    local np = gNetworkPlayers[m.playerIndex]
    local ignore = (not np.currLevelSyncValid or not np.currAreaSyncValid) and
                    m.action == ACT_SPECTATE or m.action & ACT_GROUP_MASK == ACT_GROUP_CUTSCENE or m.action == ACT_UNINITIALIZED or m.action == ACT_DISAPPEARED or
                    gPlayerSyncTable[m.playerIndex].ignoreTimer < 60
    return ignore
end

---@param val number
---@param minVal number
---@param maxVal number
---@return number
function lua_clamp(val, minVal, maxVal)
    if val < minVal then return minVal end
    if val > maxVal then return maxVal end
    return val
end

---@param name string
---@return string
function strip_colors(name)
    local string = ''
    local inSlash = false
    for i = 1, #name do
        local character = name:sub(i,i)
        if character == '\\' then
            inSlash = not inSlash
        elseif not inSlash then
            string = string .. character
        end
    end
    return string
end

function readjustGroups()
    local gpPlayers = {}
    local notFound = false
    for i = 0, (gGlobalSyncTable.groupCount - 1) do
        gpPlayers = getGpPlayers(i)
        notFound = (#gpPlayers == 0 or notFound)
        for _, playerIdx in ipairs(gpPlayers) do
            if notFound then
                gPlayerSyncTable[playerIdx].group = gPlayerSyncTable[playerIdx].group - 1
            end
        end
    end
end

---@param gp integer
---@return integer
function getGroupLeader(gp)
    local gpPlayers = getGpPlayers(gp)
    for _, idx in ipairs(gpPlayers) do
        if gNetworkPlayers[idx].connected and gPlayerSyncTable[idx].isLeader then
            return idx
        end
    end
    return -1
end

function readjustLeader()

    local gpPlayers = {}
    for i = 0, gGlobalSyncTable.groupCount - 1 do

        if getGroupLeader(i) == -1 then
            gpPlayers = getGpPlayers(i)
            for _, idx in ipairs(gpPlayers) do
                gPlayerSyncTable[idx].prevLeader = gPlayerSyncTable[idx].prevLeader - 1
                if gPlayerSyncTable[idx].prevLeader == 0 then
                    gPlayerSyncTable[idx].isLeader = true
                end
            end
        end

    end
end

---@param name string
---@return integer
function findGPByPlayerName(name)
    for i = 0, (MAX_PLAYERS - 1) do
        if gNetworkPlayers[i].connected and (strip_colors(gNetworkPlayers[i].name)):lower() == (strip_colors(name)):lower()then
            return gPlayerSyncTable[i].group
        end
    end
    return -1
end

---@param name string
---@return boolean
function hasServerRepeatedNames(name)
    local count = 0
    for i = 0, (MAX_PLAYERS - 1) do
        if count > 1 then
            return true
        end
        if gNetworkPlayers[i].name == name then
            count = count + 1
        end
    end
    return false
end

---@return integer[]
function getChainedPlayersInArea()
    local playerIndexes = {}
    for i = 0, (MAX_PLAYERS - 1) do
        if gNetworkPlayers[i].connected and gPlayerSyncTable[i].chained and gNetworkPlayers[i].currLevelNum == gNetworkPlayers[0].currLevelNum then
            tableInsert(playerIndexes, i)
        end
    end
    return playerIndexes
end

---@param gpNum integer
---@return integer[]
function getGpPlayersInArea(gpNum)
    local playerIndexes = {}
    for i = 0, (MAX_PLAYERS - 1) do
        if gNetworkPlayers[i].connected and gPlayerSyncTable[i].chained and gNetworkPlayers[i].currLevelNum == gNetworkPlayers[0].currLevelNum and gNetworkPlayers[i].currAreaIndex == gNetworkPlayers[0].currAreaIndex and gNetworkPlayers[i].currActNum == gNetworkPlayers[0].currActNum and gPlayerSyncTable[i].group == gpNum then
            tableInsert(playerIndexes, i)
        end
    end
    return playerIndexes
end

---@param gpNum integer
---@return integer[]
function getGpPlayers(gpNum)
    local playerIndexes = {}
    for i = 0, (MAX_PLAYERS - 1) do
        if gNetworkPlayers[i].connected and gPlayerSyncTable[i].chained and gPlayerSyncTable[i].group == gpNum then
            tableInsert(playerIndexes, i)
        end
    end
    return playerIndexes
end

---@param gpNum integer
---@return boolean
function nearGroup(gpNum)
    local chainedPlayers = getGpPlayersInArea(gpNum)
    local dist = 0
    if #chainedPlayers == 1 then
        local otherPos = gMarioStates[chainedPlayers[1]].pos
        dist = vec3f_dist(gMarioStates[0].pos, otherPos) / 2
    elseif #chainedPlayers > 1 then
        dist = vec3f_dist(gMarioStates[0].pos, visualCenters[gpNum + 1])
    end
    return dist <= gGlobalSyncTable.maxDistFromCenter
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Chain Behaviour ----------------------------------------------------------------------------------------------------------------------
--- @param o Object
function bhvChainInit(o)
    o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    obj_set_billboard(o)
    cur_obj_scale(0.7)
end

local id_bhv_chain = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhvChainInit, delObj)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Spectate Action -------------------------------------------------------------------------------------------------------------------
---@param m MarioState
function act_spectate(m)
    set_character_animation(m, CHAR_ANIM_SLEEP_IDLE)
    m.marioBodyState.modelState = m.marioBodyState.modelState | MODEL_STATE_NOISE_ALPHA
    vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
    m.health = 255
end

hook_mario_action(ACT_SPECTATE, act_spectate)
--#endregion

--#region Crucial Event Stuff ------------------------------------------------------------------------------------------------------------------
function update()
    local actSelect = obj_get_first_with_behavior_id(id_bhvActSelector)
    if actSelect then
        gPlayerSyncTable[0].ignoreTimer = 0
    end

    if networkIsServer() then
        readjustLeader()
    end
end

---@param m MarioState
function mario_update(m)
    if m.playerIndex == 0 and gNetworkPlayers[0].connected then
        mario_update_local(m)
    end
end

function level_init()
    gPlayerSyncTable[0].ignoreTimer = 0
end

---@param m MarioState
---@param obj Object
---@param intType integer
---@return boolean
function allow_warp_interact(m, obj, intType)

    if allowWarps then
        return true
    else
        if intType == INTERACT_WARP_DOOR or intType == INTERACT_BBH_ENTRANCE or intType == INTERACT_WARP then
            return false
        end

        return true
    end
end

function renderSpectatingHud()
    if renderingSpectatingMsg then
        if not hud_is_hidden() then
            hud_hide()
        end
        djui_hud_set_color(34, 34, 34, 255)
        local scale = 2
        local wdth = djui_hud_measure_text(SPECT_TEXT) * scale
        local x = djui_hud_get_screen_width() / 2 - wdth / 2
        local y = djui_hud_get_screen_height() / 2 - 40
        djui_hud_print_text(SPECT_TEXT, x, y, scale)
    else
        if hud_is_hidden() then
            hud_show()
        end
    end
end

function on_warp()
    if gGlobalSyncTable.enableLeaders and gPlayerSyncTable[0].chained and gPlayerSyncTable[0].isLeader then
        local gpPlayers = getGpPlayers(gPlayerSyncTable[0].group)
        local npLeader = gNetworkPlayers[0]
        for i, idx in ipairs(gpPlayers) do
            if i > 1 then
                local npPlayer = gNetworkPlayers[idx]
                if npLeader.currLevelNum ~= npPlayer.currLevelNum or npLeader.currAreaIndex ~= npPlayer.currAreaIndex or npLeader.currActNum ~= npPlayer.currActNum then
                    gPlayerSyncTable[idx].warpToLeader = true
                end
            end
        end
    end
end

--- @param m MarioState
function mario_update_local(m)

    if gGlobalSyncTable.forceChain and network_player_connected_count() > 1 then
        if not gPlayerSyncTable[0].chained then
            chain("")
        end

        if gPlayerSyncTable[0].group == -1 or #getGpPlayersInArea(gPlayerSyncTable[0].group) < 2 then
            local groupToJoin = 0
            ::recurse::
            local playersInGroup = #getGpPlayersInArea(groupToJoin)
            if playersInGroup < 2 then
                groupToJoin = groupToJoin + 1
                if groupToJoin < gGlobalSyncTable.groupCount then
                    goto recurse
                end
            else
                gPlayerSyncTable[0].group = groupToJoin
                popup("Force chain is enabled. You have been forced into an existing chain group.", 3)
            end
        end
    end

    local chainedPlayersIndexes = getChainedPlayersInArea()
    if #chainedPlayersIndexes > 1 then
        drawChainsForPlayers()
        handleChainedPhysics(m)
    end

    if spectating and m.action ~= ACT_SPECTATE then
        set_mario_action(m, ACT_SPECTATE, 0)
    elseif not spectating and m.action == ACT_SPECTATE then
        set_mario_action(m, ACT_FREEFALL, 0)
        m.health = 2176
    end

    if spectating and (m.controller.buttonPressed & L_TRIG) ~= 0 then
        toggleSpectator()
    end

    if gPlayerSyncTable[0].ignoreTimer < 60 then
        gPlayerSyncTable[0].ignoreTimer = gPlayerSyncTable[0].ignoreTimer + 1
    end

    local leaderIdx = getGroupLeader(gPlayerSyncTable[0].group)
    if gGlobalSyncTable.enableLeaders and gPlayerSyncTable[0].chained and not gPlayerSyncTable[0].isLeader and leaderIdx ~= -1 then

        allowWarps = false

        if not playerActive(gMarioStates[0]) then return end

        if m.floor ~= nil and (m.floor.type == SURFACE_WARP or (m.floor.type >= SURFACE_PAINTING_WARP_D3 and m.floor.type <= SURFACE_PAINTING_WARP_FC) or (m.floor.type >= SURFACE_INSTANT_WARP_1B and m.floor.type <= SURFACE_INSTANT_WARP_1E)) then
            m.floor.type = SURFACE_DEFAULT
        end

        local npLeader = gNetworkPlayers[leaderIdx]
        
        if npLeader ~= nil and gPlayerSyncTable[0].warpToLeader then
            warp_to_level(npLeader.currLevelNum, npLeader.currAreaIndex, npLeader.currActNum)
            gPlayerSyncTable[0].warpToLeader = false
        end
    else
        allowWarps = true
    end

    --Debugging stuff
    --[[ if (m.controller.buttonPressed & X_BUTTON) ~= 0 then
        chain('')
    end
    if (m.controller.buttonPressed & Y_BUTTON) ~= 0 then
        unchain('')
    end ]]
end

function drawChainsForPlayers()
    setVisualCenters()

    for i = 0, (gGlobalSyncTable.groupCount - 1) do
        local gpPlayers = getGpPlayersInArea(i)
        local drawnCenter = false
        if #gpPlayers > 1 then
            for _, playerIdx in ipairs(gpPlayers) do
                local m = gMarioStates[playerIdx]
                if isPlayerIgnoredForChainRender(m) then
                    goto continue
                end
                local firstCounted = false
                local center = {
                    x = visualCenters[i + 1].x,
                    y = visualCenters[i + 1].y,
                    z = visualCenters[i + 1].z
                }
                local mPos = {
                    x = m.pos.x,
                    y = m.pos.y + PLAYER_Y_POS,
                    z = m.pos.z
                }
                local direction = getDirToCenter(mPos, center)
                local dist = vec3f_dist(mPos, center)
                local currPos = {
                    x = center.x,
                    y = center.y,
                    z = center.z
                }
                while dist >= 0 do
                    if not drawnCenter or firstCounted then
                        drawnCenter = true
                        spawnObj(id_bhv_chain, E_MODEL_METALLIC_BALL, currPos.x, currPos.y, currPos.z, function() end)
                        currPos = {
                            x = currPos.x + direction.x * PART_SPACING,
                            y = currPos.y + direction.y * PART_SPACING,
                            z = currPos.z + direction.z * PART_SPACING
                        }
                        dist = dist - PART_SPACING
                    end
                    firstCounted = true
                end
                ::continue::
            end
        end
    end
end

---@param m MarioState
function handleChainedPhysics(m)
    if gPlayerSyncTable[m.playerIndex].chained and #getGpPlayersInArea(gPlayerSyncTable[0].group) > 1 then
        if gGlobalSyncTable.weightEnabled then
            handleWeightPhysics(m)
        else
            handleStaticPhysics(m)
        end
    end
end

---@param m MarioState
function handleStaticPhysics(m)
    local dist = vec3f_dist(m.pos, chainCenter)
    if isMarioMovingAway(m.pos, m.vel) and dist >= gGlobalSyncTable.maxDistFromCenter then
        if m.forwardVel > 0 then
            m.forwardVel = -CHAIN_KB
        else
            m.forwardVel = CHAIN_KB
        end

        if (m.action & ACT_FLAG_AIR) ~= 0 then
            if m.pos.x < chainCenter.x - gGlobalSyncTable.maxDistFromCenter then
                m.vel.x = CHAIN_KB
            elseif m.pos.x > chainCenter.x + gGlobalSyncTable.maxDistFromCenter then
                m.vel.x = -CHAIN_KB
            end

            if m.pos.y < chainCenter.y - gGlobalSyncTable.maxDistFromCenter then
                m.vel.y = CHAIN_KB
                gettingUp = true
                set_mario_action(m, ACT_IDLE, 0)
            elseif m.pos.y > chainCenter.y + gGlobalSyncTable.maxDistFromCenter then
                m.vel.y = -CHAIN_KB
            end

            if m.pos.z < chainCenter.z - gGlobalSyncTable.maxDistFromCenter then
                m.vel.z = CHAIN_KB
            elseif m.pos.z > chainCenter.z + gGlobalSyncTable.maxDistFromCenter then
                m.vel.z = -CHAIN_KB
            end
        end
    end
    if gettingUp and (m.controller.buttonPressed & A_BUTTON) ~= 0 then
        gettingUp = false
        m.faceAngle.y = m.intendedYaw
        m.vel.y = gGlobalSyncTable.recoveryJumpHeight
    end

    if spectating then
        local players = getGpPlayersInArea(gPlayerSyncTable[0].group)
        if #players == 2 then
            m.pos.x = gMarioStates[players[2]].pos.x + 60
            m.pos.y = gMarioStates[players[2]].pos.y
            m.pos.z = gMarioStates[players[2]].pos.z + 60
        else
            m.pos.x = chainCenter.x + 60
            m.pos.y = chainCenter.y
            m.pos.z = chainCenter.z + 60
        end
    end
end

---@param m MarioState
function handleWeightPhysics(m)
    local dist = vec3f_dist(m.pos, chainCenter)
    if dist >= gGlobalSyncTable.maxDistFromCenter then
        local boundedPos = { x = 0, y = 0, z = 0 }
        vec3f_dif(boundedPos, m.pos, chainCenter)
        vec3f_normalize(boundedPos)
        vec3f_mul(boundedPos, gGlobalSyncTable.maxDistFromCenter)
        vec3f_add(boundedPos, chainCenter)

        local rubberBandingMultiplier = lua_clamp(((dist - gGlobalSyncTable.maxDistFromCenter) / gGlobalSyncTable.rubberBandingSlack),
            gGlobalSyncTable.minPullMultiplier, gGlobalSyncTable.maxPullMultiplier)

        if dist >= gGlobalSyncTable.maxDistFromCenter * 2 and m.action & ACT_FLAG_ON_POLE ~= 0 then
            set_mario_action(m, ACT_FREEFALL, 0)
        end

        m.pos.x = approach_f32_asymptotic(m.pos.x, boundedPos.x, rubberBandingMultiplier)
        m.pos.y = approach_f32_asymptotic(m.pos.y, boundedPos.y, rubberBandingMultiplier)
        m.pos.z = approach_f32_asymptotic(m.pos.z, boundedPos.z, rubberBandingMultiplier)

        if m.action & ACT_FLAG_AIR ~= 0 and m.action ~= ACT_IN_CANNON and m.action ~= ACT_SHOT_FROM_CANNON and m.pos.y < chainCenter.y - gGlobalSyncTable.maxDistFromCenter * 0.65 and m.controller.buttonPressed & A_BUTTON ~= 0 then
            m.vel.y = gGlobalSyncTable.recoveryJumpHeight
            set_mario_action(m, ACT_FREEFALL, 0)
        end
    end
end

function setVisualCenters()
    visualCenters = {}
    for i = 0, (gGlobalSyncTable.groupCount - 1) do
        local center = {}
        if gGlobalSyncTable.weightEnabled then
            center = getWeightedCenter(getGpPlayersInArea(i))
        else
            center = getCenter(getPlayersRawPositions(getGpPlayersInArea(i)))
        end

        tableInsert(visualCenters, center)
        if i == gPlayerSyncTable[0].group then
            chainCenter = {
                x = center.x,
                y = center.y,
                z = center.z
            }
        end
    end
end

---@param playerIndexes integer[]
---@return Vec3f[]
function getPlayersRawPositions(playerIndexes)
    local positions = {}
    for _, i in ipairs(playerIndexes) do
        local m = gMarioStates[i]
        local pos = {
            x = m.pos.x,
            y = m.pos.y + PLAYER_Y_POS,
            z = m.pos.z
        }
        if m.action == ACT_SHOT_FROM_CANNON or m.action == ACT_CRAZY_BOX_BOUNCE then
            positions = { { x = m.pos.x, y = m.pos.y + PLAYER_Y_POS + 200, z = m.pos.z } }
            break
        end

        if not isPlayerIgnored(m) then
            tableInsert(positions, pos)
        end
    end
    return positions
end

---@param playerIndexes integer[]
---@param rawCenter Vec3f
---@return Vec3f[]
function getPlayersWeightedPositions(playerIndexes, rawCenter)
    local positions = {}
    for _, idx in ipairs(playerIndexes) do
        local m = gMarioStates[idx]
        if m.action == ACT_SHOT_FROM_CANNON or m.action == ACT_CRAZY_BOX_BOUNCE then
            positions = { { x = m.pos.x, y = m.pos.y + PLAYER_Y_POS + 200, z = m.pos.z } }
            break
        end

        if isPlayerIgnored(m) then
            goto continue
        end
        local weight = actionWeights[m.action] or 1

        if m.flags & MARIO_METAL_CAP ~= 0 then
            weight = weight + 20
        end

        weight = weight + min(abs(m.forwardVel / 25), 3)
        weight = weight + min(abs(m.vel.y / 120), 0.6)

        if m.action == ACT_BUBBLED then
            weight = min(weight, 0.75)
        end

        local relativeStatePos = {
            x = m.pos.x - rawCenter.x,
            y = m.pos.y + PLAYER_Y_POS - rawCenter.y,
            z = m.pos.z - rawCenter.z,
        }
        local weightedStatePos = {
            x = rawCenter.x + relativeStatePos.x * weight,
            y = rawCenter.y + relativeStatePos.y * weight,
            z = rawCenter.z + relativeStatePos.z * weight,
        }
        tableInsert(positions, weightedStatePos)
        ::continue::
    end
    return positions
end

---@param playerIndexes integer[]
---@return Vec3f
function getWeightedCenter(playerIndexes)
    local rawPositions = getPlayersRawPositions(playerIndexes)
    local rawCenter = getCenter(rawPositions)
    local weightedPositions = getPlayersWeightedPositions(playerIndexes, rawCenter)
    local weightedCenter = getCenter(weightedPositions)

    if vec3f_dist(rawCenter, weightedCenter) > gGlobalSyncTable.maxDistFromCenter then
        local dif = { x = 0, y = 0, z = 0 }
        vec3f_dif(dif, rawCenter, weightedCenter)
        vec3f_normalize(dif)
        vec3f_mul(dif, gGlobalSyncTable.maxDistFromCenter)
        local newWeightedCenter = { x = rawCenter.x - dif.x, y = rawCenter.y - dif.y, z = rawCenter.z - dif.z }
        vec3f_copy(weightedCenter, newWeightedCenter)
    end

    return weightedCenter
end

---@param positions Vec3f[]
---@return Vec3f
function getCenter(positions)
    local sumX, sumY, sumZ = 0, 0, 0
    for _, val in ipairs(positions) do
        sumX = sumX + val.x
        sumY = sumY + val.y
        sumZ = sumZ + val.z
    end
    return {
        x = sumX / #positions,
        y = sumY / #positions,
        z = sumZ / #positions
    }
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Command Functions --------------------------------------------------------------------------------------------------------------------
---@param msg string
---@return boolean
function chain(msg)
    local numMsg = tonumber(msg)
    local isName = false
    if msg == "" then
        numMsg = 0
    elseif numMsg == nil then
        numMsg = findGPByPlayerName(msg)
        isName = true
    end

    if not isName then
        if numMsg < 0 or numMsg > gGlobalSyncTable.groupCount then
            popup(
                tostring(numMsg) ..
                " is not a valid group index (valid indexes: [0-" .. tostring(gGlobalSyncTable.groupCount) .. "]).", 1)
            return true
        end
    else
        if numMsg == -1 then
            popup("The player " .. msg .. " does not exist or is not chained.", 1)
            return true
        elseif hasServerRepeatedNames(msg) and not gPlayerSyncTable[0].chained then
            chatMsg("Warning: There are 2 or more players with the name " ..
                msg .. ". You will be chained to the group of the first one found (Group " .. tostring(numMsg) .. ").")
        end
    end

    local groupPlayers = getGpPlayers(numMsg)
    if groupPlayers[1] then
        local groupReferencePlayer = gNetworkPlayers[getGroupLeader(numMsg)]
        ---@type NetworkPlayer
        local localNP = gNetworkPlayers[0]
        if localNP.currLevelNum == groupReferencePlayer.currLevelNum and localNP.currAreaIndex == groupReferencePlayer.currAreaIndex and localNP.currActNum == groupReferencePlayer.currActNum then

            ---@type MarioState
            local mLocal = gMarioStates[0]
            local mReference = gMarioStates[getGroupLeader(numMsg)]
            mLocal.pos.x = mReference.pos.x
            mLocal.pos.y = mReference.pos.y
            mLocal.pos.z = mReference.pos.z
            gPlayerSyncTable[0].ignoreTimer = 0
        else
            warp_to_level(groupReferencePlayer.currLevelNum, groupReferencePlayer.currAreaIndex, groupReferencePlayer.currActNum)
            gPlayerSyncTable[0].ignoreTimer = 0
        end
    end

    gPlayerSyncTable[0].chained = true
    gPlayerSyncTable[0].group = numMsg
    gPlayerSyncTable[0].isLeader = false

    local maxPrevLeader = -1
    for _, idx in ipairs(groupPlayers) do
        if gPlayerSyncTable[idx].prevLeader > maxPrevLeader then
            maxPrevLeader = gPlayerSyncTable[idx].prevLeader
        end
    end
    gPlayerSyncTable[0].prevLeader = maxPrevLeader + 1
    play_sound(SOUND_GENERAL_CHAIN_CHOMP1, gMarioStates[0].pos)
    popup(gNetworkPlayers[0].name .. " is now chained.", 1)

    if #groupPlayers == 0 then
        gPlayerSyncTable[0].isLeader = true
    end

    if not gGlobalSyncTable.forceChain and numMsg == gGlobalSyncTable.groupCount and gGlobalSyncTable.groupCount < gGlobalSyncTable.maxGroupCount and #groupPlayers == 0 then
        gGlobalSyncTable.groupCount = gGlobalSyncTable.groupCount + 1
    end

    return true
end

---@param msg string
---@return boolean
function unchain(msg)
    if msg ~= "" then
        return false
    end
    if gGlobalSyncTable.forceChain then
        chatMsg("This command has been disabled.")
        return true
    end

    if gPlayerSyncTable[0].chained then
        popup(gNetworkPlayers[0].name .. " is not chained anymore.", 1)
        local gpPlayers = getGpPlayers(gPlayerSyncTable[0].group)

        gPlayerSyncTable[0].chained = false
        local gp = gPlayerSyncTable[0].group
        gPlayerSyncTable[0].group = -1
        gPlayerSyncTable[0].isLeader = false
        gPlayerSyncTable[0].prevLeader = -1

        play_sound(SOUND_GENERAL_PAINTING_EJECT, gMarioStates[0].pos)

        if #gpPlayers == 1 then
            readjustGroups()

            local text = "Group "..tostring(gp).." has been deleted."
            if gGlobalSyncTable.groupCount > 1 then
                text = text.."The others are readjusted."
            end
            djui_popup_create_global(text, 1)

            gGlobalSyncTable.groupCount = gGlobalSyncTable.groupCount - 1
        end
    else
        popup(gNetworkPlayers[0].name .. " is not chained.", 1)
    end
    return true
end

function toggleSpectator()
    if gPlayerSyncTable[0].chained then
        spectating = gMarioStates[0].action ~= ACT_SPECTATE
        renderingSpectatingMsg = spectating
    else
        popup("You have to be in a group to spectate it.", 1)
    end
    return true
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_UPDATE, update)
hookEvent(HOOK_MARIO_UPDATE, mario_update)
hookEvent(HOOK_ON_LEVEL_INIT, level_init)
hookEvent(HOOK_ALLOW_INTERACT, allow_warp_interact)
hookEvent(HOOK_ON_HUD_RENDER, renderSpectatingHud)
hookEvent(HOOK_ON_WARP, on_warp)

hookChatCommand("scb-chain",
    "[number|name] - Chains your player to a subgroup number or to the subgroup of other player. Default is Group 0.",
    chain)
hookChatCommand("scb-unchain", "- Releases the chains of your player.", unchain)
hookChatCommand("scb-spectate", "- Become a spectator. The spectator is weightless according to the chain.",
    toggleSpectator)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Mod Menu -----------------------------------------------------------------------------------------------------------------------------
hookMMButton("Spectate", toggleSpectator)
if networkIsServer() then
    local function mod_menu_force_chain(_, value)
        gGlobalSyncTable.forceChain = value
    end

    local function mod_menu_change_movement_distance(_, value)
        gGlobalSyncTable.maxDistFromCenter = lua_clamp((tonumber(value) or 350), 250, 3000)
    end

    local function mod_menu_change_recovery_jump(_, value)
        gGlobalSyncTable.recoveryJumpHeight = lua_clamp((tonumber(value) or 60), 40, 200)
    end

    local function mod_menu_change_slack(_, value)
        gGlobalSyncTable.rubberBandingSlack = tonumber(value) or 100
    end

    local function mod_menu_change_min_pull(_, value)
        gGlobalSyncTable.minPullMultiplier = lua_clamp(tonumber(value) or 0.1, 0, 1)
    end

    local function mod_menu_change_max_pull(_, value)
        gGlobalSyncTable.maxPullMultiplier = lua_clamp(tonumber(value) or 0.1, 0, 1)
    end

    local function mod_menu_toggle_weight(_, value)
        gGlobalSyncTable.weightEnabled = value
    end

    local function mod_menu_toggle_enable_leaders(_, value)
        gGlobalSyncTable.enableLeaders = value
    end

    local function mod_menu_change_max_group_count(_, value)
        gGlobalSyncTable.maxGroupCount = lua_clamp(tonumber(value) or 3, 1, MAX_PLAYERS)
        if gGlobalSyncTable.groupCount > gGlobalSyncTable.maxGroupCount then
            gGlobalSyncTable.groupCount = gGlobalSyncTable.maxGroupCount
        end
    end

    local function mod_menu_resync()
        gGlobalSyncTable.forceChain = gGlobalSyncTable.forceChain
        gGlobalSyncTable.maxDistFromCenter = gGlobalSyncTable.maxDistFromCenter
        gGlobalSyncTable.recoveryJumpHeight = gGlobalSyncTable.recoveryJumpHeight
        gGlobalSyncTable.weightEnabled = gGlobalSyncTable.weightEnabled
        gGlobalSyncTable.rubberBandingSlack = gGlobalSyncTable.rubberBandingSlack
        gGlobalSyncTable.minPullMultiplier = gGlobalSyncTable.minPullMultiplier
        gGlobalSyncTable.maxPullMultiplier = gGlobalSyncTable.maxPullMultiplier
        gGlobalSyncTable.enableLeaders = gGlobalSyncTable.enableLeaders
        gGlobalSyncTable.maxGroupCount = gGlobalSyncTable.maxGroupCount
    end

    hookMMCheckbox("Force Chain Everyone", false, mod_menu_force_chain)
    hookMMInput("Movement Distance", "350", 8, mod_menu_change_movement_distance)
    hookMMInput("Recovery Jump Height", "60", 8, mod_menu_change_recovery_jump)
    hookMMCheckbox("Use Weight physics", false, mod_menu_toggle_weight)
    hookMMInput("Slack (Weight Physics)", "100", 8, mod_menu_change_slack)
    hookMMInput("Min pull [0-1] (Weight Physics)", "0.1", 8, mod_menu_change_min_pull)
    hookMMInput("Max pull [0-1] (Weight Physics)", "1", 8, mod_menu_change_max_pull)
    hookMMButton("Resync", mod_menu_resync)
    hookMMCheckbox("Enable Leaders", true, mod_menu_toggle_enable_leaders)
    hookMMInput("Max group count", "10", 3, mod_menu_change_max_group_count)
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region "API" (for TH) -----------------------------------------------------------------------------------------------------------------------
---@param playerIdx integer
---@return integer
function getPlayerGroup(playerIdx)
    return gPlayerSyncTable[playerIdx].group
end

---@return boolean
function isLeadersEnabled()
    return gGlobalSyncTable.enableLeaders
end

function getMaxGroupCount()
    return gGlobalSyncTable.maxGroupCount
end

_G.scbLoaded = true
_G.scbFunctions = {
    getPlayerGroup = getPlayerGroup,
    isLeadersEnabled = isLeadersEnabled,
    getGroupLeader = getGroupLeader,
    getMaxGroupCount = getMaxGroupCount
}
--#endregion -----------------------------------------------------------------------------------------------------------------------------------