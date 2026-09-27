# Testing Skyward

Since World of Warcraft AddOns are written in Lua and rely heavily on the WoW API (which isn't available outside the game client), testing can be challenging.

## In-Game Testing
The primary method for testing Skyward is in-game using the built-in simulator:

1. Launch World of Warcraft: Forever.
2. Type `/skyward` to open the configuration panel.
3. Click the **Simulate Skyborne Chat** button to inject test messages into your chat window, testing the current filter mode (Off, Marked, or Hide).

## Out-of-Game Unit Testing
For out-of-game testing of pure logic (like name normalization and whitelist checking), we use a mocked Lua environment.

### Prerequisites
You need a standalone Lua interpreter installed on your system (e.g., Lua 5.1 or LuaJIT, matching the WoW environment).

### Running the Tests
Navigate to the root of the `skyward` project directory and execute the test script:

```bash
lua tests/test_skyward.lua
```

### Adding New Tests
To add more tests, edit the `tests/test_skyward.lua` file. 
You will need to mock any WoW API functions (like `GetPlayerInfoByGUID`, `CreateFrame`, etc.) that your tested code relies upon, within the test file before loading the source files.
