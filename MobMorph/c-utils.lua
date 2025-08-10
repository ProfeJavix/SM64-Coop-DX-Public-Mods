local distBetObjs = dist_between_objects
local is_player_active = is_player_active
local get_object_list_from_behavior = get_object_list_from_behavior
local get_behavior_from_id = get_behavior_from_id
local gsub = string.gsub
local sub = string.sub
local length = string.len

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable

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

    if length(hexColor) == 3 then
        color.r = tonumber("0x" .. sub(hexColor, 1, 1) .. sub(hexColor, 1, 1)) or 0
        color.g = tonumber("0x" .. sub(hexColor, 2, 2) .. sub(hexColor, 2, 2)) or 0
        color.b = tonumber("0x" .. sub(hexColor, 3, 3) .. sub(hexColor, 3, 3)) or 0
    elseif length(hexColor) == 6 then
        color.r = tonumber("0x" .. sub(hexColor, 1, 2)) or 0
        color.g = tonumber("0x" .. sub(hexColor, 3, 4)) or 0
        color.b = tonumber("0x" .. sub(hexColor, 5, 6)) or 0
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

function getTotalMobs()
    local total = #ALLOWED_MOBS

    if globalTable.allowBosses then
        total = total + #ALLOWED_BOSSES
    end

    if globalTable.allowNpcs then
        total = total + #ALLOWED_NPCS
    end

    return total
end

---@return table | nil
function findMobDataBySelection()
    if selectedMobPos <= #ALLOWED_MOBS then
        return ALLOWED_MOBS[selectedMobPos]
    end
    local prevTotal = #ALLOWED_MOBS

    if globalTable.allowBosses then 
        if selectedMobPos - prevTotal <= #ALLOWED_BOSSES then
            return ALLOWED_BOSSES[selectedMobPos - prevTotal]
        else
            prevTotal = prevTotal + #ALLOWED_BOSSES
        end
    end

    if globalTable.allowBosses and selectedMobPos - prevTotal <= #ALLOWED_NPCS then
        return ALLOWED_NPCS[selectedMobPos - prevTotal]
    end

    selectedMobPos = 1
    return nil
end

---@param m MarioState
---@return MarioState | nil
function nearestAffectableMario(m)
    local nm = nil
    local minDist = 999999

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

---@param bhvId BehaviorId
---@return integer
function findSameTypeBhvsInLevel(bhvId)

    local count = 0
    local list = get_object_list_from_behavior(get_behavior_from_id(bhvId))

    local curObj = obj_get_first(list)
    while curObj ~= nil do
        if get_id_from_behavior(curObj.behavior) == bhvId then
            count = count + 1
        end
        curObj = obj_get_next(curObj)
    end
    return count
end

---@param mobData table
function canMorphIntoMob(mobData)
    return mobData[7] == -1 or findSameTypeBhvsInLevel(mobData[1]) < mobData[7]
end

---@param idx1 integer
---@param idx2 integer
function playersInSameArea(idx1, idx2)
    local np1, np2 = nps[idx1], nps[idx2]
    return (np1.currActNum == np2.currActNum and
    np1.currCourseNum == np2.currCourseNum and
    np1.currLevelNum == np2.currLevelNum and
    np1.currAreaIndex == np2.currAreaIndex)
end

---@param o Object
function sendObj(o)
    if o.activeFlags ~= ACTIVE_FLAG_DEACTIVATED then
        network_send_object(o, true)
    end
end