--#region Localizations ---------------------------------------------------------------------

local get_id_from_behavior = get_id_from_behavior
local hurt_and_set_mario_action = hurt_and_set_mario_action
local passes_pvp_interaction_checks = passes_pvp_interaction_checks
local set_mario_action = set_mario_action

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local playerTable = gPlayerSyncTable

local hooks = {}

function hooks.update()
    if playerTable[0].shockCooldown > 0 then
        playerTable[0].shockCooldown = playerTable[0].shockCooldown - 1
    end

    if playerTable[0].smashDownCooldown > 0 then
        playerTable[0].smashDownCooldown = playerTable[0].smashDownCooldown - 1
    end
end

---@param m MarioState
---@param o Object
function hooks.allow_interact(m, o)
    local id = get_id_from_behavior(o.behavior)

    if isPikachu(m.playerIndex) then
        if ((id == id_bhvThunderSeg or id == id_bhvElectroBall) and o.oElectroOwner == nps[m.playerIndex].globalIndex) or
        (_G.weatherCycleApi and obj_has_model_extended(o, _G.weatherCycleApi.constants.E_MODEL_WC_LIGHTNING) ~= 0) then
            return false
        end
    end

    if id == id_bhvThunderSeg and m.invincTimer == 0 then
        hurt_and_set_mario_action(m, ACT_TURBO_SHOCKED, o.oElectroOwner, ternary(isStorm(), 12, 8))
        return false
    end
end

---@param a MarioState
---@param v MarioState
function hooks.pika_allow_pvp_attack(a, v)
    if isPikachu(a.playerIndex) and a.action == ACT_SMASH_SIDE and passes_pvp_interaction_checks(a, v) ~= 0 then
        playerTable[a.playerIndex].smashSideHit = true
        hurt_and_set_mario_action(v, ACT_TURBO_SHOCKED, nps[a.playerIndex].globalIndex, 12)
        return false
    end
end

---@param m MarioState
function hooks.pika_mario_update(m)

    if m.action ~= ACT_SMASH_UP and m.floorHeight == m.pos.y then
        playerTable[m.playerIndex].smashUpBlocked = false
    end

    if m.action & (ACT_GROUP_CUTSCENE | ACT_FLAG_ON_POLE | ACT_FLAG_HANGING | ACT_FLAG_RIDING_SHELL | ACT_FLAG_INVULNERABLE) ~= 0 then
        return
    end

    if m.controller.buttonPressed & Y_BUTTON ~= 0 and m.action ~= ACT_SMASH_UP and
    (m.action & ACT_FLAG_SWIMMING_OR_FLYING == 0 or m.action & ACT_FLAG_SWIMMING ~= 0) and
    not playerTable[m.playerIndex].smashUpBlocked then
        playerTable[m.playerIndex].smashUpBlocked = true
        return set_mario_action(m, ACT_SMASH_UP, 0)
    end

    if m.action & ACT_FLAG_SWIMMING_OR_FLYING ~= 0 then return end

    if m.action == ACT_GROUND_POUND and m.controller.buttonDown & B_BUTTON ~= 0 then
        return set_mario_action(m, ACT_SMASH_SIDE, 0)
    end

    if playerTable[m.playerIndex].smashDownCooldown == 0 and
    m.controller.buttonPressed & X_BUTTON ~= 0 and
    m.action ~= ACT_SMASH_NORMAL and m.action ~= ACT_SMASH_SIDE then
        playerTable[m.playerIndex].smashDownCooldown = 50
        set_mario_action(m, ACT_SMASH_DOWN, 0)
    end
end

---@param m MarioState
---@param incAct integer
function hooks.pika_before_set_mario_action(m, incAct)

    if incAct == ACT_PUNCHING or incAct == ACT_MOVE_PUNCHING or (incAct == ACT_JUMP_KICK and m.action ~= ACT_SMASH_NORMAL) then
        return set_mario_action(m, ACT_SMASH_NORMAL, ternary(incAct == ACT_JUMP_KICK, 1, 0))
    end
end

---@param m MarioState
function hooks.pika_allow_force_water_action(m)
    if m.action == ACT_SMASH_UP and m.actionState ~= 2 then
        return false
    end

    playerTable[m.playerIndex].smashUpBlocked = false
end

return hooks