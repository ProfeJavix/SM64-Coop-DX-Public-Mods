if not _G.mhExists then return end

--#region Localizations ---------------------------------------------------------------------

local cur_obj_hide = cur_obj_hide
local cur_obj_unhide = cur_obj_unhide
local define_custom_obj_fields = define_custom_obj_fields
local hook_behavior = hook_behavior
local is_player_active = is_player_active
local linear_mtxf_mul_vec3f = linear_mtxf_mul_vec3f
local load_object_collision_model = load_object_collision_model
local mtxf_rotate_zxy_and_translate = mtxf_rotate_zxy_and_translate
local network_init_object = network_init_object
local obj_mark_for_deletion = obj_mark_for_deletion
local obj_scale_xyz = obj_scale_xyz
local obj_set_pos = obj_set_pos

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable

define_custom_obj_fields({
    oOwner = 's32'
})

---@param o Object
function bhv_invisible_wall_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_COMPUTE_DIST_TO_MARIO | OBJ_FLAG_SET_FACE_ANGLE_TO_MOVE_ANGLE)

    obj_scale_xyz(o, globalTable.wallXScale, globalTable.wallYScale, globalTable.wallZScale)

    o.collisionData = COL_INVISIBLE_WALL

    network_init_object(o, true, {'oAction', 'oTimer', 'oOwner'})
end

---@param o Object
function bhv_invisible_wall_loop(o)
    if canSeeWalls(states[0]) then
        o.oOpacity = 160
    else
        o.oOpacity = 0
    end

    o.oFaceAnglePitch = 0
    o.oFaceAngleRoll = 0

    local localIsOwner = o.oOwner == nps[0].globalIndex

    if o.oAction == 0 then

        if localIsOwner then
            if o.oTimer % 2 == 0 then
                cur_obj_hide()
            else
                cur_obj_unhide()
            end
        end

        if o.oTimer > 30 or not globalTable.wallIFrames then
            cur_obj_unhide()
            o.oAction = 1
        end
    end

    if not localIsOwner or o.oAction == 1 then
        load_object_collision_model()
    end

    if o.oTimer > globalTable.wallDespawnTime then
        obj_mark_for_deletion(o)
    end
end

id_bhvInvisibleWall = hook_behavior(nil, OBJ_LIST_SURFACE, true, bhv_invisible_wall_init, bhv_invisible_wall_loop)

---@param o Object
function bhv_invisible_wall_ph_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_COMPUTE_DIST_TO_MARIO)
    obj_scale_xyz(o, globalTable.wallXScale, globalTable.wallYScale, globalTable.wallZScale)
end

---@param o Object
function bhv_invisible_wall_ph_loop(o)
    obj_scale_xyz(o, globalTable.wallXScale, globalTable.wallYScale, globalTable.wallZScale)
    local m = states[0]

    if is_player_active(m) ~= 0 then
        local mat4 = gMat4Identity()
        local angle = {
            x = -gLakituState.oldPitch,
            y = gLakituState.oldYaw,
            z = 0
        }
        local offset = {x = 0, y = 0, z = curZOffset}
        local newPos = {x = m.pos.x, y = m.pos.y, z = m.pos.z}

        mtxf_rotate_zxy_and_translate(mat4, gVec3fZero(), angle)
        linear_mtxf_mul_vec3f(mat4, newPos, offset)

        obj_set_pos(o, m.pos.x + newPos.x, m.pos.y + newPos.y, m.pos.z + newPos.z)

        o.oFaceAnglePitch = 0
        o.oFaceAngleYaw = angle.y - curYawOffset
        o.oFaceAngleRoll = 0
    end

    o.oOpacity = 150
end

id_bhvInvisibleWallPH = hook_behavior(nil, OBJ_LIST_DEFAULT, true, bhv_invisible_wall_ph_init, bhv_invisible_wall_ph_loop)