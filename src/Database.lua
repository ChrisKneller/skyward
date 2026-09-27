--[[
    Skyward: Database & Storage Management
    Handles SavedVariables, Whitelist CRUD, and Race Cache
]]

local ADDON_NAME, Skyward = ...

-- Helper: Normalize character name (removes spaces, lowercases, handles realm)
function Skyward:NormalizeName(name)
    if not name or type(name) ~= "string" then return nil end
    local cleanName = strtrim(name):lower()
    cleanName = cleanName:gsub("%s+", " ") -- Collapse multiple spaces for the two-name system
    return cleanName
end

-- Helper: Capitalize character name (e.g. "chad obolt" -> "Chad Obolt", "aeloria-stormrage" -> "Aeloria-Stormrage")
function Skyward:CapitalizeName(name)
    if not name or type(name) ~= "string" then return name end
    local clean = strtrim(name):gsub("%s+", " ")

    local function capWord(w)
        return w:sub(1,1):upper() .. w:sub(2):lower()
    end

    local pName, realm = clean:match("^([^-]+)%-(.+)$")
    if pName and realm then
        local capPName = pName:gsub("(%a[%w']*)", capWord)
        local capRealm = realm:gsub("(%a[%w']*)", capWord)
        return capPName .. "-" .. capRealm
    else
        return clean:gsub("(%a[%w']*)", capWord)
    end
end

-- Initialize or migrate database
function Skyward:InitDatabase()
    if type(SkywardDB) ~= "table" then
        SkywardDB = {}
    end

    -- Deep copy defaults into SkywardDB if missing
    for key, defaultValue in pairs(Skyward.DEFAULT_SETTINGS) do
        if SkywardDB[key] == nil then
            if type(defaultValue) == "table" then
                SkywardDB[key] = {}
                for subKey, subVal in pairs(defaultValue) do
                    SkywardDB[key][subKey] = subVal
                end
            else
                SkywardDB[key] = defaultValue
            end
        end
    end

    -- Ensure whitelist, cache, and filterChannels sub-tables exist
    SkywardDB.whitelist = SkywardDB.whitelist or {}
    SkywardDB.cache = SkywardDB.cache or {}
    SkywardDB.filterChannels = SkywardDB.filterChannels or {}

    -- Ensure all defined channels have a setting (defaults to true)
    if Skyward.DEFAULT_SETTINGS and Skyward.DEFAULT_SETTINGS.filterChannels then
        for chKey, defaultState in pairs(Skyward.DEFAULT_SETTINGS.filterChannels) do
            if SkywardDB.filterChannels[chKey] == nil then
                SkywardDB.filterChannels[chKey] = defaultState
            end
        end
    end

    -- Capitalize any existing whitelist entries
    for key, data in pairs(SkywardDB.whitelist) do
        if type(data) == "table" and data.name then
            data.name = self:CapitalizeName(data.name)
        elseif type(data) == "string" then
            SkywardDB.whitelist[key] = { name = self:CapitalizeName(data), addedAt = time() }
        end
    end

    -- Migrate old Zephyr-Skyward to Zephyr Skyward
    if SkywardDB.whitelist["zephyr-skyward"] then
        SkywardDB.whitelist["zephyr-skyward"] = nil
        SkywardDB.whitelist["zephyr skyward"] = { name = "Zephyr Skyward", addedAt = time() }
    end
    if SkywardDB.whitelist["aeloria-skyward"] then
        SkywardDB.whitelist["aeloria-skyward"] = nil
        SkywardDB.whitelist["aeloria skyward"] = { name = "Aeloria Skyward", addedAt = time() }
    end

    -- Ensure styling defaults exist
    if SkywardDB.markColor == nil then SkywardDB.markColor = "777b80" end
    if SkywardDB.markTag == nil then SkywardDB.markTag = "[Skyborne]" end
    if SkywardDB.showTag == nil then SkywardDB.showTag = true end

    -- Ensure grouping defaults exist
    if SkywardDB.groupingMode == nil then SkywardDB.groupingMode = Skyward.GROUPING_MODES.OFF end
    if SkywardDB.groupingLfgBadge == nil then SkywardDB.groupingLfgBadge = true end
    if SkywardDB.groupingConfirmInvite == nil then SkywardDB.groupingConfirmInvite = true end

    -- Migrate legacy MARKED mode to WARN
    if SkywardDB.mode == "MARKED" then SkywardDB.mode = "WARN" end

    self.db = SkywardDB
end

-- Channel Filtering State Helpers
function Skyward:IsChannelFiltered(channelKey)
    if not self.db or not self.db.filterChannels then
        return true
    end
    if self.db.filterChannels[channelKey] == nil then
        return true
    end
    return self.db.filterChannels[channelKey] == true
end

function Skyward:SetChannelFiltered(channelKey, enabled)
    if not self.db then return end
    self.db.filterChannels = self.db.filterChannels or {}
    self.db.filterChannels[channelKey] = enabled and true or false
end

function Skyward:GetFilteredChannelCount()
    if not self.db or not self.db.filterChannels or not Skyward.CHANNEL_DEFINITIONS then
        return 0, 0
    end
    local total = #Skyward.CHANNEL_DEFINITIONS
    local active = 0
    for _, def in ipairs(Skyward.CHANNEL_DEFINITIONS) do
        if self:IsChannelFiltered(def.key) then
            active = active + 1
        end
    end
    return active, total
end

-- Marking Style & Character Name Coloring Helpers
function Skyward:IsReplaceNameColorEnabled()
    if not self.db or self.db.replaceNameColor == nil then
        return true
    end
    return self.db.replaceNameColor == true
end

function Skyward:SetReplaceNameColor(enabled)
    if not self.db then return end
    self.db.replaceNameColor = enabled and true or false
end

function Skyward:GetChannelColorHex(event, zoneChannelID, channelIndex)
    if ChatTypeInfo then
        local info
        if event == "CHAT_MSG_CHANNEL" then
            local chNum = zoneChannelID or channelIndex
            if chNum and ChatTypeInfo["CHANNEL" .. chNum] then
                info = ChatTypeInfo["CHANNEL" .. chNum]
            elseif ChatTypeInfo["CHANNEL"] then
                info = ChatTypeInfo["CHANNEL"]
            end
        elseif event then
            local chatType = event:gsub("^CHAT_MSG_", "")
            info = ChatTypeInfo[chatType]
        else
            -- Default to Trade channel 2 for preview
            info = ChatTypeInfo["CHANNEL2"] or ChatTypeInfo["CHANNEL"]
        end

        if info and info.r and info.g and info.b then
            return string.format("%02x%02x%02x", math.floor(info.r * 255 + 0.5), math.floor(info.g * 255 + 0.5), math.floor(info.b * 255 + 0.5))
        end
    end
    -- Fallback default channel color (the light pinkish-peach set in user screenshot)
    return "e5c8d0"
end

function Skyward:GetMarkColorCode(event, zoneChannelID, channelIndex)
    if not self:IsReplaceNameColorEnabled() then
        return nil
    end

    local color = (self.db and self.db.markColor) or "777b80"
    if color == "CHANNEL" then
        local hex = self:GetChannelColorHex(event, zoneChannelID, channelIndex)
        return "|cff" .. hex
    end

    return "|cff" .. color
end

function Skyward:IsTagEnabled()
    if not self.db or self.db.showTag == nil then
        return true
    end
    return self.db.showTag == true
end

function Skyward:SetTagEnabled(enabled)
    if not self.db then return end
    self.db.showTag = enabled and true or false
end

function Skyward:GetMarkTag()
    if not self.db or self.db.markTag == nil then
        return "[Skyborne]"
    end
    return self.db.markTag
end

function Skyward:SetMarkTag(tag)
    if not self.db then return end
    self.db.markTag = tag or ""
end

function Skyward:SetMarkColor(hex)
    if not self.db then return end
    self.db.markColor = hex or "777b80"
end



-- Get current chat filter mode ("OFF", "WARN", "HIDE")
function Skyward:GetMode()
    if not self.db then return Skyward.MODES.OFF end
    local mode = self.db.mode or Skyward.MODES.OFF
    if mode == "MARKED" then mode = "WARN" end
    return mode
end

-- Set chat filter mode
function Skyward:SetMode(newMode)
    if not self.db then return end
    if newMode == "MARKED" then newMode = "WARN" end
    if newMode == Skyward.MODES.OFF or newMode == Skyward.MODES.WARN or newMode == Skyward.MODES.HIDE then
        self.db.mode = newMode
        self:Print(("Public chat filter mode set to: |cffffd100%s|r"):format(newMode))
        if self.UpdateGUI then
            self:UpdateGUI()
        end
    end
end

-- Grouping & LFG Mode & Options Helpers
function Skyward:GetGroupingMode()
    if not self.db then return Skyward.GROUPING_MODES.OFF end
    return self.db.groupingMode or Skyward.GROUPING_MODES.OFF
end

function Skyward:SetGroupingMode(newMode)
    if not self.db then return end
    if newMode == Skyward.GROUPING_MODES.OFF or newMode == Skyward.GROUPING_MODES.WARN or newMode == Skyward.GROUPING_MODES.HIDE then
        self.db.groupingMode = newMode
        self:Print(("Grouping filter mode set to: |cffffd100%s|r"):format(newMode))
        if self.UpdateGUI then
            self:UpdateGUI()
        end
    end
end

function Skyward:IsGroupingLfgBadgeEnabled()
    if not self.db or self.db.groupingLfgBadge == nil then
        return true
    end
    return self.db.groupingLfgBadge == true
end

function Skyward:SetGroupingLfgBadgeEnabled(enabled)
    if not self.db then return end
    self.db.groupingLfgBadge = enabled and true or false
end

function Skyward:IsGroupingConfirmInviteEnabled()
    if not self.db or self.db.groupingConfirmInvite == nil then
        return true
    end
    return self.db.groupingConfirmInvite == true
end

function Skyward:SetGroupingConfirmInviteEnabled(enabled)
    if not self.db then return end
    self.db.groupingConfirmInvite = enabled and true or false
end

-- Whitelist Management
function Skyward:IsWhitelisted(characterName)
    if not characterName or not self.db or not self.db.whitelist then
        return false
    end

    local norm = self:NormalizeName(characterName)
    if not norm then return false end

    -- Check direct match (e.g. "player-realm" or "player")
    if self.db.whitelist[norm] then
        return true
    end

    -- Check name without realm if name contained a dash
    local shortName = norm:match("^([^-]+)")
    if shortName and self.db.whitelist[shortName] then
        return true
    end



    -- Check if whitelist has "player" and given is "player-realm"
    for whitelistedName in pairs(self.db.whitelist) do
        local wlShort = whitelistedName:match("^([^-]+)")
        if wlShort and wlShort == shortName then
            return true
        end
    end

    return false
end

function Skyward:AddWhitelist(characterName)
    if not characterName or strtrim(characterName) == "" then
        return false, "Invalid character name."
    end

    local norm = self:NormalizeName(characterName)
    local displayName = self:CapitalizeName(characterName)

    if self.db.whitelist[norm] then
        return false, ("'%s' is already in the whitelist."):format(displayName)
    end

    self.db.whitelist[norm] = {
        name = displayName,
        addedAt = time(),
    }

    self:Print(("Added |cff52b788%s|r to the whitelist."):format(displayName))
    if self.UpdateGUI then self:UpdateGUI() end
    return true
end

function Skyward:RemoveWhitelist(characterName)
    if not characterName then return false, "No name specified." end
    local norm = self:NormalizeName(characterName)

    -- Try direct match
    if self.db.whitelist[norm] then
        local displayName = self.db.whitelist[norm].name or characterName
        self.db.whitelist[norm] = nil
        self:Print(("Removed |cffff4d4d%s|r from the whitelist."):format(displayName))
        if self.UpdateGUI then self:UpdateGUI() end
        return true
    end

    -- Try matching display name or short name
    for key, data in pairs(self.db.whitelist) do
        if key == norm or (type(data) == "table" and data.name and data.name:lower() == norm) then
            local displayName = (type(data) == "table" and data.name) or key
            self.db.whitelist[key] = nil
            self:Print(("Removed |cffff4d4d%s|r from the whitelist."):format(displayName))
            if self.UpdateGUI then self:UpdateGUI() end
            return true
        end
    end

    return false, ("'%s' was not found in the whitelist."):format(characterName)
end

function Skyward:GetWhitelist()
    if not self.db then return {} end
    return self.db.whitelist or {}
end

-- Cache Management
function Skyward:SetPlayerRaceCache(guid, name, race, isSkyborne)
    if not self.db or not self.db.cache then return end

    local entry = {
        race = race or "Unknown",
        isSkyborne = isSkyborne and true or false,
        name = name,
        updated = time(),
    }

    if guid and guid ~= "" then
        self.db.cache[guid] = entry
    end

    if name and name ~= "" then
        local norm = self:NormalizeName(name)
        if norm then
            self.db.cache["name:" .. norm] = entry
        end
    end
end

function Skyward:GetPlayerRaceCache(guid, name)
    if not self.db or not self.db.cache then return nil end

    if guid and self.db.cache[guid] then
        return self.db.cache[guid]
    end

    if name then
        local norm = self:NormalizeName(name)
        if norm and self.db.cache["name:" .. norm] then
            return self.db.cache["name:" .. norm]
        end
    end

    return nil
end

function Skyward:ClearCache()
    if not self.db then return end
    self.db.cache = {}
    self:Print("Race detection cache cleared.")
    if self.UpdateGUI then self:UpdateGUI() end
end

function Skyward:GetCacheStats()
    if not self.db or not self.db.cache then return 0, 0 end
    local total, skyborneCount = 0, 0
    for _, entry in pairs(self.db.cache) do
        if type(entry) == "table" then
            total = total + 1
            if entry.isSkyborne then
                skyborneCount = skyborneCount + 1
            end
        end
    end
    return total, skyborneCount
end
