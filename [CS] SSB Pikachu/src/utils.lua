--#region Localizations ---------------------------------------------------------------------

local djui_chat_message_create = djui_chat_message_create
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable

---@param idx integer
---@return integer
function getLocalFromGlobalIndex(idx)
    if not nps[idx] then return -1 end

    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == idx then
            return i
        end
    end

    return -1
end

---@param m MarioState
function castElectroBall(m)
    if playerTable[m.playerIndex].shockCooldown == 0 then
        if m.playerIndex == 0 then
            local pos = {
                x = get_hand_foot_pos_x(m, 0),
                y = get_hand_foot_pos_y(m, 0),
                z = get_hand_foot_pos_z(m, 0)
            }
            spawn_sync_object(id_bhvElectroBall, E_MODEL_ELECTRO_BALL, pos.x, pos.y, pos.z, function(eb)
                eb.oOwner = nps[0].globalIndex
                eb.oMoveAngleYaw = m.faceAngle.y
            end)
            playerTable[0].shockCooldown = 30
        end
        play_character_sound(m, CHAR_SOUND_HERE_WE_GO)
    end
end

---@param cond? boolean
---@param ifTrue any
---@param ifFalse any
function ternary(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    else
        return ifFalse
    end
end

function debugLog(msg)
    djui_chat_message_create(tostring(msg))
end