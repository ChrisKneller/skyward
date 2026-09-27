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

    -- Ensure whitelist and cache sub-tables exist
    SkywardDB.whitelist = SkywardDB.whitelist or {}
    SkywardDB.cache = SkywardDB.cache or {}
    SkywardDB.filterChannels = SkywardDB.filterChannels or Skyward.DEFAULT_SETTINGS.filterChannels

    self.db = SkywardDB
end

-- Get current filter mode ("OFF", "MARKED", "HIDE")
function Skyward:GetMode()
    if not self.db then return Skyward.MODES.OFF end
    return self.db.mode or Skyward.MODES.OFF
end

-- Set filter mode
function Skyward:SetMode(newMode)
    if not self.db then return end
    if newMode == Skyward.MODES.OFF or newMode == Skyward.MODES.MARKED or newMode == Skyward.MODES.HIDE then
        self.db.mode = newMode
        self:Print(("Public chat filter mode set to: |cffffd100%s|r"):format(newMode))
        if self.UpdateGUI then
            self:UpdateGUI()
        end
    end
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
    if self.db.whitelist[norm] then
        return false, ("'%s' is already in the whitelist."):format(characterName)
    end

    self.db.whitelist[norm] = {
        name = characterName,
        addedAt = time(),
    }

    self:Print(("Added |cff52b788%s|r to the whitelist."):format(characterName))
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
