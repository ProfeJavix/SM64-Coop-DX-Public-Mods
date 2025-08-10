---Returns if the local player has a shotgun or not
---@param playerIndex any
---@return boolean
local function hasShotgun(playerIndex)
    return shouldHaveSGForLocal(playerIndex)
end

--#region Damage Values -----------------------------------------------------------------------------------------------

--Low Damage is used in normal shoots. (index = 0)
--Medium Damage is used in charged shoots and normal ground pound shoots. (index = 1)
--Huge Damage is used in charged ground pound shoots. (index = 2)

---@param dmgIndex integer
local function getBulletDamage(dmgIndex)
    if dmgIndex == 0 then
        return BULLET_DMG_LOW
    elseif dmgIndex == 1 then
        return BULLET_DMG_MEDIUM
    elseif dmgIndex == 2 then
        return BULLET_DMG_HUGE
    end

    return -1
end

---@param dmgIndex integer
---@param newValue integer
local function setBulletDamage(dmgIndex, newValue)
    if dmgIndex == 0 then
        BULLET_DMG_LOW = newValue
    elseif dmgIndex == 1 then
        BULLET_DMG_MEDIUM = newValue
    elseif dmgIndex == 2 then
        BULLET_DMG_HUGE = newValue
    end
end
--#endregion ----------------------------------------------------------------------------------------------------------

--#region Behaviors ---------------------------------------------------------------------------------------------------

--[[
Shotgun bullets won't only affect other players, but also some enemies. You can make it work with your custom enemy or
even change the behavior with the existing ones.

Recommended to use right after you hook your behaviors

Here are the current fields for a MobData table arg (ignore the ones you don't need):
-attType: integer (force an attack to be received by the mob when hit. Ex: ATTACK_FROM_ABOVE)
-dmgToAffect: integer (minimum bullet damage to get damaged)
-forceDeleteType: integer (force deletion if your mob don't die with Mario interactions. 0: spawn smoke | 1: spawn break triangles | 2: spawn explosion)
-isSurface: boolean (if your mob has a surface instead of a hitbox, like whomps)
-specificFunc: function(target, bullet, owner, dmg) (read below)

If you also need a specific behavior you can use the specificFunc field:
---@param target Object
---@param bullet Object
---@param owner MarioState
---@param dmg integer
---@return boolean, boolean
function specificFunc(target, bullet, owner, dmg)
    return canAffectLogic, shouldSyncObj
end
]]

---Insert or replace the behavior of an object when hit by the shotgun. The data table can be empty or nil.
---@param bhvId BehaviorId
---@param data table
local function defineBhvForShotgun(bhvId, data)
    data = data or {}
    data.id = bhvId
    local bhv = get_behavior_from_id(bhvId)
    for index, val in ipairs(SG_AFFECTABLE_TARGETS) do
        if val.id == bhvId or get_behavior_from_id(val.id) == bhv then
            SG_AFFECTABLE_TARGETS[index] = data
            return
        end
    end
    table.insert(SG_AFFECTABLE_TARGETS, data)
end
--#endregion ----------------------------------------------------------------------------------------------------------

_G.coopSGExists = true
_G.coopSGAPI = {
    has_shotgun = hasShotgun,
    get_bullet_dmg = getBulletDamage,
    set_bullet_dmg = setBulletDamage,
    define_bhv_for_shotgun = defineBhvForShotgun
}
