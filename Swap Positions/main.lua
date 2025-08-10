-- name: Swap Positions v1.0
-- description: Select a player from the list and swap positions with them. This mod uses EmilyEmmi's MarioHunt team mechanics (if enabled).\n\nMade by \\#333\\Profe\\#ff0\\Javix

local popup = djui_popup_create
local hookEvent = hook_event
local play_sound = play_sound
local warp = warp_to_level

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable

--#region Globals and Variables ----------------------------------------------------------------------------------------------------------------
globalTable.startSwapCooldown = 300
globalTable.everyoneCanSwap = false
globalTable.teamSwap = false

playerTable[0].warping = false
playerTable[0].warpTimer = 0

playerTable[0].targetedForSwap = false
playerTable[0].targetedCooldown = 0

playerTable[0].targetedByIdx = nil

playerTable[0].targetLevelNum = nil
playerTable[0].targetAreaIndex = nil
playerTable[0].targetActNum = nil
playerTable[0].targetPosX = nil
playerTable[0].targetPosY = nil
playerTable[0].targetPosZ = nil

swapCooldown = 0
local selectedPlayerIdx = -1
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region MH Funcs. ----------------------------------------------------------------------------------------------------------------------------
getTeam = function (_) return 0 end
isSpectator = function (_) return false end
isDead = function (_) return false end
getRoleNameAndColor = function (_) return _, _, {r = 230, g = 230, b = 230} end
mhExists = _G.mhExists

if mhExists then
    getTeam = _G.mhApi.getTeam
    isSpectator = _G.mhApi.isSpectator
    isDead = _G.mhApi.isDead
    getRoleNameAndColor = _G.mhApi.get_role_name_and_color
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Sub Funcs ----------------------------------------------------------------------------------------------------------------------------

---@param m MarioState
function moveListPos(m)

    local players = getSwappablePlayers()
    if #players == 0 then
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
    selectedListPos = adjustSelectedIdx(selectedListPos, #players, amount)
    selectedPlayerIdx = players[selectedListPos]
end

---@param m MarioState
function handleSwap(m)

    if playerTable[0].warping then

        if playerTable[0].targetLevelNum and playerTable[0].targetAreaIndex and playerTable[0].targetActNum then
            warp(playerTable[0].targetLevelNum, playerTable[0].targetAreaIndex, playerTable[0].targetActNum)
            if not playerTable[0].targetedForSwap then
                swapCooldown = globalTable.startSwapCooldown
            end
        end
        playerTable[0].targetLevelNum = nil
        playerTable[0].targetAreaIndex = nil
        playerTable[0].targetActNum = nil

        if playerTable[0].warpTimer == 0 then
            playerTable[0].warping = false
        end
    else
        if playerTable[0].targetPosX and playerTable[0].targetPosY and playerTable[0].targetPosZ then
            m.pos.x = playerTable[0].targetPosX
            m.pos.y = playerTable[0].targetPosY
            m.pos.z = playerTable[0].targetPosZ
            play_sound(SOUND_GENERAL_PAINTING_EJECT, m.marioObj.header.gfx.cameraToObject)

            if not playerTable[0].targetedForSwap then
                swapCooldown = globalTable.startSwapCooldown
                soft_reset_camera(m.area.camera)
            end
        end
        playerTable[0].targetPosX = nil
        playerTable[0].targetPosY = nil
        playerTable[0].targetPosZ = nil
    end
end

---@param idx integer
function setWarping(idx)
    playerTable[idx].warping = true
    playerTable[idx].warpTimer = 10
end

---@param np1 NetworkPlayer
---@param np2 NetworkPlayer
function setTargetedAreas(np1, np2)

    playerTable[np1.localIndex].targetLevelNum = np2.currLevelNum
    playerTable[np1.localIndex].targetAreaIndex = np2.currAreaIndex
    playerTable[np1.localIndex].targetActNum = np2.currActNum

    playerTable[np2.localIndex].targetLevelNum = np1.currLevelNum
    playerTable[np2.localIndex].targetAreaIndex = np1.currAreaIndex
    playerTable[np2.localIndex].targetActNum = np1.currActNum
end

--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hook Functions -----------------------------------------------------------------------------------------------------------------------

function update()
    if swapCooldown > 0 then
        swapCooldown = swapCooldown - 1
    end

    if playerTable[0].warpTimer > 0 then
        playerTable[0].warpTimer = playerTable[0].warpTimer - 1
    end

    if playerTable[0].targetedCooldown > 0 then
        playerTable[0].targetedCooldown = playerTable[0].targetedCooldown - 1
    end
end

---@param m MarioState
function mario_update(m)

    if m.playerIndex ~= 0 then return end

    if playerTable[0].targetedByIdx then
        local targetedByIdx = getLocalIdxFromGlobal(playerTable[0].targetedByIdx)
        if targetedByIdx ~= -1 then
            setWarping(targetedByIdx)
            playerTable[targetedByIdx].targetPosX = m.pos.x
            playerTable[targetedByIdx].targetPosY = m.pos.y
            playerTable[targetedByIdx].targetPosZ = m.pos.z
        end
        playerTable[0].targetedByIdx = nil
        return
    end

    handleSwap(m)

    if playerTable[0].targetedForSwap and playerTable[0].targetedCooldown == 0 then
        playerTable[0].targetedForSwap = false
    end

    if mhExists and getTeam(0) == 0 and not globalTable.everyoneCanSwap then return end

    moveListPos(m)

    if m.controller.buttonPressed & X_BUTTON ~= 0 then

        if selectedPlayerIdx == -1 or swapCooldown > 0 or m.action & ACT_GROUP_CUTSCENE ~= 0 or
        playerTable[0].targetedCooldown > 30 or playerTable[0].warping then
            play_sound(SOUND_MENU_CAMERA_BUZZ, m.marioObj.header.gfx.cameraToObject)
            return
        end

        local sm = states[selectedPlayerIdx]
        local smIdx = sm.playerIndex

        if not playerTable[smIdx].targetedForSwap then

            playerTable[smIdx].targetedForSwap = true
            playerTable[smIdx].targetedCooldown = 60

            playerTable[smIdx].targetPosX = m.pos.x
            playerTable[smIdx].targetPosY = m.pos.y
            playerTable[smIdx].targetPosZ = m.pos.z

            if playersInSameArea(0, smIdx) then
                playerTable[0].targetPosX = sm.pos.x
                playerTable[0].targetPosY = sm.pos.y
                playerTable[0].targetPosZ = sm.pos.z
            else
                playerTable[smIdx].targetedByIdx = nps[0].globalIndex
                setTargetedAreas(nps[0], nps[smIdx])

                setWarping(smIdx)
            end
        else
            popup("Someone just swapped positions with this player.", 1)
        end
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_UPDATE, update)
hookEvent(HOOK_MARIO_UPDATE, mario_update)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------
