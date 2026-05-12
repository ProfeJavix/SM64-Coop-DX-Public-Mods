local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

---@class _G
---@field mhExists? boolean
---@field mhApi? table
---@field hnsRebirthExists? boolean
---@field hnsRebirth? table
---@field HideAndSeek? table

---@param m MarioState
---@return boolean
function isMiniMario(m)

    local playerTeam = nil

    if _G.mhExists then
        playerTeam = _G.mhApi.getTeam(m.playerIndex)
    elseif _G.hnsRebirthExists then
        playerTeam = _G.hnsRebirth.general.is_seeker_or_hidder(m.playerIndex)
        if not _G.hnsRebirth.general.is_round_running() then
            playerTeam = 9 --match not started
        end
    elseif _G.HideAndSeek then
        playerTeam = ternary(_G.HideAndSeek.is_player_seeker(m.playerIndex), 1, 0)
    end

    if playerTeam then
        playerTable[m.playerIndex].isMiniMario = globalTable.miniTeam == playerTeam
    end

    return playerTable[m.playerIndex].isMiniMario
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