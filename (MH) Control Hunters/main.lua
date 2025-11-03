-- name: (MH) Control Hunters v1.0
-- description: Extension for EmilyEmmi's Mario Hunt that allows runners to take control of a selected hunter for a certain amount of time.\n\nMade by \\#333\\Profe\\#ff0\\Javix

if not _G.mhExists then return end

local popup = djui_popup_create
local allocate_mario_action = allocate_mario_action
local hookAction = hook_mario_action
local hookEvent = hook_event
local set_mario_action = set_mario_action
local obj_scale = obj_scale
local play_sound = play_sound
local vec3f_copy = vec3f_copy
local vec3s_copy = vec3s_copy
local mario_stop_riding_and_holding = mario_stop_riding_and_holding
local resetOverridePalette = network_player_reset_override_palette
local setNPDescription = network_player_set_description
local warp = warp_to_level

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

--#region Globals ------------------------------------------------------------------------------------------------------------------------------
globalTable.controlStartTimer = 600
globalTable.controlStartCooldown = 300

playerTable[0].controlTimer = 0

playerTable[0].warping = false
playerTable[0].warpTimer = 0

playerTable[0].becomeControlled = false
playerTable[0].idxActArg = -1
playerTable[0].forceKill = false

playerTable[0].isControlling = false
playerTable[0].controlledHunterIdx = -1

ACT_HUNTER_CONTROLLED = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)

--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Local Player Stuff -------------------------------------------------------------------------------------------------------------------
controlCooldown = 0
local selectedPlayerIdx = -1
local prevState = nil
local mToWarp = nil
local warpingType = 0 -- 0: to other player | 1: to prev pos | 2: controlled hunter warp
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region MH Funcs. ----------------------------------------------------------------------------------------------------------------------------
getTeam = _G.mhApi.getTeam
isSpectator = _G.mhApi.isSpectator
isDead = _G.mhApi.isDead
becomeHunter = _G.mhApi.become_hunter
becomeRunner = _G.mhApi.become_runner
pvpIsValid = _G.mhApi.pvpIsValid
getGlobalField = _G.mhApi.getGlobalField
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Mario Action -------------------------------------------------------------------------------------------------------------------------

---@param m MarioState
function act_hunter_controlled(m)
    local controllerIdx = getLocalIdxFromGlobal(m.actionArg)

    if controllerIdx == -1 or not playerTable[controllerIdx].isControlling then
        m.squishTimer = 0
        set_mario_action(m, ACT_IDLE, 0)
        if m.playerIndex == 0 then
            play_sound(SOUND_GENERAL_PAINTING_EJECT, m.marioObj.header.gfx.cameraToObject)
        end
        becomeHunter(m.playerIndex)
        return
    end

    local cm = states[controllerIdx]

    if (playerTable[controllerIdx].warpTimer and playerTable[controllerIdx].warpTimer > 0) then return end

    if not playersInSameArea(m.playerIndex, controllerIdx) then
        warp(nps[controllerIdx].currLevelNum, nps[controllerIdx].currAreaIndex, nps[controllerIdx].currActNum)
        if m.playerIndex == 0 then
            setWarping(2, cm)
        end
        return
    end

    m.squishTimer = 0xFF
    obj_scale(m.marioObj, 0)
    m.health = cm.health

    vec3s_copy(m.faceAngle, cm.faceAngle)
    if m.actionState == 0 then
        vec3f_copy(m.pos, cm.pos)
        vec3f_copy(m.marioObj.header.gfx.pos, cm.marioObj.header.gfx.pos)
        m.actionState = 1
    else
        vec3f_copy_interpolated(m.pos, cm.pos, .6)
        vec3f_copy_interpolated(m.marioObj.header.gfx.pos, cm.marioObj.header.gfx.pos, .6)
    end
end

hookAction(ACT_HUNTER_CONTROLLED, act_hunter_controlled)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Sub Funcs ----------------------------------------------------------------------------------------------------------------------------

---@param m MarioState
function moveListPos(m)
    if m.action == ACT_HUNTER_CONTROLLED or playerTable[0].isControlling then return end

    local hunters = getHuntersList()
    if #hunters == 0 then
        selectedPlayerIdx = -1
        return
    end
    local amount = 0
    if m.controller.buttonPressed & U_JPAD ~= 0 or
        m.controller.buttonPressed & L_JPAD ~= 0 or
        m.controller.buttonPressed & D_JPAD ~= 0 or
        m.controller.buttonPressed & R_JPAD ~= 0 then
        if m.controller.buttonPressed & U_JPAD ~= 0 then
            amount = -1
        elseif m.controller.buttonPressed & L_JPAD ~= 0 then
            amount = -5
        elseif m.controller.buttonPressed & D_JPAD ~= 0 then
            amount = 1
        else
            amount = 5
        end

        play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
    end
    selectedListPos = adjustSelectedIdx(selectedListPos, #hunters, amount)
    selectedPlayerIdx = hunters[selectedListPos]
end

---@param m MarioState
function stopControlling(m)
    playerTable[0].isControlling = false
    playerTable[0].controlledHunterIdx = -1

    if prevState then
        local np = nps[0]
        if prevState.course == np.currCourseNum and prevState.level == np.currLevelNum and prevState.area == np.currAreaIndex and prevState.act == np.currActNum then
            setPrevState(m)
        else
            warp(prevState.level, prevState.area, prevState.act)
            setWarping(1)
        end
    end

    controlCooldown = globalTable.controlStartCooldown

    becomeRunner(0)
    playerTable[0].controlTimer = 0
end

---@param m MarioState
function handleLook(m)
    local idx = m.playerIndex
    local np1 = nps[idx]

    local controlledIdx = getLocalIdxFromGlobal(playerTable[idx].controlledHunterIdx)

    if playerTable[idx].isControlling and controlledIdx ~= -1 then
        local np2 = nps[controlledIdx]

        np1.overrideModelIndex = np2.modelIndex
        copyOverridePalette(np1, np2)
    else
        np1.overrideModelIndex = np1.modelIndex
        resetOverridePalette(np1)
    end

    if playerTable[idx].isControlling then
        setNPDescription(np1, "In Control", 255, 143, 33, np1.descriptionA)
    elseif states[idx].action == ACT_HUNTER_CONTROLLED then
        setNPDescription(np1, "Controlled", 184, 43, 246, np1.descriptionA)
    end
end

---@param m MarioState
function handleWarp(m)
    if playerTable[0].warping and playerTable[0].warpTimer == 0 then
        playerTable[0].warping = false

        if warpingType == 0 then
            copyState(m, mToWarp)
        elseif warpingType == 1 then
            setPrevState(m)
        elseif warpingType == 2 then
            if mToWarp then
                set_mario_action(m, ACT_HUNTER_CONTROLLED, nps[mToWarp.playerIndex].globalIndex)
            end
        end
        mToWarp = nil
    end
end

---@param mDest MarioState
---@param mSrc MarioState | nil
function copyState(mDest, mSrc)

    if mSrc == nil then return end

    vec3f_copy(mDest.pos, mSrc.pos)
    vec3f_copy(mDest.marioObj.header.gfx.cameraToObject, mSrc.marioObj.header.gfx.cameraToObject)
    vec3s_copy(mDest.faceAngle, mSrc.faceAngle)
    mDest.health = mSrc.health
    mDest.healCounter = mSrc.healCounter
    mDest.hurtCounter = mSrc.hurtCounter
    mDest.invincTimer = mSrc.invincTimer
    mDest.flags = mSrc.flags

    local capTimer = getCapTimer(mDest.flags)
    if capTimer ~= -1 then
        mDest.capTimer = capTimer
    end

    playCapMusicIfEquiped(mSrc.flags)
    play_sound(SOUND_MENU_STAR_SOUND, mDest.marioObj.header.gfx.cameraToObject)

end

---@param m MarioState
function setPrevState(m)
    if prevState ~= nil then
        m.pos.x = prevState.x
        m.pos.y = prevState.y
        m.pos.z = prevState.z
        m.health = prevState.health
        m.flags = prevState.flags
        m.capTimer = prevState.capTimer
        playCapMusicIfEquiped(m.flags)
    end
    prevState = nil
    set_mario_action(m, ACT_IDLE, 0)
    m.invincTimer = 20
    play_sound(SOUND_GENERAL_PAINTING_EJECT, m.marioObj.header.gfx.cameraToObject)
end

---@param type integer
---@param toM MarioState | nil
---@param time integer | nil
function setWarping(type, toM, time)
    playerTable[0].warping = true
    playerTable[0].warpTimer = time or 5
    mToWarp = toM
    warpingType = type
end

--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hook Functions -----------------------------------------------------------------------------------------------------------------------

function update()
    if playerTable[0].controlTimer > 0 then
        playerTable[0].controlTimer = playerTable[0].controlTimer - 1
    end
    if controlCooldown > 0 then
        controlCooldown = controlCooldown - 1
    end
    if playerTable[0].warpTimer > 0 then
        playerTable[0].warpTimer = playerTable[0].warpTimer - 1
    end
end

---@param m MarioState
function before_mario_update(m)
    if playerTable[m.playerIndex].isControlling then
        local remainingHealth = m.health - 0x40 * m.hurtCounter
        if remainingHealth < 0x100 then
            m.hurtCounter = 0
            playerTable[m.playerIndex].controlTimer = 0

            local controlledIdx = getLocalIdxFromGlobal(playerTable[m.playerIndex].controlledHunterIdx)

            if controlledIdx ~= -1 then
                playerTable[controlledIdx].forceKill = true
            end
        end
    end
end

---@param m MarioState
function mario_update(m)
    handleLook(m)

    if m.playerIndex ~= 0 then return end

    moveListPos(m)

    if playerTable[0].isControlling and
        (getLocalIdxFromGlobal(playerTable[0].controlledHunterIdx) == -1 or playerTable[0].controlTimer <= 0) then
        stopControlling(m)
    end

    if playerTable[0].forceKill then
        m.health = 0
    end
    playerTable[0].forceKill = false

    handleWarp(m)

    if playerTable[0].becomeControlled then
        set_mario_action(m, ACT_HUNTER_CONTROLLED, playerTable[0].idxActArg)

        local controlledIdx = getLocalIdxFromGlobal(playerTable[0].idxActArg)

        becomeRunner(0)
        if controlledIdx ~= -1 then
            becomeHunter(controlledIdx)
        end

        playerTable[0].becomeControlled = false
        playerTable[0].idxActArg = -1
        return
    end

    if m.controller.buttonPressed & X_BUTTON ~= 0 and selectedPlayerIdx ~= -1 and m.action ~= ACT_HUNTER_CONTROLLED and not playerTable[0].isControlling and getTeam(0) == 1 then
        if not playerTable[0].isControlling and controlCooldown == 0 then
            local sm = states[selectedPlayerIdx]
            local smIdx = sm.playerIndex

            local np1 = nps[0]
            local np2 = nps[smIdx]

            if sm.action ~= ACT_HUNTER_CONTROLLED then

                mario_stop_riding_and_holding(m)

                playerTable[smIdx].becomeControlled = true
                playerTable[smIdx].idxActArg = np1.globalIndex

                playerTable[0].isControlling = true
                playerTable[0].controlledHunterIdx = np2.globalIndex

                prevState = {
                    course = np1.currCourseNum,
                    level = np1.currLevelNum,
                    area = np1.currAreaIndex,
                    act = np1.currActNum,
                    x = m.pos.x,
                    y = m.pos.y,
                    z = m.pos.z,
                    health = m.health,
                    flags = m.flags,
                    capTimer = m.capTimer
                }

                if playersInSameArea(0, smIdx) then
                    copyState(m, sm)
                    set_mario_action(m, sm.action, sm.actionArg)
                else
                    warp(np2.currLevelNum, np2.currAreaIndex, np2.currActNum)
                    setWarping(0, sm)
                end

                playerTable[0].controlTimer = globalTable.controlStartTimer
            else
                popup("This player is already being controlled.", 1)
            end
        end
    end
end

---@param attacker MarioState
---@param victim MarioState
---@return boolean
function on_allow_pvp_attack(attacker, victim, _)

    local allow = pvpIsValid(attacker, victim)

    local aIdx, vIdx = attacker.playerIndex, victim.playerIndex
    local ffMode = getGlobalField("anarchy")

    if ffMode ~= 3 then
        if (playerTable[aIdx].isControlling and playerTable[vIdx].isControlling) or --controllers can't hurt each other
        (getTeam(aIdx) == 1 and playerTable[vIdx].isControlling) or --runners can't hurt controllers
        (playerTable[aIdx].isControlling and getTeam(vIdx) == 1) then --controllers can't hurt runners
            allow = (ffMode == 1)
        end
    end

    --hunters and controllers can hurt each other
    if (playerTable[aIdx].isControlling and getTeam(vIdx) == 0) or
    (getTeam(aIdx) == 0 and playerTable[vIdx].isControlling) then
        allow = true
    end

    return allow
end

---@param idx integer
---@return string | nil
function on_nametags_render(idx)

    if states[idx].action == ACT_HUNTER_CONTROLLED then
        return ''
    end
end

--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_UPDATE, update)
hookEvent(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hookEvent(HOOK_MARIO_UPDATE, mario_update)
hookEvent(HOOK_ALLOW_PVP_ATTACK, on_allow_pvp_attack)
hook_event(HOOK_ON_NAMETAGS_RENDER, on_nametags_render)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------
