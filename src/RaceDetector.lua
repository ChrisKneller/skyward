--[[
    Skyward: Race Detection Engine
    Identifies if a character belongs to the Skyborne race through GUID queries,
    unit inspection, nameplates, who queries, and persistent caching.
]]

local ADDON_NAME, Skyward = ...

-- Check if a race name or token matches Skyborne
function Skyward:IsSkyborneRaceName(race)
    if not race or type(race) ~= "string" then return false end
    local clean = race:lower():gsub("%s+", "")
    if Skyward.TARGET_RACES[clean] then return true end
    if clean:find("skyborne") or clean:find("skyborn") then return true end
    return false
end

-- Inspect a unitID ("target", "mouseover", "party1", "nameplate1", etc.)
function Skyward:InspectUnit(unitID)
    if not UnitExists(unitID) or not UnitIsPlayer(unitID) then return end

    local guid = UnitGUID(unitID)
    local name, realm = UnitName(unitID)
    if realm and realm ~= "" then
        name = name .. "-" .. realm
    end

    local localizedRace, englishRace = UnitRace(unitID)
    local isSkyborne = self:IsSkyborneRaceName(englishRace) or self:IsSkyborneRaceName(localizedRace)

    self:SetPlayerRaceCache(guid, name, englishRace or localizedRace, isSkyborne)
    return isSkyborne
end

-- Resolve race by GUID
function Skyward:QueryRaceByGUID(guid, nameFallback)
    if not guid or guid == "" then return nil end

    -- Check persistent cache first
    local cached = self:GetPlayerRaceCache(guid, nameFallback)
    if cached then
        return cached.isSkyborne, cached.race
    end

    -- Query WoW API: GetPlayerInfoByGUID
    -- Returns: locClass, engClass, locRace, engRace, sex, name, realm
    local _, _, locRace, engRace = GetPlayerInfoByGUID(guid)
    if engRace or locRace then
        local isSkyborne = self:IsSkyborneRaceName(engRace) or self:IsSkyborneRaceName(locRace)
        self:SetPlayerRaceCache(guid, nameFallback, engRace or locRace, isSkyborne)
        return isSkyborne, engRace or locRace
    end

    -- Modern C_PlayerInfo fallback if available
    if C_PlayerInfo and C_PlayerInfo.GetPlayerInfoByGUID then
        local pInfo = C_PlayerInfo.GetPlayerInfoByGUID(guid)
        if pInfo and (pInfo.raceName or pInfo.raceFilename) then
            local isSkyborne = self:IsSkyborneRaceName(pInfo.raceFilename) or self:IsSkyborneRaceName(pInfo.raceName)
            self:SetPlayerRaceCache(guid, nameFallback, pInfo.raceFilename or pInfo.raceName, isSkyborne)
            return isSkyborne, pInfo.raceFilename or pInfo.raceName
        end
    end

    return nil, nil
end

-- Check if an author is Skyborne (using both GUID and character name)
function Skyward:IsAuthorSkyborne(guid, authorName)
    -- Whitelist check always takes precedence!
    if self:IsWhitelisted(authorName) then
        return false, "Whitelisted"
    end

    -- 1. Try GUID resolution
    if guid and guid ~= "" then
        local isSkyborne, race = self:QueryRaceByGUID(guid, authorName)
        if isSkyborne ~= nil then
            return isSkyborne, race
        end
    end

    -- 2. Try Name cache fallback
    if authorName and authorName ~= "" then
        local cached = self:GetPlayerRaceCache(nil, authorName)
        if cached then
            return cached.isSkyborne, cached.race
        end
    end

    return false, "Unknown"
end

-- Event listener to harvest player race data passively
function Skyward:InitRaceDetector()
    local scanner = CreateFrame("Frame")
    scanner:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    scanner:RegisterEvent("PLAYER_TARGET_CHANGED")
    scanner:RegisterEvent("PLAYER_FOCUS_CHANGED")
    scanner:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    scanner:RegisterEvent("GROUP_ROSTER_UPDATE")

    scanner:SetScript("OnEvent", function(_, event, unit)
        if event == "UPDATE_MOUSEOVER_UNIT" then
            Skyward:InspectUnit("mouseover")
        elseif event == "PLAYER_TARGET_CHANGED" then
            Skyward:InspectUnit("target")
        elseif event == "PLAYER_FOCUS_CHANGED" then
            Skyward:InspectUnit("focus")
        elseif event == "NAME_PLATE_UNIT_ADDED" and unit then
            Skyward:InspectUnit(unit)
        elseif event == "GROUP_ROSTER_UPDATE" then
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    Skyward:InspectUnit("raid" .. i)
                end
            elseif IsInGroup() then
                for i = 1, GetNumGroupMembers() do
                    Skyward:InspectUnit("party" .. i)
                end
            end
        end
    end)
end
