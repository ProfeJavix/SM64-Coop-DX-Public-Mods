local hook_behavior = hook_behavior
local define_custom_obj_fields = define_custom_obj_fields
local network_init_object = network_init_object
local cur_obj_play_sound_2 = cur_obj_play_sound_2
local cur_obj_rotate_yaw_toward = cur_obj_rotate_yaw_toward
local obj_die_if_health_non_positive = obj_die_if_health_non_positive
local obj_get_pitch_from_vel = obj_get_pitch_from_vel
local spawn_sync_object = spawn_sync_object
local set_mario_action = set_mario_action
local cur_obj_check_anim_frame = cur_obj_check_anim_frame
local cur_obj_move_standard = cur_obj_move_standard
local cur_obj_check_anim_frame_in_range = cur_obj_check_anim_frame_in_range
local obj_spawn_loot_yellow_coins = obj_spawn_loot_yellow_coins
local play_sound = play_sound
local cur_obj_init_animation = cur_obj_init_animation
local cur_obj_init_animation_with_sound = cur_obj_init_animation_with_sound
local cur_obj_init_animation_with_accel_and_sound = cur_obj_init_animation_with_accel_and_sound
local determine_interaction = determine_interaction
local cur_obj_update_floor_and_walls = cur_obj_update_floor_and_walls
local cur_obj_move_using_vel_and_gravity = cur_obj_move_using_vel_and_gravity
local obj_turn_pitch_toward_mario = obj_turn_pitch_toward_mario
local dist_between_objects = dist_between_objects
local obj_angle_to_object = obj_angle_to_object
local obj_scale = obj_scale
local obj_copy_pos_and_angle = obj_copy_pos_and_angle
local get_temp_object_hitbox = get_temp_object_hitbox
local max = math.max

local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

--#region Bhv Utils ---------------------------------------------------------------------------------------------------------------------------
define_custom_obj_fields({
    oPlayerControlling = 's32',
    oCustomTimer = 's32',
    oCustomGoombaWalkTimer = 's32',
    oCustomKoopaExposed = 's32'
})

---@param o Object
function common_init(o)
    o.oPlayerControlling = -1
    network_init_object(o, true, {
        'oPlayerControlling',
        'oCustomTimer',
        'oCustomGoombaWalkTimer',
        'oCustomKoopaExposed'
    })
end

--[[ ---@param o Object
---@param m MarioState
---@param rotateIdle boolean
---@param rotationIncrement integer
---@param slowSpeed number
---@param fastSpeed number
---@param canJump boolean
---@param jumpVelY number
---@param jumpSoundBits integer | nil
function common_movement(o, m, rotateIdle, rotationIncrement, slowSpeed, fastSpeed, canJump, jumpVelY, jumpSoundBits)

    --if m.playerIndex ~= 0 then return end

    if m.controller.buttonPressed & A_BUTTON ~= 0 and canJump then
        o.oVelY = jumpVelY

        if jumpSoundBits ~= nil then
            cur_obj_play_sound_2(jumpSoundBits)
        end
    end

    local speed = slowSpeed
    if m.controller.buttonDown & B_BUTTON ~= 0 then
        speed = fastSpeed
    end

    if m.intendedMag ~= 0 then
        cur_obj_rotate_yaw_toward(m.intendedYaw, rotationIncrement)
    elseif rotateIdle then
        o.oMoveAngleYaw = o.oFaceAngleYaw
    end

    o.oForwardVel = m.intendedMag / 32 * speed
end ]]

---@param o Object
---@param m MarioState
---@param rotateIdle boolean
---@param rotationIncrement integer
---@param slowSpeed number
---@param fastSpeed number
---@param canJump boolean
---@param jumpVelY number
---@param jumpSoundBits integer | nil
function common_movement(o, m, rotateIdle, rotationIncrement, slowSpeed, fastSpeed, canJump, jumpVelY, jumpSoundBits)

    cur_obj_update_floor_and_walls()
    if m.controller.buttonPressed & A_BUTTON ~= 0 and canJump then
        o.oVelY = jumpVelY

        if jumpSoundBits ~= nil then
            play_sound(jumpSoundBits, m.marioObj.header.gfx.cameraToObject)
        end
    end

    local speed = slowSpeed
    if m.controller.buttonDown & B_BUTTON ~= 0 then
        speed = fastSpeed
    end

    if m.intendedMag ~= 0 then
        cur_obj_rotate_yaw_toward(m.intendedYaw, rotationIncrement)
    elseif rotateIdle then
        o.oMoveAngleYaw = o.oFaceAngleYaw
    end

    o.oForwardVel = m.intendedMag / 32 * speed
    cur_obj_move_standard(78)
end

---@param o Object
function run_custom_timer(o)
    if o.oCustomTimer > 0 then
        o.oCustomTimer = o.oCustomTimer - 1
    end
end

---@param m MarioState
---@return boolean
function common_check_if_cancel_control(m)
    return (m.controller.buttonPressed & X_BUTTON ~= 0 and playerTable[m.playerIndex].controlTimer == 0) or
	(m.action ~= ACT_CONTROLLING_MOB and playerTable[m.playerIndex].controlTimer < 10) or
    (globalTable.mhControlOnlyForHunters and getMHTeam(m.playerIndex) == 1)
end

---@param o Object
---@param m MarioState
function common_cancel_control(o, m)
    o.oPlayerControlling = -1
    m.usedObj = nil
    playerTable[m.playerIndex].controlTimer = 20
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Bobomb ------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_bobomb_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]
        if common_check_if_cancel_control(m) or o.oAction == BOBOMB_ACT_EXPLODE then
            common_cancel_control(o, m)
            o.oAction = BOBOMB_ACT_EXPLODE
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oHeldState ~= HELD_FREE or (o.oAction ~= BOBOMB_ACT_PATROL and o.oAction ~= BOBOMB_ACT_CHASE_MARIO) then return end

        if (m.controller.buttonPressed & B_BUTTON ~= 0 and o.oAction == BOBOMB_ACT_PATROL) or 
		o.header.gfx.node.flags & GRAPH_RENDER_INVISIBLE ~= 0 and o.oAction == BOBOMB_ACT_PATROL then
            o.oAction = BOBOMB_ACT_CHASE_MARIO
            o.oBobombFuseLit = 1
            sendObj(o)
            return
        end

        if o.oBobombFuseLit == 0 then
            o.oAction = BOBOMB_ACT_PATROL
        end

        if m.intendedMag ~= 0 then
            o.oMoveAngleYaw = m.intendedYaw
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Boo ---------------------------------------------------------------------------------------------------------------------------------

---From boo.inc.c
---@param o Object
function boo_oscillate(o)
    o.oFaceAnglePitch = sins(o.oBooOscillationTimer) * 0x200
    o.header.gfx.scale.x = sins(o.oBooOscillationTimer) * 0.08 + o.oBooBaseScale
    o.header.gfx.scale.y = -sins(o.oBooOscillationTimer) * 0.08 + o.oBooBaseScale
    o.header.gfx.scale.z = o.header.gfx.scale.x
    o.oGravity = sins(o.oBooOscillationTimer) * o.oBooBaseScale
    o.oBooOscillationTimer = o.oBooOscillationTimer + 0x200
end

---@param o Object
function bhv_custom_boo_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            o.oAction = 1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or (o.oHealth == 0 and o.oBehParams2ndByte == 2) or (o.oAction == 3 and o.oBehParams2ndByte ~= 2) then
            
            common_cancel_control(o, m)

            if o.oHealth > 0 and o.oBehParams2ndByte == 2 then
                djui_chat_message_create("Big Boo: I'M SUPOSSED TO BE POSSESSING, NOT BEING POSSESSED!!")
                play_sound(SOUND_OBJ_BOO_LAUGH_LONG, m.marioObj.header.gfx.cameraToObject)
                o.oAction = 1
                m.pos.z = m.pos.z + 200
                set_mario_action(m, ACT_GROUND_BONK, 0)
            elseif o.oBehParams2ndByte ~= 2 then
                o.oAction = 3
                play_sound(SOUND_OBJ_DYING_ENEMY1, m.marioObj.header.gfx.cameraToObject)
            end
            return
        end

        if o.oAction == 2 or o.oAction == 3 then return end

        o.oAction = 6
        o.oGravity = 0
        o.oVelY = 0

        if m.controller.buttonDown & B_BUTTON ~= 0 then
            o.oInteractType = 0
            o.oForwardVel = 0
            o.oBooTargetOpacity = 40
            return
        else
            o.oInteractType = 0x8000
            o.oBooTargetOpacity = 255
        end

        local nm = nearestAffectableMario(m)
        if nm ~= nil then
            local interaction = determine_interaction(nm, o)
            if interaction ~= 0 then
                if interaction & INT_ANY_ATTACK ~= 0 and interaction ~= INT_HIT_FROM_ABOVE then
                    if interaction ~= INT_HIT_FROM_BELOW then
                        if o.oBehParams2ndByte == 2 then
                            play_sound(SOUND_OBJ_THWOMP, nm.marioObj.header.gfx.cameraToObject)
                        else
                            play_sound(SOUND_OBJ_DYING_ENEMY1, nm.marioObj.header.gfx.cameraToObject)
                        end
                        o.oAction = 3
                        return
                    end
                end
            end
        end

        boo_oscillate(o)
        if m.intendedMag ~= 0 then
            o.oMoveAngleYaw = m.intendedYaw
            o.oForwardVel = 13
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
            o.oForwardVel = 0
        end

        if (m.controller.buttonDown & A_BUTTON ~= 0 and o.oPosY - o.oFloorHeight < 800) or o.oPosY < o.oFloorHeight + 50 then
            o.oVelY = 5
        end
        if (m.controller.buttonDown & Z_TRIG ~= 0 and o.oPosY > o.oFloorHeight + 50) or o.oPosY - o.oFloorHeight >= 800 then
            o.oVelY = -5
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Bully -------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_bully_loop(o)

    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or (o.oAction >= 4 and o.oAction ~= 6) then
            common_cancel_control(o, m)
            if o.oAction == 6 or o.oAction <= 3 then
                o.oAction = BULLY_ACT_PATROL
            end

            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction == BULLY_ACT_KNOCKBACK then return end

        o.oAction = 6

        cur_obj_update_floor()

        if m.intendedMag ~= 0 then
            o.oMoveAngleYaw = m.intendedYaw
            o.oForwardVel = 5
            obj_check_floor_death(object_step(), o.oFloor)
        end

        local sp26 = o.header.gfx.animInfo.animFrame

        if m.controller.buttonDown & B_BUTTON ~= 0 then
            o.oForwardVel = 20
            cur_obj_init_animation(1)
            if sp26 == 0 or sp26 == 5 then
                cur_obj_play_sound_2(SOUND_OBJ_BULLY_WALK)
            end
            obj_check_floor_death(object_step(), o.oFloor)
            return
        end

        if sp26 == 0 or sp26 == 12 then
            cur_obj_play_sound_2(SOUND_OBJ_BULLY_WALK)
        end
        cur_obj_init_animation(0)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Bowser ------------------------------------------------------------------------------------------------------------------------------
local BOWSER_IGNORED_ACTIONS = {
    [1] = true,  --Held
    [2] = true,  --Recovery
    [3] = true,  --Swipes
    [7] = true,  --Rush
    [8] = true,  --Fire Rain
    [9] = true,  --Single Fireball
    [10] = true, --On Border
    [12] = true, --Hurt
    [13] = true, --Special Jump
    [15] = true, --Flame Throw
    [16] = true, --Teleport
    [17] = true, --Jump
    [19] = true  --Idle In Moving Platform (BITFS)
}

---@param o Object
function bhv_custom_bowser_loop(o)

    run_custom_timer(o)

    local idx = o.oPlayerControlling
    if idx ~= -1 then

        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            o.oAction = 0
            return
        end

        local m = states[localIdx]

        local level = o.oBehParams2ndByte -- [0: BITDW | 1: BITFS | 2: BITS]

        if common_check_if_cancel_control(m) or (o.oAction >= 4 and o.oAction <= 6) then

            common_cancel_control(o, m)

            if o.oAction < 4 or o.oAction > 6 then
                if level == 0 then
                    djui_chat_message_create("Bowser: WHAT WERE YOU DOING WITH MY BODY??!")
                elseif level == 1 then
                    djui_chat_message_create("Bowser: HEY!! DON'T DO THAT AGAIN!!")
                else
                    djui_chat_message_create("Bowser: EVEN WITH THE POWER OF THE STAR...")
                end
                play_sound(SOUND_OBJ2_BOWSER_ROAR, m.marioObj.header.gfx.cameraToObject)
                o.oAction = 0
            end

            m.pos.x = o.oHomeX
            m.pos.z = o.oHomeZ
            m.pos.y = o.oHomeY + 200
            set_mario_action(m, ACT_GROUND_BONK, 0)
			
			if localIdx == 0 then
				sendObj(o)
			end
            return
        end

        if BOWSER_IGNORED_ACTIONS[o.oAction] then
            if o.oAction == 7 and m.intendedMag ~= 0 then
                cur_obj_rotate_yaw_toward(m.intendedYaw, 0x400)
            end
            return
        end

        if m.controller.buttonPressed & A_BUTTON ~= 0 and o.oPosY == o.oFloorHeight then
            if level ~= 0 then
                o.oAction = 13
                o.oCustomTimer = max(150, o.oCustomTimer)
            else
                o.oAction = 17
            end
            return
        end

        if m.controller.buttonPressed & B_BUTTON ~= 0 then
            if level == 0 then
                o.oAction = 15
            else
                o.oAction = 7
            end
            return
        end

        if m.controller.buttonPressed & Z_TRIG ~= 0 and o.oCustomTimer == 0 then
            if level == 1 then
                o.oAction = 16
                o.oCustomTimer = 150
            else
                o.oAction = 3
            end
            return
        end

        if level ~= 0 then
            if m.controller.buttonPressed & D_JPAD ~= 0 then
                o.oAction = 9
                return
            end
            if level ~= 1 then
                if m.controller.buttonPressed & U_JPAD ~= 0 and o.oCustomTimer == 0 then
                    o.oAction = 8
                    o.oCustomTimer = 240
                    return
                end
                if m.controller.buttonPressed & R_JPAD ~= 0 then
                    o.oAction = 15
                    return
                end
            end
        end

        if m.intendedMag ~= 0 then
            o.oAction = 14
            cur_obj_rotate_yaw_toward(m.intendedYaw, 0x400)
        else
            o.oForwardVel = 0
            o.oAction = 18
        end

        --0: Idle?
        --1: Held-
        --2: Recovery-
        --3: Swipes

        --4: Dead
        --5: Text wait
        --6: Intro walk

        --7: Rush
        --8: Fire Rain
        --9: Single fireball
        --10: On Border
        --11: Fast Rotate
        --12: Hurt
        --13: Special Jump
        --14: Walk
        --15: Flame Throw
        --16: Teleport
        --17: Jump
        --18: ?
        --19: Idle In Moving Platform (BITFS)
        --20: Nothing
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Chain Chomp -------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_chain_chomp_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or o.oChainChompReleaseStatus ~= CHAIN_CHOMP_NOT_RELEASED then
            common_cancel_control(o, m)
            set_mario_action(m, ACT_GROUND_BONK, 0)
            m.pos.z = m.pos.z + 400
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oSubAction == CHAIN_CHOMP_SUB_ACT_LUNGE then return end

        if o.oFaceAnglePitch ~= 0 then
            o.oFaceAnglePitch = 0
        end

        if m.controller.buttonPressed & B_BUTTON ~= 0 then
            o.oForwardVel = 140
            o.oVelY = 20
            o.oGravity = 0
            o.oChainChompTargetPitch = obj_get_pitch_from_vel()
            play_sound(SOUND_GENERAL_CHAIN_CHOMP2, m.pos)
            o.oSubAction = CHAIN_CHOMP_SUB_ACT_LUNGE
            return
        end

        if m.controller.buttonPressed & A_BUTTON ~= 0 and o.oFloorHeight + 40 >= o.oPosY then
            o.oVelY = 80
            play_sound(SOUND_GENERAL_CHAIN_CHOMP2, m.pos)
        end

        o.oTimer = 0
        o.oSubAction = CHAIN_CHOMP_SUB_ACT_TURN

        if m.intendedMag ~= 0 then
            o.oMoveAngleYaw = m.intendedYaw
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
        end
        cur_obj_rotate_yaw_toward(o.oMoveAngleYaw, 0x400)
        o.oForwardVel = m.intendedMag / 32 * 10
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Chuckya -----------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_chuckya_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
			o.usingObj = nil
            o.oHealth = 0
            obj_die_if_health_non_positive()
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oHeldState ~= HELD_FREE or o.oAction == 1 or o.oAction == 2 then return end

        o.oAction = 0
        o.oSubAction = 1

        common_movement(o, m, true, 0x400, 30, 30, false, 0)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Fly Guy -----------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_fly_guy_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
            obj_die_if_health_non_positive()
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        local nm = nearestAffectableMario(m)

        o.oAction = 4

        if o.oTimer <= 30 then return end

        if m.intendedMag ~= 0 then
            o.oFaceAngleYaw = m.intendedYaw
            o.oMoveAngleYaw = m.intendedYaw
            o.oForwardVel = 13
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
            o.oForwardVel = 0
        end

        if m.controller.buttonPressed & R_JPAD ~= 0 and o.oTimer > 90 and localIdx == 0 then
            o.oForwardVel = 0
            o.oTimer = 0

            local anglePitch = 0
            if nm ~= nil and dist_between_objects(nm.marioObj, o) < 400 then
                o.oFaceAngleYaw = obj_angle_to_object(o, nm.marioObj)
                anglePitch = obj_turn_pitch_toward_mario(nm, 0, 0)
            end
            o.oMoveAngleYaw = o.oFaceAngleYaw

            spawn_sync_object(id_bhvSmallPiranhaFlame, E_MODEL_RED_FLAME_SHADOW, o.oPosX, o.oPosY, o.oPosZ,
                ---@param flame Object
                function(flame)
                    -- from obj_spit_fire logic
                    obj_scale(flame, 2.5)
                    obj_copy_pos_and_angle(flame, o)
                    flame.oBehParams2ndByte = 1
                    flame.oBehParams = (1 & 0xFF) << 16
                    flame.oSmallPiranhaFlameStartSpeed = 25
                    flame.oSmallPiranhaFlameEndSpeed = 20
                    flame.oMoveAnglePitch = anglePitch
                end
            )
            return
        end

        local lunging = false
        if m.controller.buttonDown & B_BUTTON ~= 0 then
            lunging = true
            o.oForwardVel = 30
        end

        o.oVelY = 0
        if (m.controller.buttonDown & A_BUTTON ~= 0 and o.oPosY - o.oFloorHeight < 800) or o.oPosY < o.oFloorHeight then
            o.oVelY = 5
            if lunging then
                o.oVelY = 10
            end
        end
        if (m.controller.buttonDown & Z_TRIG ~= 0 and o.oPosY > o.oFloorHeight) or o.oPosY - o.oFloorHeight >= 800 then
            o.oVelY = -5
            if lunging then
                o.oVelY = -20
                if nm ~= nil then
                    o.oFlyGuyLungeTargetPitch = obj_turn_pitch_toward_mario(nm, -200, 0)
                end
                obj_face_pitch_approach(o.oFlyGuyLungeTargetPitch, 0x400)
            end
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Goomba ------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_goomba_loop(o)
    local idx = o.oPlayerControlling

    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or o.oAction >= 100 then
            common_cancel_control(o, m)
            obj_die_if_health_non_positive()
			if localIdx == 0 then
				sendObj(o)
			end
            return
        end

        o.oHomeY = o.oPosY + 25000

        common_movement(o, m, true, 0x800, 10, 20, o.oFloorHeight == o.oPosY, 50 / 3 * o.oGoombaScale, SOUND_OBJ_GOOMBA_ALERT)
        cur_obj_play_sound_at_anim_range(2, 17, SOUND_OBJ_GOOMBA_WALK)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region King Bobomb -------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_king_bobomb_loop(o)
    run_custom_timer(o)

    local idx = o.oPlayerControlling
    if idx ~= -1 then

        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or o.oAction == 0 or o.oAction >= 7 then
            
			o.usingObj = nil

            common_cancel_control(o, m)

            if o.oAction > 0 and o.oAction < 7 then
                djui_chat_message_create("King Bob-Omb: Huh? What happened just now?")
                play_sound(SOUND_OBJ_KING_BOBOMB_TALK, m.marioObj.header.gfx.cameraToObject)
            end

            set_mario_action(m, ACT_GROUND_BONK, 0)
            m.pos.z = m.pos.z + 300
			
			if localIdx == 0 then
				sendObj(o)
			end
            return
        end
		
		if o.oAction == 5 and o.oSubAction == 3 or o.oAction == 6 and o.oSubAction == 2 then
            o.oAction = 2
			o.oSubAction = 0
            return
        end

        if o.oAction ~= 2 and (o.oAction ~= 3 or o.oSubAction == 2) then return end

        if o.oAction == 3 then
            o.oKingBobombUnk104 = 18
            if m.controller.buttonPressed & B_BUTTON ~= 0 and o.oCustomTimer == 0 then
                o.oCustomTimer = 20
                o.oForwardVel = 0
                o.oSubAction = 2
                --sendObj(o)
                return
            end   
        end

        common_movement(o, m, true, 0x400, 8, 8, false, 0)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Koopa -------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_koopa_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if o.oKoopaMovementType == KOOPA_BP_KOOPA_THE_QUICK_BASE or o.oKoopaMovementType == KOOPA_BP_KOOPA_THE_QUICK_BOB or o.oKoopaMovementType == KOOPA_BP_KOOPA_THE_QUICK_THI then
            djui_chat_message_create("KTQ: You can't control the mighty Koopa the Quick!")
            common_cancel_control(o, m)
        end

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
            obj_die_if_health_non_positive()

            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        local movementType = o.oKoopaMovementType
        local speed = 0

        if movementType == KOOPA_BP_NORMAL then
            if o.oCustomKoopaExposed == 1 then
                o.oCustomKoopaExposed = 0
            end
            o.oAction = KOOPA_SHELLED_ACT_STOPPED

            if m.controller.buttonDown & B_BUTTON ~= 0 then
                o.oAction = KOOPA_SHELLED_ACT_RUN_FROM_MARIO
                speed = 20
            elseif m.intendedMag ~= 0 then
                o.oAction = KOOPA_SHELLED_ACT_WALK
                speed = 10
            end
        elseif movementType == KOOPA_BP_UNSHELLED then
            if o.oAction == KOOPA_UNSHELLED_ACT_LYING and o.oCustomKoopaExposed == 0 then
                o.oCustomKoopaExposed = 1
                spawn_sync_object(id_bhvKoopaShell, E_MODEL_KOOPA_SHELL, o.oPosX, o.oPosY, o.oPosZ, function()end)
                sendObj(o)
                return
            end

            if o.oAction == KOOPA_UNSHELLED_ACT_DIVE or o.oAction == KOOPA_UNSHELLED_ACT_LYING then return end

            cur_obj_init_animation_with_sound(3)
            cur_obj_play_sound_at_anim_range(0, 6, SOUND_OBJ_KOOPA_WALK)
            speed = 30

            if m.controller.buttonPressed & B_BUTTON ~= 0 then
                o.oAction = KOOPA_UNSHELLED_ACT_DIVE
            end
        end

        if m.intendedMag ~= 0 then
            o.oForwardVel = m.intendedMag / 32 * o.oKoopaAgility * speed
            o.oKoopaTargetYaw = m.intendedYaw
        else
            o.oKoopaTargetYaw = o.oFaceAngleYaw
        end
        cur_obj_rotate_yaw_toward(o.oKoopaTargetYaw, 0x800)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Lakitu ------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_lakitu_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 and o.oAction ~= ENEMY_LAKITU_ACT_UNINITIALIZED then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oAction = 1
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
            obj_die_if_health_non_positive()
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        local hitbox = get_temp_object_hitbox()
        hitbox.interactType = INTERACT_HIT_FROM_BELOW
        hitbox.downOffset = 0
        hitbox.damageOrCoinValue = 2
        hitbox.health = 0
        hitbox.numLootCoins = 5
        hitbox.radius = 40
        hitbox.height = 50
        hitbox.hurtboxRadius = 40
        hitbox.hurtboxHeight = 50
        obj_set_hitbox(o, hitbox)
        cur_obj_become_tangible()

        if o.oInteractStatus & INT_STATUS_INTERACTED ~= 0 then
            if o.oInteractStatus & INT_STATUS_ATTACKED_MARIO == 0 then
                obj_die_if_health_non_positive()
                o.prevObj = nil
            end
            o.oInteractStatus = 0
        end

        if o.prevObj ~= nil or o.oTimer <= 10 then
            cur_obj_init_animation(2)
			if o.prevObj ~= nil then
				cur_obj_play_sound_2(SOUND_OBJ_EVIL_LAKITU_THROW);
				o.prevObj = nil
			end
            return
        elseif o.prevObj == nil then
            cur_obj_init_animation_with_sound(1)
        end
        o.oAction = 2
        o.oVelY = 0

        if m.controller.buttonPressed & B_BUTTON ~= 0 and o.oTimer > 30 and localIdx == 0 then
            o.oTimer = 0
            if o.prevObj == nil then
                local spiny = spawn_sync_object(id_bhvCustomSpiny, E_MODEL_SPINY_BALL, o.oPosX, o.oPosY, o.oPosZ,
                    ---@param s Object
                    function(s)
                        s.oAction = SPINY_ACT_HELD_BY_LAKITU
                    end)
                if spiny ~= nil then
                    cur_obj_init_animation(3)
                    o.prevObj = spiny
                    o.oEnemyLakituNumSpinies = o.oEnemyLakituNumSpinies + 1
                end
            end
            sendObj(o)
            return
        end

		cur_obj_play_sound_1(SOUND_AIR_LAKITU_FLY)
        if m.intendedMag ~= 0 then
            o.oFaceAngleYaw = m.intendedYaw
            o.oMoveAngleYaw = o.oFaceAngleYaw
            o.oForwardVel = 13
        else
            o.oForwardVel = 0
        end

        cur_obj_update_floor_and_walls()
        if m.controller.buttonDown & A_BUTTON ~= 0 then
            o.oVelY = 5
        end
        if m.controller.buttonDown & Z_TRIG ~= 0 then
            o.oVelY = -5
        end
        cur_obj_move_standard(78)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Mad Piano ---------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_mad_piano_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
            o.oAction = MAD_PIANO_ACT_WAIT
            djui_chat_message_create("Mad Piano: \\#FF0000\\GET OUT OF MY KEYS!")
            m.pos.z = m.pos.z + 200
            set_mario_action(m, ACT_GROUND_BONK, 0)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if m.intendedMag ~= 0 then
            o.oAction = MAD_PIANO_ACT_ATTACK

            o.oHomeX = o.oPosX
            o.oHomeY = o.oPosY
            o.oHomeZ = o.oPosZ
        else
            o.oAction = MAD_PIANO_ACT_WAIT
        end

        common_movement(o, m, false, 0x800, 5, 30, false, 0)
        cur_obj_move_standard(78)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Scuttlebug --------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_scuttlebug_loop(o)

    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            o.oSubAction = 0
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
            o.oHealth = 0
            obj_die_if_health_non_positive()
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oSubAction == 4 or o.oSubAction == 5 then return end

        o.oSubAction = 6
        common_movement(o, m, true, 0x800, 5, 15, o.oFloorHeight == o.oPosY, 30, SOUND_OBJ2_SCUTTLEBUG_ALERT)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Skeeter -----------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_skeeter_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
            o.oHealth = 0
            obj_die_if_health_non_positive()
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction == SKEETER_ACT_LUNGE then return end

        common_movement(o, m, true, 0x700, 5, 10, false, 0)

        if m.intendedMag == 0 or o.oMoveFlags & OBJ_MOVE_AT_WATER_SURFACE ~= 0 then
            o.oForwardVel = 0
            o.oAction = SKEETER_ACT_IDLE
        else
            o.oAction = SKEETER_ACT_WALK
        end

        if m.controller.buttonPressed & B_BUTTON ~= 0 and o.oMoveFlags & OBJ_MOVE_AT_WATER_SURFACE ~= 0 then
            o.oForwardVel = 80
            o.oAction = SKEETER_ACT_LUNGE
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Lil Penguin -------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_small_penguin_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or o.oHeldState ~= HELD_FREE then
            common_cancel_control(o, m)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        common_movement(o, m, true, 0x900, 5, 25, false, 0)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Spindrift ---------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_spindrift_loop(o)

    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) then
            common_cancel_control(o, m)
            o.oHealth = 0
            obj_die_if_health_non_positive()
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction == 1 then return end
        
        common_movement(o, m, true, 0x800, 4, 4, false, 0)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Spiny -------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_spiny_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or o.oAction == SPINY_ACT_HELD_BY_LAKITU or o.oAction == SPINY_ACT_THROWN_BY_LAKITU then

            common_cancel_control(o, m)
            if o.oAction ~= SPINY_ACT_HELD_BY_LAKITU and o.oAction ~= SPINY_ACT_THROWN_BY_LAKITU then
                obj_die_if_health_non_positive()
            end
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        common_movement(o, m, true, 0x800, 2, 2, false, 0)
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Toad Message ------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_toad_message_loop(o)

    run_custom_timer(o)
    
    local idx = o.oPlayerControlling
    cur_obj_init_animation_with_accel_and_sound(6, 1)
    if o.oToadMessageState < 0 or o.oToadMessageState > 4 then
        o.oToadMessageState = 1
    end
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            o.oGravity = 0
            o.oWallHitboxRadius = 0
            o.oPosY = o.oFloorHeight
            sendObj(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or o.oCustomTimer ~= 0 or o.oAction == 4 then

            common_cancel_control(o, m)

            o.oPosY = o.oFloorHeight
            o.oInteractStatus = 0
            o.oGravity = 0
            o.oWallHitboxRadius = 0

            if o.oCustomTimer ~= 0 then
                m.pos.x = m.pos.x + 200
                play_sound(SOUND_OBJ_POUNDING_LOUD, m.marioObj.header.gfx.cameraToObject)
                set_mario_action(m, ACT_HEAD_STUCK_IN_GROUND, 0)
            end
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        o.oOpacity = 255
        o.oToadMessageState = 5
        o.oGravity = -2
        o.oWallHitboxRadius = 40

        local nm = nearestAffectableMario(m)
        if nm ~= nil and determine_interaction(nm, o) & (INT_PUNCH | INT_KICK | INT_GROUND_POUND_OR_TWIRL | INT_FAST_ATTACK_OR_SHELL) ~= 0 and 
        dist_between_objects(nm.marioObj, o) <= nm.marioObj.hitboxRadius + o.hitboxRadius + 40 then
            o.oCustomTimer = 20
            o.oToadMessageState = 1
            return
        end

        if m.intendedMag ~= 0 then
            cur_obj_init_animation_with_accel_and_sound(6, 2.1)
            o.oMoveAngleYaw = m.intendedYaw - 30 * 0x10000 / 360
            if o.header.gfx.animInfo.animFrame == 16 then
                cur_obj_play_sound_2(SOUND_OBJ_UKIKI_STEP_DEFAULT)
            end
        else
            cur_obj_init_animation(4)
        end
        o.oForwardVel = m.intendedMag / 32 * 35

        cur_obj_update_floor_and_walls()
        if m.controller.buttonPressed & A_BUTTON ~= 0 and o.oFloorHeight >= o.oPosY - 10 then
            o.oVelY = 25
        end

        --the model's front and the face angle are not aligned, so...
        o.oVelX = o.oForwardVel * sins(o.oMoveAngleYaw + 30 * 0x10000 / 360);
        o.oVelZ = o.oForwardVel * coss(o.oMoveAngleYaw + 30 * 0x10000 / 360)
        cur_obj_move_using_vel_and_gravity()
        if o.oPosY < o.oFloorHeight then
            o.oPosY = o.oFloorHeight
        end
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Tweester ----------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_tweester_loop(o)
    if o.oPlayerControlling ~= 0 then
        if o.oCustomTimer > 150 then
            obj_mark_for_deletion(o)
        end
        o.oCustomTimer = o.oCustomTimer + 1
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Ukiki -------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_ukiki_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or (o.oAction > UKIKI_ACT_JUMP and o.oAction ~= UKIKI_ACT_WAIT_TO_RESPAWN) then
            common_cancel_control(o, m)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction == UKIKI_ACT_JUMP or o.oHeldState ~= HELD_FREE then return end

        if m.intendedMag ~= 0 then
            o.oMoveAngleYaw = m.intendedYaw
            o.oAction = UKIKI_ACT_RUN
        else
            o.oAction = UKIKI_ACT_IDLE
        end

        if m.controller.buttonPressed & A_BUTTON ~= 0 then
            o.oAction = UKIKI_ACT_JUMP
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Whomp -------------------------------------------------------------------------------------------------------------------------------

---From whomp_play_sfx_from_pound_animation() in whomp.inc.c
---@param o Object
function whomp_play_sfx_from_pound_animation(o)
    local sp28 = 0
    if o.oForwardVel < 5 then
        sp28 = cur_obj_check_anim_frame(0)
        sp28 = sp28 | cur_obj_check_anim_frame(23)
    else
        sp28 = cur_obj_check_anim_frame_in_range(0, 3)
        sp28 = sp28 | cur_obj_check_anim_frame_in_range(23, 3)
    end
    if sp28 == 1 then
        cur_obj_play_sound_2(SOUND_OBJ_POUNDING1)
    end
end

---@param o Object
function bhv_custom_whomp_loop(o)

    run_custom_timer(o)

    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            o.oAction = 0
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or (o.oBehParams2ndByte ~= 0 and (o.oAction == 0 or o.oAction == 8 or o.oAction == 9)) then

            common_cancel_control(o, m)

            if o.oBehParams2ndByte ~= 0 then
                if o.oAction ~= 0 and o.oAction ~= 8 and o.oAction ~= 9 then
                    djui_chat_message_create("King Whomp: DID I STOP STOMPING FOR A WHILE?")
                    play_sound(SOUND_OBJ_WHOMP_LOWPRIO, m.marioObj.header.gfx.cameraToObject)
                end
    
                m.vel.z = 100
                m.vel.y = 50
    
                set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    
                if o.oAction == 10 then
                    o.oAction = 2
                end
            else
                o.oNumLootCoins = 5
                obj_spawn_loot_yellow_coins(o, 5, 20)
                o.oAction = 8
            end
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction >= 3 and o.oAction <= 8 then return end

        o.oAction = 10

        if m.controller.buttonPressed & Z_TRIG ~= 0 and o.oCustomTimer == 0 then
            o.oCustomTimer = 20
            o.oAction = 3 --to the ground
            return
        end

        local speed = 3
        if m.controller.buttonDown & B_BUTTON ~= 0 then
            speed = 9
        end

        if m.intendedMag ~= 0 then
            cur_obj_rotate_yaw_toward(m.intendedYaw, 0x700)
            cur_obj_init_animation_with_accel_and_sound(0, speed / 3)
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
            cur_obj_init_animation_with_accel_and_sound(0, 1)
        end
        o.oForwardVel = m.intendedMag / 32 * speed
        whomp_play_sfx_from_pound_animation(o)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Wiggler -----------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_wiggler_head_loop(o)
    local idx = o.oPlayerControlling
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oPlayerControlling = -1
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_control(m) or o.oHealth <= 1 then
            common_cancel_control(o, m)
            if o.oHealth <= 1 then
                o.oAction = WIGGLER_ACT_SHRINK
            else
                djui_chat_message_create("Wiggler: Hey!! Which part did you control!?")
                cur_obj_play_sound_2(SOUND_OBJ_WIGGLER_TALK)
            end
            set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction == WIGGLER_ACT_JUMPED_ON then
            o.oAction = WIGGLER_ACT_WALK
            o.oHealth = o.oHealth - 1
            o.oWigglerTextStatus = WIGGLER_TEXT_STATUS_COMPLETED_DIALOG
            sendObj(o)
            return
        end

        if o.oAction ~= WIGGLER_ACT_WALK then return end

        if m.intendedMag ~= 0 then
            o.oMoveAngleYaw = m.intendedYaw
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
            o.oForwardVel = 2
        end

        if m.controller.buttonPressed & A_BUTTON ~= 0 and o.oFloorHeight == o.oPosY then
            o.oVelY = 70
            cur_obj_play_sound_2(SOUND_OBJ_WIGGLER_JUMP)
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region BHV Hooks ---------------------------------------------------------------------------------------------------------------------------
id_bhvCustomBalconyBigBoo = hook_behavior(id_bhvBalconyBigBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomBigBully = hook_behavior(id_bhvBigBully, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bully_loop)
id_bhvCustomBigBullyWithMinions = hook_behavior(id_bhvBigBullyWithMinions, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bully_loop)
id_bhvCustomBigChillBully = hook_behavior(id_bhvBigChillBully, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bully_loop)
id_bhvCustomBobomb = hook_behavior(id_bhvBobomb, OBJ_LIST_DESTRUCTIVE, false, common_init, bhv_custom_bobomb_loop)
id_bhvCustomBoo = hook_behavior(id_bhvBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomBooWithCage = hook_behavior(id_bhvBooWithCage, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomBowser = hook_behavior(id_bhvBowser, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bowser_loop)
id_bhvCustomChainChomp = hook_behavior(id_bhvChainChomp, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_chain_chomp_loop)
id_bhvCustomChuckya = hook_behavior(id_bhvChuckya, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_chuckya_loop)
id_bhvCustomEnemyLakitu = hook_behavior(id_bhvEnemyLakitu, OBJ_LIST_PUSHABLE, false, common_init, bhv_custom_lakitu_loop)
id_bhvCustomFlyGuy = hook_behavior(id_bhvFlyGuy, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_fly_guy_loop)
id_bhvCustomGhostHuntBigBoo = hook_behavior(id_bhvGhostHuntBigBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomGhostHuntBoo = hook_behavior(id_bhvGhostHuntBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomGoomba = hook_behavior(id_bhvGoomba, OBJ_LIST_PUSHABLE, false, common_init, bhv_custom_goomba_loop)
id_bhvCustomKingBobomb = hook_behavior(id_bhvKingBobomb, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_king_bobomb_loop)
id_bhvCustomKoopa = hook_behavior(id_bhvKoopa, OBJ_LIST_PUSHABLE, false, common_init, bhv_custom_koopa_loop)
id_bhvCustomMadPiano = hook_behavior(id_bhvMadPiano, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_mad_piano_loop)
id_bhvCustomMerryGoRoundBigBoo = hook_behavior(id_bhvMerryGoRoundBigBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomMerryGoRoundBoo = hook_behavior(id_bhvMerryGoRoundBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomScuttlebug = hook_behavior(id_bhvScuttlebug, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_scuttlebug_loop)
id_bhvCustomSkeeter = hook_behavior(id_bhvSkeeter, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_skeeter_loop)
id_bhvCustomSmallBully = hook_behavior(id_bhvSmallBully, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bully_loop)
id_bhvCustomSmallChillBully = hook_behavior(id_bhvSmallChillBully, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bully_loop)
id_bhvCustomSmallPenguin = hook_behavior(id_bhvSmallPenguin, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_small_penguin_loop)
id_bhvCustomSmallWhomp = hook_behavior(id_bhvSmallWhomp, OBJ_LIST_SURFACE, false, common_init, bhv_custom_whomp_loop)
id_bhvCustomSpindrift = hook_behavior(id_bhvSpindrift, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_spindrift_loop)
id_bhvCustomSpiny = hook_behavior(id_bhvSpiny, OBJ_LIST_PUSHABLE, false, common_init, bhv_custom_spiny_loop)
id_bhvCustomToadMessage = hook_behavior(id_bhvToadMessage, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_toad_message_loop)
id_bhvCustomTweester = hook_behavior(id_bhvTweester, OBJ_LIST_POLELIKE, false, nil, bhv_custom_tweester_loop)
id_bhvCustomUkiki = hook_behavior(id_bhvUkiki, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_ukiki_loop)
id_bhvCustomWhompKingBoss = hook_behavior(id_bhvWhompKingBoss, OBJ_LIST_SURFACE, false, common_init, bhv_custom_whomp_loop)
id_bhvCustomWigglerHead = hook_behavior(id_bhvWigglerHead, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_wiggler_head_loop)

ALLOWED_MOBS = {
    id_bhvCustomBalconyBigBoo,
    id_bhvCustomBigBully,
    id_bhvCustomBigBullyWithMinions,
    id_bhvCustomBigChillBully,
    id_bhvCustomBobomb,
    id_bhvCustomBoo,
    id_bhvCustomBooWithCage,
    id_bhvCustomBowser,
    id_bhvCustomChainChomp,
    id_bhvCustomChuckya,
    id_bhvCustomEnemyLakitu,
    id_bhvCustomFlyGuy,
    id_bhvCustomGhostHuntBigBoo,
    id_bhvCustomGhostHuntBoo,
    id_bhvCustomGoomba,
    id_bhvCustomKingBobomb,
    id_bhvCustomKoopa,
    id_bhvCustomMadPiano,
    id_bhvCustomMerryGoRoundBigBoo,
    id_bhvCustomMerryGoRoundBoo,
    id_bhvCustomScuttlebug,
    id_bhvCustomSkeeter,
    id_bhvCustomSmallBully,
    id_bhvCustomSmallChillBully,
    id_bhvCustomSmallPenguin,
    id_bhvCustomSmallWhomp,
    id_bhvCustomSpindrift,
    id_bhvCustomSpiny,
    id_bhvCustomToadMessage,
    id_bhvCustomUkiki,
    id_bhvCustomWhompKingBoss,
    id_bhvCustomWigglerHead
}
--#endregion ----------------------------------------------------------------------------------------------------------------------------------
