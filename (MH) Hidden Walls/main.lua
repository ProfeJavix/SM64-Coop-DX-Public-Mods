-- name: (MH) Hidden Walls v1.1
-- description: One of the teams can create hidden walls. Beware and prepare for the impact!\n\nMade by \\#333\\Profe\\#ff0\\Javix

if not _G.mhExists then return end

--#region Localizations ---------------------------------------------------------------------

local clamp = math.clamp
local hook_event = hook_event
local mod_storage_exists = mod_storage_exists
local mod_storage_load_bool = mod_storage_load_bool
local mod_storage_load_number = mod_storage_load_number
local play_sound = play_sound
local set_camera_shake_from_point = set_camera_shake_from_point
local spawn_sync_object = spawn_sync_object

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local globalTable = gGlobalSyncTable

globalTable.wallTeam = ternary(mod_storage_exists('wallTeam'), mod_storage_load_number('wallTeam'), TEAM_RUNNERS)
globalTable.wallIFrames = ternary(mod_storage_exists('wallIFrames'), mod_storage_load_bool('wallIFrames'), true)
globalTable.wallPlacementCooldown = ternary(mod_storage_exists('wallPlacementCooldown'), mod_storage_load_number('wallPlacementCooldown'), 150)
globalTable.wallDespawnTime = ternary(mod_storage_exists('wallDespawnTime'), mod_storage_load_number('wallDespawnTime'), 240)
globalTable.wallXScale = ternary(mod_storage_exists('wallXScale'), mod_storage_load_number('wallXScale'), 1)
globalTable.wallYScale = ternary(mod_storage_exists('wallYScale'), mod_storage_load_number('wallYScale'), 1)
globalTable.wallZScale = ternary(mod_storage_exists('wallZScale'), mod_storage_load_number('wallZScale'), 1)

function update()
    if cooldown > 0 then
        cooldown = cooldown - 1
    end
end

---@param m MarioState
function mario_update(m)

    if m.playerIndex ~= 0 then return end

    if m.controller.buttonPressed & X_BUTTON ~= 0 then
        showWallPH = not showWallPH
        play_sound(SOUND_MENU_CHANGE_SELECT, gGlobalSoundSource)
    end

    setWallPH(m)

    if canSeeWalls(m) and wallPH and showWallPH then
        if m.controller.buttonPressed & Y_BUTTON ~= 0 then
            if cooldown == 0 then
                cooldown = globalTable.wallPlacementCooldown
                spawn_sync_object(id_bhvInvisibleWall, E_MODEL_INVISIBLE_WALL, wallPH.oPosX, wallPH.oPosY, wallPH.oPosZ,
                    function(wall)
                        wall.oOwner = nps[0].globalIndex
                        wall.oMoveAngleYaw = wallPH.oFaceAngleYaw
                    end
                )
                play_sound(SOUND_MENU_STAR_SOUND, gGlobalSoundSource)
                set_camera_shake_from_point(SHAKE_FOV_SMALL, wallPH.oPosX, wallPH.oPosY, wallPH.oPosZ)
            else
                play_sound(SOUND_MENU_CAMERA_BUZZ, gGlobalSoundSource)
            end
        end

        if cooldown ~= 0 then return end

        if m.controller.buttonDown & U_JPAD ~= 0 then
            curZOffset = curZOffset + 20
        elseif m.controller.buttonDown & D_JPAD ~= 0 then
            curZOffset = curZOffset - 20
        end
        curZOffset = clamp(curZOffset, 100, 1000)

        if m.controller.buttonDown & L_JPAD ~= 0 then
            curYawOffset = curYawOffset - 0x200
        elseif m.controller.buttonDown & R_JPAD ~= 0 then
            curYawOffset = curYawOffset + 0x200
        end

        if m.controller.buttonPressed & L_TRIG ~= 0 then
            curZOffset = 400
            curYawOffset = 0
        end
    end
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_MARIO_UPDATE, mario_update)