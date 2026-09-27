# Skyward

**Skyward** is an addon for *World of Warcraft Forever* (Classic Beta client) designed to filter, style, and shield against interactions with the newly introduced **Skyborne** race.

Current Release: **v0.2.0 (Beta Testing Release)**

---

## Features

- **In-Game Configuration Panel (`/skyward`)**:
  - Standalone, movable dark-themed UI window with 3 organised main tabs:
    - **Chat**: Comprehensive chat filtering controls organised into 3 clean sub-tabs:
      - **Filter Mode**: High-level chat mode selection (Off, Warn, Hide/Block) with clear mode descriptions.
      - **Channels**: Granular per-channel filter toggles (General, Trade, Services, LookingForGroup, LocalDefense, Say, Yell, Emotes, Custom).
      - **Styling**: Customisable prefix tags (e.g., `[Skyborne]`) and character name colour replacement with live in-game preview.
    - **Grouping**: LFG / Premade Group Finder and party interaction shield:
      - **Mode Selection**: Off, Warn, or Hide/Block for group finder search listings and invitations.
      - **LFG Badges**: Prominent `[Skyborne]` tag and listing highlights when group leaders are Skyborne.
      - **Party & Invite Alerts**: Warning confirmation popups before applying to Skyborne groups or accepting party invites from Skyborne players.
      - **Auto-Decline in Hide Mode**: Automatically declines party invitations from Skyborne players and suppresses listings from search results.
    - **Whitelist**: Global, case-insensitive character exemption manager with dedicated search/add and scrollable roster (exempts players across both Chat and Grouping).
- **Dynamic "Channel" Colour Matching**:
  - Allows replacing the Skyborne player's class colour with the exact font colour configured in your WoW Chat Settings for that channel (e.g. Trade pink/peach).
- **Public Chat Filter Engine**:
  - **Off (Normal)**: Skyward is idle; all messages appear unmodified.
  - **Warn**: Messages from Skyborne players are marked with custom prefix tags and/or character name recolouring while preserving normal chat readability.
  - **Hide (Block)**: Completely suppresses public chat messages sent by Skyborne players.
- **Race Detection & GUID Cache**:
  - Automatically identifies character race via GUIDs (`GetPlayerInfoByGUID`).
  - Passively harvests race data from mouseovers, targets, nameplates, and group rosters.
  - Persistently caches discovered players in `SkywardDB` to maintain instant performance and zero chat lag.

---

## Manual Installation (Without an AddOn Manager)

If you are not using an AddOn manager like CurseForge or WowUp, follow these steps to install Skyward manually:

1. **Download the AddOn**:
   - Go to the [Releases](https://github.com/ChrisKneller/skyward/releases) page on GitHub.
   - Download the latest `Skyward-v0.1.1.zip` release file.

2. **Locate your World of Warcraft AddOns Folder**:
   - **WoW Forever / Classic Beta**:
     ```text
     C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\
     ```
   - **Classic Era / Classic**:
     ```text
     C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\
     ```
   - **Retail**:
     ```text
     C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\
     ```

3. **Extract the ZIP**:
   - Extract the contents of `Skyward-v0.1.1.zip` directly into your `Interface\AddOns\` directory.
   - **Important**: Make sure the final folder structure is:
     ```text
     Interface\AddOns\Skyward\Skyward.toc
     Interface\AddOns\Skyward\src\...
     ```
     *(Avoid duplicate nested folders like `Interface\AddOns\Skyward\Skyward\...`)*

4. **Verify In-Game**:
   - Launch World of Warcraft.
   - On the Character Selection screen, click the **AddOns** button in the bottom-left corner.
   - Ensure **Skyward** is checked. (If your client version differs, check **"Load out of date AddOns"**).
   - Once logged in, type `/skyward` to open settings!

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/skyward` | Open or close the Skyward configuration panel |
| `/skyward <off\|warn\|hide>` | Switch chat filter mode |
| `/skyward grouping <off\|warn\|hide>` | Switch LFG / grouping filter mode |
| `/skyward whitelist add <Name>` | Add a character to the whitelist |
| `/skyward whitelist remove <Name>` | Remove a character from the whitelist |
| `/skyward whitelist list` | View all whitelisted characters in chat |
| `/skyward test` | Run an in-game chat simulation to test your settings |
| `/skyward test lfg` | Run an in-game LFG and party invite warning simulation |
| `/skyward help` | Display available chat commands |

---

## Project Structure

```text
skyward/
├── Skyward.toc              # Addon manifest and load order
├── src/
│   ├── Constants.lua        # Colour palettes, default settings, race tokens
│   ├── Database.lua         # SavedVariables, whitelist logic, cache manager
│   ├── RaceDetector.lua     # GUID lookups, event-based race scanner
│   ├── ChatFilter.lua       # ChatFrame message event filters & formatters
│   ├── Grouping.lua         # LFG / Premade Group radar and party invite shield
│   ├── GUI.lua              # Standalone options panel & UI components
│   └── Core.lua             # Addon lifecycle, slash commands, simulation
├── docs/
│   ├── SPEC.md              # Detailed architecture spec & future roadmap
│   ├── research_wow_forever.md # WoW Forever lore & mechanics research
│   ├── assumptions.md       # Technical assumptions during initial build
│   ├── review.md            # Contrast of assumptions vs reality
│   └── testing.md           # Instructions for running tests
├── tests/
│   └── test_skyward.lua     # Out-of-game test suite
└── README.md                # User manual and documentation
```

---

## License & Contributing

Copyright © 2026 Christian Kneller. All rights reserved. See [LICENSE](LICENSE) for details.

Issues, bug reports, and contributions are welcome via [GitHub Issues and Pull Requests](https://github.com/ChrisKneller/skyward).
