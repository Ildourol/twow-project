# DATABASE_AND_BUG_INTELLIGENCE.md: Empirical Database Rectification & Bug Mining Guide

This guide provides a comprehensive, production-grade methodology for utilizing the **Turtle-WoW Official Forum Archive** ([`resources/forum/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum)) to discover server bugs, analyze complex mechanics, and rectify database records in **Tortoise-WoW** (`tortoise-wow`).

---

## 1. The Power of Empirical Forum Intelligence

World of Warcraft server emulators often suffer from discrepancies between:
1. **Raw Core Logic (C++)**: Combat mechanics, spell effects, spline movement, packet handling.
2. **World Database (MySQL / MariaDB)**: Quest flags, creature stats, waypoint data, loot templates, itemization.
3. **Player Experience & Live Behavior**: Actual server behavior over 8 years of live production.

The Turtle-WoW forum archive contains **22,155 threads** capturing eight years (2018–2026) of live bug reports, player combat logs, developer hotfixes, and itemization overhauls. This archive provides **first-hand empirical evidence** of how the game worked in production, where the database had errors, and how the developers corrected them.

---

## 2. Subsystem-to-Database Mapping Reference

When a bug report is identified in the forum archive, use this reference table to locate the relevant database tables and columns in `tortoise-wow`:

| Subsystem | Forum Search Keywords | Primary Database Tables | Key Columns to Inspect & Rectify |
| :--- | :--- | :--- | :--- |
| **Quests** | `quest`, `turnin`, `escort`, `giver`, `pre-quest` | `quest_template`<br>`quest_end_scripts`<br>`quest_start_scripts` | `entry`, `Method`, `PrevQuestId`, `NextQuestId`, `ExclusiveGroup`, `RequiredRaces`, `ReqCreatureOrGOId`, `ReqItemCount`, `RewSpellCast`, `SrcItemId` |
| **Creatures & Spawns** | `mob`, `boss`, `respawn`, `patrol`, `waypoint`, `evade` | `creature_template`<br>`creature`<br>`creature_movement`<br>`creature_addon` | `entry`, `name`, `minlevel`, `maxlevel`, `faction`, `unit_flags`, `mechanic_immune_mask`, `spawntimesecs`, `MovementType`, `wander_distance` |
| **Escort & Movement** | `escort`, `stuck`, `pathing`, `speed`, `reverse` | `creature_movement`<br>`creature_movement_template`<br>`script_waypoint` | `point`, `position_x`, `position_y`, `position_z`, `waittime`, `script_id`, `orientation` |
| **Itemization & Stats** | `item`, `stats`, `stat squish`, `weapon speed`, `set bonus` | `item_template`<br>`item_template_additional`<br>`item_set_names` | `entry`, `name`, `Quality`, `ItemLevel`, `RequiredLevel`, `stat_type1-10`, `stat_value1-10`, `dmg_min1`, `dmg_max1`, `delay`, `spellid_1-5`, `spelltrigger_1-5` |
| **Loot Tables** | `drop rate`, `missing drop`, `loot`, `skinning`, `pickpocket` | `creature_loot_template`<br>`gameobject_loot_template`<br>`item_loot_template`<br>`reference_loot_template` | `entry`, `item`, `ChanceOrQuestChance`, `groupid`, `mincountOrRef`, `maxcount` |
| **Vendors & Prices** | `vendor`, `buyback`, `stock`, `cost`, `token` | `npc_vendor`<br>`npc_vendor_template`<br>`custom_merchant_template` | `entry`, `item`, `maxcount`, `incrtime`, `ExtendedCost` |
| **GameObjects & Nodes** | `chest`, `door`, `trap`, `herb`, `mine`, `flower` | `gameobject_template`<br>`gameobject`<br>`gameobject_addon` | `entry`, `type`, `displayId`, `name`, `flags`, `data0-23` (type-specific parameters) |
| **Trainer & Spells** | `trainer`, `learn`, `spell`, `rank`, `talent` | `npc_trainer`<br>`npc_trainer_template`<br>`spell_template` (or DBC) | `entry`, `spell`, `spellcost`, `reqskill`, `reqskillvalue`, `reqlevel` |

---

## 3. Bug Mining & Database Rectification Workflows

### 3.1. Workflow 1: Investigating a Quest Issue

1. **Search Forum for Quest Title**:
   ```powershell
   .\tools\porting\Search-ForumArchive.ps1 -Query "Questioning Reethe" -Category Quests
   ```
2. **Analyze the Problem Statement**:
   - Player reports: *"Reethe doesn't spawn after speaking with Krazek"* or *"Quest cannot be turned in if died during escort"*.
   - Staff response: Look for replies by `Torta` or `[Turtle WoW Team]` confirming the fix or missing trigger.
3. **Inspect the Target Database Record**:
   In `tortoise-wow/sql/base/world_database.sql` or live DB:
   ```sql
   SELECT entry, Title, PrevQuestId, NextQuestId, ReqCreatureOrGOId1, ReqCreatureOrGOCount1
   FROM quest_template WHERE entry = 1264;
   ```
4. **Draft the Database Rectification Script**:
   Create a timestamped migration in `tortoise-wow/sql/database_updates/world/`:
   ```sql
   -- Fix quest relation for Questioning Reethe
   UPDATE `quest_template` SET `PrevQuestId` = 1263 WHERE `entry` = 1264;
   ```

---

### 3.2. Workflow 2: Reconciling Custom Item Stats & Stat Squishes

Turtle-WoW introduced several major itemization passes (notably in Patch 1.17.0, 1.17.1, 1.17.2, and 1.18.1). When VMaNGOS SQL migrations update `item_template`, they often revert custom Turtle stat adjustments back to retail vanilla values.

1. **Search Forum Itemization Changelog**:
   ```powershell
   .\tools\porting\Search-ForumArchive.ps1 -Query "Itemization Changelog" -Category Itemization
   ```
2. **Cross-Reference Specific Item**:
   ```powershell
   .\tools\porting\Search-ForumArchive.ps1 -Query "Ornate Dagger of Jalvan" -Category Itemization -ContentSearch
   ```
   *Empirical Finding*: The thread `2023 — April 8.txt` states:
   > *"Ornate Dagger of Jalvan now gives positive intellect instead of negative."*
3. **Verify `item_template` in Tortoise-WoW**:
   Check `stat_type` and `stat_value` to ensure `stat_value` is positive. If an upstream VMaNGOS migration touches this item, safeguard the Turtle modification.

---

### 3.3. Workflow 3: Fixing Creature Spawns & Waypoint Pathing

1. **Search Forum for Creature Name**:
   ```powershell
   .\tools\porting\Search-ForumArchive.ps1 -Query "Lakota" -Category Quests
   ```
   *Empirical Finding* (`2018-10-15-13-47-16_Changelog First Week!.txt`):
   > *"Lakota is spawning and despawning on correct positions."*
2. **Review Waypoint Table Structure**:
   Check `script_waypoint` or `creature_movement` for `entry = 10646` (Lakota Windsong).
   Verify that:
   - Initial spawn position matches the start waypoint.
   - Despawn delay is long enough for the turn-in conversation.
   - `MovementType` is set to `2` (Waypoint movement).

---

### 3.4. Workflow 4: Discovering Server Crashes & Client Opcode Errors

1. **Search Forum Crash Reports**:
   ```powershell
   .\tools\porting\Search-ForumArchive.ps1 -Query "Error 132" -Category Crashes -Limit 10
   ```
2. **Common Crash Vectors Documented**:
   - **Invalid Display IDs**: A creature or gameobject assigned an ID not present in the 1.18.1 client DBC files causes an instant client crash (`Error 132: Memory could not be read`).
   - **Debuff Array Overflows**: Custom spells pushing aura arrays beyond client packet limits (resolved via `TWDebuff`).
   - **Addon Message Filtering**: Improper packet lengths in `CMSG_MESSAGECHAT` breaking custom UI addons.

---

## 4. Empirical SQL Migration Standards

All database fixes derived from forum investigations must adhere to the following standards:

1. **Timestamped Naming**:
   `sql/database_updates/world/YYYYMMDDHHMMSS_world.sql`
2. **Idempotency**:
   Use `INSERT IGNORE`, `REPLACE INTO`, or check preconditions.
3. **Turtle Range Preservation**:
   - Vanilla entries: `1` to `35000`
   - Turtle custom entries: `40000+`, `50000+`, `60000+`
   - **Never overwrite or delete IDs in custom ranges** without explicit forum verification.
4. **Header Citation**:
   ```sql
   -- ==============================================================================
   -- Fix: Correct Lakota Windsong escort despawn timer & quest relations
   -- Source: Turtle-WoW Forum Archive (2018-10-15 Changelog First Week!)
   -- Subsystem: Quests / Escorts
   -- Target Table: quest_template, creature_movement
   -- ==============================================================================
   ```

---

## 5. Agent Runbook for DB & Bug Rectification

All specialist agents working on bug fixes and database migrations must follow this three-step verification cycle:

```
[ Step 1: Mine Archive ] ---> [ Step 2: Cross-Check DB ] ---> [ Step 3: Implement & Verify ]
Search-ForumArchive.ps1       Inspect SQL Schema / Rows       Verify-TurtleCompatibility.ps1
Extract symptoms & specs      Verify column alignments       Commit with forum citation
```
