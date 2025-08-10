if not _G.mhExists then return end

local cur_obj_hide = cur_obj_hide
local cur_obj_unhide = cur_obj_unhide
local obj_mark_for_deletion = obj_mark_for_deletion
local define_custom_obj_fields = define_custom_obj_fields
local cur_obj_set_hitbox_radius_and_height = cur_obj_set_hitbox_radius_and_height
local cur_obj_scale = cur_obj_scale
local network_init_object = network_init_object
local nearest_mario_state_to_object = nearest_mario_state_to_object
local cur_obj_become_tangible = cur_obj_become_tangible
local obj_check_if_collided_with_object = obj_check_if_collided_with_object
local cur_obj_become_intangible = cur_obj_become_intangible
local cur_obj_play_sound_1 = cur_obj_play_sound_1
local random = math.random
local network_send_object = network_send_object
local spawn_non_sync_object = spawn_non_sync_object
local obj_angle_to_object = obj_angle_to_object
local approach_s16_symmetric = approach_s16_symmetric
local get_hand_foot_pos_x = get_hand_foot_pos_x
local get_hand_foot_pos_y = get_hand_foot_pos_y
local get_hand_foot_pos_z = get_hand_foot_pos_z
local sins = sins
local coss = coss
local degrees_to_sm64 = degrees_to_sm64
local obj_set_gfx_pos = obj_set_gfx_pos
local cur_obj_update_floor_and_walls = cur_obj_update_floor_and_walls
local cur_obj_play_sound_2 = cur_obj_play_sound_2
local cur_obj_lateral_dist_to_home = cur_obj_lateral_dist_to_home
local set_mario_action = set_mario_action
local cur_obj_move_standard = cur_obj_move_standard
local obj_set_billboard = obj_set_billboard
local random_float = random_float
local random_u16 = random_u16
local obj_compute_vel_from_move_pitch = obj_compute_vel_from_move_pitch
local obj_set_vel = obj_set_vel
local vec3f_dist = vec3f_dist
local obj_turn_pitch_toward_mario = obj_turn_pitch_toward_mario
local lateral_dist_between_objects = lateral_dist_between_objects
local hookBhv = hook_behavior

local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

--#region Common ------------------------------------------------------------------------------------------------------

---@param o Object
---@param type integer
---@return MarioState | nil, boolean | nil
function common_held_powerup_checks(o, type)
    local idx = getLocalFromGlobalIdx(o.oPowerupHeldByPlayerIndex)
    if idx ~= -1 and playerTable[idx].powerUp == type then
        local m = states[idx]
        local hidden = false
        local act = m.action
        if act & (ACT_FLAG_SWIMMING_OR_FLYING | ACT_GROUP_CUTSCENE) ~= 0 and
        (type ~= BOOMERANG or o.oAction == 0) then
            cur_obj_hide()
            hidden = true
        else
            cur_obj_unhide()
        end

        return m, hidden
    end
    obj_mark_for_deletion(o)
end

---@class Object
---@field oPowerupType integer
---@field oPowerupRandomCurType integer
---@field oPowerupFaceMario integer
---@field oPowerupHeldByPlayerIndex integer

define_custom_obj_fields({
    oPowerupType = 's32',
    oPowerupRandomCurType = 's32',
    oPowerupFaceMario = 's32',
    oPowerupHeldByPlayerIndex = 's32'
})
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Powerup -----------------------------------------------------------------------------------------------------

---@param o Object
function bhv_powerup_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_COMPUTE_ANGLE_TO_MARIO | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    cur_obj_set_hitbox_radius_and_height(80, 100)
    cur_obj_scale(0)

    network_init_object(o, true, {
        'oPowerupType',
        'oPowerupRandomCurType',
        'oPowerupFaceMario',
        'oPowerupHeldByPlayerIndex'
    })
end

---@param o Object
function bhv_powerup_loop(o)

    local rotateIncrement = 0x200
    local m = nearest_mario_state_to_object(o)
    local act = o.oAction

    local data = POWERUP_DATA[o.oPowerupType]
    if not data then
        obj_mark_for_deletion(o)
        return
    end

    if act == 0 then --grow
        if o.oTimer > 30 then
            cur_obj_become_tangible()
            o.oAction = 1
        else
            cur_obj_scale(data.scale * o.oTimer / 30)
        end
    elseif act == 1 then --available
        cur_obj_scale(data.scale)

        if m and obj_check_if_collided_with_object(o, m.marioObj) == 1 then --pickup
            local pt = playerTable[m.playerIndex]

            if pt.powerUp == 0 and m.flags & (MARIO_WING_CAP | MARIO_METAL_CAP | MARIO_VANISH_CAP) == 0 and
            (getTeam(m.playerIndex) == 1 or globalTable.powerUpsForHunters) then
                cur_obj_become_intangible()

                if o.oPowerupType == UNKNOWN then
                    playerTable[m.playerIndex].powerUp = o.oPowerupRandomCurType
                else
                    playerTable[m.playerIndex].powerUp = o.oPowerupType
                end

                playerTable[m.playerIndex].changePowerup = true

                cur_obj_play_sound_1(o.oDeathSound)
                rotateIncrement = 0x2000
                o.oTimer = 0
                o.oAction = 2

                if m.playerIndex == 0 and o.oPowerupType == UNKNOWN then
                    o.oPowerupRandomCurType = random(MAX_PU - 1)
                    network_send_object(o, true)
                end
            end
        end
    else --hide
        if o.oTimer <= 15 then
            rotateIncrement = 0x2000
            spawn_non_sync_object(id_bhvSparkleParticleSpawner, E_MODEL_SPARKLES, o.oPosX, o.oPosY, o.oPosZ, function()end)
            cur_obj_scale(data.scale * (1 - o.oTimer / 15))
        elseif o.oTimer <= 20 then
            cur_obj_scale(0)
        end

        if o.oTimer > 300 then
            o.oTimer = 0
            o.oAction = 0
        end
    end

    if o.oPowerupFaceMario == 0 then
        o.oFaceAngleYaw = o.oFaceAngleYaw + rotateIncrement
    else
        if m then
            local angleToM = obj_angle_to_object(o, m.marioObj)
            o.oFaceAngleYaw = approach_s16_symmetric(o.oFaceAngleYaw, angleToM, 0x300)
        end
    end
end

---@param o Object
---@param data PowerupData
function initPowerup(o, data)
    o.oGraphYOffset = data.yOffset
    o.oPowerupType = data.type
    o.oDeathSound = data.pickupSound
    o.oPowerupFaceMario = data.faceMario
    
    if globalTable.randomPowerups then
        o.oPowerupRandomCurType = random(MAX_PU - 1)
    end
end

--#endregion ----------------------------------------------------------------------------------------------------------

--#region Hammer ------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_held_hammer_init(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    cur_obj_scale(0.8)
    network_init_object(o, true, {
        'oPowerupType',
        'oPowerupHeldByPlayerIndex'
    })
end

---@param o Object
function bhv_held_hammer_loop(o)

    local m, hidden = common_held_powerup_checks(o, HAMMER)
    if m then

        if hidden then
            o.oPosX = m.pos.x
            o.oPosY = m.pos.y
            o.oPosZ = m.pos.z
        else
            o.oPosX = get_hand_foot_pos_x(m, 0) + sins(m.faceAngle.y) * 20
            o.oPosY = get_hand_foot_pos_y(m, 0) - 20
            o.oPosZ = get_hand_foot_pos_z(m, 0) + coss(m.faceAngle.y) * 20
        end

        if m.action == ACT_HAMMER_SWING then

            local target = m.faceAngle.y + degrees_to_sm64(170)
            o.oPosY = o.oPosY + 20
            
            if o.oFaceAngleYaw ~= target then
                o.oFaceAngleYaw = approach_s16_symmetric(o.oFaceAngleYaw, target, 0x1000)
            end
            o.oFaceAngleRoll = m.faceAngle.z + degrees_to_sm64(90)
        elseif m.action == ACT_HAMMER_360 then
            o.oPosY = o.oPosY + 20
            o.oFaceAngleYaw = m.faceAngle.y
            o.oFaceAngleRoll = m.faceAngle.z + degrees_to_sm64(90)
        elseif m.action == ACT_HAMMER_GROUND_POUND or m.action == ACT_HAMMER_DIVE_GROUND_POUND then
            local target = m.faceAngle.x + degrees_to_sm64(90)
            if o.oFaceAnglePitch ~= target then
                o.oFaceAnglePitch = approach_s16_symmetric(o.oFaceAnglePitch, target, 0x800)
            end

            if m.action == ACT_HAMMER_GROUND_POUND then
                o.oFaceAngleYaw = m.twirlYaw
            end
        else
            o.oFaceAnglePitch = m.faceAngle.x
            o.oFaceAngleYaw = m.faceAngle.y
            o.oFaceAngleRoll = m.faceAngle.z
        end
        obj_set_gfx_pos(o, o.oPosX, o.oPosY, o.oPosZ)
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Fireball ----------------------------------------------------------------------------------------------------

---@param o Object
function bhv_fireball_init(o)
    o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE

    o.oHomeX = o.oPosX
    o.oHomeY = o.oPosY
    o.oHomeZ = o.oPosZ

    o.oWallHitboxRadius = 40
    o.oGravity = -2.5

    cur_obj_set_hitbox_radius_and_height(30, 30)
    cur_obj_become_tangible()

    network_init_object(o, true, {
        'oPowerupHeldByPlayerIndex'
    })
end

---@param o Object
function bhv_fireball_loop(o)
    o.oForwardVel = 40
    cur_obj_update_floor_and_walls()

    if o.oMoveFlags & OBJ_MOVE_LANDED ~= 0 then
        o.oVelY = 30
        cur_obj_play_sound_2(SOUND_ACTION_QUICKSAND_STEP)
    end

    spawn_non_sync_object(id_bhvFireballSmoke, E_MODEL_BURN_SMOKE, o.oPosX, o.oPosY, o.oPosZ, function(_)end)

    local m = states[getLocalFromGlobalIdx(o.oPowerupHeldByPlayerIndex)]
    local nm = nearest_mario_state_to_object(o)
    local hitSomeone = shouldHitWithPowerup(m, nm) and obj_check_if_collided_with_object(o, nm.marioObj) == 1

    if o.oMoveFlags & (OBJ_MOVE_HIT_WALL | OBJ_MOVE_MASK_IN_WATER | OBJ_MOVE_ABOVE_DEATH_BARRIER) ~= 0 or
    cur_obj_lateral_dist_to_home() > 3000 or hitSomeone then
        if hitSomeone then
            set_mario_action(nm, ACT_BURNING_GROUND, 0)
        end
        obj_mark_for_deletion(o)
    end

    cur_obj_move_standard(78)

end

---@param o Object
function bhv_fireball_smoke_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW | OBJ_FLAG_MOVE_XZ_USING_FVEL | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    obj_set_billboard(o)
    o.oGraphYOffset = 30
    cur_obj_scale(0.4)
end

---@param o Object
function bhv_fireball_smoke_loop(o)
    o.oOpacity = 0
    cur_obj_scale(0.5)
    
    if o.oTimer > 8 then
        obj_mark_for_deletion(o)
        return
    end

    if o.oTimer == 0 then
        o.oForwardVel = random_float() * 2 + 0.5
        o.oMoveAngleYaw = random_u16()
        o.oVelY = 8
    end
    o.oMoveAngleYaw = o.oMoveAngleYaw + o.oAngleVelYaw
    o.oPosY = o.oPosY + o.oVelY

    o.oAnimState = o.oAnimState + 4
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Cannon ------------------------------------------------------------------------------------------------------

---@param o Object
function bhv_held_cannon_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    cur_obj_scale(0.5)
    cur_obj_become_intangible()
    network_init_object(o, true, {
        'oPowerupType',
        'oPowerupHeldByPlayerIndex'
    })
end

---@param o Object
function bhv_held_cannon_loop(o)

    local m, hidden = common_held_powerup_checks(o, CANNON)

    if m then

        if hidden then
            o.oPosX = m.pos.x
            o.oPosY = m.pos.y
            o.oPosZ = m.pos.z
        else
            if m.action == ACT_CANNON_FIRST_PERSON then
                o.oPosX = m.pos.x + sins(m.faceAngle.y) * 50
                o.oPosY = m.marioBodyState.headPos.y - 20
                o.oPosZ = m.pos.z + coss(m.faceAngle.y) * 50
            else
                o.oPosX = get_hand_foot_pos_x(m, 0) + sins(m.faceAngle.y) * 20
                o.oPosY = get_hand_foot_pos_y(m, 0) - 20
                o.oPosZ = get_hand_foot_pos_z(m, 0) + coss(m.faceAngle.y) * 20
            end
        end

        o.oFaceAnglePitch = m.faceAngle.x
        o.oFaceAngleYaw = m.faceAngle.y
        o.oFaceAngleRoll = m.faceAngle.z
        obj_set_gfx_pos(o, o.oPosX, o.oPosY, o.oPosZ)
    end
end

---@param o Object
function bhv_cannonball_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_COMPUTE_DIST_TO_MARIO | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)

    obj_set_billboard(o)
    cur_obj_scale(0.2)
    o.oGraphYOffset = 20

    cur_obj_set_hitbox_radius_and_height(40, 40)
    o.oWallHitboxRadius = 30
    o.oForwardVel = 80

    network_init_object(o, true, {
        'oPowerupHeldByPlayerIndex'
    })
end

---@param o Object
function bhv_cannonball_loop(o)

    cur_obj_become_tangible()
    cur_obj_update_floor_and_walls()

    local nm = nearest_mario_state_to_object(o)
    local m = states[getLocalFromGlobalIdx(o.oPowerupHeldByPlayerIndex)]

    if o.oMoveFlags & (OBJ_MOVE_HIT_WALL | OBJ_MOVE_LANDED | OBJ_MOVE_MASK_IN_WATER) ~= 0 or
    (shouldHitWithPowerup(m, nm) and obj_check_if_collided_with_object(o, nm.marioObj) == 1) then
        
        if nm.playerIndex == 0 then
            spawn_sync_object(id_bhvExplosion, E_MODEL_EXPLOSION, o.oPosX, o.oPosY, o.oPosZ, function()end)
        end
        obj_mark_for_deletion(o)

    end
    obj_compute_vel_from_move_pitch(70)
    cur_obj_move_standard(78)
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Boomerang ---------------------------------------------------------------------------------------------------

---@param o Object
function bhv_boomerang_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_COMPUTE_DIST_TO_MARIO)

    cur_obj_scale(0.5)
    cur_obj_become_intangible()
    cur_obj_set_hitbox_radius_and_height(40, 20)

    network_init_object(o, true, {
        'oAction',
        'oMoveAnglePitch',
        'oPowerupType',
        'oPowerupHeldByPlayerIndex'
    })
end

---@param o Object
function bhv_boomerang_loop(o)
    local m, hidden = common_held_powerup_checks(o, BOOMERANG)
    if m then
        local act = o.oAction
        if act ~= 0 then
            cur_obj_become_tangible()
            o.oGraphYOffset = 0
            o.oForwardVel = 70
            o.oFaceAnglePitch = 0

            local curYaw = o.oFaceAngleYaw
            o.oFaceAngleYaw = curYaw + 0x1200
            if o.oTimer % 10 == 0 then
                cur_obj_play_sound_2(SOUND_ACTION_TWIRL)
            end
            o.oFaceAngleRoll = degrees_to_sm64(90)

            cur_obj_update_floor_and_walls()

            local nm = nearest_mario_state_to_object(o)
            if shouldHitWithPowerup(m, nm) and obj_check_if_collided_with_object(o, nm.marioObj) == 1 then
                cur_obj_play_sound_1(SOUND_ACTION_HIT_2)
                set_mario_action(nm, ACT_BACKWARD_GROUND_KB, 0)
				nm.invincTimer = 60
				nm.hurtCounter = 8
                playerTable[m.playerIndex].blockMovesTimer = 45

                if act ~= 2 then
                    o.oAction = 3
                end
            end
        end

        if act == 0 then
            
            o.oGraphYOffset = 40
            o.oMoveAnglePitch = 0
            obj_set_vel(o, 0, 0, 0)

            o.oHomeX = o.oPosX
            o.oHomeY = o.oPosY
            o.oHomeZ = o.oPosZ

            o.oFaceAngleYaw = m.faceAngle.y

            if m.action == ACT_BOOMERANG_FIRST_PERSON then
                o.oFaceAnglePitch = degrees_to_sm64(15)
                o.oFaceAngleRoll = degrees_to_sm64(-25)
            else
                o.oFaceAnglePitch = m.faceAngle.x
                o.oFaceAngleRoll = m.faceAngle.z
            end

            obj_set_gfx_pos(o, o.oPosX, o.oPosY, o.oPosZ)

            if m.playerIndex == 0 and playerTable[m.playerIndex].blockMovesTimer == 0 then
                local send = false
                if m.action == ACT_BOOMERANG_THROW then
                    o.oAction = 1
                    send = true
                elseif m.action == ACT_BOOMERANG_360_THROW then
                    o.oTimer = 0
                    o.oAction = 2
                    send = true
                end

                if send then
                    o.oPosY = m.pos.y + 100
                    o.oMoveAnglePitch = m.faceAngle.x
                    o.oMoveAngleYaw = m.faceAngle.y
                    network_send_object(o, true)
                    return
                end
            end
            cur_obj_become_intangible()

            if hidden then
                o.oPosX = m.pos.x
                o.oPosY = m.pos.y
                o.oPosZ = m.pos.z
            else
                o.oPosX = get_hand_foot_pos_x(m, 0) + sins(m.faceAngle.y) * ternary(m.action == ACT_BOOMERANG_FIRST_PERSON, 50, 35)
                o.oPosY = get_hand_foot_pos_y(m, 0) - 20
                o.oPosZ = get_hand_foot_pos_z(m, 0) + coss(m.faceAngle.y) * ternary(m.action == ACT_BOOMERANG_FIRST_PERSON, 50, 35)
                if m.action == ACT_BOOMERANG_FIRST_PERSON then
                    o.oPosX = o.oPosX + sins(m.faceAngle.y + 0x4000) * 25
                    o.oPosZ = o.oPosZ + coss(m.faceAngle.y + 0x4000) * 25
                end
            end

        elseif act == 1 then --throw
            obj_compute_vel_from_move_pitch(70)
            cur_obj_move_standard(78)

            if vec3f_dist({x = o.oHomeX, y = o.oHomeY, z = o.oHomeZ}, {x = o.oPosX, y = o.oPosY, z = o.oPosZ}) > 2000 or
            o.oMoveFlags & (OBJ_MOVE_LANDED | OBJ_MOVE_HIT_WALL | OBJ_MOVE_MASK_IN_WATER | OBJ_MOVE_HIT_EDGE) ~= 0 then
                o.oAction = 3
            end
        elseif act == 2 then --spin around Mario

            o.oPosX = m.pos.x + sins(o.oMoveAngleYaw) * 150
            o.oPosY = m.pos.y + 100
            o.oPosZ = m.pos.z + coss(o.oMoveAngleYaw) * 150
            o.oMoveAngleYaw = o.oMoveAngleYaw + 0x1000
            cur_obj_move_standard(78)

            if m.action ~= ACT_BOOMERANG_360_THROW then
                o.oAction = 3
            end

        elseif act == 3 then --return Mario

            o.oMoveAngleYaw = obj_angle_to_object(o, m.marioObj)
            o.oMoveAnglePitch = obj_turn_pitch_toward_mario(m, 100, 0x1000)

            obj_compute_vel_from_move_pitch(70)
            cur_obj_move_standard(78)

            if lateral_dist_between_objects(o, m.marioObj) <= 50 then
                o.oAction = 0
                cur_obj_play_sound_2(SOUND_MENU_CLICK_FILE_SELECT)
            end
        end
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

id_bhvPowerup = hookBhv(nil, OBJ_LIST_LEVEL, true, bhv_powerup_init, bhv_powerup_loop, "id_bhvMHPowerup")
id_bhvHeldHammer = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhv_held_hammer_init, bhv_held_hammer_loop, "id_bhvPUHeldHammer")
id_bhvFireball = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhv_fireball_init, bhv_fireball_loop, "id_bhvPUFireball")
id_bhvFireballSmoke = hookBhv(nil, OBJ_LIST_UNIMPORTANT, true, bhv_fireball_smoke_init, bhv_fireball_smoke_loop)
id_bhvHeldCannon = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhv_held_cannon_init, bhv_held_cannon_loop, "id_bhvPUHeldCannon")
id_bhvCannonball = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhv_cannonball_init, bhv_cannonball_loop, "id_bhvPUCannonball")
id_bhvBoomerang = hookBhv(nil, OBJ_LIST_GENACTOR, true, bhv_boomerang_init, bhv_boomerang_loop, "id_bhvPUBoomerang")