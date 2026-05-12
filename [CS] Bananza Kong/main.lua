-- name: [CS] Bananza Kong v1.2.3
-- description: Donkey Kong wants to get back his bananas stolen by Bowser. Use his Bananza moveset to help him!\n\nCredits:\n-SwagSkeleton95: DK models and animations\n-Baconator2558: coding help, Health Meter and Star Select textures\n-PeachyPeach: coding help\n-ManIscat2: coding help, Fast64 help\n-SullyBoy: DK music covers\n\nGeneral coding, moveset and chunk model by \\#333\\Profe\\#ff0\\Javix

--#region Localizations ---------------------------------------------------------------------

local define_custom_obj_fields = define_custom_obj_fields
local djui_popup_create = djui_popup_create
local hook_behavior = hook_behavior
local hook_chat_command = hook_chat_command
local hook_event = hook_event
local hook_mario_action = hook_mario_action
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local require = require

--#endregion --------------------------------------------------------------------------------


if not _G.charSelectExists then
	djui_popup_create(
		'\\#ffffdc\\\n[CS] Bananza Kong' ..
		'\nRequires the Character Select Mod' ..
		'\nto use as a Library!' ..
		'\n\nPlease turn on the Character Select Mod\nand Restart the Room!'
		, 6
	)
	return
end

require('src/defs')
require('src/animations')
require('src/utils')
local bhvs = require('src/behaviors')
local actions = require('src/actions')
local hooks = require('src/hooks')

define_custom_obj_fields({
	oChunkOwner = "s32"
})

hook_behavior(id_bhvStar, OBJ_LIST_LEVEL, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvCelebrationStar, OBJ_LIST_LEVEL, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvStarSpawnCoordinates, OBJ_LIST_LEVEL, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvSpawnedStar, OBJ_LIST_LEVEL, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvSpawnedStarNoLevelExit, OBJ_LIST_LEVEL, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvActSelectorStarType, OBJ_LIST_DEFAULT, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvUnlockDoorStar, OBJ_LIST_LEVEL, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvUkikiCageStar, OBJ_LIST_DEFAULT, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvRedCoinStarMarker, OBJ_LIST_DEFAULT, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvGrandStar, OBJ_LIST_LEVEL, false, nil, bhvs.bhv_star_loop)
hook_behavior(id_bhvBowserBodyAnchor, OBJ_LIST_GENACTOR, false, nil, bhvs.bhv_bowser_body_anchor_loop)
hook_behavior(id_bhvToadMessage, OBJ_LIST_GENACTOR, false, nil, bhvs.bhv_toad_message_loop)
hook_behavior(id_bhvSmallPenguin, OBJ_LIST_GENACTOR, false, nil, bhvs.bhv_small_penguin_loop)
id_bhvHeldChunk = hook_behavior(nil, OBJ_LIST_UNIMPORTANT, true, bhvs.bhv_held_chunk_init, bhvs.bhv_held_chunk_loop)
id_bhvChunk = hook_behavior(nil, OBJ_LIST_GENACTOR, true, bhvs.bhv_chunk_init, bhvs.bhv_chunk_loop)

hook_mario_action(ACT_DK_GRABBING_CHUNK, actions.act_dk_grabbing_chunk)
hook_mario_action(ACT_DK_PUNCHING, actions.act_dk_punching, INT_PUNCH)
hook_mario_action(ACT_DK_ROLL, actions.act_dk_roll)
hook_mario_action(ACT_DK_SLAM, actions.act_dk_slam, INT_GROUND_POUND)
hook_mario_action(ACT_DK_WALL_CLIMB, actions.act_dk_wall_climb)
hook_mario_action(ACT_DK_CHUNK_SURFING, actions.act_dk_chunk_surfing, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_DK_CHUNK_SWING, actions.act_dk_chunk_swing)
hook_mario_action(ACT_DK_CHUNK_THROWING, actions.act_dk_chunk_throwing)
hook_mario_action(ACT_DK_CHUNK_THROWING_AIR, actions.act_dk_chunk_throwing_air)

hook_event(HOOK_UPDATE, hooks.update)
hook_event(HOOK_ALLOW_INTERACT, hooks.allow_interact)
hook_event(HOOK_ON_PLAY_SOUND, hooks.on_play_sound)
hook_event(HOOK_ON_SEQ_LOAD, hooks.on_seq_load)
hook_event(HOOK_ALLOW_HAZARD_SURFACE, hooks.allow_hazard_surface)

_G.charSelect.character_hook_moveset(CT_DK, HOOK_BEFORE_MARIO_UPDATE, hooks.cs_dk_before_mario_update)
_G.charSelect.character_hook_moveset(CT_DK, HOOK_MARIO_UPDATE, hooks.cs_dk_mario_update)
_G.charSelect.character_hook_moveset(CT_DK, HOOK_ON_INTERACT, hooks.cs_dk_on_interact)
_G.charSelect.character_hook_moveset(CT_DK, HOOK_ON_SET_MARIO_ACTION, hooks.cs_dk_on_set_mario_action)
_G.charSelect.character_hook_moveset(CT_DK, HOOK_BEFORE_SET_MARIO_ACTION, hooks.cs_dk_before_set_mario_action)
_G.charSelect.character_hook_moveset(CT_DK, HOOK_ALLOW_PVP_ATTACK, hooks.cs_dk_allow_pvp_attack)
_G.charSelect.character_hook_moveset(CT_DK, HOOK_ON_PVP_ATTACK, hooks.cs_dk_on_pvp_attack)
_G.charSelect.character_hook_moveset(CT_DK, HOOK_ON_HUD_RENDER_BEHIND, hooks.cs_dk_on_hud_render_behind)

hook_chat_command("dk-moveset", "Explains DK's controls", hooks.cmd_dk_moveset)

hook_mod_menu_checkbox("Enable DK music", dkmusic, hooks.mm_checkbox_dkmusic)