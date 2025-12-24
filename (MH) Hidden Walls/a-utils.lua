---@class _G
---@field mhExists boolean
---@field mhApi table

---@class Object
---@field oOwner integer

if not _G.mhExists then return end

--#region Localizations ---------------------------------------------------------------------

local concat = table.concat
local djui_chat_message_create = djui_chat_message_create
local insert = table.insert
local obj_mark_for_deletion = obj_mark_for_deletion
local select = select
local smlua_collision_util_get = smlua_collision_util_get
local smlua_model_util_get_id = smlua_model_util_get_id
local spawn_non_sync_object = spawn_non_sync_object
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

local globalTable = gGlobalSyncTable

TEAM_HUNTERS = 0
TEAM_RUNNERS = 1

getMHTeam = _G.mhApi.getTeam

E_MODEL_INVISIBLE_WALL = smlua_model_util_get_id('invisible_wall_geo')
COL_INVISIBLE_WALL = smlua_collision_util_get('invisible_wall_collision')

showWallPH = true
wallPH = nil
curZOffset = 400
curYawOffset = 0
cooldown = 0

---@param m MarioState
function canSeeWalls(m)
    return getMHTeam(m.playerIndex) == globalTable.wallTeam
end

---@param m MarioState
function setWallPH(m)
    if showWallPH and canSeeWalls(m) and cooldown == 0 then
        if not wallPH or wallPH.activeFlags == ACTIVE_FLAG_DEACTIVATED then
            wallPH = spawn_non_sync_object(id_bhvInvisibleWallPH, E_MODEL_INVISIBLE_WALL, m.pos.x, m.pos.y, m.pos.z, function ()end)
        end
    else
        if wallPH then
            obj_mark_for_deletion(wallPH)
            wallPH = nil
        end
    end
end

---@param cond boolean | nil
---@param ifTrue any
---@param ifFalse any
function ternary(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    else
        return ifFalse
    end
end

function log(msg, ...)

    local parts = { tostring(msg) }

    for i = 1, select("#", ...) do
        local arg = select(i, ...)
        insert(parts, tostring(arg))
    end

    djui_chat_message_create(concat(parts, " "))
end