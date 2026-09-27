-- Mock WoW environment globals and APIs
_G = _G or {}
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
time = os.time
SkywardDB = {}

-- Create a mock add-on namespace
local ADDON_NAME = "Skyward"
local Skyward = {
    DEFAULT_SETTINGS = {
        mode = "OFF",
        whitelist = {},
        cache = {}
    }
}

-- Load Database.lua (simulating the WoW loading process)
-- We use loadfile to execute the file within this environment
local dbFile = assert(loadfile("src/Database.lua"))
dbFile(ADDON_NAME, Skyward)

print("Running Skyward Tests...\n")

-- Test: NormalizeName
local function TestNormalizeName()
    local tests = {
        { input = "Aeloria", expected = "aeloria" },
        { input = "Aeloria-Stormrage", expected = "aeloria-stormrage" },
        { input = "  Aeloria  ", expected = "aeloria" },
        { input = "Aeloria Windrider", expected = "aeloria windrider" },
        { input = "Aeloria    Windrider-Stormrage", expected = "aeloria windrider-stormrage" }
    }

    local passed = 0
    for _, t in ipairs(tests) do
        local result = Skyward:NormalizeName(t.input)
        if result == t.expected then
            passed = passed + 1
        else
            print(string.format("[FAIL] NormalizeName: expected '%s', got '%s'", t.expected, result))
        end
    end
    print(string.format("NormalizeName: %d/%d passed.", passed, #tests))
end

-- Test: IsWhitelisted (Two-Name System)
local function TestIsWhitelisted()
    -- Reset DB
    SkywardDB = { whitelist = {} }
    Skyward.db = SkywardDB

    -- Whitelist a player's first name
    Skyward:AddWhitelist("Aeloria")
    -- Whitelist another player's full two-name format
    Skyward:AddWhitelist("Zephyr Windrunner")

    local tests = {
        -- Given author "Aeloria", should pass because "aeloria" is whitelisted
        { input = "Aeloria", expected = true },
        -- Given author "Aeloria Windrider-Stormrage", should FAIL because "aeloria" is whitelisted, not the full name!
        { input = "Aeloria Windrider-Stormrage", expected = false },
        -- Given author "Zephyr Windrunner", should pass because full name is whitelisted
        { input = "Zephyr Windrunner", expected = true },
        -- Given author "Zephyr Windrunner-Area52", should pass because full name matches up to realm
        { input = "Zephyr Windrunner-Area52", expected = true },
        -- Given author "Zephyr", should NOT pass because "zephyr windrunner" is whitelisted, and Zephyr is only part of it
        { input = "Zephyr", expected = false },
        -- Given author "Zephyr Storm", should fail because it doesn't match the whitelisted name
        { input = "Zephyr Storm", expected = false },
        -- Given author "Unknown", should fail
        { input = "Unknown", expected = false }
    }

    local passed = 0
    for _, t in ipairs(tests) do
        local result = Skyward:IsWhitelisted(t.input)
        if result == t.expected then
            passed = passed + 1
        else
            print(string.format("[FAIL] IsWhitelisted: input '%s', expected %s, got %s", t.input, tostring(t.expected), tostring(result)))
        end
    end
    print(string.format("IsWhitelisted: %d/%d passed.", passed, #tests))
end

-- Run tests
TestNormalizeName()
TestIsWhitelisted()

print("\nTests completed.")
