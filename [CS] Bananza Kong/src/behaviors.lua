--#region Localizations ---------------------------------------------------------------------

local abs_angle_diff = abs_angle_diff
local audio_sample_play = audio_sample_play
local bhv_spawn_star_no_level_exit = bhv_spawn_star_no_level_exit
local cur_obj_become_intangible = cur_obj_become_intangible
local cur_obj_hide = cur_obj_hide
local cur_obj_move_standard = cur_obj_move_standard
local cur_obj_play_sound_1 = cur_obj_play_sound_1
local cur_obj_unhide = cur_obj_unhide
local cur_obj_update_floor = cur_obj_update_floor
local cur_obj_update_floor_and_walls = cur_obj_update_floor_and_walls
local degrees_to_sm64 = degrees_to_sm64
local dist_between_objects = dist_between_objects
local get_current_save_file_num = get_current_save_file_num
local get_hand_foot_pos_x = get_hand_foot_pos_x
local get_hand_foot_pos_y = get_hand_foot_pos_y
local get_hand_foot_pos_z = get_hand_foot_pos_z
local linear_mtxf_mul_vec3f = linear_mtxf_mul_vec3f
local mtxf_rotate_zxy_and_translate = mtxf_rotate_zxy_and_translate
local network_init_object = network_init_object
local obj_angle_to_object = obj_angle_to_object
local obj_compute_vel_from_move_pitch = obj_compute_vel_from_move_pitch
local obj_has_model_extended = obj_has_model_extended
local obj_mark_for_deletion = obj_mark_for_deletion
local obj_pitch_to_object = obj_pitch_to_object
local obj_set_gfx_pos_from_pos = obj_set_gfx_pos_from_pos
local obj_set_model_extended = obj_set_model_extended
local obj_set_pos = obj_set_pos
local play_sound = play_sound
local play_sound_with_freq_scale = play_sound_with_freq_scale
local save_file_get_star_flags = save_file_get_star_flags
local set_camera_shake_from_point = set_camera_shake_from_point
local spawn_mist_particles = spawn_mist_particles
local spawn_non_sync_object = spawn_non_sync_object
local spawn_sync_object = spawn_sync_object
local spawn_triangle_break_particles = spawn_triangle_break_particles
local vec3f_add = vec3f_add

--#endregion --------------------------------------------------------------------------------

local states = gMarioStates
local playerTable = gPlayerSyncTable

local bhvs = {}

local CHUNK_ACT_HELD = 0
local CHUNK_ACT_SURF = 1
local CHUNK_ACT_THROWN = 2
local CHUNK_ACT_DROPPED = 3
local CHUNK_ACT_BREAK = 4

---@param o Object
function bhvs.bhv_held_chunk_init(o)
	o.oFlags = o.oFlags | OBJ_FLAG_HOLDABLE

	o.oInteractType = INTERACT_GRABBABLE

	if getLocalFromGlobalIdx(o.oChunkOwner) == 0 then
		local realChunk = spawn_sync_object(id_bhvChunk, E_MODEL_CHUNK, o.oPosX, o.oPosY, o.oPosZ, function(c)
			c.oChunkOwner = o.oChunkOwner
		end)
		realChunk.parentObj = o
	end

	network_init_object(o, true, {'oHeldState', 'oTimer', 'oChunkOwner'})
end

---@param o Object
function bhvs.bhv_held_chunk_loop(o)
	--this sucks, but I don't know how to manipulate held gfx pos
	cur_obj_become_intangible()
	cur_obj_hide()

	if o.oHeldState == HELD_HELD then
		o.oTimer = 0
		obj_set_model_extended(o, E_MODEL_HELD_CHUNK)
	else
		obj_mark_for_deletion(o)
	end
end

---@param o Object
function bhvs.bhv_chunk_init(o)
	o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE

	local hb = get_temp_object_hitbox()

	hb.interactType = INTERACT_DAMAGE
	hb.radius = 150
	hb.height = 200
	hb.hurtboxRadius = 100
	hb.hurtboxHeight = 180
	hb.downOffset = 50
	hb.damageOrCoinValue = 4
	hb.numLootCoins = 0

	o.oWallHitboxRadius = 100

	obj_set_hitbox(o, hb)
	cur_obj_become_intangible()
	cur_obj_hide()

	network_init_object(o, true,
		{
			'oAction',
			'oSubAction',
			'oTimer',
			'oMoveAngleYaw',
			'oMoveAnglePitch',
			'oChunkOwner'
		}
	)
end

---@param o Object
function bhvs.bhv_chunk_loop(o)

	local m = states[getLocalFromGlobalIdx(o.oChunkOwner)]

	local shouldBreak = false
	cur_obj_become_intangible()
	cur_obj_unhide()

	if o.oAction == CHUNK_ACT_HELD then

		cur_obj_hide()

		if not m or (o.parentObj.activeFlags == ACTIVE_FLAG_DEACTIVATED and o.oTimer > 1) then
			o.oAction = CHUNK_ACT_DROPPED
			return
		elseif m.action == ACT_DK_CHUNK_SURFING then
			o.oAction = CHUNK_ACT_SURF
			return
		elseif o.parentObj.oHeldState == HELD_THROWN then
			o.oTimer = 0
			o.oAction = CHUNK_ACT_THROWN
			return
		elseif m.action == ACT_DK_CHUNK_SWING then

			if chunkHitObject(o) then
				shouldBreak = true
			end
		end

		local pos = {
			x = get_hand_foot_pos_x(m, 0),
			y = get_hand_foot_pos_y(m, 0),
			z = get_hand_foot_pos_z(m, 0)
		}

		local mat4 = gMat4Identity()
		local rotated = gVec3fZero()
		mtxf_rotate_zxy_and_translate(mat4, gVec3fZero(), m.faceAngle)
		linear_mtxf_mul_vec3f(mat4, rotated, { x = 100, y = -40, z = 50})
		vec3f_add(pos, rotated)

		obj_set_pos(o, pos.x, pos.y, pos.z)
		o.oFaceAngleYaw = m.faceAngle.y
	elseif o.oAction == CHUNK_ACT_SURF then

		if o.oTimer % 2 == 0 then
			audio_sample_play(SOUND_DRUM, o.header.gfx.cameraToObject, 0.3)
		end

		obj_set_pos(o, m.pos.x, m.pos.y + 50, m.pos.z)
		o.oFaceAngleYaw = o.oFaceAngleYaw - 0x2000

		if m.action ~= ACT_DK_CHUNK_SURFING then
			shouldBreak = true
		end

	elseif o.oAction == CHUNK_ACT_THROWN then

		if o.oSubAction == 0 then

			local target, dist = nearestChunkTarget(o)

			if target and dist < 3000 then
				o.oMoveAngleYaw = obj_angle_to_object(o, target)
				local curYPos = target.oPosY
				target.oPosY = target.oPosY + target.hitboxHeight / 2
				o.oMoveAnglePitch = obj_pitch_to_object(o, target)
				target.oPosY = curYPos
			else
				o.oMoveAngleYaw = o.oFaceAngleYaw
				o.oMoveAnglePitch = 0
			end

			obj_compute_vel_from_move_pitch(120)
			o.oForwardVel = 120
			o.oSubAction = 1
		end

		if o.oTimer > 10 then
			o.oGravity = -2
		end

		o.oFaceAngleYaw = o.oFaceAngleYaw - 0x1200
		o.oFaceAnglePitch = o.oFaceAnglePitch + 0x200

		if o.oTimer % 10 == 0 then
			cur_obj_play_sound_1(SOUND_ACTION_SPIN)
		end

		cur_obj_move_standard(-78)
		cur_obj_update_floor_and_walls()

		chunkHitObject(o)

		if o.oMoveFlags & (OBJ_MOVE_HIT_WALL | OBJ_MOVE_LANDED) ~= 0 then
			shouldBreak = true
		end
	elseif o.oAction == CHUNK_ACT_DROPPED then
		o.oVelY = -30
		cur_obj_update_floor()
		cur_obj_move_standard(78)
		chunkHitObject(o)

		o.oFaceAngleRoll = o.oFaceAngleRoll - 0x1000

		if o.oMoveFlags & (OBJ_MOVE_LANDED | OBJ_MOVE_UNDERWATER_ON_GROUND) ~= 0 then
			shouldBreak = true
		end
	elseif o.oAction == CHUNK_ACT_BREAK then
		obj_mark_for_deletion(o.parentObj)

		if m and m.action == ACT_DK_CHUNK_SWING then
			m.heldObj = nil
		end

		spawn_mist_particles()
		spawn_triangle_break_particles(20, 138, 0.7, 3)
		audio_sample_play(SOUND_BARREL_BREAK, o.header.gfx.cameraToObject, 15)
		obj_mark_for_deletion(o)
	end
	obj_set_gfx_pos_from_pos(o)

	if shouldBreak or o.oInteractStatus & INT_STATUS_INTERACTED ~= 0 then

			o.oAction = CHUNK_ACT_BREAK

			if m and o.parentObj == m.heldObj then
				playerTable[m.playerIndex].heldChunkAct = 2
			end
	end
end

function star_is_collected(starId)
	local gCurrCourseNum = gNetworkPlayers[0].currCourseNum
	local starflags = save_file_get_star_flags(get_current_save_file_num() - 1, gCurrCourseNum - 1)

	if starflags & (1 << starId) ~= 0 then
		return true
	end
	return false
end

---@param o Object
function bhvs.bhv_star_loop(o)
	if isDK(0) then
		if obj_has_model_extended(o, E_MODEL_STAR) ~= 0 then
			obj_set_model_extended(o, E_MODEL_STAR_BANANA)
		elseif obj_has_model_extended(o, E_MODEL_TRANSPARENT_STAR) ~= 0 then
			obj_set_model_extended(o, E_MODEL_TRANSPARENT_STAR_BANANA)
		end
	else
		if obj_has_model_extended(o, E_MODEL_STAR_BANANA) ~= 0 then
			obj_set_model_extended(o, E_MODEL_STAR)
		elseif obj_has_model_extended(o, E_MODEL_TRANSPARENT_STAR_BANANA) ~= 0 then
			obj_set_model_extended(o, E_MODEL_TRANSPARENT_STAR)
		end
	end
end

---@param o Object
function bhv_coin_loop(o)
	-- credit to ManIsCat2
	if isDK(0) then
		if obj_has_model_extended(o, E_MODEL_YELLOW_COIN) then
			obj_set_model_extended(o, E_MODEL_YELLOW_BANANA_COIN_NO_SHADOW)
		elseif obj_has_model_extended(o, E_MODEL_YELLOW_COIN_NO_SHADOW) then
			obj_set_model_extended(o, E_MODEL_YELLOW_BANANA_COIN_NO_SHADOW)
		else
			return
		end
	else
		if obj_has_model_extended(o, E_MODEL_YELLOW_BANANA_COIN) then
			obj_set_model_extended(o, E_MODEL_YELLOW_COIN)
		elseif obj_has_model_extended(o, E_MODEL_YELLOW_BANANA_COIN_NO_SHADOW) then
			obj_set_model_extended(o, E_MODEL_YELLOW_COIN_NO_SHADOW)
		else
			return
		end
	end
end

---@param o Object
function bhvs.bhv_bowser_body_anchor_loop(o)
	local bowser = o.parentObj
	if not bowser or bowser.oHeldState ~= HELD_FREE or (bowser.oAction > 1 and bowser.oAction <= 6) or bowser.oAction >= 19 then return end

	local m = states[0]

	if m.action == ACT_DK_PUNCHING and m.flags & MARIO_PUNCHING ~= 0 and
	dist_between_objects(o, m.marioObj) <= 400 and
	abs_angle_diff(m.faceAngle.y, obj_angle_to_object(m.marioObj, o)) < degrees_to_sm64(140) then

		play_sound(SOUND_GENERAL_WALL_EXPLOSION, m.pos)
		spawn_non_sync_object(id_bhvVertStarParticleSpawner, E_MODEL_NONE, m.pos.x, m.pos.y, m.pos.z, function()end)
		set_camera_shake_from_point(SHAKE_POS_MEDIUM, m.pos.x, m.pos.y, m.pos.z)

		bowser.oForwardVel = 260
		bowser.oVelY = 70
		bowser.oMoveAngleYaw = m.faceAngle.y

		o.oEnemyLakituBlinkTimer = 1
	end

	if o.oEnemyLakituBlinkTimer == 1 then

		bowser.oAction = 1
		o.oEnemyLakituBlinkTimer = 0
	end
end

---@param o Object
function bhvs.bhv_toad_message_loop(o)

	if o.oToadMessageState == 4 then return end

	local m = states[0]
	if m.action == ACT_DK_PUNCHING and m.flags & MARIO_PUNCHING ~= 0 and
	o.oDistanceToMario <= 180 and
	abs_angle_diff(m.faceAngle.y, obj_angle_to_object(m.marioObj, o)) < degrees_to_sm64(80) then
		o.oEnemyLakituBlinkTimer = 1
	end

	if o.oEnemyLakituBlinkTimer == 1 then
		local dialogId = o.oToadMessageDialogId
		if dialogId == gBehaviorValues.dialogs.ToadStar1Dialog then
			bhv_spawn_star_no_level_exit(m.marioObj, 0, 1)
		elseif dialogId == gBehaviorValues.dialogs.ToadStar2Dialog then
			bhv_spawn_star_no_level_exit(m.marioObj, 1, 1)
		elseif dialogId == gBehaviorValues.dialogs.ToadStar3Dialog then
			bhv_spawn_star_no_level_exit(m.marioObj, 2, 1)
		end

		o.oEnemyLakituBlinkTimer = 0

		local toadChar = gCharacters[CT_TOAD]
		spawn_mist_particles()
		play_sound(SOUND_GENERAL_BOWSER_BOMB_EXPLOSION, m.pos)
		play_sound_with_freq_scale(toadChar.sounds[CHAR_SOUND_GROUND_POUND_WAH], o.header.gfx.cameraToObject, toadChar.soundFreqScale)

		obj_mark_for_deletion(o)
	end
end

---@param o Object
function bhvs.bhv_small_penguin_loop(o)
	if o.oEnemyLakituBlinkTimer == 1 then
		o.oTimer = 0
		o.oAction = 10
		o.oEnemyLakituBlinkTimer = 0
	end

	if o.oAction == 10 then
		o.oMoveAngleYaw = o.oMoveAngleYaw + 0x1000
		o.oForwardVel = 0
		o.oVelY = 0

		if o.oTimer % 30 == 0 then
			play_sound(SOUND_OBJ2_BABY_PENGUIN_YELL, o.header.gfx.cameraToObject)
		end

		if o.oTimer > 150 then
			o.oSmallPenguinUnk88 = 1
		end
	end
end

return bhvs