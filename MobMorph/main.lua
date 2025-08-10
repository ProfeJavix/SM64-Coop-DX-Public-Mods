-- name: \\#f00\\Mob\\#9350ad\\Morph \\#fff\\v1.1
-- description: This mod allows you to select a mob from a list and morph into it. Don't expect a vanilla behavior from that mob >:).\n\nAlso adapted to EmilyEmmi's MarioHunt team mechanics.\n\nThanks to \\#890606\\Mugiboy\\#fff\\ for helping me testing everything.\n\nMade by \\#333\\Profe\\#ff0\\Javix

local network_is_server = network_is_server
local hookAction = hook_mario_action
local hookEvent = hook_event
local clamp = clampf
local set_mario_action = set_mario_action
local set_mario_particle_flags = set_mario_particle_flags
local play_sound = play_sound
local mario_stop_riding_and_holding = mario_stop_riding_and_holding
local object_pos_to_vec3f = object_pos_to_vec3f

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable
local cam = gLakituState

--#region Globals ------------------------------------------------------------------------------------------------------------------------------
ACT_MORPHED = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)

selectedMobPos = 1

globalTable.allowNametagsInMobs = true
globalTable.allowBosses = true
globalTable.allowNpcs = true

globalTable.startingMorphCooldown = 300
globalTable.morphedCooldown = true

globalTable.mhMorphOnlyForHunters = true
globalTable.mhHunterOnlyAttackWithMobs = false

playerTable[0].blockInputTimer = 0
playerTable[0].morphCooldown = 0
playerTable[0].leaveMobCooldown = 0
playerTable[0].morphedBhvId = -1

if network_is_server() then
    gServerSettings.pauseAnywhere = true
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region MH Comp. ---------------------------------------------------------------------------------------------------------------------
mhExists = _G.mhExists
getMHTeam = function(_) return 0 end
mhPvpIsValid = function(_, _) return true end
if mhExists then
    getMHTeam = _G.mhApi.getTeam
    mhPvpIsValid = _G.mhApi.pvpIsValid
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Colored Nametags Comp. ---------------------------------------------------------------------------------------------------------------
cnOn = _G.coloredNametagsOn
cnSetNametagVisibility = function(_, _) end
cnSetNametagWorldPos = function(_, _) end
if cnOn then
    cnSetNametagVisibility = _G.coloredNametagsFuncs.set_nametag_visibility
    cnSetNametagWorldPos = _G.coloredNametagsFuncs.set_nametag_world_pos
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Mario Action -------------------------------------------------------------------------------------------------------------------------

---@param m MarioState
function act_morphed(m)

    if m.usedObj == nil or
    m.usedObj.activeFlags == ACTIVE_FLAG_DEACTIVATED or
    (mhExists and globalTable.mhControlOnlyForHunters and getMHTeam(m.playerIndex) == 1) then
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
        m.squishTimer = 0
        m.invincTimer = 30
        play_sound(SOUND_GENERAL_PAINTING_EJECT, m.marioObj.header.gfx.cameraToObject)
        set_mario_action(m, ACT_IDLE, 0)
        return false
    end

    local state = m.actionState

    if state == 0 then
        m.forwardVel = 0
        m.actionTimer = 20
        m.usedObj.oMorphedPlayer = nps[m.playerIndex].globalIndex
        m.actionState = 1
    elseif state == 1 then

        local angle = m.marioObj.header.gfx.angle.y
        
        if m.actionArg ~= 2 then --cause, if not, small whomp dashes like crazy
            m.usedObj.oPosX = m.pos.x
            m.usedObj.oPosY = m.pos.y
            m.usedObj.oPosZ = m.pos.z
        end
        
        set_character_animation(m, CHAR_ANIM_TWIRL)

        m.marioObj.header.gfx.angle.y = angle + 0x2000
        local timerScale = m.actionTimer / 20
        m.squishTimer = 0xFF
        vec3f_set(m.marioObj.header.gfx.scale, timerScale, timerScale, timerScale)

        m.actionTimer = m.actionTimer - 1
        if m.actionTimer <= 0 then
            play_sound(SOUND_MARIO_HERE_WE_GO, m.pos)
            m.usedObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
            m.usedObj.oIntangibleTimer = 0
            m.actionState = 2
        elseif angle > m.marioObj.header.gfx.angle.y then
            play_sound(SOUND_GENERAL_SHORT_STAR, m.marioObj.header.gfx.cameraToObject)
        end
        set_mario_particle_flags(m, PARTICLE_SPARKLES, 0)
    else
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags | GRAPH_RENDER_INVISIBLE
        m.squishTimer = 0
        set_mario_animation(m, MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)
        m.faceAngle.y = m.usedObj.oFaceAngleYaw

        m.pos.x = m.usedObj.oPosX - 10 * sins(m.usedObj.oFaceAngleYaw)
        m.pos.y = m.usedObj.oPosY
        m.pos.z = m.usedObj.oPosZ - 10 * coss(m.usedObj.oFaceAngleYaw)

        if m.actionArg == 1 then
            m.pos.y = m.pos.y + 500
            if m.playerIndex == 0 then
                object_pos_to_vec3f(cam.curFocus, m.usedObj)
            end
        end
    end
    vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
end

hookAction(ACT_MORPHED, act_morphed)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hook Functions -----------------------------------------------------------------------------------------------------------------------

function update()
    if playerTable[0].blockInputTimer > 0 then
        playerTable[0].blockInputTimer = playerTable[0].blockInputTimer - 1
    end
    if playerTable[0].morphCooldown > 0 then
        playerTable[0].morphCooldown = playerTable[0].morphCooldown - 1
    end
    if playerTable[0].leaveMobCooldown > 0 then
        playerTable[0].leaveMobCooldown = playerTable[0].leaveMobCooldown - 1
    end
end

---@param m MarioState
function useColoredNametags(m)

    if cnOn then
        if m.action == ACT_MORPHED and m.usedObj ~= nil then
            cnSetNametagVisibility(m.playerIndex, globalTable.allowNametagsInMobs)
            local o = m.usedObj
            cnSetNametagWorldPos(m.playerIndex, {x = o.oPosX, y = o.oPosY - o.hitboxDownOffset + o.hitboxHeight + 100, z = o.oPosZ})
        else
            cnSetNametagVisibility(m.playerIndex, true)
            cnSetNametagWorldPos(m.playerIndex, nil)
        end
    end
end

---@param m MarioState
function moveListPos(m)

    local total = getTotalMobs()
    local newSelPos = selectedMobPos

    if m.controller.buttonPressed & U_JPAD ~= 0 or
        m.controller.buttonPressed & L_JPAD ~= 0 or
        m.controller.buttonPressed & D_JPAD ~= 0 or
        m.controller.buttonPressed & R_JPAD ~= 0 then
        local amount = 0

        if m.controller.buttonPressed & U_JPAD ~= 0 then
            amount = -1
        elseif m.controller.buttonPressed & L_JPAD ~= 0 then
            amount = -5
        elseif m.controller.buttonPressed & D_JPAD ~= 0 then
            amount = 1
        else
            amount = 5
        end

        newSelPos = selectedMobPos + amount

        if selectedMobPos == 1 and amount < 0 then
            newSelPos = total
        elseif selectedMobPos == total and amount > 0 then
            newSelPos = 1
        end

        play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
    end

    selectedMobPos = clamp(newSelPos, 1, total)
end

---@param m MarioState
function mario_update(m)

    useColoredNametags(m)

    if m.playerIndex ~= 0 then return end

    if m.action ~= ACT_MORPHED then

        playerTable[0].morphedBhvId = -1

        if (mhExists and globalTable.mhMorphOnlyForHunters and getMHTeam(0) == 1) or
        playerTable[0].morphCooldown > 0 or playerTable[0].blockInputTimer > 0 or
        m.heldObj ~= nil then return end

        if m.controller.buttonPressed & X_BUTTON ~= 0 and m.action & ACT_GROUP_CUTSCENE == 0 then
            local mobData = findMobDataBySelection()
            if mobData == nil or not canMorphIntoMob(mobData) then
                playerTable[0].blockInputTimer = 10
                djui_popup_create("This level has reached his max amount of the selected mob.", 1)
                return
            end

            mario_stop_riding_and_holding(m)

            if globalTable.morphedCooldown and mobData[4] ~= -1 then
                playerTable[0].leaveMobCooldown = mobData[4]
            end

            if mobData[6] then
                m.pos.y = m.floorHeight
            end

            m.usedObj = spawn_sync_object(mobData[1], mobData[3], m.pos.x, m.pos.y, m.pos.z, function (o)

                o.header.gfx.node.flags = m.marioObj.header.gfx.node.flags | GRAPH_RENDER_INVISIBLE
                o.oIntangibleTimer = -1

                if mobData[5] ~= nil then
                    mobData[5](o)
                end
            end)
            playerTable[0].blockInputTimer = 20
            playerTable[0].morphedBhvId = mobData[1]
            set_mario_action(m, ACT_MORPHED, mobData[8])
        end

        moveListPos(m)
    end
end

---@param attacker MarioState
---@param victim MarioState
function on_allow_pvp_attack(attacker, victim)
    if mhExists and globalTable.mhHunterOnlyAttackWithMobs and getMHTeam(attacker.playerIndex) == 0 then
        return false
    end
    return mhPvpIsValid(attacker, victim)
end

---@param idx integer
---@return string | nil
function on_nametags_render(idx)
    if cnOn or states[idx].action == ACT_MORPHED then
        return ""
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_UPDATE, update)
hookEvent(HOOK_MARIO_UPDATE, mario_update)
hookEvent(HOOK_ALLOW_PVP_ATTACK, on_allow_pvp_attack)
hookEvent(HOOK_ON_NAMETAGS_RENDER, on_nametags_render)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------