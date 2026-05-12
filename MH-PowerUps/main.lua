-- name: (MH) Powerups v1.2.1
-- description: This mod adds some PvP powerups to make the gameplay more chaotic. Some of the powerups concepts were inspired on the Arena mod.\n\nBest played with MarioHunt.\n\nMade by \\#333\\Profe\\#ff0\\Javix
--#region Localizations ---------------------------------------------------------------------

local coss = coss
local get_id_from_behavior = get_id_from_behavior
local hook_event = hook_event
local ipairs = ipairs
local lateral_dist_between_objects = lateral_dist_between_objects
local network_player_reset_override_palette = network_player_reset_override_palette
local network_player_set_override_palette_color = network_player_set_override_palette_color
local obj_angle_to_object = obj_angle_to_object
local obj_get_first_with_behavior_id = obj_get_first_with_behavior_id
local obj_get_next = obj_get_next
local obj_mark_for_deletion = obj_mark_for_deletion
local play_sound = play_sound
local set_first_person_enabled = set_first_person_enabled
local set_mario_action = set_mario_action
local sins = sins

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local states = gMarioStates
local globalTable = gGlobalSyncTable
local playerTable = gPlayerSyncTable

--#region Globals --------------------------------------------------------------------------------------------------------
globalTable.randomPowerups = false
globalTable.powerUpStartTimer = 300
globalTable.powerUpsForHunters = true

playerTable[0].powerUpTimer = 0
playerTable[0].changePowerup = false
playerTable[0].powerUp = 0
playerTable[0].blockMovesTimer = 0
playerTable[0].toggleRandomPowerups = false
--#endregion -------------------------------------------------------------------------------------------------------------

--#region Hook Utils -----------------------------------------------------------------------------------------------------

---@param m MarioState
function handleHammer(m)
	if playerTable[m.playerIndex].powerUp ~= HAMMER then return end

	local playBonk = false
	local gpParalize = true
	local ignorePlayersToParalize = {
		[m.playerIndex] = true
	}

	local hammer = m.usedObj
	local curPos = { x = hammer.oPosX, y = hammer.oPosY, z = hammer.oPosZ}
	objSetVec3fPos(hammer, getHammerPos(m.pos, hammer.oFaceAngleYaw))

	local marios = puHitObject(hammer, true)
	if hammer.oInteractStatus == INT_STATUS_INTERACTED then
		for _, nm in ipairs(marios) do
			local dmg = 0
			local hit = false
			local squish = false

			ignorePlayersToParalize[nm.playerIndex] = true

			if m.action == ACT_HAMMER_SWING then
				dmg = 8
			elseif m.action == ACT_HAMMER_360 and m.actionState < 2 then
				dmg = 16
			elseif m.action == ACT_HAMMER_GROUND_POUND or m.action == ACT_HAMMER_DIVE_GROUND_POUND then
				dmg = 12
				if nm.floorHeight >= nm.pos.y then
					squish = true
					dmg = 16
				end
				gpParalize = false
			end

			local kbLateralMult = 40
			local kbY = 50
			if nm.flags & MARIO_METAL_CAP ~= 0 then
				dmg = 0
				squish = false
				kbLateralMult = 20
				kbY = 20
			end

			if squish then
				nm.squishTimer = 50
			else
				set_mario_action(nm, ACT_BACKWARD_AIR_KB, 0)
			end

			local kbAngle = obj_angle_to_object(m.marioObj, nm.marioObj)
			nm.faceAngle.y = obj_angle_to_object(nm.marioObj, m.marioObj)


			nm.vel.y = kbY
			nm.vel.x = kbLateralMult * sins(kbAngle)
			nm.vel.z = kbLateralMult * coss(kbAngle)

			nm.knockbackTimer = 20
			nm.invincTimer = ternary(squish, 60, 30)
			nm.hurtCounter = dmg

			playBonk = true
		end
	end

	objSetVec3fPos(hammer, curPos)

	if playBonk then
		play_sound(SOUND_OBJ_POUNDING_LOUD, m.pos)
	end

	if (m.action == ACT_HAMMER_GROUND_POUND or m.action == ACT_HAMMER_DIVE_GROUND_POUND) and
	gpParalize and m.floorHeight == m.pos.y then
		for i = 0, MAX_PLAYERS - 1 do
			local mi = states[i]
			if not ignorePlayersToParalize[i] and
			mi.pos.y == mi.floorHeight and
			lateral_dist_between_objects(mi.marioObj, m.marioObj) <= 1000 then
				set_mario_action(mi, ACT_SHOCKWAVE_BOUNCE, 0)
			end
		end
	end
end

---@param m MarioState
function handleFireballLook(m)

	local np = nps[m.playerIndex]

	if playerTable[m.playerIndex].powerUp ~= FIREFLOWER then
		network_player_reset_override_palette(np)
		return
	end

	local palette = FIREFLOWER_RECOLOR_PARTS[m.character.type]
	for i = 0, PLAYER_PART_MAX - 1 do
		if not palette then break end

		local color = palette[i]
		if color then
			network_player_set_override_palette_color(np, i, color)
		end
	end
end

---@param m MarioState
---@param type integer
function handlePowerupMoves(m, type)

	if playerTable[m.playerIndex].blockMovesTimer ~= 0 or
	m.action & (ACT_FLAG_ATTACKING | ACT_GROUP_CUTSCENE | ACT_FLAG_SWIMMING_OR_FLYING) ~= 0 then return end

	local b = m.controller.buttonPressed

	if type == HAMMER then
		if m.action & ACT_FLAG_AIR == 0 then
			if b & X_BUTTON ~= 0 then
				set_mario_action(m, ACT_HAMMER_360, 0)
			elseif b & Y_BUTTON ~= 0 then
				set_mario_action(m, ACT_HAMMER_SWING, 0)
			end
		else
			if b & X_BUTTON ~= 0 then
				set_mario_action(m, ACT_HAMMER_GROUND_POUND, 0)
			elseif b & Y_BUTTON ~= 0 then
				set_mario_action(m, ACT_HAMMER_DIVE_GROUND_POUND, 0)
			end
		end
	elseif type == FIREFLOWER then

		if b & Y_BUTTON ~= 0 then
			set_mario_action(m, ACT_FIREBALL_SHOOT, 0)
		elseif b & X_BUTTON ~= 0 then

			if m.action & ACT_FLAG_AIR == 0 then
				set_mario_action(m, ACT_FIREBALL_TRIPLE_SHOOT, 0)
			else
				set_mario_action(m, ACT_FIREBALL_TWIRL_SHOOTING, 0)
			end
		end
	elseif type == CANNON then

		if b & Y_BUTTON ~= 0 then
			set_mario_action(m, ACT_CANNON_SHOOT, ternary(m.action & ACT_FLAG_AIR ~= 0, 1, 0))
		elseif m.floorHeight == m.pos.y and b & U_JPAD ~= 0 then
			playerTable[m.playerIndex].blockMovesTimer = 20
			set_mario_action(m, ACT_CANNON_FIRST_PERSON, 0)
		end
	elseif type == BOOMERANG then

		if not m.usedObj or m.usedObj.oAction ~= 0 or m.action & ACT_FLAG_AIR ~= 0 then return end

		if b & Y_BUTTON ~= 0 then
			set_mario_action(m, ACT_BOOMERANG_THROW, 0)
		elseif b & X_BUTTON ~= 0 then
			set_mario_action(m, ACT_BOOMERANG_360_THROW, 0)
		elseif b & U_JPAD ~= 0 then
			playerTable[m.playerIndex].blockMovesTimer = 15
			set_mario_action(m, ACT_BOOMERANG_FIRST_PERSON, 0)
		end
	end
end
--#endregion -------------------------------------------------------------------------------------------------------------

--#region Hook Funcs -----------------------------------------------------------------------------------------------------

function update()
	if playerTable[0].powerUpTimer > 0 then
		playerTable[0].powerUpTimer = playerTable[0].powerUpTimer - 1
	end
	if playerTable[0].blockMovesTimer > 0 then
		playerTable[0].blockMovesTimer = playerTable[0].blockMovesTimer - 1
	end
end

---@param m MarioState
function before_mario_update(m)
	
	local pu = playerTable[m.playerIndex].powerUp

	if pu ~= 0 and ((not playerTable[m.playerIndex].changePowerup and
	playerTable[m.playerIndex].powerUpTimer and playerTable[m.playerIndex].powerUpTimer == 0) or
	(getTeam(m.playerIndex) == 0 and not globalTable.powerUpsForHunters)) and
	m.action & ACT_GROUP_CUTSCENE == 0 then
		if pu == FIREFLOWER then
			network_player_reset_override_palette(nps[m.playerIndex])
		end
		if m.playerIndex == 0 then
			set_first_person_enabled(false)
		end
		playerTable[m.playerIndex].powerUp = 0
		m.usedObj = nil
		m.invincTimer = 20
		set_mario_action(m, ACT_WALKING, 0)
		play_sound(SOUND_MENU_ENTER_PIPE, m.pos)
		return
	end

	if m.playerIndex ~= 0 then return end

	if playerTable[0].toggleRandomPowerups then

		if nps[0].currAreaSyncValid and localPlayerHasLowestIndexInArea() then
			local puObj = obj_get_first_with_behavior_id(id_bhvPowerup)
			while puObj do
				if get_id_from_behavior(puObj.behavior) == id_bhvPowerup then
					obj_mark_for_deletion(puObj)
				end
				puObj = obj_get_next(puObj)
			end

			spawnLocalPowerups()
		end
		playerTable[0].toggleRandomPowerups = false
	end
	
	if playerTable[0].changePowerup and m.action & ACT_GROUP_CUTSCENE == 0 then

		if pu ~= 0 and not POWERUP_DATA[pu] then
			playerTable[0].powerUp = 0
		end
		m.usedObj = nil
		playerTable[0].changePowerup = false
		playerTable[0].powerUpTimer = globalTable.powerUpStartTimer
	end

	if nps[0].currAreaSyncValid and pu ~= 0 and (not m.usedObj or m.usedObj.activeFlags & ACTIVE_FLAG_DEACTIVATED ~= 0) then
		spawnHeldItem(m, pu)
	end
end

---@param m MarioState
function mario_update(m)
	local pu = playerTable[m.playerIndex].powerUp
	if not pu or pu == 0 or not POWERUP_MOVES[pu] then return end

	handleFireballLook(m)

	if POWERUP_MOVES[pu][m.action] then
		handleHammer(m)
	else
		handlePowerupMoves(m, pu)
	end
end

---@param m MarioState
---@param o Object
---@param intType integer
---@return boolean
function on_allow_interact(m, o, intType)
	local pu = playerTable[m.playerIndex].powerUp
	if pu ~= 0 and (intType == INTERACT_CAP or (intType == INTERACT_FLAME and pu == FIREFLOWER)) then
		return false
	end

	return mhAllowInteract(m, o, intType)
end

function on_sync_valid()

	states[0].usedObj = nil
	
	if localPlayerIsAloneInArea() then
		spawnLocalPowerups()
	end
end

---@param m MarioState
---@param incAction integer
function before_set_mario_action(m, incAction)
	local pu = playerTable[m.playerIndex].powerUp

	if incAction == ACT_WALKING and (pu == HAMMER or pu == CANNON) then
		m.faceAngle.x = 0
		m.faceAngle.z = 0
	end

	if m.playerIndex == 0 and m.action == ACT_CANNON_SHOOT and incAction ~= ACT_CANNON_FIRST_PERSON then
		set_first_person_enabled(false)
	end

end

---@param m MarioState
function on_death(m)
	playerTable[m.playerIndex].powerUpTimer = 0
end
--#endregion -------------------------------------------------------------------------------------------------------------

--#region Hooks ----------------------------------------------------------------------------------------------------------
hook_event(HOOK_UPDATE, update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_ALLOW_INTERACT, on_allow_interact)
hook_event(HOOK_ON_SYNC_VALID, on_sync_valid)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action)
hook_event(HOOK_ON_DEATH, on_death)
--#endregion -------------------------------------------------------------------------------------------------------------
