--#region Localizations ---------------------------------------------------------------------

local allocate_mario_action = allocate_mario_action
local audio_sample_load = audio_sample_load
local audio_stream_load = audio_stream_load
local cast_graph_node = cast_graph_node
local geo_get_mario_state = geo_get_mario_state
local get_texture_info = get_texture_info
local mod_storage_load_bool = mod_storage_load_bool
local smlua_audio_utils_replace_sequence = smlua_audio_utils_replace_sequence
local smlua_model_util_get_id = smlua_model_util_get_id

--#endregion --------------------------------------------------------------------------------

local playerTable = gPlayerSyncTable

---@class _G
---@field charSelectExists? boolean
---@field charSelect? table

---@class Object
---@field oChunkOwner integer

--#region Vars ------------------------------------------------------------------------------------------------------------------------

for i = 0, (MAX_PLAYERS - 1) do
	playerTable[i].nearBanana = false
	playerTable[i].slamCharge = 0
	playerTable[i].rollJumpSpeed = 0
	playerTable[i].heldChunkAct = 0 --0: none | 1: surf | 2: drop
end

dkmusic = mod_storage_load_bool("dkmusic")

--#endregion ---------------------------------------------------------------------------------------------------------------------------

--#region Obj Stuff --------------------------------------------------------------------------------------------------------------------

E_MODEL_DK = smlua_model_util_get_id("bananza_dk_geo")
E_MODEL_DK_PANTS = smlua_model_util_get_id("bananza_dk_pants_geo")
E_MODEL_STAR_BANANA = smlua_model_util_get_id("star_banana_geo")
E_MODEL_TRANSPARENT_STAR_BANANA = smlua_model_util_get_id("transparent_star_banana_geo")
E_MODEL_YELLOW_BANANA_COIN = smlua_model_util_get_id("yellow_banana_coin_geo")
E_MODEL_YELLOW_BANANA_COIN_NO_SHADOW = smlua_model_util_get_id("yellow_banana_coin_no_shadow_geo")
E_MODEL_CHUNK = smlua_model_util_get_id("chunk_geo")
E_MODEL_HELD_CHUNK = smlua_model_util_get_id("held_chunk_geo")

function geo_switch_DKemote(node)
	--[[
		1 angry
		2 scared
		3 happy
		4 oo
		5 oo (angry)
	]]
	local asSwitchNode = cast_graph_node(node)
	local m = geo_get_mario_state()
	
	if not isDK(m.playerIndex) then return end

	local happyConditions = {
		[ACT_BACKFLIP_LAND_STOP] = true,
		[ACT_FLYING] = m.forwardVel < 70,
		[ACT_PUTTING_ON_CAP] = true,
		[ACT_SLEEPING] = m.marioObj.header.gfx.animInfo.animFrame >= 50,
		[ACT_STAR_DANCE_EXIT] = m.marioObj.header.gfx.animInfo.animFrame >= 60,
		[ACT_STAR_DANCE_NO_EXIT] = m.marioObj.header.gfx.animInfo.animFrame >= 60,
		[ACT_STAR_DANCE_WATER] = true,
		[ACT_TRIPLE_JUMP] = true,
		[ACT_DK_CHUNK_SURFING] = true
	}

	local angryConditions = {
		[ACT_PUNCHING] = true,
		[ACT_MOVE_PUNCHING] = true,
		[ACT_DK_PUNCHING] = true,
		[ACT_DK_SLAM] = true,
	}

	local scaredConditions = {
		[ACT_FLYING] = m.forwardVel >= 70,
		[ACT_THROWN_FORWARD] = true,
		[ACT_THROWN_BACKWARD] = true,
		[ACT_LAVA_BOOST] = true,
		[ACT_BACKWARD_AIR_KB] = true,
		[ACT_BACKWARD_GROUND_KB] = true,
		[ACT_HARD_BACKWARD_AIR_KB] = true,
		[ACT_HARD_BACKWARD_GROUND_KB] = true,
		[ACT_SOFT_BACKWARD_GROUND_KB] = true,
		[ACT_FORWARD_AIR_KB] = true,
		[ACT_FORWARD_GROUND_KB] = true,
		[ACT_HARD_FORWARD_AIR_KB] = true,
		[ACT_HARD_FORWARD_GROUND_KB] = true,
		[ACT_SOFT_FORWARD_GROUND_KB] = true,
	}

	local ooConditions = {
		[ACT_BACKFLIP] = true,
		[ACT_CROUCHING] = true,
		[ACT_DOUBLE_JUMP] = true,
		[ACT_JUMP] = true,
		[ACT_LONG_JUMP] = true,
		[ACT_SLEEPING] = m.marioObj.header.gfx.animInfo.animFrame < 50,
		[ACT_STAR_DANCE_EXIT] = m.marioObj.header.gfx.animInfo.animFrame >= 15 and
		m.marioObj.header.gfx.animInfo.animFrame < 43,
		[ACT_STAR_DANCE_NO_EXIT] = m.marioObj.header.gfx.animInfo.animFrame >= 15 and
		m.marioObj.header.gfx.animInfo.animFrame < 43,
		[ACT_START_SLEEPING] = m.marioObj.header.gfx.animInfo.animID == CHAR_ANIM_START_SLEEP_SCRATCH or
		m.marioObj.header.gfx.animInfo.animID == CHAR_ANIM_START_SLEEP_YAWN or
		m.marioObj.header.gfx.animInfo.animID == CHAR_ANIM_START_SLEEP_SITTING,
		[ACT_DK_WALL_CLIMB] = true
	}

	local ooAngryConditions = {
		[ACT_DK_ROLL] = true,
		[ACT_DK_CHUNK_THROWING] = true,
		[ACT_DK_CHUNK_THROWING_AIR] = m.actionState == 0
	}

	if happyConditions[m.action] then
		asSwitchNode.selectedCase = 3
	elseif angryConditions[m.action] then
		asSwitchNode.selectedCase = 1
	elseif scaredConditions[m.action] then
		asSwitchNode.selectedCase = 2
	elseif ooConditions[m.action] or playerTable[m.playerIndex].nearBanana then
		asSwitchNode.selectedCase = 4
	elseif ooAngryConditions[m.action] then
		asSwitchNode.selectedCase = 5
	else
		asSwitchNode.selectedCase = 0
	end
end

function geo_switch_DKGB(node, _)
	local asSwitchNode = cast_graph_node(node)
	local m = geo_get_mario_state()

	if not isDK(m.playerIndex) then return end

	local anim = m.marioObj.header.gfx.animInfo
	if (m.action == ACT_START_SLEEPING and anim.animID == CHAR_ANIM_START_SLEEP_SITTING and anim.animFrame > 14) or
	(m.action == ACT_SLEEPING) or
	(m.action == ACT_WAKING_UP and anim.animFrame < 9) then
		asSwitchNode.selectedCase = 1
	else
		asSwitchNode.selectedCase = 0
	end
end

--#endregion ---------------------------------------------------------------------------------------------------------------------------

--#region Sounds -----------------------------------------------------------------------------------------------------------------------

SOUND_BANANA1 = audio_sample_load("sample_banana_1.ogg")
SOUND_BANANA2 = audio_sample_load("sample_banana_2.ogg")
SOUND_BARREL_BREAK = audio_sample_load("sample_barrel_break.ogg")
SOUND_BOUNCE1 = audio_sample_load("sample_bounce_1.ogg")
SOUND_BOUNCE3 = audio_sample_load("sample_bounce_2.ogg")
SOUND_DRUM = audio_sample_load("sample_drum.ogg")

STREAM_DKRAP = audio_stream_load("stream_dkrap.ogg")
STREAM_OHBANANA = audio_stream_load("stream_ohbanana.ogg")
STREAM_COLLECT_BANANA = audio_stream_load("stream_collect_banana.ogg")

SEQ_SAFE_IDX = 100

SEQ_AQUATIC_AMBIENCE = SEQ_SAFE_IDX + 1
SEQ_SNOWBOUND_LAND = SEQ_SAFE_IDX + 2
SEQ_KROOKS_MARCH = SEQ_SAFE_IDX + 3
SEQ_WRINKLY_64 = SEQ_SAFE_IDX + 4
SEQ_CROCODILE_CACOPHONY = SEQ_SAFE_IDX + 5
SEQ_GANGPLANK_GALLEON = SEQ_SAFE_IDX + 6
SEQ_DK_ISLAND_SWING = SEQ_SAFE_IDX + 7

smlua_audio_utils_replace_sequence(SEQ_AQUATIC_AMBIENCE, 42, 256, "mus_aquaticambience")
smlua_audio_utils_replace_sequence(SEQ_SNOWBOUND_LAND, 42, 256, "mus_snowboundland")
smlua_audio_utils_replace_sequence(SEQ_KROOKS_MARCH, 42, 256, "mus_krooksmarch")
smlua_audio_utils_replace_sequence(SEQ_WRINKLY_64, 42, 256, "mus_wrinkly64")
smlua_audio_utils_replace_sequence(SEQ_DK_ISLAND_SWING, 42, 256, "mus_jungle")
smlua_audio_utils_replace_sequence(SEQ_CROCODILE_CACOPHONY, 42, 256, "mus_crocodilecacophony")
smlua_audio_utils_replace_sequence(SEQ_GANGPLANK_GALLEON, 42, 256, "mus_gangplankgalleon")

--#endregion ---------------------------------------------------------------------------------------------------------------------------

--#region Actions ----------------------------------------------------------------------------------------------------------------------

ACT_DK_GRABBING_CHUNK = allocate_mario_action(ACT_GROUP_OBJECT | ACT_FLAG_STATIONARY)
ACT_DK_PUNCHING = allocate_mario_action(ACT_FLAG_STATIONARY | ACT_FLAG_ATTACKING)
ACT_DK_SLAM = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_ATTACKING)
ACT_DK_ROLL = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)
ACT_DK_WALL_CLIMB = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)
ACT_DK_CHUNK_SURFING = allocate_mario_action(ACT_FLAG_RIDING_SHELL | ACT_FLAG_ATTACKING)
ACT_DK_CHUNK_SWING = allocate_mario_action(ACT_FLAG_STATIONARY | ACT_FLAG_ATTACKING)
ACT_DK_CHUNK_THROWING = allocate_mario_action(ACT_GROUP_OBJECT | ACT_FLAG_MOVING | ACT_FLAG_THROWING)
ACT_DK_CHUNK_THROWING_AIR = allocate_mario_action(ACT_GROUP_OBJECT | ACT_FLAG_AIR | ACT_FLAG_THROWING)

--#endregion ---------------------------------------------------------------------------------------------------------------------------

--#region Anim Names -------------------------------------------------------------------------------------------------------------------

DK_ANIM_CLIMB = 'dk_climb'
DK_ANIM_CLIMBSLIDE = 'dk_climbslide'
DK_ANIM_CROUCH = 'dk_crouch'
DK_ANIM_CROUCHSTART = 'dk_crouchstart'
DK_ANIM_CROUCHSTOP = 'dk_crouchstop'
DK_ANIM_FLY = 'dk_fly'
DK_ANIM_FREEFALL_LAND = 'dk_freefall_land'
DK_ANIM_FREEFALL = 'dk_freefall'
DK_ANIM_GAMING = 'dk_gaming'
DK_ANIM_GAMING2 = 'dk_gaming2'
DK_ANIM_HANGLEFT = 'dk_hangleft'
DK_ANIM_HANGRIGHT = 'dk_hangright'
DK_ANIM_HANGSTART = 'dk_hangstart'
DK_ANIM_IDLE1 = 'dk_idle1'
DK_ANIM_IDLE2 = 'dk_idle2'
DK_ANIM_IDLE3 = 'dk_idle3'
DK_ANIM_IDLEFRONT = 'dk_idlefront'
DK_ANIM_JUMP = 'dk_jump'
DK_ANIM_JUMPANDLAND = 'dk_jumpandland'
DK_ANIM_JUMPFALL = 'dk_jumpfall'
DK_ANIM_JUMPLAND = 'dk_jumpland'
DK_ANIM_LEDGEGRAB = 'dk_ledgegrab'
DK_ANIM_LONGJUMPLAND = 'dk_longjumpland'
DK_ANIM_PICKUPROCKET = 'dk_pickuprocket'
DK_ANIM_ROLL = 'dk_roll'
DK_ANIM_RUN = 'dk_run'
DK_ANIM_SKID = 'dk_skid'
DK_ANIM_SKID_STOP = 'dk_skidstop'
DK_ANIM_SLAM = 'dk_slam'
DK_ANIM_STARDANCE_STOP = 'dk_stardance_stop'
DK_ANIM_STARDANCE = 'dk_stardance'
DK_ANIM_STARTGAME1 = 'dk_startgame1'
DK_ANIM_STARTGAME2 = 'dk_startgame2'
DK_ANIM_STARTGAME3 = 'dk_startgame3'
DK_ANIM_STARTGAME4 = 'dk_startgame4'
DK_ANIM_SWINGLEFT = 'dk_swingleft'
DK_ANIM_SWINGRIGHT = 'dk_swingright'
DK_ANIM_TIPTOE = 'dk_tiptoe'
DK_ANIM_WAKEUP = 'dk_wakeup'
DK_ANIM_WALK = 'dk_walk'

--#endregion ---------------------------------------------------------------------------------------------------------------------------

--#region CS Stuff ----------------------------------------------------------------------------------------------------------------------

local TEX_DK_LIFE_ICON = get_texture_info("DKlifeicon")
local TEX_DK_STAR_ICON = get_texture_info("DKstaricon")
local TEX_DK_GRAFFITI =  get_texture_info("DKgraffiti")
local COURSE_DK = {
    top = get_texture_info("dk-course-top"),
    bottom = get_texture_info("dk-course-bottom"),
}

local VOICETABLE_DK = {
	[CHAR_SOUND_OKEY_DOKEY] =		   {'dk_yahey.ogg','dk_okay.ogg'}, -- Starting game
	[CHAR_SOUND_LETS_A_GO] =		   'dk_yeah.ogg', -- Starting level
	[CHAR_SOUND_PUNCH_YAH] =		   'dk_hup.ogg', -- Punch 1
	[CHAR_SOUND_PUNCH_WAH] =		   'dk_grunt.ogg', -- Punch 2
	[CHAR_SOUND_PUNCH_HOO] =		   'dk_tch.ogg', -- Punch 3
	[CHAR_SOUND_YAH_WAH_HOO] =		   {'dk_hup.ogg', 'dk_hup2.ogg', 'dk_hup3.ogg','dk_yup.ogg'}, -- First Jump Sounds
	[CHAR_SOUND_HOOHOO] =			   {'dk_hup.ogg', 'dk_hup2.ogg', 'dk_hup3.ogg','dk_yup.ogg','dk_yup.ogg'}, -- Second jump sound
	[CHAR_SOUND_YAHOO_WAHA_YIPPEE] =   {'dk_yahey.ogg', 'dk_wahoo.ogg','dk_yoohoo.ogg'}, -- Triple jump sounds
	[CHAR_SOUND_UH] =				   {'dk_bonk.ogg','dk_hurt.ogg'}, -- Wall bonk
	[CHAR_SOUND_HAHA] =				   'dk_hehe.ogg', -- Landing triple jump
	[CHAR_SOUND_HAHA_2] =			   'dk_hehu.ogg', -- Landing in water after long fall
	[CHAR_SOUND_YAHOO] =			   {'dk_hup.ogg', 'dk_hup2.ogg', 'dk_hup3.ogg','dk_yup.ogg','dk_tch.ogg'}, -- Long jump
	[CHAR_SOUND_DOH] =				   'dk_bonk.ogg', -- Long jump wall bonk
	[CHAR_SOUND_WHOA] =				   'dk_grunt.ogg', -- Grabbing ledge
	[CHAR_SOUND_EEUH] =				   'dk_hrm.ogg', -- Climbing over ledge
	[CHAR_SOUND_WAAAOOOW] =			   {'dk_fall.ogg', 'dk_oowa.ogg'}, -- Falling a long distance
	[CHAR_SOUND_TWIRL_BOUNCE] =		   'dk_monkey.ogg', -- Bouncing off of a flower spring
	[CHAR_SOUND_GROUND_POUND_WAH] =	   'dk_grunt.ogg', 
	[CHAR_SOUND_HRMM] =				   'dk_hrm.ogg', -- Lifting something
	[CHAR_SOUND_HERE_WE_GO] =		   'dk_cool.ogg', -- Star get
	[CHAR_SOUND_SO_LONGA_BOWSER] =	   'dk_yodel.ogg', -- Throwing Bowser
	[CHAR_SOUND_ATTACKED] =			   {'dk_hurt.ogg','dk_hurt2.ogg','dk_hurt3.ogg'}, -- Damaged
	[CHAR_SOUND_OOOF] =				   'dk_hurt3.ogg', -- Grabbed
	[CHAR_SOUND_OOOF2] =			   {'dk_hurt.ogg','dk_hurt2.ogg'}, -- Landing during knockback
	[CHAR_SOUND_ON_FIRE] =			   'dk_eeyikes.ogg', -- Burned
	[CHAR_SOUND_SNORING1] =			   {'g1.ogg','g2.ogg','g3.ogg','g4.ogg','g5.ogg','g6.ogg','g7.ogg','g8.ogg','g9.ogg','g10.ogg'}, -- Snore Inhale
	[CHAR_SOUND_SNORING2] =			   {'g1.ogg','g2.ogg','g3.ogg','g4.ogg','g5.ogg','g6.ogg','g7.ogg','g8.ogg','g9.ogg','g10.ogg'}, -- Exhale
	[CHAR_SOUND_SNORING3] =			   {'g1.ogg','g2.ogg','g3.ogg','g4.ogg','g5.ogg','g6.ogg','g7.ogg','g8.ogg','g9.ogg','g10.ogg'}, -- Sleep talking / mumbling
}

local PALETTE_DK = {
	[PANTS]	 = "EC3193",
	[SHIRT]	 = "13F3FF",
	[GLOVES] = "ffffff",
	[SHOES]	 = "ffffff",
	[HAIR]	 = "603221",--"603323", 
	[SKIN]	 = "F3B78C", --"CDB28E",
	[CAP]	 = "D62B19",
	[EMBLEM] = "FFF700"
}

local PALETTE_DK_PANTS = {
	[PANTS]	 = "3B93B5",
	[SHIRT]	 = "13F3FF",
	[GLOVES] = "ffffff",
	[SHOES]	 = "ffffff",
	[HAIR]	 = "603221",--"603323", 
	[SKIN]	 = "F3B78C", --"CDB28E",
	[CAP]	 = "D62B19",
	[EMBLEM] = "FFF700"
}

local HEALTH_METER_DK = {
	label = {
		left = get_texture_info("DKhealthleft"),
		right = get_texture_info("DKhealthright"),
	},
	pie = {}
}

local ANIMTABLE_DK = {
	[_G.charSelect.CS_ANIM_MENU] = DK_ANIM_STARDANCE,
	[CHAR_ANIM_SKID_ON_GROUND] = DK_ANIM_SKID,
	[CHAR_ANIM_STOP_SKID] = DK_ANIM_SKID_STOP,
	[CHAR_ANIM_CROUCH_FROM_FAST_LONGJUMP] = DK_ANIM_LONGJUMPLAND,
	[CHAR_ANIM_CROUCH_FROM_SLOW_LONGJUMP] = DK_ANIM_LONGJUMPLAND,
	[CHAR_ANIM_IDLE_ON_LEDGE] = DK_ANIM_LEDGEGRAB,
	[CHAR_ANIM_HANG_ON_CEILING] = DK_ANIM_HANGSTART,
	[CHAR_ANIM_PUT_CAP_ON] = DK_ANIM_PICKUPROCKET,
	[CHAR_ANIM_WALKING]	= DK_ANIM_WALK,
	[CHAR_ANIM_LAND_FROM_DOUBLE_JUMP] = DK_ANIM_JUMPLAND,
	[CHAR_ANIM_DOUBLE_JUMP_FALL] = DK_ANIM_JUMPFALL,
	[CHAR_ANIM_SINGLE_JUMP] = DK_ANIM_JUMP,
	[CHAR_ANIM_LAND_FROM_SINGLE_JUMP] = DK_ANIM_JUMPANDLAND,
	[CHAR_ANIM_DOUBLE_JUMP_RISE] = DK_ANIM_JUMP,
	[CHAR_ANIM_GENERAL_FALL] = DK_ANIM_FREEFALL,
	[CHAR_ANIM_GENERAL_LAND] = DK_ANIM_FREEFALL_LAND,
	[CHAR_ANIM_MOVE_ON_WIRE_NET_RIGHT] = DK_ANIM_SWINGRIGHT,
	[CHAR_ANIM_MOVE_ON_WIRE_NET_LEFT] = DK_ANIM_SWINGLEFT,
	[CHAR_ANIM_FORWARD_SPINNING] = DK_ANIM_ROLL,
	[CHAR_ANIM_RUNNING] = DK_ANIM_RUN,
	[CHAR_ANIM_START_SLEEP_IDLE] = DK_ANIM_STARTGAME1,
	[CHAR_ANIM_START_SLEEP_SCRATCH] = DK_ANIM_STARTGAME2,
	[CHAR_ANIM_START_SLEEP_YAWN] = DK_ANIM_STARTGAME3,
	[CHAR_ANIM_START_SLEEP_SITTING] = DK_ANIM_STARTGAME4,
	[CHAR_ANIM_SLEEP_IDLE] = DK_ANIM_GAMING,
	[CHAR_ANIM_SLEEP_START_LYING] = DK_ANIM_GAMING2,
	[CHAR_ANIM_SLEEP_LYING] = DK_ANIM_GAMING2,
	[CHAR_ANIM_TIPTOE] = DK_ANIM_TIPTOE,
	[CHAR_ANIM_STOP_CROUCHING] = DK_ANIM_CROUCHSTOP,
	[CHAR_ANIM_START_CROUCHING]	= DK_ANIM_CROUCHSTART,
	[CHAR_ANIM_CROUCHING] = DK_ANIM_CROUCH,
	[CHAR_ANIM_FIRST_PERSON] = DK_ANIM_IDLEFRONT,
	[CHAR_ANIM_IDLE_HEAD_LEFT] = DK_ANIM_IDLE1,
	[CHAR_ANIM_IDLE_HEAD_RIGHT] = DK_ANIM_IDLE2,
	[CHAR_ANIM_IDLE_HEAD_CENTER] = DK_ANIM_IDLE3,
	[CHAR_ANIM_HANDSTAND_LEFT] = DK_ANIM_HANGLEFT,
	[CHAR_ANIM_HANDSTAND_RIGHT]	= DK_ANIM_HANGRIGHT,
	[CHAR_ANIM_WAKE_FROM_SLEEP] = DK_ANIM_WAKEUP,
	[CHAR_ANIM_WAKE_FROM_LYING] = DK_ANIM_WAKEUP,
	[CHAR_ANIM_START_TIPTOE] = DK_ANIM_TIPTOE,
	[CHAR_ANIM_STAR_DANCE] = DK_ANIM_STARDANCE,
	[CHAR_ANIM_RETURN_FROM_STAR_DANCE] = DK_ANIM_STARDANCE_STOP
}

CT_DK = _G.charSelect.character_add(
    "Donkey Kong",    -- Character Name
    "Oh Banana!",     -- Description
    "SwagSkeleton95",       -- Credits
    "7e3b19",               -- Menu Color
    E_MODEL_DK,            -- Character Model
    CT_MARIO,               -- Override Character
    TEX_DK_LIFE_ICON,      -- Life Icon
    1.4,                    -- Camera Scale
    0                       -- Vertical Offset
)

CT_SDKPANTS = _G.charSelect.character_add_costume(
    CT_DK,
    "Donkey Kong",      -- Character Name
    "Pants?? COOL",     -- Description
    "SwagSkeleton95",       -- Credits
    "7e3b19",               -- Menu Color
    E_MODEL_DK_PANTS,      -- Character Model
    CT_MARIO,               -- Override Character
    TEX_DK_LIFE_ICON,      -- Life Icon
    1.4,                    -- Camera Scale
    0                       -- Vertical Offset
)

_G.charSelect.character_add_animations(E_MODEL_DK, ANIMTABLE_DK)
_G.charSelect.character_add_animations(E_MODEL_DK_PANTS, ANIMTABLE_DK)
_G.charSelect.character_add_voice(E_MODEL_DK, VOICETABLE_DK)
_G.charSelect.character_add_voice(E_MODEL_DK_PANTS, VOICETABLE_DK)
_G.charSelect.character_add_celebration_star(E_MODEL_DK, E_MODEL_STAR_BANANA, TEX_DK_STAR_ICON)
_G.charSelect.character_add_celebration_star(E_MODEL_DK_PANTS, E_MODEL_STAR_BANANA, TEX_DK_STAR_ICON)
_G.charSelect.character_add_palette_preset(E_MODEL_DK, PALETTE_DK, "Default")
_G.charSelect.character_add_palette_preset(E_MODEL_DK_PANTS, PALETTE_DK_PANTS, "Default")
_G.charSelect.character_add_health_meter(CT_DK, HEALTH_METER_DK)
_G.charSelect.character_add_costume_health_meter(CT_DK, 2, HEALTH_METER_DK)
_G.charSelect.character_add_menu_instrumental(CT_DK, STREAM_DKRAP)
_G.charSelect.character_add_graffiti(CT_DK, TEX_DK_GRAFFITI)
_G.charSelect.character_add_course_texture(CT_DK, COURSE_DK)
_G.charSelect.config_character_sounds()

-- Adds credits to the credits menu
local TEXT_MOD_NAME = 'Bananza Kong'

_G.charSelect.credit_add(TEXT_MOD_NAME, "SwagSkeleton95", "Models")
_G.charSelect.credit_add(TEXT_MOD_NAME, "SwagSkeleton95", "Animations")
_G.charSelect.credit_add(TEXT_MOD_NAME, "ProfeJavix", "General Coding")
_G.charSelect.credit_add(TEXT_MOD_NAME, "ProfeJavix", "Moveset")
_G.charSelect.credit_add(TEXT_MOD_NAME, "ProfeJavix", "Chunk Model")
_G.charSelect.credit_add(TEXT_MOD_NAME, "Baconator2558", "Coding Help")
_G.charSelect.credit_add(TEXT_MOD_NAME, "Baconator2558", "Health Meter")
_G.charSelect.credit_add(TEXT_MOD_NAME, "Baconator2558", "Star Select Texture")
_G.charSelect.credit_add(TEXT_MOD_NAME, "PeachyPeach", "Coding Help")
_G.charSelect.credit_add(TEXT_MOD_NAME, "ManIscat2", "Coding Help")
_G.charSelect.credit_add(TEXT_MOD_NAME, "ManIscat2", "Fast64 Help")
_G.charSelect.credit_add(TEXT_MOD_NAME, "SullyBoy", "DK Music")

--#endregion ---------------------------------------------------------------------------------------------------------------------------