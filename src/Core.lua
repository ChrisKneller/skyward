--[[
    Skyward: Core & Lifecycle Management
    Addon for World of Warcraft Forever
    Handles initialization, slash commands, chat simulation, and category registration.
]]

local ADDON_NAME, Skyward = ...

-- Formatted chat printing
function Skyward:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(Skyward.COLORS.PRIMARY .. "[Skyward]|r " .. tostring(msg))
end

-- Slash Command Handler
local function HandleSlashCommand(msg)
    local msg = strtrim(msg or "")
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = command and command:lower() or ""

    if command == "" then
        -- Open GUI panel
        Skyward.GUI:Toggle()
        return
    end

    if command == "off" then
        Skyward:SetMode(Skyward.MODES.OFF)
    elseif command == "marked" or command == "mark" or command == "dim" then
        Skyward:SetMode(Skyward.MODES.MARKED)
    elseif command == "hide" or command == "block" then
        Skyward:SetMode(Skyward.MODES.HIDE)
    elseif command == "whitelist" or command == "wl" then
        local subCmd, target = rest:match("^(%S*)%s*(.-)$")
        subCmd = subCmd and subCmd:lower() or ""

        if subCmd == "add" and target ~= "" then
            Skyward:AddWhitelist(target)
        elseif (subCmd == "remove" or subCmd == "rem" or subCmd == "del") and target ~= "" then
            Skyward:RemoveWhitelist(target)
        elseif subCmd == "list" then
            local wl = Skyward:GetWhitelist()
            local count = 0
            Skyward:Print("Whitelisted Characters:")
            for key, data in pairs(wl) do
                count = count + 1
                local name = (type(data) == "table" and data.name) or key
                DEFAULT_CHAT_FRAME:AddMessage("  - |cff52b788" .. name .. "|r")
            end
            if count == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  (No characters whitelisted)")
            end
        else
            Skyward:Print("Whitelist usage: /skyward whitelist <add|remove|list> [CharacterName]")
        end
    elseif command == "test" then
        Skyward:RunChatSimulation()
    elseif command == "help" then
        Skyward:Print("Available commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff90e0ef/skyward|r - Open configuration panel")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff90e0ef/skyward <off|marked|hide>|r - Change chat filter mode")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff90e0ef/skyward whitelist add <Name>|r - Exempt character from filtering")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff90e0ef/skyward whitelist remove <Name>|r - Remove character from whitelist")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff90e0ef/skyward whitelist list|r - View whitelisted characters")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff90e0ef/skyward test|r - Simulate Skyborne chat filtering")
    else
        Skyward:Print("Unknown command. Type |cff90e0ef/skyward help|r for options, or |cff90e0ef/skyward|r to open settings.")
    end
end

-- Register Slash Command at file load time (WoW standard for reliable indexing)
SLASH_SKYWARD1 = "/skyward"
SlashCmdList["SKYWARD"] = HandleSlashCommand



-- Simulation tool for in-game testing
function Skyward:RunChatSimulation()
    local mode = self:GetMode()
    self:Print(("Running chat simulation under mode: |cffffd100%s|r"):format(mode))

    -- Simulated players
    local skybornePlayer = "Aeloria Skyward"
    local whitelistedPlayer = "Zephyr Skyward"
    local sampleMessage = "Greetings mortals, the Skyborne have taken flight above Azeroth!"

    -- Ensure simulated race data in cache
    self:SetPlayerRaceCache("Player-Sim-001", skybornePlayer, "Skyborne", true)
    self:SetPlayerRaceCache("Player-Sim-002", whitelistedPlayer, "Skyborne", true)

    -- Ensure whitelistedPlayer is actually on whitelist for demo
    self.db.whitelist[self:NormalizeName(whitelistedPlayer)] = { name = whitelistedPlayer, addedAt = time() }

    -- 1. Test Skyborne Player Message
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa--- Test 1: Standard Skyborne Player ---|r")
    if mode == Skyward.MODES.HIDE then
        self:Print("|cffff4d4d[BLOCKED]|r Message from " .. skybornePlayer .. " was suppressed by Skyward.")
    elseif mode == Skyward.MODES.MARKED then
        local formatted = self:FormatMarkedMessage(sampleMessage)
        DEFAULT_CHAT_FRAME:AddMessage(("[1. General] [%s]: %s"):format(skybornePlayer, formatted))
    else
        DEFAULT_CHAT_FRAME:AddMessage(("[1. General] [%s]: %s"):format(skybornePlayer, sampleMessage))
    end

    -- 2. Test Whitelisted Skyborne Player Message
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa--- Test 2: Whitelisted Skyborne Player ---|r")
    DEFAULT_CHAT_FRAME:AddMessage(("[1. General] [%s]: %s |cff52b788(Bypassed filter via Whitelist)|r"):format(whitelistedPlayer, sampleMessage))
end

-- Integration with WoW Game Menu / Settings Panel
local function RegisterGameMenuCategory()
    -- Create small container frame for modern Settings API
    local panel = CreateFrame("Frame", "SkywardSettingsPanel", UIParent)
    panel.name = "Skyward"

    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 16, -16)
    header:SetText("Skyward - Skyborne Shield")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    desc:SetText("Filter and shield against interactions with the Skyborne race in WoW Forever.")

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(180, 28)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openBtn:SetText("Open Skyward Control Panel")
    openBtn:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        Skyward.GUI:Toggle()
    end)

    -- Register with modern WoW Settings API if present
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Skyward")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Addon Lifecycle Events
local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_LOGIN")

coreFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        Skyward:InitDatabase()
        Skyward:InitChatFilter()
        Skyward:InitRaceDetector()
    elseif event == "PLAYER_LOGIN" then
        RegisterGameMenuCategory()

        -- Ensure registration in hash_SlashCmdList if present in the client
        if hash_SlashCmdList then
            hash_SlashCmdList["/SKYWARD"] = HandleSlashCommand
            hash_SlashCmdList["/SW"] = nil
            hash_SlashCmdList["/SKY"] = nil
        end

        local currentMode = Skyward:GetMode()
        Skyward:Print(("Loaded |cff90e0efv%s|r. Current Mode: |cffffd100%s|r. Type |cff00b4d8/skyward|r for settings."):format(Skyward.VERSION, currentMode))
    end
end)
