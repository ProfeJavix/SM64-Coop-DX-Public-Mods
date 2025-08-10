-- name: Team Hud v1.0
-- description: Let's you create groups see the information of your teammates on your HUD. If you have Super Chained Bros. mod it'll act automatically.\nMade by ProfeJavix
-- pausable: false

--#region Localization -------------------------------------------------------------------------------------------------------------------------
local chatMsg = djui_chat_message_create
local popup = djui_popup_create
local globalPopup = djui_popup_create_global
local isGamePaused = is_game_paused
local tableInsert = table.insert
local tostring = tostring
local tonumber = tonumber
local sub = string.sub
local gsub = string.gsub
local match = string.match
local length = string.len
local floor = math.floor
local ceil = math.ceil
local max = math.max
local hookEvent = hook_event
local hookCommand = hook_chat_command
local hookMMSlider = hook_mod_menu_slider
local hookMMInput = hook_mod_menu_inputbox
local drawRect = djui_hud_render_rect
local drawText = djui_hud_print_text
local drawTexture = djui_hud_render_texture
local drawTile = djui_hud_render_texture_tile
local drawPowerMeter = hud_render_power_meter
local setColor = djui_hud_set_color
local setFont = djui_hud_set_font
local getScreenheight = djui_hud_get_screen_height
local getTex = get_texture_info
local measureTxt = djui_hud_measure_text
local getlevelName = get_level_name
local getOverridePallete = network_player_get_override_palette_color

local nps = gNetworkPlayers
local states = gMarioStates
local globalSync = gGlobalSyncTable
local playerSync = gPlayerSyncTable
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Globals ------------------------------------------------------------------------------------------------------------------------------
playerSync[0].group = -1

gGlobalSyncTable.groupCount = 0
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Textures -----------------------------------------------------------------------------------------------------------------------------
-- text base h: 32
local rectTex = getTex("rect-frame")     -- w:64 h:32
local squareTex = getTex("square-frame") --w:64 h:64
local papyrTex = getTex("text-papyr")    --w:64 h:32
local healthFrameTex = getTex("health-frame") --w:32 h:32
local iconsTex = getTex("icons") --w:128 h:128
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Scales -------------------------------------------------------------------------------------------------------------------------------
local gpLblScaleX = 6.25
local gpLblScaleY = 2

local playerSquareScale = 1.6

local namePapyrusScaleX = 1.5
local namePapyrusScaleY = 1

local locationPapyrusScaleX = 2.5
local locationPapyrusScaleY = 1

local playerRectScaleX = 4.5
local playerRectScaleY = 2

local iconScale = 3

local healthFrameScale = 2.1875

local arrowScale = 2
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Character Select Vars ----------------------------------------------------------------------------------------------------------------
local csOn = _G.charSelectExists
local isCSMenuOpen
local getCSLifeIcon

if csOn then
    isCSMenuOpen = _G.charSelect.is_menu_open
    getCSLifeIcon = _G.charSelect.character_get_life_icon
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region SCB Vars -----------------------------------------------------------------------------------------------------------------------------
local scbOn = _G.scbLoaded
local getPlayerGroup
local isLeadersEnabled
local getGroupLeader
if scbOn then
    getPlayerGroup = _G.scbFunctions.getPlayerGroup
    isLeadersEnabled = _G.scbFunctions.isLeadersEnabled
    getGroupLeader = _G.scbFunctions.getGroupLeader
end

local leaderIdx = -1
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Constants ----------------------------------------------------------------------------------------------------------------------------
local X_LEFT_MARGIN = 5
local FRAME_SPACING = 20
local HEX_PATTERN = "\\#[0-9a-fA-F]+\\"

local DEF_ICONS = {
    [gTextures.mario_head] = true,
    [gTextures.luigi_head] = true,
    [gTextures.toad_head] = true,
    [gTextures.waluigi_head] = true,
    [gTextures.wario_head] = true,
}

local TILE_X_POS = {
    [CT_MARIO] = 0,
    [CT_LUIGI] = 16,
    [CT_TOAD] = 32,
    [CT_WALUIGI] = 48,
    [CT_WARIO] = 64
}

local IN_CUTSCENE = {
    [ACT_GROUP_CUTSCENE] = true,
    [ACT_INTRO_CUTSCENE] = true,
    [ACT_CREDITS_CUTSCENE] = true,
    [ACT_END_PEACH_CUTSCENE] = true,
    [ACT_END_WAVING_CUTSCENE] = true,
    [ACT_JUMBO_STAR_CUTSCENE] = true
}
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Variables ----------------------------------------------------------------------------------------------------------------------------
local hudAlpha = 230
local currentPage = 1
local pageCount = 1
local playersPerPage = 4
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Utils --------------------------------------------------------------------------------------------------------------------------------

---@param gp integer
---@return integer[]
function getGpPlayers(gp)
    local gpPlayers = {}

    if leaderIdx ~= -1 and leaderIdx ~= 0 then
        tableInsert(gpPlayers, leaderIdx)
    end

    for i=1, (MAX_PLAYERS - 1) do
        if nps[i].connected and playerSync[i].group == gp and i ~= leaderIdx then
            tableInsert(gpPlayers, i)
        end
    end
    return gpPlayers
end

function setDefaultColor() setColor(255, 255, 255, hudAlpha) end

---@param text string
---@param scale number
---@param x number
---@param y number
---@param wdth number
---@param hght number
function drawCenteredText(text, scale, x, y, wdth, hght)
    local noHexText = stringWithoutHex(text)
    local textWdth = measureTxt(noHexText) * scale
    if textWdth >= wdth then
        scale = getFittingTextScale(noHexText, scale, wdth)
        textWdth = measureTxt(noHexText) * scale
    end
    local posX = x + wdth / 2 - (textWdth) / 2
    local posY = y + hght / 2 - (32 * scale) / 2

    local auxText = ""
    local addToAux = true
    for i = 1, #text do
        local c = sub(text, i, i)

        if c == "\\" then
            addToAux = not addToAux

            if not addToAux then
                if #auxText > 0 then
                    drawText(auxText, posX, posY, scale)
                    posX = posX + measureTxt(auxText) * scale
                    auxText = ""
                end
                local hex = match(text, HEX_PATTERN, i - 1)
                local color = colorHexToRGB(hex)
                setColor(color.r, color.g, color.b, hudAlpha)
            end
        elseif addToAux then
            auxText = auxText .. c
        end
    end

    drawText(auxText, posX, posY, scale)
    
end

---@param text string
---@param baseScale number
---@param targetWdth number
---@return number
function getFittingTextScale(text, baseScale, targetWdth)
    local scale = baseScale
    while measureTxt(text) * scale > targetWdth and scale >= 0.2 do
        scale = scale - 0.001
    end
    return scale
end

---@param hexColor string
---@return Color
function colorHexToRGB(hexColor)

    local color = {r = 0, g = 0, b = 0}
    if hexColor == nil then return color end
    hexColor = gsub(hexColor, "\\", "")
    hexColor = gsub(hexColor, "#", "")

    if length(hexColor) == 3 then
        color.r = tonumber("0x"..sub(hexColor, 1, 1)..sub(hexColor, 1, 1)) or 0
        color.g = tonumber("0x"..sub(hexColor, 2, 2)..sub(hexColor, 2, 2)) or 0
        color.b = tonumber("0x"..sub(hexColor, 3, 3)..sub(hexColor, 3, 3)) or 0
    elseif length(hexColor) == 6 then
        color.r = tonumber("0x"..sub(hexColor, 1, 2)) or 0
        color.g = tonumber("0x"..sub(hexColor, 3, 4)) or 0
        color.b = tonumber("0x"..sub(hexColor, 5, 6)) or 0
    end

    return color
    
end

---@param text string
---@return string
function stringWithoutHex(text)
    local result = gsub(text, HEX_PATTERN, "")
    return result
end

---@param gpCount integer
function adjustPages(gpCount)

    pageCount = ceil(gpCount / playersPerPage)

    if gpCount == 0 then
        pageCount = 1
    end

    if currentPage > pageCount then
        currentPage = pageCount
    end
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hud Rendering ------------------------------------------------------------------------------------------------------------------------
---@param m MarioState
function mario_update(m)
    if m.playerIndex ~= 0 or playerSync[0].group == -1 then return end

    if m.controller.buttonPressed & U_JPAD ~= 0 then
        if currentPage > 1 then
            currentPage = currentPage - 1
            play_sound(SOUND_MENU_CHANGE_SELECT, m.pos)
        end
    end

    if m.controller.buttonPressed & D_JPAD ~= 0 then
        if currentPage < pageCount then
            currentPage = currentPage + 1
            play_sound(SOUND_MENU_CHANGE_SELECT, m.pos)
        end
    end
end

function on_hud_rendered()
    local m = states[0]
    local gp = playerSync[0].group
    
    if scbOn then
        playerSync[0].group = getPlayerGroup(0)
        if isLeadersEnabled() then
            leaderIdx = getGroupLeader(gp)
        else
            leaderIdx = -1
        end
    end
    if isGamePaused() or (csOn and isCSMenuOpen()) or IN_CUTSCENE[m.action] or gp == -1 then return end
    
    local y = floor(getScreenheight() / 7)

    drawGroupLabel(y)
    y = y + 32 * gpLblScaleY + 40

    local gpPlayers = getGpPlayers(gp)
    adjustPages(#gpPlayers)

    --Up Arrow
    if currentPage > 1 then
        setDefaultColor()
        drawTile(iconsTex, X_LEFT_MARGIN, y - 36, arrowScale, arrowScale, 80, 16, 16, 16)
    end

    local firstPos = playersPerPage * (currentPage - 1)

    for i, idx in ipairs(gpPlayers) do
        if i > firstPos and i <= firstPos + playersPerPage then
            drawPlayerLabel(idx, y)
            y = y + (playerSquareScale * 64) + FRAME_SPACING
        end
    end

    if currentPage < pageCount then
        setDefaultColor()
        drawTile(iconsTex, X_LEFT_MARGIN, y - FRAME_SPACING + 2, arrowScale, arrowScale, 80, 32, 16, 16)
    end
end

---@param y integer
function drawGroupLabel(y)
    setDefaultColor()
    drawTexture(papyrTex, X_LEFT_MARGIN, y, gpLblScaleX, gpLblScaleY)
    setFont(FONT_CUSTOM_HUD)
    local text = "Group " .. tostring(playerSync[0].group)
    drawCenteredText(text, 2, X_LEFT_MARGIN, y, (64 * gpLblScaleX), (32 * gpLblScaleY))
    setFont(FONT_NORMAL)

    if leaderIdx == 0 then
        drawTile(iconsTex, X_LEFT_MARGIN + 30, y + (32 * gpLblScaleY) / 2 - 16 , 2, 2, 80, 0, 16, 16)
    end

end

---@param playerIdx integer
---@param y integer
function drawPlayerLabel(playerIdx, y)

    --Icon | w: 16 h:16
    local currX = X_LEFT_MARGIN + (64 * playerSquareScale) / 2 - (16 * iconScale)/2
    local currY = y + (64 * playerSquareScale) / 2 - (16 * iconScale)/2
    drawIcon(playerIdx, currX, currY, y)

    --Frame
    drawTexture(rectTex, X_LEFT_MARGIN + 64 * playerSquareScale, y + (64 * playerSquareScale) / 2 - (32 * playerRectScaleY) / 2,
        playerRectScaleX, playerRectScaleY)
    drawTexture(squareTex, X_LEFT_MARGIN, y, playerSquareScale, playerSquareScale)

    --Name
    currX = X_LEFT_MARGIN + (64 * playerSquareScale) / 2 - (namePapyrusScaleX * 64) / 2
    currY = y + (playerSquareScale * 64) - 35
    setDefaultColor()
    drawTexture(papyrTex, currX, currY, namePapyrusScaleX, namePapyrusScaleY)
    setColor(0, 0, 0, hudAlpha)
    local txt = gNetworkPlayers[playerIdx].name
    drawCenteredText(txt, 1, currX+6, currY, 64 * namePapyrusScaleX - 12, 32 * namePapyrusScaleY)
    setDefaultColor()

    --Health Meter
    currX = X_LEFT_MARGIN + (64 * playerSquareScale)
    currY = y + (64 * playerSquareScale)/2 - (32 * healthFrameScale)/2
    drawHealth(playerIdx, currX, currY)

    --Current Location
    currX = currX + (32 * healthFrameScale)
    currY = y + (64 * playerSquareScale) / 2 - (32 * playerRectScaleY) / 2
    drawLocation(playerIdx, currX, currY)
end

---@param playerIdx integer
---@param x number
---@param y number
---@param squareY number
function drawIcon(playerIdx, x, y, squareY)
    if csOn then
        local icon = getCSLifeIcon(playerIdx)
        if icon ~= nil and not DEF_ICONS[icon] then
            setColor(238, 195, 154, min(30, hudAlpha))
            drawRect(X_LEFT_MARGIN, squareY, 64 * playerSquareScale, 64 * playerSquareScale)
            setDefaultColor()
            drawTexture(icon, x, y, iconScale, iconScale)
        else
            drawDefIcon(playerIdx, x, y, squareY)
        end

    else
        drawDefIcon(playerIdx, x, y, squareY)
    end
    setDefaultColor()

    if leaderIdx == playerIdx then
        drawTile(iconsTex, x + (16 * iconScale) / 2 - (16 * 1.4) / 2, y - 12, 1.4, 1.4, 80, 0, 16, 16)
    end

end

---@param playerIdx integer
---@param x number
---@param y number
function drawHealth(playerIdx, x, y)
    local size = 32 * healthFrameScale
    drawTexture(healthFrameTex, x, y, healthFrameScale, healthFrameScale)
    local health = states[playerIdx].health
    drawPowerMeter(health, x + 2, y + 2, size - 4, size - 4)
end

---@param playerIdx integer
---@param x number
---@param y number
function drawLocation(playerIdx, x, y)

    setColor(0,0,0,hudAlpha)
    local lblW, lblH = (64 * playerRectScaleX) - (32 * healthFrameScale), (32 * playerRectScaleY) / 2
    drawCenteredText("Current Location:", 0.7, x, y, lblW, lblH)
    setDefaultColor()

    local np = nps[playerIdx]
    local levelName = getlevelName(np.currCourseNum, np.currLevelNum, np.currAreaIndex)

    local x, y = x + lblW / 2 - (64 * locationPapyrusScaleX) / 2, y + lblH + lblH / 2 - (32 * locationPapyrusScaleY) / 2 - 4
    drawTexture(papyrTex, x, y, locationPapyrusScaleX, locationPapyrusScaleY)
    setColor(60,60,60, hudAlpha)
    drawCenteredText(levelName, 0.7, x + 6, y + 2, (64 * locationPapyrusScaleX) - 12, (32 * locationPapyrusScaleY) - 4)
    setDefaultColor()
end

---@param playerIdx integer
---@param x number
---@param y number
---@param squareY number
function drawDefIcon(playerIdx, x, y, squareY)

    local m = states[playerIdx]
    local np = nps[playerIdx]

    local isToad = m.character.type == CT_TOAD

    local hasCap = m.marioBodyState.capState == MARIO_HAS_DEFAULT_CAP_ON
    local isWing = m.marioBodyState.capState == MARIO_HAS_WING_CAP_ON
    local isMetal = m.marioBodyState.modelState & MODEL_STATE_METAL ~= 0
    local isInvis = m.marioBodyState.modelState & MODEL_STATE_NOISE_ALPHA ~= 0

    local tileX = TILE_X_POS[m.character.type]
    local tileY = 0
    setDefaultColor()

    local color = {r = 255, g = 255, b = 255}
    local alpha = hudAlpha

    --BG
    setColor(238, 195, 154, min(200, hudAlpha))
    drawRect(X_LEFT_MARGIN, squareY, 64 * playerSquareScale, 64 * playerSquareScale)
    setDefaultColor()

    if isInvis then
        alpha = max(hudAlpha - 150, 0)
    end

    if isMetal then
        color = getOverridePallete(np, METAL)
        setColor(color.r, color.g, color.b, alpha)
    end

    --Skin

    if not isMetal then
        color = getOverridePallete(np, SKIN)
        setColor(color.r, color.g, color.b, alpha)
    end
    
    drawTile(iconsTex, x, y, iconScale, iconScale, tileX, tileY, 16, 16)

    --Hair
    tileY = 16

    if not isMetal then
        color = getOverridePallete(np, HAIR)
        setColor(color.r, color.g, color.b, alpha)
    end

    drawTile(iconsTex, x, y, iconScale, iconScale, tileX, tileY, 16, 16)

    --Face
    if not isMetal then
        tileY = 64
        setColor(255, 255, 255, alpha)
        drawTile(iconsTex, x, y, iconScale, iconScale, tileX, tileY, 16, 16)
        setColor(color.r, color.g, color.b, alpha)
    end

    if not hasCap and not isMetal and not isInvis and not isWing then return end

    --Cap
    tileY = 32

    if not isMetal then
        color = getOverridePallete(np, CAP)
        setColor(color.r, color.g, color.b, alpha)
    end

    drawTile(iconsTex, x, y, iconScale, iconScale, tileX, tileY, 16, 16)

    --Cap Details
    tileY = 96

    if not isMetal then
        setColor(255, 255, 255, alpha)
    end

    drawTile(iconsTex, x, y, iconScale, iconScale, tileX, tileY, 16, 16)
    setColor(color.r, color.g, color.b, alpha)

    --Emblem
    tileY = 80

    if not isMetal then
        if isToad then
            color = getOverridePallete(np, GLOVES)
        else
            color = getOverridePallete(np, EMBLEM)
        end
        setColor(color.r, color.g, color.b, alpha)
    end

    drawTile(iconsTex, x, y, iconScale, iconScale, tileX, tileY, 16, 16)

    --Wings
    if not isWing then return end

    tileY = 48
    setDefaultColor()
    drawTile(iconsTex, x, y, iconScale, iconScale, tileX, tileY, 16, 16)

end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Command Stuff ------------------------------------------------------------------------------------------------------------------------
---@param msg string
---@return boolean
function joinGroup(msg)

    local numMsg = tonumber(msg)
    if numMsg == nil then
        return false
    end

    if numMsg < 0 or numMsg > globalSync.groupCount then
        popup("Wrong group number. Valid range is: [0-"..tostring(globalSync.groupCount).."].", 1)
    else
        playerSync[0].group = numMsg
        play_sound(SOUND_MENU_STAR_SOUND, gMarioStates[0].pos)
        if globalSync.groupCount == numMsg then
            globalSync.groupCount = globalSync.groupCount + 1
        end
        popup("You are now part of Group "..tostring(numMsg)..".", 1)
    end

    return true
end

---@param msg string
---@return boolean
function leaveGroup(msg)

    if msg ~= "" then
        return false
    end

    if playerSync[0].group == -1 then
        popup("You are not in a group.", 1)
    else
        local count = 0
        for i=0, (MAX_PLAYERS - 1) do
            if nps[i].connected and playerSync[i].group == playerSync[0].group then
                count = count + 1
            end
        end

        local gp = playerSync[0].group
        playerSync[0].group = -1
        popup(nps[0].name.." is not in a group anymore.", 1)
        play_sound(SOUND_GENERAL_PAINTING_EJECT, gMarioStates[0].pos)
        
        if count == 1 then
            local text = "Group "..tostring(gp).." has been deleted."
            if globalSync.groupCount > 1 then
                for i = 1, MAX_PLAYERS - 1 do
                    if nps[i].connected and playerSync[i].group ~= -1 and playerSync[i].group > gp then
                        playerSync[i].group = playerSync[i].group - 1
                    end
                end
                text = text.."The others are readjusted."
            end
            globalSync.groupCount = globalSync.groupCount - 1
            globalPopup(text, 1)
        end
    end

    return true
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Hooks --------------------------------------------------------------------------------------------------------------------------------
hookEvent(HOOK_MARIO_UPDATE, mario_update)
hookEvent(HOOK_ON_HUD_RENDER_BEHIND, on_hud_rendered)

if not scbOn then
    hookCommand("join-group", "[number] - Join to a group.", joinGroup)
    hookCommand("leave-group", "Leave your current group.", leaveGroup)
end
--#endregion -----------------------------------------------------------------------------------------------------------------------------------

--#region Mod Menu -----------------------------------------------------------------------------------------------------------------------------
hookMMSlider("HUD Alpha", 230, 0, 255, function(_, val)
    hudAlpha = val
end)
hookMMInput("Players per page", "4", 2, function(_, val)
    local numVal = tonumber(val) or 4
    if numVal < 1 then
        playersPerPage = 1
    elseif numVal > 5 then
        playersPerPage = 5
    else
        playersPerPage = floor(numVal)
    end
end)
--#endregion -----------------------------------------------------------------------------------------------------------------------------------