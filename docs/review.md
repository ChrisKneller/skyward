# Architecture Review & Conflict Analysis

This document cross-references our `assumptions.md` against the real-world constraints discovered during research (`research_wow_forever.md`) for **World of Warcraft: Forever**.

## 1. Character Naming System (CRITICAL)
- **Assumption:** Classic `Firstname-Realm` string format.
- **Reality:** *WoW: Forever* introduces a **two-name system** (e.g., "Firstname Lastname" or "Firstname Surname"). 
- **Conflict:** `Database.lua` normalizes names by splitting at the hyphen (`-`). If players have spaces in their names (e.g., `Aeloria Windrider`), the whitelist logic and chat filter hooks `author` parameter checking will break.
- **Action Required:** Update `Database.lua:NormalizeName` to correctly parse strings with spaces, dropping realm identifiers if appended, or strictly caching based on GUID instead of display name.

## 2. Beta Client Path (CRITICAL)
- **Assumption:** Addon installation belongs in `_retail_/Interface/AddOns/`.
- **Reality:** The game is currently in beta. The client is housed at:
  `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`
- **Conflict:** The `README.md` and installation instructions mislead users.
- **Action Required:** Update installation documentation in `README.md` and `SPEC.md` to point to the `_classic_beta_` directory.

## 3. Interface Number
- **Assumption:** `## Interface: 110100` (Modern Retail).
- **Reality:** While built on an updated engine, if the beta path is `_classic_beta_`, it may use a Classic-era interface number (e.g., `11503` or a completely new `Forever` branch interface number).
- **Action Required:** Monitor the client to discover the actual Interface ID for *WoW: Forever*. Temporarily keep `110100` but note this as a high-risk failure point.

## 4. Skyborne Faction Neutrality
- **Assumption:** Standard two-faction logic applies.
- **Reality:** Skyborne are a neutral race that eventually chooses a faction. 
- **Conflict:** Addons often expect `UnitFactionGroup` to return "Horde" or "Alliance". If it returns "Neutral", third-party compatibility could break. 
- **Action Required:** Ensure `RaceDetector.lua` relies exclusively on `englishRace` or `localizedRace` string values rather than making assumptions based on faction affiliations.

## 5. Racial Emotes & Sounds
- **Assumption:** Skyborne emotes use standard emote IDs.
- **Reality:** Skyborne have unique glides and wind-themed vocalizations.
- **Action Required:** To fulfill the future roadmap (Muting Skyborne), we must datamine the specific `SoundKitID` arrays for these new racial traits.
