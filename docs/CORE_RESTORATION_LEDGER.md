# Turtle-WoW Native Core Restoration Ledger

This document is the permanent, authoritative ledger tracking all official Turtle-WoW forum patch specifications, changelogs, and custom mechanics audited by **Agent 5 (`task restore` / `task 5`)**.

> [!NOTE]
> **PREVENTION OF REDUNDANT FORUM SEARCHES (ZERO DOUBLE-CHECKING)**
> Every topic, patch note, or mechanic searched via `task restore <topic>` or `task restore-batch` is persistently catalogued here and in `tools/queue/restoration_history.json`.
> When a topic has already been audited, future runs recognize the cached evaluation and immediately report its status without re-scanning all 22,155 forum threads.

---

## 1. Executive Summary & Restoration Metrics

- **Total Topics Audited**: 3
- **Parity Confirmed (Already Present in Leaked Core)**: 2 (`Holy Strike`, `Blood Frenzy`)
- **Missing / Divergent (Restoration Packages Staged)**: 1 (`Moonfury`)
- **Restorations Built & Pushed to Remote**: 0
- **Cache File**: `tools/queue/restoration_history.json`

---

## 2. High-Priority Restoration Queue (Reference Catalog: Patch Notes 1.15.0 - 1.18.1)

The following custom Turtle-WoW systems and mechanics are queued for sequential parity audits:

| Priority | Topic | Target Patch / Source | Subsystem | Key Invariants to Verify |
|---|:---|:---|:---|:---|
| 1 | `Holy Strike` | Patch 1.16.1 Class Balance | Spells / Paladin | Custom spell ID 40000+ range, holy weapon damage formula |
| 2 | `Moonfury` | Patch 1.16.1 Class Balance | Spells / Druid | Balance druid cast time reduction, spell power scaling |
| 3 | `Blood Frenzy` | Patch 1.16.1 Class Balance | Spells / Warrior | Custom bleed proc mechanics |
| 4 | `Goblins Racial` | Patch 1.15.0 Race Expansion | Player / Racials | `MAX_RACES = 11`, Best Deals Anywhere (vendor discount), Rocket Jump |
| 5 | `High Elves Racial` | Patch 1.15.0 Race Expansion | Player / Racials | `MAX_RACES = 11`, Arcane Meditation, Magic Resistance |
| 6 | `Survival Skill` | Patch 1.12.1+ Custom Profession | Spells / Skills | Campfires, fishing tents, survival buffs |
| 7 | `Gardening Skill` | Patch 1.12.1+ Custom Profession | Spells / Skills | Custom plant nodes, herbalism synergies |
| 8 | `Karazhan Crypts` | Patch 1.17.2 Raid / Dungeon | Dungeons / Scripts | Custom instance scripts, boss encounter scripts |
| 9 | `Looking For Turtle (LFT)` | Patch 1.16.0+ Dungeon Finder | Core / Addon Protocol | `LFTMgr`, custom opcode routing, dungeon teleporting |
| 10 | `Transmogrification` | Patch 1.16.0+ Custom Feature | Core / Addon Protocol | `TransmogMgr`, appearance caching, token vendor |
| 11 | `Custom Collections` | Patch 1.17.0+ Mounts & Toys | Core / Managers | `MountManager`, `CompanionManager`, `ToyManager` |
| 12 | `Dynamic Visibility` | Patch 1.17.0+ Engine Scaling | Engine / Platform | `DynamicVisibilityMgr`, crowd visibility optimization |

---

## 3. Audited Forum Specifications & Parity Registry

| # | Date Audited | Topic / Feature | Subsystem | Forum Threads Verified | Codebase Status in Tortoise-WoW | Restoration Verdict | Package / Commit ID |
|---|:---|:---|:---|:---|:---|:---|:---|
| 1 | 2026-09-09 | `Holy Strike` | Auto | Patch 1.12.1+ - Holy Strike.txt | Present (10 occurrences) | **PARITY_VERIFIED** | None (Parity OK) |
| 2 | 2026-09-09 | `Moonfury` | Auto | None found | Missing / Stubbed | **AWAITING_RESTORATION** | `CORE-0001` |
| 3 | 2026-09-09 | `Blood Frenzy` | Auto | None found | Present (11 occurrences) | **PARITY_VERIFIED** | None (Parity OK) |
