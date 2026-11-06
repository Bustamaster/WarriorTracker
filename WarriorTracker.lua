local MAX_RANGE = 30
local FAR_RANGE = 100
local UPDATE_INTERVAL = 0.1
local ANIMATION_SPEED = 6

local strings = {
    cs = {
        title = "Warrior Tracker - nastavení", width = "Délka (šířka pruhu)",
        height = "Výška (tloušťka pruhu)", x = "Pozice X (od středu obrazovky)",
        y = "Pozice Y (od středu obrazovky)", lock = "Zamknout pozici (nejde přetahovat myší)",
        reset = "Výchozí hodnoty", close = "Zavřít", language = "Jazyk",
        noTarget = "Bez cíle", melee = "NA BLÍZKO", dead = "MRTVÁ ZÓNA",
        inRange = "V DOSAHU", outOfRange = "MIMO DOSAHU", unknown = "DOSAH NEZJIŠTĚN",
        missing = "Chybí %.1f yd", missingEstimate = "Chybí ~%.0f yd",
        pet = "Pet útočí na tento cíl (tvůj target se nezmění)",
        marker = "Levé: lebka\nCtrl+levé: další volná značka (kříž, čtverec, měsíc…)\nPravé: zavřít řádek\nShift+levé: zrušit značku",
        dice = "Náhodně rozdat značky: lebka, kříž, čtverec, …\n(každý nepřítel v seznamu jednu, nejvýš 8)",
        unavailable = "Cil neni dostupny pro kliknuti. Zapni nepratelske nameplaty (V) a priprav seznam pred bojem.",
        locked = "zamceno", unlocked = "odemceno", positionReset = "Pozice Warrior Tracker byla obnovena.",
        stackCleared = "Sloupec pouzitych schopnosti byl vycisten.",
        commands = "Prikazy: /wrt, /wt lock, /wt unlock, /wt reset, /wt debug, /wt clear, /wt seznam",
        listCombat = "Seznam targetu se vycisti po boji.", listClear = "Seznam targetu se vycisti za 0,5 s.",
        openSettings = "Otevřít nastavení", secureError = "zabezpecene tlacitko cile se nepodarilo vytvorit: ",
        fontError = "nepodarilo se nacist font Lato-Regular.ttf.",
        debugSelect = "nejprve vyber target.", debugTarget = "diagnostika targetu ",
        debugNoApi = "UnitDistanceSquared: API neni dostupne", debugItem = "predmet",
        debugThreshold = "Hranice %s yd (%s): %s", debugMeleeItems = "Na blizko (predmety 5 yd): ",
        debugMelee = "Na blizko (%s): %s", debugShort = "Kratky dosah (predmety 10/20 yd): ",
        debugInteraction = "interakce ",
    },
    en = {
        title = "Warrior Tracker - Settings", width = "Length (bar width)",
        height = "Height (bar thickness)", x = "X position (from screen center)",
        y = "Y position (from screen center)", lock = "Lock position (disable dragging)",
        reset = "Defaults", close = "Close", language = "Language",
        noTarget = "No target", melee = "MELEE RANGE", dead = "DEAD ZONE",
        inRange = "IN RANGE", outOfRange = "OUT OF RANGE", unknown = "RANGE UNKNOWN",
        missing = "%.1f yd to range", missingEstimate = "~%.0f yd to range",
        pet = "Send pet to this target (your target stays unchanged)",
        marker = "Left: skull\nCtrl+left: next available marker (cross, square, moon...)\nRight: close row\nShift+left: clear marker",
        dice = "Randomly assign markers: skull, cross, square, ...\n(one per listed enemy, up to 8)",
        unavailable = "Target unavailable. Enable enemy nameplates (V) and prepare the list before combat.",
        locked = "locked", unlocked = "unlocked", positionReset = "Warrior Tracker position reset.",
        stackCleared = "Used abilities column cleared.",
        commands = "Commands: /wrt, /wt lock, /wt unlock, /wt reset, /wt debug, /wt clear, /wt list",
        listCombat = "Target list will be cleared after combat.", listClear = "Target list will be cleared in 0.5 seconds.",
        openSettings = "Open settings", secureError = "could not create secure target button: ",
        fontError = "could not load Lato-Regular.ttf.",
        debugSelect = "select a target first.", debugTarget = "target diagnostics ",
        debugNoApi = "UnitDistanceSquared: API unavailable", debugItem = "item",
        debugThreshold = "Threshold %s yd (%s): %s", debugMeleeItems = "Melee (5 yd items): ",
        debugMelee = "Melee (%s): %s", debugShort = "Short range (10/20 yd items): ",
        debugInteraction = "interaction ",
    },
}

local function L(key)
    local language = WarriorTrackerDB and WarriorTrackerDB.language
    return strings[language == "en" and "en" or "cs"][key]
end

local FONT_PATH = "Interface\\AddOns\\WarriorTracker\\Lato-Regular.ttf"
local function applyAddonFont(fontString)
    local _, size, flags = fontString:GetFont()
    if not fontString:SetFont(FONT_PATH, size or 12, flags or "") then
        print("WarriorTracker: " .. L("fontError"))
    end
end

-- Real range thresholds available for hostile targets (item IDs taken from LibRangeCheck-3.0, Era/Forever lists).
local HOSTILE_THRESHOLDS = {
    { range = 45, itemIDs = { 221316 } },
    { range = 100, itemIDs = { 23715, 23718, 23719, 23721, 23722, 227685, 17162, 5418 } },
}

local MELEE_RANGE = 5

-- Melee range: 5 yd items (LibRangeCheck Era/Forever), then warrior melee spells.
local MELEE_ITEMS = { 8149, 15826, 16308, 17117, 22259, 22432, 206466, 208760, 208855, 209027, 209057, 213036, 221199, 225943 }
local MELEE_SPELLS = {
    { spellID = 78, spellName = "Heroic Strike" },
}

local ZONE_STYLES = {
    ranged = { fill = { 0.25, 1, 0.3 }, glow = { 0.3, 1, 0.3 }, flash = { 0.7, 1, 0.7 } },
    melee = { fill = { 1, 0.7, 0.1 }, glow = { 1, 0.75, 0.1 }, flash = { 1, 0.9, 0.5 } },
}

local FALLBACK_CHECKS = {
    { range = 9.9, interactIndex = 3, friendlyOnly = true },
    { range = 11.11, interactIndex = 2, friendlyOnly = true },
    { range = 28, interactIndex = 1, friendlyOnly = true },
}

local frame = CreateFrame("Frame", "WarriorTrackerFrame", UIParent)
frame:SetSize(460, 32)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

-- Visual style copied from the built-in swing timer (Blizzard_SwingTimer.xml); plain colors are used if the atlases are missing.
local function hasAtlas(atlas)
    return C_Texture and type(C_Texture.GetAtlasInfo) == "function" and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local USE_SWING_STYLE = hasAtlas("ui-swingtimerbar-frame") and hasAtlas("ui-swingtimerbar-background")
local FILL_ATLAS = "ui-swingtimerbar-filling-mainhand"

local background = frame:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints(frame)

local border = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
border:SetAllPoints(frame)

local statusBar = CreateFrame("StatusBar", nil, frame)
statusBar:SetMinMaxValues(0, 1)
statusBar:SetValue(0)

if USE_SWING_STYLE then
    background:SetAtlas("ui-swingtimerbar-background")
    border:SetAtlas("ui-swingtimerbar-frame")
    statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -4)
    statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 4)
    if hasAtlas(FILL_ATLAS) then
        statusBar:SetStatusBarTexture(FILL_ATLAS)
        statusBar:GetStatusBarTexture():SetDesaturated(true)
    else
        statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    statusBar:SetStatusBarColor(0.25, 1, 0.3, 1)
else
    background:SetColorTexture(0.22, 0.03, 0.03, 1)
    border:Hide()
    statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(0.1, 0.9, 0.2, 1)
end

local rageFrame = CreateFrame("Frame", nil, UIParent)
rageFrame:SetFrameStrata("MEDIUM")
rageFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
rageFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
rageFrame:EnableMouse(false)

local rageBackground = rageFrame:CreateTexture(nil, "BACKGROUND")
rageBackground:SetAllPoints(rageFrame)
local rageBorder = rageFrame:CreateTexture(nil, "OVERLAY")
rageBorder:SetAllPoints(rageFrame)
local rageBar = CreateFrame("StatusBar", nil, rageFrame)
rageBar:EnableMouse(false)
rageBar:SetPoint("TOPLEFT", rageFrame, "TOPLEFT", 3, -2)
rageBar:SetPoint("BOTTOMRIGHT", rageFrame, "BOTTOMRIGHT", -3, 2)
rageBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
rageBar:SetStatusBarColor(1, 0.08, 0.08, 1)
if USE_SWING_STYLE then
    rageBackground:SetAtlas("ui-swingtimerbar-background")
    rageBorder:SetAtlas("ui-swingtimerbar-frame")
else
    rageBackground:SetColorTexture(0.12, 0.04, 0.04, 1)
    rageBorder:Hide()
end

local rageText = rageBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rageText:SetPoint("CENTER", rageBar, "CENTER", 0, 0)

local function updateRage()
    rageBar:SetMinMaxValues(0, UnitPowerMax("player", 1))
    local rage = UnitPower("player", 1)
    rageBar:SetValue(rage)
    rageText:SetText(rage)
end

local function resizeRageBar()
    rageFrame:SetHeight(frame:GetHeight() * 0.75)
end
frame:HookScript("OnSizeChanged", resizeRageBar)
resizeRageBar()

local rageEvents = CreateFrame("Frame")
rageEvents:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
rageEvents:RegisterUnitEvent("UNIT_MAXPOWER", "player")
rageEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
rageEvents:SetScript("OnEvent", function(_, event, _, powerType)
    if event == "PLAYER_ENTERING_WORLD" or powerType == "RAGE" then
        updateRage()
    end
end)

local pip
if USE_SWING_STYLE and hasAtlas("ui-swingtimerbar-pip") then
    pip = statusBar:CreateTexture(nil, "OVERLAY")
    pip:SetAtlas("ui-swingtimerbar-pip", true)
    pip:SetPoint("RIGHT", statusBar:GetStatusBarTexture(), "RIGHT", 0, 0)
end

if USE_SWING_STYLE and hasAtlas("ui-swingtimerbar-textshadow-left") then
    local textShadow = statusBar:CreateTexture(nil, "OVERLAY")
    textShadow:SetAtlas("ui-swingtimerbar-textshadow-left")
    textShadow:SetWidth(171)
    textShadow:SetPoint("TOPLEFT")
    textShadow:SetPoint("BOTTOMLEFT")
end

local nameLabel = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
applyAddonFont(nameLabel)
nameLabel:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
nameLabel:SetJustifyH("LEFT")

local infoLabel = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
applyAddonFont(infoLabel)
infoLabel:SetPoint("RIGHT", statusBar, "RIGHT", -10, 0)
infoLabel:SetJustifyH("RIGHT")

-- Texts are built as "Name  |  distance  |  status": the name goes left, the rest right (like the swing timer).
local label = {}
function label:SetText(text)
    local name, rest = string.match(text, "^(.-)  |  (.*)$")
    nameLabel:SetText(name or text)
    infoLabel:SetText(rest or "")
end

local BAR_STATES = {
    none = { alpha = 0.6, text = { 0.7, 0.7, 0.7 }, plainBackground = { 0.3, 0.3, 0.3 } },
    outOfRange = { alpha = 1, text = { 1, 0.13, 0.13 }, plainBackground = { 0.22, 0.03, 0.03 } },
    inRange = { alpha = 1, text = { 1, 1, 1 }, plainBackground = { 0.22, 0.03, 0.03 } },
}

local function setBarState(stateName)
    local state = BAR_STATES[stateName]
    frame:SetAlpha(state.alpha)
    nameLabel:SetTextColor(1, 1, 1)
    infoLabel:SetTextColor(state.text[1], state.text[2], state.text[3])
    if stateName == "none" then
        nameLabel:SetTextColor(state.text[1], state.text[2], state.text[3])
    end
    if not USE_SWING_STYLE then
        background:SetColorTexture(state.plainBackground[1], state.plainBackground[2], state.plainBackground[3], 1)
    end
end

local function matchSwingTimerSize()
    local reference = _G.SwingTimerRangedFrame or _G.SwingTimerMainHandFrame
    if reference and reference.GetSize then
        local width, height = reference:GetSize()
        if type(width) == "number" and type(height) == "number" and width > 50 and height > 5 then
            frame:SetSize(width, height)
        end
    end
end

if pip then
    statusBar:HookScript("OnValueChanged", function(_, value)
        pip:SetShown(value > 0.005 and value < 0.995)
    end)
    pip:Hide()
end

-- Bright green outline shown while the target is in shooting range.
local rangeGlow = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
rangeGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
rangeGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
rangeGlow:SetColorTexture(0.3, 1, 0.3, 0.9)
rangeGlow:Hide()

-- Short flash over the bar when the target enters range.
local rangeFlash = statusBar:CreateTexture(nil, "OVERLAY", nil, -1)
rangeFlash:SetAllPoints(statusBar)
rangeFlash:SetColorTexture(0.7, 1, 0.7, 1)
rangeFlash:SetBlendMode("ADD")
rangeFlash:SetAlpha(0)

local ICON_SIZE = 39
local MIN_TRACKED_COOLDOWN = 1.6
local IGNORED_SPELLS = {
    [75] = true, -- Auto Shot
    [6603] = true, -- Auto Attack
}

local iconLane = CreateFrame("Frame", nil, frame)
iconLane:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
iconLane:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
iconLane:SetHeight(ICON_SIZE)

local floatingIcons = {}
local pendingCasts = {}
local sentCasts = {}
local iconPool = {}

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local MARK_SPELL_ID = 1130 -- Hunter's Mark (rank 1); used for the name and icon of every rank.

local markIcon = CreateFrame("Frame", nil, frame)
markIcon:SetSize(ICON_SIZE, ICON_SIZE)
markIcon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
markIcon.texture = markIcon:CreateTexture(nil, "ARTWORK")
markIcon.texture:SetAllPoints(markIcon)
markIcon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
markIcon.timer = markIcon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
markIcon.timer:SetPoint("BOTTOM", markIcon, "BOTTOM", 0, 2)
markIcon:Hide()

-- Returns aura table for Hunter's Mark on the target (from any hunter), or nil.
local function findTargetMark()
    if not UnitExists("target") then
        return nil
    end

    local name
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        name = C_Spell.GetSpellName(MARK_SPELL_ID)
    end
    if type(name) ~= "string" or isSecret(name) then
        name = "Hunter's Mark"
    end

    if C_UnitAuras and type(C_UnitAuras.GetAuraDataBySpellName) == "function" then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", name, "HARMFUL")
        if ok and type(aura) == "table" then
            return aura
        end
    end
end

local function updateMarkIcon()
    local aura = findTargetMark()
    if not aura then
        markIcon:Hide()
        return
    end

    local texture = aura.icon
    if texture == nil or isSecret(texture) then
        texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(MARK_SPELL_ID)
    end
    markIcon.texture:SetTexture(texture)

    local expirationTime = aura.expirationTime
    local remaining = (type(expirationTime) == "number" and not isSecret(expirationTime) and expirationTime > 0)
        and (expirationTime - GetTime()) or nil
    if remaining and remaining > 0 then
        markIcon.timer:SetText(remaining >= 60 and string.format("%dm", math.ceil(remaining / 60))
            or string.format("%d", math.ceil(remaining)))
    else
        markIcon.timer:SetText("")
    end
    markIcon:Show()
end

local function readSpellCooldown(spellID)
    local startTime, duration
    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local info = C_Spell.GetSpellCooldown(spellID)
        if type(info) == "table" and not isSecret(info) then
            startTime, duration = info.startTime, info.duration
        end
    elseif type(GetSpellCooldown) == "function" then
        startTime, duration = GetSpellCooldown(spellID)
    end

    if isSecret(startTime) or isSecret(duration)
        or type(startTime) ~= "number" or type(duration) ~= "number"
    then
        return nil
    end
    return startTime, duration
end

local function isTrackedCooldown(startTime, duration)
    if duration <= 0 then
        return false
    end
    if duration > MIN_TRACKED_COOLDOWN then
        return true
    end
    local gcdStart, gcdDuration = readSpellCooldown(61304)
    if not gcdStart then
        return false
    end
    return gcdDuration <= 0 or math.abs(startTime - gcdStart) > 0.05
        or math.abs(duration - gcdDuration) > 0.05
end

local function spellIcon(spellID)
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        return C_Spell.GetSpellTexture(spellID)
    elseif type(GetSpellTexture) == "function" then
        return GetSpellTexture(spellID)
    end
end

local function acquireIcon()
    local icon = table.remove(iconPool)
    if icon then
        return icon
    end

    icon = CreateFrame("Frame", nil, iconLane)
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    icon.shadow = icon:CreateTexture(nil, "BACKGROUND", nil, -2)
    icon.shadow:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
    icon.shadow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
    icon.shadow:SetColorTexture(0, 0, 0, 0.45)

    -- Coloured outer edge (bronze like the swing timer frame, red for stings) with a thin black inner edge.
    icon.border = icon:CreateTexture(nil, "BACKGROUND", nil, -1)
    icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
    icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    icon.innerEdge = icon:CreateTexture(nil, "BACKGROUND", nil, 0)
    icon.innerEdge:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    icon.innerEdge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    icon.innerEdge:SetColorTexture(0, 0, 0, 1)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints(icon)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Clock-like sweep that darkens the part of the cooldown that is still left.
    local ok, cooldown = pcall(CreateFrame, "Cooldown", nil, icon, "CooldownFrameTemplate")
    if ok and cooldown then
        cooldown:SetAllPoints(icon)
        if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
        if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
        if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
        if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.55) end
        icon.cooldown = cooldown
    end

    -- Text and flash live on a child frame so they are drawn above the cooldown sweep.
    icon.overlay = CreateFrame("Frame", nil, icon)
    icon.overlay:SetAllPoints(icon)
    icon.overlay:SetFrameLevel(icon:GetFrameLevel() + 5)
    icon.timer = icon.overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    icon.timer:SetPoint("TOP", icon, "TOP", 0, -2)
    icon.timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    icon.timer:SetShadowOffset(1, -1)
    icon.timer:SetShadowColor(0, 0, 0, 1)
    icon.flash = icon.overlay:CreateTexture(nil, "OVERLAY")
    icon.flash:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
    icon.flash:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    icon.flash:SetColorTexture(1, 1, 1, 1)
    icon.flash:SetBlendMode("ADD")
    icon.flash:SetAlpha(0)
    return icon
end

local ICON_TRAVEL_DURATION = 10

local function releaseIcon(index)
    local icon = table.remove(floatingIcons, index)
    icon:Hide()
    table.insert(iconPool, icon)
end

-- Used abilities stack upwards; green indicates enough rage.
local STACK_ICON_SIZE = 26
local STACK_SPACING = 3
local STACK_FLASH_DURATION = 0.6
local stackEntries = {}
local stackOrder = {}

-- The column sits above the right end of the bar; travelling icons stop short of it so they don't overlap.
iconLane:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -(STACK_ICON_SIZE + 6), 2)

local function layoutStack()
    for index, entry in ipairs(stackOrder) do
        entry:ClearAllPoints()
        entry:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 4 + (index - 1) * (STACK_ICON_SIZE + STACK_SPACING))
    end
end

local function getStackEntry(spellID, texture)
    local entry = stackEntries[spellID]
    if not entry then
        entry = CreateFrame("Frame", nil, frame)
        entry:SetSize(STACK_ICON_SIZE, STACK_ICON_SIZE)
        entry.border = entry:CreateTexture(nil, "BACKGROUND")
        entry.border:SetPoint("TOPLEFT", entry, "TOPLEFT", -2, 2)
        entry.border:SetPoint("BOTTOMRIGHT", entry, "BOTTOMRIGHT", 2, -2)
        entry.border:SetColorTexture(1, 1, 1, 1)
        entry.texture = entry:CreateTexture(nil, "ARTWORK")
        entry.texture:SetAllPoints(entry)
        entry.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        entry.rageGlow = entry:CreateTexture(nil, "OVERLAY")
        entry.rageGlow:SetAllPoints(entry)
        entry.rageGlow:SetColorTexture(0.3, 1, 0.3, 1)
        entry.rageGlow:SetBlendMode("ADD")
        entry.rageGlow:SetAlpha(0)
        entry.shade = entry:CreateTexture(nil, "OVERLAY")
        entry.shade:SetAllPoints(entry)
        entry.shade:SetColorTexture(0, 0, 0, 0.55)
        entry.cooldown = CreateFrame("Cooldown", nil, entry, "CooldownFrameTemplate")
        entry.cooldown:SetAllPoints(entry)
        if entry.cooldown.SetDrawEdge then entry.cooldown:SetDrawEdge(false) end
        if entry.cooldown.SetDrawBling then entry.cooldown:SetDrawBling(false) end
        entry.gcd = CreateFrame("Cooldown", nil, entry, "CooldownFrameTemplate")
        entry.gcd:SetAllPoints(entry)
        if entry.gcd.SetDrawEdge then entry.gcd:SetDrawEdge(false) end
        if entry.gcd.SetDrawBling then entry.gcd:SetDrawBling(false) end
        if entry.gcd.SetHideCountdownNumbers then entry.gcd:SetHideCountdownNumbers(true) end
        entry.rageBackground = entry:CreateTexture(nil, "BACKGROUND")
        entry.rageBackground:SetPoint("LEFT", entry, "RIGHT", 3, 0)
        entry.rageBackground:SetSize(70, 14)
        entry.rageBackground:SetColorTexture(0.1, 0.02, 0.02, 0.95)
        entry.rageBar = CreateFrame("StatusBar", nil, entry)
        entry.rageBar:SetPoint("TOPLEFT", entry.rageBackground, "TOPLEFT", 1, -1)
        entry.rageBar:SetPoint("BOTTOMRIGHT", entry.rageBackground, "BOTTOMRIGHT", -1, 1)
        entry.rageBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        entry.rageBar:SetStatusBarColor(1, 0.08, 0.08, 1)
        entry.rageText = entry.rageBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        entry.rageText:SetPoint("CENTER", entry.rageBar, "CENTER", 0, 0)
        entry.rageBackground:Hide()
        entry.rageBar:Hide()
        entry.flash = entry:CreateTexture(nil, "OVERLAY")
        entry.flash:SetPoint("TOPLEFT", entry, "TOPLEFT", -2, 2)
        entry.flash:SetPoint("BOTTOMRIGHT", entry, "BOTTOMRIGHT", 2, -2)
        entry.flash:SetColorTexture(0.3, 1, 0.3, 1)
        entry.flash:SetBlendMode("ADD")
        entry.flash:SetAlpha(0)
        entry.timer = entry:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        entry.timer:SetPoint("CENTER", entry, "CENTER", 0, 0)
        -- Right click removes the icon from the column (it comes back the next time the ability is used).
        entry.spellID = spellID
        entry:EnableMouse(true)
        entry:SetScript("OnMouseUp", function(self, mouseButton)
            if mouseButton ~= "RightButton" then
                return
            end
            self:Hide()
            self.flashStart = nil
            if stackEntries[self.spellID] == self then
                stackEntries[self.spellID] = nil
            end
            pendingCasts[self.spellID] = nil
            for index, other in ipairs(stackOrder) do
                if other == self then
                    table.remove(stackOrder, index)
                    break
                end
            end
            layoutStack()
        end)
        stackEntries[spellID] = entry
        table.insert(stackOrder, entry)
        layoutStack()
    end
    entry.texture:SetTexture(texture)
    return entry
end

local function setStackCooldown(spellID, texture)
    local entry = getStackEntry(spellID, texture)
    entry.ready = false
    entry.unknownCooldown = false
    entry.timer:SetText("")
    entry.cooldown:Clear()
    entry.texture:SetDesaturated(true)
    entry.shade:Show()
    entry:Show()
end

local function readRageCost(spellID)
    local costs
    local unknownCost = false
    if C_Spell and type(C_Spell.GetSpellPowerCost) == "function" then
        costs = C_Spell.GetSpellPowerCost(spellID)
    elseif type(GetSpellPowerCost) == "function" then
        costs = GetSpellPowerCost(spellID)
    else
        unknownCost = true
    end

    local rageCost
    if isSecret(costs) then
        unknownCost = true
    elseif type(costs) == "table" then
        for _, info in ipairs(costs) do
            if isSecret(info) or (type(info) == "table" and (isSecret(info.type)
                or isSecret(info.cost) or isSecret(info.minCost) or isSecret(info.requiredAuraID)
                or isSecret(info.hasRequiredAura))) then
                unknownCost = true
            elseif type(info) == "table"
                and info.type == 1 and not isSecret(info.cost)
                and type(info.cost) == "number" and info.cost > 0
                and (not info.requiredAuraID or info.requiredAuraID == 0 or info.hasRequiredAura)
            then
                rageCost = info.cost
                if type(info.minCost) == "number" and not isSecret(info.minCost) then
                    rageCost = info.minCost
                end
                break
            end
        end
    end
    return rageCost, unknownCost
end

local function updateStackRage(entry)
    local rageCost, unknownCost = readRageCost(entry.spellID)
    entry.rageCost, entry.rageCostUnknown = rageCost, unknownCost
    if rageCost and rageCost > 0 then
        entry.rageBar:SetMinMaxValues(0, rageCost)
        entry.rageBar:SetValue(UnitPower("player", 1))
        entry.rageText:SetText(rageCost)
        entry.rageBackground:Show()
        entry.rageBar:Show()
    elseif unknownCost then
        entry.rageBar:SetMinMaxValues(0, 1)
        entry.rageBar:SetValue(0)
        entry.rageText:SetText("?")
        entry.rageBackground:Show()
        entry.rageBar:Show()
    else
        entry.rageBackground:Hide()
        entry.rageBar:Hide()
    end
end

local function updateAllStackRage()
    for _, entry in ipairs(stackOrder) do
        updateStackRage(entry)
    end
end

local rageMax
local function updateRageMax()
    local value = UnitPowerMax("player", 1)
    if not isSecret(value) and type(value) == "number" and value > 0 then
        rageMax = value
    else
        rageMax = nil
    end
end
updateRageMax()

local stackRageEvents = CreateFrame("Frame")
stackRageEvents:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
stackRageEvents:RegisterUnitEvent("UNIT_MAXPOWER", "player")
stackRageEvents:RegisterEvent("SPELL_UPDATE_USABLE")
stackRageEvents:RegisterEvent("SPELLS_CHANGED")
stackRageEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
stackRageEvents:SetScript("OnEvent", function(_, event, _, powerType)
    if event == "PLAYER_ENTERING_WORLD" or (event == "UNIT_MAXPOWER" and powerType == "RAGE") then
        updateRageMax()
    end
    if (event ~= "UNIT_POWER_UPDATE" and event ~= "UNIT_MAXPOWER") or powerType == "RAGE" then
        updateAllStackRage()
    end
end)

local function setStackReady(spellID)
    local entry = stackEntries[spellID]
    if not entry or entry.ready then
        return
    end
    entry.ready = true
    entry.unknownCooldown = false
    entry.cooldown:Clear()
    entry.texture:SetDesaturated(false)
    entry.shade:Hide()
    entry.timer:SetText("")
end

local function setStackUnknownCooldown(entry, now)
    entry.unknownCooldown = true
    entry.nextCooldownCheck = now + 0.2
    entry.ready = false
    entry.texture:SetDesaturated(false)
    entry.shade:Hide()
    entry.cooldown:Clear()
    local durationObject = C_Spell and C_Spell.GetSpellCooldownDuration
        and C_Spell.GetSpellCooldownDuration(entry.spellID, true)
    if durationObject and entry.cooldown.SetCooldownFromDurationObject then
        entry.timer:SetText("")
        entry.cooldown:SetCooldownFromDurationObject(durationObject)
    else
        entry.timer:SetText("?")
    end
end

local function setStackTimer(spellID, text)
    local entry = stackEntries[spellID]
    if entry and not entry.ready then
        entry.timer:SetText(text)
    end
end

local function updateStackGCD()
    local durationObject
    if C_Spell and type(C_Spell.GetSpellCooldownDuration) == "function" then
        durationObject = C_Spell.GetSpellCooldownDuration(61304)
    end
    local startTime, duration = readSpellCooldown(61304)
    for _, entry in ipairs(stackOrder) do
        if durationObject and entry.gcd.SetCooldownFromDurationObject then
            entry.gcd:SetCooldownFromDurationObject(durationObject)
        elseif startTime then
            entry.gcd:SetCooldown(startTime, duration)
        else
            entry.gcd:Clear()
        end
    end
end

local gcdEvents = CreateFrame("Frame")
gcdEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
gcdEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
gcdEvents:SetScript("OnEvent", updateStackGCD)

local function updateStackRageReady(entry, rage, now)
    local eligible
    if not entry.rageCostUnknown and entry.rageCost and entry.rageCost > 0 then
        if not isSecret(rage) and type(rage) == "number" then
            eligible = rage >= entry.rageCost
        elseif rageMax and type(UnitPowerPercent) == "function" and C_CurveUtil
            and type(C_CurveUtil.CreateColorCurve) == "function"
            and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
            and type(CreateColor) == "function"
        then
            if entry.curveCost ~= entry.rageCost or entry.curveMax ~= rageMax then
                entry.rageCurve = C_CurveUtil.CreateColorCurve()
                entry.rageCurve:SetType(Enum.LuaCurveType.Step)
                entry.rageCurve:AddPoint(0, CreateColor(0.2, 0.2, 0.2, 0))
                entry.rageCurve:AddPoint(entry.rageCost / rageMax, CreateColor(0.1, 1, 0.1, 0.35))
                entry.curveCost, entry.curveMax = entry.rageCost, rageMax
            end
            local color = UnitPowerPercent("player", 1, false, entry.rageCurve)
            local r, g, b, alpha = color:GetRGBA()
            entry.border:SetVertexColor(r, g, b, 1)
            entry.rageGlow:SetAlpha(alpha)
            entry.flashStart = nil
            entry.flash:SetAlpha(0)
            entry.rageReady = nil
            return
        end
    elseif not entry.rageCostUnknown then
        eligible = false
    end
    if eligible == true then
        if entry.rageReady == false then entry.flashStart = now end
        entry.border:SetVertexColor(0.1, 1, 0.1, 1)
        entry.rageGlow:SetAlpha(0.35)
    else
        entry.border:SetVertexColor(0.2, 0.2, 0.2, 1)
        entry.rageGlow:SetAlpha(0)
        entry.flashStart = nil
        entry.flash:SetAlpha(0)
    end
    entry.rageReady = eligible
end

local function updateStackFlashes(now)
    for _, entry in ipairs(stackOrder) do
        if entry.flashStart then
            local t = now - entry.flashStart
            if t >= STACK_FLASH_DURATION then
                entry.flashStart = nil
                entry.flash:SetAlpha(0)
            else
                entry.flash:SetAlpha(0.8 * math.abs(math.sin(t / STACK_FLASH_DURATION * 2 * math.pi)))
            end
        end
    end
end

local function clearStack()
    for _, entry in ipairs(stackOrder) do
        entry:Hide()
    end
    stackEntries = {}
    stackOrder = {}
    pendingCasts = {}
end

local function updateFloatingIcons(now)
    for index = #floatingIcons, 1, -1 do
        local icon = floatingIcons[index]
        local x = icon.offset - icon.speed * (now - icon.shownAt)
        if x <= 0 then
            releaseIcon(index)
        else
            icon.laneX = x
            icon.timer:SetText(tostring(math.min(10, math.max(1, math.ceil(now - icon.shownAt)))))
            icon:ClearAllPoints()
            icon:SetPoint("BOTTOMLEFT", iconLane, "BOTTOMLEFT", x, 0)
        end
    end
end

local function startFloatingIcon(spellID, now)
    local texture = spellIcon(spellID)
    if not texture then
        return
    end
    updateFloatingIcons(now)
    local startX = math.max(0, iconLane:GetWidth() - ICON_SIZE)
    local previous = floatingIcons[#floatingIcons]
    if previous then
        local overlap = previous.laneX + ICON_SIZE - startX
        if overlap > 0 then
            for _, icon in ipairs(floatingIcons) do
                icon.offset = icon.offset - overlap
                icon.laneX = icon.laneX - overlap
                icon:ClearAllPoints()
                icon:SetPoint("BOTTOMLEFT", iconLane, "BOTTOMLEFT", icon.laneX, 0)
            end
            updateFloatingIcons(now)
            previous = floatingIcons[#floatingIcons]
        end
    end
    local icon = acquireIcon()
    icon.shownAt = now
    icon.offset, icon.laneX = startX, startX
    icon.speed = previous and previous.speed
        or startX / ICON_TRAVEL_DURATION
    icon.texture:SetTexture(texture)
    icon.border:SetColorTexture(0.78, 0.62, 0.3, 1)
    icon.timer:SetText("1")
    icon.flash:SetAlpha(0)
    icon:SetAlpha(1)
    icon:SetScale(1)
    if icon.cooldown and icon.cooldown.Clear then icon.cooldown:Clear() end
    icon:ClearAllPoints()
    icon:SetPoint("BOTTOMLEFT", iconLane, "BOTTOMLEFT", startX, 0)
    icon:Show()
    table.insert(floatingIcons, icon)
end

local function updateCooldownIcons()
    local now = GetTime()
    updateFloatingIcons(now)
    for castGUID, sentAt in pairs(sentCasts) do
        if now - sentAt > 120 then sentCasts[castGUID] = nil end
    end

    local rage = UnitPower("player", 1)
    for _, entry in ipairs(stackOrder) do
        local castTime = pendingCasts[entry.spellID]
        local startTime, duration = readSpellCooldown(entry.spellID)
        if startTime and isTrackedCooldown(startTime, duration) and startTime + duration > now then
            if entry.ready or entry.unknownCooldown then
                setStackCooldown(entry.spellID, spellIcon(entry.spellID))
            end
            local remaining = startTime + duration - now
            setStackTimer(entry.spellID, tostring(math.ceil(remaining)))
            pendingCasts[entry.spellID] = nil
        elseif castTime and now - castTime <= 0.3 then
            -- Cooldown data may not be updated at the instant of the cast.
        elseif not startTime then
            if not entry.unknownCooldown then setStackUnknownCooldown(entry, now) end
            pendingCasts[entry.spellID] = nil
        else
            setStackReady(entry.spellID)
            pendingCasts[entry.spellID] = nil
        end
        updateStackRageReady(entry, rage, now)
    end
    updateStackFlashes(now)
end

local function onPlayerSpellAttempt(spellID, castGUID)
    if type(spellID) ~= "number" or isSecret(spellID) or IGNORED_SPELLS[spellID] then
        return
    end
    if type(castGUID) ~= "string" or isSecret(castGUID) then
        return
    end
    local now = GetTime()
    sentCasts[castGUID] = now
    startFloatingIcon(spellID, now)
end

local function onPlayerSpellCast(spellID, castGUID)
    if type(spellID) ~= "number" or isSecret(spellID) or IGNORED_SPELLS[spellID] then
        return
    end
    local wasSent = type(castGUID) == "string" and not isSecret(castGUID) and sentCasts[castGUID]
    if wasSent then sentCasts[castGUID] = nil end
    local texture = spellIcon(spellID)
    if texture then
        setStackCooldown(spellID, texture)
        updateStackRage(stackEntries[spellID])
        updateStackGCD()
        if not wasSent then startFloatingIcon(spellID, GetTime()) end
        pendingCasts[spellID] = GetTime()
    end
end

local function restorePosition()
    WarriorTrackerDB = WarriorTrackerDB or {}
    WarriorTrackerDB.locked = WarriorTrackerDB.locked == true
    frame:ClearAllPoints()
    frame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        WarriorTrackerDB.x or 0,
        WarriorTrackerDB.y or -180
    )
end

local function savePosition()
    WarriorTrackerDB = WarriorTrackerDB or {}
    -- After dragging the frame is no longer anchored to CENTER, so convert to an offset from the screen center.
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and parentX then
        WarriorTrackerDB.x = math.floor(x - parentX + 0.5)
        WarriorTrackerDB.y = math.floor(y - parentY + 0.5)
    end
end

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 460, 32
local MIN_WIDTH, MAX_WIDTH = 100, 1000
local MIN_HEIGHT, MAX_HEIGHT = 10, 80

-- Uses the saved size; without one the bar copies the built-in swing timer size.
local function applySize()
    local db = WarriorTrackerDB or {}
    if not (db.width and db.height) then
        frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        matchSwingTimerSize()
    end
    local width, height = frame:GetSize()
    frame:SetSize(db.width or width, db.height or height)
end

local settingsFrame
local refreshSettings = function() end

local function createFrameSafe(frameType, parent, template)
    if template then
        local ok, created = pcall(CreateFrame, frameType, nil, parent, template)
        if ok and created then
            return created, true
        end
    end
    return CreateFrame(frameType, nil, parent), false
end

-- Slider with a caption and an edit box for typing an exact value.
local function createSettingRow(parent, caption, minValue, maxValue, top, onChange)
    local row = {}
    row.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    applyAddonFont(row.label)
    row.label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, top)
    row.label:SetText(caption)

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(200, 16)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, top - 20)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(6)
    track:SetColorTexture(0.15, 0.15, 0.15, 1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta)
    end)
    row.slider = slider

    local editBox = createFrameSafe("EditBox", parent, "InputBoxTemplate")
    editBox:SetSize(60, 20)
    editBox:SetPoint("LEFT", slider, "RIGHT", 16, 0)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetJustifyH("CENTER")
    row.editBox = editBox

    local function setValue(value)
        value = math.floor(math.min(maxValue, math.max(minValue, value)) + 0.5)
        row.updating = true
        slider:SetValue(value)
        editBox:SetText(tostring(value))
        row.updating = false
        return value
    end
    row.setValue = setValue

    slider:SetScript("OnValueChanged", function(_, value)
        if row.updating then
            return
        end
        onChange(setValue(value))
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            onChange(setValue(value))
        end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        refreshSettings()
    end)
    return row
end

local function createSettingsFrame()
    local panel, templated = createFrameSafe("Frame", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(340, 400)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    if not templated then
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(panel)
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
        local close = createFrameSafe("Button", panel, "UIPanelCloseButton")
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
        close:SetScript("OnClick", function() panel:Hide() end)
    end
    if _G.UISpecialFrames then
        _G.WarriorTrackerSettingsFrame = panel
        table.insert(_G.UISpecialFrames, "WarriorTrackerSettingsFrame")
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    applyAddonFont(title)
    title:SetPoint("TOP", panel, "TOP", 0, -6)
    panel.title = title

    local function db()
        WarriorTrackerDB = WarriorTrackerDB or {}
        return WarriorTrackerDB
    end

    local halfWidth = math.floor((UIParent:GetWidth() or 2000) / 2)
    local halfHeight = math.floor((UIParent:GetHeight() or 1200) / 2)

    panel.widthRow = createSettingRow(panel, L("width"), MIN_WIDTH, MAX_WIDTH, -36, function(value)
        db().width = value
        db().height = db().height or math.floor(frame:GetHeight() + 0.5)
        applySize()
    end)
    panel.heightRow = createSettingRow(panel, L("height"), MIN_HEIGHT, MAX_HEIGHT, -86, function(value)
        db().height = value
        db().width = db().width or math.floor(frame:GetWidth() + 0.5)
        applySize()
    end)
    panel.xRow = createSettingRow(panel, L("x"), -halfWidth, halfWidth, -136, function(value)
        db().x = value
        restorePosition()
    end)
    panel.yRow = createSettingRow(panel, L("y"), -halfHeight, halfHeight, -186, function(value)
        db().y = value
        restorePosition()
    end)

    local lockCheck, checkTemplated = createFrameSafe("CheckButton", panel, "UICheckButtonTemplate")
    if not checkTemplated then
        lockCheck:SetSize(24, 24)
        lockCheck:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        lockCheck:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    lockCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -236)
    local lockText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    applyAddonFont(lockText)
    lockText:SetPoint("LEFT", lockCheck, "RIGHT", 4, 0)
    panel.lockText = lockText
    lockCheck:SetScript("OnClick", function(self)
        db().locked = self:GetChecked() and true or false
    end)
    panel.lockCheck = lockCheck

    local resetButton = createFrameSafe("Button", panel, "UIPanelButtonTemplate")
    resetButton:SetSize(140, 24)
    resetButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 20)
    applyAddonFont(resetButton:GetFontString())
    panel.resetButton = resetButton
    resetButton:SetScript("OnClick", function()
        local saved = db()
        saved.width, saved.height, saved.x, saved.y = nil, nil, 0, -180
        applySize()
        restorePosition()
        refreshSettings()
    end)

    local closeButton = createFrameSafe("Button", panel, "UIPanelButtonTemplate")
    closeButton:SetSize(100, 24)
    closeButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 20)
    applyAddonFont(closeButton:GetFontString())
    panel.closeButton = closeButton
    closeButton:SetScript("OnClick", function() panel:Hide() end)

    local languageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    applyAddonFont(languageLabel)
    languageLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -274)
    panel.languageLabel = languageLabel

    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetSize(160, 24)
    dropdown:SetPoint("LEFT", languageLabel, "RIGHT", 12, 0)
    dropdown:SetupMenu(function(_, root)
        local function selected(value)
            return (db().language == "en" and "en" or "cs") == value
        end
        local function selectLanguage(value)
            db().language = value
            refreshSettings()
        end
        root:CreateRadio("Cestina", selected, selectLanguage, "cs")
        root:CreateRadio("English", selected, selectLanguage, "en")
    end)
    panel.languageDropdown = dropdown

    panel:SetScript("OnShow", function() refreshSettings() end)
    return panel
end

refreshSettings = function()
    if not (settingsFrame and settingsFrame:IsShown()) then
        return
    end
    local db = WarriorTrackerDB or {}
    settingsFrame.title:SetText(L("title"))
    settingsFrame.widthRow.label:SetText(L("width"))
    settingsFrame.heightRow.label:SetText(L("height"))
    settingsFrame.xRow.label:SetText(L("x"))
    settingsFrame.yRow.label:SetText(L("y"))
    settingsFrame.lockText:SetText(L("lock"))
    settingsFrame.resetButton:SetText(L("reset"))
    settingsFrame.closeButton:SetText(L("close"))
    settingsFrame.languageLabel:SetText(L("language"))
    local width, height = frame:GetSize()
    settingsFrame.widthRow.setValue(db.width or width)
    settingsFrame.heightRow.setValue(db.height or height)
    settingsFrame.xRow.setValue(db.x or 0)
    settingsFrame.yRow.setValue(db.y or -180)
    settingsFrame.lockCheck:SetChecked(db.locked == true)
end

local function toggleSettings()
    if not settingsFrame then
        settingsFrame = createSettingsFrame()
        settingsFrame:Hide()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
        refreshSettings()
    end
end

local function exactDistance()
    if type(UnitDistanceSquared) ~= "function" then
        return nil
    end

    local distanceSquared, checked = UnitDistanceSquared("target")
    if checked == true and type(distanceSquared) == "number" and distanceSquared >= 0 then
        return math.sqrt(distanceSquared)
    end
end

local function unitMapPosition(unit)
    if type(UnitPosition) ~= "function" then
        return nil
    end

    local ok, y, x, z, instanceID = pcall(UnitPosition, unit)
    if ok and type(x) == "number" and type(y) == "number" then
        return x, y, type(z) == "number" and z or 0, instanceID
    end
end

local function positionDistance()
    local px, py, pz, pInstance = unitMapPosition("player")
    local tx, ty, tz, tInstance = unitMapPosition("target")
    if not px or not tx or pInstance ~= tInstance then
        return nil
    end

    local distance = math.sqrt((tx - px) ^ 2 + (ty - py) ^ 2 + (tz - pz) ^ 2)
    if distance > 0 then
        return distance
    end
end

local function progressForDistance(distance)
    return math.max(0, math.min(1, (FAR_RANGE - distance) / (FAR_RANGE - MAX_RANGE)))
end

local function checkItemRange(itemIDs)
    local isItemInRange = (C_Item and C_Item.IsItemInRange) or IsItemInRange
    if type(isItemInRange) ~= "function" then
        return nil
    end

    for _, itemID in ipairs(itemIDs) do
        local ok, result = pcall(function()
            local inRange = isItemInRange(itemID, "target")
            if inRange == true or inRange == 1 then
                return true
            elseif inRange == false or inRange == 0 then
                return false
            end
        end)
        if ok and result ~= nil then
            return result
        end
    end
end

local function checkFallbackRange(check)
    if check.spellID and C_Spell and type(C_Spell.IsSpellInRange) == "function" then
        local inRange = C_Spell.IsSpellInRange(check.spellID)
        if type(inRange) == "boolean" then
            return inRange
        end
    end

    if check.spellName and type(IsSpellInRange) == "function" then
        local inRange = IsSpellInRange(check.spellName, "target")
        if inRange == true or inRange == 1 then
            return true
        elseif inRange == false or inRange == 0 then
            return false
        end
    end

    if check.interactIndex and type(CheckInteractDistance) == "function" then
        local inRange = CheckInteractDistance("target", check.interactIndex)
        if type(inRange) == "boolean" then
            return inRange
        elseif inRange == 1 then
            return true
        elseif inRange == 0 then
            return false
        end
    end
end

local RANGED_SPELLS = { [2] = 2480, [3] = 7918, [18] = 7919, [16] = 2764 }
local function rangedWeaponInRange(unit)
    if not (C_Item and type(C_Item.GetItemInfoInstant) == "function"
        and type(GetInventoryItemID) == "function"
        and C_Spell and type(C_Spell.IsSpellInRange) == "function"
        and type(C_Spell.IsSpellUsable) == "function") then
        return nil
    end
    local itemID = GetInventoryItemID("player", 18)
    if not itemID or isSecret(itemID) then
        return nil
    end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if isSecret(classID) or isSecret(subclassID) or classID ~= 2 then
        return nil
    end
    local spellID = RANGED_SPELLS[subclassID]
    if not spellID then
        return nil
    end
    local usable = C_Spell.IsSpellUsable(spellID)
    if isSecret(usable) or not usable then
        return nil
    end
    local inRange = C_Spell.IsSpellInRange(spellID, unit)
    if isSecret(inRange) or type(inRange) ~= "boolean" then
        return nil
    end
    return inRange
end

local function fallbackDistanceBand(hostileTarget)
    local lowerBound = 0
    local upperBound = MAX_RANGE
    local checksUsed = 0

    for _, check in ipairs(FALLBACK_CHECKS) do
        if not check.friendlyOnly and not check.hostileOnly
            or (hostileTarget and check.hostileOnly)
            or (not hostileTarget and check.friendlyOnly)
        then
            local inRange = checkFallbackRange(check)
            if inRange ~= nil then
                checksUsed = checksUsed + 1
                if inRange then
                    upperBound = math.min(upperBound, check.range)
                else
                    lowerBound = math.max(lowerBound, check.range)
                end
            end
        end
    end

    if checksUsed == 0 or lowerBound > upperBound then
        return nil
    end

    local estimatedDistance = (lowerBound + upperBound) / 2
    local progress = math.max(0, math.min(1, 1 - estimatedDistance / MAX_RANGE))
    return lowerBound, upperBound, progress
end

local function reportRangeDebug()
    if not UnitExists("target") then
        print("Warrior Tracker: " .. L("debugSelect"))
        return
    end

    print("Warrior Tracker: " .. L("debugTarget") .. (UnitName("target") or "?"))
    if type(UnitDistanceSquared) == "function" then
        local distanceSquared, checked = UnitDistanceSquared("target")
        print("UnitDistanceSquared: " .. tostring(distanceSquared) .. ", checked=" .. tostring(checked))
    else
        print(L("debugNoApi"))
    end

    local hostileTarget = UnitCanAttack and UnitCanAttack("player", "target")
    local px, py, _, pInstance = unitMapPosition("player")
    local tx, ty, _, tInstance = unitMapPosition("target")
    print(string.format("UnitPosition player: %s, %s (%s)", tostring(px), tostring(py), tostring(pInstance)))
    print(string.format("UnitPosition target: %s, %s (%s)", tostring(tx), tostring(ty), tostring(tInstance)))

    if hostileTarget then
        for _, threshold in ipairs(HOSTILE_THRESHOLDS) do
            local result
            if threshold.itemIDs then
                result = checkItemRange(threshold.itemIDs)
            else
                result = checkFallbackRange(threshold)
            end
            local name = threshold.spellName or L("debugItem")
            print(string.format(L("debugThreshold"), threshold.range, name, tostring(result)))
        end
        print(L("debugMeleeItems") .. tostring(checkItemRange(MELEE_ITEMS)))
        for _, spell in ipairs(MELEE_SPELLS) do
            print(string.format(L("debugMelee"), spell.spellName, tostring(checkFallbackRange(spell))))
        end
    end

    for _, check in ipairs(FALLBACK_CHECKS) do
        if not check.friendlyOnly and not check.hostileOnly
            or (hostileTarget and check.hostileOnly)
            or (not hostileTarget and check.friendlyOnly)
        then
            local result = checkFallbackRange(check)
            local name = check.spellName or (L("debugInteraction") .. check.interactIndex)
            print(string.format("%s (%s yd): %s", name, check.range, tostring(result)))
        end
    end
end

local function hostileRangeBand()
    local lowerBound = 0
    local upperBound
    local checksUsed = 0

    for _, threshold in ipairs(HOSTILE_THRESHOLDS) do
        local inRange
        if threshold.itemIDs then
            inRange = checkItemRange(threshold.itemIDs)
        else
            inRange = checkFallbackRange(threshold)
        end

        if inRange ~= nil then
            checksUsed = checksUsed + 1
            if inRange then
                upperBound = math.min(upperBound or threshold.range, threshold.range)
            else
                lowerBound = math.max(lowerBound, threshold.range)
            end
        end
    end

    if checksUsed == 0 or (upperBound and lowerBound > upperBound) then
        return nil
    end
    return lowerBound, upperBound
end

-- Estimates the distance inside a known band from how far the player moved since the last band crossing.
local estimator = {}

local function resetEstimator()
    estimator = {}
end

local function estimateDistanceInBand(lowerBound, upperBound, elapsed)
    if upperBound == nil then
        resetEstimator()
        return nil
    end

    if estimator.lowerBound ~= lowerBound or estimator.upperBound ~= upperBound then
        local movedOutward = estimator.upperBound ~= nil and lowerBound >= estimator.upperBound
        estimator.anchorDistance = movedOutward and lowerBound or upperBound
        estimator.direction = movedOutward and 1 or -1
        estimator.lowerBound = lowerBound
        estimator.upperBound = upperBound
        estimator.travelled = 0
        estimator.anchorX, estimator.anchorY = unitMapPosition("player")
    end

    local x, y = unitMapPosition("player")
    if estimator.anchorX and x then
        estimator.travelled = math.sqrt((x - estimator.anchorX) ^ 2 + (y - estimator.anchorY) ^ 2)
    elseif type(GetUnitSpeed) == "function" then
        estimator.travelled = estimator.travelled + (GetUnitSpeed("player") or 0) * elapsed
    end

    local estimate = estimator.anchorDistance + estimator.direction * estimator.travelled
    return math.max(lowerBound, math.min(upperBound, estimate))
end

local function setTargetProgress(progress)
    frame.targetProgress = progress
end

local function setZone(zone)
    frame.zoneNow = zone
end

local function meleeStatus()
    local inRange = checkItemRange(MELEE_ITEMS)
    if inRange ~= nil then
        return inRange
    end
    for _, spell in ipairs(MELEE_SPELLS) do
        inRange = checkFallbackRange(spell)
        if inRange ~= nil then
            return inRange
        end
    end
end

local function computeBar(elapsed)
    elapsed = elapsed or 0

    if not UnitExists("target") then
        resetEstimator()
        frame.hasTarget = false
        setTargetProgress(0)
        label:SetText(L("noTarget"))
        return
    end

    frame.hasTarget = true

    local targetName = UnitName("target") or "Target"
    local hostileTarget = UnitCanAttack and UnitCanAttack("player", "target")
    local distance = exactDistance() or positionDistance()
    local melee = hostileTarget and meleeStatus() == true
    local ranged = hostileTarget and rangedWeaponInRange("target") == true

    if distance ~= nil then
        resetEstimator()
        setTargetProgress(progressForDistance(distance))
        if hostileTarget and (melee or distance <= MELEE_RANGE) then
            setZone("melee")
            label:SetText(string.format("%s  |  %.1f yd  |  %s", targetName, distance, L("melee")))
        elseif ranged then
            setZone("ranged")
            label:SetText(string.format("%s  |  %.1f yd  |  %s", targetName, distance, L("inRange")))
        elseif distance > MAX_RANGE then
            label:SetText(string.format(
                "%s  |  %.1f yd  |  %s",
                targetName,
                distance,
                string.format(L("missing"), distance - MAX_RANGE)
            ))
        else
            label:SetText(string.format("%s  |  %.1f yd  |  %s", targetName, distance, L("unknown")))
        end
        return
    end

    if hostileTarget then
        if melee then
            resetEstimator()
            setTargetProgress(1)
            setZone("melee")
            label:SetText(string.format("%s  |  <=%d yd  |  %s", targetName, MELEE_RANGE, L("melee")))
            return
        elseif ranged then
            resetEstimator()
            setTargetProgress(1)
            setZone("ranged")
            label:SetText(string.format("%s  |  %s", targetName, L("inRange")))
            return
        end

        local lowerBound, upperBound = hostileRangeBand()
        if lowerBound == nil then
            resetEstimator()
            setTargetProgress(0)
            label:SetText(string.format("%s  |  ? yd  |  %s", targetName, L("unknown")))
        elseif upperBound == nil then
            resetEstimator()
            setTargetProgress(0)
            label:SetText(string.format("%s  |  >%.0f yd  |  %s", targetName, lowerBound, L("outOfRange")))
        else
            local estimate = estimateDistanceInBand(lowerBound, upperBound, elapsed)
            setTargetProgress(progressForDistance(estimate))
            local text = estimate > MAX_RANGE and string.format(L("missingEstimate"), estimate - MAX_RANGE) or L("unknown")
            label:SetText(string.format("%s  |  ~%.0f yd  |  %s", targetName, estimate, text))
        end
        return
    end

    resetEstimator()
    local lowerBound, upperBound, progress = fallbackDistanceBand(hostileTarget)
    if lowerBound == nil then
        setTargetProgress(0)
        label:SetText(string.format("%s  |  ~? yd", targetName))
        return
    end

    local rangeText
    if lowerBound >= MAX_RANGE then
        rangeText = string.format(">%.0f yd", MAX_RANGE)
    elseif upperBound <= 5 then
        rangeText = "<=5 yd"
    elseif lowerBound > 0 then
        rangeText = string.format("~%.0f-%.0f yd", lowerBound, upperBound)
    else
        rangeText = string.format("~0-%.0f yd", upperBound)
    end

    setTargetProgress(progress)
    label:SetText(string.format("%s  |  %s", targetName, rangeText))
end

local FLASH_DURATION = 0.6

local function applyZoneStyle(zone)
    local style = ZONE_STYLES[zone or "ranged"]
    statusBar:SetStatusBarColor(style.fill[1], style.fill[2], style.fill[3], 1)
    rangeGlow:SetColorTexture(style.glow[1], style.glow[2], style.glow[3], 0.9)
    rangeFlash:SetColorTexture(style.flash[1], style.flash[2], style.flash[3], 1)
end

local function updateBar(elapsed)
    frame.zoneNow = nil
    computeBar(elapsed)
    updateMarkIcon()

    local zone = frame.zoneNow
    if zone ~= frame.zone then
        applyZoneStyle(zone)
        if zone then
            frame.flashStart = GetTime()
        end
    end
    frame.zone = zone

    if zone == "ranged" or zone == "melee" then
        setBarState("inRange")
        rangeGlow:Show()
    else
        setBarState(frame.hasTarget and "outOfRange" or "none")
        rangeGlow:Hide()
        frame.flashStart = nil
    end
end

local function updateRangeFlash()
    if not frame.flashStart then
        rangeFlash:SetAlpha(0)
        return
    end

    local t = GetTime() - frame.flashStart
    if t >= FLASH_DURATION then
        frame.flashStart = nil
        rangeFlash:SetAlpha(0)
        return
    end

    -- Two quick pulses.
    rangeFlash:SetAlpha(0.8 * math.abs(math.sin(t / FLASH_DURATION * 2 * math.pi)))
end

frame:SetScript("OnDragStart", function(self)
    if not WarriorTrackerDB or not WarriorTrackerDB.locked then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if WarriorTrackerDB then
        savePosition()
        restorePosition()
        refreshSettings()
    end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SENT" then
        local _, _, castGUID, spellID = ...
        onPlayerSpellAttempt(spellID, castGUID)
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        onPlayerSpellCast(spellID, castGUID)
        return
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local _, castGUID = ...
        if type(castGUID) == "string" and not isSecret(castGUID) then sentCasts[castGUID] = nil end
        return
    end
    if event == "PLAYER_LOGIN" then
        restorePosition()
        if C_Spell and type(C_Spell.EnableSpellRangeCheck) == "function" then
            for _, check in ipairs(FALLBACK_CHECKS) do
                if check.spellID then
                    C_Spell.EnableSpellRangeCheck(check.spellID, true)
                end
            end
            for _, spell in ipairs(MELEE_SPELLS) do
                pcall(C_Spell.EnableSpellRangeCheck, spell.spellID, true)
            end
        end
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            for _, threshold in ipairs(HOSTILE_THRESHOLDS) do
                for _, itemID in ipairs(threshold.itemIDs or {}) do
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
            end
            for _, list in ipairs({ MELEE_ITEMS }) do
                for _, itemID in ipairs(list) do
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
            end
        end
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        applySize()
    end
    if event == "PLAYER_TARGET_CHANGED" then
        resetEstimator()
        updateBar(0)
        frame.displayedProgress = frame.targetProgress or 0
        statusBar:SetValue(frame.displayedProgress)
        return
    end
    updateBar(0)
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= UPDATE_INTERVAL then
        local checkElapsed = self.elapsed
        self.elapsed = 0
        updateBar(checkElapsed)
    end

    local targetProgress = self.targetProgress or 0
    local displayedProgress = self.displayedProgress or 0
    displayedProgress = displayedProgress
        + (targetProgress - displayedProgress) * math.min(1, elapsed * ANIMATION_SPEED)
    if math.abs(targetProgress - displayedProgress) < 0.001 then
        displayedProgress = targetProgress
    end
    self.displayedProgress = displayedProgress
    statusBar:SetValue(displayedProgress)
    updateRangeFlash()
    updateCooldownIcons()
end)

SLASH_WARRIORTRACKER1 = "/wt"
SLASH_WARRIORTRACKER2 = "/wrt"
SlashCmdList.WARRIORTRACKER = function(message)
    local command = strtrim and strtrim(string.lower(message or "")) or string.lower(message or "")
    if command == "" or command == "config" or command == "nastaveni" then
        toggleSettings()
    elseif command == "lock" or command == "unlock" then
        WarriorTrackerDB = WarriorTrackerDB or {}
        if command == "unlock" then
            WarriorTrackerDB.locked = false
        else
            WarriorTrackerDB.locked = not WarriorTrackerDB.locked
        end
        print("Warrior Tracker: " .. L(WarriorTrackerDB.locked and "locked" or "unlocked"))
        refreshSettings()
    elseif command == "reset" then
        WarriorTrackerDB = WarriorTrackerDB or {}
        WarriorTrackerDB.x = 0
        WarriorTrackerDB.y = -180
        restorePosition()
        refreshSettings()
        print(L("positionReset"))
    elseif command == "debug" then
        reportRangeDebug()
    elseif command == "clear" then
        clearStack()
        print(L("stackCleared"))
    else
        print(L("commands"))
    end
end

-- Entry in Esc > Options > AddOns that opens the settings window.
if Settings and type(Settings.RegisterCanvasLayoutCategory) == "function" and type(Settings.RegisterAddOnCategory) == "function" then
    local optionsPanel = CreateFrame("Frame")
    optionsPanel.name = "Warrior Tracker"
    local optionsTitle = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    optionsTitle:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 16, -16)
    optionsTitle:SetText("Warrior Tracker")
    local openButton = createFrameSafe("Button", optionsPanel, "UIPanelButtonTemplate")
    openButton:SetSize(180, 24)
    openButton:SetPoint("TOPLEFT", optionsTitle, "BOTTOMLEFT", 0, -12)
    applyAddonFont(openButton:GetFontString())
    optionsPanel:SetScript("OnShow", function()
        openButton:SetText(L("openSettings"))
    end)
    openButton:SetScript("OnClick", function()
        if HideUIPanel and _G.SettingsPanel then
            HideUIPanel(_G.SettingsPanel)
        end
        if not (settingsFrame and settingsFrame:IsShown()) then
            toggleSettings()
        end
    end)
    pcall(function()
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Warrior Tracker")
        Settings.RegisterAddOnCategory(category)
    end)
end

-- Clickable list of enemies targeted outside combat, stacked upward left of the bar.
-- Left click targets by name; right click marks the row for removal.
-- Secure buttons cannot be changed in combat, so removals are deferred until combat ends.
do
    local BUTTON_WIDTH, BUTTON_HEIGHT, BUTTON_GAP = 214, 22, 2
    local SIDE = BUTTON_HEIGHT -- pet button (left) and mark button (right) are square
    local DISTANCE_WIDTH = 30
    local BAR_LEFT = SIDE + 4
    local BAR_WIDTH = BUTTON_WIDTH - BAR_LEFT - DISTANCE_WIDTH - SIDE - 1
    local PET_ICON = "Interface\\Icons\\Ability_Hunter_Pet_Cat"
    local SKULL, CROSS = 8, 7
    local MARK_ICON_ROOM = 39 + 8 -- space kept free for the Hunter's Mark icon left of the bar
    local ROW = BUTTON_HEIGHT + BUTTON_GAP
    local ITEMS_45 = HOSTILE_THRESHOLDS[1].itemIDs
    local ITEMS_100 = HOSTILE_THRESHOLDS[2].itemIDs

    local SCAN_UNITS = { "target", "mouseover", "focus", "targettarget", "pettarget" }
    for index = 1, 40 do
        table.insert(SCAN_UNITS, "nameplate" .. index)
    end

    local function inCombat()
        return type(InCombatLockdown) == "function" and InCombatLockdown()
    end

    local list = CreateFrame("Frame", "WarriorTrackerTargetList", UIParent)
    list:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    list:SetFrameStrata("MEDIUM")
    list:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)

    local tooltipFont = CreateFont("WarriorTrackerTooltipFont")
    tooltipFont:SetFontObject(GameTooltipHeaderText)
    local _, tooltipSize, tooltipFlags = GameTooltipHeaderText:GetFont()
    if not tooltipFont:SetFont(FONT_PATH, tooltipSize, tooltipFlags) then
        print("WarriorTracker: " .. L("fontError"))
    end
    local listTooltip = CreateFrame("GameTooltip", "WarriorTrackerListTooltip", UIParent, "GameTooltipTemplate")
    listTooltip.textLeft1Font = "WarriorTrackerTooltipFont"

    local function showListTooltip(owner, text)
        listTooltip:SetOwner(owner, "ANCHOR_TOP")
        listTooltip:SetText(text)
        listTooltip.TextLeft1:SetFontObject(tooltipFont)
        listTooltip:Show()
    end

    local entries = {}
    local layout
    local needsLayout = false
    local CLOSE_DELAY = 0.5

    -- Health colour by remaining health; works with secret values (evaluated by the game).
    local healthCurve
    pcall(function()
        healthCurve = C_CurveUtil.CreateColorCurve()
        healthCurve:SetType(Enum.LuaCurveType.Linear)
        healthCurve:AddPoint(0, CreateColor(0.85, 0.1, 0.1))
        healthCurve:AddPoint(0.5, CreateColor(0.9, 0.8, 0.1))
        healthCurve:AddPoint(1, CreateColor(0.15, 0.75, 0.1))
    end)
    local percentCurve = CurveConstants and CurveConstants.ScaleTo100

    local function squareIcon(row, layer)
        local icon = row:CreateTexture(nil, layer)
        icon:SetSize(SIDE - 2, SIDE - 2)
        return icon
    end

    -- Row: [pet][range stripe][health bar: name ... %][distance][raid mark]
    local function decorate(row)
        row:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)

        row.edge = row:CreateTexture(nil, "BACKGROUND", nil, -1)
        row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", -1, 1)
        row.edge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 1, -1)
        row.edge:SetColorTexture(0, 0, 0, 1)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints(row)
        row.background:SetColorTexture(0.08, 0.08, 0.08, 0.95)

        row.petIcon = squareIcon(row, "ARTWORK")
        row.petIcon:SetPoint("LEFT", row, "LEFT", 1, 0)
        row.petIcon:SetTexture(PET_ICON)
        row.petIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Stripe: green = Arcane Shot range, yellow = up to 45 yd, red = up to 100 yd, grey = unknown.
        row.rangeStripe = row:CreateTexture(nil, "ARTWORK")
        row.rangeStripe:SetPoint("TOPLEFT", row, "TOPLEFT", SIDE, 0)
        row.rangeStripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", SIDE, 0)
        row.rangeStripe:SetWidth(3)

        row.healthBack = row:CreateTexture(nil, "BORDER")
        row.healthBack:SetPoint("TOPLEFT", row, "TOPLEFT", BAR_LEFT, -1)
        row.healthBack:SetSize(BAR_WIDTH, BUTTON_HEIGHT - 2)
        row.healthBack:SetColorTexture(0.25, 0.04, 0.04, 1)

        -- StatusBar accepts the secret health values of this client; it does not take mouse clicks.
        row.health = CreateFrame("StatusBar", nil, row)
        row.health:EnableMouse(false)
        row.health:SetAllPoints(row.healthBack)
        row.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        row.health:SetMinMaxValues(0, 1)
        row.health:SetValue(1)

        row.over = CreateFrame("Frame", nil, row)
        row.over:EnableMouse(false)
        row.over:SetAllPoints(row)
        row.over:SetFrameLevel(row.health:GetFrameLevel() + 1)

        row.nameText = row.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameText:SetPoint("LEFT", row.healthBack, "LEFT", 4, 0)
        row.nameText:SetPoint("RIGHT", row.healthBack, "RIGHT", -34, 0)
        row.nameText:SetJustifyH("LEFT")
        if row.nameText.SetWordWrap then
            row.nameText:SetWordWrap(false)
        end
        row.healthText = row.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.healthText:SetPoint("RIGHT", row.healthBack, "RIGHT", -3, 0)
        row.healthText:SetJustifyH("RIGHT")

        row.distanceBox = row:CreateTexture(nil, "BORDER")
        row.distanceBox:SetPoint("TOPLEFT", row.healthBack, "TOPRIGHT", 1, 1)
        row.distanceBox:SetSize(DISTANCE_WIDTH, BUTTON_HEIGHT)
        row.distanceBox:SetColorTexture(0.12, 0.12, 0.12, 1)
        row.rangeText = row.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.rangeText:SetPoint("CENTER", row.distanceBox, "CENTER", 0, 0)

        row.markSlot = row:CreateTexture(nil, "BORDER")
        row.markSlot:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.markSlot:SetSize(SIDE, SIDE)
        row.markSlot:SetColorTexture(0.16, 0.16, 0.16, 1)
        row.raidIcon = row.over:CreateTexture(nil, "OVERLAY")
        row.raidIcon:SetPoint("CENTER", row.markSlot, "CENTER", 0, 0)
        row.raidIcon:SetSize(SIDE - 4, SIDE - 4)
        row.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

        row.targetGlow = row.over:CreateTexture(nil, "OVERLAY", nil, 1)
        row.targetGlow:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 2)
        row.targetGlow:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -2)
        row.targetGlow:SetColorTexture(1, 0.82, 0, 0.3)
        row.targetGlow:SetBlendMode("ADD")
        row.targetGlow:Hide()

        row.closeFlash = row.over:CreateTexture(nil, "OVERLAY", nil, 3)
        row.closeFlash:SetAllPoints(row)
        row.closeFlash:SetColorTexture(1, 0.15, 0.1, 1)
        row.closeFlash:Hide()

        row.hover = row.over:CreateTexture(nil, "OVERLAY", nil, 2)
        row.hover:SetAllPoints(row)
        row.hover:SetColorTexture(1, 1, 1, 0.1)
        row.hover:Hide()
        row:HookScript("OnEnter", function() row.hover:Show() end)
        row:HookScript("OnLeave", function() row.hover:Hide() end)
        row:Hide()
        return row
    end

    -- Small secure button over the pet / mark square of a clickable row.
    local function addSideButton(row, anchorPoint, tooltipKey, name)
        local ok, button = pcall(CreateFrame, "Button", name, row, "SecureActionButtonTemplate")
        if not ok or not button then
            return nil
        end
        button:SetSize(SIDE, SIDE)
        button:SetPoint(anchorPoint, row, anchorPoint, 0, 0)
        button:SetFrameLevel(row.over:GetFrameLevel() + 2)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- Add-on secure buttons otherwise follow the ActionButtonUseKeyDown CVar and act only on mouse down.
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("type", "macro")
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(1, 1, 1, 0.25)
        button:SetScript("OnEnter", function(self)
            showListTooltip(self, L(tooltipKey))
        end)
        button:SetScript("OnLeave", function()
            listTooltip:Hide()
        end)
        return button
    end
    local function placeRow(row, slot, entry)
        row.entry = entry
        entry.row = row
        entry.slot = slot
        row:ClearAllPoints()
        row:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 0, (slot - 1) * ROW)
        row:SetAlpha(1)
        row.closeFlash:SetShown(entry.closingAt ~= nil)
        row:Show()
    end

    -- Takes the row away from the entry. Secure rows cannot be hidden in combat, so they only become invisible.
    local function releaseRow(entry)
        local row = entry.row
        entry.row = nil
        if not row then
            return
        end
        row.entry = nil
        row.closeFlash:Hide()
        if row.secure and inCombat() then
            row:SetAlpha(0)
        else
            row:Hide()
        end
    end

    local function dropEntry(entry)
        if not entry or entry.closingAt then
            return
        end
        entry.closingAt = GetTime()
        if entry.row then
            entry.row.closeFlash:SetAlpha(0.65)
            entry.row.closeFlash:Show()
        end
    end

    local function updateClosingRows(now)
        local removed = false
        for index = #entries, 1, -1 do
            local entry = entries[index]
            if entry.closingAt then
                local elapsed = now - entry.closingAt
                if elapsed >= CLOSE_DELAY and not inCombat() then
                    table.remove(entries, index)
                    releaseRow(entry)
                    removed = true
                elseif entry.row and elapsed >= CLOSE_DELAY then
                    entry.row.closeFlash:SetAlpha(0.55)
                elseif entry.row then
                    entry.row.closeFlash:SetAlpha(0.25 + 0.4 * math.abs(math.cos(elapsed / CLOSE_DELAY * math.pi)))
                end
            end
        end
        if removed then
            layout()
        end
    end

    -- Ctrl+left click gives the next unused mark (cross, square, moon, …).
    -- The choice runs in a secure snippet so it works in combat too; marks in use are kept as attributes
    -- "used1".."used7" on the protected header and re-read from the game out of combat when readable.
    local POOL_SNIPPET = [[
        if button ~= "LeftButton" or not IsControlKeyDown() or IsShiftKeyDown() then
            return
        end
        local current = self:GetAttribute("hrb-mark")
        if current then
            owner:SetAttribute("used" .. current, nil)
        end
        local mark
        for index = 7, 1, -1 do
            if index ~= current and not owner:GetAttribute("used" .. index) then
                mark = index
                break
            end
        end
        if not mark then
            for index = 1, 7 do
                owner:SetAttribute("used" .. index, nil)
            end
            mark = (current == 7) and 6 or 7
        end
        owner:SetAttribute("used" .. mark, true)
        self:SetAttribute("hrb-mark", mark)
        if self:GetAttribute("unit") then
            self:SetAttribute("ctrl-marker1", mark)
        end
    ]]
    local markPool
    do
        local ok, header = pcall(CreateFrame, "Frame", "WarriorTrackerMarkPool", UIParent, "SecureHandlerBaseTemplate")
        if ok and header and type(SecureHandlerWrapScript) == "function" then
            markPool = header
        end
    end

    local function wrapMarkButton(markButton)
        if markPool and markButton then
            local ok = pcall(SecureHandlerWrapScript, markButton, "OnClick", markPool, POOL_SNIPPET)
            markButton.pooled = ok
        end
    end

    -- Dice button left of the first row: hands out skull, cross, square, … to the listed enemies in random order.
    -- A secure snippet shuffles the rows on every click (works in combat too) and writes marker4 into each row's
    -- mark button; the dice macro then clicks those mark buttons with Button4 (secure "raidtarget" action).
    local RANDOM_SNIPPET = [[
        local count = owner:GetAttribute("count") or 0
        local order = newtable()
        for index = 1, count do
            order[index] = index
        end
        for index = count, 2, -1 do
            local other = math.random(index)
            order[index], order[other] = order[other], order[index]
        end
        for index = 1, 7 do
            owner:SetAttribute("used" .. index, nil)
        end
        for slot = 1, count do
            local markButton = owner:GetFrameRef("m" .. order[slot])
            local mark = 9 - slot
            if markButton then
                if mark >= 1 then
                    local bound = markButton:GetAttribute("unit")
                    markButton:SetAttribute("type4", bound and "raidtarget" or nil)
                    markButton:SetAttribute("marker4", bound and mark or nil)
                    if mark <= 7 then
                        markButton:SetAttribute("hrb-mark", mark)
                        owner:SetAttribute("used" .. mark, true)
                    else
                        markButton:SetAttribute("hrb-mark", nil)
                    end
                else
                    markButton:SetAttribute("type4", nil)
                    markButton:SetAttribute("marker4", nil)
                end
            end
        end
    ]]
    local diceButton
    if markPool then
        local ok, button = pcall(CreateFrame, "Button", "WarriorTrackerMarkDice", list, "SecureActionButtonTemplate")
        if ok and button then
            diceButton = button
            button:SetSize(BUTTON_HEIGHT, BUTTON_HEIGHT)
            button:SetPoint("BOTTOMRIGHT", list, "BOTTOMLEFT", -4, 0)
            button:RegisterForClicks("LeftButtonUp")
            button:SetAttribute("useOnKeyDown", false)
            button:SetAttribute("type", "macro")
            local edge = button:CreateTexture(nil, "BACKGROUND")
            edge:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
            edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
            edge:SetColorTexture(0, 0, 0, 1)
            local back = button:CreateTexture(nil, "BORDER")
            back:SetAllPoints(button)
            back:SetColorTexture(0.12, 0.12, 0.12, 0.95)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(button)
            highlight:SetColorTexture(1, 1, 1, 0.25)
            button:SetScript("OnEnter", function(self)
                showListTooltip(self, L("dice"))
            end)
            button:SetScript("OnLeave", function()
                listTooltip:Hide()
            end)
            if not pcall(SecureHandlerWrapScript, button, "OnClick", markPool, RANDOM_SNIPPET) then
                diceButton = nil
                button:Hide()
            else
                button:Hide()
            end
        end
    end

    -- Clickable secure rows (created and changed only out of combat) and plain rows for combat.
    local buttons, plainRows = {}, {}
    local canClick = true

    local function getButton(index)
        if buttons[index] then
            return buttons[index]
        end
        local ok, button = pcall(CreateFrame, "Button", nil, list, "SecureActionButtonTemplate")
        if ok and button then
            button.secure = true
        else
            canClick = false
            print("WarriorTracker: " .. L("secureError") .. tostring(button))
            button = CreateFrame("Button", nil, list)
        end
        decorate(button)
        if button.secure then
            button:SetAttribute("useOnKeyDown", false)
            button.petButton = addSideButton(button, "LEFT", "pet")
            button.petButton:SetAttribute("type2", "none")
            button.petButton:SetScript("PostClick", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    dropEntry(button.entry)
                end
            end)
            button.markButton = addSideButton(button, "RIGHT",
                "marker",
                "WTM" .. index)
            button.markButton:SetAttribute("type2", "none")
            button.markButton:SetScript("PostClick", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    dropEntry(button.entry)
                end
            end)
            -- The dice macro invokes this button as Button4; SecureActionButton resolves
            -- the action type by that suffix, independently from the default mouse buttons.
            button.markButton:SetAttribute("action4", "set")
            button.markButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "Button4Up")
            wrapMarkButton(button.markButton)
        end
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("PostClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                dropEntry(self.entry)
            elseif mouseButton == "LeftButton" and self.entry and not self.entry.clickUnit and not self.entry.targetByName then
                print(L("unavailable"))
            end
        end)
        buttons[index] = button
        return button
    end

    local function getPlainRow()
        for _, row in ipairs(plainRows) do
            if not row.entry then
                return row
            end
        end
        local row = decorate(CreateFrame("Frame", nil, list))
        row:EnableMouse(true)
        -- Above the secure rows, so it also covers an invisible secure row of a removed enemy.
        row:SetFrameLevel(list:GetFrameLevel() + 10)
        row:SetScript("OnMouseUp", function(self, mouseButton)
            if mouseButton == "RightButton" then
                dropEntry(self.entry)
            end
        end)
        table.insert(plainRows, row)
        return row
    end

    local function matchesGuid(unit, guid)
        local ok, same = pcall(function()
            local unitGuid = UnitGUID(unit)
            return unitGuid ~= nil and not isSecret(unitGuid) and unitGuid == guid
        end)
        return ok and same == true
    end

    -- Bind to visible unit tokens, not names. Capture the target's nameplate token directly too:
    -- UnitGUID can be secret in this client, which otherwise leaves the row with no action target.
    local function findClickUnit(guid)
        if not guid then
            return nil
        end
        for index = 1, 40 do
            local unit = "nameplate" .. index
            if matchesGuid(unit, guid) then
                return unit
            end
        end
        if matchesGuid("focus", guid) then
            return "focus"
        end
    end

    local function getTargetClickUnit()
        if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
            local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
            if ok and plate and type(plate.GetUnit) == "function" then
                local unitOk, unit = pcall(plate.GetUnit, plate)
                if unitOk and type(unit) == "string" then
                    return unit
                end
            end
        end
        for index = 1, 40 do
            local unit = "nameplate" .. index
            local ok, same = pcall(UnitIsUnit, unit, "target")
            if ok and same then
                return unit
            end
        end
        local ok, same = pcall(UnitIsUnit, "focus", "target")
        if ok and same then
            return "focus"
        end
    end

    local function isUsableClickUnit(unit, guid, name)
        if not unit then
            return false
        end
        if guid then
            return matchesGuid(unit, guid)
        end
        local ok, exists, unitName = pcall(function()
            return UnitExists(unit), UnitName(unit)
        end)
        return ok and exists and type(unitName) == "string" and not isSecret(unitName) and unitName == name
    end

    local function setRowMacros(button, entry)
        local unit
        if not entry.closingAt then
            unit = findClickUnit(entry.guid)
            if not unit and isUsableClickUnit(entry.clickUnit, entry.guid, entry.name) then
                unit = entry.clickUnit
            end
        end
        local targetByName = not entry.closingAt and type(entry.name) == "string" and entry.name ~= ""
        entry.clickUnit = unit
        entry.targetByName = targetByName
        -- Use the secure target command for the main row click. Unit-token target actions
        -- were unreliable on this client; exact-name targeting is securely handled by the client.
        button:SetAttribute("type1", targetByName and "macro" or nil)
        button:SetAttribute("unit", nil)
        button:SetAttribute("macrotext1", targetByName and ("/targetexact " .. entry.name) or nil)
        if button.petButton then
            button.petButton:SetAttribute("macrotext", unit and ("/petattack [@" .. unit .. ",exists,harm,nodead]") or nil)
        end
        if button.markButton then
            -- "/tm" is not a secure slash command in this client, so SetRaidTarget from a macro is blocked
            -- in combat. The built-in secure "raidtarget" action calls it from Blizzard's secure code instead.
            local markButton = button.markButton
            local mark = unit and "raidtarget" or nil
            markButton:SetAttribute("unit", unit)
            markButton:SetAttribute("macrotext1", nil)
            markButton:SetAttribute("ctrl-macrotext1", nil)
            markButton:SetAttribute("shift-macrotext1", nil)
            markButton:SetAttribute("macrotext4", nil)
            markButton:SetAttribute("type1", mark)
            markButton:SetAttribute("marker1", SKULL)
            markButton:SetAttribute("action1", "toggle")
            markButton:SetAttribute("ctrl-type1", mark)
            markButton:SetAttribute("ctrl-marker1", CROSS)
            markButton:SetAttribute("ctrl-action1", "set")
            markButton:SetAttribute("shift-type1", mark)
            markButton:SetAttribute("shift-action1", "clear")
            markButton:SetAttribute("type4", nil)
            markButton:SetAttribute("marker4", nil)
        end
    end

    local function readableMark(entry)
        local mark = entry and entry.mark
        if mark ~= nil and not isSecret(mark) and type(mark) == "number" then
            return mark
        end
    end

    -- Out of combat: rebuild the pool of used marks from the marks the game shows (when readable)
    -- and the marks this addon handed out to rows that are still listed.
    local function syncMarkPool()
        if not markPool or inCombat() then
            return
        end
        local used = {}
        for _, button in ipairs(buttons) do
            local markButton = button.markButton
            if markButton then
                local live = button.entry and button:IsShown()
                local known = live and readableMark(button.entry)
                local given = markButton:GetAttribute("hrb-mark")
                if not live then
                    given = nil
                elseif known then
                    given = (known >= 1 and known <= 7) and known or nil
                end
                markButton:SetAttribute("hrb-mark", given)
                if given then
                    used[given] = true
                end
            end
        end
        for _, entry in ipairs(entries) do
            local known = readableMark(entry)
            if known then
                used[known] = true
            end
        end
        for index = 1, 7 do
            markPool:SetAttribute("used" .. index, used[index] or nil)
        end

        -- Rows the dice button may mark (the first 8 listed rows with a mark button).
        if diceButton then
            local count, clicks = 0, {}
            for index, button in ipairs(buttons) do
                if index <= 8 and button.markButton and button.entry and button:IsShown() then
                    count = count + 1
                    markPool:SetFrameRef("m" .. count, button.markButton)
                    table.insert(clicks, "/click WTM" .. index .. " Button4")
                end
            end
            markPool:SetAttribute("count", count)
            diceButton:SetAttribute("macrotext", table.concat(clicks, "\n"))
            diceButton:SetShown(count > 0)
        end
    end
    layout = function()
        if inCombat() then
            needsLayout = true
            return
        end
        needsLayout = false
        for _, row in ipairs(plainRows) do
            row.entry = nil
            row:Hide()
        end
        for index, entry in ipairs(entries) do
            local button = getButton(index)
            if canClick then
                setRowMacros(button, entry)
            end
            entry.pending = nil
            placeRow(button, index, entry)
        end
        for index = #entries + 1, #buttons do
            buttons[index].entry = nil
            buttons[index]:Hide()
        end
        syncMarkPool()
    end

    local function findUnit(guid)
        if not guid then
            return nil
        end
        for _, unit in ipairs(SCAN_UNITS) do
            if matchesGuid(unit, guid) then
                return unit
            end
        end
    end

    local function itemInRange(itemIDs, unit)
        local isItemInRange = (C_Item and C_Item.IsItemInRange) or IsItemInRange
        if type(isItemInRange) ~= "function" then
            return nil
        end
        for _, itemID in ipairs(itemIDs) do
            local ok, inRange = pcall(isItemInRange, itemID, unit)
            if ok and not isSecret(inRange) then
                if inRange == true or inRange == 1 then
                    return true
                elseif inRange == false or inRange == 0 then
                    return false
                end
            end
        end
    end

    -- Returns text, r, g, b and whether the enemy is confirmed beyond 100 yd.
    local function unitRange(unit)
        if rangedWeaponInRange(unit) == true then
            return "OK", 0.25, 1, 0.3, false
        end
        if itemInRange(ITEMS_45, unit) then
            return "45", 1, 0.85, 0.2, false
        end
        local in100 = itemInRange(ITEMS_100, unit)
        if in100 then
            return "100", 1, 0.3, 0.2, false
        elseif in100 == false then
            return ">100", 0.5, 0.5, 0.5, true
        end
        return "?", 0.6, 0.6, 0.6, false
    end

    -- Stores health of a visible unit in the entry. The values may be secret: they are only handed
    -- to the StatusBar / FontString, which accept them, never compared or calculated with.
    local function captureHealth(entry, unit)
        local ok, health, maxHealth = pcall(function()
            return UnitHealth(unit), UnitHealthMax(unit)
        end)
        if not ok or health == nil or maxHealth == nil then
            return
        end
        entry.hpCur, entry.hpMax = health, maxHealth
        entry.hpColor, entry.hpText = nil, nil

        if not isSecret(health) and not isSecret(maxHealth) then
            if maxHealth > 0 then
                local fraction = math.max(0, math.min(1, health / maxHealth))
                if fraction > 0.5 then
                    entry.hpColor = { (1 - fraction) * 2, 0.75, 0.1 }
                else
                    entry.hpColor = { 0.85, fraction * 1.5, 0.1 }
                end
                entry.hpText = string.format("%d%%", math.floor(fraction * 100 + 0.5))
            end
            return
        end

        if type(UnitHealthPercent) == "function" then
            if healthCurve then
                local okColor, color = pcall(UnitHealthPercent, unit, true, healthCurve)
                if okColor and color then
                    local okRGB, r, g, b = pcall(color.GetRGB, color)
                    if okRGB then
                        entry.hpColor = { r, g, b }
                    end
                end
            end
            local okPercent, percent = pcall(UnitHealthPercent, unit, true, percentCurve)
            if okPercent and percent ~= nil then
                local okText, text = pcall(string.format, percentCurve and "%.0f%%" or "%.2f", percent)
                if okText then
                    entry.hpText = text
                end
            end
        end
    end

    -- The mark index may be a secret value: it is only checked against nil and handed to the texture.
    local function readMark(unit)
        local ok, mark = pcall(GetRaidTargetIndex, unit)
        if ok and mark ~= nil then
            return mark
        end
        return nil
    end

    local function isDead(unit)
        local ok, dead = pcall(function()
            local value = UnitIsDead(unit)
            return not isSecret(value) and value == true
        end)
        return ok and dead == true
    end

    local function drawRow(row, entry, unit, text, r, g, b)
        row.nameText:SetText(entry.name)
        row:SetAlpha(entry.pending and 0.6 or (unit and 1 or 0.75))
        row.rangeText:SetText(entry.pending and "⌛" or text)
        row.rangeText:SetTextColor(r, g, b)
        row.rangeStripe:SetColorTexture(r, g, b, 1)

        local shown = entry.hpMax ~= nil and pcall(function()
            row.health:SetMinMaxValues(0, entry.hpMax)
            row.health:SetValue(entry.hpCur)
        end)
        if shown then
            local color = entry.hpColor
            if not (color and pcall(row.health.SetStatusBarColor, row.health, color[1], color[2], color[3])) then
                row.health:SetStatusBarColor(0.15, 0.75, 0.1)
            end
            if not (entry.hpText and pcall(row.healthText.SetText, row.healthText, entry.hpText)) then
                row.healthText:SetText("")
            end
        else
            -- Health not known yet: grey full bar.
            row.health:SetMinMaxValues(0, 1)
            row.health:SetValue(1)
            row.health:SetStatusBarColor(0.3, 0.3, 0.3)
            row.healthText:SetText("")
        end
        row.targetGlow:SetShown(matchesGuid("target", entry.guid))

        local hasPet = UnitExists("pet")
        row.petIcon:SetDesaturated(not hasPet)
        row.petIcon:SetAlpha(hasPet and 1 or 0.4)

        -- Without a mark the slot shows a faint skull as a hint for the mark button.
        local marked = entry.mark ~= nil and pcall(row.raidIcon.SetSpriteSheetCell, row.raidIcon, entry.mark, 4, 4)
        if not marked then
            pcall(row.raidIcon.SetSpriteSheetCell, row.raidIcon, SKULL, 4, 4)
        end
        row.raidIcon:SetAlpha(marked and 1 or 0.2)
    end

    local function updateEntry(entry)
        if entry.closingAt then
            return
        end
        local unit = findUnit(entry.guid)
        local text, r, g, b = "?", 0.6, 0.6, 0.6
        if unit then
            if isDead(unit) then
                dropEntry(entry)
                return
            end
            text, r, g, b = unitRange(unit)
            captureHealth(entry, unit)
            entry.mark = readMark(unit)
        end
        if entry.row then
            drawRow(entry.row, entry, unit, text, r, g, b)
        end
    end

    -- The pet / mark macros depend on which row is the current target; they can only change out of combat.
    local function refreshMacros()
        if inCombat() or not canClick then
            return
        end
        for _, button in ipairs(buttons) do
            if button.entry and button:IsShown() then
                setRowMacros(button, button.entry)
            end
        end
        syncMarkPool()
    end

    local function addCurrentTarget()
        if inCombat() then
            return
        end
        refreshMacros()
        local ok, data = pcall(function()
            if not UnitExists("target") then
                return nil
            end
            local attackable = UnitCanAttack("player", "target")
            if isSecret(attackable) or not attackable or isDead("target") then
                return nil
            end
            local name, guid = UnitName("target"), UnitGUID("target")
            if type(name) ~= "string" or isSecret(name) or name == "" then
                return nil
            end
            if isSecret(guid) then
                guid = nil
            end
            return { name = name, guid = guid, clickUnit = getTargetClickUnit() }
        end)
        if not ok or not data then
            return
        end
        captureHealth(data, "target")
        data.mark = readMark("target")

        -- One row per enemy (GUID); without a GUID fall back to the name.
        for _, entry in ipairs(entries) do
            local sameEnemy = data.guid and entry.guid == data.guid
                or not data.guid and not entry.guid and (
                    data.clickUnit and entry.clickUnit == data.clickUnit
                    or not data.clickUnit and not entry.clickUnit and entry.name == data.name
                )
            if sameEnemy then
                if data.hpMax ~= nil then
                    entry.hpCur, entry.hpMax, entry.hpColor, entry.hpText = data.hpCur, data.hpMax, data.hpColor, data.hpText
                end
                entry.mark = data.mark
                entry.clickUnit = data.clickUnit or entry.clickUnit
                refreshMacros()
                return
            end
        end

        table.insert(entries, data)
        layout()
        updateEntry(data)
    end

    local pendingSync = false
    local function syncPosition()
        if inCombat() then
            pendingSync = true
            return
        end
        pendingSync = false
        -- Absolute coordinates (secure rows must not be anchored to the movable bar):
        -- left of the bar, the first row level with the bar's bottom edge, growing upwards.
        local left, bottom = frame:GetLeft(), frame:GetBottom()
        if left and bottom then
            list:ClearAllPoints()
            list:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", left - MARK_ICON_ROOM, bottom)
        end
    end

    hooksecurefunc(frame, "SetPoint", syncPosition)
    frame:HookScript("OnSizeChanged", syncPosition)
    frame:HookScript("OnDragStop", syncPosition)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_TARGET_CHANGED" then
            addCurrentTarget()
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            return
        end
        if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
            if event == "NAME_PLATE_UNIT_REMOVED" then
                for _, entry in ipairs(entries) do
                    if entry.clickUnit == unit then
                        entry.clickUnit = nil
                    end
                end
            end
            refreshMacros()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            for index = #entries, 1, -1 do
                local entry = entries[index]
                updateEntry(entry)
                if entry.closingAt then
                    table.remove(entries, index)
                    releaseRow(entry)
                end
            end
        end
        if event == "PLAYER_ENTERING_WORLD" or pendingSync then
            syncPosition()
        end
        layout()
    end)

    local updateElapsed = 0
    frame:HookScript("OnUpdate", function(_, elapsed)
        updateClosingRows(GetTime())
        updateElapsed = updateElapsed + elapsed
        if updateElapsed < 0.2 then
            return
        end
        updateElapsed = 0
        refreshMacros()
        for index = #entries, 1, -1 do
            if entries[index] then
                updateEntry(entries[index])
            end
        end
    end)

    local slashHandler = SlashCmdList.WARRIORTRACKER
    SlashCmdList.WARRIORTRACKER = function(message)
        local command = string.lower(message or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if command == "seznam" or command == "list" then
            for index = #entries, 1, -1 do
                dropEntry(entries[index])
            end
            print(L(inCombat() and "listCombat" or "listClear"))
            return
        end
        slashHandler(message)
    end
end
