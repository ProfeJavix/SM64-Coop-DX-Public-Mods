-- name: \\#f00\\Mob\\#ff0\\Control \\#fff\\v1.1
-- description: This mod allows the players to control most of the vanilla enemies of SM64 and to use their (almost) vanilla moves.\n\nAlso adapted to EmilyEmmi's MarioHunt team mechanics.\n\nThanks to \\#619233\\The Incredible Holc\\#fff\\ for network optimization tips and some cool animation ideas.\n\nThanks to \\#920442\\Los Fantacastasmas\\#fff\\ for all the testing on online functions.\n\nMade by \\#333\\Profe\\#ff0\\Javix

local hookAction = hook_mario_action
local hookEvent = hook_event
local hookCmd = hook_chat_command
local network_is_server = network_is_server
local set_mario_action = set_mario_action
local get_id_from_behavior = get_id_from_behavior
local network_send_object = network_send_object
local distBetObjs = dist_between_objects
local spawn_wind_particles = spawn_wind_particles
local play_sound = play_sound
local object_pos_to_vec3f = object_pos_to_vec3f
local mario_stop_riding_and_holding = mario_stop_riding_and_holding

local nps = gNetworkPlayers
local states = gMarioStates
local playerTable = gPlayerSyncTable
local globalTable = gGlobalSyncTable
local cam = gLakituState

--#region MH Comp. ---------------------------------------------------------------------------------------------------------------------
mhExists = _G.mhExists
getMHTeam = function(_) return 0 end
mhPvpIsValid = function(_, _) return true end
if mhExists then
    getMHTeam = _G.mhApi.getTeam
    mhPvpIsValid = _G.mhApi.pvpIsValid
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Colored Nametags Comp. ---------------------------------------------------------------------------------------------------------------
cnOn = _G.coloredNametagsOn
cnSetNametagVisibility = function(_, _) end
cnSetNametagWorldPos = function(_, _) end
if cnOn then
    cnSetNametagVisibility = _G.coloredNametagsFuncs.set_nametag_visibility
    cnSetNametagWorldPos = _G.coloredNametagsFuncs.set_nametag_world_pos
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Globals ------------------------------------------------------------------------------------------------------------------------------
ACT_CONTROLLING_MOB = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)

nearMobDetected = false
nearMobBhvId = -1

globalTable.allowNametagsInMobs = true
globalTable.allowPowers = true
globalTable.powersRange = 1500
globalTable.controlRange = 800
globalTable.powersCooldownStart = 300

globalTable.mhControlOnlyForHunters = true
globalTable.mhPowersOnlyForHunters = true
globalTable.mhHunterOnlyAttackWithMobs = false

playerTable[0].controlTimer = 0
playerTable[0].powersCooldown = 0
playerTable[0].controlledBhvId = -1
playerTable[0].affectedByVertWindTimer = 0
playerTable[0].affectedByStuckButtTimer = 0
playerTable[0].affectedByShockTimer = 0

if network_is_server() then
    gServerSettings.pauseAnywhere = true
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hook Func Utils ----------------------------------------------------------------------------------------------------------------------

---@param m MarioState
function useColoredNametags(m)

    if cnOn then

        if m.action == ACT_CONTROLLING_MOB and m.usedObj then
            cnSetNametagVisibility(m.playerIndex, globalTable.allowNametagsInMobs)

            local o = m.usedObj
            cnSetNametagWorldPos(m.playerIndex, {x = o.oPosX, y = o.oPosY - o.hitboxDownOffset + o.hitboxHeight + 100, z = o.oPosZ})
        else
            cnSetNametagVisibility(m.playerIndex, true)
            cnSetNametagWorldPos(m.playerIndex, nil)
        end
    end
end

---@param m MarioState
function handlePowers(m)

    if playerTable[m.playerIndex].affectedByVertWindTimer and playerTable[m.playerIndex].affectedByVertWindTimer > 0 then
        spawn_wind_particles(1, 0)
        play_sound(SOUND_ENV_WIND2, m.marioObj.header.gfx.cameraToObject)
        m.vel.y = m.vel.y + 15
        set_mario_action(m, ACT_VERTICAL_WIND, 0)
    end

    if playerTable[0].affectedByStuckButtTimer and playerTable[0].affectedByStuckButtTimer > 0 then
        play_sound(SOUND_OBJ_POUNDING_LOUD, m.marioObj.header.gfx.cameraToObject)
        set_mario_action(m, ACT_BUTT_STUCK_IN_GROUND, 0)
    end

    if playerTable[0].affectedByShockTimer and playerTable[0].affectedByShockTimer > 0 then
        play_sound(SOUND_MOVING_SHOCKED, m.marioObj.header.gfx.cameraToObject)
        set_mario_action(m, ACT_SHOCKED, 0)
    end

    if m.playerIndex ~= 0 or 
    (mhExists and globalTable.mhPowersOnlyForHunters and getMHTeam(0) == 1) or
    m.action == ACT_CONTROLLING_MOB then 
        return 
    end

    if playerTable[0].powersCooldown > 0 then return end

    local nm = nearestAffectableMario(m)
    if nm ~= nil and distBetObjs(m.marioObj, nm.marioObj) <= globalTable.powersRange then
        
        placeFocusPointer(nm.marioObj)

        if m.controller.buttonPressed & L_JPAD ~= 0 then

            local power = spawn_sync_object(id_bhvCustomTweester, E_MODEL_TWEESTER, nm.pos.x, nm.pos.y, nm.pos.z, function(o) o.oPlayerControlling = 1 end)
            network_send_object(power, true)
            playerTable[0].powersCooldown = globalTable.powersCooldownStart

        elseif m.controller.buttonPressed & R_JPAD ~= 0 then

            playerTable[nm.playerIndex].affectedByShockTimer = 1
            playerTable[0].powersCooldown = globalTable.powersCooldownStart

        elseif m.controller.buttonPressed & U_JPAD ~= 0 then

            playerTable[nm.playerIndex].affectedByVertWindTimer = 15
            playerTable[0].powersCooldown = globalTable.powersCooldownStart

        elseif m.controller.buttonPressed & D_JPAD ~= 0 then

            playerTable[nm.playerIndex].affectedByStuckButtTimer = 1
            playerTable[0].powersCooldown = globalTable.powersCooldownStart

        end
    elseif m.controller.buttonPressed & L_JPAD ~= 0 or m.controller.buttonPressed & R_JPAD ~= 0 or m.controller.buttonPressed & U_JPAD ~= 0 then
        play_sound_button_change_blocked()
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Mario Action -------------------------------------------------------------------------------------------------------------------------

---Thanks to Holc for the idea of the jump and the lerp explanation XD
---@param m MarioState
function act_controlling_mob(m)

    if m.usedObj == nil or
    m.usedObj.activeFlags == ACTIVE_FLAG_DEACTIVATED or
    (mhExists and globalTable.mhControlOnlyForHunters and getMHTeam(m.playerIndex) == 1) then
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
        m.squishTimer = 0
        m.invincTimer = 30
        play_sound(SOUND_GENERAL_PAINTING_EJECT, m.marioObj.header.gfx.cameraToObject)
        set_mario_action(m, ACT_IDLE, 0)
        --m.marioObj.hitboxHeight = 160
        --m.marioObj.hitboxRadius = 37
        return false
    end
    
    local state = m.actionState

    if state == 0 then
        set_character_animation(m, CHAR_ANIM_DOUBLE_JUMP_RISE)
        m.pos.y = m.usedObj.oPosY
        m.vel.y = 60
        play_mario_jump_sound(m)
        m.faceAngle.y = obj_angle_to_object(m.marioObj, m.usedObj)
        mario_set_forward_vel(m, 20)
        m.actionState = 1

    elseif state == 1 then

        perform_air_step(m, 0)
        if m.vel.y <= 30 then
            if set_character_animation(m, CHAR_ANIM_FORWARD_SPINNING) == 0 then
                play_sound(SOUND_ACTION_SPIN, m.marioObj.header.gfx.cameraToObject)
            end

            if m.vel.y <= 0 then
                play_sound(SOUND_MENU_STAR_SOUND, m.marioObj.header.gfx.cameraToObject)
                m.actionTimer = 40
                m.actionState = 2
            end
        end

    elseif state == 2 then
        perform_air_step(m, 0)
        set_character_animation(m, CHAR_ANIM_DIVE)
        m.squishTimer = 0xFF

        local timerScale = m.actionTimer / 40
        m.actionTimer = m.actionTimer - 2
        m.pos.x = lerp(m.usedObj.oPosX, m.pos.x, timerScale)
        m.pos.z = lerp(m.usedObj.oPosZ, m.pos.z, timerScale)
        vec3f_set(m.marioObj.header.gfx.scale, timerScale, timerScale, timerScale)
        if timerScale <= 0.15 then
            m.actionState = 3
        end
    else
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags | GRAPH_RENDER_INVISIBLE
        m.squishTimer = 0
        set_mario_animation(m, MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)
        m.pos.x = m.usedObj.oPosX - 10 * sins(m.usedObj.oFaceAngleYaw)
        m.pos.y = m.usedObj.oPosY
        m.pos.z = m.usedObj.oPosZ - 10 * coss(m.usedObj.oFaceAngleYaw)

        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
		
		if m.actionArg == 1 then
            m.pos.y = m.pos.y + 500
            if m.playerIndex == 0 then
                object_pos_to_vec3f(cam.curFocus, m.usedObj)
            end
        end

        --m.marioObj.hitboxHeight = 0
        --m.marioObj.hitboxRadius = 0
    end
end

hookAction(ACT_CONTROLLING_MOB, act_controlling_mob)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hook Functions -----------------------------------------------------------------------------------------------------------------------

function update()

    if playerTable[0].controlTimer > 0 then
        playerTable[0].controlTimer = playerTable[0].controlTimer - 1
    end

    if playerTable[0].powersCooldown > 0 then
        playerTable[0].powersCooldown = playerTable[0].powersCooldown - 1
    end

    if playerTable[0].affectedByVertWindTimer > 0 then
        playerTable[0].affectedByVertWindTimer = playerTable[0].affectedByVertWindTimer - 1
    end

    if playerTable[0].affectedByStuckButtTimer > 0 then
        playerTable[0].affectedByStuckButtTimer = playerTable[0].affectedByStuckButtTimer - 1
    end

    if playerTable[0].affectedByShockTimer > 0 then
        playerTable[0].affectedByShockTimer = playerTable[0].affectedByShockTimer - 1
    end
end

---@param m MarioState
function mario_update(m)

    useColoredNametags(m)

    local localIdx = m.playerIndex

    if globalTable.allowPowers then
        handlePowers(m)
    end

    if localIdx == 0 then
        mario_update_local(m)
    end
end

---@param m MarioState
function mario_update_local(m)
    if m.action ~= ACT_CONTROLLING_MOB then

        playerTable[0].controlledBhvId = -1

        if (mhExists and globalTable.mhControlOnlyForHunters and getMHTeam(0) == 1) then return end

        if playerTable[0].controlTimer > 0 then return end

        local nearestObj = detectNearestAllowedMob(m.pos)
        if nearestObj ~= nil and m.action & ACT_GROUP_CUTSCENE == 0 then
            placeFocusPointer(nearestObj)
            nearMobDetected = true
            nearMobBhvId = get_id_from_behavior(nearestObj.behavior)
            if m.controller.buttonPressed & X_BUTTON ~= 0 then
				mario_stop_riding_and_holding(m)
                m.usedObj = nearestObj
                m.usedObj.oPlayerControlling = nps[0].globalIndex
				sendObj(m.usedObj)
                playerTable[0].controlTimer = 20
                playerTable[0].controlledBhvId = nearMobBhvId
                m.usedObj.oForwardVel = 0
				
				local actArg = 0
				if nearMobBhvId == id_bhvCustomChuckya or nearMobBhvId == id_bhvCustomBowser then
					actArg = 1
				end
                set_mario_action(m, ACT_CONTROLLING_MOB, actArg)
            end
        else
            nearMobDetected = false
            nearMobBhvId = -1
        end
    else
        nearMobDetected = false
        nearMobBhvId = -1
    end
end

---@param attacker MarioState
---@param victim MarioState
function on_allow_pvp_attack(attacker, victim)
    if mhExists and globalTable.mhHunterOnlyAttackWithMobs and getMHTeam(attacker.playerIndex) == 0 then
        return false
    end
    return mhPvpIsValid(attacker, victim)
end

---@param idx integer
---@return string | nil
function on_nametags_render(idx)
    if states[idx].action == ACT_CONTROLLING_MOB then
        return ""
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Chat Functions -----------------------------------------------------------------------------------------------------------------------

---@param msg string
---@return boolean
function spawnMob(msg)

    local mob, model = nil, nil

    local function setupFunc(o)
    end
	
	if msg:lower() == "big boo" then
        mob = id_bhvCustomBalconyBigBoo
        model = E_MODEL_BOO
    elseif msg:lower() == "big bully" then
        mob = id_bhvCustomBigBully
        model = E_MODEL_BULLY_BOSS
    elseif msg:lower() == "big chill bully" then
        mob = id_bhvCustomBigChillBully
        model = E_MODEL_BIG_CHILL_BULLY
    elseif msg:lower() == "bob-omb" then
        mob = id_bhvCustomBobomb
        model = E_MODEL_BLACK_BOBOMB
    elseif msg:lower() == "boo" then
        mob = id_bhvCustomBoo
        model = E_MODEL_BOO
    elseif msg:lower() == "boo with cage" then
        mob = id_bhvCustomBooWithCage
        model = E_MODEL_BOO
    elseif msg:lower() == "bowser" then
        mob = id_bhvCustomBowser
        model = E_MODEL_BOWSER
		setupFunc = function (o)
			o.oAction = 14
		end
    elseif msg:lower() == "chain chomp" then
        mob = id_bhvCustomChainChomp
        model = E_MODEL_CHAIN_CHOMP
    elseif msg:lower() == "chuckya" then
        mob = id_bhvCustomChuckya
        model = E_MODEL_CHUCKYA
    elseif msg:lower() == "fly guy" then
        mob = id_bhvCustomFlyGuy
        model = E_MODEL_FLYGUY
    elseif msg:lower() == "tiny goomba" or msg:lower() == "goomba" or msg:lower() == "huge goomba" then
        mob = id_bhvCustomGoomba
        model = E_MODEL_GOOMBA
        setupFunc = function (o)
            if msg:lower() == "tiny goomba" then
                o.oBehParams2ndByte = 2
                o.oGoombaSize = GOOMBA_SIZE_TINY
                o.oGoombaScale = 0.5
                o.oDeathSound = SOUND_OBJ_ENEMY_DEATH_HIGH
                o.oDrawingDistance = 1500
                o.oDamageOrCoinValue = 0
            elseif msg:lower() == "goomba" then
                o.oBehParams2ndByte = 0
                o.oGoombaSize = GOOMBA_SIZE_REGULAR
                o.oGoombaScale = 1.5
                o.oDeathSound = SOUND_OBJ_ENEMY_DEATH_HIGH
                o.oDrawingDistance = 4000
                o.oDamageOrCoinValue = 1
            else
                o.oBehParams2ndByte = 1
                o.oGoombaSize = GOOMBA_SIZE_HUGE
                o.oGoombaScale = 3.5
                o.oDeathSound = SOUND_OBJ_ENEMY_DEATH_LOW
                o.oDrawingDistance = 4000
                o.oDamageOrCoinValue = 2
            end

            o.oGravity = -8/3 * o.oGoombaScale
            end
    elseif msg:lower() == "king bob-omb" then
        mob = id_bhvCustomKingBobomb
        model = E_MODEL_KING_BOBOMB
    elseif msg:lower() == "king whomp" then
        mob = id_bhvCustomWhompKingBoss
        model = E_MODEL_WHOMP
    elseif msg:lower() == "tiny koopa" or msg:lower() == "koopa" then
        mob = id_bhvCustomKoopa
        model = E_MODEL_KOOPA_WITH_SHELL

        setupFunc = function (o)
            
            o.oBehParams2ndByte = 1
            o.oKoopaMovementType = KOOPA_BP_NORMAL
            if msg:lower() == "tiny koopa" then
                o.oBehParams2ndByte = KOOPA_BP_TINY
                o.oKoopaAgility = 1.6 / 3
                o.oDrawingDistance = 1500
                obj_set_gfx_scale(o, 0.8, 0.8, 0.8)
                o.oGravity = -6.4 / 3
            end
        end
    elseif msg:lower() == "lakitu" then
        mob = id_bhvCustomEnemyLakitu
        model = E_MODEL_ENEMY_LAKITU
    elseif msg:lower() == "mad piano" then
        mob = id_bhvCustomMadPiano
        model = E_MODEL_MAD_PIANO
    elseif msg:lower() == "toad" or msg:lower() == "npc toad" or msg:lower() == "toad message" then
        mob = id_bhvCustomToadMessage
        model = E_MODEL_TOAD
    elseif msg:lower() == "scuttlebug" then
        mob = id_bhvCustomScuttlebug
        model = E_MODEL_SCUTTLEBUG
    elseif msg:lower() == "skeeter" then
        mob = id_bhvCustomSkeeter
        model = E_MODEL_SKEETER
    elseif msg:lower() == "small bully" or msg:lower() == "bully" then
        mob = id_bhvCustomSmallBully
        model = E_MODEL_BULLY
    elseif msg:lower() == "small chill bully" or msg:lower() == "chill bully" then
        mob = id_bhvCustomSmallChillBully
        model = E_MODEL_CHILL_BULLY
    elseif msg:lower() == "small penguin" then
        mob = id_bhvCustomSmallPenguin
        model = E_MODEL_PENGUIN
    elseif msg:lower() == "spindrift" then
        mob = id_bhvCustomSpindrift
        model = E_MODEL_SPINDRIFT
    elseif msg:lower() == "ukiki" then
        mob = id_bhvCustomUkiki
        model = E_MODEL_UKIKI
    elseif msg:lower() == "whomp" or msg:lower() == "small whomp" then
        mob = id_bhvCustomSmallWhomp
        model = E_MODEL_WHOMP
    elseif msg:lower() == "wiggler" or msg:lower() == "wiggler head" then
        mob = id_bhvCustomWigglerHead
        model = E_MODEL_WIGGLER_HEAD
    end

    if mob ~= nil and model ~= nil then
        local m = states[0]
        local spawnPos = {
            x= m.pos.x + 800 * sins(m.faceAngle.y),
            y= m.pos.y + 200,
            z= m.pos.z + 800 * coss(m.faceAngle.y)
        }
        spawn_sync_object(mob, model, spawnPos.x, spawnPos.y, spawnPos.z, setupFunc)
    end
	
	return true
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_UPDATE, update)
hookEvent(HOOK_MARIO_UPDATE, mario_update)
hookEvent(HOOK_ALLOW_PVP_ATTACK, on_allow_pvp_attack)
hookEvent(HOOK_ON_NAMETAGS_RENDER, on_nametags_render)

hookCmd("spawn", "[mobName] - Spawn a mob by it's name (debug).", spawnMob)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------