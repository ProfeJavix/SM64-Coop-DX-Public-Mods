--#region Localizations ---------------------------------------------------------------------

local abs = math.abs
local abs_angle_diff = abs_angle_diff
local adjust_sound_for_speed = adjust_sound_for_speed
local animated_stationary_ground_step = animated_stationary_ground_step
local apply_slope_accel = apply_slope_accel
local approach_f32_symmetric = approach_f32_symmetric
local approach_s16_symmetric = approach_s16_symmetric
local atan2s = atan2s
local audio_sample_play = audio_sample_play
local coss = coss
local cur_obj_check_anim_frame = cur_obj_check_anim_frame
local degrees_to_sm64 = degrees_to_sm64
local drop_and_set_mario_action = drop_and_set_mario_action
local find_floor_height = find_floor_height
local is_anim_at_end = is_anim_at_end
local is_anim_past_end = is_anim_past_end
local is_anim_past_frame = is_anim_past_frame
local lava_boost_on_wall = lava_boost_on_wall
local mario_drop_held_object = mario_drop_held_object
local mario_get_collided_object = mario_get_collided_object
local mario_grab_used_object = mario_grab_used_object
local mario_obj_angle_to_object = mario_obj_angle_to_object
local mario_set_forward_vel = mario_set_forward_vel
local mario_throw_held_object = mario_throw_held_object
local max = math.max
local obj_has_behavior_id = obj_has_behavior_id
local obj_set_gfx_pos = obj_set_gfx_pos
local perform_air_step = perform_air_step
local perform_ground_step = perform_ground_step
local play_character_sound = play_character_sound
local play_mario_sound = play_mario_sound
local play_sound = play_sound
local play_step_sound = play_step_sound
local s16 = math.s16
local set_anim_to_frame = set_anim_to_frame
local set_camera_shake_from_point = set_camera_shake_from_point
local set_character_animation = set_character_animation
local set_mario_action = set_mario_action
local set_mario_anim_with_accel = set_mario_anim_with_accel
local set_mario_animation = set_mario_animation
local set_mario_particle_flags = set_mario_particle_flags
local set_mario_y_vel_based_on_fspeed = set_mario_y_vel_based_on_fspeed
local should_begin_sliding = should_begin_sliding
local sins = sins
local smlua_anim_util_set_animation = smlua_anim_util_set_animation
local spawn_non_sync_object = spawn_non_sync_object
local spawn_sync_object = spawn_sync_object
local tilt_body_ground_shell = tilt_body_ground_shell
local update_air_with_turn = update_air_with_turn
local update_air_without_turn = update_air_without_turn
local update_shell_speed = update_shell_speed
local vec3f_copy = vec3f_copy

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable

local actions = {}

---@param m MarioState
function actions.act_dk_grabbing_chunk(m)

	if m.actionState == 0 then
		mario_drop_held_object(m)
		set_mario_animation(m, CHAR_ANIM_A_POSE)
		smlua_anim_util_set_animation(m.marioObj, DK_ANIM_SLAM)
		m.marioObj.header.gfx.animInfo.animAccel = 0x8000 * 7

		mario_set_forward_vel(m, 0)
		play_character_sound(m, CHAR_SOUND_UH)

		m.actionState = 1
	elseif m.actionState == 1 then
		if is_anim_past_frame(m, 20) ~= 0 then
			set_mario_animation(m, CHAR_ANIM_PICK_UP_LIGHT_OBJ)

			set_camera_shake_from_point(SHAKE_POS_SMALL, m.pos.x, m.pos.y, m.pos.z)
			play_sound(SOUND_GENERAL_QUIET_POUND1_LOWPRIO, m.marioObj.header.gfx.cameraToObject)
			set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE | PARTICLE_HORIZONTAL_STAR, 0)

			if m.playerIndex == 0 then
				m.usedObj = spawn_sync_object(id_bhvHeldChunk, E_MODEL_NONE, m.pos.x, m.pos.y, m.pos.z, function(c)
					c.oChunkOwner = nps[0].globalIndex
				end)
			end

			m.actionState = 2
		end
	else
		if m.actionArg == 0 then
			mario_grab_used_object(m)
			m.marioBodyState.grabPos = GRAB_POS_LIGHT_OBJ
			m.actionArg = 1
		end
		if is_anim_past_end(m) ~= 0 then
			return set_mario_action(m, ACT_HOLD_IDLE, 0)
		end
	end
end

---@param m MarioState
function actions.act_dk_punching(m)

	m.controller.buttonDown = m.controller.buttonDown & ~B_BUTTON

	if m.input & INPUT_UNKNOWN_10 ~= 0 then
		return drop_and_set_mario_action(m, ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if m.actionState == 0 then
		if m.floorHeight ~= m.pos.y then
			mario_set_forward_vel(m, max(10, m.forwardVel))
		end
		m.actionState = 1
		m.actionArg = 1
	end

	if m.actionState == 1 and m.actionTimer == 0 then
		if m.floorHeight == m.pos.y and m.intendedMag > 5 then
			mario_set_forward_vel(m, max(50 * (m.intendedMag / 32), m.forwardVel))
		end

		m.actionArg = abs(1 - m.actionArg)
		play_character_sound(m, CHAR_SOUND_PUNCH_HOO)
		m.actionState = 2
	end

	if m.intendedMag > 0 then
		if abs_angle_diff(m.intendedMag, m.faceAngle.y) > 0x4000 then
			m.faceAngle.y = m.intendedYaw
		else
			m.faceAngle.y = approach_s16_symmetric(m.faceAngle.y, m.intendedYaw, 0x800)
		end
	end

	if m.actionState == 2 then

		set_character_animation(m, CHAR_ANIM_FIRST_PUNCH + m.actionArg)

		if is_anim_past_end(m) ~= 0 then
			m.actionState = 3
			m.marioBodyState.punchState = ((0 + m.actionArg) << 6) | 4
		end

		if m.marioObj.header.gfx.animInfo.animFrame > (1 - m.actionArg) then

			if m.heldObj then
				local act = ACT_THROWING
				if m.heldObj.oInteractionSubtype == INT_SUBTYPE_GRABS_MARIO then
					act = ACT_HEAVY_THROW
				elseif m.floorHeight ~= m.pos.y then
					act = ACT_AIR_THROW
				else
					mario_set_forward_vel(m, 0)
				end
				return set_mario_action(m, act, 0)
			else
				local intObj = mario_get_collided_object(m, INTERACT_GRABBABLE) ---@type Object|nil
				
				if not intObj and m.wall and m.wall.object and m.wall.object.oInteractType == INTERACT_GRABBABLE then
					intObj = m.wall.object
				end
				if intObj and obj_has_behavior_id(intObj, id_bhvBowser) ~= 0 then
					intObj = nil
				end

				if intObj and intObj.oHeldState ~= HELD_HELD then
					if abs_angle_diff(m.faceAngle.y, mario_obj_angle_to_object(m, intObj)) < degrees_to_sm64(80) then
						m.usedObj = intObj
						mario_grab_used_object(m)
						play_character_sound(m, CHAR_SOUND_WHOA)

						if intObj.oInteractionSubtype & INT_SUBTYPE_GRABS_MARIO ~= 0 then
							m.marioBodyState.grabPos = GRAB_POS_HEAVY_OBJ
						else
							m.marioBodyState.grabPos = GRAB_POS_LIGHT_OBJ
						end
						mario_set_forward_vel(m, 0)
						return set_mario_action(m, ACT_HOLD_IDLE, 0)
					end
				end
			end

			m.flags = m.flags | MARIO_PUNCHING
		end
	elseif m.actionState == 3 then
		set_character_animation(m, CHAR_ANIM_FIRST_PUNCH_FAST + m.actionArg)
		if m.marioObj.header.gfx.animInfo.animFrame <= 0 then
            m.flags = m.flags | MARIO_PUNCHING
        end

		if m.input & INPUT_ABOVE_SLIDE ~= 0 then
			return set_mario_action(m, ACT_BEGIN_SLIDING, 0)
		end

        if m.controller.buttonPressed & Y_BUTTON ~= 0 then
			m.actionTimer = 2
			m.actionState = 1
		end

		if is_anim_at_end(m) ~= 0 then
			m.controller.buttonPressed = m.controller.buttonPressed & ~Y_BUTTON
			return set_mario_action(m, ACT_WALKING, 0)
		end
	end

	if m.pos.y ~= m.floorHeight then
		mario_set_forward_vel(m, max(approach_f32_symmetric(m.forwardVel, 0, 0.5), -10))
		perform_air_step(m, 0)
	else
		mario_set_forward_vel(m, max(approach_f32_symmetric(m.forwardVel, 0, 2.5), -10))
		perform_ground_step(m)
	end

	if m.actionTimer > 0 then
		m.actionTimer = m.actionTimer - 1
	end
end

---@param m MarioState
function actions.act_dk_slam(m)

	local dkSound, shake = CHAR_SOUND_PUNCH_YAH, SHAKE_POS_SMALL
	if m.actionArg == 1 then
		dkSound, shake = CHAR_SOUND_PUNCH_WAH, SHAKE_POS_MEDIUM
	elseif m.actionArg == 2 then
		dkSound, shake = CHAR_SOUND_PUNCH_HOO, SHAKE_POS_LARGE
	end

	if m.actionState == 0 then
		mario_drop_held_object(m)
		set_mario_animation(m, CHAR_ANIM_A_POSE)
		smlua_anim_util_set_animation(m.marioObj, DK_ANIM_SLAM)
		m.marioObj.header.gfx.animInfo.animAccel = 0x8000 * 10

		mario_set_forward_vel(m, 0)
		play_character_sound(m, dkSound)

		if m.pos.y > m.floorHeight then
			m.vel.y = -70
			m.actionState = 1
		else
			m.actionState = 2
		end
	elseif m.actionState == 1 then
		set_anim_to_frame(m, 3)
		if perform_air_step(m, 0) == AIR_STEP_LANDED then
			m.actionState = 2
		end
	elseif m.actionState == 2 then

		set_camera_shake_from_point(shake, m.pos.x, m.pos.y, m.pos.z)
		set_mario_particle_flags(m, PARTICLE_HORIZONTAL_STAR | PARTICLE_MIST_CIRCLE, 0)
		audio_sample_play(SOUND_DRUM, m.pos, 0.8)
		play_sound(SOUND_GENERAL_WALL_EXPLOSION, m.pos)

		m.actionState = 3
	else
		if is_anim_past_frame(m, 41) ~= 0 then
			m.controller.buttonDown = m.controller.buttonDown & ~B_BUTTON
			return set_mario_action(m, ACT_IDLE, 0)
		end
	end

	m.marioBodyState.handState = MARIO_HAND_OPEN
end

---@param m MarioState
function actions.act_dk_roll(m)

	set_mario_anim_with_accel(m, MARIO_ANIM_FORWARD_SPINNING, (0x10000 * max(m.forwardVel, 30)) / 60)

	local inAir = m.pos.y > m.floorHeight and not m.marioObj.platform
	local step = 0
	local yawIncrement = ternary(inAir, 0x150, 0x250)

	m.faceAngle.y = approach_s16_symmetric(m.faceAngle.y, m.intendedYaw, yawIncrement)

	if inAir then
		step = perform_air_step(m, 0)
	else
		apply_slope_accel(m)
		step = perform_ground_step(m)

		m.forwardVel = max(m.forwardVel - 1, 0)

		if should_begin_sliding(m) ~= 0 then
			return set_mario_action(m, ACT_BEGIN_SLIDING, 0)
		end

		if m.controller.buttonPressed & A_BUTTON ~= 0 then
			playerTable[m.playerIndex].rollJumpSpeed = m.forwardVel
			return set_mario_action(m, ACT_LONG_JUMP, 0)
		end
	end

	if step == AIR_STEP_HIT_WALL then
		if not inAir then
			m.vel.y = 30
		end

        set_mario_particle_flags(m, PARTICLE_VERTICAL_STAR, 0)
		return set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
	end

	if m.controller.buttonPressed & Y_BUTTON ~= 0 then
		return set_mario_action(m, ACT_DK_PUNCHING, 0)
	end

	if m.controller.buttonDown & Z_TRIG ~= 0 and m.actionTimer > 10 then
		local dustPos = {
			x = m.pos.x + m.forwardVel * sins(m.faceAngle.y),
			y = m.pos.y,
			z = m.pos.z + m.forwardVel * coss(m.faceAngle.y)
		}
		dustPos.y = find_floor_height(dustPos.x, dustPos.y + 200, dustPos.z)
		spawn_non_sync_object(id_bhvMistCircParticleSpawner, E_MODEL_NONE, dustPos.x, dustPos.y, dustPos.z, function()end)

		if not inAir then
			m.vel.y = 20
		end
		m.actionTimer = 0
		m.actionState = 2
	end

	if cur_obj_check_anim_frame(4) ~= 0 then
		play_sound(SOUND_ACTION_SPIN, m.pos)
	end

	if m.actionState ~= 1 then
		if m.actionState == 2 then
			audio_sample_play(SOUND_BOUNCE1, m.pos, 0.4)
		end
		mario_set_forward_vel(m, 60)
		m.actionState = 1
	end

	if m.forwardVel <= 5 then
		return set_mario_action(m, ternary(inAir, ACT_FREEFALL, ACT_WALKING), 0)
	end

	m.actionTimer = m.actionTimer + 1
end

---@param m MarioState
function actions.act_dk_wall_climb(m)

	if not m.wall then

		if m.actionTimer > 3 then
			m.vel.y = 20
			mario_set_forward_vel(m, 20)
			return set_mario_action(m, ACT_FORWARD_ROLLOUT, 0)
		end

		m.actionTimer = m.actionTimer + 1
		mario_set_forward_vel(m, 10)
		perform_air_step(m, 0)

		return
	end
	m.actionTimer = 0

	if m.actionState == 0 then
		set_mario_animation(m, CHAR_ANIM_A_POSE)
		mario_set_forward_vel(m, 0)
		m.actionState = 1
	end
	local curVel = m.forwardVel
	mario_set_forward_vel(m, 6)

	m.faceAngle.y = s16(atan2s(m.wall.normal.z, m.wall.normal.x) - 0x8000)

	if m.controller.buttonPressed & A_BUTTON ~= 0 then
		m.faceAngle.y = m.faceAngle.y + 0x8000
		return set_mario_action(m, ACT_WALL_KICK_AIR, 0)
	elseif m.controller.buttonPressed & Z_TRIG ~= 0 then
		m.pos.x = m.pos.x - 30 * sins(m.faceAngle.y)
		m.pos.z = m.pos.z - 30 * coss(m.faceAngle.y)
		mario_set_forward_vel(m, -20)
		return set_mario_action(m, ACT_FREEFALL, 0)
	end

	vec3f_copy(m.vel, gVec3fZero())

	if m.intendedMag > 0 then
		curVel = approach_f32_symmetric(curVel, 50 * (m.intendedMag / 64), 2)

		if abs(m.controller.stickX) > 0 then
			local yaw = m.faceAngle.y
			local hVel = curVel * abs(m.controller.stickX / 64)

			if m.controller.stickX > 0 then
				yaw = yaw - 0x3999
			elseif m.controller.stickX < 0 then
				yaw = yaw + 0x3999
			end
			yaw = s16(yaw)

			m.vel.x = hVel * sins(yaw)
			m.vel.z = hVel * coss(yaw)
		end

		if abs(m.controller.stickY) > 0 then
			m.vel.y = curVel * (m.controller.stickY / 64)
		end
	else
		curVel = 0
	end

	if curVel > 0 and (m.vel.y >= 0 or (m.vel.x ~= 0 and m.vel.z ~= 0)) then
		smlua_anim_util_set_animation(m.marioObj, DK_ANIM_CLIMB)
		m.marioObj.header.gfx.animInfo.animAccel = abs(curVel * 0x2000)
		play_step_sound(m, 1, 21)
	else
		smlua_anim_util_set_animation(m.marioObj, DK_ANIM_CLIMBSLIDE)
		m.marioObj.header.gfx.animInfo.animAccel = 0

		if m.vel.y < 0 then
			play_sound(SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, m.marioObj.header.gfx.cameraToObject)
			set_mario_particle_flags(m, PARTICLE_DUST, 0)
		end
	end

	local step = perform_air_step(m, AIR_STEP_CHECK_LEDGE_GRAB)
	m.forwardVel = curVel

	if step == AIR_STEP_GRABBED_LEDGE then
		return
	elseif step == AIR_STEP_LANDED then
		return set_mario_action(m, ACT_FREEFALL_LAND, 0)
	end
end

---@param m MarioState
function actions.act_dk_chunk_surfing(m)

	if m.actionState == 0 then
		mario_drop_held_object(m)
		set_character_animation(m, CHAR_ANIM_START_RIDING_SHELL)
		play_character_sound(m, CHAR_SOUND_HAHA)

		m.actionState = 1
	else
		if m.controller.buttonPressed & X_BUTTON ~= 0 then
			m.controller.buttonPressed = m.controller.buttonPressed & ~X_BUTTON
			return set_mario_action(m, ACT_FREEFALL, 0)
		end

		local step = 0

		if m.floorHeight == m.pos.y or m.marioObj.platform or m.waterLevel == m.pos.y then

			set_character_animation(m, CHAR_ANIM_START_RIDING_SHELL)

			local startYaw = m.faceAngle.y
			local startFVel = m.forwardVel

			update_shell_speed(m)

			if m.actionState == 2 then
				mario_set_forward_vel(m, startFVel - 3)

				if m.forwardVel <= 64 then
					m.actionState = 1
				end
			end

			if m.controller.buttonPressed & Y_BUTTON ~= 0 and m.actionTimer > 5 then
				set_anim_to_frame(m, 0)
				play_sound(SOUND_ACTION_SPIN, m.pos)
				m.forwardVel = 120
				m.actionState = 2
				m.actionTimer = 0
			end

			step = perform_ground_step(m)
			if step == GROUND_STEP_HIT_WALL then
				play_sound(ternary(m.flags & MARIO_METAL_CAP ~= 0, SOUND_ACTION_METAL_BONK, SOUND_ACTION_BONK), m.pos)
				set_mario_particle_flags(m, PARTICLE_VERTICAL_STAR, 0)
				return set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0)
			end

			if m.controller.buttonPressed & A_BUTTON ~= 0 then
				m.pos.y = m.pos.y + 1
				set_mario_y_vel_based_on_fspeed(m, 42, 0.25)
				play_mario_sound(m, SOUND_ACTION_TERRAIN_JUMP, CHAR_SOUND_YAHOO)
				m.flags = m.flags & ~(MARIO_ACTION_SOUND_PLAYED | MARIO_MARIO_SOUND_PLAYED)
				return
			end

			tilt_body_ground_shell(m, startYaw)

			local sound = 0
			if m.floor and m.floor.type == SURFACE_BURNING then
				sound = SOUND_MOVING_RIDING_SHELL_LAVA
			else
				sound = SOUND_MOVING_TERRAIN_RIDING_SHELL + m.terrainSoundAddend
			end
			play_sound(sound, m.marioObj.header.gfx.cameraToObject)
    		adjust_sound_for_speed(m)

		else
			set_character_animation(m, CHAR_ANIM_JUMP_RIDING_SHELL)
			update_air_without_turn(m)

			step = perform_air_step(m, 0)
			if step == AIR_STEP_HIT_WALL then
				mario_set_forward_vel(m, 0)
			elseif step == AIR_STEP_HIT_LAVA_WALL then
				return lava_boost_on_wall(m)
			end
			
			if m.vel.y < 0 and m.controller.buttonPressed & A_BUTTON ~= 0 then
				return set_mario_action(m, ACT_TRIPLE_JUMP, 0)
			end
		end

		m.actionTimer = m.actionTimer + 1
	end

	obj_set_gfx_pos(m.marioObj,
		m.pos.x + 50 * sins(m.faceAngle.y),
		m.pos.y + 85,
		m.pos.z + 50 * coss(m.faceAngle.y)
	)
end

---@param m MarioState
function actions.act_dk_chunk_swing(m)

	if m.input & INPUT_UNKNOWN_10 ~= 0 then
		return drop_and_set_mario_action(m, ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if m.actionState == 0 then
		m.forwardVel = m.forwardVel + 5
		set_mario_animation(m, CHAR_ANIM_FIRST_PUNCH)
		play_character_sound(m, CHAR_SOUND_PUNCH_YAH)
		m.actionState = 1
	elseif m.actionState == 1 then
		if is_anim_past_end(m) ~= 0 then
			set_character_animation(m, CHAR_ANIM_FIRST_PUNCH_FAST)
			m.actionState = 2
		end
	else
		if is_anim_at_end(m) ~= 0 then
			set_mario_action(m, ternary(playerTable[m.playerIndex].heldChunkAct == 2, ACT_WALKING, ACT_HOLD_WALKING), 0)
			playerTable[m.playerIndex].heldChunkAct = 0
			return
		end
	end

	mario_set_forward_vel(m, max(m.forwardVel - 1, 0))

	if m.pos.y > m.floorHeight then
		perform_air_step(m, 0)
	else
		perform_ground_step(m)
	end
end

---@param m MarioState
function actions.act_dk_chunk_throwing(m)
	if m.input & INPUT_UNKNOWN_10 ~= 0 then
        return drop_and_set_mario_action(m, ACT_SHOCKWAVE_BOUNCE, 0)
    end

    if m.input & INPUT_OFF_FLOOR ~= 0 then
        return drop_and_set_mario_action(m, ACT_FREEFALL, 0)
	end

	animated_stationary_ground_step(m, CHAR_ANIM_GROUND_THROW, ACT_IDLE)

	if cur_obj_check_anim_frame(8) ~= 0 then
		mario_throw_held_object(m)
		play_character_sound(m, CHAR_SOUND_PUNCH_WAH)
		play_sound(SOUND_ACTION_THROW, m.marioObj.header.gfx.cameraToObject)
	end
end

---@param m MarioState
function actions.act_dk_chunk_throwing_air(m)

	if m.actionState == 0 then
		update_air_with_turn(m)
		if set_character_animation(m, CHAR_ANIM_THROW_LIGHT_OBJECT) == 5 then
			play_character_sound(m, CHAR_SOUND_PUNCH_WAH)
			mario_throw_held_object(m)
			m.vel.y = 40
			mario_set_forward_vel(m, -15)
			m.actionState = 1
		end
	else
		if set_character_animation(m, CHAR_ANIM_BACKWARD_SPINNING) == 4 then
			play_sound(SOUND_ACTION_SPIN, m.marioObj.header.gfx.cameraToObject)
		end
	end

	local step = perform_air_step(m, 0)
	if step == AIR_STEP_HIT_WALL then
		mario_set_forward_vel(m, 0)
	elseif step == AIR_STEP_HIT_LAVA_WALL then
		return lava_boost_on_wall(m)
	elseif step == AIR_STEP_LANDED then
		return set_mario_action(m, ternary(m.actionState ~= 0, ACT_IDLE, ACT_DK_CHUNK_THROWING), 0)
	end
end

return actions