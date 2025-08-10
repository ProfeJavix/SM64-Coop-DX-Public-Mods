local hook_mario_action = hook_mario_action
local allocate_mario_action = allocate_mario_action
local set_mario_action = set_mario_action
local set_camera_shake_from_point = set_camera_shake_from_point
local play_mario_sound = play_mario_sound
local perform_ground_step = perform_ground_step
local perform_air_step = perform_air_step
local set_character_animation = set_character_animation
local set_anim_to_frame = set_anim_to_frame
local get_first_person_enabled = get_first_person_enabled
local set_first_person_enabled = set_first_person_enabled
local sins = sins
local coss = coss
local check_fall_damage = check_fall_damage
local drop_and_set_mario_action = drop_and_set_mario_action

local globalTable = gGlobalSyncTable

ACT_SG_SHOOT = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_MOVING | ACT_FLAG_ALLOW_FIRST_PERSON)
ACT_SG_GP_SHOOT = allocate_mario_action( ACT_FLAG_AIR | ACT_GROUP_AIRBORNE)
ACT_SG_BOOST_SHOOT = allocate_mario_action(ACT_FLAG_AIR | ACT_GROUP_AIRBORNE)

hook_mario_action(ACT_SG_SHOOT, function (m)

    if m.actionState ~= 0 and m.actionTimer == 0 then
        return set_mario_action(m, ternary(m.floorHeight == m.pos.y, ACT_WALKING, ACT_FREEFALL), 0)
    end

    if m.actionState == 0 then

        play_mario_sound(m, SOUND_OBJ_CANNON4, CHAR_SOUND_UH)
        set_camera_shake_from_point(SHAKE_POS_SMALL, m.pos.x, m.pos.y, m.pos.z)

        m.forwardVel = m.forwardVel * 0.6
        m.actionTimer = 15

        shootShotgun(m, 6, BULLET_DMG_LOW)

        m.actionState = 1
    else
        m.actionTimer = m.actionTimer - 1
    end

    if m.pos.y == m.floorHeight then
        perform_ground_step(m)
        set_character_animation(m, ternary(m.forwardVel ~= 0, CHAR_ANIM_SKID_ON_GROUND, CHAR_ANIM_PICK_UP_LIGHT_OBJ))
        if m.forwardVel == 0 then
            set_anim_to_frame(m, 10)
        end
    else
        perform_air_step(m, 0)
        set_character_animation(m, CHAR_ANIM_FALL_WITH_LIGHT_OBJ)
    end
end)

hook_mario_action(ACT_SG_GP_SHOOT, function (m)
    local step = 0

    if m.actionState == 0 then
        play_mario_sound(m, SOUND_OBJ_CANNON4, CHAR_SOUND_PUNCH_HOO)
        set_camera_shake_from_point(SHAKE_POS_MEDIUM, m.pos.x, m.pos.y, m.pos.z)

        m.faceAngle.x = 0x4000
        
        if m.playerIndex == 0 then
            m.faceAngle.y = ternary(get_first_person_enabled(), gFirstPersonCamera.yaw - 0x8000, m.intendedYaw)

            local vel, bullets, dmg = 70, 6, BULLET_DMG_MEDIUM
            if m.actionArg == 1 then
                vel, bullets, dmg = 100, 12, BULLET_DMG_HUGE
            end
            m.vel.x = vel * 0.4 * sins(m.faceAngle.y)
            m.vel.y = vel
            m.vel.z = vel * 0.4 * coss(m.faceAngle.y)
            shootShotgun(m, bullets, dmg, true)
            set_first_person_enabled(false)
        end
        m.peakHeight = m.pos.y
        m.actionState = 1
    else
        step = perform_air_step(m, AIR_STEP_CHECK_LEDGE_GRAB | AIR_STEP_CHECK_HANG)
        local anim = ternary(m.vel.y > 0, CHAR_ANIM_DOUBLE_JUMP_RISE, CHAR_ANIM_DOUBLE_JUMP_FALL)
        set_character_animation(m, anim)

        m.vel.x = m.vel.x + m.intendedMag / 32 * sins(m.intendedYaw)
        m.vel.z = m.vel.z + m.intendedMag / 32 * coss(m.intendedYaw)
    end

    if m.vel.y < -20 then
        if m.input & INPUT_B_PRESSED ~= 0 then
            return set_mario_action(m, ACT_DIVE, 0)
        elseif m.input & INPUT_Z_PRESSED ~= 0 and globalTable.allowFlyingGlitch then
            return set_mario_action(m, ACT_GROUND_POUND, 0)
        end
    end

    if step & AIR_STEP_LANDED ~= 0 then
        check_fall_damage(m, ACT_HARD_BACKWARD_GROUND_KB)
        return set_mario_action(m, ternary(m.action == ACT_SG_GP_SHOOT, ACT_JUMP_LAND, m.action), m.actionArg)
    elseif step & AIR_STEP_GRABBED_LEDGE ~= 0 then
        set_character_animation(m, CHAR_ANIM_IDLE_ON_LEDGE)
        drop_and_set_mario_action(m, ACT_LEDGE_GRAB, 0)
    elseif step & AIR_STEP_GRABBED_CEILING ~= 0 then
        set_mario_action(m, ACT_START_HANGING, 0)
    end
end)

hook_mario_action(ACT_SG_BOOST_SHOOT, function (m)

    local step = 0

    if m.actionState == 0 then
        play_mario_sound(m, SOUND_OBJ_CANNON4, CHAR_SOUND_HOOHOO)
        set_camera_shake_from_point(SHAKE_POS_MEDIUM, m.pos.x, m.pos.y, m.pos.z)

        if m.playerIndex == 0 then
            local yaw, pitch = ternary(get_first_person_enabled(), gFirstPersonCamera.yaw, gLakituState.yaw) - 0x8000, shotgunObjs[0].oFaceAnglePitch
            m.faceAngle.y = yaw
            m.forwardVel = 0
            m.vel.x = 80 * sins(yaw - 0x8000) * coss(pitch)
            m.vel.y = 120 * sins(pitch)
            m.vel.z = 80 * coss(yaw - 0x8000) * coss(pitch)
            
            shootShotgun(m, 12, BULLET_DMG_MEDIUM)
            set_first_person_enabled(false)
        end
        m.marioObj.header.gfx.angle.y = m.faceAngle.y
        m.actionState = 1
    else
        
        step = perform_air_step(m, AIR_STEP_CHECK_LEDGE_GRAB | AIR_STEP_CHECK_HANG)

        local anim = ternary(m.vel.y > 0, CHAR_ANIM_SLOW_LONGJUMP, CHAR_ANIM_DOUBLE_JUMP_FALL)
        set_character_animation(m, anim)

        m.vel.x = m.vel.x + m.intendedMag / 32 * sins(m.intendedYaw)
        m.vel.z = m.vel.z + m.intendedMag / 32 * coss(m.intendedYaw)

        m.peakHeight = m.pos.y
    end


    if step & AIR_STEP_LANDED ~= 0 then
        return set_mario_action(m, ACT_DOUBLE_JUMP_LAND, 0)
    elseif step & AIR_STEP_GRABBED_LEDGE ~= 0 then
        set_character_animation(m, CHAR_ANIM_IDLE_ON_LEDGE)
        drop_and_set_mario_action(m, ACT_LEDGE_GRAB, 0)
    elseif step & AIR_STEP_GRABBED_CEILING ~= 0 then
        set_mario_action(m, ACT_START_HANGING, 0)
    end
end)

SG_ACTIONS = {
    [ACT_SG_SHOOT] = true,
    [ACT_SG_GP_SHOOT] = true,
    [ACT_SG_BOOST_SHOOT] = true
}