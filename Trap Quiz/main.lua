-- name: Trap Quiz v1.0
-- description: The host must decide the two contestants and also chooses when to open their death trap doors.\n\nMade by \\#333\\Profe\\#ff0\\Javix

--#region Localizations ---------------------------------------------------------------------

local hook_behavior = hook_behavior
local hook_event = hook_event
local hook_mario_action = hook_mario_action
local require = require

--#endregion --------------------------------------------------------------------------------


require('src/utils')
require('src/defs')
local loops = require('src/loops')
local hooks = require('src/hooks')

id_bhvTrap = hook_behavior(nil, OBJ_LIST_SURFACE, true, loops.bhv_trap_init, loops.bhv_trap_loop, 'bhvTrapDoor')
id_bhvButton = hook_behavior(nil, OBJ_LIST_SURFACE, true, loops.bhv_button_init, loops.bhv_button_loop, 'bhvButton')
id_bhvContestantSpawn = hook_behavior(nil, OBJ_LIST_LEVEL, true, function()end, function()end, 'bhvContestantSpawn')

hook_mario_action(ACT_SINK_IN_LAVA, loops.act_sink_in_lava)
hook_mario_action(ACT_SPECTATING, loops.act_spectating)

hook_event(HOOK_MARIO_UPDATE, hooks.mario_update)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, hooks.before_set_mario_action)
hook_event(HOOK_ON_NAMETAGS_RENDER, hooks.on_nametags_render)
hook_event(HOOK_ON_HUD_RENDER, hooks.on_hud_render)
