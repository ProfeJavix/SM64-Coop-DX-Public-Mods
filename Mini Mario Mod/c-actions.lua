local allocate_mario_action = allocate_mario_action
local hook_mario_action = hook_mario_action
local play_character_sound = play_character_sound
local mario_set_forward_vel = mario_set_forward_vel
local set_mario_action = set_mario_action
local set_character_anim_with_accel = set_character_anim_with_accel
local play_step_sound = play_step_sound
local perform_air_step = perform_air_step
local sins = sins
local coss = coss

local playerTable = gPlayerSyncTable

ACT_WALL_RUN = allocate_mario_action(ACT_FLAG_MOVING)

hook_mario_action(ACT_WALL_RUN, function (m)
    if not playerTable[m.playerIndex].isMiniMario or m.pos.y + 130 > m.ceilHeight then
        play_character_sound(m, CHAR_SOUND_UH)
        mario_set_forward_vel(m, -2)
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    if m.controller.buttonPressed & A_BUTTON ~= 0 then
        m.faceAngle.y = m.faceAngle.y - 0x8000
        mario_set_forward_vel(m, 20)
        return set_mario_action(m, ACT_LONG_JUMP, 0)
    end

    set_character_anim_with_accel(m, CHAR_ANIM_RUNNING, 8 * 0x10000)
    play_step_sound(m, 9, 45)

    m.vel.y = 35
    perform_air_step(m, 0)
    if not m.wall then
        mario_set_forward_vel(m, 20)
        return set_mario_action(m, ACT_TRIPLE_JUMP, 0)
    end
    
    m.marioObj.header.gfx.pos.x = m.pos.x + 50 * sins(m.faceAngle.y)
    m.marioObj.header.gfx.pos.z = m.pos.z + 50 * coss(m.faceAngle.y)
    m.marioObj.header.gfx.angle.x = -0x4000
end)