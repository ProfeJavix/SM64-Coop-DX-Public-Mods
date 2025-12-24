-- name: [MH] Freeze Tag v1.0
-- description: Runners can cast a frostbite to freeze hunters if they collect enough coins. Frozen hunters can be saved by teammates or will have to wait for the ice to melt. Simple and fun!\n\nMade by \\#333\\Profe\\#ff0\\Javix

if not _G.mhExists then return end

--#region Localizations ---------------------------------------------------------------------

local hook_event = hook_event
local require = require

--#endregion --------------------------------------------------------------------------------

require('src/utils')
require('src/defs')
local hooks = require('src/hooks')

hook_event(HOOK_UPDATE, hooks.update)
hook_event(HOOK_MARIO_UPDATE, hooks.mario_update)
hook_event(HOOK_ALLOW_FORCE_WATER_ACTION, hooks.allow_force_water_action)
hook_event(HOOK_ON_INTERACT, hooks.on_interact)
hook_event(HOOK_ON_HUD_RENDER, hooks.on_hud_render)