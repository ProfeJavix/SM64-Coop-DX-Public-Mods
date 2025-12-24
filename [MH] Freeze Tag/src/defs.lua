--#region Localizations ---------------------------------------------------------------------

local allocate_mario_action = allocate_mario_action
local define_custom_obj_fields = define_custom_obj_fields
local hook_behavior = hook_behavior
local hook_mario_action = hook_mario_action
local mod_storage_exists = mod_storage_exists
local mod_storage_load_number = mod_storage_load_number
local require = require
local smlua_collision_util_get = smlua_collision_util_get
local smlua_model_util_get_id = smlua_model_util_get_id
local tointeger = math.tointeger

--#endregion --------------------------------------------------------------------------------

local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

globalTable.frozenTimer = tointeger(ternary(mod_storage_exists('frozenTimer'), mod_storage_load_number('frozenTimer'), 150))
globalTable.freezeCooldown = tointeger(ternary(mod_storage_exists('freezeCooldown'), mod_storage_load_number('freezeCooldown'), 300))
globalTable.coinsToFreeze = tointeger(ternary(mod_storage_exists('coinsToFreeze'), mod_storage_load_number('coinsToFreeze'), 20))

for i = 0, MAX_PLAYERS - 1 do
    playerTable[i].coins = 0
    playerTable[i].cooldown = 0
    playerTable[i].hasFrostbite = false
    playerTable[i].freeze = false
end

local loops = require('loops')

E_MODEL_TAG_ICE = smlua_model_util_get_id('ice_geo')
COLLISION_TAG_ICE = smlua_collision_util_get('ice_collision')

E_MODEL_FB_ICON = smlua_model_util_get_id('frostbite_icon_geo')

---@class Object
---@field oOwner integer

---@class _G
---@field mhExists? boolean
---@field mhApi? table

define_custom_obj_fields({
    oOwner = "s32"
})

id_bhvTagIce = hook_behavior(nil, OBJ_LIST_SURFACE, true, loops.bhv_tag_ice_init, loops.bhv_tag_ice_loop)
id_bhvFrostbiteIcon = hook_behavior(nil, OBJ_LIST_GENACTOR, true, loops.bhv_frostbite_icon_init, loops.bhv_frostbite_icon_loop)

ACT_FROZEN = allocate_mario_action(ACT_FLAG_INVULNERABLE | ACT_FLAG_INTANGIBLE)

hook_mario_action(ACT_FROZEN, loops.act_frozen)