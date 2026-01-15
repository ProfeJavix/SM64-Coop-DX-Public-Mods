---@class Object
---@field oOwner integer

---@class _G
---@field charSelectExists? boolean
---@field charSelect? table

--#region Localizations ---------------------------------------------------------------------

local allocate_mario_action = allocate_mario_action
local cast_graph_node = cast_graph_node
local define_custom_obj_fields = define_custom_obj_fields
local geo_get_current_object = geo_get_current_object
local get_texture_info = get_texture_info
local smlua_model_util_get_id = smlua_model_util_get_id

--#endregion --------------------------------------------------------------------------------

local playerTable = gPlayerSyncTable

for i = 0, MAX_PLAYERS - 1 do
    playerTable[i].shockCooldown = 0
    playerTable[i].smashUpBlocked = false
    playerTable[i].smashDownCooldown = 0
    playerTable[i].smashSideHit = false
end

define_custom_obj_fields({
    oOwner = "s32"
})

E_MODEL_PIKACHU = smlua_model_util_get_id("pikachu_geo")
E_MODEL_THUNDER_SEG = smlua_model_util_get_id('thunder_segment_geo')
E_MODEL_ELECTRO_BALL = smlua_model_util_get_id('electro_ball_geo')
E_MODEL_ELECTRO_PARTICLE = smlua_model_util_get_id('electro_particle_geo')

ACT_SMASH_NORMAL = allocate_mario_action(ACT_FLAG_ATTACKING)
ACT_SMASH_UP = allocate_mario_action(ACT_FLAG_AIR)
ACT_SMASH_DOWN = allocate_mario_action(ACT_FLAG_STATIONARY)
ACT_SMASH_SIDE = allocate_mario_action(ACT_FLAG_ATTACKING)
ACT_TURBO_SHOCKED = allocate_mario_action(ACT_FLAG_INVULNERABLE | ACT_GROUP_AUTOMATIC)

---@param node FnGraphNode|GraphNode
function geo_switch_electro_particle(node, _)
	local gn = cast_graph_node(node)
	local o = geo_get_current_object()

	gn.selectedCase = o.oBehParams2ndByte
end

--#region Char Select ---------------------------------------------------------------------------------------------------------

local TEX_CUSTOM_LIFE_ICON = get_texture_info("pikaicon")

VOICETABLE_PIKACHU = {
    [CHAR_SOUND_ATTACKED] = {'Pika-Hoo.ogg'},
    [CHAR_SOUND_DOH] = {'Pika-Oof.ogg'},
    [CHAR_SOUND_DROWNING] = {'Pika-Die.ogg'},
    [CHAR_SOUND_DYING] = {'Pika-Die.ogg'},
    [CHAR_SOUND_GROUND_POUND_WAH] = {'Pika-Yahoo.ogg'},
    [CHAR_SOUND_HAHA] = {'Pika-We-Go.ogg'},
    [CHAR_SOUND_HAHA_2] = {'Pika-We-Go.ogg'},
    [CHAR_SOUND_HERE_WE_GO] = {'Pika-Wahoo.ogg'},
    [CHAR_SOUND_HOOHOO] = {'Pika-Wah.ogg'},
    [CHAR_SOUND_MAMA_MIA] = {'Pika-Oof.ogg'},
    [CHAR_SOUND_OKEY_DOKEY] = {'Pika-Wahoo.ogg'},
    [CHAR_SOUND_ON_FIRE] = {'Pika-Waaooow.ogg'},
    [CHAR_SOUND_OOOF] = {'Pika-Oof.ogg'},
    [CHAR_SOUND_OOOF2] = {'Pika-Oof.ogg'},
    [CHAR_SOUND_PUNCH_HOO] = {'Pika-Wahoo.ogg'},
    [CHAR_SOUND_PUNCH_WAH] = {'Pika-Wah.ogg'},
    [CHAR_SOUND_PUNCH_YAH] = {'Pika-Wah.ogg'},
    [CHAR_SOUND_SO_LONGA_BOWSER] = {'Pika-Wahoo.ogg'},
    [CHAR_SOUND_TWIRL_BOUNCE] = {'Pika-Wahoo.ogg'},
    [CHAR_SOUND_WAAAOOOW] = {'Pika-Waaooow.ogg'},
    [CHAR_SOUND_WAH2] = {'Pika-Wah.ogg'},
    [CHAR_SOUND_WHOA] = {'Pika-Oof.ogg'},
    [CHAR_SOUND_YAHOO] = {'Pika-Yahoo.ogg'},
    [CHAR_SOUND_YAHOO_WAHA_YIPPEE] = {'Pika-Jump.ogg'},
    [CHAR_SOUND_YAH_WAH_HOO] = {'Pika-Wah.ogg'},
    [CHAR_SOUND_YAWNING] = {'Pika-Yawn.ogg'},
}

--[[ local CAPTABLE_PIKACHU = {
    normal = smlua_model_util_get_id("pikachunormal_geo"),
    wing = smlua_model_util_get_id("pikachuwing_geo"),
    metal = smlua_model_util_get_id("pikachumetal_geo"),
    metalWing = smlua_model_util_get_id("pikachucapwing_geo"),
} ]]

local PALETTE_CHAR = {
    [PANTS]  = "ffffff",
    [SHIRT]  = "ffffff",
    [GLOVES] = "ffffff",
    [SHOES]  = "ffffff",
    [HAIR]   = "ffffff",
    [SKIN]   = "ffffff",
    [CAP]    = "ffffff",
}

CT_PIKACHU = _G.charSelect.character_add(
    "Pikachu",
    {"Pika Pika!"},
    "nessie.",
    {r = 255, g = 200, b = 200},
    E_MODEL_PIKACHU,
    CT_MARIO,
    TEX_CUSTOM_LIFE_ICON
)
--_G.charSelect.character_add_caps(E_MODEL_PIKACHU, CAPTABLE_PIKACHU)
_G.charSelect.character_add_voice(E_MODEL_PIKACHU, VOICETABLE_PIKACHU)
_G.charSelect.character_add_palette_preset(E_MODEL_PIKACHU, PALETTE_CHAR)

--#endregion ----------------------------------------------------------------------------------------------------------------------