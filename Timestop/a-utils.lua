--#region Localizations ---------------------------------------------------------------------

local audio_sample_load = audio_sample_load
local djui_chat_message_create = djui_chat_message_create
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

---@class _G
---@field mhExists? boolean
---@field mhApi? table

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable

TEAM_RED = 0
TEAM_BLUE = 1

TEAM_NAMES = {
    [-1] = {'', ''},
    [TEAM_RED] = {'Red', 'Hunters'},
    [TEAM_BLUE] = {'Blue', 'Runners'},
}
TEAM_COLORS = {
    [-1] = {r = 0, g = 0, b = 0, a = 0},
    [TEAM_RED] = {r = 240, g = 0, b = 0, a = 240},
    [TEAM_BLUE] = {r = 0, g = 0, b = 240, a = 240}
}

SOUND_TIME_STOP = audio_sample_load('time-stop.ogg')
SOUND_TIME_RESUME = audio_sample_load('time-resume.ogg')

allowJJBAEffects = true
--#region MH Stuff -------------------------------------------------------------------------------------------------------------------------

mhExists = _G.mhExists or false

getTeam = function (idx) return playerTable[idx].team end

if mhExists then
    getTeam = _G.mhApi.getTeam
end
--#endregion -------------------------------------------------------------------------------------------------------------------------------

---@param cond boolean
---@param ifTrue any
---@param ifFalse any
function ternary(cond, ifTrue, ifFalse)
    return cond and ifTrue or ifFalse
end

---@param team integer
---@return integer
function playersInTeam(team)
    local count = 0
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and playerTable[i].team == team then
            count = count + 1
        end
    end

    return count
end

function log(msg)
    djui_chat_message_create(tostring(msg))
end