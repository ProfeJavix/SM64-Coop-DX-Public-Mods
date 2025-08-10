-- name: \\#ff0\\Co\\#639bff\\lo\\#f00\\red \\#0f0\\Name\\#666\\tags\\#fff\\ v1.1
-- description: Make your nametags match your name's color code.\n\nMade by \\#333\\Profe\\#ff0\\Javix


local hookEvent = hook_event
local measure = djui_hud_measure_text
local setColor = djui_hud_set_color
local drawText = djui_hud_print_text_interpolated
local setResolution = djui_hud_set_resolution
local setFont = djui_hud_set_font
local worldToScreenPos = djui_hud_world_pos_to_screen_pos
local insert = table.insert
local sub = string.sub
local gsub = string.gsub
local find = string.find
local match = string.match
local length = string.len
local min = min
local max = max
local clamp = clampf
local is_player_active = is_player_active
local find_object_with_behavior = find_object_with_behavior
local get_behavior_from_id = get_behavior_from_id
local djui_hud_get_fov_coeff = djui_hud_get_fov_coeff
local network_get_player_text_color_string = network_get_player_text_color_string

local nps = gNetworkPlayers
local states = gMarioStates

local extraStates = {}
for i = 0, MAX_PLAYERS - 1 do
    extraStates[i] = {}

    extraStates[i].visible = true
    extraStates[i].stringToRender = nil
    extraStates[i].curPos = nil
    extraStates[i].prevScale = 0
    extraStates[i].prevPos = { x = 0, y = 0, z = 0 }
end

local HEX_REGEX = "\\#[0-9a-zA-Z]+\\"
local HIDE_NAMETAGS_ACTIONS = {
    [ACT_START_CROUCHING] = true,
    [ACT_CROUCHING] = true,
    [ACT_STOP_CROUCHING] = true,
    [ACT_START_CRAWLING] = true,
    [ACT_CRAWLING] = true,
    [ACT_STOP_CRAWLING] = true,
    [ACT_IN_CANNON] = true,
    [ACT_DISAPPEARED] = true
}

---@param text string
---@param keepColors boolean | nil
---@return string
function stringWithoutBackslashes(text, keepColors)

    keepColors = keepColors or false
    local newText = ""
    local i = 1
    local ignoreTill = 0

    while i <= #text do

        local c = sub(text, i, i)

        if c == "\\" and i > ignoreTill then
            local s = find(text, "\\", i + 1, true)
            if s then
                if keepColors and (s - i == 5 or s - i == 8) and match(sub(text, i, s), HEX_REGEX) then
                    i = i - 1
                    ignoreTill = s
                else
                    i = s
                end
            else
                return newText
            end
        else
            newText = newText .. c
        end
        i = i + 1
    end

    return newText
end

---@param colors Color[]
---@return Color
function getShadowColor(colors)
    local avg = { r = 0, g = 0, b = 0 }
    local count = 0
    for _, color in ipairs(colors) do
        count = count + 1
        avg.r = avg.r + color.r
        avg.g = avg.g + color.g
        avg.b = avg.b + color.b
    end

    count = max(1, count)

    return {
        r = avg.r / count,
        g = avg.g / count,
        b = avg.b / count,
    }
end

---@param hexColor string
---@return Color
function getColorFromHex(hexColor)
    local color = { r = 0, g = 0, b = 0 }
    if hexColor == nil then return color end
    hexColor = gsub(hexColor, "\\", "")
    hexColor = gsub(hexColor, "#", "")

    if length(hexColor) == 3 then
        color.r = tonumber("0x" .. sub(hexColor, 1, 1) .. sub(hexColor, 1, 1)) or 0
        color.g = tonumber("0x" .. sub(hexColor, 2, 2) .. sub(hexColor, 2, 2)) or 0
        color.b = tonumber("0x" .. sub(hexColor, 3, 3) .. sub(hexColor, 3, 3)) or 0
    elseif length(hexColor) == 6 then
        color.r = tonumber("0x" .. sub(hexColor, 1, 2)) or 0
        color.g = tonumber("0x" .. sub(hexColor, 3, 4)) or 0
        color.b = tonumber("0x" .. sub(hexColor, 5, 6)) or 0
    end
    return color
end

---@param text string
---@param idx integer
---@return string[], Color[]
function splitStringsWithColors(text, idx)
    local splittedText = {}
    local onlyColors = {}

    local auxStr = ""
    local auxColor = getColorFromHex(network_get_player_text_color_string(idx))
    local addToAux = true


    for i = 1, #text do
        local c = sub(text, i, i)

        if c == "\\" then
            addToAux = not addToAux

            if not addToAux then
                if #auxStr > 0 then
                    insert(splittedText, auxStr)
                    insert(onlyColors, auxColor)
                    auxStr = ""
                end
                local hex = match(text, HEX_REGEX, i)
                auxColor = getColorFromHex(hex)
            end
        elseif addToAux then
            auxStr = auxStr .. c
        end
    end

    if #auxStr > 0 then
        insert(splittedText, auxStr)
        insert(onlyColors, auxColor)
    end

    return splittedText, onlyColors
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

function on_hud_render()

    if gServerSettings.nametags ~= 1 then return end

    setResolution(RESOLUTION_N64);
    setFont(FONT_NORMAL)

    for i = 0, MAX_PLAYERS - 1 do
        local np = nps[i]
        local m = states[i]
        local e = extraStates[i]
        
        local str = e.stringToRender or np.name
        if str == "" or not e.visible then goto continue end

        local name = stringWithoutBackslashes(str, true)
        local noHexName = stringWithoutBackslashes(name)

        if (i == 0 and (not gNametagsSettings.showSelfTag or m.action == ACT_FIRST_PERSON)) or
            not is_player_active(m) or
            not nps[i].currAreaSyncValid or
            not playersInSameArea(0, i) or
            find_object_with_behavior(get_behavior_from_id(id_bhvActSelector)) ~= nil or
            HIDE_NAMETAGS_ACTIONS[m.action]
        then
            e.prevPos = { x = 0, y = 0, z = 0 }
            e.prevScale = 0
            goto continue
        end
        
        local mPos = e.curPos or { x = m.marioBodyState.headPos.x, y = m.pos.y + 180, z = m.marioBodyState.headPos.z }

        local pos = { x = 0, y = 0, z = 0 }

        if worldToScreenPos(mPos, pos) then
            local scale = -400 / pos.z * djui_hud_get_fov_coeff()

            pos = {
                x = pos.x - measure(noHexName) * scale / 2,
                y = pos.y - 16 * scale,
                z = pos.z
            }

            if e.prevScale == 0 then
                vec3f_copy(e.prevPos, pos)
                e.prevScale = scale
            end

            local prevPos = { x = e.prevPos.x, y = e.prevPos.y }
            local prevScale = e.prevScale

            local offset = scale * 2
            local prevOffset = e.prevScale * 2

            local curPrevPosX = e.prevPos.x
            local curPosX = pos.x
            local alpha = 255
            if i ~= 0 then
                alpha = min(np.fadeOpacity * 8, 255) * clamp(4 - scale, 0, 1)
            end

            local splittedName, colors = splitStringsWithColors(name, i)

            local color = getShadowColor(colors)
            setColor(color.r * 0.25, color.g * 0.25, color.b * 0.25, alpha)
            drawText(noHexName, prevPos.x - prevOffset, prevPos.y, prevScale, pos.x - offset, pos.y, scale)
            drawText(noHexName, prevPos.x + prevOffset, prevPos.y, prevScale, pos.x + offset, pos.y, scale)
            drawText(noHexName, prevPos.x, prevPos.y - prevOffset, prevScale, pos.x, pos.y - offset, scale)
            drawText(noHexName, prevPos.x, prevPos.y + prevOffset, prevScale, pos.x, pos.y + offset, scale)

            for j = 1, #splittedName do
                local text = splittedName[j]
                color = colors[j]
                setColor(color.r, color.g, color.b, 255)
                drawText(text, curPrevPosX, prevPos.y, prevScale, curPosX, pos.y, scale)
                curPrevPosX = curPrevPosX + measure(text) * prevScale
                curPosX = curPosX + measure(text) * scale
            end

            vec3f_copy(e.prevPos, pos)
            e.prevScale = scale
        end
        ::continue::
    end
end

---@param idx integer
---@return string | nil
function on_nametags_render(idx)
    return ""
end

hookEvent(HOOK_ON_HUD_RENDER_BEHIND, on_hud_render)
hookEvent(HOOK_ON_NAMETAGS_RENDER, on_nametags_render)

--#region API ----------------------------------------------------------------------------------------------------------------------------------

---Check if this mod is enabled
_G.coloredNametagsOn = true

---Call this to show or hide the nametag of a player
---@param playerIndex integer
---@param isVisible boolean
local function set_nametag_visibility(playerIndex, isVisible)
    if playerIndex >= 0 and playerIndex < MAX_PLAYERS then
        extraStates[playerIndex].visible = isVisible
    end
end

---Call this to change the text rendered in a player's nametag. Pass the text as nil to render the name normally.
---@param playerIndex integer
---@param text string | nil
local function set_nametag_text(playerIndex, text)
    if playerIndex >= 0 and playerIndex < MAX_PLAYERS then
        extraStates[playerIndex].stringToRender = text
    end
end

---Call this to change the position where the nametag is rendered. Pass the pos as nil to render it where it usually does. (Recommended to use on mario_update )
---@param playerIndex integer
---@param pos Vec3f | nil
local function set_nametag_world_pos(playerIndex, pos)
    if playerIndex >= 0 and playerIndex < MAX_PLAYERS then
        extraStates[playerIndex].curPos = pos
    end
end

_G.coloredNametagsFuncs = {
    set_nametag_visibility = set_nametag_visibility,
    set_nametag_text = set_nametag_text,
    set_nametag_world_pos = set_nametag_world_pos
}
--#endregion -----------------------------------------------------------------------------------------------------------------------------------