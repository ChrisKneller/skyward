--[[
    Skyward: In-Game Configuration Panel
    Standalone UI frame accessible via /skyward, /sw, /sky
    Tabs: General (Mode / Whitelist), Channels, and Styling (Appearance & Live Preview).
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

-- Tab Containers & Buttons
local currentTab = "GENERAL"
local tabButtons = {}
local tabContents = {}

-- Channels Tab UI references
local channelCheckboxes = {}
local channelStatusText = nil

-- Styling Tab UI references
local tagCheckbox = nil
local tagInput = nil
local nameColorCheckbox = nil
local colorPresetButtons = {}
local previewText = nil

-- Helper to create standard styled buttons
local function CreateStyledButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 100, height or 24)
    btn:SetText(text)
    return btn
end

-- Helper to create clean checkboxes
local function CreateCheckbox(parent, labelText, tooltipText, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)

    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetText(labelText)
    cb.Label = label

    if tooltipText then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 1, 1)
            GameTooltip:AddLine(tooltipText, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    cb:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        if onClick then
            onClick(isChecked)
        end
    end)

    return cb
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

-- Update the live preview box in the Styling tab
local function UpdateLivePreview()
    if not previewText then return end

    local isReplaceColor = Skyward:IsReplaceNameColorEnabled()
    local nameColorCode = isReplaceColor and Skyward:GetMarkColorCode("CHAT_MSG_CHANNEL", 2, 2) or nil
    local showTag = Skyward:IsTagEnabled()
    local tag = Skyward:GetMarkTag()

    local sampleMsg = "Does anyone know if the Rune Broker is in forever?"
    local tagStr = (showTag and tag and tag ~= "") and (tag .. " ") or ""

    local chHex = Skyward:GetChannelColorHex("CHAT_MSG_CHANNEL", 2, 2)
    local chCode = "|cff" .. chHex

    local channelPart = chCode .. "[2. Trade - English]|r"

    local authorPart
    if isReplaceColor and nameColorCode then
        authorPart = chCode .. "[" .. nameColorCode .. "Moon Ray" .. chCode .. "]|r"
    else
        -- Unticked: show class color (Druid orange |cffff7c0a) with channel-colored brackets
        authorPart = chCode .. "[|cffff7c0aMoon Ray" .. chCode .. "]|r"
    end

    local msgPart = chCode .. tagStr .. sampleMsg .. "|r"

    previewText:SetText(("%s %s%s: %s"):format(channelPart, authorPart, chCode, msgPart))
end

-- Switch between tabs
local function SwitchTab(tabKey)
    currentTab = tabKey
    for key, contentFrame in pairs(tabContents) do
        if key == tabKey then
            contentFrame:Show()
            if tabButtons[key] then tabButtons[key]:LockHighlight() end
        else
            contentFrame:Hide()
            if tabButtons[key] then tabButtons[key]:UnlockHighlight() end
        end
    end
    Skyward:UpdateGUI()
end

-- Update GUI display states across all tabs
function Skyward:UpdateGUI()
    if not mainFrame or not mainFrame:IsShown() then return end

    local currentMode = self:GetMode()

    -- 1. Update Mode Buttons
    for modeKey, btn in pairs(modeButtons) do
        if modeKey == currentMode then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    -- 2. Update Status Banner
    if statusText then
        if currentMode == Skyward.MODES.OFF then
            statusText:SetText("Status: |cff808080Filter Off (All Messages Shown)|r")
        elseif currentMode == Skyward.MODES.MARKED then
            statusText:SetText("Status: |cff90e0efStyled (Skyborne Messages Filtered & Styled)|r")
        elseif currentMode == Skyward.MODES.HIDE then
            statusText:SetText("Status: |cffff4d4dBlocked (Skyborne Messages Hidden)|r")
        end
    end

    -- 3. Update Cache Stats (Footer)
    if statsText then
        local total, skyborneCount = self:GetCacheStats()
        statsText:SetText(("Known Players in Cache: |cffffffff%d|r  |  Skyborne Identified: |cff00b4d8%d|r"):format(total, skyborneCount))
    end

    -- 4. Update Whitelist Scroll List
    self:UpdateWhitelistList()

    -- 5. Update Channels Checkboxes & Count
    for chKey, cb in pairs(channelCheckboxes) do
        cb:SetChecked(self:IsChannelFiltered(chKey))
    end
    if channelStatusText then
        local active, total = self:GetFilteredChannelCount()
        channelStatusText:SetText(("Active Channel Filters: |cff52b788%d|r of |cffffffff%d|r enabled"):format(active, total))
    end

    -- 6. Update Styling Tab Elements
    if tagCheckbox then
        tagCheckbox:SetChecked(self:IsTagEnabled())
    end
    if tagInput and not tagInput:HasFocus() then
        tagInput:SetText(self:GetMarkTag())
    end
    if nameColorCheckbox then
        nameColorCheckbox:SetChecked(self:IsReplaceNameColorEnabled())
    end

    -- Update Color Preset Highlights & State
    local isColorEnabled = self:IsReplaceNameColorEnabled()
    local currentColor = (self.db and self.db.markColor) or "777b80"
    for hex, btn in pairs(colorPresetButtons) do
        if hex == "CHANNEL" then
            local chHex = self:GetChannelColorHex("CHAT_MSG_CHANNEL", 2, 2)
            btn:SetText("|cff" .. chHex .. "Channel|r")
        end

        if not isColorEnabled then
            btn:UnlockHighlight()
            btn:SetAlpha(0.4)
        else
            btn:SetAlpha(1.0)
            if hex == currentColor then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
    end

    UpdateLivePreview()
end

-- Construct the main standalone panel
function GUI:CreateMainFrame()
    if mainFrame then return mainFrame end

    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "SkywardMainFrame", UIParent, backdropTemplate)
    f:SetSize(470, 570)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    tinsert(UISpecialFrames, "SkywardMainFrame")

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
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -14)
    title:SetText(Skyward.COLORS.PRIMARY .. "Skyward|r " .. Skyward.COLORS.ACCENT .. "v" .. Skyward.VERSION .. "|r")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Skyborne Race Interaction & Chat Shield - WoW Forever")

    -- Navigation Tab Bar
    local tabBar = CreateFrame("Frame", nil, f)
    tabBar:SetSize(434, 28)
    tabBar:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)

    local tabs = {
        { id = "GENERAL",   label = "General" },
        { id = "WHITELIST", label = "Whitelist" },
        { id = "CHANNELS",  label = "Channels" },
        { id = "STYLING",   label = "Styling" },
    }

    local tabX = 0
    for _, t in ipairs(tabs) do
        local btn = CreateStyledButton(tabBar, t.label, 104, 24)
        btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", tabX, 0)
        btn:SetScript("OnClick", function()
            SwitchTab(t.id)
        end)
        tabButtons[t.id] = btn
        tabX = tabX + 110
    end

    -- Tab Divider Line
    local tabDiv = f:CreateTexture(nil, "ARTWORK")
    tabDiv:SetSize(434, 1)
    tabDiv:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -4)
    tabDiv:SetColorTexture(0.35, 0.4, 0.45, 0.8)

    -- Container area for tab contents
    local function CreateTabContentFrame()
        local content = CreateFrame("Frame", nil, f)
        content:SetPoint("TOPLEFT", tabDiv, "BOTTOMLEFT", 0, -6)
        content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 55)
        return content
    end

    ---------------------------------------------------------------------------
    -- TAB 1: GENERAL
    ---------------------------------------------------------------------------
    local tabGeneral = CreateTabContentFrame()
    tabContents["GENERAL"] = tabGeneral

    statusText = tabGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", tabGeneral, "TOPLEFT", 0, -2)
    statusText:SetText("Status: Initializing...")

    local modeHeader = tabGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeHeader:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -12)
    modeHeader:SetText("Public Channels Filter Mode:")

    local modeContainer = CreateFrame("Frame", nil, tabGeneral)
    modeContainer:SetSize(434, 32)
    modeContainer:SetPoint("TOPLEFT", modeHeader, "BOTTOMLEFT", 0, -6)

    local modes = {
        { id = Skyward.MODES.OFF, label = "Off (Normal)", width = 135 },
        { id = Skyward.MODES.MARKED, label = "Styled", width = 145 },
        { id = Skyward.MODES.HIDE, label = "Hide (Block)", width = 135 },
    }

    local btnX = 0
    for _, m in ipairs(modes) do
        local btn = CreateStyledButton(modeContainer, m.label, m.width, 26)
        btn:SetPoint("TOPLEFT", modeContainer, "TOPLEFT", btnX, 0)
        btn:SetScript("OnClick", function()
            Skyward:SetMode(m.id)
        end)
        modeButtons[m.id] = btn
        btnX = btnX + m.width + 9
    end

    -- Information Card describing the modes
    local infoCard = CreateFrame("Frame", nil, tabGeneral, backdropTemplate)
    infoCard:SetSize(434, 160)
    infoCard:SetPoint("TOPLEFT", modeContainer, "BOTTOMLEFT", 0, -18)
    infoCard:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    infoCard:SetBackdropColor(0, 0, 0, 0.4)
    infoCard:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)

    local cardHeader = infoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cardHeader:SetPoint("TOPLEFT", 12, -12)
    cardHeader:SetText("Filter Mode Details:")

    local cardDesc = infoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cardDesc:SetPoint("TOPLEFT", cardHeader, "BOTTOMLEFT", 0, -8)
    cardDesc:SetPoint("RIGHT", infoCard, "RIGHT", -12, 0)
    cardDesc:SetJustifyH("LEFT")
    cardDesc:SetText(
        "|cffffd100Off (Normal)|r:\nSkyward is idle. All messages and class colours appear normally.\n\n" ..
        "|cff00b4d8Styled|r:\nMessages from Skyborne players are styled with a prefix tag and/or custom name colour (configured in the Styling tab).\n\n" ..
        "|cffff4d4dHide (Block)|r:\nCompletely suppresses public chat messages sent by Skyborne players."
    )

    local navTip = tabGeneral:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    navTip:SetPoint("TOPLEFT", infoCard, "BOTTOMLEFT", 2, -16)
    navTip:SetText("Use the tabs above to manage Whitelist, Channel toggles, and Styling options.")

    ---------------------------------------------------------------------------
    -- TAB 2: WHITELIST
    ---------------------------------------------------------------------------
    local tabWhitelist = CreateTabContentFrame()
    tabContents["WHITELIST"] = tabWhitelist
    tabWhitelist:Hide()

    local wlHeader = tabWhitelist:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wlHeader:SetPoint("TOPLEFT", tabWhitelist, "TOPLEFT", 0, -2)
    wlHeader:SetText("Whitelist (Exempt Characters):")

    local wlDesc = tabWhitelist:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    wlDesc:SetPoint("TOPLEFT", wlHeader, "BOTTOMLEFT", 0, -2)
    wlDesc:SetText("Whitelisted players are never filtered, even if they play Skyborne.")

    nameInput = CreateFrame("EditBox", "SkywardWhitelistInput", tabWhitelist, "InputBoxTemplate")
    nameInput:SetSize(280, 24)
    nameInput:SetPoint("TOPLEFT", wlDesc, "BOTTOMLEFT", 6, -8)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(50)

    local inputPrompt = nameInput:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    inputPrompt:SetPoint("LEFT", nameInput, "LEFT", 6, 0)
    inputPrompt:SetText("Firstname Lastname...")

    nameInput:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then
            inputPrompt:Show()
        else
            inputPrompt:Hide()
        end
    end)

    local addBtn = CreateStyledButton(tabWhitelist, "Add Whitelist", 120, 24)
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
    local scrollFrame = CreateFrame("ScrollFrame", "SkywardWhitelistScrollFrame", tabWhitelist, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(410, 300)
    scrollFrame:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -10)

    local scrollBg = CreateFrame("Frame", nil, tabWhitelist, backdropTemplate)
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
    whitelistScrollChild:SetSize(410, 300)
    scrollFrame:SetScrollChild(whitelistScrollChild)

    ---------------------------------------------------------------------------
    -- TAB 3: CHANNELS
    ---------------------------------------------------------------------------
    local tabChannels = CreateTabContentFrame()
    tabContents["CHANNELS"] = tabChannels
    tabChannels:Hide()

    local chHeader = tabChannels:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chHeader:SetPoint("TOPLEFT", tabChannels, "TOPLEFT", 0, -2)
    chHeader:SetText("Channel Filter Toggles:")

    local chSub = tabChannels:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    chSub:SetPoint("TOPLEFT", chHeader, "BOTTOMLEFT", 0, -3)
    chSub:SetText("Select which chat channels Skyward monitors. Unticked channels are never filtered.")

    channelStatusText = tabChannels:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    channelStatusText:SetPoint("TOPLEFT", chSub, "BOTTOMLEFT", 0, -6)
    channelStatusText:SetText("Active Channel Filters: 9 of 9 enabled")

    -- Two Column Checkbox layout
    local chCol1X = 10
    local chCol2X = 225
    local chY = -65

    for idx, def in ipairs(Skyward.CHANNEL_DEFINITIONS or {}) do
        local colX = (idx <= 5) and chCol1X or chCol2X
        local curY = chY - (((idx <= 5) and (idx - 1) or (idx - 6)) * 34)

        local cb = CreateCheckbox(tabChannels, def.name, def.desc, function(isChecked)
            Skyward:SetChannelFiltered(def.key, isChecked)
            Skyward:UpdateGUI()
        end)
        cb:SetPoint("TOPLEFT", tabChannels, "TOPLEFT", colX, curY)
        channelCheckboxes[def.key] = cb
    end

    -- Bulk action buttons
    local chBtnContainer = CreateFrame("Frame", nil, tabChannels)
    chBtnContainer:SetSize(434, 30)
    chBtnContainer:SetPoint("BOTTOMLEFT", tabChannels, "BOTTOMLEFT", 0, 10)

    local selectAllBtn = CreateStyledButton(chBtnContainer, "Select All", 100, 24)
    selectAllBtn:SetPoint("LEFT", chBtnContainer, "LEFT", 10, 0)
    selectAllBtn:SetScript("OnClick", function()
        for _, def in ipairs(Skyward.CHANNEL_DEFINITIONS or {}) do
            Skyward:SetChannelFiltered(def.key, true)
        end
        Skyward:UpdateGUI()
    end)

    local deselectAllBtn = CreateStyledButton(chBtnContainer, "Deselect All", 105, 24)
    deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 10, 0)
    deselectAllBtn:SetScript("OnClick", function()
        for _, def in ipairs(Skyward.CHANNEL_DEFINITIONS or {}) do
            Skyward:SetChannelFiltered(def.key, false)
        end
        Skyward:UpdateGUI()
    end)

    local resetChBtn = CreateStyledButton(chBtnContainer, "Reset Defaults", 115, 24)
    resetChBtn:SetPoint("LEFT", deselectAllBtn, "RIGHT", 10, 0)
    resetChBtn:SetScript("OnClick", function()
        for _, def in ipairs(Skyward.CHANNEL_DEFINITIONS or {}) do
            Skyward:SetChannelFiltered(def.key, true)
        end
        Skyward:UpdateGUI()
    end)

    ---------------------------------------------------------------------------
    -- TAB 4: STYLING
    ---------------------------------------------------------------------------
    local tabStyling = CreateTabContentFrame()
    tabContents["STYLING"] = tabStyling
    tabStyling:Hide()

    local stHeader = tabStyling:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stHeader:SetPoint("TOPLEFT", tabStyling, "TOPLEFT", 0, -2)
    stHeader:SetText("Styled Skyborne Message Appearance:")

    local stSub = tabStyling:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    stSub:SetPoint("TOPLEFT", stHeader, "BOTTOMLEFT", 0, -3)
    stSub:SetText("Customise character name colour and prefix tags for Skyborne players.")

    -- 1. Prefix Tag Toggle & Input Box
    tagCheckbox = CreateCheckbox(tabStyling, "Add Prefix Tag:", "Toggle whether a prefix tag is added before Skyborne messages.", function(isChecked)
        Skyward:SetTagEnabled(isChecked)
        UpdateLivePreview()
    end)
    tagCheckbox:SetPoint("TOPLEFT", stSub, "BOTTOMLEFT", 2, -12)

    tagInput = CreateFrame("EditBox", "SkywardTagInput", tabStyling, "InputBoxTemplate")
    tagInput:SetSize(180, 22)
    tagInput:SetPoint("LEFT", tagCheckbox.Label, "RIGHT", 12, 0)
    tagInput:SetAutoFocus(false)
    tagInput:SetMaxLetters(30)
    tagInput:SetText(Skyward:GetMarkTag())
    tagInput:SetScript("OnTextChanged", function(self)
        Skyward:SetMarkTag(self:GetText())
        UpdateLivePreview()
    end)

    -- 2. Character Name Color Theme (2 rows of 3 buttons)
    nameColorCheckbox = CreateCheckbox(tabStyling, "Replace Character Name Colour", "Toggle whether the character's class colour is replaced for Skyborne players.", function(isChecked)
        Skyward:SetReplaceNameColor(isChecked)
        Skyward:UpdateGUI()
    end)
    nameColorCheckbox:SetPoint("TOPLEFT", tagCheckbox, "BOTTOMLEFT", 0, -14)

    local colorContainer = CreateFrame("Frame", nil, tabStyling)
    colorContainer:SetSize(434, 56)
    colorContainer:SetPoint("TOPLEFT", nameColorCheckbox, "BOTTOMLEFT", 0, -6)

    for idx, preset in ipairs(Skyward.MARK_COLOR_PRESETS or {}) do
        local row = (idx <= 3) and 0 or 1
        local col = (idx <= 3) and (idx - 1) or (idx - 4)
        local btnX = col * 144
        local btnY = - (row * 28)

        local btnText
        if preset.hex == "CHANNEL" then
            local chHex = Skyward:GetChannelColorHex("CHAT_MSG_CHANNEL", 2, 2)
            btnText = "|cff" .. chHex .. "Channel|r"
        else
            btnText = "|cff" .. preset.hex .. preset.label .. "|r"
        end

        local btn = CreateStyledButton(colorContainer, btnText, 138, 24)
        btn:SetPoint("TOPLEFT", colorContainer, "TOPLEFT", btnX, btnY)
        btn:SetScript("OnClick", function()
            Skyward:SetMarkColor(preset.hex)
            Skyward:UpdateGUI()
        end)
        colorPresetButtons[preset.hex] = btn
    end

    -- 3. Live Preview Box
    local previewLabel = tabStyling:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", colorContainer, "BOTTOMLEFT", 0, -22)
    previewLabel:SetText("Live Chat Preview:")

    local previewBox = CreateFrame("Frame", nil, tabStyling, backdropTemplate)
    previewBox:SetSize(430, 48)
    previewBox:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -4)
    previewBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    previewBox:SetBackdropColor(0, 0, 0, 0.7)
    previewBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    previewText = previewBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewText:SetPoint("LEFT", previewBox, "LEFT", 10, 0)
    previewText:SetPoint("RIGHT", previewBox, "RIGHT", -10, 0)
    previewText:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- PERSISTENT FOOTER TOOLS (Always visible across all tabs)
    ---------------------------------------------------------------------------
    local footDiv = f:CreateTexture(nil, "ARTWORK")
    footDiv:SetSize(434, 1)
    footDiv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 52)
    footDiv:SetColorTexture(0.3, 0.35, 0.4, 0.6)

    statsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 56)
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
        SwitchTab(currentTab)
        Skyward:UpdateGUI()
    end)

    mainFrame = f
    SwitchTab("GENERAL")
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
