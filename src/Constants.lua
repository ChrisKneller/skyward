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

-- Granular channel definitions for settings & tabs
Skyward.CHANNEL_DEFINITIONS = {
    { key = "GENERAL",      name = "General",          desc = "Zone General chat (e.g., [1. General - Orgrimmar])" },
    { key = "TRADE",        name = "Trade",            desc = "City Trade chat (e.g., [2. Trade - English])" },
    { key = "SERVICES",     name = "Services",         desc = "Trade Services / Boosting channel" },
    { key = "LFG",          name = "LookingForGroup",  desc = "Global LookingForGroup channel" },
    { key = "LOCALDEFENSE", name = "LocalDefense",     desc = "Zone defense alerts" },
    { key = "SAY",          name = "Say (/say)",       desc = "Local proximity speech" },
    { key = "YELL",         name = "Yell (/yell)",     desc = "Wide proximity shout" },
    { key = "EMOTE",        name = "Emotes (/emote)",  desc = "Player text emotes (/emote, /me)" },
    { key = "CUSTOM",       name = "Custom",           desc = "Player-created or custom channels (e.g., /join world)" },
}

-- Character name color presets for "Styled" mode
Skyward.MARK_COLOR_PRESETS = {
    { id = "CHANNEL", label = "Channel",    hex = "CHANNEL" },
    { id = "GREY",    label = "Muted Grey", hex = "777b80" },
    { id = "DARK",    label = "Dark Slate", hex = "4f5660" },
    { id = "SLATE",   label = "Faded Blue", hex = "5c7080" },
    { id = "VIOLET",  label = "Dim Violet", hex = "6c5b7b" },
    { id = "ASH",     label = "Ash Grey",   hex = "8c8c8c" },
}

-- Default SavedVariables
Skyward.DEFAULT_SETTINGS = {
    mode = Skyward.MODES.OFF,     -- Default to OFF as requested ("default off")
    replaceNameColor = true,      -- Toggle whether character name class color is replaced
    markColor = "777b80",         -- 6-hex color code or "CHANNEL"
    showTag = true,               -- Toggle prefix tag on/off
    markTag = "[Skyborne]",       -- Custom prefix tag
    filterChannels = {
        GENERAL      = true,
        TRADE        = true,
        SERVICES     = true,
        LFG          = true,
        LOCALDEFENSE = true,
        SAY          = true,
        YELL         = true,
        EMOTE        = true,
        CUSTOM       = true,
    },
    whitelist = {
        -- Format: ["playername-realm"] = { name = "DisplayName", addedAt = 123456 }
    },
    cache = {
        -- Format: [guid] = { race = "Skyborne", isSkyborne = true, name = "Player-Realm", timestamp = 123456 }
    },
    debug = false,
}

