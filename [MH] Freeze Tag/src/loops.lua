--#region Localizations ---------------------------------------------------------------------

local abs = math.abs
local atan2s = atan2s
local cur_obj_hide = cur_obj_hide
local cur_obj_play_sound_1 = cur_obj_play_sound_1
local cur_obj_play_sound_2 = cur_obj_play_sound_2
local cur_obj_scale = cur_obj_scale
local cur_obj_unhide = cur_obj_unhide
local is_player_active = is_player_active
local lerp = math.lerp
local load_object_collision_model = load_object_collision_model
local mario_set_forward_vel = mario_set_forward_vel
local mario_stop_riding_and_holding = mario_stop_riding_and_holding
local network_init_object = network_init_object
local obj_copy_pos = obj_copy_pos
local obj_mark_for_deletion = obj_mark_for_deletion
local play_character_sound = play_character_sound
local set_anim_to_frame = set_anim_to_frame
local set_character_animation = set_character_animation
local set_mario_action = set_mario_action
local spawn_mist_particles_variable = spawn_mist_particles_variable
local spawn_mist_particles_with_sound = spawn_mist_particles_with_sound

--#endregion --------------------------------------------------------------------------------

local states = gMarioStates
local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

local loops = {}

---@param o Object
---@param m MarioState
---@return boolean
local function checkIfBreakIce(o, m)

    if getMHTeam(m.playerIndex) == 1 then return false end

    if m.wall and m.wall.object == o then
        return abs(atan2s(m.wall.normal.z, m.wall.normal.x) - m.faceAngle.y) > 0x5000 and m.action & ACT_FLAG_ATTACKING ~= 0
    end

    return m.marioObj.platform == o and m.action == ACT_GROUND_POUND_LAND
end

---@param o Object
function loops.bhv_tag_ice_init(o)
    o.oFlags = o.oFlags | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.collisionData = COLLISION_TAG_ICE

    cur_obj_scale(0)

    o.oOpacity = 200

    network_init_object(o, true, {'oAction', 'oTimer'})
end

---@param o Object
function loops.bhv_tag_ice_loop(o)

    local m = states[getLocalFromGlobalIdx(o.oOwner)]
    if not m then
        obj_mark_for_deletion(o)
        return
    end

    obj_copy_pos(m.marioObj, o)

    if o.oAction == 0 then

        cur_obj_play_sound_1(SOUND_AIR_BLOW_WIND)

        local scale = lerp(0, 1, o.oTimer / 20)
        cur_obj_scale(scale)

        if scale == 1 then
            o.oAction = 1
        end
    elseif o.oAction == 1 then

        if m.playerIndex ~= 0 then
            load_object_collision_model()
        end

        if checkIfBreakIce(o, states[0]) then
            o.oAction = 3
            return
        end

        if m.action ~= ACT_FROZEN then
            o.oTimer = 0
            o.oAction = 2
        end
    elseif o.oAction == 2 then
        local scale = lerp(1, 0, o.oTimer / 20)
        cur_obj_scale(scale)

        if o.oTimer % 2 == 0 then
            spawn_mist_particles_variable(2, 0, 50 * scale)
        end

        if o.oTimer % 8 == 0 then
            cur_obj_play_sound_2(SOUND_OBJ_BULLY_EXPLODE_2)
        end

        if scale <= 0 then
            obj_mark_for_deletion(o)
        end
    else
        set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
        spawn_mist_particles_with_sound(SOUND_GENERAL_WALL_EXPLOSION)
        obj_mark_for_deletion(o)
    end
end

---@param o Object
function loops.bhv_frostbite_icon_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)
end

---@param o Object
function loops.bhv_frostbite_icon_loop(o)

    local idx = o.oOwner
    local m = states[idx]

    if is_player_active(m) ~= 0 then
        if getMHTeam(idx) == 1 and playerTable[idx].hasFrostbite then
            cur_obj_unhide()
            obj_copy_pos(o, m.marioObj)
            o.oPosY = m.marioBodyState.headPos.y + 100

            o.oMoveAngleYaw = o.oMoveAngleYaw + 0x700
        else
            cur_obj_hide()
        end
    else
        obj_mark_for_deletion(o)
    end
end

---@param m MarioState
function loops.act_frozen(m)
    if m.actionTimer >= globalTable.frozenTimer or getMHTeam(m.playerIndex) == 1 then
        return set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
    end

    if m.actionState == 0 then
        mario_stop_riding_and_holding(m)
        mario_set_forward_vel(m, 0)
        play_character_sound(m, CHAR_SOUND_WHOA)
        m.actionState = 1
    end

    set_character_animation(m, m.marioObj.header.gfx.animInfo.animID)
    set_anim_to_frame(m, m.marioObj.header.gfx.animInfo.animFrame)

    m.actionTimer = m.actionTimer + 1
end

return loops