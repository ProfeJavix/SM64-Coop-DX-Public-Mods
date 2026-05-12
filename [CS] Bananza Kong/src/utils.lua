--#region Localizations ---------------------------------------------------------------------

local abs_angle_diff = abs_angle_diff
local approach_s16_symmetric = approach_s16_symmetric
local clamp = math.clamp
local cur_obj_become_tangible = cur_obj_become_tangible
local degrees_to_sm64 = degrees_to_sm64
local dist_between_objects = dist_between_objects
local djui_chat_message_create = djui_chat_message_create
local ipairs = ipairs
local is_player_active = is_player_active
local obj_angle_to_object = obj_angle_to_object
local obj_check_hitbox_overlap = obj_check_hitbox_overlap
local obj_get_first = obj_get_first
local obj_get_first_with_behavior_id = obj_get_first_with_behavior_id
local obj_get_nearest_object_with_behavior_id = obj_get_nearest_object_with_behavior_id
local obj_get_next = obj_get_next
local obj_get_next_with_same_behavior_id = obj_get_next_with_same_behavior_id
local obj_has_behavior_id = obj_has_behavior_id
local obj_is_attackable = obj_is_attackable
local obj_is_bully = obj_is_bully
local obj_is_valid_for_interaction = obj_is_valid_for_interaction
local obj_pitch_to_object = obj_pitch_to_object
local s16 = math.s16
local smlua_anim_util_set_animation = smlua_anim_util_set_animation
local tostring = tostring

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable

local lookToBhvs = {
	id_bhvStar,
	id_bhvSpawnedStar,
	id_bhvSpawnedStarNoLevelExit,
	id_bhvStarSpawnCoordinates,
	id_bhvMetalCap,
	id_bhvWingCap,
	id_bhvVanishCap,
	id_bhvBowserKey,
}
---@param m MarioState
---@return Object | nil
function nearestLookTarget(m)
	local o = nil
	local minDist = 750

	for _, bhv in ipairs(lookToBhvs) do
		local curO = obj_get_nearest_object_with_behavior_id(m.marioObj, bhv)

		if curO then
			local this_dist = dist_between_objects(m.marioObj, curO)
			if this_dist < minDist then
				minDist = this_dist
				o = curO
			end
		end
	end

	return o
end

local targetBhvs = {
	id_bhvMario,
	id_bhvBalconyBigBoo,
	id_bhvBigBully,
	id_bhvBigChillBully,
	id_bhvBobomb,
	id_bhvBoo,
	id_bhvBooWithCage,
	id_bhvBowser,
	id_bhvBulletBill,
	id_bhvChainChomp,
	id_bhvChuckya,
	id_bhvEnemyLakitu,
	id_bhvFlyGuy,
	id_bhvFlyingBookend,
	id_bhvGhostHuntBigBoo,
	id_bhvGhostHuntBoo,
	id_bhvGoomba,
	id_bhvHauntedChair,
	id_bhvKoopa,
	id_bhvMerryGoRoundBigBoo,
	id_bhvMerryGoRoundBoo,
	id_bhvMoneybag,
	id_bhvMontyMole,
	id_bhvPiranhaPlant,
	id_bhvPokey,
	id_bhvScuttlebug,
	id_bhvSkeeter,
	id_bhvSmallBully,
	id_bhvSmallChillBully,
	id_bhvSmallPenguin,
	id_bhvSnufit,
	id_bhvSpindrift,
	id_bhvSpiny,
	id_bhvToadMessage,
	id_bhvWigglerBody,
	id_bhvWigglerHead
}

---@param o Object
---@return Object|nil, number
function nearestChunkTarget(o)
	local minDist = 2000
	local target = nil

	for _, id in ipairs(targetBhvs) do
		local curO = obj_get_first_with_behavior_id(id)
		while curO do
			if id ~= id_bhvMario or
			(is_player_active(states[getLocalFromGlobalIdx(curO.globalPlayerIndex)]) ~= 0 and
			curO.globalPlayerIndex ~= o.oChunkOwner) then
				local dist = dist_between_objects(o, curO)
				if dist < minDist and abs_angle_diff(obj_angle_to_object(o, curO), o.oFaceAngleYaw) < 0x2000 then
					minDist = dist
					target = curO
				end
			end

			curO = obj_get_next_with_same_behavior_id(curO)
		end
	end

	return target, minDist
end

---@param o Object
---@return Object | nil
function chunkFindWallObj(o)
	local colData = collision_get_temp_wall_collision_data()

	colData.offsetY = 10
	colData.radius = 150
	colData.x = o.oPosX
	colData.y = o.oPosY
	colData.z = o.oPosZ

	local numCols = find_wall_collisions(colData)
	if numCols ~= 0 then
		local wall = colData.walls[colData.numWalls]
		return wall.object
	end

	return nil
end

---@param o Object
---@return boolean
function chunkHitObject(o)

	cur_obj_become_tangible()

	local wall = chunkFindWallObj(o)

	for _, list in ipairs({ OBJ_LIST_PUSHABLE, OBJ_LIST_GENACTOR, OBJ_LIST_SURFACE }) do
		local curO = obj_get_first(list)
		while curO do
			local hit = false

			if list == OBJ_LIST_SURFACE then
				if o.platform == curO or wall == curO then
					hit = true
					curO.oInteractStatus = (INT_STATUS_WAS_ATTACKED | INT_STATUS_INTERACTED)
				end
			else
				if obj_check_hitbox_overlap(o, curO) then
					if obj_is_attackable(curO) or obj_has_behavior_id(curO, id_bhvChainChomp) ~= 0 and obj_is_valid_for_interaction(curO) then
						curO.oInteractStatus = (ATTACK_PUNCH | INT_STATUS_WAS_ATTACKED | INT_STATUS_INTERACTED | INT_STATUS_TOUCHED_BOB_OMB)
						hit = true
					elseif obj_is_bully(curO) and obj_is_valid_for_interaction(curO) then
						curO.oInteractStatus = ATTACK_KICK_OR_TRIP
						hit = true
					elseif obj_has_behavior_id(curO, id_bhvBowserBodyAnchor) ~= 0 or
						obj_has_behavior_id(curO, id_bhvToadMessage) ~= 0 or
						obj_has_behavior_id(curO, id_bhvSmallPenguin) ~= 0 then
						curO.oEnemyLakituBlinkTimer = 1
						hit = true
					end
				end
			end

			if hit then
				o.oInteractStatus = o.oInteractStatus | INT_STATUS_INTERACTED
				return true
			end

			curO = obj_get_next(curO)
		end
	end

	return false
end

local noLookActs = {
	[ACT_PUTTING_ON_CAP] = true,
	[ACT_START_SLEEPING] = true,
	[ACT_SLEEPING] = true,
	[ACT_WAKING_UP] = true
}

---@param m MarioState
function handleDKLook(m)
	playerTable[m.playerIndex].nearBanana = false

	if noLookActs[m.action] then return end

	local target = nearestLookTarget(m)
	if target then
		local headAngle = m.marioBodyState.headAngle
		if m.action == ACT_IDLE then
			smlua_anim_util_set_animation(m.marioObj, "dk_idlefront")
		end
		m.marioBodyState.allowPartRotation = 1

		local angle = obj_angle_to_object(m.marioObj, target)

		if abs_angle_diff(angle, m.faceAngle.y) <= degrees_to_sm64(105) then
			playerTable[m.playerIndex].nearBanana = true

			local yaw = s16(clamp(angle - m.faceAngle.y, degrees_to_sm64(-70), degrees_to_sm64(70)))

			m.marioObj.oPosY = m.marioObj.oPosY + 120
			local pitch = clamp(obj_pitch_to_object(m.marioObj, target), degrees_to_sm64(-50), degrees_to_sm64(50))
			m.marioObj.oPosY = m.marioObj.oPosY - 120

			headAngle.y = approach_s16_symmetric(headAngle.y, yaw, degrees_to_sm64(12))
			headAngle.x = approach_s16_symmetric(headAngle.x, pitch, degrees_to_sm64(6))
		else
			headAngle.x = approach_s16_symmetric(headAngle.x, 0, degrees_to_sm64(5))
			headAngle.y = approach_s16_symmetric(headAngle.y, 0, degrees_to_sm64(10))
		end
	end
end

function for_each_object_with_behavior(behavior, func)
    --Credit to isaac
	local o = obj_get_first_with_behavior_id(behavior)
	while o do
		func(o)
		o = obj_get_next_with_same_behavior_id(o)
	end
end

---@param idx integer
---@return boolean
function isDK(idx)
	return _G.charSelect.character_get_current_number(idx) == CT_DK
end

---@param m MarioState
---@return boolean
function isHoldingChunk(m)
	return m.heldObj ~= nil and obj_has_behavior_id(m.heldObj, id_bhvHeldChunk) ~= 0
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

---@param cond? boolean
---@param ifTrue any
---@param ifFalse any
function ternary(cond, ifTrue, ifFalse)
	if cond then
		return ifTrue
	else
		return ifFalse
	end
end

return {}