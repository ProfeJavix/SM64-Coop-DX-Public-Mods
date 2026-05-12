--#region Localizations ---------------------------------------------------------------------

local abs_angle_diff = abs_angle_diff
local approach_s16_symmetric = approach_s16_symmetric
local atan2s = atan2s
local audio_sample_play = audio_sample_play
local audio_stream_play = audio_stream_play
local clamp = math.clamp
local degrees_to_sm64 = degrees_to_sm64
local djui_chat_message_create = djui_chat_message_create
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_get_screen_width = djui_hud_get_screen_width
local djui_hud_render_rect = djui_hud_render_rect
local djui_hud_render_rect_interpolated = djui_hud_render_rect_interpolated
local djui_hud_set_color = djui_hud_set_color
local mario_drop_held_object = mario_drop_held_object
local min = math.min
local mod_storage_save_bool = mod_storage_save_bool
local obj_has_behavior_id = obj_has_behavior_id
local obj_mark_for_deletion = obj_mark_for_deletion
local random = math.random
local s16 = math.s16
local set_mario_action = set_mario_action
local spawn_mist_particles_variable = spawn_mist_particles_variable
local spawn_triangle_break_particles = spawn_triangle_break_particles

--#endregion --------------------------------------------------------------------------------

local hooks = {}

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable

function hooks.update()
	for_each_object_with_behavior(id_bhvYellowCoin, bhv_coin_loop)
	for_each_object_with_behavior(id_bhvMovingYellowCoin, bhv_coin_loop)
	for_each_object_with_behavior(id_bhvMoneybagHidden, bhv_coin_loop)
end

---@param m MarioState
---@param o Object
function hooks.allow_interact(m, o)
	if obj_has_behavior_id(o, id_bhvChunk) ~= 0 and o.oChunkOwner == nps[m.playerIndex].globalIndex then
		return false
	end
end

---@param sound integer
---@return integer|nil
function hooks.on_play_sound(sound)
	if isDK(0) then
		if sound == SOUND_GENERAL_COIN or sound == SOUND_GENERAL_COIN_WATER then
			if random(0,1) == 1 then
				audio_sample_play(SOUND_BANANA1, gMarioStates[0].pos, 0.7)
				return 0
			else
				audio_sample_play(SOUND_BANANA2, gMarioStates[0].pos, 0.7)
				return 0
			end
		end
	end
end

---@param seq integer
function hooks.on_seq_load(_, seq)

	if not isDK(0) then return end

	if seq == SEQ_EVENT_CUTSCENE_STAR_SPAWN then
		audio_stream_play(STREAM_OHBANANA, true, 1.0)
		return 0
	end

	if seq == SEQ_EVENT_CUTSCENE_COLLECT_STAR then
		audio_stream_play(STREAM_COLLECT_BANANA, true, 1.0)
		return 0
	end

	local musiclist = {
		[SEQ_LEVEL_GRASS] = SEQ_DK_ISLAND_SWING,
		[SEQ_LEVEL_WATER] = SEQ_AQUATIC_AMBIENCE,
		[SEQ_LEVEL_SNOW] = SEQ_SNOWBOUND_LAND,
		[SEQ_LEVEL_KOOPA_ROAD] = SEQ_KROOKS_MARCH,
		[SEQ_LEVEL_INSIDE_CASTLE] = SEQ_WRINKLY_64,
		[SEQ_LEVEL_BOSS_KOOPA] = SEQ_CROCODILE_CACOPHONY,
	}

	if dkmusic then
		if musiclist[seq] ~= nil then
			return musiclist[seq]
		end
	end
end

local DK_ACTS = {
	[ACT_DK_GRABBING_CHUNK] = true,
	[ACT_DK_PUNCHING] = true,
	[ACT_DK_SLAM] = true,
	[ACT_DK_ROLL] = true,
	[ACT_DK_WALL_CLIMB] = true,
	[ACT_DK_CHUNK_SURFING] = true,
	[ACT_DK_CHUNK_SWING] = true,
	[ACT_DK_CHUNK_THROWING] = true,
	[ACT_DK_CHUNK_THROWING_AIR] = true
}

---@param m MarioState
---@param surfaceType integer
function hooks.allow_hazard_surface(m, surfaceType)
	if DK_ACTS[m.action] and m.floorHeight ~= m.pos.y and
	(surfaceType == HAZARD_TYPE_LAVA_FLOOR or surfaceType == HAZARD_TYPE_QUICKSAND) then
		return false
	end
end

local NO_DK_ACT_FLAG = (
	ACT_GROUP_CUTSCENE |
	ACT_FLAG_INVULNERABLE |
	ACT_FLAG_THROWING |
	ACT_FLAG_RIDING_SHELL |
	ACT_FLAG_SWIMMING_OR_FLYING |
	ACT_FLAG_BUTT_OR_STOMACH_SLIDE
)

---@param m MarioState
function hooks.cs_dk_before_mario_update(m)
	if _G.charSelect.get_options_status(6) ~= 0 then
		--[[ if m.action & ACT_FLAG_SHORT_HITBOX ~= 0 then
			m.marioObj.hitboxHeight = 100
			m.marioObj.hurtboxHeight = 100
		else
			m.marioObj.hitboxHeight = 200
			m.marioObj.hurtboxHeight = 200
		end ]]

		m.marioObj.hitboxRadius = 100
		m.marioObj.hurtboxRadius = 100

		if m.heldObj ~= nil and obj_has_behavior_id(m.heldObj, id_bhvBobomb) ~= 0 then
			m.heldObj.oIntangibleTimer = -1
		end
	end

	if isHoldingChunk(m) then

		if m.action & ACT_FLAG_SWIMMING ~= 0 then
			return drop_and_set_mario_action(m, ACT_WATER_IDLE, 0)
		end

		if m.controller.buttonPressed & B_BUTTON ~= 0 then
			m.controller.buttonPressed = m.controller.buttonPressed & ~B_BUTTON
			playerTable[m.playerIndex].heldChunkAct = 2
			playerTable[m.playerIndex].slamCharge = -5
			return
		end

		if m.controller.buttonPressed & Z_TRIG ~= 0 then
			m.controller.buttonPressed = m.controller.buttonPressed & ~Z_TRIG
			m.controller.buttonDown = m.controller.buttonDown & ~Z_TRIG

			if m.action ~= ACT_DK_CHUNK_SURFING then
				playerTable[m.playerIndex].heldChunkAct = 1
			end
		end
	end
end

---@param m MarioState
function hooks.cs_dk_mario_update(m)

	m.peakHeight = m.pos.y

	if (m.action == ACT_SLEEPING) or (m.action == ACT_START_SLEEPING) then
        m.marioBodyState.eyeState = 0
    end

	if m.action == ACT_JUMP or m.action == ACT_DOUBLE_JUMP then
        m.faceAngle.y = approach_s16_symmetric(m.faceAngle.y, m.intendedYaw, 0x350)
    end

	if m.action == ACT_FLYING then
		spawn_non_sync_object(id_bhvSparkleParticleSpawner, E_MODEL_SMOKE, m.pos.x, m.pos.y + 50, m.pos.z, function()end)
	end

	handleDKLook(m)

	if m.action & NO_DK_ACT_FLAG ~= 0 or DK_ACTS[m.action] then return end

	if isHoldingChunk(m) then

		if playerTable[m.playerIndex].heldChunkAct == 1 then
			playerTable[m.playerIndex].heldChunkAct = 0
			return set_mario_action(m, ACT_DK_CHUNK_SURFING, 0)
		end

		if m.controller.buttonPressed & Y_BUTTON ~= 0 then
			return set_mario_action(m, ACT_DK_CHUNK_SWING, 0)
		end

		if m.controller.buttonPressed & X_BUTTON ~= 0 then
			return set_mario_action(m, ternary(m.pos.y == m.floorHeight, ACT_DK_CHUNK_THROWING, ACT_DK_CHUNK_THROWING_AIR), 0)
		end

		if playerTable[m.playerIndex].heldChunkAct == 2 then
			mario_drop_held_object(m)
			playerTable[m.playerIndex].heldChunkAct = 0
			return set_mario_action(m, ternary(m.pos.y == m.floorHeight, ACT_WALKING, ACT_FREEFALL), 0)
		end
	else
		if m.wall and not m.wall.object and m.intendedMag > 15 then
			local wallAngle = s16(atan2s(m.wallNormal.z, m.wallNormal.x) - 0x8000)
			if abs_angle_diff(m.intendedYaw, wallAngle) < degrees_to_sm64(30) then
				return set_mario_action(m, ACT_DK_WALL_CLIMB, 0)
			end
		end

		if m.controller.buttonPressed & X_BUTTON ~= 0 and m.floorHeight == m.pos.y then
			playerTable[0].slamCharge = 0
			return set_mario_action(m, ACT_DK_GRABBING_CHUNK, 0)
		end

		if m.controller.buttonPressed & Y_BUTTON ~= 0 and m.action ~= ACT_BEGIN_SLIDING then
			return set_mario_action(m, ACT_DK_PUNCHING, 0)
		end

		if m.controller.buttonDown & B_BUTTON ~= 0 then
			if m.playerIndex == 0 and playerTable[0].slamCharge >= 0 then
				playerTable[0].slamCharge = min(playerTable[0].slamCharge + 1, 90)
			end
		elseif m.controller.buttonReleased & B_BUTTON ~= 0 then
			if playerTable[m.playerIndex].slamCharge >= 0 then

				local arg = 0
				local charge = playerTable[m.playerIndex].slamCharge / 90
				if charge >= 0.66 then
					arg = 2
				elseif charge >= 0.33 then
					arg = 1
				end

				set_mario_action(m, ACT_DK_SLAM, arg)
			end
		else
			playerTable[m.playerIndex].slamCharge = 0
		end

		if m.controller.buttonPressed & Z_TRIG ~= 0 and m.forwardVel > 10 then
			return set_mario_action(m, ACT_DK_ROLL, 0)
		end
	end
end

---@param o Object
function hooks.cs_dk_on_interact(_, o)
	if (obj_has_behavior_id(o, id_bhvMetalCap) ~= 0 or obj_has_behavior_id(o, id_bhvVanishCap) ~= 0) then
		spawn_mist_particles_variable(0, 0, 46)
		spawn_triangle_break_particles(30, 138, 3.0, 4)
		obj_mark_for_deletion(o)
	end
end

---@param m MarioState
function hooks.cs_dk_on_set_mario_action(m)
	m.marioBodyState.allowPartRotation = 0

	if m.prevAction == ACT_DK_ROLL and m.action == ACT_LONG_JUMP then
		mario_set_forward_vel(m, playerTable[m.playerIndex].rollJumpSpeed)
	end
	playerTable[m.playerIndex].rollJumpSpeed = 0
end

local ignoreActs = {
	[ACT_DIVE] = true,
	[ACT_GROUND_POUND] = true,
	[ACT_JUMP_KICK] = true,
	[ACT_MOVE_PUNCHING] = true,
	[ACT_PUNCHING] = true,
	[ACT_SLIDE_KICK] = true
}

---@param incAct integer
function hooks.cs_dk_before_set_mario_action(_, incAct)
	if ignoreActs[incAct] then
		return 1
	end
end

---@param a MarioState
function hooks.cs_dk_allow_pvp_attack(a)
	if a.action == ACT_DK_CHUNK_SWING then
		return false
	end
end

---@param a MarioState
---@param v MarioState
function hooks.cs_dk_on_pvp_attack(a, v)
	if a.action == ACT_DK_SLAM then
		v.hurtCounter = 4 * (6 * clamp(playerTable[a.playerIndex].slamCharge / 90, 0.3, 1))
	elseif a.action == ACT_DK_PUNCHING then
		v.hurtCounter = 2 * 4
	elseif a.action == ACT_DK_CHUNK_SURFING then
		v.hurtCounter = 1 * 4
	elseif a.action == ACT_DK_ROLL then
		v.hurtCounter = 0
	end
end

local prev = {x = 0, y = 0, wdth = 0}
function hooks.cs_dk_on_hud_render_behind()

	if states[0].action & NO_DK_ACT_FLAG ~= 0 then return end

	if playerTable[0].slamCharge > 0 then

		if states[0].controller.buttonDown & B_BUTTON ~= 0 and playerTable[0].slamCharge % 4 == 0 then
			audio_sample_play(SOUND_BOUNCE3, gGlobalSoundSource, 0.5)
		end

		local x = djui_hud_get_screen_width() / 2 - 100
		local y = djui_hud_get_screen_height() - 30
		local wdth = 200 * playerTable[0].slamCharge / 90

		djui_hud_set_color(0, 0, 0, 240)
		djui_hud_render_rect(x - 5, y - 5, 210, 20)

		djui_hud_set_color(240, 0, 0, 240)
		djui_hud_render_rect_interpolated(prev.x, prev.y, prev.wdth, 10, x, y, wdth, 10)

		prev = {x = x, y = y, wdth = wdth}
	else
		prev = {x = 0, y = 0, wdth = 0}
	end
end

---@return boolean
function hooks.cmd_dk_moveset(_)
    djui_chat_message_create('DK MOVESET:')

	djui_chat_message_create('')
	djui_chat_message_create('No chunk:')
	djui_chat_message_create('-\\#dec620\\Y Button\\#fff\\ to punch. Can be spammed')
	djui_chat_message_create('-\\#7ad939\\B Button\\#fff\\ to ground slam (acts as a ground pound). Hold to charge and deal more damage.')
	djui_chat_message_create('-Hold \\#888\\Z Trigger\\#fff\\ to roll. Jump or punch to cancel and keep inertia.')
	djui_chat_message_create('-Go into a wall to climb it. Use Left Stick to move, \\#5168f4\\A Button\\#fff\\ to wall kick or \\#888\\Z Trigger\\#fff\\ to fall.')
	djui_chat_message_create('-\\#37c2ff\\X Button\\#fff\\ on ground to grab a chunk from the floor.')

	djui_chat_message_create('')
	djui_chat_message_create('Chunk:')
	djui_chat_message_create('-\\#dec620\\Y Button\\#fff\\ to swing the chunk and hit foes. Breaks on contact.')
	djui_chat_message_create('-\\#888\\Z Trigger\\#fff\\ to surf the chunk. Press \\#5168f4\\A Button\\#fff\\ to jump from ground and a second time to double jump (this breaks the chunk) and \\#37c2ff\\X Button\\#fff\\ to stop surfing.')
	djui_chat_message_create('-\\#37c2ff\\X Button\\#fff\\ to throw the chunk. Can be done in air.')
	djui_chat_message_create('-\\#7ad939\\B Button\\#fff\\ to drop the chunk.')
	return true
end

function hooks.mm_checkbox_dkmusic(_, val)
	dkmusic = val
	mod_storage_save_bool("dkmusic", dkmusic)
end

return hooks
