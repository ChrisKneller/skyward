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
        { input = "Aeloria Windrider", expected = "aeloria windrider" } -- WoW Forever two-name format
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

-- Run tests
TestNormalizeName()

print("\nTests completed.")
