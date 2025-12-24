local hook_mario_action = hook_mario_action
local allocate_mario_action = allocate_mario_action
local object_pos_to_vec3f = object_pos_to_vec3f
local set_mario_action = set_mario_action
local play_sound = play_sound

local globalTable = gGlobalSyncTable

ACT_CONTROLLING_MOB = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)

---Thanks to Holc for the idea of the jump and the lerp explanation XD
---@param m MarioState
function act_controlling_mob(m)

    if m.usedObj == nil or
    m.usedObj.activeFlags == ACTIVE_FLAG_DEACTIVATED or
    (mhExists and globalTable.mhControlOnlyForHunters and getMHTeam(m.playerIndex) == 1) then
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
        m.squishTimer = 0
        m.invincTimer = 30
        play_sound(SOUND_GENERAL_PAINTING_EJECT, m.marioObj.header.gfx.cameraToObject)
        set_mario_action(m, ACT_IDLE, 0)
        --m.marioObj.hitboxHeight = 160
        --m.marioObj.hitboxRadius = 37
        return false
    end
    
    local state = m.actionState

    if state == 0 then
        set_character_animation(m, CHAR_ANIM_DOUBLE_JUMP_RISE)
        m.pos.y = m.usedObj.oPosY
        m.vel.y = 60
        play_mario_jump_sound(m)
        m.faceAngle.y = obj_angle_to_object(m.marioObj, m.usedObj)
        mario_set_forward_vel(m, 20)
        m.actionState = 1

    elseif state == 1 then

        perform_air_step(m, 0)
        if m.vel.y <= 30 then
            if set_character_animation(m, CHAR_ANIM_FORWARD_SPINNING) == 0 then
                play_sound(SOUND_ACTION_SPIN, m.marioObj.header.gfx.cameraToObject)
            end

            if m.vel.y <= 0 then
                play_sound(SOUND_MENU_STAR_SOUND, m.marioObj.header.gfx.cameraToObject)
                m.actionTimer = 40
                m.actionState = 2
            end
        end

    elseif state == 2 then
        perform_air_step(m, 0)
        set_character_animation(m, CHAR_ANIM_DIVE)
        m.squishTimer = 0xFF

        local timerScale = m.actionTimer / 40
        m.actionTimer = m.actionTimer - 2
        m.pos.x = lerp(m.usedObj.oPosX, m.pos.x, timerScale)
        m.pos.z = lerp(m.usedObj.oPosZ, m.pos.z, timerScale)
        vec3f_set(m.marioObj.header.gfx.scale, timerScale, timerScale, timerScale)
        if timerScale <= 0.15 then
            m.actionState = 3
        end
    else
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags | GRAPH_RENDER_INVISIBLE
        m.squishTimer = 0
        set_mario_animation(m, MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)
        m.pos.x = m.usedObj.oPosX - 10 * sins(m.usedObj.oFaceAngleYaw)
        m.pos.y = m.usedObj.oPosY
        m.pos.z = m.usedObj.oPosZ - 10 * coss(m.usedObj.oFaceAngleYaw)

        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
		
		if m.actionArg == 1 then
            m.pos.y = m.pos.y + 500
            if m.playerIndex == 0 then
                object_pos_to_vec3f(gLakituState.curFocus, m.usedObj)
            end
        end

        --m.marioObj.hitboxHeight = 0
        --m.marioObj.hitboxRadius = 0
    end
end

hook_mario_action(ACT_CONTROLLING_MOB, act_controlling_mob)