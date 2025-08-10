local hook_behavior = hook_behavior
local get_id_from_behavior = get_id_from_behavior
local cur_obj_scale = cur_obj_scale
local spawn_non_sync_object = spawn_non_sync_object
local sins = sins
local coss = coss
local get_hand_foot_pos_x = get_hand_foot_pos_x
local get_hand_foot_pos_y = get_hand_foot_pos_y
local get_hand_foot_pos_z = get_hand_foot_pos_z
local cur_obj_play_sound_2 = cur_obj_play_sound_2
local cur_obj_set_hitbox_radius_and_height = cur_obj_set_hitbox_radius_and_height
local network_init_object = network_init_object
local cur_obj_become_tangible = cur_obj_become_tangible
local cur_obj_update_floor_and_walls = cur_obj_update_floor_and_walls
local obj_mark_for_deletion = obj_mark_for_deletion
local obj_compute_vel_from_move_pitch = obj_compute_vel_from_move_pitch
local cur_obj_move_standard = cur_obj_move_standard
local get_first_person_enabled = get_first_person_enabled
local define_custom_obj_fields = define_custom_obj_fields
local cur_obj_hide = cur_obj_hide
local cur_obj_unhide = cur_obj_unhide
local play_sound = play_sound
local obj_set_held_state = obj_set_held_state
local get_behavior_from_id = get_behavior_from_id

local states = gMarioStates

---@class Object
---@field oBulletOwner integer
---@field oBulletDamage integer

define_custom_obj_fields({
    oBulletOwner = "s32",
    oBulletDamage = "s32"
})
--#region Shotgun -----------------------------------------------------------------------------------------------------

---@param o Object
function bhv_shotgun_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE)
    o.hookRender = 1
    cur_obj_scale(0.8)
end

---@param o Object
function bhv_shotgun_loop(o)
    
    local m = states[o.heldByPlayerIndex]
    if m then

        if m.action & ACT_FLAG_SG_NOT_ALLOWED ~= 0 then
            cur_obj_hide()
            return
        end

        cur_obj_unhide()

        if m.action == ACT_SG_SHOOT and o.oTimer % 5 == 0 then
            local pos = getSGPos(o, 150)
            spawn_non_sync_object(id_bhvMistParticleSpawner, E_MODEL_MIST, pos.x, pos.y, pos.z, function()end)
        end

        if m.playerIndex == 0 and reloadTimer > 0 and o.oTimer % 20 == 0 then
            play_sound(SOUND_OBJ_CANNON3, gGlobalSoundSource)
        end
    else
        obj_mark_for_deletion(o)
    end
end

---@param o Object
hook_event(HOOK_ON_OBJECT_RENDER, function(o)
    if get_id_from_behavior(o.behavior) == id_bhvMHShotgun then
        local m = states[o.heldByPlayerIndex]
        if m then

            local pitch, yaw = m.faceAngle.x, m.faceAngle.y

            o.oPosX = m.pos.x + 30 * sins(yaw)
            o.oPosY = m.pos.y + 60
            o.oPosZ = m.pos.z + 30 * coss(yaw)

            if m.action == ACT_SG_GP_SHOOT or m.action == ACT_GROUND_POUND then
                pitch = 0x4000
            end

            if m.action & ACT_FLAG_SG_NOT_ALLOWED ~= 0 then
                o.oFaceAnglePitch = -pitch
            elseif m.playerIndex == 0 and get_first_person_enabled() then
                yaw, pitch = gFirstPersonCamera.yaw - 0x8000, gFirstPersonCamera.pitch
                o.oGraphYOffset = 100
                o.header.gfx.pos.x = m.marioBodyState.headPos.x + 20 * sins(yaw) * coss(pitch)
                o.header.gfx.pos.y = gLakituState.pos.y - 20 * sins(pitch)
                o.header.gfx.pos.z = m.marioBodyState.headPos.z + 20 * coss(yaw) * coss(pitch)
            else
                o.header.gfx.pos.x = get_hand_foot_pos_x(m, 0) + 10 * sins(yaw)
                o.header.gfx.pos.y = get_hand_foot_pos_y(m, 0) + 10
                o.header.gfx.pos.z = get_hand_foot_pos_z(m, 0) + 10 * coss(yaw)
            end

            o.oFaceAnglePitch = pitch
            o.oFaceAngleYaw = yaw
        end
    end
end)
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Bullet ------------------------------------------------------------------------------------------------------

---@param b Object
---@param o Object
---@param m MarioState
---@param oData table | nil
---@return boolean
function bullet_interact(b, o, m, oData)

    if not oData then
        return false
    end

    if (oData.dmgToAffect and oData.dmgToAffect > b.oBulletDamage) then
        return true
    end

    if oData.specificFunc then
        local actuallyHit, sync = oData.specificFunc(o, b, m, b.oBulletDamage)
        if sync then
            syncObj(o)
        end
        return actuallyHit
    end

    local forceType = oData.forceDeleteType
    local intType = o.oInteractType

    if intType == INTERACT_GRABBABLE then
        obj_set_held_state(o, get_behavior_from_id(id_bhvCarrySomething5))
    else
        local attType = ATTACK_KICK_OR_TRIP
        if intType == INTERACT_BREAKABLE then
            attType = ATTACK_KICK_OR_TRIP
        elseif oData.isSurface then
            forceType = DT_TRIANGLE
        else
            attType = oData.attType or ternary(b.oBulletDamage == BULLET_DMG_LOW, attType, ATTACK_GROUND_POUND_OR_TWIRL)
        end
        o.oInteractStatus = INT_STATUS_INTERACTED | INT_STATUS_WAS_ATTACKED | attType
    end

    if forceType then
        spawnForceDelParticles(forceType, o, m)
        obj_mark_for_deletion(o)
    end

    syncObj(o)

    return true
end

---@param o Object
function bhv_sg_bullet_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_COMPUTE_DIST_TO_MARIO | OBJ_FLAG_SET_FACE_ANGLE_TO_MOVE_ANGLE)
    cur_obj_scale(0.5)
    o.oGraphYOffset = 20

    cur_obj_set_hitbox_radius_and_height(20, 20)
    o.oWallHitboxRadius = 20

    network_init_object(o, true, {'oBulletOwner', 'oBulletDamage'})
end

---@param o Object
function bhv_sg_bullet_loop(o)
    cur_obj_become_tangible()
    cur_obj_update_floor_and_walls()

    local m = states[getLocalFromGlobalIdx(o.oBulletOwner)]
    local hitTarget, mobData = detectCollidedTarget(o)

    local shouldDissapear = (o.oTimer > 15 and o.oForwardVel < 5)

    if o.oMoveFlags & (OBJ_MOVE_HIT_WALL | OBJ_MOVE_ON_GROUND | OBJ_MOVE_MASK_IN_WATER) ~= 0
    or hitTarget or shouldDissapear then

        local actuallyHit = true

        if hitTarget then
            actuallyHit = bullet_interact(o, hitTarget, m, mobData)
        end
        
        if actuallyHit or shouldDissapear then
            spawn_non_sync_object(id_bhvMistParticleSpawner, E_MODEL_MIST, o.oPosX, o.oPosY, o.oPosZ, function(_)end)
            cur_obj_play_sound_2(SOUND_ACTION_HIT_2)
            obj_mark_for_deletion(o)
        end
    end
    obj_compute_vel_from_move_pitch(120)
    cur_obj_move_standard(78)
end
--#endregion ----------------------------------------------------------------------------------------------------------

id_bhvMHShotgun = hook_behavior(nil, OBJ_LIST_GENACTOR, true, bhv_shotgun_init, bhv_shotgun_loop, "id_bhvCoopShotgun")
id_bhvMHShotgunShell = hook_behavior(nil, OBJ_LIST_GENACTOR, true, bhv_sg_bullet_init, bhv_sg_bullet_loop, "id_bhvCoopShotgunBullet")