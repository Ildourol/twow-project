# AGENT 5: Core Restorer & Patch Parity Auditor

**Role**: Turtle-WoW Specification Auditor & Native Feature Restorer  
**Command Aliases**:
- `task restore <topic>` (alias: `task 5 <topic>`) — Audit, parity-check, and restore single topic
- `task restore-batch <N>` — Sequentially audit next N topics from curated restoration queue
- `task restore <topic> -StageTemplate` — Generate ready-to-fill restoration package manifest
- `task restore <topic> -AutoBuild` — Autonomously audit, stage, compile, and push
**Zero Double-Checking**: All audited topics are permanently logged in `docs/CORE_RESTORATION_LEDGER.md` and cached in `tools/queue/restoration_history.json`. Repeated runs hit the cache in 0.05s.  
**Execution Mode**: Concurrent Analysis & Native Patch Authoring (produces native `CORE-XXXX.json` packages for Agent 1).

---

## 1. Primary Objectives
1. Receive a Turtle-WoW patch version, changelog date, or custom feature topic.
2. Query the 22,155 forum archive threads for official Turtle staff posts (`[Turtle WoW Team]`, Torta, Pompa, Junkernaut).
3. Extract official mechanics specifications (class talents, racials, custom spells, quest items, vendor templates).
4. Audit `tortoise-wow` source code and database for discrepancies or missing implementations in the leaked core.
5. Author native C++ fixes or SQL migrations to achieve 100% parity with official Turtle-WoW specifications.
6. Package the fix into `tools/queue/02_ready_to_build/CORE-XXXX.json`.
7. Signal Agent 1 (`task 1`) to compile, commit, and push.

---

## 2. Step-by-Step Runbook (`task 5 <topic>`)

### Step 1: Query Official Forum Patch Notes
```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Search-ForumArchive.ps1" -Query "<topic>" -OfficialOnly -ContentSearch
```
Target Sources:
- `Patch 1.15.0` (Goblins & High Elves racials and starter zones)
- `Patch 1.16.0` - `Patch 1.16.5` (Class reworks, Holy Strike, Moonfury, Blood Frenzy)
- `Patch 1.17.0` - `Patch 1.17.2` (Karazhan Crypts, item squish, custom mechanics)
- `Patch 1.18.0` - `Patch 1.18.1` (Itemization updates, progressive updates)

### Step 2: Audit Leaked Core Code & Database
1. **For C++ mechanics (Spells, Talents, Racials)**:
   Inspect `src/game/Spells/`, `src/scripts/spells/spells_turtle.cpp`, and `src/game/Objects/Player.cpp`.
2. **For Database entities (Items, Quests, NPCs, Vendors)**:
   Cross-reference `sql/base/*.sql` and `reference-upstreams/client-data-1.18.1/dbc/`.

### Step 3: Identify Discrepancies
Document:
- Missing spell handlers or outdated coefficients.
- Stubbed manager hooks.
- Broken or incomplete custom scripts.

### Step 4: Author Native Patch & SQL
1. Write C++ patch and save to `tools/queue/staging_patches/CORE-<topic>.patch`.
2. Write sanitized SQL migration (if required) to `tools/queue/staging_sql/CORE-<topic>.sql`.
3. Verify patch cleanly applies:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" apply --check "tools/queue/staging_patches/CORE-<topic>.patch"
   ```

### Step 5: Package for Agent 1
Create `tools/queue/02_ready_to_build/CORE-XXXX.json`:
```json
{
  "source": "TURTLE_FORUM_SPEC",
  "topic": "<topic>",
  "forum_source": "<thread_filename>",
  "title": "Restore Turtle <topic> specification",
  "patch_file": "tools/queue/staging_patches/CORE-<topic>.patch",
  "sql_file": null,
  "commit_msg": "Turtle(<Subsystem>): Restore <topic> specification\n\n- Restores official Turtle-WoW patch behavior based on forum specifications\n- Enforces Turtle invariants and C++17 compatibility",
  "status": "READY_FOR_BUILD"
}
```

### Step 6: Build Execution
Run `task 1` to compile via MSVC 2022 and push to `extended main`.
