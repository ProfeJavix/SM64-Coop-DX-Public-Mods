-- name: Mini Mario Mod v1.1
-- description: You have a new size and mass, allowing you to be floatier in air and run on walls. But be careful, you might be more fragile!\n\nMade by \\#333\\Profe\\#ff0\\Javix

local hook_event = hook_event
local degrees_to_sm64 = degrees_to_sm64
local abs_angle_diff = abs_angle_diff
local set_mario_action = set_mario_action
local atan2s = atan2s
local obj_scale = obj_scale
local play_sound = play_sound
local network_is_server = network_is_server
local hook_chat_command = hook_chat_command
local hook_mod_menu_checkbox = hook_mod_menu_checkbox
local mod_storage_exists = mod_storage_exists
local mod_storage_load_number = mod_storage_load_number
local djui_chat_message_create = djui_chat_message_create
local max = math.max

local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

globalTable.miniTeam = 0
globalTable.miniDmgMult = ternary(mod_storage_exists('miniMarioDmgMult'), mod_storage_load_number('miniMarioDmgMult'), 0.5)
globalTable.miniDefenseMult = ternary(mod_storage_exists('miniMarioDefenseMult'), mod_storage_load_number('miniMarioDefenseMult'), 0.5)

for i = 0, MAX_PLAYERS - 1 do
    playerTable[i].isMiniMario = false
end

local hnsUseExtraSpeed = false

---@param m MarioState
function mario_update(m)

    local scale = m.marioObj.header.gfx.scale.x

    if isMiniMario(m) then

        if m.playerIndex == 0 or
        not _G.hnsRebirthExists or
        _G.hnsRebirth.general.get_round_modifiers() & 1 == 0 or
        _G.hnsRebirth.general.is_seeker_or_hidder(m.playerIndex) ~= 0 then
            scale = 0.2
        end

        if m.action ~= ACT_GROUND_POUND then
            m.vel.y = max(m.vel.y, -25)
        end
        m.peakHeight = m.pos.y

        if m.action == ACT_WALKING and m.wall and not m.wall.object and m.intendedMag > 20 then
            local angleToWall = atan2s(m.wallNormal.z, m.wallNormal.x) - 0x8000
            if abs_angle_diff(angleToWall, m.intendedYaw) < degrees_to_sm64(15) then
                m.faceAngle.y = angleToWall
                set_mario_action(m, ACT_WALL_RUN, 0)
            end
        end
    end

    obj_scale(m.marioObj, scale)
    m.marioObj.hitboxHeight = m.marioObj.hitboxHeight * scale

    if m.playerIndex == 0 and _G.hnsRebirthExists then
        hnsUseExtraSpeed = false

        if playerTable[0].isMiniMario and
        _G.hnsRebirth.general.is_seeker_or_hidder(m.playerIndex) == 0 and
        _G.hnsRebirth.general.is_round_running() then
            for i = 1, MAX_PLAYERS - 1 do
                if is_player_active(states[i]) ~= 0 and _G.hnsRebirth.general.is_seeker_or_hidder(i) == 1 then
                    return
                end
            end
            hnsUseExtraSpeed = true
        end
    end
end

---@param m MarioState
function before_phys_step(m)

    if m.playerIndex ~= 0 then return end

    if playerTable[0].isMiniMario and m.action & (ACT_FLAG_INVULNERABLE | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ON_POLE) == 0 and
    m.action ~= ACT_WATER_JUMP and
	(m.prevAction & ACT_FLAG_ON_POLE == 0 or m.action & (ACT_FLAG_AIR) == 0) then

        local mult = ternary(hnsUseExtraSpeed, 2, 1.2)
        
        m.vel.x = m.vel.x * mult
        m.vel.z = m.vel.z * mult
    end
end

local JUMP_ACTIONS = {
    [ACT_JUMP] = true,
    [ACT_HOLD_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_STEEP_JUMP] = true,
    [ACT_SIDE_FLIP] = true,
    [ACT_BACKFLIP] = true,
    [ACT_BURNING_JUMP] = true,
    [ACT_WATER_JUMP] = true,
    [ACT_HOLD_WATER_JUMP] = true,
    [ACT_METAL_WATER_JUMP] = true,
    [ACT_TOP_OF_POLE_JUMP] = true,
    [ACT_SPECIAL_TRIPLE_JUMP] = true,
    [ACT_RIDING_SHELL_JUMP] = true,
    [ACT_WALL_KICK_AIR] = true
}

---@param m MarioState
function on_set_mario_action(m)
    if playerTable[m.playerIndex].isMiniMario and JUMP_ACTIONS[m.action] and m.prevAction ~= ACT_WALL_RUN then
        m.vel.y = m.vel.y * 1.5
    end
end

---@param a MarioState
---@param v MarioState
function on_pvp_attack(a, v)
    local aIdx, vIdx = a.playerIndex, v.playerIndex

    if playerTable[aIdx].isMiniMario and not playerTable[vIdx].isMiniMario then
        v.hurtCounter = v.hurtCounter * globalTable.miniDmgMult
    elseif not playerTable[aIdx].isMiniMario and playerTable[vIdx].isMiniMario then
        v.hurtCounter = v.hurtCounter * 4 * (1 - globalTable.miniDefenseMult)
    end
end

---@param m MarioState
function allow_interact(m)
    if playerTable[m.playerIndex].isMiniMario then
        m.hurtCounter = m.hurtCounter * 4 * (1 - globalTable.miniDefenseMult)
    end
end

local initMsgShown = false
function on_level_init()
    if not initMsgShown then
        djui_chat_message_create('Type /mini-toggle to use the Mini Mario Moveset!')
        initMsgShown = true
    end
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_SET_MARIO_ACTION, on_set_mario_action)
hook_event(HOOK_BEFORE_PHYS_STEP, before_phys_step)
hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)
hook_event(HOOK_ALLOW_INTERACT, allow_interact)

if not _G.mhExists and not _G.hnsRebirthExists and not _G.HideAndSeek then

    hook_event(HOOK_ON_LEVEL_INIT, on_level_init)

    hook_chat_command('mini-toggle', "Toggle your character's mini moveset", function(msg)
        playerTable[0].isMiniMario = not playerTable[0].isMiniMario
        play_sound(ternary(playerTable[0].isMiniMario, SOUND_MENU_ENTER_PIPE, SOUND_MENU_EXIT_PIPE), gGlobalSoundSource)
        return true
    end)
elseif network_is_server() then

    local opts = '[OFF-HUNTERS | ON-RUNNERS]'
    if _G.hnsRebirthExists or _G.HideAndSeek then
        opts = '[OFF-HIDERS | ON-SEEKERS]'
    end

    hook_mod_menu_checkbox('Mini Team '.. opts, false, function(_, val)
        globalTable.miniTeam = ternary(val, 1, 0)

        if _G.mhExists then
            djui_popup_create_global('Current Mini Team: ' .. ternary(val, 'Runners', 'Hunters'), 1)
        elseif _G.hnsRebirthExists or _G.HideAndSeek then
            djui_popup_create_global('Current Mini Team: ' .. ternary(val, 'Seekers', 'Hiders'), 1)
        end
    end)
end

if network_is_server() then
    hook_mod_menu_slider('Mini Mario Attack Mult.', globalTable.miniDmgMult * 10, 1, 10, function (_, val)
        globalTable.miniDmgMult = val / 10
        mod_storage_save_number('miniMarioDmgMult', globalTable.miniDmgMult)
    end)

    hook_mod_menu_slider('Mini Mario Defense Mult.', globalTable.miniDefenseMult * 100, 0, 75, function (_, val)
        globalTable.miniDefenseMult = val / 100
        mod_storage_save_number('miniMarioDmgMult', globalTable.miniDefenseMult)
    end)
end