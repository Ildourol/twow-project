# FORUM_RESOURCE_GUIDE.md: Turtle-WoW Official Forum Archive & Intelligence Guide

This guide details the structure, contents, research methodologies, and porting integration protocols for the official **Turtle-WoW Forum Archive** located in [`resources/forum/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum).

---

## 1. Overview of the Forum Archive

The forum archive contains **22,155 historical threads** spanning September 2018 through May 2026. It documents the entire eight-year lifecycle of Turtle-WoW (1.12.1 through 1.18.1), capturing:

1. **Official Major Patch Releases**: Design documents, feature specifications, class reworks, new zones, dungeons, raids, and systems from Patch 1.12.1+ through Patch 1.18.1.
2. **Developer Hotfixes & Changelogs**: Over 300 periodic maintenance updates authored by the core development team (`Torta`, `Pompa`, `Junkernaut`), detailing precise code, script, and database corrections.
3. **Player Bug Reports & Staff Responses**: Thousands of empirical bug reports covering spell anomalies, quest breaks, pathfinding glitches, combat calculation discrepancies, and client crashes.
4. **Class & Combat Mechanics Specifications**: Detailed discussions explaining *why* certain vanilla mechanics were intentionally modified (e.g. Paladin Holy Strike, Druid form itemization, Shaman tanking, racials, diminishing returns).
5. **Itemization & Stat Squish Ledgers**: Authoritative itemization changelogs documenting custom gear, tier set bonuses, stat rebalances, and profession recipes.

### Archive Statistics

| Metric | Count / Detail |
| :--- | :--- |
| **Total Forum Threads** | **22,155 files** |
| **Date Range** | September 5, 2018 – May 12, 2026 |
| **Official Patch Threads** | 270+ threads |
| **Official Maintenance Changelogs** | 310+ date-stamped developer updates |
| **Quest Bug / Script Threads** | 1,254 threads |
| **Combat & PvP Mechanics Threads** | 942 threads |
| **Spell & Aura Interaction Threads** | 225+ direct mechanic threads |
| **Client Crash & Error 132 Threads** | 303 threads |
| **File Format** | Plain text (`.txt`), normalized with metadata header (`Posted:`, `Thread:`, `by:`) |

---

## 2. Why the Forum Archive is Vital for Porting

When porting fixes from **VMaNGOS** (`twow project/core`) to **Tortoise-WoW** (`twow project/tortoise-wow`), engineers and AI agents face a critical risk: **accidental regression of intentional Turtle-WoW custom mechanics**.

VMaNGOS is a strict vanilla 1.12.1 emulator targeting absolute Blizzard retail parity. However, Tortoise-WoW targets **Turtle-WoW 1.18.1 (Build 7272)**, which contains hundreds of intentional gameplay adjustments, class reworks, and custom systems.

### The Divergence Dilemma: Bug vs. Design
Before porting any upstream VMaNGOS commit, agents must ask:
> *"Is this vanilla bug also a bug in Turtle-WoW, or was this behavior intentionally changed or already fixed by the Turtle-WoW dev team?"*

The forum archive provides the definitive answer. By querying the archive, agents can:
- **Verify Intentional Divergences**: Confirm whether a formula (e.g. Moonfury, Curse of Agony, parry haste) was customized on Turtle-WoW.
- **Identify Historical Turtle Fixes**: Check how the Turtle-WoW team originally solved a known issue (often documented in weekly changelogs).
- **Avoid Breaking Custom Quests/Spells**: Ensure vanilla database or script cleanups do not destroy custom Turtle entries.
- **Recover Missing Specifications**: Extract exact damage coefficients, cooldowns, or proc chances for custom spells and items.

---

## 3. Key Milestone Patches in the Archive

Below is a roadmap of the major patch documents available in [`resources/forum/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum):

### Era 1: The Vanilla+ Foundation (2018 – 2020)
- **`2018-10-15-13-47-16_Changelog First Week!.txt`**: First official post-launch fixes (creature waypoint reverse system, FFA attacks, logout disconnects, transport ships).
- **`2018-12-14-17-42-40_Patch 1.12.1+ - Rogue's Disguise.txt`**: Implementation of Rogue disguise ability and stealth mechanics.
- **`2019-01-05-22-43-19_Patch 1.12.1+ - Khadgar's Unlocking.txt`**: Custom lockpicking and key mechanics.
- **`2019-04-07-22-43-49_Patch 1.12.1+ - Barbershop.txt`**: Custom appearance alteration system.
- **`2019-05-06-00-37-57_Patch 1.12.1+ - Survival Skill.txt`**: Introduction of the custom Survival secondary profession (campfires, tents, rest XP).
- **`2019-05-27-20-33-00_Patch 1.12.1+ - Tauren Plainsrunning.txt`**: Implementation of Plainsrunning mechanics for Tauren.
- **`2019-12-22-00-03-09_Patch 1.12.1+ - Glyphs.txt`**: Early custom glyph system.
- **`2020-01-17-16-47-50_Patch 1.12.1+ - Holy Strike.txt`**: Paladin custom Holy Strike spell specification and ranks.
- **`2020-05-07-04-09-45_Patch 1.12.1+ - Gardening.txt`**: Secondary profession for herb planting and harvest nodes.

### Era 2: Expansion of Azeroth (2020 – 2022)
- **`2020-10-04-10-46-23_Patch 1.15.0 - Goblins & High Elves.txt`**: Foundation of the **10-race system** (`MAX_RACES = 11`), custom starting zones (Alah'Thalas, Gilneas), racial traits, and racials.
- **`2021-05-10-06-51-35_Patch 1.12.1+ - Chronoboon Displacer, Mage Table, and Warlock Soulwell.txt`**: World buff preservation and raid convenience spells.
- **`2021-11-22-12-16-13_Patch 1.16.0 - Mysteries of Azeroth.txt`**: Massive world expansion (Gillijim's Isle, Lapidis Isle, Tel'Abim, Hyjal, new dungeons).
- **`2021-11-06-16-57-46_Final Changelog for Class Changes coming in 1.16.1.txt`**: Comprehensive class rebalancing specifications for all 9 classes.
- **`2022-07-24-18-52-27_Patch 1.16.1 - Hateforge Quarry.txt`**: Hateforge Quarry 5-man dungeon, loot tables, and boss scripts.
- **`2022-09-30-19-13-36_Patch 1.16.4 - Anchor's Fall.txt`**: Maritime content and custom quest hubs.

### Era 3: Beyond the Greymane Wall & Karazhan (2023 – 2024)
- **`2023-01-21-22-37-23_Patch 1.17.0 - Beyond the Greymane Wall.txt`**: Opening of Gilneas zone, Zul'Gurub scaling, class adjustments.
- **`2023-07-10-14-32-05_1.17.0 Itemization Changelog.txt`**: Authoritative stat adjustments across pre-raid and raid tiers.
- **`2023-10-15-20-05-30_Patch 1.17.1 - Labor and Legacy.txt`**: Gathering and crafting reworks, economy updates.
- **`2023-12-01-18-25-44_1.17.1 Itemization Changelog.txt`**: Mid-patch gear balancing and set bonus revisions.
- **`2023-12-28-11-21-36_Patch 1.17.2 - Tower of Karazhan.txt`**: 10-man Karazhan Crypts raid, Tower of Karazhan specifications, boss mechanics, and custom loot.
- **`2024-10-12-18-10-48_Patch 1.17.2 & Beyond - Class & Gameplay Changes.txt`**: In-depth talent tree restructuring, hybrid role viability buffs.

### Era 4: Modern Era & Nightmares of Ursol (2025 – 2026)
- **`2025-02-22-00-28-34_Patch 1.18.0 - Scars of the Past.txt`**: Major client transition, updated asset pipeline, class revamps.
- **`2025-06-30-23-26-04_Patch 1.18.0 - Itemization Changelog.txt`**: Complete itemization database overhaul for 1.18.0.
- **`2025-10-03-10-13-30_Patch 1.18.1 - Nightmares of Ursol.txt`**: Moonwhisper Coast (50-56), Windhorn Canyon (26-30 dungeon), Timbermaw Hold (20-man raid), Onyxia/BWL modernizations.
- **`2026-02-15-17-57-46_Patch 1.18.1 - Itemization Changelog.txt`**: The current baseline itemization ledger for Build 7272.
- **`2026-04-14-21-18-10_2026 — April 15.txt`** through **`2026-04-28-23-40-11_2026 — April 29.txt`**: Final live maintenance hotfixes.

---

## 4. Developer Hotfix & Changelog Threads

Over 300 threads in [`resources/forum/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum) are named in the format:
`YYYY-MM-DD-HH-MM-SS_YYYY — Month DD.txt` (e.g. `2023-04-08-14-49-12_2023 — April 8.txt`).

These threads are published directly by `Torta [Turtle WoW Team]` and contain bulleted lists of core, script, and database fixes applied during server maintenance.

### Example Fix Entry Analysis (`2023 — April 8`):
```markdown
- Greater blessing should work on non-grouped players again.
- The damage bonus from the Moonfury talent now applies after spell power.
- The damage bonus from the Improved Curse of Agony talent now applies after spell power.
- Sap will no longer proc damaging weapon effects or enchants.
- Fixed quest relations for The First Settlement, The Lost Tablets, and The Shadow Well.
- Head of Speaker Ganto will no longer drop from Witherbark Venomblood.
```
**Engineering Lesson**: Notice that Turtle-WoW explicitly changed Moonfury and Improved Curse of Agony talent scaling to apply *after* spell power. If an upstream VMaNGOS commit alters talent modifier order in `Unit::SpellDamageBonus`, an agent porting the fix without consulting this changelog would inadvertently revert Turtle-WoW's custom talent balancing!

---

## 5. Tooling: Automated Forum Intelligence Search

To eliminate manual searching across 22,155 files, use the PowerShell utility:
[`tools/porting/Search-ForumArchive.ps1`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/Search-ForumArchive.ps1)

### CLI Parameters:
- `-Query <string>`: Search pattern (matches thread titles or file contents).
- `-Category <string>`: Filter by subsystem: `All`, `Patches`, `Changelogs`, `Combat`, `Spells`, `Quests`, `Bugs`, `Crashes`, `Itemization`.
- `-ContentSearch`: Scans inside file text rather than just titles (ideal for specific spell names, item IDs, or NPC names).
- `-OfficialOnly`: Restricts results to posts authored by `[Turtle WoW Team]`, `Torta`, or `Pompa`.
- `-Limit <int>`: Max results to return (default: 20).
- `-Year <string>`: Filter by year (e.g. `2025`, `2026`).

### Practical Search Recipes for Agents

#### 1. Checking Custom Spell Behavior
```powershell
.\tools\porting\Search-ForumArchive.ps1 -Query "Holy Strike" -Category Spells
```

#### 2. Checking Combat Mechanic Adjustments
```powershell
.\tools\porting\Search-ForumArchive.ps1 -Query "parry haste" -Category Combat -ContentSearch
```

#### 3. Searching Official Weekly Changelogs for a Quest Fix
```powershell
.\tools\porting\Search-ForumArchive.ps1 -Query "The Tome of Valor" -Category Changelogs -ContentSearch -OfficialOnly
```

#### 4. Investigating Client Crashes or Error 132
```powershell
.\tools\porting\Search-ForumArchive.ps1 -Query "132" -Category Crashes -Limit 10
```

#### 5. Finding 1.18.1 Itemization or Set Changes
```powershell
.\tools\porting\Search-ForumArchive.ps1 -Query "1.18.1" -Category Itemization
```

---

## 6. Subsystem Research Protocols for Porting Agents

Every specialist agent must consult the forum archive during its porting workflow:

### `AGENT_COMBAT`
- **Focus**: Physical formulas, armor mitigation, defense skills, glancing blows, rage generation, weapon procs.
- **Forum Check**: Query `Category Combat` for the affected mechanic. Verify if Turtle WoW altered damage coefficients, racial weapon bonuses (e.g. High Elf / Goblin racials), or diminishing return categories.

### `AGENT_SPELLS`
- **Focus**: Aura handlers, spell damage bonus formulas, spell stacking, debuff limits.
- **Forum Check**: Query `Category Spells` and `Category Changelogs`. Check whether the spell was reworked in 1.16.1, 1.17.2, or 1.18.0. Verify that `sTWDebuff` streaming hooks and custom spell IDs (>40000) are preserved.

### `AGENT_AI_SCRIPTS`
- **Focus**: Creature waypoints, escort logic, boss scripts (MC, BWL, Onyxia, Karazhan).
- **Forum Check**: Query `Category Quests` and `Category Changelogs` for the NPC or boss name. Check if Turtle WoW has custom waypoints (e.g. "REVERSE" flag), custom escort speed adjustments, or custom encounter phases.

### `AGENT_WORLD_CONTENT`
- **Focus**: Gameobjects, doors, chests, vendor inventories, quest prerequisite chains.
- **Forum Check**: Query `Category Quests` or `Category Bugs`. Ensure vanilla template updates do not delete custom Turtle quest givers, custom items, or `CustomMerchantMgr` currencies.

### `AGENT_DATABASE`
- **Focus**: SQL updates, item templates, creature loot, spell DBC links.
- **Forum Check**: Query `Category Itemization` and `Category Changelogs`. Cross-reference stats against `Patch 1.18.1 - Itemization Changelog.txt` to prevent rolling back custom item stats or set bonuses.

### `AGENT_QA_VERIFY`
- **Focus**: Pre-merge verification, regression prevention.
- **Forum Check**: Query known bug reports for the touched system to ensure the proposed patch does not reintroduce a bug that was historically solved and documented on the forums.
