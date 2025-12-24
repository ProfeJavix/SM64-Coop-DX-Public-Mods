local hook_behavior = hook_behavior
local nearest_mario_state_to_object = nearest_mario_state_to_object
local cur_obj_is_mario_ground_pounding_platform = cur_obj_is_mario_ground_pounding_platform

id_bhvCustomSmallWhomp = hook_behavior(id_bhvSmallWhomp, OBJ_LIST_SURFACE, false, nil, function (o)
    if o.oAction == 8 and o.oTimer <= 100 and cur_obj_is_mario_ground_pounding_platform() == 1 and o.oGoombaBlinkTimer == 0 then
        o.oGoombaBlinkTimer = 1 --desperate times require desperate solutions
        markObjAsInteracted(o)
    end
end)

id_bhvCustomWhompKingBoss = hook_behavior(id_bhvWhompKingBoss, OBJ_LIST_SURFACE, false, nil, function (o)
    if o.oAction == 8 and cur_obj_is_mario_ground_pounding_platform() == 1 then
        markObjAsInteracted(o)
    end
end)

hook_behavior(id_bhvEyerokHand, OBJ_LIST_SURFACE, false, nil, function (o)

    local m = nearest_mario_state_to_object(o)
    if o.oAction == EYEROK_HAND_ACT_DIE and m and m.playerIndex == 0 then
        markObjAsInteracted(o.parentObj)
    end
end)

id_bhvCustomKoopa = hook_behavior(id_bhvKoopa, OBJ_LIST_GENACTOR, false, nil, function (o)

    if o.oKoopaMovementType < KOOPA_BP_KOOPA_THE_QUICK_BASE then return end

    local m = nearest_mario_state_to_object(o)
    if not m or m.playerIndex ~= 0 then return end

    if o.oAction == KOOPA_THE_QUICK_ACT_AFTER_RACE and o.parentObj.oKoopaRaceEndpointRaceStatus > 0 then
        local id = ternary(o.oKoopaTheQuickRaceIndex == KOOPA_THE_QUICK_BOB_INDEX, 'beat_ktq1', 'beat_ktq2')
        markIdForLocal(id)
    end
end)

hook_behavior(id_bhvRacingPenguin, OBJ_LIST_GENACTOR, false, nil, function (o)

    local m = nearest_mario_state_to_object(o)
    if not m or m.playerIndex ~= 0 then return end

    if o.oAction == RACING_PENGUIN_ACT_SHOW_FINAL_TEXT and
    o.oRacingPenguinMarioWon == 1 and o.oRacingPenguinMarioCheated == 0 then
        markIdForLocal('beat_race_penguin')
    end
end)