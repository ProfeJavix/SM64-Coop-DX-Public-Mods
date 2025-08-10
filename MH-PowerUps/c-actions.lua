if not _G.mhExists then return end

local spawn_sync_object = spawn_sync_object
local spawn_non_sync_object = spawn_non_sync_object
local allocate_mario_action = allocate_mario_action
local perform_ground_step = perform_ground_step
local perform_air_step = perform_air_step
local play_sound = play_sound
local set_camera_shake_from_point = set_camera_shake_from_point
local set_character_animation = set_character_animation
local set_mario_action = set_mario_action
local hookAction = hook_mario_action
local apply_slope_decel = apply_slope_decel
local play_character_sound = play_character_sound
local set_mario_particle_flags = set_mario_particle_flags
local update_air_without_turn = update_air_without_turn
local set_first_person_enabled = set_first_person_enabled
local common_air_knockback_step = common_air_knockback_step
local set_anim_to_frame = set_anim_to_frame

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable

---@param pos Vec3f
function spawnMist(pos)
    spawn_non_sync_object(id_bhvMistCircParticleSpawner, E_MODEL_MIST, pos.x, pos.y, pos.z, function() end)
end

--#region HAMMER ---------------------------------------------------------------------------------------------------------
ACT_HAMMER_SWING = allocate_mario_action(ACT_FLAG_ATTACKING | ACT_FLAG_STATIONARY)
ACT_HAMMER_360 = allocate_mario_action(ACT_FLAG_ATTACKING)
ACT_HAMMER_GROUND_POUND = allocate_mario_action(ACT_FLAG_ATTACKING | ACT_FLAG_AIR | ACT_GROUP_AIRBORNE)
ACT_HAMMER_DIVE_GROUND_POUND = allocate_mario_action(ACT_FLAG_ATTACKING | ACT_FLAG_AIR | ACT_GROUP_AIRBORNE)

---@param m MarioState
---@return boolean
function pound_ground(m)
    if perform_air_step(m, 0) == AIR_STEP_LANDED then
        spawnMist(getHammerPos(m.pos, m.faceAngle.y))
        play_sound(SOUND_GENERAL_WALL_EXPLOSION, m.pos)
        set_camera_shake_from_point(SHAKE_POS_SMALL, m.pos.x, m.pos.y, m.pos.z)
        set_character_animation(m, CHAR_ANIM_SLOW_LAND_FROM_DIVE)
        m.forwardVel = 0
        m.actionTimer = 30
        return true
    end
    return false
end

hookAction(ACT_HAMMER_SWING, function(m)
    if m.actionTimer <= 0 and m.actionState ~= 0 then
        return set_mario_action(m, ACT_IDLE, 0)
    end
    perform_ground_step(m)
    if m.forwardVel > 0 then
        apply_slope_decel(m, 2)
    end
    if m.actionState == 0 then
        
        m.actionTimer = 15
        set_character_animation(m, CHAR_ANIM_FIRST_PUNCH)
        play_character_sound(m, CHAR_SOUND_HAHA)
        m.actionState = 1
    else
        m.actionTimer = m.actionTimer - 1
    end
end)

hookAction(ACT_HAMMER_360, function(m)
    if m.actionTimer <= 0 and m.actionState ~= 0 then
        return set_mario_action(m, ACT_IDLE, 0)
    end
    
    if m.actionState == 0 then
        m.actionTimer = 60
        set_character_animation(m, CHAR_ANIM_HOLDING_BOWSER)
        play_character_sound(m, CHAR_SOUND_HERE_WE_GO)
        m.actionState = 1
    elseif m.actionState == 1 then
        if m.actionTimer % 10 == 0 then
            spawnMist(m.pos)
        end
        set_mario_particle_flags(m, PARTICLE_MIST_CIRCLE, 0)
        m.faceAngle.y = m.faceAngle.y + 0x1200
        m.marioObj.header.gfx.angle.y = m.faceAngle.y
        m.actionTimer = m.actionTimer - 1

        if m.actionTimer <= 30 then
            set_character_animation(m, CHAR_ANIM_RELEASE_BOWSER)
            m.actionState = 2
        end

    else
        m.actionTimer = m.actionTimer - 1
    end
end)

hookAction(ACT_HAMMER_GROUND_POUND, function(m)
    if m.actionTimer <= 0 and m.actionState == 3 and m.floorHeight >= m.pos.y then
        return set_mario_action(m, ACT_WALKING, 0)
    end
    if m.actionState == 0 then
        set_character_animation(m, CHAR_ANIM_HOLDING_BOWSER)
        play_character_sound(m, CHAR_SOUND_WHOA)
        m.twirlYaw = m.faceAngle.y
        m.forwardVel = 0
        m.actionState = 1
    elseif m.actionState == 1 then

        m.twirlYaw = m.twirlYaw + 0x1000
        m.marioObj.header.gfx.angle.y = m.twirlYaw

        if m.faceAngle.y == m.twirlYaw then

            play_sound(SOUND_ACTION_TWIRL, m.pos)
            set_character_animation(m, CHAR_ANIM_DIVE)
            m.actionState = 2
        end
    elseif m.actionState == 2 then
        m.vel.y = -70
        if pound_ground(m) then
            m.actionState = 3
        end
    else
        m.actionTimer = m.actionTimer - 1
    end
end)

hookAction(ACT_HAMMER_DIVE_GROUND_POUND, function(m)
    if m.actionTimer <= 0 and m.actionState == 2 and m.floorHeight >= m.pos.y then
        return set_mario_action(m, ACT_WALKING, 0)
    end
    if m.actionState == 0 then
        set_character_animation(m, CHAR_ANIM_DIVE)
        play_character_sound(m, CHAR_SOUND_GROUND_POUND_WAH)
        m.forwardVel = 40
        m.vel.y = 40
        m.actionState = 1
    elseif m.actionState == 1 then
        update_air_without_turn(m)
        if pound_ground(m) then
            m.actionState = 2
        end
    else
        m.actionTimer = m.actionTimer - 1
    end
end)
--#endregion -------------------------------------------------------------------------------------------------------------

--#region FIREBALL -------------------------------------------------------------------------------------------------------
ACT_FIREBALL_SHOOT = allocate_mario_action(ACT_FLAG_ATTACKING)
ACT_FIREBALL_TRIPLE_SHOOT = allocate_mario_action(ACT_FLAG_ATTACKING)
ACT_FIREBALL_TWIRL_SHOOTING = allocate_mario_action(ACT_FLAG_ATTACKING | ACT_FLAG_AIR | ACT_GROUP_AIRBORNE)

---@param m MarioState
---@param yaw integer
function throwFireball(m, yaw)
    play_sound(SOUND_OBJ_FLAME_BLOWN, m.pos)
    if m.playerIndex == 0 then
        spawn_sync_object(id_bhvFireball, E_MODEL_FIREBALL, m.pos.x, m.pos.y + 50, m.pos.z, function (o)
            o.oPowerupHeldByPlayerIndex = nps[m.playerIndex].globalIndex
            o.oMoveAngleYaw = yaw
        end)
    end
end

hookAction(ACT_FIREBALL_SHOOT, function (m)
    if m.actionTimer <= 0 and m.actionState ~= 0 then
        playerTable[m.playerIndex].blockMovesTimer = 20
        return set_mario_action(m, ACT_WALKING, 0)
    end
    perform_air_step(m, 0)
    if m.actionState == 0 then
        m.forwardVel = 0
        set_character_animation(m, CHAR_ANIM_FIRST_PUNCH_FAST)
        throwFireball(m, m.faceAngle.y)
        m.actionTimer = 10
        m.actionState = 1
    else
        m.actionTimer = m.actionTimer - 1
    end

end)

hookAction(ACT_FIREBALL_TRIPLE_SHOOT, function (m)
    if m.actionTimer <= 0 and m.actionState ~= 0 then
        playerTable[m.playerIndex].blockMovesTimer = 20
        return set_mario_action(m, ACT_WALKING, 0)
    end

    if m.actionState == 0 then
        m.forwardVel = 0
        m.actionTimer = 20
        m.actionState = 1
    else
        if m.actionTimer % 5 == 0 and m.actionArg < 3 then
            m.actionArg = m.actionArg + 1
            set_character_animation(m, ternary(m.actionArg % 2 ~= 0, CHAR_ANIM_FIRST_PUNCH_FAST, CHAR_ANIM_SECOND_PUNCH_FAST))
            throwFireball(m, m.faceAngle.y)
        end
        m.actionTimer = m.actionTimer - 1
    end
end)

hookAction(ACT_FIREBALL_TWIRL_SHOOTING, function (m)

    local step = perform_air_step(m, 0)

    if step & AIR_STEP_LANDED ~= 0 or playerTable[m.playerIndex].powerUp ~= FIREFLOWER then
        play_character_sound(m, CHAR_SOUND_HAHA)
        set_mario_action(m, ACT_TWIRL_LAND, 0)
    end

    if m.actionState == 0 then
        m.forwardVel = 0
        set_character_animation(m, CHAR_ANIM_TWIRL)
        m.twirlYaw = m.faceAngle.y
        m.actionState = 1
    else

        if m.actionTimer % math.random(6, 7) == 0 or m.actionTimer % 15 == 0 then
            throwFireball(m, m.twirlYaw)
        end

        local startTwirlYaw = m.twirlYaw
        m.vel.y = -5
        m.twirlYaw = m.twirlYaw + 0x1200

        if startTwirlYaw > m.twirlYaw then
            play_sound(SOUND_ACTION_TWIRL, m.pos)
        end

        m.marioObj.header.gfx.angle.y = m.marioObj.header.gfx.angle.y + m.twirlYaw
        m.actionTimer = m.actionTimer + 1
    end
end)
--#endregion -------------------------------------------------------------------------------------------------------------

--#region CANNON ---------------------------------------------------------------------------------------------------------
ACT_CANNON_SHOOT = allocate_mario_action(ACT_FLAG_STATIONARY)
ACT_CANNON_FIRST_PERSON = allocate_mario_action(ACT_FLAG_ALLOW_FIRST_PERSON | ACT_FLAG_STATIONARY)

hookAction(ACT_CANNON_SHOOT, function(m)
    if m.actionTimer <= 0 and m.actionState == 2 then
        local nextAct = ternary(m.prevAction == ACT_CANNON_FIRST_PERSON, m.prevAction, ACT_WALKING)
        if m.playerIndex == 0 then
            set_first_person_enabled(nextAct == ACT_CANNON_FIRST_PERSON)
        end
        return set_mario_action(m, nextAct, 0)
    end

    local step = 0
    if m.actionArg == 1 and m.actionState == 1 then
        local curState = m.actionState
        step = common_air_knockback_step(m, ACT_BACKWARD_GROUND_KB, ACT_HARD_BACKWARD_GROUND_KB, 0x0002, -16)
        m.actionState = curState
    end

    if m.actionState == 0 then

        play_sound(SOUND_OBJ_CANNON4, m.pos)
        set_camera_shake_from_point(SHAKE_POS_SMALL, m.pos.x, m.pos.y, m.pos.z)

        if m.playerIndex == 0 then
            local yaw = ternary(get_first_person_enabled(), gFirstPersonCamera.yaw - 0x8000, m.faceAngle.y)
            local pitch = ternary(get_first_person_enabled(), gFirstPersonCamera.pitch, 0)

            m.faceAngle.y = yaw

            spawn_sync_object(id_bhvCannonball, E_MODEL_BOWLING_BALL, m.pos.x, m.pos.y + 50, m.pos.z,
                function(o)
                    o.oPowerupHeldByPlayerIndex = nps[m.playerIndex].globalIndex
                    o.oMoveAngleYaw = yaw
                    o.oMoveAnglePitch = pitch
                end)
        end

        if m.actionArg == 0 then
            m.forwardVel = 0
            set_character_animation(m, CHAR_ANIM_RELEASE_BOWSER)
        end

        m.actionTimer = 40
        m.actionState = 1
    elseif m.actionState == 1 then

        if m.actionArg == 0 or step == AIR_STEP_LANDED then
            m.actionState = 2
        end
    else
        m.actionTimer = m.actionTimer - 1
    end
end)

hookAction(ACT_CANNON_FIRST_PERSON, function(m)
    if m.controller.buttonPressed & U_JPAD ~= 0 then
        playerTable[m.playerIndex].blockMovesTimer = 20

        if m.playerIndex == 0 then
            set_first_person_enabled(false)
        end

        return set_mario_action(m, ACT_WALKING, 0)
    elseif m.controller.buttonPressed & B_BUTTON ~= 0 then
        return set_mario_action(m, ACT_CANNON_SHOOT, 0)
    end

    if m.actionState == 0 then
        if m.playerIndex == 0 then
            set_first_person_enabled(true)
            gFirstPersonCamera.yaw = m.faceAngle.y - 0x8000
        end
        set_character_animation(m, CHAR_ANIM_IDLE_WITH_LIGHT_OBJ)

        m.actionState = 1
    else
        set_anim_to_frame(m, 0)
        if m.playerIndex == 0 then
            m.faceAngle.x = gFirstPersonCamera.pitch
            m.faceAngle.y = gFirstPersonCamera.yaw - 0x8000
        end
        m.marioObj.header.gfx.angle.y = m.faceAngle.y
    end
end)
--#endregion -------------------------------------------------------------------------------------------------------------

--#region BOOMERANG ------------------------------------------------------------------------------------------------------
ACT_BOOMERANG_THROW = allocate_mario_action(ACT_FLAG_ATTACKING)
ACT_BOOMERANG_FIRST_PERSON = allocate_mario_action(ACT_FLAG_ALLOW_FIRST_PERSON | ACT_FLAG_STATIONARY)
ACT_BOOMERANG_360_THROW = allocate_mario_action(ACT_FLAG_ATTACKING | ACT_FLAG_MOVING)

hookAction(ACT_BOOMERANG_THROW, function (m)

    if m.actionState ~= 0 and m.actionTimer == 0 then
        m.faceAngle.x = 0
        return set_mario_action(m, ACT_WALKING, 0)
    end
    if m.actionState == 0 then
        set_character_animation(m, CHAR_ANIM_THROW_LIGHT_OBJECT)
        m.actionTimer = 25
        m.actionState = 1
    else
        playerTable[m.playerIndex].blockMovesTimer = 20
        if m.actionArg ~= 1 then
            m.faceAngle.x = 0
        end
        m.actionTimer = m.actionTimer - 1
    end
end)

hookAction(ACT_BOOMERANG_FIRST_PERSON, function(m)
    if m.controller.buttonPressed & U_JPAD ~= 0 then
        playerTable[m.playerIndex].blockMovesTimer = 20
        m.faceAngle.x = 0
        if m.playerIndex == 0 then
            set_first_person_enabled(false)
        end

        return set_mario_action(m, ACT_WALKING, 0)
    elseif m.controller.buttonPressed & B_BUTTON ~= 0 and playerTable[m.playerIndex].blockMovesTimer == 0 then
        if m.playerIndex == 0 then
            set_first_person_enabled(false)
        end
        return set_mario_action(m, ACT_BOOMERANG_THROW, 1)
    end

    if m.actionState == 0 then
        if m.playerIndex == 0 then
            set_first_person_enabled(true)
            gFirstPersonCamera.yaw = m.faceAngle.y - 0x8000
        end
        m.actionState = 1
    else
        set_character_animation(m, CHAR_ANIM_THROW_CATCH_KEY)
        set_anim_to_frame(m, 135)
        if m.playerIndex == 0 then
            m.faceAngle.x = gFirstPersonCamera.pitch
            m.faceAngle.y = gFirstPersonCamera.yaw - 0x8000
        end
        m.marioBodyState.headAngle.x = m.faceAngle.x
        m.marioBodyState.headAngle.y = m.faceAngle.y
        m.marioBodyState.torsoAngle.y = m.faceAngle.y
        m.marioObj.header.gfx.angle.y = m.faceAngle.y
    end
end)

hookAction(ACT_BOOMERANG_360_THROW, function (m)
    
    if m.actionState ~= 0 and m.actionTimer == 0 then
        playerTable[m.playerIndex].blockMovesTimer = 20
        return set_mario_action(m, ACT_WALKING, 0)
    end

    if m.actionState == 0 then
        m.actionTimer = 45
        set_character_animation(m, CHAR_ANIM_TWIRL)
        play_character_sound(m, CHAR_SOUND_HERE_WE_GO)
        m.forwardVel = 0
        m.twirlYaw = m.faceAngle.y
        m.actionState = 1
    else
        
        local startAngle = m.marioObj.header.gfx.angle.y
        m.marioObj.header.gfx.angle.y = startAngle + 0x1000

        if startAngle > m.marioObj.header.gfx.angle.y then
            play_sound(SOUND_ACTION_TWIRL, m.pos)
        end

        m.actionTimer = m.actionTimer - 1
    end

end)
--#endregion -------------------------------------------------------------------------------------------------------------

POWERUP_MOVES = {
    { --HAMMER
        [ACT_HAMMER_360] = true,
        [ACT_HAMMER_SWING] = true,
        [ACT_HAMMER_GROUND_POUND] = true,
        [ACT_HAMMER_DIVE_GROUND_POUND] = true
    },
    { --FIREFLOWER
        [ACT_FIREBALL_SHOOT] = true,
        [ACT_FIREBALL_TRIPLE_SHOOT] = true,
        [ACT_FIREBALL_TWIRL_SHOOTING] = true
    },
    { --CANNON
        [ACT_CANNON_SHOOT] = true,
        [ACT_CANNON_FIRST_PERSON] = true
    },
    { --BOOMERANG
        [ACT_BOOMERANG_THROW] = true,
        [ACT_BOOMERANG_FIRST_PERSON] = true,
        [ACT_BOOMERANG_360_THROW] = true
    }
}
