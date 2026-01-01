--#region Localizations ---------------------------------------------------------------------

local approach_s16_symmetric = approach_s16_symmetric
local coss = coss
local cur_obj_hide = cur_obj_hide
local cur_obj_play_sound_1 = cur_obj_play_sound_1
local cur_obj_set_home_once = cur_obj_set_home_once
local djui_popup_create = djui_popup_create
local lerp = math.lerp
local load_object_collision_model = load_object_collision_model
local network_init_object = network_init_object
local network_is_server = network_is_server
local obj_set_model_extended = obj_set_model_extended
local perform_air_step = perform_air_step
local play_dialog_sound = play_dialog_sound
local play_sound = play_sound
local set_character_animation = set_character_animation
local set_mario_action = set_mario_action
local sins = sins

--#endregion --------------------------------------------------------------------------------

local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

local loops = {}

---@param o Object
function loops.bhv_trap_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_SET_FACE_ANGLE_TO_MOVE_ANGLE)

    obj_set_model_extended(o, E_MODEL_TRAP)
    o.collisionData = COL_TRAP
end

---@param o Object
function loops.bhv_trap_loop(o)
    local targetState = getTargetContestant((o.oBehParams >> 24) & 0xFF) .. 'State'

    local targetPitch = ternary(globalTable[targetState] < o.oBehParams2ndByte, 0x4000, 0)

    if o.oMoveAnglePitch ~= targetPitch then
        o.oMoveAnglePitch = approach_s16_symmetric(o.oMoveAnglePitch, targetPitch, 0x800)
        cur_obj_play_sound_1(SOUND_MOVING_AIM_CANNON)
    end

    if o.oMoveAnglePitch ~= 0x4000 then
        load_object_collision_model()
    end
end

---@param o Object
function loops.bhv_button_init(o)
    o.oFlags = o.oFlags | (OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE | OBJ_FLAG_SET_FACE_ANGLE_TO_MOVE_ANGLE)

    obj_set_model_extended(o, E_MODEL_BUTTON)
    o.collisionData = COL_BUTTON

    cur_obj_set_home_once()

    network_init_object(o, true, { 'oAction', 'oPosZ', 'oTimer' })
end

---@param o Object
function loops.bhv_button_loop(o)
    load_object_collision_model()

    if o.oAction == 0 then
        if o.oPosZ == o.oHomeZ then
            o.oAction = 1
        else
            o.oPosZ = lerp(o.oHomeZ + 40 * coss(o.oFaceAngleYaw), o.oHomeZ, o.oTimer / 30)
        end
    elseif o.oAction == 2 then
        o.oPosZ = o.oHomeZ + 40 * coss(o.oFaceAngleYaw)
        if network_is_server() then
            if o.oBehParams2ndByte == 2 then
                resetStatus()
                play_sound(SOUND_MENU_STAR_SOUND, gGlobalSoundSource)
                djui_popup_create('Settings back to default', 1)
            else
                local target = getTargetContestant(o.oBehParams2ndByte) .. 'State'
                globalTable[target] = globalTable[target] - 1
            end
        end
        o.oAction = 0
        o.oTimer = 0
    end
end

---@param m MarioState
function loops.act_sink_in_lava(m)
    if m.actionTimer > 60 then
        return set_mario_action(m, ACT_SPECTATING, 0)
    end

    if m.actionState == 0 then
        set_character_animation(m, CHAR_ANIM_DYING_IN_QUICKSAND)
        set_anim_to_frame(m, 60)
        m.actionState = 1
    end

    play_sound(SOUND_MOVING_QUICKSAND_DEATH, m.marioObj.header.gfx.cameraToObject)
    set_mario_particle_flags(m, PARTICLE_FIRE, 0)

    m.marioObj.header.gfx.pos.y = m.pos.y - m.actionTimer * 3

    m.actionTimer = m.actionTimer + 1
end

---@param m MarioState
function loops.act_spectating(m)
    if not playerTable[m.playerIndex].inContestantSpot then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    m.flags = m.flags | (MARIO_VANISH_CAP | MARIO_CAP_ON_HEAD)
    set_character_animation(m, CHAR_ANIM_SLIDE_DIVE)

    if m.playerIndex == 0 then
        m.marioBodyState.modelState = m.marioBodyState.modelState | MODEL_STATE_NOISE_ALPHA

        if m.actionState == 0 then
            play_dialog_sound(DIALOG_021)
            m.actionState = 1
        end
    else
        cur_obj_hide()
    end

    if m.controller.buttonDown & A_BUTTON ~= 0 then
        m.vel.y = 20
    elseif m.controller.buttonDown & Z_TRIG ~= 0 then
        m.vel.y = -20
    else
        m.vel.y = 0
    end

    local speed = 20 * m.intendedMag / 32

    m.faceAngle.y = m.intendedYaw
    m.vel.x = speed * sins(m.faceAngle.y)
    m.vel.z = speed * coss(m.faceAngle.y)

    perform_air_step(m, 0)
end

return loops
