# World of Warcraft: Forever - Research & Lore Context

This document compiles the currently known information regarding the upcoming **World of Warcraft: Forever** and the newly introduced **Skyborne** race, providing essential context for the development of the Skyward addon.

## Overview
**World of Warcraft: Forever** is a highly anticipated title from Blizzard Entertainment scheduled to launch on **November 4, 2026**. It serves as a "third pillar" in the franchise, coexisting alongside modern *World of Warcraft* (Retail) and *WoW: Classic*.

- **Theme & Concept:** It is an alternate-universe reimagining of the original 2004 setting. It updates graphics and introduces modern gameplay enhancements while staying true to the classic *Warcraft* design philosophy.
- **Beta Access:** The beta client is currently accessible for eligible players (those who pre-purchased the Skyborne Heroic Pack or Warcraft Forever Collection). The beta client path is typically located at:
  `C:\Program Files (x86)\World of Warcraft\_classic_beta_`

## The Skyborne Race
The Skyborne (often referred to as the *shen'dorei* or "hidden people") are a central feature of the new title.

- **Origins:** They are an evolutionary branch of the ancient Highborne who, unlike their arcane-focused brethren, were shaped by the elemental forces of air.
- **Starting Zone:** New Skyborne characters start their journey on **Zephras Isle**, a floating island zone scaled for levels 1–12.
- **Faction Allegiance:** Unlike traditional races locked to one faction, the Skyborne are a **neutral race**. Upon character creation or conclusion of the starting experience, they must choose to join either the **Alliance** or the **Horde**.
- **Available Classes:** 
  - *Both Factions:* Warrior, Hunter, Rogue, Druid.
  - *Alliance Exclusive:* Mage.
  - *Horde Exclusive:* Shaman.
- **Racial Abilities:**
  - *Walk on Air:* A specialized glide ability.
  - *Wind Blessed:* A passive or active haste buff.
  - *Elemental Insight:* Provides bonus damage against elemental enemies.
  - *Faction-Specific:* 'Read Leyline' (Alliance) and 'Skysight' (Horde).

## Technical Addon Implications
For addon developers, the introduction of a neutral race that eventually chooses a faction introduces specific challenges:
- **Faction Handling:** Standard APIs for checking faction will need to account for Skyborne characters who have not yet chosen a faction, or properly identify them once they have.
- **Name System:** The game introduces a "two-name system" (e.g., Firstname Lastname) which deviates from the classic `Name-Realm` format used in legacy clients.
- **Racial Emotes & Sounds:** The Skyborne possess unique aerial animations, glides, and vocal emotes (e.g., wind-themed spell effects and vocalizations) that are distinct from other races.
