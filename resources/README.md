# Project Resources & Empirical Intelligence

This directory contains external reference assets, community data dumps, empirical gameplay archives, and canonical design documents utilized by developers and AI agents to guide bugfixing and backporting from **VMaNGOS** into **Tortoise-WoW**.

---

## Available Resources & Guides

### 1. [`resources/forum/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum)
- **Description**: The complete official Turtle-WoW forum archive consisting of **22,155 threads** dating from September 2018 through May 2026.
- **Key Contents**:
  - Official Major Patch Announcements & Design Specs (Patches 1.12.1+ through 1.18.1).
  - Over 300 date-stamped developer hotfix changelogs authored by `Torta`, `Pompa`, and `Junkernaut`.
  - Extensive player bug reports, combat mechanic breakdowns, and spell interaction audits.
  - Baseline itemization and class change records for Turtle-WoW 1.18.1 (Build 7272).

### 2. [`resources/FORUM_RESOURCE_GUIDE.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/FORUM_RESOURCE_GUIDE.md)
- **Description**: Architectural and historical guide detailing the 8-year patch roadmap, changelog indexes, and empirical triage methodology.

### 3. [`resources/DATABASE_AND_BUG_INTELLIGENCE.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/DATABASE_AND_BUG_INTELLIGENCE.md)
- **Description**: Exhaustive guide mapping forum bug reports directly to `world` database tables (`quest_template`, `creature_template`, `item_template`, `creature_movement`, `loot_template`) with practical rectification walkthroughs and SQL standards.

### 4. [`tools/porting/Search-ForumArchive.ps1`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/Search-ForumArchive.ps1)
- **Description**: High-performance search utility supporting category filtering, database table mapping (`-DBTable`), full-text content searching, and staff filtering.

### 5. Historical Reference Database ([`reference-upstreams/lights-hope-database-history/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/lights-hope-database-history))
- **Description**: The primary historical database reference resides at [`reference-upstreams/lights-hope-database-history/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/lights-hope-database-history) (from `brotalnia/database`), featuring the uncompressed `world_full_14_june_2021.sql` snapshot (from `world_full_14_june_2021.7z`) for original vanilla entities unchanged by Turtle WoW. Modern VMaNGOS full database dump is maintained at [`reference-upstreams/vmangos-core/db_latest/mysql-dump/mangos.sql`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/vmangos-core/db_latest/mysql-dump/mangos.sql) as an updated donor backup.

### 6. Turtle Database Viewer & Dashboard ([`reference-upstreams/tortoise-db-viewer/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/tortoise-db-viewer))
- **Description**: The interactive database viewer and dashboard resides at [`reference-upstreams/tortoise-db-viewer/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/tortoise-db-viewer) (cloned from `https://github.com/Xian55/tortoise-db-viewer`), providing an AoWoW-style web dashboard, compiled SQLite schema, REST API, and local dataset catalogs (`scripts/data/vanilla-ids.json`) for items, NPCs, spells, and quests.

---

## Usage Guidelines

1. **Read-Only Archive**: Files under `resources/forum/` represent historical records and must be treated as immutable reference material.
2. **Search Before Porting**: Always consult the forum archive via `Search-ForumArchive.ps1` before porting changes that touch combat formulas, talent damage scalers, spell auras, creature waypoints, or database item stats.
3. **Database Rectification**: Follow the workflows in `DATABASE_AND_BUG_INTELLIGENCE.md` to map reported bug symptoms to the exact table columns.
4. **Citation in History**: When resolving a conflict or justifying a porting adaptation using forum data, reference the exact thread title and date in [`docs/BACKPORT_HISTORY.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/BACKPORT_HISTORY.md).
