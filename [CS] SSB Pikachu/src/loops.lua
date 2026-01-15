--#region Localizations ---------------------------------------------------------------------

local abs = math.abs
local common_air_action_step = common_air_action_step
local common_air_knockback_step = common_air_knockback_step
local coss = coss
local cur_obj_move_standard = cur_obj_move_standard
local cur_obj_play_sound_1 = cur_obj_play_sound_1
local cur_obj_update_floor_and_walls = cur_obj_update_floor_and_walls
local drop_and_set_mario_action = drop_and_set_mario_action
local get_hand_foot_pos_x = get_hand_foot_pos_x
local get_hand_foot_pos_y = get_hand_foot_pos_y
local get_hand_foot_pos_z = get_hand_foot_pos_z
local get_temp_object_hitbox = get_temp_object_hitbox
local is_anim_past_end = is_anim_past_end
local is_anim_past_frame = is_anim_past_frame
local lerp = math.lerp
local mario_set_forward_vel = mario_set_forward_vel
local max = math.max
local min = math.min
local network_init_object = network_init_object
local obj_angle_to_object = obj_angle_to_object
local obj_mark_for_deletion = obj_mark_for_deletion
local obj_scale_random = obj_scale_random
local obj_set_gfx_scale = obj_set_gfx_scale
local obj_set_hitbox = obj_set_hitbox
local obj_translate_xyz_random = obj_translate_xyz_random
local perform_air_step = perform_air_step
local perform_ground_step = perform_ground_step
local play_character_sound = play_character_sound
local play_sound = play_sound
local random = math.random
local set_anim_to_frame = set_anim_to_frame
local set_camera_shake_from_point = set_camera_shake_from_point
local set_character_anim_with_accel = set_character_anim_with_accel
local set_character_animation = set_character_animation
local set_mario_action = set_mario_action
local set_mario_particle_flags = set_mario_particle_flags
local sins = sins
local spawn_non_sync_object = spawn_non_sync_object
local spawn_sync_object = spawn_sync_object

--#endregion --------------------------------------------------------------------------------

local loops = {}

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable

---@param o Object
function loops.bhv_thunder_seg_init(o)
    local hb = get_temp_object_hitbox()

    hb.damageOrCoinValue = 4
    hb.downOffset = 0
    hb.health = 0
    hb.height = 150
    hb.radius = 150
    hb.interactType = INTERACT_DAMAGE
    hb.numLootCoins = 0
    hb.hurtboxHeight = 150
    hb.hurtboxRadius = 150

    obj_set_hitbox(o, hb)
end

---@param o Object
function loops.bhv_thunder_seg_loop(o)

    local m = states[getLocalFromGlobalIndex(o.oOwner)]
    if o.oTimer == 1 and m ~= nil then
        if o.oPosY > m.pos.y + 50 then
            if m.playerIndex == 0 then
                spawn_sync_object(id_bhvThunderSeg, E_MODEL_THUNDER_SEG, o.oPosX, o.oPosY - 49, o.oPosZ, function (nextO)
                    nextO.oOwner = o.oOwner
                end)
            end
        else
            spawn_non_sync_object(id_bhvHorStarParticleSpawner, E_MODEL_NONE, m.pos.x, m.pos.y, m.pos.z, function()end)
            spawn_non_sync_object(id_bhvMistCircParticleSpawner, E_MODEL_NONE, m.pos.x, m.pos.y, m.pos.z, function()end)
            set_camera_shake_from_point(SHAKE_POS_SMALL, m.pos.x, m.pos.y, m.pos.z)
            cur_obj_play_sound_1(SOUND_GENERAL_BIG_POUND)
        end
    end

    if o.oTimer % 3 == 0 then
        spawn_non_sync_object(id_bhvSparkleSpawn, E_MODEL_NONE, o.oPosX, o.oPosY, o.oPosZ, function()end)
    end

    if o.oTimer > 8 then
        obj_mark_for_deletion(o)
    end
end

---@param o Object
function loops.bhv_electro_particle_loop(o)

    spawn_non_sync_object(id_bhvSparkle, E_MODEL_ELECTRO_PARTICLE, o.oPosX, o.oPosY, o.oPosZ, function(p)
        obj_translate_xyz_random(p, 50)
        obj_scale_random(p, 2, 0.5)

        local r = random()
        if r > 0.9 then
            p.oBehParams2ndByte = 0
        elseif r > 0.6 then
            p.oBehParams2ndByte = 1
        elseif r > 0.2 then
            p.oBehParams2ndByte = 2
        else
            p.oBehParams2ndByte = 3
        end
    end)

    if o.oTimer > 1 then
        obj_mark_for_deletion(o)
    end
end

---@param o Object
function loops.bhv_electro_ball_init(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE

    local hb = get_temp_object_hitbox()

    hb.damageOrCoinValue = 2
    hb.downOffset = 20
    hb.health = 0
    hb.height = 70
    hb.radius = 70
    hb.interactType = INTERACT_SHOCK
    hb.numLootCoins = 0
    hb.hurtboxHeight = 50
    hb.hurtboxRadius = 50

    obj_set_hitbox(o, hb)

    network_init_object(o, true, {'oInteractStatus', 'oOwner'})
end

---@param o Object
function loops.bhv_electro_ball_loop(o)
    o.oFaceAnglePitch= o.oFaceAnglePitch + 0x1000
    o.oFaceAngleRoll = o.oFaceAngleRoll + 0x800

    cur_obj_update_floor_and_walls()

    if o.oAction == 0 then
        o.oGravity = -1.5
        o.oForwardVel = 20

        if abs(o.oPosY - o.oFloorHeight) <= 50 then
            o.oVelY = 0
            o.oPosY = o.oFloorHeight + 5
            o.oAction = 1
        end
    else
        spawn_non_sync_object(id_bhvElectroParticle, E_MODEL_NONE, o.oPosX, o.oPosY, o.oPosZ, function()end)

        o.oForwardVel = 30
        o.oGravity = -5

        if o.oMoveFlags & OBJ_MOVE_LANDED ~= 0 then
            o.oVelY = 30
        end

        if o.oTimer % 2 == 0 then
            cur_obj_play_sound_1(SOUND_AIR_AMP_BUZZ)
        end
    end

    cur_obj_move_standard(78)

    if o.oTimer > 130 or o.oMoveFlags & OBJ_MOVE_HIT_WALL ~= 0 or o.oInteractStatus & INT_STATUS_INTERACTED ~= 0 then
        obj_mark_for_deletion(o)
    end
end

---@param m MarioState
function loops.act_smash_normal(m)

    if m.actionState == 0 then
        playerTable[m.playerIndex].smashUpBlocked = true
        castElectroBall(m)

        if m.actionArg == 1 then
            return set_mario_action(m, ACT_JUMP_KICK, 0)
        end

        set_character_animation(m, CHAR_ANIM_FIRST_PUNCH)
        m.actionState = 1
    elseif m.actionState == 1 then
        if is_anim_past_end(m) ~= 0 then
            set_character_animation(m, CHAR_ANIM_FIRST_PUNCH_FAST)
            m.actionState = 2
        end
    end

    perform_ground_step(m)

    m.actionTimer = m.actionTimer + 1
    mario_set_forward_vel(m, max(0, 20 - m.actionTimer))

    if m.actionState == 2 and is_anim_past_end(m) ~= 0 then
        return set_mario_action(m, ACT_WALKING, 0)
    end
end

---@param m MarioState
function loops.act_smash_up(m)
    set_character_animation(m, CHAR_ANIM_DOUBLE_JUMP_FALL)

    if m.actionState == 0 then
        m.actionTimer = 3
        m.actionState = 1
    elseif m.actionState == 1 then

        m.squishTimer = 0
        m.vel.x = 0
        m.vel.y = 0
        m.vel.z = 0

        if m.actionArg > 1 or (m.actionArg == 1 and m.controller.buttonDown & (A_BUTTON | Z_TRIG) == 0 and m.intendedMag == 0) then
            m.actionState = 2
            return
        end

        if m.actionTimer > 3 then
            m.actionTimer = 0
            m.actionArg = m.actionArg + 1

            local flags = 0
            if m.intendedMag ~= 0 then
                m.faceAngle.y = m.intendedYaw
                flags = flags | B_BUTTON
            end

            if m.controller.buttonDown & A_BUTTON ~= 0 then
                flags = flags | A_BUTTON
            end

            if m.controller.buttonDown & Z_TRIG ~= 0 then
                flags = flags | Z_TRIG
            end

            if flags == 0 and m.actionArg == 1 then
                flags = A_BUTTON
            end

            m.actionState = 2 + flags

            play_character_sound(m, CHAR_SOUND_HOOHOO)
        end
    elseif m.actionState == 2 then
        common_air_action_step(m, ACT_FREEFALL_LAND, CHAR_ANIM_GENERAL_FALL, 0)
        m.peakHeight = m.pos.y
    else
        m.squishTimer = 5
        obj_set_gfx_scale(m.marioObj, 0.5, 1, 0.5)
        spawn_non_sync_object(id_bhvElectroParticle, E_MODEL_NONE, m.pos.x, m.pos.y, m.pos.z, function()end)

        m.pos.y = max(m.pos.y, m.floorHeight + 50)

        local flags = m.actionState - 2
        local speed = 100

        if flags & B_BUTTON ~= 0 then
            m.vel.x = speed * sins(m.faceAngle.y)
            m.vel.z = speed * coss(m.faceAngle.y)
        else
            m.vel.x = 0
            m.vel.z = 0
        end

        if flags & A_BUTTON ~= 0 then
            m.vel.y = speed
        elseif flags & Z_TRIG ~= 0 then
            m.vel.y = -speed
        else
            m.vel.y = 0
        end

        if perform_air_step(m, AIR_STEP_CHECK_LEDGE_GRAB) == AIR_STEP_GRABBED_LEDGE then
            m.squishTimer = 0
            set_character_animation(m, CHAR_ANIM_IDLE_ON_LEDGE)
            return drop_and_set_mario_action(m, ACT_LEDGE_GRAB, 0)
        end

        play_sound(SOUND_ENV_STAR, m.marioObj.header.gfx.cameraToObject)

        if m.actionTimer > 10 then
            m.actionTimer = 0
            m.actionState = 1
        end
    end

    m.actionTimer = m.actionTimer + 1
end

---@param m MarioState
function loops.act_smash_down(m)

    if m.actionTimer > 30 then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    set_character_anim_with_accel(m, CHAR_ANIM_TRIPLE_JUMP_LAND, 0.7 * 0x10000)

    if m.actionState == 0 then
        playerTable[m.playerIndex].smashUpBlocked = true
        play_character_sound(m, CHAR_SOUND_YAHOO)
        

        if m.playerIndex == 0 then
            spawn_sync_object(id_bhvThunderSeg, E_MODEL_THUNDER_SEG, m.pos.x, m.pos.y + 600, m.pos.z, function(o)
                o.oOwner = nps[0].globalIndex
            end)
        end

        m.vel.x = 0
        m.vel.z = 0
        m.forwardVel = 0

        m.actionState = 1
    else
        m.actionTimer = m.actionTimer + 1

        if m.floorHeight < m.pos.y and m.actionTimer > 15 then
            m.vel.y = -5
            perform_air_step(m, 0)
        end
    end
end

---@param m MarioState
function loops.act_smash_side(m)

    if m.actionState == 0 then
        playerTable[m.playerIndex].smashUpBlocked = true
        set_character_animation(m, CHAR_ANIM_DIVE)
        mario_set_forward_vel(m, 0)
        m.vel.y = 0
        m.actionState = 1
    elseif m.actionState == 1 then

        m.actionTimer = min(m.actionTimer + 1, 90)

        if is_anim_past_frame(m, 8) ~= 0 then
            set_anim_to_frame(m, 4)
        end

        if m.actionTimer % 5 == 0 then
            set_mario_particle_flags(m, PARTICLE_DUST, 0)
            play_sound(SOUND_ACTION_SPIN, m.pos)
        end

        m.vel.y = m.vel.y + 3
        perform_air_step(m, 0)

        if m.controller.buttonDown & B_BUTTON == 0 then

            m.actionArg = lerp(20, 200, m.actionTimer / 90)

            m.vel.y = 25
            if m.intendedMag > 0 then
                m.faceAngle.y = m.intendedYaw
            end

            play_character_sound(m, CHAR_SOUND_PUNCH_HOO)
            play_sound(SOUND_GENERAL_BOWSER_BOMB_EXPLOSION, m.pos)
            set_camera_shake_from_point(SHAKE_POS_SMALL, m.pos.x, m.pos.y, m.pos.z)

            m.actionTimer = min(60, m.actionTimer)
            m.actionState = 2
        end
    elseif m.actionState == 3 then
        common_air_action_step(m, ACT_FREEFALL_LAND, CHAR_ANIM_GENERAL_FALL, 0)
        m.peakHeight = m.pos.y
    else

        if m.actionTimer == 0 then
            m.actionState = 3
            return
        end

        set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0)

        mario_set_forward_vel(m, m.actionArg)
        m.vel.y = m.vel.y + 2

        local step = perform_air_step(m, 0)
        if step == AIR_STEP_HIT_WALL or playerTable[m.playerIndex].smashSideHit then
            playerTable[m.playerIndex].smashSideHit = false
            mario_set_forward_vel(m, 0)
            play_sound(SOUND_GENERAL_WALL_EXPLOSION, m.pos)
            set_camera_shake_from_point(SHAKE_POS_SMALL, m.pos.x, m.pos.y, m.pos.z)
            m.forwardVel = -15
            m.actionState = 3
            return
        elseif step == AIR_STEP_LANDED then
            return set_mario_action(m, ACT_GROUND_POUND_LAND, 0)
        end

        m.actionTimer = m.actionTimer - 1
    end

end

---@param m MarioState
function loops.act_turbo_shocked(m)

    if m.actionState == 0 then
        m.invincTimer = 30
        play_sound(SOUND_MOVING_SHOCKED, m.marioObj.header.gfx.cameraToObject)

        if set_character_animation(m, CHAR_ANIM_SHOCKED) == 0 then
            m.flags = m.flags | MARIO_METAL_SHOCK
        end

        m.actionTimer = m.actionTimer + 1

        if m.playerIndex == 0 then
            set_camera_shake_from_hit(SHAKE_SHOCK)
        end

        if m.actionTimer > 20 then

            local att = states[getLocalFromGlobalIndex(m.actionArg)]
            if att then
                m.faceAngle.y = obj_angle_to_object(m.marioObj, att.marioObj)
            end

            play_character_sound(m, CHAR_SOUND_ATTACKED)
            m.vel.y = 50
            m.actionState = 1
        end
    else
        set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0)
        common_air_knockback_step(m, ACT_BACKWARD_GROUND_KB, ACT_HARD_BACKWARD_GROUND_KB, 0x0002, -56)
    end
end

return loops