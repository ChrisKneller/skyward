--[[
    Skyward: In-Game Configuration Panel
    Custom standalone UI frame accessible via /skyward
]]

local ADDON_NAME, Skyward = ...

local GUI = {}
Skyward.GUI = GUI

local mainFrame = nil
local whitelistScrollChild = nil
local modeButtons = {}
local statusText = nil
local statsText = nil
local nameInput = nil

-- Helper to create styled buttons
local function CreateStyledButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 100, height or 24)
    btn:SetText(text)
    return btn
end

-- Refresh the whitelist entries in the scroll list
function Skyward:UpdateWhitelistList()
    if not whitelistScrollChild then return end

    -- Clear existing rows
    for _, child in ipairs({ whitelistScrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local whitelist = self:GetWhitelist()
    local yOffset = -4
    local count = 0

    local sortedEntries = {}
    for key, data in pairs(whitelist) do
        local displayName = (type(data) == "table" and data.name) or key
        table.insert(sortedEntries, { key = key, name = displayName })
    end
    table.sort(sortedEntries, function(a, b) return a.name:lower() < b.name:lower() end)

    if #sortedEntries == 0 then
        local emptyLabel = whitelistScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        emptyLabel:SetPoint("TOPLEFT", 10, -10)
        emptyLabel:SetText("No characters whitelisted yet. Enter a character name above.")
        whitelistScrollChild:SetHeight(40)
        return
    end

    for _, entry in ipairs(sortedEntries) do
        count = count + 1
        local row = CreateFrame("Frame", nil, whitelistScrollChild)
        row:SetSize(410, 24)
        row:SetPoint("TOPLEFT", 6, yOffset)

        -- Background highlight on hover
        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        rowBg:SetColorTexture(1, 1, 1, (count % 2 == 0) and 0.04 or 0.01)

        -- Character name font string
        local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLabel:SetPoint("LEFT", row, "LEFT", 8, 0)
        nameLabel:SetText(entry.name)

        -- Remove button
        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(65, 18)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        removeBtn:SetText("Remove")
        removeBtn:SetNormalFontObject("GameFontNormalSmall")
        removeBtn:SetHighlightFontObject("GameFontHighlightSmall")
        removeBtn:SetScript("OnClick", function()
            Skyward:RemoveWhitelist(entry.key)
        end)

        yOffset = yOffset - 26
    end

    whitelistScrollChild:SetHeight(math.max(math.abs(yOffset) + 10, 140))
end

-- Update GUI display states (mode buttons, status, stats)
function Skyward:UpdateGUI()
    if not mainFrame or not mainFrame:IsShown() then return end

    local currentMode = self:GetMode()

    -- Update Mode Buttons highlight/state
    for modeKey, btn in pairs(modeButtons) do
        if modeKey == currentMode then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    -- Update Status Banner
    if statusText then
        if currentMode == Skyward.MODES.OFF then
            statusText:SetText("Status: |cff808080Filter Off (All Messages Shown)|r")
        elseif currentMode == Skyward.MODES.MARKED then
            statusText:SetText("Status: |cff90e0efDimmed (Skyborne Messages Greyed Out)|r")
        elseif currentMode == Skyward.MODES.HIDE then
            statusText:SetText("Status: |cffff4d4dBlocked (Skyborne Messages Hidden)|r")
        end
    end

    -- Update Cache Stats
    if statsText then
        local total, skyborneCount = self:GetCacheStats()
        statsText:SetText(("Known Players in Cache: |cffffffff%d|r  |  Skyborne Identified: |cff00b4d8%d|r"):format(total, skyborneCount))
    end

    -- Refresh Whitelist List
    self:UpdateWhitelistList()
end

-- Construct the main standalone panel
function GUI:CreateMainFrame()
    if mainFrame then return mainFrame end

    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "SkywardMainFrame", UIParent, backdropTemplate)
    f:SetSize(470, 560)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    -- ESC key closes frame
    tinsert(UISpecialFrames, "SkywardMainFrame")

    -- Backdrop styling
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0.08, 0.09, 0.11, 0.95)

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    -- Title Bar Header
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -16)
    title:SetText(Skyward.COLORS.PRIMARY .. "Skyward|r " .. Skyward.COLORS.ACCENT .. "v" .. Skyward.VERSION .. "|r")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Skyborne Race Interaction & Chat Shield - WoW Forever")

    -- Status Subheading
    statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    statusText:SetText("Status: Initializing...")

    -- Horizontal Divider 1
    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetSize(434, 1)
    div1:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
    div1:SetColorTexture(0.3, 0.35, 0.4, 0.6)

    -- SECTION 1: Public Chat Filter Mode
    local modeHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeHeader:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", 0, -10)
    modeHeader:SetText("Public Channels Filter Mode:")

    local modeSub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    modeSub:SetPoint("TOPLEFT", modeHeader, "BOTTOMLEFT", 0, -3)
    modeSub:SetText("Controls General, Trade, Services, Say, Yell, and Emotes from Skyborne.")

    local modeContainer = CreateFrame("Frame", nil, f)
    modeContainer:SetSize(434, 34)
    modeContainer:SetPoint("TOPLEFT", modeSub, "BOTTOMLEFT", 0, -8)

    local modes = {
        { id = Skyward.MODES.OFF, label = "Off (Normal)", desc = "Do not filter chat", width = 135 },
        { id = Skyward.MODES.MARKED, label = "Dimmed / Marked", desc = "Grey out Skyborne messages", width = 145 },
        { id = Skyward.MODES.HIDE, label = "Hide (Block)", desc = "Completely remove messages", width = 135 },
    }

    local btnX = 0
    for _, m in ipairs(modes) do
        local btn = CreateStyledButton(modeContainer, m.label, m.width, 28)
        btn:SetPoint("TOPLEFT", modeContainer, "TOPLEFT", btnX, 0)
        btn:SetScript("OnClick", function()
            Skyward:SetMode(m.id)
        end)
        modeButtons[m.id] = btn
        btnX = btnX + m.width + 9
    end

    -- SECTION 2: Marking Style Sub-Options (When in Dimmed/Marked mode)
    local styleContainer = CreateFrame("Frame", nil, f)
    styleContainer:SetSize(434, 26)
    styleContainer:SetPoint("TOPLEFT", modeContainer, "BOTTOMLEFT", 0, -6)

    local styleLabel = styleContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    styleLabel:SetPoint("LEFT", styleContainer, "LEFT", 2, 0)
    styleLabel:SetText("Visual Style:")

    local dimStyleBtn = CreateStyledButton(styleContainer, "Greyed Out", 85, 20)
    dimStyleBtn:SetPoint("LEFT", styleLabel, "RIGHT", 10, 0)
    dimStyleBtn:SetScript("OnClick", function()
        Skyward.db.markStyle = "DIM"
        Skyward:Print("Visual style set to: |cff90e0efGreyed Out|r")
    end)

    local strikeStyleBtn = CreateStyledButton(styleContainer, "Strikethrough", 95, 20)
    strikeStyleBtn:SetPoint("LEFT", dimStyleBtn, "RIGHT", 6, 0)
    strikeStyleBtn:SetScript("OnClick", function()
        Skyward.db.markStyle = "STRIKE"
        Skyward:Print("Visual style set to: |cff90e0efStrikethrough|r")
    end)

    local tagStyleBtn = CreateStyledButton(styleContainer, "Tag Only", 75, 20)
    tagStyleBtn:SetPoint("LEFT", strikeStyleBtn, "RIGHT", 6, 0)
    tagStyleBtn:SetScript("OnClick", function()
        Skyward.db.markStyle = "TAG"
        Skyward:Print("Visual style set to: |cff90e0efTag Only|r")
    end)

    -- Horizontal Divider 2
    local div2 = f:CreateTexture(nil, "ARTWORK")
    div2:SetSize(434, 1)
    div2:SetPoint("TOPLEFT", styleContainer, "BOTTOMLEFT", 0, -8)
    div2:SetColorTexture(0.3, 0.35, 0.4, 0.6)

    -- SECTION 3: Whitelist Management
    local wlHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wlHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 0, -10)
    wlHeader:SetText("Whitelist (Exempt Characters):")

    local wlDesc = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    wlDesc:SetPoint("TOPLEFT", wlHeader, "BOTTOMLEFT", 0, -3)
    wlDesc:SetText("Whitelisted players are never filtered or dimmed, even if they play Skyborne.")

    -- Whitelist Add Input Box
    nameInput = CreateFrame("EditBox", "SkywardWhitelistInput", f, "InputBoxTemplate")
    nameInput:SetSize(280, 24)
    nameInput:SetPoint("TOPLEFT", wlDesc, "BOTTOMLEFT", 6, -8)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(40)

    -- Placeholder prompt
    local inputPrompt = nameInput:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    inputPrompt:SetPoint("LEFT", nameInput, "LEFT", 6, 0)
    inputPrompt:SetText("CharacterName or Name-Realm...")

    nameInput:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then
            inputPrompt:Show()
        else
            inputPrompt:Hide()
        end
    end)

    local addBtn = CreateStyledButton(f, "Add Whitelist", 120, 24)
    addBtn:SetPoint("LEFT", nameInput, "RIGHT", 10, 0)

    local function DoAdd()
        local txt = nameInput:GetText()
        if txt and strtrim(txt) ~= "" then
            local success, err = Skyward:AddWhitelist(txt)
            if success then
                nameInput:SetText("")
                nameInput:ClearFocus()
            elseif err then
                Skyward:Print("|cffff4d4d" .. err .. "|r")
            end
        end
    end

    addBtn:SetScript("OnClick", DoAdd)
    nameInput:SetScript("OnEnterPressed", DoAdd)

    -- Whitelist Scroll Area
    local scrollFrame = CreateFrame("ScrollFrame", "SkywardWhitelistScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(410, 140)
    scrollFrame:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -10)

    -- ScrollFrame Backdrop
    local scrollBg = CreateFrame("Frame", nil, f, backdropTemplate)
    scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -6, 6)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 24, -6)
    scrollBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    scrollBg:SetBackdropColor(0, 0, 0, 0.4)
    scrollBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    whitelistScrollChild = CreateFrame("Frame", nil, scrollFrame)
    whitelistScrollChild:SetSize(410, 140)
    scrollFrame:SetScrollChild(whitelistScrollChild)

    -- SECTION 4: Footer Tools (Test, Stats, Clear Cache)
    statsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 50)
    statsText:SetText("Known Players: 0  |  Skyborne Identified: 0")

    local testBtn = CreateStyledButton(f, "Simulate Skyborne Chat", 175, 24)
    testBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
    testBtn:SetScript("OnClick", function()
        Skyward:RunChatSimulation()
    end)

    local clearCacheBtn = CreateStyledButton(f, "Clear Cache", 100, 24)
    clearCacheBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
    clearCacheBtn:SetScript("OnClick", function()
        Skyward:ClearCache()
    end)

    f:SetScript("OnShow", function()
        Skyward:UpdateGUI()
    end)

    mainFrame = f
    return mainFrame
end

-- Toggle visibility of the main settings panel
function GUI:Toggle()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        Skyward:UpdateGUI()
    end
end
