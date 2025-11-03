---@class _G
---@field mhExists? boolean
---@field mhApi? table

if not _G.mhExists then return end

local is_player_active = is_player_active
local insert = table.insert
local measureText = djui_hud_measure_text
local clamp = math.clamp
local setOverridePalette = network_player_set_override_palette_color
local getOverridePalette = network_player_get_override_palette_color
local play_cap_music = play_cap_music
local stop_cap_music = stop_cap_music

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable

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

---@param a number
---@param b number
---@param t number
---@return number
function lerp(a, b, t)
    return a * (1 - t) + b * t
end

---@param dest Vec3f
---@param src Vec3f
---@param t number
function vec3f_copy_interpolated(dest, src, t)
    dest.x = lerp(dest.x, src.x, t)
    dest.y = lerp(dest.y, src.y, t)
    dest.z = lerp(dest.z, src.z, t)
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

---@param globalIdx integer
function getLocalIdxFromGlobal(globalIdx)
    
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == globalIdx then
            return nps[i].localIndex
        end
    end
    return -1
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

---@return integer[]
function getHuntersList()
    local hunters = {}
    for i = 1, MAX_PLAYERS - 1 do
        local m = states[i]
        local pt = playerTable[i]
        if nps[i].connected and is_player_active(m) and
        not pt.isControlling and
        m.action & ACT_GROUP_CUTSCENE == 0 and
        not pt.warping
        and getTeam(i) == 0 and not isSpectator(i) and not isDead(i) then
            insert(hunters, nps[i].localIndex)
        end
    end
    return hunters
end

---@param flags integer
---@return integer
function getCapTimer(flags)
    
    if flags & MARIO_WING_CAP ~= 0 then
        return gLevelValues.wingCapDuration
    elseif flags & MARIO_METAL_CAP ~= 0 then
        return gLevelValues.metalCapDuration
    elseif flags & MARIO_VANISH_CAP ~= 0 then
        return gLevelValues.vanishCapDuration
    else
        return -1
    end
end

---@param flags integer
function playCapMusicIfEquiped(flags)
    
    if flags & MARIO_WING_CAP ~= 0 then
        play_cap_music(gLevelValues.wingCapSequence)
    elseif flags & MARIO_METAL_CAP ~= 0 then
        play_cap_music(gLevelValues.metalCapSequence)
    elseif flags & MARIO_VANISH_CAP ~= 0 then
        play_cap_music(gLevelValues.vanishCapSequence)
    else
        stop_cap_music()
    end

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

---@param npDest any
---@param npSrc any
function copyOverridePalette(npDest, npSrc)
    for i = 0, PLAYER_PART_MAX - 1 do
        setOverridePalette(npDest, i, getOverridePalette(npSrc, i))
    end
end