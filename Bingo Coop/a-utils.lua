local sub = string.sub
local random = math.random
local insert = table.insert
local remove = table.remove
local sort = table.sort
local measureText = djui_hud_measure_text
local clamp = math.clamp
local get_time = get_time
local ipairs = ipairs
local spawn_sync_object = spawn_sync_object

---@class _G
---@field mhApi? table

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable

--#region MH Stuff ----------------------------------------------------------------------------------------------------
getTeam = function (_) return 0 end
allowPvpAttack = function (_, _) return gServerSettings.playerInteractions == PLAYER_INTERACTIONS_PVP end
getMHState = function () return 0 end

mhExists = _G.mhExists
if mhExists then
    getTeam = _G.mhApi.getTeam
    allowPvpAttack = _G.mhApi.pvpIsValid
    getMHState = _G.mhApi.getState
end
--#endregion ----------------------------------------------------------------------------------------------------------

MODE_FFA = 'FFA'
MODE_TEAM = 'Team'
MODE_MH = 'MH'

TEAM_NONE = -1
TEAM_RED = 0
TEAM_BLUE = 1

STATE_WAIT = 0
STATE_INIT = 1
STATE_RUNNING = 2
STATE_FINISH = 3

TASK_INTERACT = 0
TASK_TIMER = 1
TASK_MISC = 2

COMPLETED_FAILED = -1
COMPLETED_NONE = 0
COMPLETED_SUCCESS = 1
COMPLETED_LINE = 2

PTYPE_CELL_TO_HOST = 'ptype_bingo_cell_to_host'
PTYPE_CELL = 'ptype_bingo_cell'
PTYPE_INTERACT = 'ptype_bingo_interact'
PTYPE_MISC = 'ptype_bingo_misc'

BUFF_NONE = -1
BUFF_GIVE = 0

--rewards
BUFF_WING_CAP = 1
BUFF_METAL_CAP = 2
BUFF_VANISH_CAP = 3
BUFF_MORE_JUMP_HEIGHT = 4
BUFF_INVINCIBLE = 5
BUFF_DEAL_MORE_DAMAGE = 6
BUFF_SPAWN_COINS = 7
BUFF_SPAWN_SHELL = 8
MAX_REWARDS = 9

--punishments
BUFF_SPAWN_GOOMBAS = 1
BUFF_SPAWN_BOBOMBS = 2
BUFF_SPAWN_CHUCKYAS = 3
BUFF_SPAWN_HEAVEHOES = 4
BUFF_TOXIC_POISON = 5
BUFF_LESS_JUMP_HEIGHT = 6
BUFF_PAINFUL_JUMPS = 7
BUFF_BLINDED = 8
BUFF_DEAL_LESS_DAMAGE = 9
MAX_PUNISHMENTS = 10

LINE_COUNT = 5
CELL_DATA = {
    { id = 'kill_goombas', min = 10, max = 20, type = TASK_INTERACT },
    { id = 'kill_koopas', min = 3, max = 10, type = TASK_INTERACT },
    { id = 'kill_bobombs', min = 8, max = 25, type = TASK_INTERACT },
    { id = 'kill_bullies', min = 10, max = 20, type = TASK_INTERACT },
    { id = 'kill_boos', min = 5, max = 10, type = TASK_INTERACT },
    { id = 'kill_chuckyas', min = 3, max = 8, type = TASK_INTERACT },
    { id = 'kill_whomps', min = 3, max = 15, type = TASK_INTERACT },
    { id = 'kill_king_bobomb', type = TASK_INTERACT },
    { id = 'kill_king_whomp', type = TASK_INTERACT },
    { id = 'kill_big_boo', type = TASK_INTERACT },
    { id = 'kill_big_bully', type = TASK_INTERACT },
    { id = 'kill_eyerok', type = TASK_INTERACT },
    { id = 'kill_wiggler', type = TASK_INTERACT },
    { id = 'kill_bowser1', type = TASK_INTERACT },
    { id = 'kill_bowser2', type = TASK_INTERACT },
    { id = 'kill_bowser3', type = TASK_INTERACT },
    { id = 'kick_klepto', type = TASK_INTERACT },
    { id = 'collect_yellow_coins', min = 50, max = 150, type = TASK_INTERACT },
    { id = 'collect_red_coins', min = 8, max = 16, type = TASK_INTERACT },
    { id = 'collect_blue_coins', min = 10, max = 20, type = TASK_INTERACT },
    { id = 'collect_stars', min = 8, max = 120, type = TASK_INTERACT },
    { id = 'collect_stars_in_course', min = 3, max = 5, type = TASK_INTERACT },
    { id = 'kill_player', pickPlayerIdx = true, type = TASK_INTERACT },
    { id = 'open_cannons', min = 3, max = 6, type = TASK_INTERACT },
    { id = 'beat_ktq1', type = TASK_MISC },
    { id = 'beat_ktq2', type = TASK_MISC },
    { id = 'beat_race_penguin', type = TASK_MISC },
    { id = 'seconds_in_air', minTime = 150, maxTime = 450, type = TASK_TIMER },
    { id = 'seconds_in_ground', minTime = 1200, maxTime = 7200, type = TASK_TIMER },
    { id = 'seconds_in_shell', minTime = 300, maxTime = 1800, type = TASK_TIMER }
}

---@return integer
function generateSeed()
    return get_time() * 1000 + random(999)
end

---@param cond boolean
---@param ifTrue any
---@param ifFalse any
function ternary(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    else
        return ifFalse
    end
end

---@param index integer
---@param top integer
---@return integer
function clampSelection(index, top)
    if index < 1 then
        index = top
    elseif index > top then
        index = 1
    end
    return index
end

---@param globalIdx integer
---@return integer
function getLocalFromGlobalIdx(globalIdx)
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == globalIdx then
            return i
        end
    end
    return -1
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

---@param text string
---@param wdth number
---@param scale number
---@return string
function fitText(text, wdth, scale)
    while measureText(text) * scale > wdth do
        text = sub(text, 1, #text - 1)
        if text == "" then
            break
        end
    end
    return text
end

---@param id string
---@return boolean, string
function isIdLevelStar(id)
    local pref = 'collect_stars_in_course'
    local suffix = ternary(sub(id, 1, #pref) == pref, sub(id, #pref + 1), nil)

    return suffix ~= nil, suffix
end

---@param globalIdx integer
---@return string
function getPlayerName(globalIdx)
    local name = ''
    local idx = getLocalFromGlobalIdx(globalIdx)
    if idx ~= -1 then
        name = stringWithoutHex(nps[idx].name)
    end
    return name
end

---@return integer
function getTeamAmount()
    local teams = {}
    for i = 0, MAX_PLAYERS - 1 do
        local team = playerTable[i].bingoTeam
        for _, val in ipairs(teams) do
            if team == TEAM_NONE or team == val then
                goto continue
            end
        end

        insert(teams, team)
        ::continue::
    end
    return #teams
end

---@param id string
function findTaskTypeById(id)

    if isIdLevelStar(id) then
        id = 'collect_stars_in_course'
    end

    for i = 1, #CELL_DATA do
        if CELL_DATA[i].id == id then
            return CELL_DATA[i].type
        end
    end
end

---@param table table
function tableRemoveOnTimer(table)
    for i = #table, 1, -1 do
        if table[i].timer == 0 or table[i].remove then
            remove(table, i)
        end
    end
end

---@param team integer
---@return integer[]
function getTeamMembers(team)
    if team == TEAM_NONE then return {} end

    local indexes = {}
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and playerTable[i].bingoTeam == team then
            insert(indexes, nps[i].globalIndex)
        end
    end
    sort(indexes)
    return indexes
end
--#region BUFF STUFF --------------------------------------------------------------------------------------------------

---@param m MarioState
---@param id integer
---@param isPunishment boolean
function spawn_buff(m, id, isPunishment)
    
    local mobId, model, count = nil, nil, 0

    if isPunishment then
        if id == BUFF_SPAWN_GOOMBAS then
            mobId, model, count = id_bhvGoomba, E_MODEL_GOOMBA, 15
        elseif id == BUFF_SPAWN_BOBOMBS then
            mobId, model, count = id_bhvBobomb, E_MODEL_BLACK_BOBOMB, 10
        elseif id == BUFF_SPAWN_CHUCKYAS then
            mobId, model, count = id_bhvChuckya, E_MODEL_CHUCKYA, 4
        elseif id == BUFF_SPAWN_HEAVEHOES then
            mobId, model, count = id_bhvHeaveHo, E_MODEL_HEAVE_HO, 3
        end
    else
        if id == BUFF_WING_CAP then
            mobId, model = id_bhvWingCap, E_MODEL_MARIOS_WING_CAP
        elseif id == BUFF_METAL_CAP then
            mobId, model = id_bhvMetalCap, E_MODEL_MARIOS_METAL_CAP
        elseif id == BUFF_VANISH_CAP then
            mobId, model = id_bhvVanishCap, E_MODEL_MARIOS_CAP
        elseif id == BUFF_SPAWN_COINS then
            mobId, model, count = id_bhvMovingYellowCoin, E_MODEL_YELLOW_COIN, 10
        elseif id == BUFF_SPAWN_SHELL then
            mobId, model = id_bhvKoopaShell, E_MODEL_KOOPA_SHELL
        end
    end

    if mobId and model then
        if count > 0 then
            for i = 1, count do
                local pos = {
                    x = m.pos.x + random(- 300, 300),
                    y = m.pos.y + random(0, 300),
                    z = m.pos.z + random(-300, 300)
                }
                spawn_sync_object(mobId, model, pos.x, pos.y, pos.z, function ()end)
            end
        else
            spawn_sync_object(mobId, model, m.pos.x, m.pos.y, m.pos.z, function ()end)
        end

        if isPunishment then
            playerTable[0].punishmentCooldown = 0
        else
            playerTable[0].rewardCooldown = 0
        end
    end
end

local JUMP_ACTIONS = {
    [ACT_JUMP] = true,
    [ACT_HOLD_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_STEEP_JUMP] = true,
    [ACT_SIDE_FLIP] = true,
    [ACT_BACKFLIP] = true,
    [ACT_BURNING_JUMP] = true,
    [ACT_WATER_JUMP] = true,
    [ACT_HOLD_WATER_JUMP] = true,
    [ACT_METAL_WATER_JUMP] = true,
    [ACT_TOP_OF_POLE_JUMP] = true,
    [ACT_SPECIAL_TRIPLE_JUMP] = true,
    [ACT_RIDING_SHELL_JUMP] = true,
    [ACT_WALL_KICK_AIR] = true
}

---@param m MarioState
---@param id integer
function buff_on_jump(m, id, _)

    if JUMP_ACTIONS[m.action] then
        local mult = 1

        if id == BUFF_LESS_JUMP_HEIGHT then
            mult = clamp(random(), 0.3, 0.7)
        elseif id == BUFF_MORE_JUMP_HEIGHT then
            mult = random(2, 10)
        elseif id == BUFF_PAINFUL_JUMPS and m.playerIndex == 0 then
            m.hurtCounter = m.hurtCounter + 4
        end

        m.vel.y = m.vel.y * mult
    end

end

---@param m MarioState
---@param id integer
function buff_continuous(m, id, isPunishment)

    if isPunishment then
        if id == BUFF_TOXIC_POISON then
            if (m.healCounter | m.hurtCounter) == 0 and
            (m.action & ACT_FLAG_INTANGIBLE) == 0 and
            m.flags & MARIO_METAL_CAP == 0 then
                m.health = m.health - 4
            end
        end
    else
        if id == BUFF_INVINCIBLE then
            m.hurtCounter = 0
        end
    end
end

REWARD_DATA = {
    [BUFF_WING_CAP] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_METAL_CAP] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_VANISH_CAP] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_MORE_JUMP_HEIGHT] = {hook = HOOK_ON_SET_MARIO_ACTION, func = buff_on_jump},
    [BUFF_INVINCIBLE] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = buff_continuous},
    [BUFF_SPAWN_COINS] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_SPAWN_SHELL] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff}
}

PUNISHMENT_DATA = {
    [BUFF_SPAWN_GOOMBAS] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_SPAWN_BOBOMBS] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_SPAWN_CHUCKYAS] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_SPAWN_HEAVEHOES] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff},
    [BUFF_TOXIC_POISON] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = buff_continuous},
    [BUFF_LESS_JUMP_HEIGHT] = {hook = HOOK_ON_SET_MARIO_ACTION, func = buff_on_jump},
    [BUFF_PAINFUL_JUMPS] = {hook = HOOK_ON_SET_MARIO_ACTION, func = buff_on_jump},
    [BUFF_BLINDED] = {hook = HOOK_BEFORE_MARIO_UPDATE, func = spawn_buff}
    
}
--#endregion ----------------------------------------------------------------------------------------------------------

function debugLog(a)
    djui_chat_message_create(tostring(a))
end