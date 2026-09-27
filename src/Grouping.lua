--[[
    Skyward: Grouping & LFG Interaction Shield
    Addon for World of Warcraft Forever
    Handles Premade Group / LFG List badges, search filtering, and party invite warnings.
]]

local ADDON_NAME, Skyward = ...

local Grouping = {}
Skyward.Grouping = Grouping

-- StaticPopup Dialogs for Grouping Warnings
StaticPopupDialogs["SKYWARD_CONFIRM_LFG_APPLY"] = {
    text = "|cff00b4d8[Skyward Warning]|r\n\nThe leader of this group (|cffffd100%s|r) has been identified as |cff00b4d8Skyborne|r.\n\nDo you still wish to apply?",
    button1 = "Apply Anyway",
    button2 = "Cancel",
    OnAccept = function(dialog, data)
        if data and data.originalFunc then
            data.originalFunc(unpack(data.args or {}))
        elseif C_LFGList and C_LFGList.ApplyToGroup and data and data.resultID then
            C_LFGList.ApplyToGroup(data.resultID, data.comment or "", data.roles or {})
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SKYWARD_CONFIRM_PARTY_INVITE"] = {
    text = "|cff00b4d8[Skyward Warning]|r\n\n|cffffd100%s|r (|cff00b4d8Skyborne|r) has invited you to join a group.\n\nDo you wish to accept?",
    button1 = "Accept",
    button2 = "Decline",
    OnAccept = function()
        AcceptGroup()
    end,
    OnCancel = function()
        DeclineGroup()
    end,
    timeout = 60,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Check if an LFG search entry leader is Skyborne
function Grouping:IsLeaderSkyborne(searchResultID)
    if not searchResultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then
        return false, nil
    end

    local info = C_LFGList.GetSearchResultInfo(searchResultID)
    if not info or not info.leaderName or info.leaderName == "" then
        return false, nil
    end

    local leader = info.leaderName
    if Skyward:IsWhitelisted(leader) then
        return false, leader
    end

    local isSkyborne = Skyward:IsPlayerSkyborne(leader)
    return isSkyborne, leader, info
end

-- Process Premade Group Search Entry updates
function Grouping:OnSearchEntryUpdate(entry)
    if not entry or not entry.resultID then return end

    local mode = Skyward:GetGroupingMode()
    if mode == Skyward.GROUPING_MODES.OFF then
        return
    end

    local isSkyborne, leader, info = self:IsLeaderSkyborne(entry.resultID)
    if not isSkyborne then return end

    if mode == Skyward.GROUPING_MODES.HIDE then
        -- Hide the search entry completely from the list
        entry:Hide()
        entry:SetAlpha(0)
    elseif mode == Skyward.GROUPING_MODES.WARN then
        entry:Show()
        entry:SetAlpha(1.0)

        if Skyward:IsGroupingLfgBadgeEnabled() and entry.Name and entry.Name.GetText then
            local currentText = entry.Name:GetText() or (info and info.name) or ""
            if not currentText:find("%[Skyborne%]") then
                entry.Name:SetText("|cff00b4d8[Skyborne]|r " .. currentText)
            end
        end
    end
end

-- Hook Premade Groups search results
local function HookLFGList()
    if LFGListSearchEntry_Update then
        hooksecurefunc("LFGListSearchEntry_Update", function(entry)
            Grouping:OnSearchEntryUpdate(entry)
        end)
    end

    -- Hook Sign-Up button to warn if leader is Skyborne
    if LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.SignUpButton then
        local signUpBtn = LFGListFrame.SearchPanel.SignUpButton
        local origOnClick = signUpBtn:GetScript("OnClick")

        signUpBtn:SetScript("OnClick", function(self, ...)
            local mode = Skyward:GetGroupingMode()
            local confirmEnabled = Skyward:IsGroupingConfirmInviteEnabled()

            if mode == Skyward.GROUPING_MODES.WARN and confirmEnabled then
                local selectedResult = LFGListFrame.SearchPanel.selectedResult
                if selectedResult then
                    local isSkyborne, leader = Grouping:IsLeaderSkyborne(selectedResult)
                    if isSkyborne and leader then
                        local dialog = StaticPopup_Show("SKYWARD_CONFIRM_LFG_APPLY", leader)
                        if dialog then
                            dialog.data = {
                                resultID = selectedResult,
                                originalFunc = origOnClick,
                                args = { self, ... },
                            }
                        end
                        return
                    end
                end
            end

            if origOnClick then
                origOnClick(self, ...)
            end
        end)
    end
end

-- Hook Classic LFGBrowseFrame if present
local function HookClassicLFGBrowse()
    if LFGBrowse_UpdateList then
        hooksecurefunc("LFGBrowse_UpdateList", function()
            local mode = Skyward:GetGroupingMode()
            if mode == Skyward.GROUPING_MODES.OFF then return end

            local numEntries = NUM_LFG_LIST_ENTRIES or 14
            for i = 1, numEntries do
                local entry = _G["LFGBrowseFrameEntry" .. i]
                if entry and entry:IsShown() and entry.Name then
                    local leaderName = entry.Name:GetText()
                    if leaderName and leaderName ~= "" and not Skyward:IsWhitelisted(leaderName) then
                        if Skyward:IsPlayerSkyborne(leaderName) then
                            if mode == Skyward.GROUPING_MODES.HIDE then
                                entry:Hide()
                            elseif mode == Skyward.GROUPING_MODES.WARN and Skyward:IsGroupingLfgBadgeEnabled() then
                                local txt = entry.Name:GetText() or ""
                                if not txt:find("%[Skyborne%]") then
                                    entry.Name:SetText("|cff00b4d8[Skyborne]|r " .. txt)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- Initialize Grouping Module & Event Listeners
function Grouping:Init()
    HookLFGList()
    HookClassicLFGBrowse()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PARTY_INVITE_REQUEST")

    eventFrame:SetScript("OnEvent", function(self, event, inviterName, isTank, isHealer, isDamage, isCrossRealm, outOfRealm, inviterGUID)
        if event == "PARTY_INVITE_REQUEST" then
            if not inviterName or inviterName == "" then return end
            if Skyward:IsWhitelisted(inviterName) then return end

            local mode = Skyward:GetGroupingMode()
            if mode == Skyward.GROUPING_MODES.OFF then return end

            local isSkyborne = Skyward:IsPlayerSkyborne(inviterName, inviterGUID)
            if not isSkyborne then return end

            if mode == Skyward.GROUPING_MODES.HIDE then
                -- Automatically decline invite and suppress popup
                DeclineGroup()
                if StaticPopup_Hide then
                    StaticPopup_Hide("PARTY_INVITE")
                    StaticPopup_Hide("PARTY_INVITE_XREALM")
                end
                Skyward:Print(("|cffff4d4d[BLOCKED]|r Party invite from Skyborne player |cffffd100%s|r was automatically declined."):format(inviterName))
            elseif mode == Skyward.GROUPING_MODES.WARN and Skyward:IsGroupingConfirmInviteEnabled() then
                -- Hide default invite popup and display our clear warning prompt
                if StaticPopup_Hide then
                    StaticPopup_Hide("PARTY_INVITE")
                    StaticPopup_Hide("PARTY_INVITE_XREALM")
                end
                StaticPopup_Show("SKYWARD_CONFIRM_PARTY_INVITE", inviterName)
                Skyward:Print(("|cff00b4d8[Skyward Alert]|r Group invite received from Skyborne player |cffffd100%s|r."):format(inviterName))
            end
        end
    end)
end

-- Simulation for Testing Grouping Warnings In-Game
function Skyward:SimulateLfgWarning()
    local mode = self:GetGroupingMode()
    self:Print(("Simulating Grouping & LFG filter under mode: |cffffd100%s|r"):format(mode))

    local skyborneLeader = "Aeloria Skyward"
    self:SetPlayerRaceCache("Player-Sim-001", skyborneLeader, "Skyborne", true)

    if mode == Skyward.GROUPING_MODES.HIDE then
        self:Print("|cffff4d4d[BLOCKED]|r Group listing for 'Mythic Zephras Isle' led by Skyborne player " .. skyborneLeader .. " was hidden.")
        self:Print("|cffff4d4d[BLOCKED]|r Direct party invite from " .. skyborneLeader .. " was automatically declined.")
    elseif mode == Skyward.GROUPING_MODES.WARN then
        self:Print("|cff00b4d8[LFG Preview]|r |cff00b4d8[Skyborne]|r Mythic Zephras Isle (+10) - Leader: " .. skyborneLeader)
        if self:IsGroupingConfirmInviteEnabled() then
            StaticPopup_Show("SKYWARD_CONFIRM_PARTY_INVITE", skyborneLeader)
        end
    else
        self:Print("|cff808080[Normal]|r Mythic Zephras Isle (+10) - Leader: " .. skyborneLeader .. " (Grouping filter is currently Off)")
    end
end
