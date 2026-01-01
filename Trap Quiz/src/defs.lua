--#region Localizations ---------------------------------------------------------------------

local allocate_mario_action = allocate_mario_action
local cast_graph_node = cast_graph_node
local geo_get_current_object = geo_get_current_object
local level_register = level_register
local smlua_collision_util_get = smlua_collision_util_get
local smlua_model_util_get_id = smlua_model_util_get_id

--#endregion --------------------------------------------------------------------------------

local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

globalTable.contestantA = -1
globalTable.contestantB = -1
globalTable.contestantAState = 2
globalTable.contestantBState = 2

for i = 0, MAX_PLAYERS - 1 do
	playerTable[i].inContestantSpot = false
end

ACT_SPECTATING = allocate_mario_action(ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)
ACT_SINK_IN_LAVA = allocate_mario_action(ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE | ACT_FLAG_STATIONARY)

LEVEL_QUIZ_ROOM = level_register('level_quiz_room_entry', COURSE_NONE, 'Quiz Room', 'quiz_room', 20000, 0, 0, 0)

E_MODEL_TRAP = smlua_model_util_get_id('trap_geo')
COL_TRAP = smlua_collision_util_get('trap_collision')

E_MODEL_BUTTON = smlua_model_util_get_id('button_geo')
COL_BUTTON = smlua_collision_util_get('button_collision')

SURFACE_QUIZ_DEATH = 0x2

---@param node FnGraphNode|GraphNode
function geo_switch_trap_door(node, _)
	local gn = cast_graph_node(node)
	local o = geo_get_current_object()

	gn.selectedCase = o.oBehParams2ndByte --order
end

---@param node FnGraphNode|GraphNode
function geo_switch_button(node, _)
	local gn = cast_graph_node(node)
	local o = geo_get_current_object()

	gn.selectedCase = ternary(o.oAction == 1, 0, 1) --order
end