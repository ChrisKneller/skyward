--[[
    Skyward: Chat Filter Engine
    Hooks public chat channels and filters or marks messages originating from Skyborne characters.
]]

local ADDON_NAME, Skyward = ...

-- Format a message for "MARKED" mode (greyed out / strikethrough style)
function Skyward:FormatMarkedMessage(msg)
    if not msg then return msg end

    local dimColor = "|cff777b80"
    local tag = "|cff8b949e[Skyborne]|r "

    -- Preserve clickable links (items, quests, etc.) while keeping text dimmed
    -- Replace reset tags (|r) inside message so they return to our dimmed color instead of white/channel color
    local dimmedMsg = msg:gsub("|r", "|r" .. dimColor)

    local markStyle = (self.db and self.db.markStyle) or "DIM"
    if markStyle == "STRIKE" then
        return tag .. dimColor .. "~~ " .. dimmedMsg .. " ~~|r"
    elseif markStyle == "TAG" then
        return tag .. msg
    else
        -- Default: "DIM" (Muted / Greyed Out with [Skyborne] indicator)
        return tag .. dimColor .. dimmedMsg .. "|r"
    end
end

-- Main Chat Frame message filter
local function SkywardChatEventFilter(self, event, msg, author, languageName, channelName, target, flags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
    -- If addon is disabled or in OFF mode, do not modify or block anything
    local currentMode = Skyward:GetMode()
    if currentMode == Skyward.MODES.OFF then
        return false
    end

    -- Fast-path: Check whitelist
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
        -- Modify message to appear dimmed/greyed out
        local newMsg = Skyward:FormatMarkedMessage(msg)
        return false, newMsg, author, languageName, channelName, target, flags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons
    end

    return false
end

-- Register chat filters for public channels
function Skyward:InitChatFilter()
    for _, eventName in ipairs(Skyward.PUBLIC_CHAT_EVENTS) do
        ChatFrame_AddMessageEventFilter(eventName, SkywardChatEventFilter)
    end
end
