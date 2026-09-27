--[[
    Skyward: Chat Filter Engine
    Hooks public chat channels, filters or marks messages from Skyborne,
    and supports whole-line recoloring with custom colors, opacity, and prefixes.
]]

local ADDON_NAME, Skyward = ...

-- Invisible marker code used to safely identify filtered lines in the ChatFrame AddMessage hook
local SKYWARD_MARKER = "|c00010203|r"
Skyward.SKYWARD_MARKER = SKYWARD_MARKER

-- Determine channel identifier key from event and channel arguments
function Skyward:GetChannelKey(event, channelString, zoneChannelID, channelBaseName)
    if event == "CHAT_MSG_SAY" then return "SAY" end
    if event == "CHAT_MSG_YELL" then return "YELL" end
    if event == "CHAT_MSG_TEXT_EMOTE" then return "EMOTE" end

    if event == "CHAT_MSG_CHANNEL" then
        local base = (channelBaseName or ""):lower()
        local str = (channelString or ""):lower()

        if base:find("general") or str:find("general") or zoneChannelID == 1 then
            return "GENERAL"
        elseif base:find("trade") or str:find("trade") or zoneChannelID == 2 then
            return "TRADE"
        elseif base:find("services") or str:find("services") then
            return "SERVICES"
        elseif base:find("lookingforgroup") or str:find("lookingforgroup") or base:find("lfg") or str:find("lfg") or zoneChannelID == 4 or zoneChannelID == 6 then
            return "LFG"
        elseif base:find("localdefense") or str:find("localdefense") or zoneChannelID == 3 then
            return "LOCALDEFENSE"
        else
            return "CUSTOM"
        end
    end

    return "OTHER"
end

-- Format a message for "MARKED" (STYLED) mode
function Skyward:FormatMarkedMessage(msg)
    if not msg then return msg end

    local dimColor = self:GetMarkColorCode()
    local showTag = self:IsTagEnabled()
    local customTag = self:GetMarkTag()
    local tag = ""
    if showTag and customTag and customTag ~= "" then
        tag = customTag .. " "
    end

    local formatted = ""
    if dimColor then
        -- Preserve clickable links by ensuring resets return to our dim color
        local dimmedMsg = msg:gsub("|r", "|r" .. dimColor)
        formatted = tag .. dimColor .. dimmedMsg .. "|r"
    else
        -- Regular text color
        formatted = tag .. msg
    end

    -- Include invisible marker tag so AddMessage hook knows to recolor the entire line if enabled
    return SKYWARD_MARKER .. formatted
end

-- Helper to recolor an entire chat line (including channel name and sender)
local function RecolorWholeLine(text, dimColor)
    if not text then return text end
    -- Remove the invisible detection marker
    local clean = text:gsub("|c00010203|r", "")

    -- If Regular text color is selected, don't recolor the line
    if not dimColor then
        return clean
    end

    -- Replace all 8-digit color codes (|caarrggbb) with our chosen dimColor.
    -- Crucial: ONLY match exact 8 hex digits once to avoid substring re-matching bugs.
    local recolored = clean:gsub("|c%x%x%x%x%x%x%x%x", dimColor)
    -- Replace internal color resets so they maintain the dim color
    recolored = recolored:gsub("|r", dimColor)
    return recolored .. "|r"
end

-- Hook a ChatFrame's AddMessage method for whole-line styling
local function HookChatFrame(frame)
    if not frame or frame.SkywardHooked then return end
    frame.SkywardHooked = true

    local origAddMessage = frame.AddMessage
    frame.AddMessage = function(self, text, r, g, b, id, ...)
        if text and type(text) == "string" and text:find(SKYWARD_MARKER, 1, true) then
            if Skyward:IsDimWholeLine() then
                local dimColor = Skyward:GetMarkColorCode()
                text = RecolorWholeLine(text, dimColor)
            else
                -- Just strip the marker
                text = text:gsub(SKYWARD_MARKER, "")
            end
        end
        return origAddMessage(self, text, r, g, b, id, ...)
    end
end

-- Hook all existing and future chat windows
function Skyward:HookAllChatFrames()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. i]
        if frame then
            HookChatFrame(frame)
        end
    end

    -- Hook temporary / whisper tabs if FCF function exists
    if FCF_OpenTemporaryWindow and not self.FCFHooked then
        self.FCFHooked = true
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            Skyward:HookAllChatFrames()
        end)
    end
end

-- Main Chat Frame message event filter
local function SkywardChatEventFilter(self, event, msg, author, languageName, channelName, target, flags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
    -- If addon is disabled or in OFF mode, do not modify or block anything
    local currentMode = Skyward:GetMode()
    if currentMode == Skyward.MODES.OFF then
        return false
    end

    -- Check if this specific channel is enabled for filtering
    local channelKey = Skyward:GetChannelKey(event, channelName, zoneChannelID, channelBaseName)
    if not Skyward:IsChannelFiltered(channelKey) then
        return false
    end

    -- Fast-path: Check whitelist (exempt players are never filtered)
    if Skyward:IsWhitelisted(author) then
        return false
    end

    -- Check if author is Skyborne
    local isSkyborne = Skyward:IsAuthorSkyborne(guid, author)
    if not isSkyborne then
        return false
    end

    -- Skyborne detected!
    if currentMode == Skyward.MODES.HIDE then
        -- Suppress message completely
        return true
    elseif currentMode == Skyward.MODES.MARKED then
        -- Modify message to appear dimmed/greyed out with chosen styling
        local newMsg = Skyward:FormatMarkedMessage(msg)
        return false, newMsg, author, languageName, channelName, target, flags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons
    end

    return false
end

-- Register chat filters for public channels and hook frames
function Skyward:InitChatFilter()
    for _, eventName in ipairs(Skyward.PUBLIC_CHAT_EVENTS) do
        ChatFrame_AddMessageEventFilter(eventName, SkywardChatEventFilter)
    end

    self:HookAllChatFrames()
end
