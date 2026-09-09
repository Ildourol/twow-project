# PORTING_PLAN.md: Strategic Blueprint for VMaNGOS-to-Tortoise Porting

This document outlines the strategic blueprint, subsystem divergence analysis, priority matrix, and engineering safeguards for backporting bugfixes and mechanics improvements from **VMaNGOS** (`reference-upstreams/vmangos-core`, aliased via `core`) into **Tortoise-WoW Extended** (`twow project/tortoise-wow`).

---

## 1. Executive Summary & Context

### 1.1. Background
- **VMaNGOS** represents nearly a decade of rigorous, empirical research into the World of Warcraft 1.12.1 (Build 5875) vanilla server architecture. It features thousands of fixes derived from retail sniffs, classic sniffs, and combat log analysis covering combat formulas, line of sight, creature pathing, boss encounters, and database consistency.
- **Tortoise-WoW** is an open-source, community-driven restoration of the Turtle-WoW 1.18.1 (Build 7272) server core. While originally derived from the same historical Elysium/Nostalrius lineage, Tortoise-WoW has diverged significantly to support custom client features: custom races (Goblins and High Elves), custom classes and talents, a dynamic debuff streaming system (`TWDebuff`), modern modules (AzerothCore-derived), LFT (dungeon finder), transmogrification, and custom world content.

### 1.2. The Core Objective
To systematically backport applicable fixes, combat accuracy improvements, movement stability, encounter scripts, and engine safeguards from VMaNGOS into Tortoise-WoW **without regressing or breaking any Turtle-WoW specific mechanics, custom races, debuff architecture, or client protocol compatibility**.

### 1.3. Development Model & Metrics
- **Target Repository**: [`https://github.com/Ildourol/tortoise-wow-extended`](https://github.com/Ildourol/tortoise-wow-extended) branch `main`
- **Baseline Anchor**: [`Penqle/tortoise-wow`](https://github.com/Penqle/tortoise-wow.git) @ `b8f24bef6cfc69feafc5870ac6a8918a521253d7`
- **Current HEAD**: [`053cb501f`](https://github.com/Ildourol/tortoise-wow-extended/commit/053cb501f11fda999967ffef60852b8902bf26c0)
- **Development Model**: Strict **commit-by-commit backporting** (1 bug diagnosis = 1 donor commit = 1 AI investigation = 1 Turtle adaptation = 1 build verification = 1 atomic git commit = 1 remote push).
- **Current Active State**: 1 build fix patch (`BUILD-0001`) + 0 donor bugfixes (fresh inception run).
- **Compilation Gate**: 100% clean MSVC 2022 x64 Release builds (`realmd.exe` + `mangosd.exe` with Exit Code 0).

---

## 2. Subsystem Audit & Divergence Matrix

| Subsystem | VMaNGOS Architecture | Tortoise-WoW Architecture | Divergence Severity | Forum Intelligence Reference (`resources/forum/`) | Porting Strategy |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Combat & Formulas** | C++14, 8 playable races (`MAX_RACES = 9`), vanilla mitigation & crit formulas. | C++17, 10 playable races (`MAX_RACES = 11`), custom racial bonuses & balance tweaks. | **Medium** | `Patch 1.15.0 - Goblins & High Elves`, `2021-11-06 Final Class Changes 1.16.1`, `Category Combat` | Port formulas individually; update loop bounds to `MAX_RACES`; preserve custom racials. |
| **Spells & Auras** | Strict 1.12.1 aura limits (16 debuffs), standard aura slots in unit fields. | Custom `TWDebuff` streaming architecture; custom spell IDs (>40000); 1.18.1 spells. | **High** | `Patch 1.17.2 Class Changes`, `Patch 1.18.0`, weekly changelogs (`YYYY - Month DD.txt`) | Port logic selectively. Never omit `sTWDebuff->AddDebuff` / `RemoveDebuff` calls. |
| **Creature AI & Scripts** | Highly tuned CreatureEventAI, boss scripts (MC, BWL, AQ, Naxx), waypoint systems. | Elysium-era ScriptDev, custom Turtle scripts (`spells_turtle.cpp`), custom zone AI. | **Low to Medium** | `Changelog First Week!` (Reverse waypoint system), `Patch 1.17.2 Karazhan Crypts` | Highly portable. Vanilla dungeon and raid scripts can be ported with minimal friction. |
| **Movement & Pathing** | Refined spline movement, pet follow angles, escort walk/run speeds, MMap/VMap. | Baseline MMap/VMap, standard movement generators. | **Low to Medium** | `Category Quests` (1,254 threads covering escort routes and pathing) | Port escort and follower fixes directly; spline logic is largely compatible. |
| **GameObjects & World** | Comprehensive traps, doors, LoS checks, chest traps, vendor template validation. | Standard gameobjects, custom merchant manager (`CustomMerchantMgr.cpp`). | **Low** | `Patch 1.12.1+ Survival Skill`, `Patch 1.12.1+ Gardening`, `Category Quests` | High porting value. Fixes like buyback slot preservation and vendor checks apply cleanly. |
| **Core Engine & Networking** | Vanilla 1.12.1 opcode table (`NUM_MSG_TYPES = 0x33C`), socket handling. | 1.18.1 client support, custom addon messages for LFT/Shop/Transmog, Optick profiling. | **Medium to High** | `Category Crashes` (303 threads: Error 132, packet disconnects, client-side crashes) | Port memory leak and crash fixes. Avoid changing opcode structures without 1.18.1 client verification. |
| **Database & Migrations** | `sql/migrations/` (`YYYYMMDDHHMMSS_world.sql`), 1.12.1 vanilla schema with progressive versioning columns (`patch`, `build`). | `sql/database_updates/world/`, Nostalrius schema, custom tables (`tw_world_*`), custom spell IDs (>= 40000) and world IDs (>= 300000). | **Medium** | `Patch 1.18.1 - Itemization Changelog`, `1.17.0/1.17.1 Itemization Changelogs` | Convert migrations to Tortoise format; scalp and diff vanilla entities via `task scalp` from Choice 1 (`brotalnia/database`) & Choice 2 (`vmangos/core db_latest`); verify tooltips via Online DB Viewer (`task 6`); strip progressive columns; protect custom IDs; audit via `Audit-DatabaseMigrations.ps1`. |

---

## 3. Prioritization Framework (Impact vs. Risk)

All porting tasks are evaluated and prioritized using the following hierarchy:

1. **Tier 1: Server Crashes, Exploits & Critical Memory Leaks**  
   *Bounds checks, null pointer dereference guards, heap safety, auth anti-exploits.*
2. **Tier 2: Bounds & Data Validation Fixes**  
   *Bag nesting, line-of-sight fallbacks, roll boundaries, vendor validations.*
3. **Tier 3: Combat Accuracy & Formula Correctness**  
   *HitInfo flags, wand damage calculations, water interrupt states, swing timers.*
4. **Tier 4: Pet, AI & Movement Mechanics**  
   *Escort follow angles, pet stabling/reviving, confused movement speeds.*
5. **Tier 5: Quests, World Content & Dungeons**  
   *EventAI scripts, dungeon boss resets, world event timing.*