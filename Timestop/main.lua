-- name: Timestop v1.1
-- description: There are two teams and one of them has a Sta... ehem, ability to stop time.\n\nBest played with MarioHunt.\n\nMade by \\#333\\Profe\\#ff0\\Javix

--#region Localizations ---------------------------------------------------------------------

local audio_sample_play = audio_sample_play
local djui_popup_create = djui_popup_create
local hook_chat_command = hook_chat_command
local hook_event = hook_event
local le_set_ambient_color = le_set_ambient_color
local lower = string.lower
local network_is_server = network_is_server
local network_player_connected_count = network_player_connected_count
local network_player_set_description = network_player_set_description
local play_sound = play_sound
local set_mario_action = set_mario_action

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

globalTable.timeStopTeam = TEAM_RED

globalTable.timeStopStartingSeconds = 150
globalTable.timeStopStartingCooldown = 300

globalTable.timeStopSeconds = 0
globalTable.timeStopCooldown = 0

for i = 0, MAX_PLAYERS - 1 do
    playerTable[i].team = -1
    playerTable[i].timestopKBTimer = 0
    playerTable[i].timestopDmg = 0
    playerTable[i].playResumeSound = false
end

function update()

    if mhExists and playerTable[0].team ~= getTeam(0) then
        playerTable[0].team = getTeam(0)
    end

    if network_is_server() then

        if playerTable[0].team == -1 then
            playerTable[0].team = TEAM_RED
        end

        if globalTable.timeStopCooldown > 0 then
            globalTable.timeStopCooldown = globalTable.timeStopCooldown - 1
        end

        if globalTable.timeStopSeconds > 0 then
            globalTable.timeStopSeconds = globalTable.timeStopSeconds - 1

            if globalTable.timeStopSeconds == 0 then
                ambientTimer = 0
                globalTable.timeStopCooldown = globalTable.timeStopStartingCooldown

                for i = 0, MAX_PLAYERS - 1 do
                    if nps[i].connected then
                        playerTable[i].playResumeSound = true
                    end
                end
            end
        end
    end

    if globalTable.timeStopSeconds > 0 then
        playerTable[0].timestopKBTimer = playerTable[0].timestopKBTimer + 1
    else
        playerTable[0].timestopKBTimer = 0
    end
end

---@param m MarioState
function mario_update(m)

    local idx = m.playerIndex
    local team = playerTable[idx].team

    if not mhExists then
        network_player_set_description(
            nps[idx],
            TEAM_NAMES[team][1],
            TEAM_COLORS[team].r, TEAM_COLORS[team].g, TEAM_COLORS[team].b, TEAM_COLORS[team].a
        )
    end

    if globalTable.timeStopSeconds > 0 then
        if m.action ~= ACT_FROZEN and
        m.action ~= ACT_BUBBLED and
        m.action & ACT_GROUP_CUTSCENE == 0 and
        team ~= globalTable.timeStopTeam and
        playerTable[idx].timestopKBTimer >= 10 then
            set_mario_action(m, ACT_FROZEN, 0)
        end
    else

        if playerTable[idx].timestopDmg ~= 0 then
            m.hurtCounter = m.hurtCounter + playerTable[idx].timestopDmg
            playerTable[idx].timestopDmg = 0
        end

        if m.controller.buttonPressed & X_BUTTON ~= 0 and globalTable.timeStopTeam == team then

            if globalTable.timeStopCooldown == 0 then
                ambientTimer = 0

                if idx == 0 then
                    globalTable.timeStopSeconds = globalTable.timeStopStartingSeconds
                    set_mario_action(m, ACT_STOP_TIME, 0)
                end
            elseif idx == 0 then
                play_sound(SOUND_MENU_CAMERA_BUZZ, gGlobalSoundSource)
            end
        end
    end

    if idx ~= 0 then return end

    if playerTable[0].playResumeSound then
        playerTable[0].playResumeSound = false

        if allowJJBAEffects then
            audio_sample_play(SOUND_TIME_RESUME, gGlobalSoundSource, 2)
        end
    end
end

---@param m MarioState
function on_player_connected(m)
    if not mhExists and network_is_server() then
        playerTable[m.playerIndex].team = ternary(playersInTeam(TEAM_RED) > playersInTeam(TEAM_BLUE), TEAM_BLUE, TEAM_RED)
    end
end

---@param m MarioState
function on_player_disconnected(m)
    playerTable[m.playerIndex].team = -1
end

---@param attacker MarioState
---@param victim MarioState
function on_pvp_attack(attacker, victim)
    if playerTable[attacker.playerIndex].team ~= playerTable[victim.playerIndex].team and
    globalTable.timeStopSeconds > 0 then
        playerTable[victim.playerIndex].timestopDmg = playerTable[victim.playerIndex].timestopDmg + victim.hurtCounter
        victim.hurtCounter = 0
        playerTable[victim.playerIndex].timestopKBTimer = 0
    end
end

---@param m MarioState
function on_interact(m)
    if globalTable.timeStopTeam ~= playerTable[m.playerIndex].team and
    globalTable.timeStopSeconds > 0 then
        m.hurtCounter = 0
    end
end

function on_level_init()
    le_set_ambient_color(255, 255, 255)
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_disconnected)
hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)
hook_event(HOOK_ON_INTERACT, on_interact)
hook_event(HOOK_ON_LEVEL_INIT, on_level_init)

if not mhExists then

    hook_chat_command('ts-team', '[red|blue] - Change your team', function(msg)

        local curTeam = TEAM_NAMES[playerTable[0].team][1]
        msg = lower(msg)

        if msg == 'red' or msg == 'blue' then
            if lower(curTeam) ~= msg and
            network_player_connected_count() > 1 and
            playersInTeam(playerTable[0].team) <= 1 then
                djui_popup_create('You are the only member of ' .. curTeam .. 'Team', 1)
                return true
            end

            if msg == 'red' then
                playerTable[0].team = TEAM_RED
            elseif msg == 'blue' then
                playerTable[0].team = TEAM_BLUE
            end

            curTeam = TEAM_NAMES[playerTable[0].team][1]
        end

        djui_popup_create('You belong to ' .. curTeam .. ' Team', 1)

        return true
    end)
end

if network_is_server() then
    local options = '['..ternary(mhExists, 'hunters|runners', 'red|blue')..']'
    hook_chat_command('ts-teammode', options .. ' - Set which team can stop time', function (msg)
        
        msg = lower(msg)
        local nameIdx = ternary(mhExists, 2, 1)

        if msg == lower(TEAM_NAMES[TEAM_RED][nameIdx]) then
            globalTable.timeStopTeam = TEAM_RED
        elseif msg == lower(TEAM_NAMES[TEAM_BLUE][nameIdx]) then
            globalTable.timeStopTeam = TEAM_BLUE
        end

        djui_popup_create('Timestop team: ' .. TEAM_NAMES[globalTable.timeStopTeam][nameIdx] .. ' Team', 1)

        return true
    end)
end
