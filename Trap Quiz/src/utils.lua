--#region Localizations ---------------------------------------------------------------------

local djui_chat_message_create = djui_chat_message_create
local insert = table.insert
local obj_get_first_with_behavior_id = obj_get_first_with_behavior_id
local obj_get_next_with_same_behavior_id = obj_get_next_with_same_behavior_id
local sub = string.sub
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local globalTable = gGlobalSyncTable

---@param num integer
---@return string
function getTargetContestant(num)
    return 'contestant' .. ternary(num == 0, 'A', 'B')
end

function resetStatus()
    globalTable.contestantA = -1
    globalTable.contestantB = -1
    globalTable.contestantAState = 2
    globalTable.contestantBState = 2
end

---@param idx integer
---@return integer
function getLocalFromGlobalIndex(idx)
    if not nps[idx] then return -1 end

    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == idx then
            return i
        end
    end

    return - 1
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

---@return table
function getNonHostAndNotSelPlayers()
    local idxs = {[0] = {}, [1] = {}}

    for i = 1, MAX_PLAYERS - 1 do
        if nps[i].connected then
            if globalTable.contestantB ~= nps[i].globalIndex then
                insert(idxs[0], i)
            end
            if globalTable.contestantA ~= nps[i].globalIndex then
                insert(idxs[1], i)
            end
        end
    end

    return idxs
end

---@param localIdx integer
---@return Object | nil
function getContestantSpot(localIdx)
    local param = -1
    if localIdx == getLocalFromGlobalIndex(globalTable.contestantA) then
        param = 0
    elseif localIdx == getLocalFromGlobalIndex(globalTable.contestantB) then
        param = 1
    end

    if param ~= -1 then
        local curO = obj_get_first_with_behavior_id(id_bhvContestantSpawn)
        while curO do
            if curO.oBehParams2ndByte == param then
                return curO
            end
            curO = obj_get_next_with_same_behavior_id(curO)
        end
    end
end

---@param cond? boolean
---@param ifTrue any
---@param ifFalse any
function ternary(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    else
        return ifFalse
    end
end

function debugLog(msg)
    djui_chat_message_create(tostring(msg))
end