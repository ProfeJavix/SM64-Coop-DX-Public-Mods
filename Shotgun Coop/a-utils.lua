local smlua_model_util_get_id = smlua_model_util_get_id
local spawn_sync_object = spawn_sync_object
local network_send_object = network_send_object
local sins = sins
local coss = coss
local insert = table.insert
local random = math.random
local degrees_to_sm64 = degrees_to_sm64
local passes_pvp_interaction_checks = passes_pvp_interaction_checks
local nearest_mario_state_to_object = nearest_mario_state_to_object
local set_mario_action = set_mario_action
local obj_get_nearest_object_with_behavior_id = obj_get_nearest_object_with_behavior_id
local collision_find_surface_on_ray = collision_find_surface_on_ray
local obj_is_valid_for_interaction = obj_is_valid_for_interaction
local obj_check_hitbox_overlap = obj_check_hitbox_overlap
local spawn_mist_particles_with_sound = spawn_mist_particles_with_sound
local spawn_triangle_break_particles = spawn_triangle_break_particles
local play_sound = play_sound
local get_behavior_from_id = get_behavior_from_id

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable

E_MODEL_SHOTGUN = smlua_model_util_get_id('shotgun_geo')
E_MODEL_BULLET = smlua_model_util_get_id('bullet_geo')

shotgunObjs = {}
for i = 0, MAX_PLAYERS - 1 do
    shotgunObjs[i] = nil
end

ACT_FLAG_SG_NOT_ALLOWED = (ACT_GROUP_CUTSCENE | ACT_FLAG_SWIMMING_OR_FLYING | ACT_FLAG_RIDING_SHELL | ACT_FLAG_ON_POLE | ACT_FLAG_HANGING)

BULLET_DMG_LOW = 2
BULLET_DMG_MEDIUM = 4
BULLET_DMG_HUGE = 8

DT_DEFAULT = 0
DT_TRIANGLE = 1
DT_EXPLOSION = 2

local function mario_sf(o, bullet, owner, dmg)
    local nm = nearest_mario_state_to_object(bullet)
    if shouldHitPlayer(owner, nm) then
        set_mario_action(nm, ACT_BACKWARD_GROUND_KB, 0)
        nm.hurtCounter = dmg * 4
        nm.invincTimer = 60
        return true, false
    end
    return false, false
end

local function boo_sf(o, bullet, owner, dmg)
    if o.oBooTargetOpacity < 0xFF then
        return false, false
    end

    o.oInteractStatus = INT_STATUS_INTERACTED | INT_STATUS_WAS_ATTACKED | ATTACK_GROUND_POUND_OR_TWIRL
    return true, true
end

local function bowser_body_anchor_sf(o, _, _, _)
    o = o.parentObj
    if o and o.oAction == 14 and random() < 0.8 then
        o.oAction = 1
    end
    return true, true
end

local function whomp_king_boss_sf(o, _, _, _)
    if o.oAction == 2 then --make him fall only during the battle
        o.oAction = 3
    end

    return true, false
end

SG_AFFECTABLE_TARGETS = {
    {id = id_bhvMario, specificFunc = mario_sf},
    {id = id_bhvCirclingAmp, forceDeleteType = DT_DEFAULT},
    {id = id_bhvBalconyBigBoo, specificFunc = boo_sf},
    {id = id_bhvBigBully},
    {id = id_bhvBigBullyWithMinions},
    {id = id_bhvBigChillBully},
    {id = id_bhvBobomb},
    {id = id_bhvBobombBuddy, forceDeleteType = DT_EXPLOSION, dmgToAffect = BULLET_DMG_LOW},
    {id = id_bhvBoo, specificFunc = boo_sf},
    {id = id_bhvBooWithCage, specificFunc = boo_sf},
    {id = id_bhvBowserBodyAnchor, dmgToAffect = BULLET_DMG_LOW, specificFunc = bowser_body_anchor_sf},
    {id = id_bhvBreakableBox},
    {id = id_bhvBreakableBoxSmall},
    {id = id_bhvChainChomp},
    {id = id_bhvChuckya},
    {id = id_bhvDoor, forceDeleteType = DT_TRIANGLE, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvEnemyLakitu},
    {id = id_bhvExclamationBox},
    {id = id_bhvEyerokHand},
    {id = id_bhvFirePiranhaPlant},
    {id = id_bhvFlyGuy},
    {id = id_bhvFlyingBookend},
    {id = id_bhvGhostHuntBigBoo, specificFunc = boo_sf},
    {id = id_bhvGhostHuntBoo, specificFunc = boo_sf},
    {id = id_bhvGoomba},
    {id = id_bhvHauntedChair},
    {id = id_bhvHeaveHo, forceDeleteType = DT_TRIANGLE, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvHomingAmp, forceDeleteType = DT_DEFAULT},
    {id = id_bhvJrbSlidingBox, forceDeleteType = DT_TRIANGLE},
    {id = id_bhvKingBobomb, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvKlepto},
    {id = id_bhvKoopa},
    {id = id_bhvLargeBomp, forceDeleteType = DT_TRIANGLE, isSurface = true, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvMadPiano, forceDeleteType = DT_TRIANGLE, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvMerryGoRoundBigBoo, specificFunc = boo_sf},
    {id = id_bhvMerryGoRoundBoo, specificFunc = boo_sf},
    {id = id_bhvMessagePanel, forceDeleteType = DT_TRIANGLE},
    {id = id_bhvMips, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvMoneybag},
    {id = id_bhvMontyMole},
    {id = id_bhvMrBlizzard, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvMrI, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvPenguinBaby, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_LOW},
    {id = id_bhvPiranhaPlant},
    {id = id_bhvPokey},
    {id = id_bhvPokeyBodyPart},
    {id = id_bhvRacingPenguin, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_LOW},
    {id = id_bhvScuttlebug},
    {id = id_bhvSkeeter},
    {id = id_bhvSLWalkingPenguin, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvSmallBomp, forceDeleteType = DT_TRIANGLE, isSurface = true, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvSmallBully},
    {id = id_bhvSmallChillBully},
    {id = id_bhvSmallChillBully},
    {id = id_bhvSmallPenguin, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_LOW},
    {id = id_bhvSmallWhomp, forceDeleteType = DT_TRIANGLE, isSurface = true, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvSnufit},
    {id = id_bhvSpindrift},
    {id = id_bhvSpiny, forceDeleteType = DT_DEFAULT},
    {id = id_bhvStarDoor, forceDeleteType = DT_TRIANGLE, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvSwoop},
    {id = id_bhvThwomp, forceDeleteType = DT_TRIANGLE, isSurface = true, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvThwomp2, forceDeleteType = DT_TRIANGLE, isSurface = true, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvToadMessage, forceDeleteType = DT_DEFAULT},
    {id = id_bhvToxBox, forceDeleteType = DT_TRIANGLE, isSurface = true, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvTree, forceDeleteType = DT_TRIANGLE, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvTuxiesMother, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_MEDIUM},
    {id = id_bhvUkiki, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_HUGE},
    {id = id_bhvWhompKingBoss, isSurface = true, dmgToAffect = BULLET_DMG_MEDIUM, specificFunc = whomp_king_boss_sf},
    {id = id_bhvWigglerBody},
    {id = id_bhvWigglerHead, attType = ATTACK_FROM_ABOVE},
    {id = id_bhvYoshi, forceDeleteType = DT_DEFAULT, dmgToAffect = BULLET_DMG_HUGE}
}
--#region MH Stuff ----------------------------------------------------------------------------------------------------

getTeam = function (_) return 0 end
allowPvpAttack = function (_, _) return gServerSettings.playerInteractions == PLAYER_INTERACTIONS_PVP end

if _G.mhExists then
    getTeam = _G.mhApi.getTeam
    allowPvpAttack = _G.mhApi.pvpIsValid
end
--#endregion ----------------------------------------------------------------------------------------------------------

---@param cond boolean
---@param ifTrue any
---@param ifFalse any
---@return any
function ternary(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    else
        return ifFalse
    end
end

---@param a number
---@param b number
---@param t number
---@return number
function lerp(a, b, t)
    return a * (1 - t) + b * t
end

---@param idx1 integer
---@param idx2 integer
function playersInSameArea(idx1, idx2)
    local np1, np2 = nps[idx1], nps[idx2]
    return (np1.currActNum == np2.currActNum and
    np1.currCourseNum == np2.currCourseNum and
    np1.currLevelNum == np2.currLevelNum and
    np1.currAreaIndex == np2.currAreaIndex)
end

---@param globalIdx integer
---@return integer
function getLocalFromGlobalIdx(globalIdx)
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == globalIdx then
            return i
        end
    end
    return -1
end

---@param index integer
---@return boolean
function shouldHaveSGForLocal(index)

    local allowForMHTeam = globalTable.mhTeamWithSG

    return nps[index].connected and
    nps[index].currAreaSyncValid and
    playersInSameArea(0, index) and
    (allowForMHTeam == 2 or getTeam(index) == allowForMHTeam)
end

---@param o Object
---@param length number | nil
---@return Vec3f
function getSGPos(o, length)

    local yaw, pitch = o.oFaceAngleYaw, o.oFaceAnglePitch
    length = length or 0

    return {
        x = o.oPosX + length * sins(yaw) * coss(pitch),
        y = o.oPosY - length * sins(pitch),
        z = o.oPosZ + length * coss(yaw) * coss(pitch)
    }
end

---@param m MarioState
---@param bulletAmount integer
---@param bulletDamage integer
---@param aimDown boolean | nil
function shootShotgun(m, bulletAmount, bulletDamage, aimDown)

    if m.playerIndex ~= 0 then return end

    aimDown = aimDown or false

    local o = shotgunObjs[0]

    local mainYaw, mainPitch = o.oFaceAngleYaw, ternary(aimDown, 0x4000, o.oFaceAnglePitch)

    local angles = {}

    insert(angles, {yaw = mainYaw, pitch = mainPitch})

    for _ = 1, bulletAmount - 1 do
        local dYaw = random(-2, 2)
        local dPitch = random(-2, 2)

        local angle = {
            yaw = mainYaw + degrees_to_sm64(dYaw),
            pitch = mainPitch + degrees_to_sm64(dPitch)
        }

        insert(angles, angle)
    end

    local pos = {
        x = m.pos.x,
        y = m.pos.y + 50,
        z = m.pos.z
    }

    for i = 1, #angles do
        ---@param o Object
        local bullet = spawn_sync_object(id_bhvMHShotgunShell, E_MODEL_BULLET, pos.x, pos.y, pos.z, function(o)
            o.oBulletOwner = nps[m.playerIndex].globalIndex
            o.oBulletDamage = bulletDamage
            o.oMoveAngleYaw = angles[i].yaw
            o.oMoveAnglePitch = angles[i].pitch
        end)
        network_send_object(bullet, true)
    end
end

---@param owner MarioState
---@param target MarioState
---@return boolean
function shouldHitPlayer(owner, target)
    if not owner or not target or owner.playerIndex == target.playerIndex or
    passes_pvp_interaction_checks(owner, target) == 0 then
        return false
    end

    return allowPvpAttack(states[owner.playerIndex], states[target.playerIndex])
end

---@param o Object
---@return Object | nil, table | nil
function detectCollidedTarget(o)

    for _, data in ipairs(SG_AFFECTABLE_TARGETS) do
        local id = data.id
        local obj = obj_get_nearest_object_with_behavior_id(o, id)
        
        if obj then
            if data.isSurface then
                local endPos = {
                    x = o.oPosX + 50 * sins(o.oMoveAngleYaw) * coss(o.oMoveAnglePitch),
                    y = o.oPosY - 50 * sins(o.oMoveAnglePitch),
                    z = o.oPosZ + 50 * coss(o.oMoveAngleYaw) * coss(o.oMoveAnglePitch)
                }
                local rayInfo = collision_find_surface_on_ray(o.oPosX, o.oPosY, o.oPosZ, endPos.x, endPos.y, endPos.z, 0.001)
                if (rayInfo.surface and rayInfo.surface.object == obj) or o.platform == obj then
                    return obj, data
                end
            elseif obj_is_valid_for_interaction(obj) and (obj_check_hitbox_overlap(o, obj) or o.platform == o) then
                return obj, data
            end
        end

        if get_behavior_from_id(id) == get_behavior_from_id(id_bhvMario) and not globalTable.sgDamagesMobs then
            return
        end
    end
end

---@param forceType integer
---@param o Object
---@param m MarioState
function spawnForceDelParticles(forceType, o, m)
    if forceType == DT_DEFAULT then
        local sound = o.oDeathSound
        if sound == 0 then
            sound = SOUND_OBJ_DEFAULT_DEATH
        end
        spawn_mist_particles_with_sound(sound)
    elseif forceType == DT_TRIANGLE then
        spawn_triangle_break_particles(30, 138, 3, 4)
        play_sound(SOUND_GENERAL_BREAK_BOX, {x = o.oPosX, y = o.oPosY, z = o.oPosZ})
    elseif forceType == DT_EXPLOSION then
        if m.playerIndex == 0 then
            spawn_sync_object(id_bhvExplosion, E_MODEL_EXPLOSION, o.oPosX, o.oPosY, o.oPosZ, function()end)
        end
    end
end

---@param o Object
function syncObj(o)
    if o.oSyncID ~= 0 and o.activeFlags & ACTIVE_FLAG_DEACTIVATED == 0 then
        network_send_object(o, false)
    end
end