--#region Localizations ---------------------------------------------------------------------

local allocate_mario_action = allocate_mario_action
local audio_sample_play = audio_sample_play
local hook_mario_action = hook_mario_action
local play_character_sound = play_character_sound
local set_anim_to_frame = set_anim_to_frame
local set_character_anim_with_accel = set_character_anim_with_accel
local set_character_animation = set_character_animation
local set_mario_action = set_mario_action

--#endregion --------------------------------------------------------------------------------

local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

ACT_FROZEN = allocate_mario_action(ACT_FLAG_STATIONARY)
ACT_STOP_TIME = allocate_mario_action(ACT_FLAG_STATIONARY)

hook_mario_action(ACT_FROZEN, function (m)
    if playerTable[m.playerIndex].team == globalTable.timeStopTeam or
    globalTable.timeStopSeconds == 0 then
        return set_mario_action(m, m.prevAction, 0)
    end

    if m.actionState == 0 then
        set_character_animation(m, m.marioObj.header.gfx.animInfo.animID)
        set_anim_to_frame(m, m.marioObj.header.gfx.animInfo.animFrame)
    end
end)

hook_mario_action(ACT_STOP_TIME, function (m)
    
    if m.actionState ~= 0 and m.actionTimer <= 0 then
        return set_mario_action(m, ACT_WALKING, 0)
    end

    if m.actionState == 0 then

        play_character_sound(m, CHAR_SOUND_HERE_WE_GO)

        if allowJJBAEffects then
            audio_sample_play(SOUND_TIME_STOP, gGlobalSoundSource, 2)
        end
        set_character_anim_with_accel(m, CHAR_ANIM_TRIPLE_JUMP_LAND, 0.7 * 0x10000)

        m.actionTimer = 30
        m.actionState = 1
    else
        m.actionTimer = m.actionTimer - 1
    end

end)