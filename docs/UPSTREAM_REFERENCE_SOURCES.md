# Upstream Reference Sources

This document establishes the authority hierarchy, purpose, local filesystem paths, revision ledger, and research workflows for all external reference repositories used in developing and maintaining **Tortoise-WoW Extended**.

---

## 1. Authority Hierarchy

All porting, debugging, and data investigation work must strictly respect the following authority ordering:

1. **`Penqle/tortoise-wow`** — **Authoritative Host**
   - Repository: https://github.com/Penqle/tortoise-wow
   - Owns all identifiers, numeric values, enum allocations, database schema layouts, configuration keys, custom gameplay systems (`sTWDebuff`, custom races, custom DBCs, custom managers, custom spell IDs >40000), and public/core semantics.
   - **Turtle WoW always wins in conflicts.** Never alter or renumber an existing Turtle value merely to accommodate foreign donor code or data.

2. **`vmangos/core`** — **Primary Modern Fix Donor**
   - Repository: https://github.com/vmangos/core
   - The primary source of candidate fixes for modern Vanilla bugs: crashes, exploits, memory/lifetime leaks, bounds checks, combat formulas, spell mechanics, movement/AI pathing, mature dungeon/raid encounters, and Nostalrius/vanilla database corrections.
   - Always prove that the candidate bug actually exists in Turtle WoW before porting. Never cherry-pick diffs blindly.

3. **`lduguid/core` (Elysium Core)** — **Historical Implementation Reference**
   - Repository: https://github.com/lduguid/core
   - Historical archaeological reference used when modern VMaNGOS has undergone large architectural rewrites, refactors, or introduced complex helper dependencies that Turtle does not possess.
   - Useful for discovering the original minimal semantic fix before subsequent layers of abstraction were added.
   - **Strictly read-only reference.** Age is not evidence of correctness; do not assume older Elysium code is superior to modern VMaNGOS fixes.

4. **`brotalnia/database`** — **Historical Database Lineage Snapshots**
   - Repository: https://github.com/brotalnia/database
   - Historical database reference for investigating the evolution of world data, creature templates, EventAI scripts, spell templates, loot distributions, and spawn waypoints across the Nostalrius -> Elysium -> Light's Hope timeline.
   - **Strictly read-only reference.** Never import full dumps, execute foreign migrations directly, or overwrite Turtle tables.

5. **`LightsHope/database`** — **Secondary Historical DB Reference**
   - Repository: https://github.com/LightsHope/database
   - Secondary historical database reference for cross-validating Light's Hope progression data, bugfix migrations, and schema changes when Brotalnia's archives require corroboration.

6. **`xian55/tortoise-db-viewer`** — **Online Turtle Database Viewer & Asset Oracle**
   - Website: https://xian55.github.io/tortoise-db-viewer/
   - Repository: https://github.com/xian55/tortoise-db-viewer (branches `cdn`, `cdn-dev`)
   - Authoritative online viewer and client SQLite/WASM database compiled directly from Turtle-WoW 1.18.1 server dumps. Provides item stats, 3D character models, creature loot tables, vendor inventories, and live CDN database changelogs.
   - Command: `task 6 <query_or_id>` (alias: `task db-viewer`).

---

## 2. Hard Separation Boundaries

All historical donor and reference repositories are maintained **strictly outside the Turtle source tree** in a single consolidated directory (`twow project/reference-upstreams/`).

- **Never clone inside the Turtle repository**: No external repositories reside within `twow project/tortoise-wow`.
- **Never add as Git submodules**: Reference repositories must never be linked as submodules in the Turtle Git tree.
- **Never link in CMake or build systems**: CMakeLists.txt and build configurations must have zero dependencies on reference directories.
- **Never compile, install, or run foreign code**: Reference repositories are never compiled, installed, or executed as server binaries.
- **Never import or execute foreign database dumps**: Foreign SQL files are reference evidence only. All database updates in Turtle must be hand-crafted, schema-compliant, progressive-column-free migrations in `sql/database_updates/world/`.
- **Read-Only Inspection Only**: Reference repositories exist solely for source inspection, commit archaeology, `git blame` tracing, and row-level SQL comparison.

### 2.1. Physical Filesystem Policy & Elimination of NTFS Junctions
All reference repositories and client data directories in `twow project/reference-upstreams/` MUST be **100% standard physical directories**:
- **Zero NTFS Junctions / Reparse Points**: All directory junctions have been permanently removed. Creating junctions (`mklink /J`), symlinks (`mklink /D`), or reparse points is strictly prohibited across the workspace.
- **Physical Directory Standardization & Renames**:
  - `client-data-1.18.1`: Extracted client assets (158 DBCs, 2,805 maps, 2,133 mmaps, 6,921 vmaps). Renamed from `twow_data-1.18.1` to directly match server configuration expectations; the former alias junction has been completely deleted.
  - `lights-hope-database-history`: Retained as the sole historical DB reference (`brotalnia/database`). All `.7z` archives have been cleared; `world_full_14_june_2021.sql` is retained uncompressed as the latest baseline.
  - `vmangos-core/db_latest`: Modern VMaNGOS database dump (`mysql-dump/mangos.sql`).
  - Redundant directories (`reference_db`, `lights-hope-database`, and the dangling junction `resources/reference_db`) have been permanently deleted.

---

## 3. Local Reference Inventory & Inspected Revisions

All paths below are fully resolved absolute local filesystem paths on this system:

| Identifier | Upstream Source | Role | Local Path | Current Branch | Verified Inspected SHA |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`HOST`** | `Penqle/tortoise-wow` | Authoritative Host | `C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow` | `main` | `053cb501f11fda999967ffef60852b8902bf26c0` |
| **`vmangos-core`** | `vmangos/core` | Primary Modern Donor | `C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core` | `development` | `448df9ba06d2b2b1678fcfd782a77e1e3ebf26b9` |
| **`elysium-core`** | `lduguid/core` | Historical Core Reference | `C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\elysium-core` | `master` | `641e6a564c6f9f6c6695296666e530e460ac563d` |
| **`lh-db-history`** | `brotalnia/database` | Main Historical DB Reference | `C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\lights-hope-database-history` | `master` | `world_full_14_june_2021.sql` (Latest uncompressed snapshot) |
| **`client-data-1.18.1`** | `Twow_data-1.18.1` | Client Data Reference (DBC/Maps) | `C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\client-data-1.18.1` | `main` | `c993a49af2dd470e9ae0dcca48d75168be915117` |
| **`tortoise-db-viewer`** | `xian55/tortoise-db-viewer` | Online DB & 3D Asset Oracle | `https://xian55.github.io/tortoise-db-viewer/` | `cdn-dev` | Live CDN SQLite / WASM (`task 6`) |

---

## 4. Single-Commit Reference Research Protocol

When investigating any individual candidate donor commit:

1. **Step 1 — Identify**: View the candidate commit in `core` (`git show <sha>`). Record full SHA, commit title, touched files, and underlying bug.
2. **Step 2 — Prove Bug**: Inspect current Turtle source and database. Verify whether the defect exists in Turtle. If not, record `NOT-APPLICABLE` and stop.
3. **Step 3 — Check Turtle Customization**: Search for custom Turtle spells (>40000), 10-race handling (`MAX_RACES = 11`), debuff streaming (`sTWDebuff`), custom DBCs, and custom managers.
4. **Step 4 — Compare Modern VMaNGOS**: Isolate the minimal semantic correction from surrounding refactors.
5. **Step 5 — Consult Elysium When Diverged**: If modern VMaNGOS has diverged substantially, compare the function in `elysium-core`. Check if an older, simpler implementation fits Turtle's Elysium-era baseline better.
6. **Step 6 — Trace Intermediate History**: Trace `Elysium -> Light's Hope -> VMaNGOS` to distinguish the original bug fix from subsequent abstraction layers.
7. **Step 7 — Adapt Minimal Semantics**: Implement only the minimal semantic fix into Turtle native code.
8. **Step 8 — Adapt Conflicts**: If identifiers or contracts conflict, adapt the donor patch. Penqle identifiers never move.
9. **Step 9 — Database Scalping & Sanitization**: If SQL changes accompany the fix or an entity requires investigation, use the database scalper (`task scalp <table_alias> <entry_id> -Diff` / `tools/porting/Extract-DbEntity.ps1`). The scalper compares Brotalnia (`world_full_14_june_2021.sql`) against Turtle base SQL (`sql/base/tw_world_*.sql`), strips progressive columns (`patch`, `patch_min`, `patch_max`, `build`), protects custom IDs (`entry >= 300000`), and auto-generates sanitized migrations with `-Export`.
10. **Step 10 — Verify & QA**: Run static checks, migration audit (`Audit-DatabaseMigrations.ps1`), compatibility audit (`Verify-TurtleCompatibility.ps1`), and verify build/link.
