# Skyward

**Skyward** is an addon for *World of Warcraft Forever* designed to mitigate and filter interactions with the newly introduced **Skyborne** race.

---

## Features (v1.0.0)

- **In-Game Control Panel (`/skyward`)**:
  - Movable, standalone configuration frame.
  - Quick-switch toggle buttons for public chat filtering.
  - Whitelist management interface to exempt specific characters.
  - Built-in simulation tool to preview filter modes.
  - Cache inspector displaying detected characters.
- **Public Chat Filter Engine**:
  - Supports General, Trade, Services, Say, Yell, and Emote channels.
  - **Three Filter Modes**:
    - **Off (Default)**: Normal chat behavior; messages pass through unmodified.
    - **Dimmed / Marked**: Greys out Skyborne messages and attaches a muted `[Skyborne]` tag (supports strikethrough or greyed-out styles).
    - **Hide (Blocked)**: Completely drops messages sent by Skyborne characters from chat.
- **Whitelist System**:
  - Add character names (e.g. `Character` or `Character-Realm`) to protect friends and guildmates.
  - Whitelisted characters bypass filtering in all modes.
- **Race Detection & GUID Cache**:
  - Automatically queries character race via GUIDs (`GetPlayerInfoByGUID`).
  - Passively harvests race data from mouseovers, targets, nameplates, and group rosters.
  - Stores discovered races persistently in `SkywardDB` to maintain speed and reduce API lag.

---

## Installation

1. Copy the `skyward` folder into your WoW client's AddOns directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/Skyward
   ```
2. Start the game and make sure **Skyward** is enabled in the AddOn list on your character selection screen.

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/skyward` or `/sw` | Open/close the Skyward configuration panel |
| `/skyward off` | Disable chat filtering (normal mode) |
| `/skyward marked` | Enable dimmed / greyed-out mode for Skyborne messages |
| `/skyward hide` | Enable hide / blocked mode for Skyborne messages |
| `/skyward whitelist add <Name>` | Add a character to the whitelist |
| `/skyward whitelist remove <Name>` | Remove a character from the whitelist |
| `/skyward whitelist list` | List all whitelisted characters in chat |
| `/skyward test` | Run a chat filter simulation in your chat frame |
| `/skyward help` | Display available commands |

---

## Project Structure

```
skyward/
├── Skyward.toc          # Addon manifest and load order
├── Constants.lua        # Color palettes, default settings, race tokens
├── Database.lua         # SavedVariables, whitelist logic, cache manager
├── RaceDetector.lua     # GUID lookups, event-based race scanner
├── ChatFilter.lua       # ChatFrame message event filters & formatters
├── GUI.lua              # Standalone options panel & UI components
├── Core.lua             # Addon lifecycle, slash commands, simulation
├── SPEC.md              # Detailed architecture spec & future roadmap
└── README.md            # User manual and documentation
```

For the complete architectural design and roadmap for future versions (audio muting, nameplate culling, LFG radar, duel defense), see [SPEC.md](SPEC.md).
