# Skyward: Project Specification & Architecture Roadmap

> **Addon Name:** Skyward  
> **Target Game:** World of Warcraft Forever  
> **Core Objective:** Provide players with comprehensive controls to filter, diminish, and avoid interactions with characters playing the new **Skyborne** race.  
> **Initial Release Version:** `1.0.0`

---

## 1. Executive Summary

With the introduction of the **Skyborne** race in *World of Warcraft Forever*, players encounter a distinct influx of new visual aesthetics, racial emotes, soaring flight animations, and public channel communication.

**Skyward** is an interface modification designed to give users granular agency over their gameplay experience. The addon provides tools to:
- Filter or diminish public chat messages from Skyborne characters.
- Maintain an explicit whitelist of friends, guildmates, or specific players exempt from filtering.
- Lay the architectural groundwork for auditory, visual, and group-finder shields in future releases.

---

## 2. Architecture & Design Principles

```
+-----------------------------------------------------------------------+
|                             User / Player                             |
+-----------------------------------------------------------------------+
               |                                           |
        /skyward (CLI)                            In-Game Control Panel
               |                                           |
               +-------------------+-----------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
|                             Core Engine                               |
|                     (Addon Lifecycle & Config)                        |
+-----------------------------------------------------------------------+
         |                                                 |
         v                                                 v
+--------------------------------+       +------------------------------+
|     Race Detection Engine      |       |      Whitelist Manager       |
| - GetPlayerInfoByGUID          |       | - Name / Realm normalization |
| - Unit scanner (Mouse/Target)  |       | - SavedVariables persistence |
| - Persistent DB Cache          |       | - Fast-path bypass           |
+--------------------------------+       +------------------------------+
         |                                                 |
         +-----------------------+-------------------------+
                                 |
                                 v
+-----------------------------------------------------------------------+
|                          Chat Filter Engine                           |
|       (CHAT_MSG_CHANNEL, CHAT_MSG_SAY, CHAT_MSG_YELL, EMOTES)         |
|                                                                       |
|   Modes:                                                              |
|   - OFF: Pass through untouched                                       |
|   - MARKED (Dimmed): Greys out text + [Skyborne] prefix badge         |
|   - HIDE (Blocked): Completely drops message from chat                |
+-----------------------------------------------------------------------+
```

### Key Engineering Tenets:
1. **Zero External Dependency Footprint**: Built entirely on standard WoW Lua APIs (no heavy Ace3 or LibSharedMedia requirements needed for core operation), maximizing performance and compatibility.
2. **Asynchronous Cache Resilience**: WoW's `GetPlayerInfoByGUID` can return `nil` if the character has not yet been streamed into local client memory. Skyward employs a passive multi-vector caching system (vicinity scanning, mouseover, target, nameplates, who queries) to build and maintain a persistent database of player races across sessions.
3. **Hyperlink Preservation**: When modifying chat messages for visual dimming, escape sequences (`|cff...|r`) must be carefully re-anchored so item links, achievements, and player names remain interactive and clickable.

---

## 3. Version 1.0.0 Feature Specification (MVP)

### 3.1. In-Game Configuration Panel (`GUI.lua`)
- **Invocation**: Triggered anytime a player runs `/skyward` (or `/sw`) without arguments.
- **Form Factor**: Standalone, draggable dialog frame with ESC-to-close behavior (`UISpecialFrames`) and modern `BackdropTemplate` styling.
- **Settings Category Hook**: Automatically registers a landing page in the game's native Settings menu (`Settings.RegisterAddOnCategory` / `InterfaceOptions_AddCategory`).
- **Interactive Controls**:
  - **Mode Selector**: Segmented toggles between `Off`, `Dimmed / Marked`, and `Hide (Block)`.
  - **Dimmed Visual Style Picker**: Allows choosing between `Greyed Out` (default), `Strikethrough` (`~~ msg ~~`), and `Tag Only`.
  - **Whitelist Manager**: Text input field with `Add Whitelist` button, enter-key submission, and scrollable table of whitelisted characters with inline `[Remove]` actions.
  - **Simulator**: `Simulate Skyborne Chat` button for immediate verification of active settings without needing a live Skyborne player.
  - **Cache Inspector**: Real-time counter of total characters detected vs. identified Skyborne players, plus a `Clear Cache` utility.

### 3.2. Public Chat Filter Engine (`ChatFilter.lua`)
- **Monitored Events**:
  - `CHAT_MSG_CHANNEL`: General, Trade, Services, LocalDefense, LookingForGroup.
  - `CHAT_MSG_SAY`: Local `/say` speech.
  - `CHAT_MSG_YELL`: Local `/yell` speech.
  - `CHAT_MSG_TEXT_EMOTE`: Custom and standard `/e` emotes.
- **Filter Modes**:
  1. **`OFF` (Default)**: Normal behavior. No messages are blocked or altered.
  2. **`MARKED` ("Dimmed")**:
     - Attaches a muted identifier tag: `|cff8b949e[Skyborne]|r `.
     - Applies muted grey styling (`|cff777b80`) to the message body.
     - Preserves item/quest hyperlinks without letting reset codes return the text to default channel colors.
     - Optional strikethrough variant: `~~ <message> ~~`.
  3. **`HIDE`**:
     - Returns `true` inside `ChatFrame_AddMessageEventFilter`, preventing the message from rendering in the chat window.

### 3.3. Whitelist Engine (`Database.lua`)
- **Persistence**: Stored in `SkywardDB.whitelist`.
- **Normalization**: Accepts either plain `CharacterName` or cross-realm `CharacterName-Realm`. Matches case-insensitively and handles both realm-qualified and realm-agnostic sender formats.
- **Priority**: Whitelist check executes before any race resolution. If whitelisted, the message is immediately passed through unmodified.
- **Slash Commands**:
  - `/skyward whitelist add <Name>`
  - `/skyward whitelist remove <Name>`
  - `/skyward whitelist list`

### 3.4. Race Detection Pipeline (`RaceDetector.lua`)
- **Primary Mechanism**: `GetPlayerInfoByGUID(guid)` resolving `englishRace` and `localizedRace`.
- **Passive Vicinity Harvesters**:
  - `UPDATE_MOUSEOVER_UNIT`: Inspects hovered players.
  - `PLAYER_TARGET_CHANGED`: Inspects current target.
  - `PLAYER_FOCUS_CHANGED`: Inspects focus target.
  - `NAME_PLATE_UNIT_ADDED`: Scans players entering nameplate render range.
  - `GROUP_ROSTER_UPDATE`: Scans party and raid members.
- **Persistent Cache**: Saves discovered race records to `SkywardDB.cache` indexed by GUID and normalized player name to avoid duplicate API requests.

---

## 4. Future Roadmap & Idea Specification

The following features represent conceptual expansions for future versions of Skyward:

### 4.1. Audio & Emote Suppressor (V1.1)
- **Goal**: Silence racial vocalizations, wing flaps, and soar sound effects.
- **Mechanism**:
  - Utilize WoW's `MuteSoundFile(soundFileID)` API to mute specific audio assets tied to Skyborne emotes (e.g. `/cheer`, `/laugh`, `/flirt`, `/roar`).
  - Intercept voice lines or sound triggers linked to racial abilities (such as glide/glide activation audio).
  - Add a toggle in `/skyward` under an "Audio Shields" tab.

### 4.2. Nameplate Culling & Dimming (V1.2)
- **Goal**: Minimize visual dominance of Skyborne players in high-traffic cities (e.g. Stormwind, Orgrimmar, Dornogal).
- **Mechanism**:
  - Hook `NamePlateDriverFrame` and `NAME_PLATE_UNIT_ADDED`.
  - For identified Skyborne units (non-hostile):
    - Reduce nameplate alpha (opacity) to 15%–30%.
    - Optionally scale down the nameplate size.
    - Replace or suppress the health bar / title text.
  - *Technical Note*: In modern WoW, nameplate modifications for friendly players inside dungeons/raids are restricted by Blizzard; however, in open-world cities and non-instanced zones, custom nameplate styling remains fully functional.

### 4.3. Group Finder / LFG Radar & Party Shields (V1.3)
- **Goal**: Warn players before joining Mythic+ dungeons or raid groups containing Skyborne members.
- **Mechanism**:
  - Hook `LFGListFrame` search results:
    - Query leader GUIDs if exposed, or scan party members upon group creation.
    - Add a warning badge `[Skyborne Leader]` on listing entries.
  - Party Invite Interceptor:
    - On `PARTY_INVITE_REQUEST`, inspect the inviter's GUID/race.
    - If Skyborne, display an alert dialog:
      `"Warning: Party invitation received from Skyborne player [Name]. Accept anyway?"`

### 4.4. Social Interaction Defense (V1.4)
- **Goal**: Prevent unwanted direct social interactions.
- **Features**:
  - **Duel Auto-Decline**: Automatically call `CancelDuel()` if `DUEL_REQUESTED` originates from a Skyborne player (with an optional chat notification).
  - **Trade Request Shield**: Prompt confirmation or auto-cancel trade windows initiated by Skyborne.
  - **Whisper Quarantine**: Separate Skyborne whispers into a dedicated tab or reply with an automated out-of-office response ("This player has Skyward enabled").

### 4.5. Tooltip & Unit Frame Indicators (V1.5)
- **Goal**: Instant situational awareness when mousing over or targeting players.
- **Mechanism**:
  - Hook `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)`.
  - When inspecting a player, if race is Skyborne:
    - Append a styled warning line: `|cffff4d4d[Skyward Warning: Skyborne Detected]|r`.
    - If whitelisted, append: `|cff52b788[Skyward: Whitelisted]|r`.

### 4.6. Crowd-Sourced Census Sync (V2.0)
- **Goal**: Pre-populate race data so uninspected players in trade chat are caught immediately even before their GUID is cached by the local client.
- **Mechanism**:
  - Provide an export/import string format (Base64 / serialized table) for guilds or community members to share observed player race registries.
  - External companion updater (similar to Details or Raider.IO client) that synchronizes realm census data into `SkywardDB.cache`.

---

## 5. Technical Constraints & Blizzard API Guidelines

| Component | Blizzard Constraint | Skyward Mitigation |
| :--- | :--- | :--- |
| **Protected Actions in Combat** | Addons cannot hide secure action buttons or protected unit frames during `InCombatLockdown()`. | Skyward's chat filters and non-secure UI frames are completely unaffected by combat lockdown. Any future nameplate modifications must respect combat state. |
| **GUID Race Cache Latency** | `GetPlayerInfoByGUID` returns `nil` if player metadata is not yet streamed. | Skyward uses a two-tier lookup: immediate API query + persistent fallback cache harvested from mouseovers, target events, and nameplates. |
| **Chat Hyperlink Breaking** | Injecting color codes can corrupt item, spell, or quest links (`|H...|h`). | The string replacement logic preserves all hyperlink headers and replaces only the terminator sequence `|r` with `|r|cff777b80`. |
| **Addon Communication** | Using public channels to broadcast addon data violates Blizzard ToS. | Skyward relies strictly on local client inspection, local event listeners, and optional manual import/export strings. |

---

## 6. Verification & Testing Protocol

1. **Syntax & Unit Sanity**:
   - Verify all Lua files parse with zero syntax errors.
   - Validate `.toc` interface numbers and load order dependencies.
2. **In-Game Validation**:
   - Run `/skyward` to verify the settings panel renders and responds to drag, click, and ESC key.
   - Run `/skyward test` across all three modes (`OFF`, `MARKED`, `HIDE`) to verify chat output.
   - Test adding and removing names from the whitelist via both GUI and slash command.
   - Verify whitelisted characters bypass the filter under `HIDE` and `MARKED` modes.
