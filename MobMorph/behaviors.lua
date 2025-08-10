local hookBhv = hook_behavior
local floor = math.floor
local defineCustomFields = define_custom_obj_fields
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
local object_step = object_step
local play_sound = play_sound
local cur_obj_init_animation = cur_obj_init_animation
local cur_obj_init_animation_with_sound = cur_obj_init_animation_with_sound
local cur_obj_init_animation_with_accel_and_sound = cur_obj_init_animation_with_accel_and_sound
local determine_interaction = determine_interaction
local cur_obj_update_floor_and_walls = cur_obj_update_floor_and_walls
local obj_turn_pitch_toward_mario = obj_turn_pitch_toward_mario
local dist_between_objects = dist_between_objects
local obj_angle_to_object = obj_angle_to_object
local obj_scale = obj_scale
local obj_copy_pos_and_angle = obj_copy_pos_and_angle
local get_temp_object_hitbox = get_temp_object_hitbox
local degrees_to_sm64 = degrees_to_sm64
local cur_obj_become_intangible = cur_obj_become_intangible
local cur_obj_become_tangible = cur_obj_become_tangible
local mario_drop_held_object = mario_drop_held_object

local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

--#region Bhv Utils ---------------------------------------------------------------------------------------------------------------------------

---@class Object
---@field oMorphedPlayer integer
---@field oDeleteMob integer
---@field oCustomTimer integer
---@field oCustomKoopaExposed integer
---@field oCustomWigglerPartIndex integer
---@field oCustomWigglerPartPosX number
---@field oCustomWigglerPartPosY number
---@field oCustomWigglerPartPosZ number
---@field oCustomWigglerPartYaw integer
---@field oCustomWigglerPartPitch integer

defineCustomFields({
    oMorphedPlayer = 's32',
    oDeleteMob = 's32',
    oCustomTimer = 's32',
    oCustomKoopaExposed = 's32',
    oCustomWigglerPartIndex = 's32',
    oCustomWigglerPartPosX = 'f32',
    oCustomWigglerPartPosY = 'f32',
    oCustomWigglerPartPosZ = 'f32',
    oCustomWigglerPartYaw = 's32',
    oCustomWigglerPartPitch = 's32'
})

---@param o Object
function common_init(o)
    o.oMorphedPlayer = -1
    network_init_object(o, true, {
        'oMorphedPlayer',
        'oDeleteMob',
        'oCustomTimer',
        'oCustomKoopaExposed'
    })
end

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

---@param o Object
---@param m MarioState
---@param isTypeAllowed boolean | nil
---@param forceLeave boolean | nil
---@return boolean
function common_check_if_cancel_morph(o, m, isTypeAllowed, forceLeave)
    isTypeAllowed = isTypeAllowed or true
    forceLeave = forceLeave or false
    return (m.controller.buttonPressed & X_BUTTON ~= 0 and playerTable[m.playerIndex].blockInputTimer == 0) or
    m.action ~= ACT_MORPHED or
    o.oAction >= 100 or
    (globalTable.mhMorphOnlyForHunters and getMHTeam(m.playerIndex) == 1) or not isTypeAllowed or
    (forceLeave and playerTable[m.playerIndex].leaveMobCooldown <= 0 and globalTable.morphedCooldown)
end

---@param o Object
---@param m MarioState
---@param giveKB boolean
function common_cancel_morph(o, m, giveKB)
    local idx = m.playerIndex
    o.oMorphedPlayer = -1
    m.usedObj = nil
    m.pos.y = maxf(m.pos.y - 300, m.floorHeight)
    playerTable[idx].blockInputTimer = 20
    playerTable[idx].morphCooldown = max(globalTable.startingMorphCooldown, floor(playerTable[idx].leaveMobCooldown or 0) / 2)

    if globalTable.morphedCooldown then
        playerTable[idx].leaveMobCooldown = 0
    end

    if o.oHeldState == HELD_HELD then
        local hm = states[globalIdxToLocal(o.heldByPlayerIndex)]
        mario_drop_held_object(hm)
        set_mario_action(hm, ACT_IDLE, 0)
    end

    if o.oAction >= 100 or o.activeFlags == ACTIVE_FLAG_DEACTIVATED or giveKB then
        set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    end
end

---@param o Object
function common_hide_with_parent(o)
    if o.parentObj ~= nil and o.parentObj.oMorphedPlayer ~= -1 then
        if o.parentObj.header.gfx.node.flags & GRAPH_RENDER_INVISIBLE ~= 0 then
            cur_obj_hide()
            cur_obj_become_intangible()
        else
            cur_obj_unhide()
            cur_obj_become_tangible()
        end
    end
end

---@param localIdx integer
function common_force_hide_with_player(localIdx)
    if playerTable[localIdx].blockInputTimer > 0 then
        cur_obj_hide()
        cur_obj_become_intangible()
    else
        cur_obj_unhide()
        cur_obj_become_tangible()
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Bobomb ------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_bobomb_loop(o)

    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]
        if common_check_if_cancel_morph(o, m) or (o.oPrevAction == BOBOMB_ACT_LAUNCHED and o.oAction == BOBOMB_ACT_EXPLODE) then
            common_cancel_morph(o, m, o.oPrevAction == BOBOMB_ACT_LAUNCHED and o.oAction == BOBOMB_ACT_EXPLODE)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oHeldState ~= HELD_FREE or (o.oAction ~= BOBOMB_ACT_CHASE_MARIO and o.oAction ~= BOBOMB_ACT_PATROL) then return end

        o.oBobombFuseLit = 1
        if o.oBobombFuseTimer > 60 then
            o.oBobombFuseTimer = 0
        end

        if m.controller.buttonPressed & Z_TRIG ~= 0 and o.oAction == BOBOMB_ACT_CHASE_MARIO then
            o.oAction = BOBOMB_ACT_EXPLODE
            sendObj(o)
            return
        end

        o.oAction = BOBOMB_ACT_CHASE_MARIO

        object_step()
        common_movement(o, m, true, 0x1000, 5, 40, false, 0)
        if localIdx == 0 then
            sendObj(o)
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
function bhv_custom_coin_inside_boo_loop(o)
    common_hide_with_parent(o)
end

---@param o Object
function bhv_custom_boo_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, (globalTable.allowBosses or o.oBehParams2ndByte ~= 2), o.oBehParams2ndByte == 2) or 
        (o.oHealth == 0 and o.oBehParams2ndByte == 2) or (o.oAction == 3 and o.oBehParams2ndByte ~= 2) then
            
            common_cancel_morph(o, m, o.oBehParams2ndByte == 2 and o.oHealth == 0)

            if o.oBehParams2ndByte == 2 then
                play_sound(SOUND_OBJ_BOO_LAUGH_LONG, m.marioObj.header.gfx.cameraToObject)
                obj_mark_for_deletion(o)
            else
                o.oAction = 3
                play_sound(SOUND_OBJ_DYING_ENEMY1, m.marioObj.header.gfx.cameraToObject)
            end
            cur_obj_become_intangible()
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
                    if interaction ~= INT_HIT_FROM_BELOW and 
                    dist_between_objects(nm.marioObj, o) <= nm.marioObj.hitboxRadius + o.hitboxRadius + 80 then
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
            o.oForwardVel = 40
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
            o.oForwardVel = 0
        end

        if m.controller.buttonDown & A_BUTTON ~= 0 then
            o.oVelY = 20
        end
        if (m.controller.buttonDown & Z_TRIG ~= 0 and o.oPosY > o.oFloorHeight + 50) then
            o.oVelY = -20
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Bully -------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_bully_loop(o)

    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        common_force_hide_with_player(localIdx)

        if common_check_if_cancel_morph(o, m, (globalTable.allowBosses or o.oBehParams2ndByte ~= BULLY_BP_SIZE_BIG), o.oBehParams2ndByte == BULLY_BP_SIZE_BIG) or
        (o.oAction >= 4 and o.oAction ~= 6) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
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
            o.oForwardVel = 15
            obj_check_floor_death(object_step(), o.oFloor)
        end

        local sp26 = o.header.gfx.animInfo.animFrame

        if m.controller.buttonDown & B_BUTTON ~= 0 then
            o.oForwardVel = 35
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
        --sendObj(o)
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

    if o.oDeleteMob == 1 then
        obj_mark_for_deletion(o)
        return
    end

    run_custom_timer(o)

    local idx = o.oMorphedPlayer
    if idx ~= -1 then

        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            o.oDeleteMob = 1
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        o.oHomeX = o.oPosX
        o.oHomeY = o.oPosY
        o.oHomeZ = o.oPosZ

        if common_check_if_cancel_morph(o, m, globalTable.allowBosses, true) or o.oAction == 4 then
            common_cancel_morph(o, m, o.oHealth <= 0)
            o.oDeleteMob = 1
            obj_mark_for_deletion(o)
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
            o.oAction = 17
            return
        end

        if m.controller.buttonPressed & B_BUTTON ~= 0 then
            o.oAction = 7
            return
        end

        if m.controller.buttonPressed & Z_TRIG ~= 0 and o.oCustomTimer == 0 then
            o.oAction = 16
            o.oCustomTimer = 150
            return
        end

        if m.controller.buttonPressed & D_JPAD ~= 0 then
            o.oAction = 9
            return
        end
        if m.controller.buttonPressed & U_JPAD ~= 0 and o.oCustomTimer == 0 then
            o.oAction = 8
            o.oCustomTimer = 240
            return
        end
        if m.controller.buttonPressed & R_JPAD ~= 0 then
            o.oAction = 15
            return
        end

        if m.intendedMag ~= 0 then
            o.oAction = 14
            cur_obj_rotate_yaw_toward(m.intendedYaw, 0x400)
        else
            o.oForwardVel = 0
            o.oAction = 18
        end

        --0: Idle?
        --1: Held
        --2: Recovery
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
function bhv_custom_wooden_post_loop(o)
    if o.parentObj ~= o and o.parentObj.oMorphedPlayer ~= -1 then
        if o.oMorphedPlayer == -1 then
            o.oMorphedPlayer = o.parentObj.oMorphedPlayer
            o.oBehParams = WOODEN_POST_BP_NO_COINS_MASK
        end

        if obj_has_model_extended(o, E_MODEL_WOODEN_POST) == 0 then
            obj_set_model_extended(o, E_MODEL_WOODEN_POST)
        end

        common_hide_with_parent(o)
    end

    if o.oMorphedPlayer ~= -1 and (o.parentObj == o or o.parentObj == nil or o.parentObj.activeFlags == ACTIVE_FLAG_DEACTIVATED) then
        obj_mark_for_deletion(o)
    end
end

---@param o Object
function bhv_custom_chain_chomp_chain_part_loop(o)
    if o.parentObj == nil or o.parentObj.activeFlags == ACTIVE_FLAG_DEACTIVATED then
        return
    end

    if obj_has_model_extended(o, E_MODEL_METALLIC_BALL) == 0 then
        obj_set_model_extended(o, E_MODEL_METALLIC_BALL)
    end

    common_hide_with_parent(o)
end

---@param o Object
function bhv_custom_chain_chomp_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)

        common_force_hide_with_player(localIdx)

        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, true, true) or o.oChainChompReleaseStatus ~= CHAIN_CHOMP_NOT_RELEASED then
            common_cancel_morph(o, m, o.oChainChompReleaseStatus ~= CHAIN_CHOMP_NOT_RELEASED)
            obj_mark_for_deletion(o)
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

    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, true, true) or (o.oAction == 2 and o.oFloorHeight > o.oPosY - 5) then
            common_cancel_morph(o, m, o.oAction == 2 and o.oFloorHeight > o.oPosY - 10)
            o.usingObj = nil
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oHeldState ~= HELD_FREE or o.oAction == 1 or o.oAction == 2 then return end
        o.oAction = 0
        o.oSubAction = 0
        cur_obj_init_animation_with_sound(4)
        play_sound(SOUND_AIR_CHUCKYA_MOVE, m.marioObj.header.gfx.cameraToObject)
        common_movement(o, m, true, 0x4000, 15, 30, false, 0)

    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Fly Guy -----------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_fly_guy_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        local nm = nearestAffectableMario(m)

        o.oAction = 4

        local lunging = false
        if m.controller.buttonDown & B_BUTTON ~= 0 then
            lunging = true
        end

        if m.intendedMag ~= 0 then
            o.oFaceAngleYaw = m.intendedYaw
            o.oMoveAngleYaw = m.intendedYaw
            if lunging then
                o.oForwardVel = 45
            else
                o.oForwardVel = 30
            end
        else
            o.oMoveAngleYaw = o.oFaceAngleYaw
            o.oForwardVel = 0
        end

        if m.controller.buttonPressed & R_JPAD ~= 0 and o.oTimer > 30 and localIdx == 0 then
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

        o.oVelY = 0
        if m.controller.buttonDown & A_BUTTON ~= 0 then
            o.oVelY = 15
            if lunging then
                o.oVelY = 30
            end
        end
        if m.controller.buttonDown & Z_TRIG ~= 0 and o.oPosY > o.oFloorHeight then
            o.oVelY = -15
            if lunging then
                o.oVelY = -30
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
function bhv_custom_huge_goomba_setup(o)
    o.oBehParams2ndByte = 1
    o.oGoombaSize = GOOMBA_SIZE_HUGE
    o.oGoombaScale = 3.5
    o.oDeathSound = SOUND_OBJ_ENEMY_DEATH_LOW
    o.oDrawingDistance = 4000
    o.oDamageOrCoinValue = 2
end

---@param o Object
function bhv_custom_tiny_goomba_setup(o)
    o.oBehParams2ndByte = 2
    o.oGoombaSize = GOOMBA_SIZE_TINY
    o.oGoombaScale = 0.5
    o.oDeathSound = SOUND_OBJ_ENEMY_DEATH_HIGH
    o.oDrawingDistance = 1500
end

---@param o Object
function bhv_custom_goomba_loop(o)
    local idx = o.oMorphedPlayer

    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oGoombaSize == GOOMBA_SIZE_TINY then
            o.oDamageOrCoinValue = 1
        end

        o.oHomeY = o.oPosY + 25000

        common_movement(o, m, true, 0x800, 15, 35, o.oFloorHeight == o.oPosY, 100 / 3 * o.oGoombaScale, SOUND_OBJ_GOOMBA_ALERT)
        cur_obj_play_sound_at_anim_range(2, 17, SOUND_OBJ_GOOMBA_WALK)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region King Bobomb -------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_king_bobomb_setup(o)
    o.oAction = 2
    o.oFlags = o.oFlags | OBJ_FLAG_HOLDABLE
end

---@param o Object
function bhv_custom_king_bobomb_loop(o)

    run_custom_timer(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then

        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        o.oHomeX = o.oPosX
        o.oHomeY = o.oPosY - 200 --avoid default jump
        o.oHomeZ = o.oPosZ

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, globalTable.allowBosses, true) or o.oAction >= 7 then
            common_cancel_morph(o, m, o.oAction >= 7)
            o.usingObj = nil
            obj_mark_for_deletion(o)
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
            if m.controller.buttonPressed & Z_TRIG ~= 0 and o.oCustomTimer == 0 then
                o.oCustomTimer = 20
                o.oForwardVel = 0
                o.oSubAction = 2
                --sendObj(o)
                return
            end   
        end

        common_movement(o, m, true, 0x400, 15, 25, (o.oAction == 2 and o.oPosY <= o.oFloorHeight + 50), 100, SOUND_OBJ_KING_BOBOMB_JUMP)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Koopa -------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_koopa_setup(o)
    o.oBehParams2ndByte = KOOPA_BP_NORMAL
    o.oKoopaMovementType = KOOPA_BP_NORMAL
end

---@param o Object
function bhv_custom_tiny_koopa_setup(o)
    o.oBehParams2ndByte = KOOPA_BP_TINY
    o.oKoopaMovementType = KOOPA_BP_TINY
    o.oKoopaAgility = 1.6 / 3
    o.oDrawingDistance = 1500
    obj_set_gfx_scale(o, 0.8, 0.8, 0.8)
    o.oGravity = -6.4 / 3
end

---@param o Object
function bhv_custom_koopa_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
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
                speed = 35
            elseif m.intendedMag ~= 0 then
                o.oAction = KOOPA_SHELLED_ACT_WALK
                speed = 20
            end
        elseif movementType == KOOPA_BP_UNSHELLED then
            if o.oAction == KOOPA_UNSHELLED_ACT_LYING and o.oCustomKoopaExposed == 0 then
                o.oCustomKoopaExposed = 1
                spawn_sync_object(id_bhvKoopaShell, E_MODEL_KOOPA_SHELL, o.oPosX, o.oPosY, o.oPosZ, nil)
                sendObj(o)
                return
            end

            if o.oAction == KOOPA_UNSHELLED_ACT_DIVE or o.oAction == KOOPA_UNSHELLED_ACT_LYING then return end

            cur_obj_init_animation_with_sound(3)
            cur_obj_play_sound_at_anim_range(0, 6, SOUND_OBJ_KOOPA_WALK)
            speed = 40

            if m.controller.buttonPressed & B_BUTTON ~= 0 then
                o.oAction = KOOPA_UNSHELLED_ACT_DIVE
            end
        end

        if o.oKoopaMovementType ~= KOOPA_BP_TINY then
            o.oDamageOrCoinValue = 2
        else
            o.oDamageOrCoinValue = 1
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
function bhv_custom_cloud_loop(o)

    if o.oBehParams2ndByte == CLOUD_BP_LAKITU_CLOUD and o.parentObj.oMorphedPlayer ~= -1 then
        if o.parentObj.header.gfx.node.flags & GRAPH_RENDER_INVISIBLE ~= 0 then
            obj_scale(o, 0)
        else
            obj_scale(o, 2)
        end
    end
end

---@param o Object
function bhv_custom_lakitu_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        common_force_hide_with_player(localIdx)

        if common_check_if_cancel_morph(o, m) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        o.oAction = 2

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
        elseif o.prevObj == nil then
            cur_obj_init_animation_with_sound(1)
        end

        cur_obj_play_sound_1(SOUND_AIR_LAKITU_FLY)
        if m.intendedMag ~= 0 then
            o.oFaceAngleYaw = m.intendedYaw
            o.oMoveAngleYaw = o.oFaceAngleYaw
            o.oForwardVel = 40
        else
            o.oForwardVel = 0
        end

        cur_obj_update_floor_and_walls()
        o.oVelY = 0
        if m.controller.buttonDown & A_BUTTON ~= 0 then
            o.oVelY = 15
        end
        if m.controller.buttonDown & Z_TRIG ~= 0 then
            o.oVelY = -15
        end
        cur_obj_move_standard(78)

        if m.controller.buttonPressed & B_BUTTON ~= 0 and o.oTimer > 30 and localIdx == 0 then
            o.oTimer = 0
            if o.prevObj == nil then
                o.prevObj = spawn_sync_object(id_bhvSpiny, E_MODEL_SPINY_BALL, o.oPosX, o.oPosY, o.oPosZ,
                    function(s)
                        s.oAction = SPINY_ACT_HELD_BY_LAKITU
                    end)
                    cur_obj_init_animation(3)
                    o.oEnemyLakituNumSpinies = o.oEnemyLakituNumSpinies + 1
            end
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Mad Piano ---------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_mad_piano_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, true, true) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        o.oGravity = -1
        o.oBounciness = 0
        
        if m.intendedMag ~= 0 then
            o.oAction = MAD_PIANO_ACT_ATTACK

            o.oHomeX = o.oPosX
            o.oHomeY = o.oPosY
            o.oHomeZ = o.oPosZ
        else
            o.oAction = MAD_PIANO_ACT_WAIT
        end
        common_movement(o, m, false, 0x800, 10, 35, o.oFloorHeight >= o.oPosY - 20, 40, SOUND_ACTION_METAL_JUMP)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Scuttlebug --------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_scuttlebug_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oSubAction == 4 or o.oSubAction == 5 then return end

        o.oSubAction = 6
        common_movement(o, m, true, 0x800, 10, 20, o.oFloorHeight == o.oPosY, 50, SOUND_OBJ2_SCUTTLEBUG_ALERT)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Skeeter -----------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_skeeter_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction == SKEETER_ACT_LUNGE then return end

        common_movement(o, m, true, 0x700, 10, 25, false, 0)

        if m.intendedMag == 0 or o.oMoveFlags & OBJ_MOVE_AT_WATER_SURFACE ~= 0 then
            o.oForwardVel = 0
            o.oAction = SKEETER_ACT_IDLE
        else
            o.oAction = SKEETER_ACT_WALK
        end

        if m.controller.buttonPressed & B_BUTTON ~= 0 and o.oMoveFlags & OBJ_MOVE_AT_WATER_SURFACE ~= 0 then
            o.oForwardVel = 100
            o.oAction = SKEETER_ACT_LUNGE
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Lil Penguin -------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_small_penguin_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, globalTable.allowNpcs) or o.oHeldState ~= HELD_FREE or o.oAction == 6 then
            common_cancel_morph(o, m, o.oAction == 6)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        local hitbox = get_temp_object_hitbox()
        hitbox.interactType = INTERACT_BOUNCE_TOP2
        hitbox.downOffset = 0
        hitbox.damageOrCoinValue = 1
        hitbox.health = 0
        hitbox.numLootCoins = 0
        hitbox.radius = 50
        hitbox.height = 50
        hitbox.hurtboxRadius = 50
        hitbox.hurtboxHeight = 50
        obj_set_hitbox(o, hitbox)
        cur_obj_become_tangible()

        if o.oInteractStatus & INT_STATUS_INTERACTED ~= 0 then
            if o.oInteractStatus & INT_STATUS_ATTACKED_MARIO == 0 then
                o.oAction = 6
                sendObj(o)
                return
            end
            o.oInteractStatus = 0
        end

        common_movement(o, m, true, 0x900, 10, 30, false, 0)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Spindrift ---------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_spindrift_loop(o)
    log_to_console(tostring(o.oTimer))
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m) then
            common_cancel_morph(o, m, false)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        if o.oAction == 1 then
            --sendObj(o)
            return
        end
        
        common_movement(o, m, true, 0x800, 20, 40, false, 0)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Toad Message ------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_toad_message_loop(o)

    run_custom_timer(o)
    
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, globalTable.allowNpcs) or o.oAction == 5 then

            common_cancel_morph(o, m, o.oAction == 5)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        o.oOpacity = 255
        o.oGravity = -2
        o.oWallHitboxRadius = 40

        local hitbox = get_temp_object_hitbox()
        hitbox.interactType = INTERACT_BOUNCE_TOP2
        hitbox.downOffset = 0
        hitbox.damageOrCoinValue = 1
        hitbox.health = 0
        hitbox.numLootCoins = 0
        hitbox.radius = 50
        hitbox.height = 50
        hitbox.hurtboxRadius = 50
        hitbox.hurtboxHeight = 50
        obj_set_hitbox(o, hitbox)
        cur_obj_become_tangible()

        if o.oInteractStatus & INT_STATUS_INTERACTED ~= 0 then
            if o.oInteractStatus & INT_STATUS_ATTACKED_MARIO == 0 then
                o.oAction = 5
                sendObj(o)
                return
            end
            o.oInteractStatus = 0
        end

        common_movement(o, m, true, 0x1000, 20, 40, o.oFloorHeight >= o.oPosY - 10, 25, SOUND_OBJ_WIGGLER_JUMP)

        local alignDegs = degrees_to_sm64(25)
        if m.intendedMag ~= 0 then
            cur_obj_init_animation_with_accel_and_sound(6, 2.1)
            o.oMoveAngleYaw = m.intendedYaw - alignDegs
            if o.header.gfx.animInfo.animFrame == 16 then
                cur_obj_play_sound_2(SOUND_OBJ_UKIKI_STEP_DEFAULT)
            end
        else
            cur_obj_init_animation(4)
        end

        --the model's front and the face angle are not aligned, so...
        o.oVelX = o.oForwardVel * sins(o.oMoveAngleYaw + alignDegs)
        o.oVelZ = o.oForwardVel * coss(o.oMoveAngleYaw + alignDegs)
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region Ukiki -------------------------------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_custom_ukiki_setup(o)
    o.oUkikiHasCap = o.oUkikiHasCap & ~UKIKI_CAP_ON
end

---@param o Object
function bhv_custom_ukiki_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        if common_check_if_cancel_morph(o, m, globalTable.allowNpcs) or o.oAction > UKIKI_ACT_JUMP then
            common_cancel_morph(o, m, o.oAction == 8)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        o.oInteractType = INTERACT_BOUNCE_TOP2
        o.oDamageOrCoinValue = 1

        local nm = nearestAffectableMario(m)
        if nm ~= nil and determine_interaction(nm, o) & (INT_PUNCH | INT_KICK | INT_GROUND_POUND_OR_TWIRL | INT_FAST_ATTACK_OR_SHELL) ~= 0 and 
        dist_between_objects(nm.marioObj, o) <= nm.marioObj.hitboxRadius + o.hitboxRadius + 80 then
            play_sound(SOUND_OBJ_DYING_ENEMY1, m.pos)
            o.oAction = 8
            sendObj(o)
            return
        end

        common_movement(o, m, false, 0x3000, 15, 35, o.oFloorHeight >= o.oPosY - 30, 80, SOUND_OBJ_UKIKI_CHATTER_LONG)

        if m.intendedMag ~= 0 then
            o.oAction = UKIKI_ACT_RUN
        else
            o.oAction = UKIKI_ACT_IDLE
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
function bhv_custom_whomp_setup(o)
    o.oAction = 10
end

---@param o Object
function bhv_custom_whomp_loop(o)
    run_custom_timer(o)

    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)
        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        local m = states[localIdx]

        common_force_hide_with_player(localIdx)

        if common_check_if_cancel_morph(o, m, (globalTable.allowBosses or o.oBehParams2ndByte == 0), o.oBehParams2ndByte ~= 0) or
        (o.oBehParams2ndByte ~= 0 and o.oHealth == 0) or (o.oBehParams2ndByte == 0 and o.oAction == 8) then
            common_cancel_morph(o, m, (o.oBehParams2ndByte ~= 0 and o.oHealth == 0) or (o.oBehParams2ndByte == 0 and o.oAction == 8))
            obj_mark_for_deletion(o)
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
            --sendObj(o)
            return
        end

        local speed = 10
        if m.controller.buttonDown & B_BUTTON ~= 0 then
            speed = 25
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

--This mdfckr used to crash the game, so screw it

---@param o Object
function bhv_custom_wiggler_body_init(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.oAnimations = gObjectAnimations.wiggler_seg5_anims_0500C874

    o.oGravity = -4
    o.oDragStrength = 10
    o.oFriction = 10
    o.oBuoyancy = 2

    cur_obj_hide()
    cur_obj_scale(4)

    network_init_object(o, true, {
        'oFaceAnglePitch',
        'oWigglerWalkAnimSpeed',
        'oWigglerSquishSpeed',
        'oHealth',
        'oFaceAngleYaw',
        'oCustomWigglerPartPosX',
        'oCustomWigglerPartPosY',
        'oCustomWigglerPartPosZ',
        'oCustomWigglerPartYaw',
        'oCustomWigglerPartPitch'
    })
end

---@param o Object
---@return table
function wiggler_get_parts(o)
    local parts = {}
    table.insert(parts, o)
    local prev = o
    local cur = obj_get_first_with_behavior_id(id_bhvCustomWigglerBody)
    while cur do
        if cur.parentObj == prev then
            table.insert(parts, cur)
            prev = cur
        end
        cur = obj_get_next_with_same_behavior_id(cur)
    end

    table.sort(parts, function(a,b)
        return a.oCustomWigglerPartIndex < b.oCustomWigglerPartIndex
    end)

    return parts
end

---@param o Object
function bhv_custom_wiggler_body_loop(o)

    local parent = o.parentObj
    if not parent or parent.activeFlags == ACTIVE_FLAG_DEACTIVATED then
        obj_mark_for_deletion(o)
        return
    end
    common_hide_with_parent(o)

    o.oHealth = parent.oHealth
    o.oWigglerWalkAnimSpeed = parent.oWigglerWalkAnimSpeed

    cur_obj_scale(parent.header.gfx.scale.x)

    o.oFaceAngleYaw = o.oCustomWigglerPartYaw
    o.oFaceAnglePitch = o.oCustomWigglerPartPitch

    local posOffset = -37.5 * o.header.gfx.scale.x
    local dxz = posOffset * sins(o.oFaceAnglePitch)
    local dx = dxz * sins(o.oFaceAngleYaw)
    local dy = posOffset * coss(o.oFaceAnglePitch) - posOffset
    local dz = dxz * coss(o.oFaceAngleYaw)

    o.oPosX = o.oCustomWigglerPartPosX + dx
    o.oPosY = o.oCustomWigglerPartPosY + dy
    o.oPosZ = o.oCustomWigglerPartPosZ + dz

    o.oCustomWigglerPartPosY = o.oPosY

    cur_obj_init_animation_with_accel_and_sound(0, parent.oWigglerWalkAnimSpeed)
    if parent.oWigglerWalkAnimSpeed == 0 then
        cur_obj_reverse_animation()
    end

    cur_obj_become_tangible()

    local hb = get_temp_object_hitbox()
    hb.interactType = 32768
    hb.downOffset = 0
    hb.damageOrCoinValue = 3
    hb.numLootCoins = 0
    hb.radius = 30
    hb.height = 30
    hb.hurtboxRadius = 30
    hb.hurtboxHeight = 10

    obj_check_attacks(hb, o.oAction)
end

---@param o Object
---@return ObjectHitbox
function wiggler_get_hitbox(o)
    local hb = get_temp_object_hitbox()

    hb.interactType = 32768
    hb.downOffset = 0
    hb.damageOrCoinValue = 3
    hb.health = o.oHealth
    hb.numLootCoins = 0
    hb.radius = 60
    hb.height = 50
    hb.hurtboxRadius = 30
    hb.hurtboxHeight = 40

    return hb
end

---@param val number
---@param target number
---@param delta number
---@return number, boolean
function approach_f32_wiggler(val, target, delta)

    if val > target then
        delta = -delta
    end

    val = val + delta

    if (val - target) * delta >= 0 then
        val = target
        return val, true
    end
    return val, false
end

---@param o Object
function bhv_custom_wiggler_head_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_COMPUTE_ANGLE_TO_MARIO | OBJ_FLAG_COMPUTE_DIST_TO_MARIO | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    o.oAnimations = gObjectAnimations.wiggler_seg5_anims_0500EC8C

    o.oWallHitboxRadius = 60
    o.oGravity = -4
    o.oDragStrength = 10
    o.oFriction = 10
    o.oBuoyancy = 2

    cur_obj_hide()
    cur_obj_scale(4)

    o.oMorphedPlayer = -1
    o.oHealth = 3

    network_init_object(o, true, {
        'oFaceAnglePitch',
        'oWigglerWalkAnimSpeed',
        'oWigglerSquishSpeed',
        'oHealth',
        'oFaceAngleYaw',
        'oCustomWigglerPartPosX',
        'oCustomWigglerPartPosY',
        'oCustomWigglerPartPosZ',
        'oCustomWigglerPartYaw',
        'oCustomWigglerPartPitch',
        'oMorphedPlayer'
    })
end

---@param o Object
function bhv_custom_wiggler_head_loop(o)
    local idx = o.oMorphedPlayer
    if idx ~= -1 then
        local localIdx = globalIdxToLocal(idx)

        if localIdx == -1 then
            obj_mark_for_deletion(o)
            return
        end

        if o.oAction == WIGGLER_ACT_UNINITIALIZED then

            local parts = wiggler_get_parts(o)
            for i = 2, #parts do
                obj_mark_for_deletion(parts[i])
            end

            local prevPart = o
            for i = 1, 3 do
                local part = spawn_sync_object(id_bhvCustomWigglerBody, E_MODEL_WIGGLER_BODY, o.oPosX, o.oPosY, o.oPosZ, function (part)
                    part.parentObj = prevPart
                    part.oCustomWigglerPartIndex = i
                    part.oCustomWigglerPartPosX = o.oPosX
                    part.oCustomWigglerPartPosY = o.oPosY
                    part.oCustomWigglerPartPosZ = o.oPosZ
                    part.oCustomWigglerPartYaw = o.oFaceAngleYaw
                    part.oCustomWigglerPartPitch = o.oFaceAnglePitch
                end)
                prevPart = part
            end
            
            o.oTimer = 0
            o.oAction = WIGGLER_ACT_WALK
            return
        end

        local m = states[localIdx]

        common_force_hide_with_player(localIdx)

        if common_check_if_cancel_morph(o, m, globalTable.allowBosses, true) or o.oHealth <= 0 then
            common_cancel_morph(o, m, o.oHealth <= 0)
            obj_mark_for_deletion(o)
            if localIdx == 0 then
                sendObj(o)
            end
            return
        end

        cur_obj_init_animation_with_accel_and_sound(0, o.oWigglerWalkAnimSpeed)
        if o.oWigglerWalkAnimSpeed ~= 0 then
            local sound = o.oHealth >= 4 and SOUND_OBJ_WIGGLER_LOW_PITCH or SOUND_OBJ_WIGGLER_HIGH_PITCH
            cur_obj_play_sound_at_anim_range(0, 13, sound)
        else
            cur_obj_reverse_animation()
        end

        cur_obj_update_floor_and_walls()

        local speed = 15
        if m.controller.buttonDown & B_BUTTON ~= 0 then
            speed = 35
        end

        if o.oAction == WIGGLER_ACT_WALK then
            cur_obj_become_intangible()
            o.oWigglerWalkAnimSpeed = 0.06 * o.oForwardVel
            o.oForwardVel = m.intendedMag / 32 * speed

            if m.controller.buttonPressed & A_BUTTON ~= 0 and o.oMoveFlags & OBJ_MOVE_ON_GROUND ~= 0 then
                o.oVelY = 70
                play_sound(SOUND_OBJ_WIGGLER_JUMP, m.marioObj.header.gfx.cameraToObject)
            end

            if m.intendedMag ~= 0 then
                cur_obj_rotate_yaw_toward(m.intendedYaw, 0x2000)
            end

            obj_face_yaw_approach(o.oMoveAngleYaw, 60 * o.oForwardVel);
            obj_face_pitch_approach(0, 0x320)

            cur_obj_become_tangible()
            obj_set_hitbox(o, wiggler_get_hitbox(o))
            
            if o.oTimer >= 60 then
                local handleAtt = obj_die_if_above_lava_and_health_non_positive()
                
                if handleAtt == 0 and o.oInteractStatus & INT_STATUS_INTERACTED ~= 0 and o.oInteractStatus & INT_STATUS_ATTACKED_MARIO == 0 then
                    handleAtt = o.oInteractStatus & INT_STATUS_ATTACK_MASK

                    if handleAtt == ATTACK_FROM_ABOVE or handleAtt == ATTACK_GROUND_POUND_OR_TWIRL then
                        cur_obj_play_sound_2(SOUND_OBJ_WIGGLER_ATTACKED)
                        if o.header.gfx.scale.x == 1 then
                            o.oAction = WIGGLER_ACT_KNOCKBACK
                        else
                            o.oAction = WIGGLER_ACT_JUMPED_ON
                            o.oHealth = o.oHealth - 1
                            o.oForwardVel = 0
                            o.oVelY = 0
                            o.oWigglerSquishSpeed = 0.4
                        end
                    else
                        obj_set_knockback_action(handleAtt)
                    end
                end
                o.oInteractStatus = 0

                if handleAtt ~= 0 then
                    if o.oAction ~= WIGGLER_ACT_JUMPED_ON then
                        o.oAction = WIGGLER_ACT_KNOCKBACK
                    end
                    o.oWigglerWalkAnimSpeed = 0
                    sendObj(o)
                end
                
            end
        elseif o.oAction == WIGGLER_ACT_KNOCKBACK then
            if o.oVelY > 0 then
                o.oFaceAnglePitch = o.oFaceAnglePitch - o.oVelY * 30
            else
                obj_face_pitch_approach(0, 0x190)
            end

            if obj_forward_vel_approach(0, 1) ~= 0 and o.oFaceAnglePitch == 0 then
                o.oAction = WIGGLER_ACT_WALK
                o.oMoveAngleYaw = o.oFaceAngleYaw
            end
        
            obj_check_attacks(wiggler_get_hitbox(o), o.oAction)
        elseif o.oAction == WIGGLER_ACT_JUMPED_ON then

            local aux1, aux2 = approach_f32_wiggler(o.oWigglerSquishSpeed, 0, 0.05)
            o.oWigglerSquishSpeed = aux1

            if aux2 then
                o.header.gfx.scale.y = approach_f32_wiggler(o.header.gfx.scale.y, 4, 0.2)
            else
                o.header.gfx.scale.y = o.header.gfx.scale.y - o.oWigglerSquishSpeed
            end

            if o.header.gfx.scale.y >= 4 then
                if o.oTimer > 30 then
                    o.oAction = WIGGLER_ACT_WALK
                    o.oMoveAngleYaw = o.oFaceAngleYaw
                end
            else
                o.oTimer = 0
            end
        
            obj_check_attacks(wiggler_get_hitbox(o), o.oAction)
        end
        cur_obj_move_standard(-78)

        o.oCustomWigglerPartPosX = o.oPosX
        o.oCustomWigglerPartPosY = o.oPosY
        o.oCustomWigglerPartPosZ = o.oPosZ
        o.oCustomWigglerPartYaw = o.oFaceAngleYaw
        o.oCustomWigglerPartPitch = o.oFaceAnglePitch

        local parts = wiggler_get_parts(o)
        if #parts ~= 4 and o.oTimer > 5 then
            o.oAction = WIGGLER_ACT_UNINITIALIZED
            return
        end
        for i = 1, #parts do
            prevPart = parts[i - 1]
            curPart = parts[i]

            if not prevPart or not curPart then goto continue end

            local dx = curPart.oCustomWigglerPartPosX - prevPart.oCustomWigglerPartPosX
            local dy = curPart.oCustomWigglerPartPosY - prevPart.oCustomWigglerPartPosY
            local dz = curPart.oCustomWigglerPartPosZ - prevPart.oCustomWigglerPartPosZ

            local dYaw = atan2s(-dz, -dx) - prevPart.oCustomWigglerPartYaw
            curPart.oCustomWigglerPartYaw = prevPart.oCustomWigglerPartYaw + clamp(dYaw, -0x2000, 0x2000)

            local dxz = sqrf(dx * dx + dz * dz)
            local dPitch = atan2s(dxz, dy) - prevPart.oCustomWigglerPartPitch
            curPart.oCustomWigglerPartPitch = prevPart.oCustomWigglerPartPitch + clamp(dPitch, -0x2000, 0x2000)

            dxz = 140 * coss(curPart.oCustomWigglerPartPitch)
            curPart.oCustomWigglerPartPosX = prevPart.oCustomWigglerPartPosX - dxz * sins(curPart.oCustomWigglerPartYaw)
            curPart.oCustomWigglerPartPosY = 140 * sins(curPart.oCustomWigglerPartPitch) + prevPart.oCustomWigglerPartPosY
            curPart.oCustomWigglerPartPosZ = prevPart.oCustomWigglerPartPosZ - dxz * coss(curPart.oCustomWigglerPartYaw)

            ::continue::
        end
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------------------------------

--#region BHV Hooks ---------------------------------------------------------------------------------------------------------------------------
id_bhvCustomBigBoo = hookBhv(id_bhvBalconyBigBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomBigBully = hookBhv(id_bhvBigBully, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bully_loop)
id_bhvCustomBobomb = hookBhv(id_bhvBobomb, OBJ_LIST_DESTRUCTIVE, false, common_init, bhv_custom_bobomb_loop)
id_bhvCustomBoo = hookBhv(id_bhvBoo, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_boo_loop)
id_bhvCustomBowser = hookBhv(id_bhvBowser, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bowser_loop)
id_bhvCustomChainChomp = hookBhv(id_bhvChainChomp, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_chain_chomp_loop)
id_bhvCustomChainChompChainPart = hookBhv(id_bhvChainChompChainPart, OBJ_LIST_GENACTOR, false, nil, bhv_custom_chain_chomp_chain_part_loop)
id_bhvCustomChuckya = hookBhv(id_bhvChuckya, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_chuckya_loop)
id_bhvCustomCloud = hookBhv(id_bhvCloud, OBJ_LIST_DEFAULT, false, common_init, bhv_custom_cloud_loop)
id_bhvCustomCoinInsideBoo = hookBhv(id_bhvCoinInsideBoo, OBJ_LIST_LEVEL, false, common_init, bhv_custom_coin_inside_boo_loop)
id_bhvCustomEnemyLakitu = hookBhv(id_bhvEnemyLakitu, OBJ_LIST_PUSHABLE, false, common_init, bhv_custom_lakitu_loop)
id_bhvCustomFlyGuy = hookBhv(id_bhvFlyGuy, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_fly_guy_loop)
id_bhvCustomGoomba = hookBhv(id_bhvGoomba, OBJ_LIST_PUSHABLE, false, common_init, bhv_custom_goomba_loop)
id_bhvCustomKingBobomb = hookBhv(id_bhvKingBobomb, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_king_bobomb_loop)
id_bhvCustomKoopa = hookBhv(id_bhvKoopa, OBJ_LIST_PUSHABLE, false, common_init, bhv_custom_koopa_loop)
id_bhvCustomMadPiano = hookBhv(id_bhvMadPiano, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_mad_piano_loop)
id_bhvCustomScuttlebug = hookBhv(id_bhvScuttlebug, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_scuttlebug_loop)
id_bhvCustomSkeeter = hookBhv(id_bhvSkeeter, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_skeeter_loop)
id_bhvCustomSmallBully = hookBhv(id_bhvSmallBully, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_bully_loop)
id_bhvCustomSmallPenguin = hookBhv(id_bhvSmallPenguin, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_small_penguin_loop)
id_bhvCustomSmallWhomp = hookBhv(id_bhvSmallWhomp, OBJ_LIST_SURFACE, false, common_init, bhv_custom_whomp_loop)
id_bhvCustomSpindrift = hookBhv(id_bhvSpindrift, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_spindrift_loop)
id_bhvCustomToadMessage = hookBhv(id_bhvToadMessage, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_toad_message_loop)
id_bhvCustomUkiki = hookBhv(id_bhvUkiki, OBJ_LIST_GENACTOR, false, common_init, bhv_custom_ukiki_loop)
id_bhvCustomWhompKingBoss = hookBhv(id_bhvWhompKingBoss, OBJ_LIST_SURFACE, false, common_init, bhv_custom_whomp_loop)
id_bhvCustomWigglerBody = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhv_custom_wiggler_body_init, bhv_custom_wiggler_body_loop)
id_bhvCustomWigglerHead = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhv_custom_wiggler_head_init, bhv_custom_wiggler_head_loop)
id_bhvCustomWoodenPost = hookBhv(id_bhvWoodenPost, OBJ_LIST_SURFACE, false, common_init, bhv_custom_wooden_post_loop)
--#endregion ----------------------------------------------------------------------------------------------------------------------------------

-- 1: bhvId | 2: name | 3: model | 4: leave cooldown (-1 == none) | 5: setup function | 6: spawn on ground | 7: limit per level (-1 == no limit) | 8: action arg
ALLOWED_MOBS = {
    {id_bhvCustomBobomb, 'Bob-Omb', E_MODEL_BLACK_BOBOMB, -1, nil, false, 9, 0},
    {id_bhvCustomBoo, 'Boo', E_MODEL_BOO, -1, nil, false, -1, 0},
    {id_bhvCustomChainChomp, 'Chain Chomp', E_MODEL_CHAIN_CHOMP, 1500, nil, true, 3, 0},
    {id_bhvCustomChuckya, 'Chuckya', E_MODEL_CHUCKYA, 600, nil, false, -1, 1},
    {id_bhvCustomFlyGuy, 'Fly Guy', E_MODEL_FLYGUY, -1, nil, false, -1, 0},
    {id_bhvCustomGoomba, 'Goomba', E_MODEL_GOOMBA, -1, nil, false, -1, 0},
    {id_bhvCustomGoomba, 'Goomba (Huge)', E_MODEL_GOOMBA, -1, bhv_custom_huge_goomba_setup, false, -1, 0},
    {id_bhvCustomGoomba, 'Goomba (Tiny)', E_MODEL_GOOMBA, -1, bhv_custom_tiny_goomba_setup, false, -1, 0},
    {id_bhvCustomKoopa, 'Koopa', E_MODEL_KOOPA_WITH_SHELL, -1, bhv_custom_koopa_setup, false, -1, 0},
    {id_bhvCustomKoopa, 'Koopa (Tiny)', E_MODEL_KOOPA_WITH_SHELL, -1, bhv_custom_tiny_koopa_setup, false, -1, 0},
    {id_bhvCustomEnemyLakitu, 'Lakitu', E_MODEL_ENEMY_LAKITU, -1, nil, false, -1, 0},
    {id_bhvCustomMadPiano, 'Mad Piano', E_MODEL_MAD_PIANO, 600, nil, true, -1, 0},
    {id_bhvCustomScuttlebug, 'Scuttlebug', E_MODEL_SCUTTLEBUG, -1, nil, false, -1, 0},
    {id_bhvCustomSkeeter, 'Skeeter', E_MODEL_SKEETER, -1, nil, false, -1, 0},
    {id_bhvCustomSmallBully, 'Small Bully', E_MODEL_BULLY, -1, nil, false, -1, 0},
    {id_bhvCustomSmallBully, 'Small Chill Bully', E_MODEL_CHILL_BULLY, -1, nil, false, -1, 0},
    {id_bhvCustomSmallWhomp, 'Small Whomp', E_MODEL_WHOMP, -1, bhv_custom_whomp_setup, true, -1, 2},
    {id_bhvCustomSpindrift, 'Spindrift', E_MODEL_SPINDRIFT, -1, nil, false, -1, 0}
}

ALLOWED_BOSSES = {
    {id_bhvCustomBigBoo, 'Big Boo', E_MODEL_BOO, 1800, nil, false, -1, 0},
    {id_bhvCustomBigBully, 'Big Bully', E_MODEL_BULLY_BOSS, 1500, nil, false, -1, 0},
    {id_bhvCustomBigBully, 'Big Chill Bully', E_MODEL_BIG_CHILL_BULLY, 1500, nil, false, -1, 0},
    {id_bhvCustomBowser, 'Bowser', E_MODEL_BOWSER, 450, nil, true, 1, 1},
    {id_bhvCustomKingBobomb, 'King Bob-Omb', E_MODEL_KING_BOBOMB, 900, bhv_custom_king_bobomb_setup, true, 2, 0},
    {id_bhvCustomWhompKingBoss, 'King Whomp', E_MODEL_WHOMP, 900, nil, true, 2, 0},
    {id_bhvCustomWigglerHead, 'Wiggler', E_MODEL_WIGGLER_HEAD, 900, nil, true, 2, 0}
}

ALLOWED_NPCS = {
    {id_bhvCustomSmallPenguin, 'Small Penguin', E_MODEL_PENGUIN, -1, nil, true, -1, 0},
    {id_bhvCustomToadMessage, 'Toad', E_MODEL_TOAD, -1, nil, true, -1, 0},
    {id_bhvCustomUkiki, 'Ukiki', E_MODEL_UKIKI, -1, bhv_custom_ukiki_setup, true, -1, 0}
}