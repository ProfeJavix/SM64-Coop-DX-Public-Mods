-- name: Shotgun Coop v1.1
-- description: Grab a shotgun and start shooting everyone and everything! Best played with MarioHunt and its team mechanics, but it can be used alone.\n\nCredits to Gun Mod and Shotgun Mario romhack for the gun concept and gameplay.\n\nMade by \\#333\\Profe\\#ff0\\Javix

local hook_event = hook_event
local spawn_non_sync_object = spawn_non_sync_object
local set_first_person_enabled = set_first_person_enabled
local get_first_person_enabled = get_first_person_enabled
local set_mario_action = set_mario_action
local play_sound = play_sound
local calculate_pitch = calculate_pitch
local network_is_server = network_is_server
local hook_chat_command = hook_chat_command
local popup = djui_popup_create
local ceil = math.ceil
local tonumber = tonumber
local mod_storage_load = mod_storage_load
local mod_storage_save_number = mod_storage_save_number

local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

SHOOT_BUTTON = ceil(tonumber(mod_storage_load('SHOOT_BUTTON')) or Y_BUTTON)
AIM_BUTTON = ceil(tonumber(mod_storage_load('AIM_BUTTON')) or X_BUTTON)

if network_is_server() then
    globalTable.reloadStartTimer = ceil(tonumber(mod_storage_load('sgReloadTimer')) or 150)
    globalTable.boostShootTimer = ceil(tonumber(mod_storage_load('sgBoostShootTimer')) or 90)
    globalTable.sgDamagesMobs = (mod_storage_load('sgDamagesMobs') or true) == true
    globalTable.allowFlyingGlitch = (mod_storage_load('allowFlyingGlitch') or false) == true
end

globalTable.mhTeamWithSG = 0

for i = 0, MAX_PLAYERS - 1 do
    playerTable[i].shootSGTimer = 0
    playerTable[i].holdingYTimer = 0
end

isHoldingShootButton = false
reloadTimer = 0

---@param m MarioState
function handleSGMoves(m)

    if playerTable[m.playerIndex].shootSGTimer == 0 or
    m.action & ACT_FLAG_SG_NOT_ALLOWED ~= 0 or
    SG_ACTIONS[m.action] then return end

    local act, arg = ACT_SG_SHOOT, 50

    local timer = playerTable[m.playerIndex].holdingYTimer
    if timer > globalTable.boostShootTimer then
        act = ACT_SG_BOOST_SHOOT
        arg = 1
    end

    if m.action == ACT_GROUND_POUND then
        act = ACT_SG_GP_SHOOT
    end

    set_mario_action(m, act, arg)

    if m.playerIndex == 0 then
        reloadTimer = globalTable.reloadStartTimer
    end
end 

function update()
    if isHoldingShootButton then
        playerTable[0].holdingYTimer = playerTable[0].holdingYTimer + 1
    end

    if playerTable[0].shootSGTimer > 0 then
        playerTable[0].shootSGTimer = playerTable[0].shootSGTimer - 1
    end

    if reloadTimer > 0 then
        reloadTimer = reloadTimer - 1
    end
end

---@param m MarioState
function before_mario_update(m)
    local idx = m.playerIndex

    local sg = shotgunObjs[idx]
    if shouldHaveSGForLocal(idx) then
        if sg == nil then
            shotgunObjs[idx] = spawn_non_sync_object(id_bhvMHShotgun, E_MODEL_SHOTGUN, m.pos.x, m.pos.y, m.pos.z, function (o)
                o.heldByPlayerIndex = idx
            end)
            sg = shotgunObjs[idx]
        end
    elseif sg ~= nil then
        shotgunObjs[idx] = nil
        sg = nil
        if idx == 0 then
            set_first_person_enabled(false)
        end
    end

    if sg then

        handleSGMoves(m)
    end

    if idx ~= 0 then return end

    if sg then

        if not isHoldingShootButton and playerTable[0].shootSGTimer == 0 then
            playerTable[0].holdingYTimer = 0
        end

        if m.controller.buttonPressed & SHOOT_BUTTON ~= 0 and m.action & ACT_FLAG_SG_NOT_ALLOWED == 0 then
            if reloadTimer == 0 then
                isHoldingShootButton = true
            else
                play_sound(SOUND_MENU_CAMERA_BUZZ, gGlobalSoundSource)
            end
        end

        if m.controller.buttonReleased & SHOOT_BUTTON ~= 0 and isHoldingShootButton then
            playerTable[0].shootSGTimer = 5
            isHoldingShootButton = false
        end

        if m.controller.buttonPressed & AIM_BUTTON ~= 0 and not SG_ACTIONS[m.action] and m.action & ACT_FLAG_SG_NOT_ALLOWED == 0 then
            set_first_person_enabled(not get_first_person_enabled())
            gFirstPersonCamera.yaw = m.faceAngle.y - 0x8000
        end

        if get_first_person_enabled() then
            m.faceAngle.x = gFirstPersonCamera.pitch
            if m.forwardVel == 0 then
                m.faceAngle.y = gFirstPersonCamera.yaw - 0x8000
            end
        elseif m.action & ACT_FLAG_SG_NOT_ALLOWED == 0 then
            m.faceAngle.x = -calculate_pitch(gLakituState.pos, gLakituState.focus)
        end
    end
end

---@param m MarioState
---@param incAct integer
---@return integer | nil
function before_set_action(m, incAct)

    if not shotgunObjs[m.playerIndex] then return end

    if (incAct & ACT_FLAG_SG_NOT_ALLOWED ~= 0 and m.playerIndex == 0 or incAct == ACT_SG_GP_SHOOT or incAct == ACT_GROUND_POUND) and get_first_person_enabled() then
        set_first_person_enabled(false)
    end

    if not globalTable.allowFlyingGlitch and incAct == ACT_GROUND_POUND and SG_ACTIONS[m.action] then
        return 1
    end
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_action)


local BTNS = {
    ['A'] = A_BUTTON,
    ['B'] = B_BUTTON,
    ['Z'] = Z_TRIG,
    ['X'] = X_BUTTON,
    ['Y'] = Y_BUTTON,
    ['R'] = R_TRIG,
    ['L'] = L_TRIG,
    ['C-UP'] = U_CBUTTONS,
    ['C-DOWN'] = D_CBUTTONS,
    ['C-LEFT'] = L_CBUTTONS,
    ['C-RIGHT'] = R_CBUTTONS,
    ['DPAD-UP'] = U_JPAD,
    ['DPAD-DOWN'] = D_JPAD,
    ['DPAD-LEFT'] = L_JPAD,
    ['DPAD-RIGHT'] = R_JPAD,
}

local allowedValues = '['
for k, _ in pairs(BTNS) do
    allowedValues = allowedValues .. k .. '|'
end
allowedValues = allowedValues:sub(1, #allowedValues - 1) .. ']'

hook_chat_command('sgcoop-shootBtn', allowedValues .. ' Change the shoot button.', function (msg)

    msg = msg:upper()
    local btn = BTNS[msg]

    if btn then

        if btn == AIM_BUTTON then
            popup(msg .. ' is already used for aiming.', 1)
            return true
        end

        SHOOT_BUTTON = btn
        mod_storage_save_number('SHOOT_BUTTON', SHOOT_BUTTON)
    else
        for k, v in pairs(BTNS) do
            if v == SHOOT_BUTTON then
                msg = k
                break
            end
        end
    end

    popup('Current Shooting Button: ' .. msg, 1)
    return true
end)

hook_chat_command('sgcoop-aimBtn', allowedValues .. ' Change the aim button.', function (msg)

    msg = msg:upper()
    local btn = BTNS[msg]

    if btn then

        if btn == SHOOT_BUTTON then
            popup(msg .. ' is already used for shooting.', 1)
            return true
        end

        AIM_BUTTON = btn
        mod_storage_save_number('AIM_BUTTON', AIM_BUTTON)
    else
        for k, v in pairs(BTNS) do
            if v == AIM_BUTTON then
                msg = k
                break
            end
        end
    end

    popup('Current Aiming Button: ' .. msg, 1)
    return true
end)

if network_is_server() and _G.mhExists then

    TEAM_ON_COMMAND = {
        [0] = 'Hunters (0)',
        [1] = 'Runners (1)',
        [2] = 'Everyone (2)'
    }

    hook_chat_command('sgcoop-mhteam', '[0 | hunters | 1 | runners | 2 | both] Give shotguns to team', function (msg)
        
        msg = msg:lower()
        local text = 'Shotguns are set for: '
        if msg == "" then
            text = text.. TEAM_ON_COMMAND[globalTable.mhTeamWithSG]
        elseif msg == 'hunters' or msg == '0' then
            globalTable.mhTeamWithSG = 0
            text = text .. TEAM_ON_COMMAND[0]
        elseif msg == 'runners' or msg == '1' then
            globalTable.mhTeamWithSG = 1
            text = text .. TEAM_ON_COMMAND[1]
        elseif msg == 'both' or msg == '2' then
            globalTable.mhTeamWithSG = 2
            text = text .. TEAM_ON_COMMAND[2]
        else
            text = 'Valid values are:\n-\"hunters\" or \"0\"\n-\"runners\" or \"1\"\n-\"both\" or \"2\"'
        end

        popup(text, 1)
        return true
    end)
end