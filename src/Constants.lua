--[[
    Skyward: Constants & Configuration Defaults
    Addon for World of Warcraft Forever
]]

local ADDON_NAME, Skyward = ...

Skyward.VERSION = "1.0.0"
Skyward.TITLE = "Skyward"
Skyward.INTERFACE = "110100"

-- Filter Modes
Skyward.MODES = {
    OFF = "OFF",       -- Filter inactive; all messages displayed normally
    MARKED = "MARKED", -- Messages are visually altered (dimmed/greyed out with [Skyborne] tag)
    HIDE = "HIDE",     -- Messages are completely suppressed from chat
}

-- Target Race Tokens & Identifiers
-- In WoW Forever, "Skyborne" may appear as a localized race string or token
Skyward.TARGET_RACES = {
    ["skyborne"] = true,
    ["the skyborne"] = true,
    ["skyborn"] = true,
}

-- Default public chat events to monitor
Skyward.PUBLIC_CHAT_EVENTS = {
    "CHAT_MSG_CHANNEL",    -- General, Trade, Services, LocalDefense, etc.
    "CHAT_MSG_SAY",        -- Local /say
    "CHAT_MSG_YELL",       -- Local /yell
    "CHAT_MSG_TEXT_EMOTE", -- Public /emote
}

-- UI Color Palette (Hex & RGB)
Skyward.COLORS = {
    PRIMARY       = "|cff00b4d8", -- Skyward Cyan
    ACCENT        = "|cff90e0ef", -- Light Blue
    WARNING       = "|cffffaa00", -- Amber
    DANGER        = "|cffff4d4d", -- Red
    SUCCESS       = "|cff52b788", -- Green
    MUTED         = "|cff808080", -- Grey for marked messages
    STRIKETHROUGH = "|cff666666", -- Darker grey
    WHITE         = "|cffffffff",
}

-- Default SavedVariables
Skyward.DEFAULT_SETTINGS = {
    mode = Skyward.MODES.OFF,     -- Default to OFF as requested ("default off")
    markStyle = "DIM",            -- "DIM", "TAG", or "STRIKE"
    filterChannels = {
        ["CHAT_MSG_CHANNEL"] = true,
        ["CHAT_MSG_SAY"] = true,
        ["CHAT_MSG_YELL"] = true,
        ["CHAT_MSG_TEXT_EMOTE"] = true,
    },
    whitelist = {
        -- Format: ["playername-realm"] = true
    },
    cache = {
        -- Format: [guid] = { race = "Skyborne", isSkyborne = true, name = "Player-Realm", timestamp = 123456 }
    },
    debug = false,
}
