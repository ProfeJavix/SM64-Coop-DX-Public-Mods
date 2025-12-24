--#region Localizations ---------------------------------------------------------------------

local dist_between_objects = dist_between_objects
local djui_hud_get_color = djui_hud_get_color
local djui_hud_get_screen_height = djui_hud_get_screen_height
local djui_hud_get_screen_width = djui_hud_get_screen_width
local djui_hud_print_text_interpolated = djui_hud_print_text_interpolated
local djui_hud_set_color = djui_hud_set_color
local is_player_active = is_player_active

--#endregion --------------------------------------------------------------------------------

local nps = gNetworkPlayers
local states = gMarioStates

getMHTeam = _G.mhApi.getTeam ---@type fun(idx: integer):0|1

---@param idx integer
function getLocalFromGlobalIdx(idx)
    for i = 0, MAX_PLAYERS - 1 do
        if nps[i].connected and nps[i].globalIndex == idx then
            return i
        end
    end
    return -1
end

---@param m MarioState
---@return MarioState | nil
function nearestFreezeTarget(m)

    if getMHTeam(0) ~= 1 then
        return nil
    end

    local minDist = math.huge
    local target = nil

    for i = 1, MAX_PLAYERS - 1 do
        local mi = states[i]
        if is_player_active(mi) ~= 0 and getMHTeam(i) == 0 and mi.action ~= ACT_FROZEN then
            local dist = dist_between_objects(m.marioObj, mi.marioObj)

            if dist < minDist then
                minDist = dist

                if dist < 1500 then
                    target = mi
                end
            end
        end
    end

    return target
end

---@param x integer
---@param y integer
function isPosInScreen(x, y)
    return x >= 0 and x <= djui_hud_get_screen_width() and y >= 0 and y <= djui_hud_get_screen_height()
end

---@param text string
---@param x integer
---@param y integer
---@param scale number
---@param prevInfo? table
function drawTextWithBorder(text, x, y, scale, prevInfo)
    local color = djui_hud_get_color()
    local off = scale * 2
    djui_hud_set_color(0, 0, 0, color.a)

    if prevInfo then
        prevX, prevY, prevScale = prevInfo.x, prevInfo.y, prevInfo.scale
        local prevOff = prevScale * 2

        djui_hud_print_text_interpolated(text, prevX - prevOff, prevY, prevScale, x - off, y, scale)
        djui_hud_print_text_interpolated(text, prevX + prevOff, prevY, prevScale, x + off, y, scale)
        djui_hud_print_text_interpolated(text, prevX, prevY - prevOff, prevScale, x, y - off, scale)
        djui_hud_print_text_interpolated(text, prevX, prevY + prevOff, prevScale, x, y + off, scale)

        djui_hud_set_color(color.r, color.g, color.b, color.a)
        djui_hud_print_text_interpolated(text, prevX, prevY, prevScale, x, y, scale)
    else
        djui_hud_print_text(text, x - off, y, scale)
        djui_hud_print_text(text, x + off, y, scale)
        djui_hud_print_text(text, x, y - off, scale)
        djui_hud_print_text(text, x, y + off, scale)

        djui_hud_set_color(color.r, color.g, color.b, color.a)
        djui_hud_print_text(text, x, y, scale)
    end
    
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