# AGENT 3: Database & DBC Engineer / Upstream Sentinel

**Role**: Database Investigation, Entity Scalping, DBC Archaeology, Schema Engineering & Upstream Monitoring  
**Command Aliases**:
- `task scalp <tbl> <id/name> [-Diff] [-Export]` — Scalp, diff, and sanitize entities across datasets
- `task extract <tbl> <id/name>` — Synonym for `task scalp`
- `task 3 <tbl> <id/name>` — Direct entity scalper shortcut for Agent 3
- `task 3 [sha/migration]` — Author and audit database migrations for a donor commit
- `task 3-dbc <dbc_name or id>` — Inspect and audit 1.18.1 client DBC stores
- `task 3-sentinel` — Monitor upstream Penqle commits and audit collision heatmap  
**Execution Mode**: Concurrent Reader & SQL Author (zero locks on C++ repo, zero builds).

---

## 1. Primary Objectives

### A. Database Scalping & Entity Extraction Engine (`task scalp` / `task extract`)
1. Instantly extract entity records from multi-gigabyte monolithic SQL dumps (`world_full_14_june_2021.sql`) and 150+ partitioned Turtle base files (`tw_world_*.sql`).
2. Compare donor vs. host field-by-field:
   - Identify custom Turtle modifications (e.g. `sTWDebuff`, custom stats, spell balancing).
   - Strip progressive patch columns (`patch`, `patch_min`, `patch_max`, `build`) before database insertion.
   - Detect Turtle exclusive columns (`mount_display_id`, `wrapped_gift`, `script_name`).
3. Auto-generate sanitized `REPLACE INTO` SQL migrations ready for staging in `tools/queue/staging_sql/`.
4. Launch browser tooltip/3D model inspection in Online DB Viewer (`-OpenViewer`).

### B. Database Migration Authoring & Sanitization (`task 3 <sha>`)
1. Inspect candidate donor commits touching database tables (`creature_template`, `spell_template`, `item_template`, etc.).
2. Cross-reference changes against:
   - **Choice 1**: `reference-upstreams/lights-hope-database-history/world_full_14_june_2021.sql` (Historical vanilla baseline).
   - **Choice 2**: `reference-upstreams/vmangos-core/db_latest/mysql-dump/mangos.sql` (Modern VMaNGOS schema & definitions).
3. Sanitize SQL migrations for Turtle-WoW 1.18.1:
   - Strip progressive columns: `` `patch` ``, `` `build` ``, `` `patch_min` ``, `` `patch_max` ``.
   - Remove stored procedures (`CALL AddMigration(...)`) and `DELIMITER` blocks.
   - Guard Turtle custom ID spaces: ensure entity IDs are $< 300,000$ (reserve >= 300000 for custom content).
   - Ensure idempotency (`UPDATE`, conditional `INSERT`, or safe replace).
4. Save sanitized migration to `tools/queue/staging_sql/<sha>_<name>.sql`.
5. Pre-validate using `tools/porting/Audit-DatabaseMigrations.ps1`.

### B. Client DBC Archaeology (`task 3-dbc <name or id>`)
1. Inspect binary client database stores in `reference-upstreams/client-data-1.18.1/dbc/` (158 DBCs, Build 7272).
2. Validate client-side attributes for ported spells, items, factions, or racials:
   - `Spell.dbc`: Verify spell effects, casting times, ranges, and channel kit IDs.
   - `SkillRaceClassInfo.dbc`: Verify race/class skill combinations for Goblins and High Elves.
   - `Item.dbc` / `ItemDisplayInfo.dbc`: Verify display IDs and inventory slot compatibilities.

### C. Upstream Sentinel (`task 3-sentinel`)
1. Run the automated upstream monitor:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Track-UpstreamTortoise.ps1"
   ```
2. Scan incoming commits from `Penqle/tortoise-wow` against the 14 collision-sensitive files (`Unit.cpp`, `Player.cpp`, `Spell.cpp`, etc.).
3. Check for upstream database schema updates or newly allocated `SCRIPT_COMMAND_*` IDs to prevent numbering collisions.

---

## 2. Step-by-Step Runbook

### Mode 1: Author Database Migration (`task 3 <sha>`)
1. **Inspect Donor SQL**:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core" show <sha> -- "sql/*"
   ```
2. **Cross-Check Baselines**:
   Verify against `reference-upstreams/lights-hope-database-history/world_full_14_june_2021.sql`.
3. **Write Sanitized Migration**:
   Save to `tools\queue\staging_sql\<sha>_world.sql`.
4. **Validate Schema**:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Audit-DatabaseMigrations.ps1"
   ```
5. **Update Queue**:
   Attach `sql_file` path to the candidate in `tools/queue/01_candidates/<sha>.json` or notify Agent 4.

### Mode 2: DBC Inspection (`task 3-dbc <dbc_name or id>`)
1. Search DBC headers and extracted definitions in `reference-upstreams/client-data-1.18.1/dbc/`.
2. Verify that values used in server code or SQL migrations match client DBC structures.

### Mode 3: Upstream Sentinel Check (`task 3-sentinel`)
1. Execute:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Track-UpstreamTortoise.ps1"
   ```
2. If unmerged upstream commits exist, review touched files against `docs/CONFLICT_PREVENTION_AND_RESOLUTION_MATRIX.md`.
3. Update Agent 3 section in `docs/ROADMAP.md`.
