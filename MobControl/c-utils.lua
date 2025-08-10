local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable

local distBetObjs = dist_between_objects
local get_id_from_behavior = get_id_from_behavior
local is_player_active = is_player_active
local spawn_non_sync_object = spawn_non_sync_object
local vec3f_dist = vec3f_dist
local gsub = string.gsub
local sub = string.sub
local length = string.len

local ALLOWED_MOBS = {
    id_bhvCustomBalconyBigBoo,
    id_bhvCustomBigBully,
    id_bhvCustomBigBullyWithMinions,
    id_bhvCustomBigChillBully,
    id_bhvCustomBobomb,
    id_bhvCustomBoo,
    id_bhvCustomBooWithCage,
    id_bhvCustomBowser,
    id_bhvCustomChainChomp,
    id_bhvCustomChuckya,
    id_bhvCustomEnemyLakitu,
    id_bhvCustomFlyGuy,
    id_bhvCustomGhostHuntBigBoo,
    id_bhvCustomGhostHuntBoo,
    id_bhvCustomGoomba,
    id_bhvCustomKingBobomb,
    id_bhvCustomKoopa,
    id_bhvCustomMadPiano,
    id_bhvCustomMerryGoRoundBigBoo,
    id_bhvCustomMerryGoRoundBoo,
    id_bhvCustomScuttlebug,
    id_bhvCustomSkeeter,
    id_bhvCustomSmallBully,
    id_bhvCustomSmallChillBully,
    id_bhvCustomSmallPenguin,
    id_bhvCustomSmallWhomp,
    id_bhvCustomSpindrift,
    id_bhvCustomSpiny,
    id_bhvCustomToadMessage,
    id_bhvCustomUkiki,
    id_bhvCustomWhompKingBoss,
    id_bhvCustomWigglerHead
}

---@param a number
---@param b number
---@param t number
---@return number
function lerp(a, b, t)
    return a * (1 - t) + b * t
end

---@param text string
---@return string
function stringWithoutHex(text)
    local aux = ""
    local inSlash = false
    for i = 1, #text do
        local c = sub(text, i, i)
        if c == '\\' then
            inSlash = not inSlash
        elseif not inSlash then
            aux = aux .. c
        end
    end
    return aux
end

---@param hexColor string
---@return Color
function colorHexToRGB(hexColor)

    local color = {r = 0, g = 0, b = 0}
    if hexColor == nil then return color end
    hexColor = gsub(hexColor, "\\", "")
    hexColor = gsub(hexColor, "#", "")

    if length(hexColor) == 6 then
        color.r = tonumber("0x"..sub(hexColor, 1, 2)) or 0
        color.g = tonumber("0x"..sub(hexColor, 3, 4)) or 0
        color.b = tonumber("0x"..sub(hexColor, 5, 6)) or 0
    end

    return color 
end

---@param globalIdx integer
---@return integer
function globalIdxToLocal(globalIdx)

    if globalIdx ~= -1 then
        for i = 0, MAX_PLAYERS - 1 do
            if nps[i].connected and nps[i].globalIndex == globalIdx then
                return i
            end
        end
    end
    return -1
end

---@param fromPos Vec3f
---@param bhvId BehaviorId
---@param minDist number
---@return Object | nil
function getNearestNonControlledMobById(fromPos, bhvId, minDist)
    local nearestObj = nil

    local curMinDist = minDist
    local obj = obj_get_first_with_behavior_id(bhvId)
    while obj ~= nil do
        if get_id_from_behavior(obj.behavior) == bhvId and
            obj.oPlayerControlling == -1 and
            obj.oHeldState == 0 and
            obj.header.gfx.node.flags & GRAPH_RENDER_INVISIBLE == 0 then
            local dist = vec3f_dist(fromPos, {x=obj.oPosX, y=obj.oPosY, z=obj.oPosZ})
            if dist < curMinDist then
                nearestObj = obj
                curMinDist = dist
            elseif dist == curMinDist and nearestObj == nil then
                nearestObj = obj
            end
        end
        obj = obj_get_next(obj)
    end

    return nearestObj
end

---@param fromPos Vec3f
---@param minDist number | nil
---@return Object | nil
function detectNearestAllowedMob(fromPos, minDist)
    local curMinDist = minDist or globalTable.controlRange
    local nearestObj = nil
    for i = 1, #ALLOWED_MOBS do
        local obj = getNearestNonControlledMobById(fromPos, ALLOWED_MOBS[i], curMinDist)
        if obj ~= nil then
            local dist = vec3f_dist(fromPos, {x=obj.oPosX, y=obj.oPosY, z=obj.oPosZ})
            if dist < curMinDist then
                nearestObj = obj
                curMinDist = dist
            elseif dist == curMinDist and nearestObj == nil then
                nearestObj = obj
            end
        end
    end
    return nearestObj
end

---@param m MarioState
---@return MarioState | nil
function nearestAffectableMario(m)
    local nm = nil
    local minDist = globalTable.powersRange

    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and
            i ~= m.playerIndex and
            is_player_active(states[i]) and
            states[i].action & ACT_GROUP_CUTSCENE == 0 and
            states[i].action ~= ACT_BUBBLED and
            nps[i].currActNum == nps[m.playerIndex].currActNum and
            nps[i].currAreaIndex == nps[m.playerIndex].currAreaIndex and
            nps[i].currLevelNum == nps[m.playerIndex].currLevelNum and
            (not mhExists or getMHTeam(m.playerIndex) ~= getMHTeam(i)) then
            local dist = distBetObjs(m.marioObj, states[i].marioObj)
            if dist < minDist then
                nm = states[i]
                minDist = dist
            elseif dist == minDist and nm == nil then
                nm = states[i]
            end
        end
    end

    return nm
end

---@param focusedObj Object
function placeFocusPointer(focusedObj)
    local camPos = gLakituState.curPos
    local objPos = {
        x = focusedObj.oPosX,
        y = focusedObj.oPosY,
        z = focusedObj.oPosZ
    }
    local dir = {x=0, y=0, z=0}
    vec3f_dif(dir, camPos, objPos)
    vec3f_normalize(dir)

    local spawnPos = {
        x = objPos.x + dir.x * (10 * focusedObj.header.gfx.scale.x + focusedObj.hitboxRadius),
        y = objPos.y + focusedObj.hitboxHeight / 2 + dir.y * (10 * focusedObj.header.gfx.scale.y + focusedObj.hitboxRadius),
        z = objPos.z + dir.z * (10 * focusedObj.header.gfx.scale.z + focusedObj.hitboxRadius)
    }
    spawn_non_sync_object(id_bhvSparkle, E_MODEL_SPARKLES_ANIMATION, spawnPos.x, spawnPos.y, spawnPos.z, nil)
end

---@param o Object
function sendObj(o)
    if o.activeFlags ~= ACTIVE_FLAG_DEACTIVATED then
        network_send_object(o, true)
    end
end