-- name: [CS] SSB Pikachu v1.1
-- description: This CS mod adds Pikachu with a moveset insired in his Super Smash Bros. series one.\n\nPikachu model by lochsteps.\n\nMade by \\#333\\Profe\\#ff0\\Javix.

--#region Localizations ---------------------------------------------------------------------

local hook_behavior = hook_behavior
local hook_event = hook_event
local hook_mario_action = hook_mario_action
local require = require

--#endregion --------------------------------------------------------------------------------

if not _G.charSelectExists then return end

require('src/defs')
require('src/utils')
local loops = require('src/loops')
local hooks = require('src/hooks')

id_bhvThunderSeg = hook_behavior(nil, OBJ_LIST_GENACTOR, true, loops.bhv_thunder_seg_init, loops.bhv_thunder_seg_loop)
id_bhvElectroParticle = hook_behavior(nil, OBJ_LIST_SPAWNER, true, nil, loops.bhv_electro_particle_loop)
id_bhvElectroBall = hook_behavior(nil, OBJ_LIST_GENACTOR, true, loops.bhv_electro_ball_init, loops.bhv_electro_ball_loop)

hook_mario_action(ACT_SMASH_NORMAL, loops.act_smash_normal)
hook_mario_action(ACT_SMASH_UP, loops.act_smash_up)
hook_mario_action(ACT_SMASH_DOWN, loops.act_smash_down)
hook_mario_action(ACT_SMASH_SIDE, loops.act_smash_side)
hook_mario_action(ACT_TURBO_SHOCKED, loops.act_turbo_shocked)

hook_event(HOOK_UPDATE, hooks.update)
hook_event(HOOK_MARIO_UPDATE, hooks.mario_update)
hook_event(HOOK_CHARACTER_SOUND, hooks.on_character_sound)
hook_event(HOOK_ALLOW_INTERACT, hooks.allow_interact)
hook_event(HOOK_ALLOW_PVP_ATTACK, hooks.allow_pvp_attack)
hook_event(HOOK_ALLOW_FORCE_WATER_ACTION, hooks.allow_force_water_action)

_G.charSelect.character_hook_moveset(CT_PIKACHU, HOOK_MARIO_UPDATE, hooks.cs_pikachu_mario_update)
_G.charSelect.character_hook_moveset(CT_PIKACHU, HOOK_BEFORE_SET_MARIO_ACTION, hooks.cs_pikachu_before_set_mario_action)