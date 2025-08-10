local is_player_active = is_player_active
local insert = table.insert
local measureText = djui_hud_measure_text
local clamp = clamp

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

---@param cond boolean
---@param ifTrue any
---@param ifFalse any
---@return any
function ternary(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    else
        return ifFalse
    end
end

---@param m1 MarioState
---@param m2 MarioState
function swapMPos(m1, m2)
    local aux = {x = 0, y = 0, z = 0}
    vec3f_copy(aux, m1.pos)
    vec3f_copy(m1.pos, m2.pos)
    vec3f_copy(m2.pos, aux)
end

---@param playerIdx integer
function nameWithoutHex(playerIdx)
    if playerIdx == -1 then return '?' end

    local name = nps[playerIdx].name
    local aux = ""
    local inSlash = false
    for i = 1, #name do
        local c = name:sub(i,i)
        if c == '\\' then
            inSlash = not inSlash
        elseif not inSlash then
            aux = aux .. c
        end
    end
    return aux
end

---@param text string
---@param wdth number
---@param scale number
---@return string
function fitText(text, wdth, scale)
    while measureText(text) * scale > wdth do
        text = text:sub(1, #text - 1)
        if text == "" then
            break
        end
    end
    return text
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

---@param globalIdx integer
function getLocalIdxFromGlobal(globalIdx)
    
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == globalIdx then
            return nps[i].localIndex
        end
    end
    return -1
end

---@return integer[]
function getSwappablePlayers()
    local players = {}
    for i = 1, MAX_PLAYERS - 1 do
        local m = states[i]
        local pt = playerTable[i]
        local team = getTeam(i)

        if not nps[i].connected or not is_player_active(m) or pt.warping or (playersInSameArea(0, i) and m.action & ACT_GROUP_CUTSCENE ~= 0) or
        (mhExists and (isSpectator(i) or isDead(i) or (getTeam(0) == team and not globalTable.teamSwap))) then goto continue end

        insert(players, nps[i].localIndex)
        ::continue::
    end
    return players
end

---@param curPos integer
---@param top integer
---@return integer
function adjustSelectedIdx(curPos, top, moveAmount)
    local newPos = curPos + moveAmount
    if top ~= 0 then
        if curPos == top and newPos > top then
            newPos = 1
        elseif curPos == 1 and newPos < 1 then
            newPos = top
        end
        curPos = clamp(newPos, 1, top)
    else
        curPos = 1
    end
    return curPos
end