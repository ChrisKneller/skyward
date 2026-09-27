# Initial Assumptions Log

During the initial scaffold and development of **Skyward**, several technical and design assumptions were made regarding how the new client (*World of Warcraft: Forever*) operates under the hood.

1. **Character Naming Format:**
   - **Assumption:** Assumed the standard modern/classic WoW string format of `Firstname-Realmname` (e.g., `Aeloria-Stormrage`) or just `Firstname` for local players.
   - **Impact:** The `Database.lua` normalization and whitelist functions strip spaces and try to match the prefix before the dash.

2. **Race API Output:**
   - **Assumption:** Assumed `GetPlayerInfoByGUID` and `UnitRace` return a single string token, such as `"Skyborne"` or `"skyborne"`.
   - **Impact:** `RaceDetector.lua` caches and checks against a hardcoded lookup table (`Skyward.TARGET_RACES`) for "skyborne", "the skyborne", and "skyborn".

3. **Client Interface Version:**
   - **Assumption:** Assumed the TOC interface number `110100` (Modern WoW / 11.x Retail style API) is applicable, given the game uses an updated engine.
   - **Impact:** `Skyward.toc` declares `## Interface: 110100`, which might be incorrect if *WoW: Forever* uses a specific `_classic_beta_` or bespoke interface numbering system.

4. **Addon Directory Path:**
   - **Assumption:** Assumed the standard `_retail_/Interface/AddOns/` path structure for installation.
   - **Impact:** The `README.md` instructs users to install into `_retail_`.

5. **Settings UI API:**
   - **Assumption:** Assumed the modern `Settings.RegisterAddOnCategory` or `Settings.RegisterCanvasLayoutCategory` are available for adding the UI to the main game options menu.
   - **Impact:** `Core.lua` uses a fallback to `InterfaceOptions_AddCategory`, but if the UI backend is entirely rewritten, this could throw a Lua error.

6. **Chat Filter API (`ChatFrame_AddMessageEventFilter`):**
   - **Assumption:** Assumed the traditional 17-argument payload for chat event filters, with `guid` being the 12th argument.
   - **Impact:** `ChatFilter.lua` expects parameter 12 to be the sender's GUID. If *WoW: Forever* shifts this index (e.g., to support the two-name system), race detection will fail.
