--[[
    Skyward: In-Game Configuration Panel
    Standalone UI frame accessible via /skyward
    Tabs: Chat (Mode, Channels, Styling), Grouping (LFG & Party Filters), Whitelist.
]]

local ADDON_NAME, Skyward = ...

local GUI = {}
Skyward.GUI = GUI

local mainFrame = nil
local whitelistScrollChild = nil
local statsText = nil
local nameInput = nil

-- Top-level Navigation Tabs
local currentTab = "CHAT"
local tabButtons = {}
local tabContents = {}

-- Chat Tab Navigation & UI references
local currentChatSubTab = "MODE"
local chatSubButtons = {}
local chatSubContents = {}
local chatModeButtons = {}
local chatStatusText = nil

-- Channels Sub-tab UI references
local channelCheckboxes = {}
local channelStatusText = nil

-- Styling Sub-tab UI references
local tagCheckbox = nil
local tagInput = nil
local nameColorCheckbox = nil
local colorPresetButtons = {}
local previewText = nil

-- Grouping Tab UI references
local groupingModeButtons = {}
local groupingStatusText = nil
local groupingBadgeCheckbox = nil
local groupingConfirmCheckbox = nil

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

-- Update the live preview box in the Styling sub-tab
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
        -- Unticked: show class colour (Druid orange |cffff7c0a) with channel-coloured brackets
        authorPart = chCode .. "[|cffff7c0aMoon Ray" .. chCode .. "]|r"
    end

    local msgPart = chCode .. tagStr .. sampleMsg .. "|r"

    previewText:SetText(("%s %s%s: %s"):format(channelPart, authorPart, chCode, msgPart))
end

-- Switch between top-level tabs
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

-- Switch between sub-tabs inside Chat
local function SwitchChatSubTab(subKey)
    currentChatSubTab = subKey
    for key, contentFrame in pairs(chatSubContents) do
        if key == subKey then
            contentFrame:Show()
            if chatSubButtons[key] then chatSubButtons[key]:LockHighlight() end
        else
            contentFrame:Hide()
            if chatSubButtons[key] then chatSubButtons[key]:UnlockHighlight() end
        end
    end
    Skyward:UpdateGUI()
end

-- Update GUI display states across all tabs
function Skyward:UpdateGUI()
    if not mainFrame or not mainFrame:IsShown() then return end

    local currentChatMode = self:GetMode()
    local currentGroupingMode = self:GetGroupingMode()

    -- 1. Update Chat Mode Buttons
    for modeKey, btn in pairs(chatModeButtons) do
        if modeKey == currentChatMode then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    -- 2. Update Chat Status Banner
    if chatStatusText then
        if currentChatMode == Skyward.MODES.OFF then
            chatStatusText:SetText("Chat Status: |cff808080Filter Off (All Messages Shown)|r")
        elseif currentChatMode == Skyward.MODES.WARN then
            chatStatusText:SetText("Chat Status: |cff90e0efWarn (Skyborne Messages Filtered & Styled)|r")
        elseif currentChatMode == Skyward.MODES.HIDE then
            chatStatusText:SetText("Chat Status: |cffff4d4dBlocked (Skyborne Messages Hidden)|r")
        end
    end

    -- 3. Update Grouping Mode Buttons
    for modeKey, btn in pairs(groupingModeButtons) do
        if modeKey == currentGroupingMode then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    -- 4. Update Grouping Status Banner
    if groupingStatusText then
        if currentGroupingMode == Skyward.GROUPING_MODES.OFF then
            groupingStatusText:SetText("Grouping Status: |cff808080Filter Off (Normal Grouping)|r")
        elseif currentGroupingMode == Skyward.GROUPING_MODES.WARN then
            groupingStatusText:SetText("Grouping Status: |cff90e0efWarn (LFG Badges & Invite Warnings Active)|r")
        elseif currentGroupingMode == Skyward.GROUPING_MODES.HIDE then
            groupingStatusText:SetText("Grouping Status: |cffff4d4dBlocked (Skyborne Groups Hidden & Blocked)|r")
        end
    end

    -- 5. Update Grouping Options Checkboxes
    if groupingBadgeCheckbox then
        groupingBadgeCheckbox:SetChecked(self:IsGroupingLfgBadgeEnabled())
    end
    if groupingConfirmCheckbox then
        groupingConfirmCheckbox:SetChecked(self:IsGroupingConfirmInviteEnabled())
    end

    -- 6. Update Cache Stats (Footer)
    if statsText then
        local total, skyborneCount = self:GetCacheStats()
        statsText:SetText(("Known Players in Cache: |cffffffff%d|r  |  Skyborne Identified: |cff00b4d8%d|r"):format(total, skyborneCount))
    end

    -- 7. Update Whitelist Scroll List
    self:UpdateWhitelistList()

    -- 8. Update Channels Checkboxes & Count
    for chKey, cb in pairs(channelCheckboxes) do
        cb:SetChecked(self:IsChannelFiltered(chKey))
    end
    if channelStatusText then
        local active, total = self:GetFilteredChannelCount()
        channelStatusText:SetText(("Active Channel Filters: |cff52b788%d|r of |cffffffff%d|r enabled"):format(active, total))
    end

    -- 9. Update Styling Sub-tab Elements
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
    f:SetSize(470, 580)
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

    -- Top-Level Navigation Tab Bar (Chat, Grouping, Whitelist)
    local tabBar = CreateFrame("Frame", nil, f)
    tabBar:SetSize(434, 28)
    tabBar:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)

    local tabs = {
        { id = "CHAT",      label = "Chat" },
        { id = "GROUPING",  label = "Grouping" },
        { id = "WHITELIST", label = "Whitelist" },
    }

    local tabX = 0
    for _, t in ipairs(tabs) do
        local btn = CreateStyledButton(tabBar, t.label, 140, 24)
        btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", tabX, 0)
        btn:SetScript("OnClick", function()
            SwitchTab(t.id)
        end)
        tabButtons[t.id] = btn
        tabX = tabX + 147
    end

    -- Tab Divider Line
    local tabDiv = f:CreateTexture(nil, "ARTWORK")
    tabDiv:SetSize(434, 1)
    tabDiv:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -4)
    tabDiv:SetColorTexture(0.35, 0.4, 0.45, 0.8)

    -- Container area for top-level tab contents
    local function CreateTabContentFrame()
        local content = CreateFrame("Frame", nil, f)
        content:SetPoint("TOPLEFT", tabDiv, "BOTTOMLEFT", 0, -6)
        content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 55)
        return content
    end

    ---------------------------------------------------------------------------
    -- MAIN TAB 1: CHAT
    ---------------------------------------------------------------------------
    local tabChat = CreateTabContentFrame()
    tabContents["CHAT"] = tabChat

    -- Sub-tab navigation bar for Chat (Filter Mode, Channels, Styling)
    local chatSubTabBar = CreateFrame("Frame", nil, tabChat)
    chatSubTabBar:SetSize(434, 24)
    chatSubTabBar:SetPoint("TOPLEFT", tabChat, "TOPLEFT", 0, 0)

    local chatSubTabs = {
        { id = "MODE",     label = "Filter Mode" },
        { id = "CHANNELS", label = "Channels" },
        { id = "STYLING",  label = "Styling" },
    }

    local subX = 0
    for _, st in ipairs(chatSubTabs) do
        local btn = CreateStyledButton(chatSubTabBar, st.label, 140, 22)
        btn:SetPoint("TOPLEFT", chatSubTabBar, "TOPLEFT", subX, 0)
        btn:SetScript("OnClick", function()
            SwitchChatSubTab(st.id)
        end)
        chatSubButtons[st.id] = btn
        subX = subX + 147
    end

    local chatSubDiv = tabChat:CreateTexture(nil, "ARTWORK")
    chatSubDiv:SetSize(434, 1)
    chatSubDiv:SetPoint("TOPLEFT", chatSubTabBar, "BOTTOMLEFT", 0, -4)
    chatSubDiv:SetColorTexture(0.25, 0.3, 0.35, 0.6)

    local function CreateChatSubFrame()
        local subContent = CreateFrame("Frame", nil, tabChat)
        subContent:SetPoint("TOPLEFT", chatSubDiv, "BOTTOMLEFT", 0, -6)
        subContent:SetPoint("BOTTOMRIGHT", tabChat, "BOTTOMRIGHT", 0, 0)
        return subContent
    end

    -- Sub-tab 1A: Chat Filter Mode
    local subChatMode = CreateChatSubFrame()
    chatSubContents["MODE"] = subChatMode

    chatStatusText = subChatMode:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chatStatusText:SetPoint("TOPLEFT", subChatMode, "TOPLEFT", 0, -2)
    chatStatusText:SetText("Chat Status: Initializing...")

    local modeHeader = subChatMode:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeHeader:SetPoint("TOPLEFT", chatStatusText, "BOTTOMLEFT", 0, -12)
    modeHeader:SetText("Public Channels Filter Mode:")

    local modeContainer = CreateFrame("Frame", nil, subChatMode)
    modeContainer:SetSize(434, 32)
    modeContainer:SetPoint("TOPLEFT", modeHeader, "BOTTOMLEFT", 0, -6)

    local modes = {
        { id = Skyward.MODES.OFF,  label = "Off (Normal)", width = 135 },
        { id = Skyward.MODES.WARN, label = "Warn",         width = 145 },
        { id = Skyward.MODES.HIDE, label = "Hide (Block)", width = 135 },
    }

    local btnX = 0
    for _, m in ipairs(modes) do
        local btn = CreateStyledButton(modeContainer, m.label, m.width, 26)
        btn:SetPoint("TOPLEFT", modeContainer, "TOPLEFT", btnX, 0)
        btn:SetScript("OnClick", function()
            Skyward:SetMode(m.id)
        end)
        chatModeButtons[m.id] = btn
        btnX = btnX + m.width + 9
    end

    local infoCard = CreateFrame("Frame", nil, subChatMode, backdropTemplate)
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
    cardHeader:SetText("Chat Filter Mode Details:")

    local cardDesc = infoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cardDesc:SetPoint("TOPLEFT", cardHeader, "BOTTOMLEFT", 0, -8)
    cardDesc:SetPoint("RIGHT", infoCard, "RIGHT", -12, 0)
    cardDesc:SetJustifyH("LEFT")
    cardDesc:SetText(
        "|cffffd100Off (Normal)|r:\nSkyward is idle. All messages and class colours appear normally.\n\n" ..
        "|cff00b4d8Warn|r:\nMessages from Skyborne players are styled with a prefix tag and/or custom name colour (configured in the Styling sub-tab).\n\n" ..
        "|cffff4d4dHide (Block)|r:\nCompletely suppresses public chat messages sent by Skyborne players."
    )

    local navTip = subChatMode:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    navTip:SetPoint("TOPLEFT", infoCard, "BOTTOMLEFT", 2, -16)
    navTip:SetText("Use the sub-tabs above to customise monitored Channels and Styling options.")

    -- Sub-tab 1B: Channels
    local subChatChannels = CreateChatSubFrame()
    chatSubContents["CHANNELS"] = subChatChannels
    subChatChannels:Hide()

    local chHeader = subChatChannels:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chHeader:SetPoint("TOPLEFT", subChatChannels, "TOPLEFT", 0, -2)
    chHeader:SetText("Channel Filter Toggles:")

    local chSub = subChatChannels:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    chSub:SetPoint("TOPLEFT", chHeader, "BOTTOMLEFT", 0, -3)
    chSub:SetText("Select which chat channels Skyward monitors. Unticked channels are never filtered.")

    channelStatusText = subChatChannels:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    channelStatusText:SetPoint("TOPLEFT", chSub, "BOTTOMLEFT", 0, -6)
    channelStatusText:SetText("Active Channel Filters: 9 of 9 enabled")

    local chCol1X = 10
    local chCol2X = 225
    local chY = -65

    for idx, def in ipairs(Skyward.CHANNEL_DEFINITIONS or {}) do
        local colX = (idx <= 5) and chCol1X or chCol2X
        local curY = chY - (((idx <= 5) and (idx - 1) or (idx - 6)) * 34)

        local cb = CreateCheckbox(subChatChannels, def.name, def.desc, function(isChecked)
            Skyward:SetChannelFiltered(def.key, isChecked)
            Skyward:UpdateGUI()
        end)
        cb:SetPoint("TOPLEFT", subChatChannels, "TOPLEFT", colX, curY)
        channelCheckboxes[def.key] = cb
    end

    local chBtnContainer = CreateFrame("Frame", nil, subChatChannels)
    chBtnContainer:SetSize(434, 30)
    chBtnContainer:SetPoint("BOTTOMLEFT", subChatChannels, "BOTTOMLEFT", 0, 10)

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

    -- Sub-tab 1C: Styling
    local subChatStyling = CreateChatSubFrame()
    chatSubContents["STYLING"] = subChatStyling
    subChatStyling:Hide()

    local stHeader = subChatStyling:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stHeader:SetPoint("TOPLEFT", subChatStyling, "TOPLEFT", 0, -2)
    stHeader:SetText("Styled Skyborne Message Appearance:")

    local stSub = subChatStyling:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    stSub:SetPoint("TOPLEFT", stHeader, "BOTTOMLEFT", 0, -3)
    stSub:SetText("Customise character name colour and prefix tags for Skyborne players.")

    tagCheckbox = CreateCheckbox(subChatStyling, "Add Prefix Tag:", "Toggle whether a prefix tag is added before Skyborne messages.", function(isChecked)
        Skyward:SetTagEnabled(isChecked)
        UpdateLivePreview()
    end)
    tagCheckbox:SetPoint("TOPLEFT", stSub, "BOTTOMLEFT", 2, -12)

    tagInput = CreateFrame("EditBox", "SkywardTagInput", subChatStyling, "InputBoxTemplate")
    tagInput:SetSize(180, 22)
    tagInput:SetPoint("LEFT", tagCheckbox.Label, "RIGHT", 12, 0)
    tagInput:SetAutoFocus(false)
    tagInput:SetMaxLetters(30)
    tagInput:SetText(Skyward:GetMarkTag())
    tagInput:SetScript("OnTextChanged", function(self)
        Skyward:SetMarkTag(self:GetText())
        UpdateLivePreview()
    end)

    nameColorCheckbox = CreateCheckbox(subChatStyling, "Replace Character Name Colour", "Toggle whether the character's class colour is replaced for Skyborne players.", function(isChecked)
        Skyward:SetReplaceNameColor(isChecked)
        Skyward:UpdateGUI()
    end)
    nameColorCheckbox:SetPoint("TOPLEFT", tagCheckbox, "BOTTOMLEFT", 0, -14)

    local colorContainer = CreateFrame("Frame", nil, subChatStyling)
    colorContainer:SetSize(434, 56)
    colorContainer:SetPoint("TOPLEFT", nameColorCheckbox, "BOTTOMLEFT", 0, -6)

    for idx, preset in ipairs(Skyward.MARK_COLOR_PRESETS or {}) do
        local row = (idx <= 3) and 0 or 1
        local col = (idx <= 3) and (idx - 1) or (idx - 4)
        local cbtnX = col * 144
        local cbtnY = - (row * 28)

        local btnText
        if preset.hex == "CHANNEL" then
            local chHex = Skyward:GetChannelColorHex("CHAT_MSG_CHANNEL", 2, 2)
            btnText = "|cff" .. chHex .. "Channel|r"
        else
            btnText = "|cff" .. preset.hex .. preset.label .. "|r"
        end

        local btn = CreateStyledButton(colorContainer, btnText, 138, 24)
        btn:SetPoint("TOPLEFT", colorContainer, "TOPLEFT", cbtnX, cbtnY)
        btn:SetScript("OnClick", function()
            Skyward:SetMarkColor(preset.hex)
            Skyward:UpdateGUI()
        end)
        colorPresetButtons[preset.hex] = btn
    end

    local previewLabel = subChatStyling:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", colorContainer, "BOTTOMLEFT", 0, -22)
    previewLabel:SetText("Live Chat Preview:")

    local previewBox = CreateFrame("Frame", nil, subChatStyling, backdropTemplate)
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
    -- MAIN TAB 2: GROUPING (LFG / LFM & Party Invites)
    ---------------------------------------------------------------------------
    local tabGrouping = CreateTabContentFrame()
    tabContents["GROUPING"] = tabGrouping
    tabGrouping:Hide()

    groupingStatusText = tabGrouping:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groupingStatusText:SetPoint("TOPLEFT", tabGrouping, "TOPLEFT", 0, -2)
    groupingStatusText:SetText("Grouping Status: Initializing...")

    local gModeHeader = tabGrouping:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gModeHeader:SetPoint("TOPLEFT", groupingStatusText, "BOTTOMLEFT", 0, -12)
    gModeHeader:SetText("LFG & Grouping Filter Mode:")

    local gModeContainer = CreateFrame("Frame", nil, tabGrouping)
    gModeContainer:SetSize(434, 32)
    gModeContainer:SetPoint("TOPLEFT", gModeHeader, "BOTTOMLEFT", 0, -6)

    local gModes = {
        { id = Skyward.GROUPING_MODES.OFF,  label = "Off (Normal)", width = 135 },
        { id = Skyward.GROUPING_MODES.WARN, label = "Warn",         width = 145 },
        { id = Skyward.GROUPING_MODES.HIDE, label = "Hide (Block)", width = 135 },
    }

    local gBtnX = 0
    for _, gm in ipairs(gModes) do
        local btn = CreateStyledButton(gModeContainer, gm.label, gm.width, 26)
        btn:SetPoint("TOPLEFT", gModeContainer, "TOPLEFT", gBtnX, 0)
        btn:SetScript("OnClick", function()
            Skyward:SetGroupingMode(gm.id)
        end)
        groupingModeButtons[gm.id] = btn
        gBtnX = gBtnX + gm.width + 9
    end

    -- Grouping Options Header & Checkboxes
    local gOptionsHeader = tabGrouping:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gOptionsHeader:SetPoint("TOPLEFT", gModeContainer, "BOTTOMLEFT", 0, -14)
    gOptionsHeader:SetText("Warning & Detection Options:")

    groupingBadgeCheckbox = CreateCheckbox(
        tabGrouping,
        "Badge & highlight group listings in LFG browser",
        "Displays a prominent [Skyborne] warning badge in the Premade Group Finder when the leader is Skyborne.",
        function(isChecked)
            Skyward:SetGroupingLfgBadgeEnabled(isChecked)
        end
    )
    groupingBadgeCheckbox:SetPoint("TOPLEFT", gOptionsHeader, "BOTTOMLEFT", 2, -6)

    groupingConfirmCheckbox = CreateCheckbox(
        tabGrouping,
        "Warning confirmation popup when applying or accepting invites",
        "Prompts a confirmation warning dialog before applying to a Skyborne-led group or accepting a party invite from a Skyborne player.",
        function(isChecked)
            Skyward:SetGroupingConfirmInviteEnabled(isChecked)
        end
    )
    groupingConfirmCheckbox:SetPoint("TOPLEFT", groupingBadgeCheckbox, "BOTTOMLEFT", 0, -6)

    -- Grouping Information Card
    local gInfoCard = CreateFrame("Frame", nil, tabGrouping, backdropTemplate)
    gInfoCard:SetSize(434, 150)
    gInfoCard:SetPoint("TOPLEFT", groupingConfirmCheckbox, "BOTTOMLEFT", -2, -14)
    gInfoCard:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    gInfoCard:SetBackdropColor(0, 0, 0, 0.4)
    gInfoCard:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)

    local gCardHeader = gInfoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    gCardHeader:SetPoint("TOPLEFT", 12, -12)
    gCardHeader:SetText("Grouping Filter Mode Details:")

    local gCardDesc = gInfoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gCardDesc:SetPoint("TOPLEFT", gCardHeader, "BOTTOMLEFT", 0, -8)
    gCardDesc:SetPoint("RIGHT", gInfoCard, "RIGHT", -12, 0)
    gCardDesc:SetJustifyH("LEFT")
    gCardDesc:SetText(
        "|cffffd100Off (Normal)|r:\nAll LFG listings and group invitations behave normally.\n\n" ..
        "|cff00b4d8Warn|r:\nHighlights Skyborne leaders in the Group Finder and prompts a warning confirmation dialog before applying or accepting group invitations.\n\n" ..
        "|cffff4d4dHide (Block)|r:\nCompletely suppresses Skyborne groups from LFG search results and automatically declines party invites from Skyborne players."
    )

    -- Test / Simulation Button for Grouping
    local simLfgBtn = CreateStyledButton(tabGrouping, "Simulate Skyborne LFG Listing", 215, 24)
    simLfgBtn:SetPoint("TOPLEFT", gInfoCard, "BOTTOMLEFT", 2, -14)
    simLfgBtn:SetScript("OnClick", function()
        Skyward:SimulateLfgWarning()
    end)

    ---------------------------------------------------------------------------
    -- MAIN TAB 3: WHITELIST
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

    local scrollFrame = CreateFrame("ScrollFrame", "SkywardWhitelistScrollFrame", tabWhitelist, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(410, 310)
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
    whitelistScrollChild:SetSize(410, 310)
    scrollFrame:SetScrollChild(whitelistScrollChild)

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
        SwitchChatSubTab(currentChatSubTab)
        Skyward:UpdateGUI()
    end)

    mainFrame = f
    SwitchTab("CHAT")
    SwitchChatSubTab("MODE")
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
