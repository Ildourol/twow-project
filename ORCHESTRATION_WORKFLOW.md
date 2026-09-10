# ORCHESTRATION_WORKFLOW.md: End-to-End Porting Lifecycle & Runbooks

This document defines the operational orchestration workflow, step-by-step runbooks, conflict resolution strategies, and automated tracking procedures for porting fixes from **VMaNGOS** (`reference-upstreams/vmangos-core`, aliased via `core`) to **Tortoise-WoW** (`twow project/tortoise-wow`).

---

## 1. The 6-Stage Porting Lifecycle

```
[ Stage 1: Discovery & Ingestion ]
                |
                v
[ Stage 2: Compatibility Triage  ]
                |
                v
[ Stage 3: Branching & Alignment ]
                |
                v
[ Stage 4: Semantic Porting      ]
                |
                v
[ Stage 5: QA & Verification     ]
                |
                v
[ Stage 6: Commit & Audit Log    ]
```

---

### Stage 1: Discovery & Ingestion
- **Objective**: Maintain the audited, deduplicated crucial commit queue across the 7,339 commit history of VMaNGOS.
- **Runbook**:
  1. The master roadmap is pre-audited and maintained in [`docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md) and [`tools/porting/CRUCIAL_COMMITS_QUEUE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv) (5,092 crucial candidates).
  2. To refresh the deduplicated queue when new upstream commits arrive from VMaNGOS:
     ```powershell
     powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Build-CrucialRoadmap.ps1" -FetchLatest
     ```
  3. The script audits all commits, eliminates older superseded duplicates, verifies against already-ported commits, and refreshes the master roadmap.

---

### Stage 2: Compatibility Triage & AI Semantic Context Assembly
- **Objective**: Evaluate the files touched by an upstream commit, assemble local C++ surrounding code context, cross-reference historical Turtle-WoW forum lore, and assign a risk tier.
- **AI Semantic Engine Runbook (Default)**:
  1. Run the AI Semantic Context Assembler from any directory or empty CLI terminal:
     ```powershell
     & "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" port <sha>
     ```
     Or generate an isolated AI dossier:
     ```powershell
     & "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" ai-audit <sha>
     ```
  2. `Invoke-AiAudit.ps1` extracts:
     - Target donor diff in `reference-upstreams/vmangos-core`
     - Exact target source files and surrounding lines in `tortoise-wow/src/`
     - Historical design specifications from 22,155 threads in `resources/forum/`
     - Outputs complete AI dossier to `tools/queue/ai_dossiers/<sha>.md`.
  3. If cleanly applicable, stages directly in `tools/queue/02_ready_to_build/PORT-XXXX.json`. If context diverged (e.g. Turtle custom parameters like `inGurubashiArena`), stages as `AWAITING_AI_ADAPTATION` with its AI dossier.
- **Triage Decision Tree**:
  1. **Does it touch `TWDebuff` or aura application in `Unit.cpp` / `SpellAuras.cpp`?**
     -> *Tier 4: Deep Audit (Agent: AGENT_SPELLS)*.
  2. **Does it touch playable race arrays or loops?**
     -> *Tier 2: High Priority (Agent: AGENT_COMBAT). Must ensure MAX_RACES = 11*.
  3. **Does it touch custom Turtle managers (`LFTMgr`, `TransmogMgr`, `Shop`, etc.)?**
     -> *Tier 4: Deep Audit. Must preserve custom addon handlers*.
  4. **Does it touch standard vanilla gameobjects, vendors, buyback, or quests?**
     -> *Tier 1 or Tier 2 (Agent: AGENT_WORLD_CONTENT)*.
  5. **Does it touch dungeon or raid boss scripts?**
     -> *Tier 1: Fast-Track (Agent: AGENT_AI_SCRIPTS)*.
  6. **Is it a pure engine/memory leak/crash fix?**
     -> *Tier 1: Fast-Track (Agent: AGENT_ENGINE_PLATFORM)*.

---

### Stage 3: Branching & Alignment
- **Objective**: Create a clean, isolated topic branch for the backport.
- **Runbook**:
  ```powershell
  cd "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow"
  git checkout main
  git pull origin main
  git checkout -b port/vmangos-<short_sha>-<topic_name>
  ```
- Example:
  `git checkout -b port/vmangos-c782680-buyback-fix`

---

### Stage 4: Semantic Porting & Code Adaptation
- **Objective**: Adapt and apply the fix to the target codebase without copy-pasting incompatible assumptions.
- **Runbook**:
  1. View the exact diff from VMaNGOS:
     ```powershell
     git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core" show <commit_hash>
     ```
  2. Locate the corresponding target file and function in `tortoise-wow`.
     *(Note: Due to code divergence, search by symbol or method name rather than relying on line numbers).*
  3. Apply the fix following the recipes in `ENGINEERING_HANDBOOK.md`.
  4. If the fix touches database records:
     a. Primary / Authoritative: Compare against Turtle base catalog in `tortoise-wow/sql/base/`.
     b. Choice 1 (Main Historic DB): Use Brotalnia `brotalnia/database` (`reference-upstreams/lights-hope-database-history/world_full_14_june_2021.sql` from `world_full_14_june_2021.7z`) for original vanilla baseline values unchanged by Turtle WoW.
     c. Choice 2 (Backup Updated Donor DB): Fall back to `vmangos/core db_latest` (`mangos.sql`) if modern columns, EventAI, or newer vanilla fixes are involved.
     d. Interactive Scalper & Dashboard: Use `task scalp [type] <id> -Diff` and `task dashboard <id>` (powered by `tortoise-db-viewer` REST API and web UI) to inspect live client tooltips and 3D models.
     e. Export sanitized `REPLACE INTO` migrations via `task scalp [type] <id> -ExportSql`, stripping progressive columns (`patch`, `build`), removing stored procedures, and protecting IDs >= 300000.
     f. Move finalized SQL to `tortoise-wow/sql/database_updates/world/` and audit via `Audit-DatabaseMigrations.ps1`.

---

### Stage 5: QA, Linting & Verification
- **Objective**: Validate code correctness, database schema compatibility, and Turtle preservation invariants.
- **Runbook**:
  1. Run the automated compatibility scanner:
     ```powershell
     cd "C:\Users\Admin\AntigravityProfiles\Projects\twow project"
     .\tools\porting\Verify-TurtleCompatibility.ps1 -TargetRepo "tortoise-wow"
     ```
  2. Run the automated database migration auditor:
     ```powershell
     cd "C:\Users\Admin\AntigravityProfiles\Projects\twow project"
     .\tools\porting\Audit-DatabaseMigrations.ps1
     ```
     Ensure all migrations pass with 0 errors, 0 warnings, 0 progressive column leaks, and 0 custom entity clobbers.
  3. Verify diff scope:
     ```powershell
     git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" diff
     ```
     Ensure no unintended edits, commented-out dead code, or unrelated formatting churn were introduced.
  4. Ensure headers, includes, and C++17 syntax are clean.
  5. **Forum Regression Audit**:
     ```powershell
     .\tools\porting\Search-ForumArchive.ps1 -Query "<spell_or_quest_or_npc>" -Category Bugs
     ```
     Ensure that applying this fix does not reintroduce any edge-case bug previously reported and resolved on Turtle-WoW.

---

### Stage 6: Commit, Push & Audit Log Update
- **Objective**: Record and publish the backport with full upstream attribution.
- **Runbook**:
  1. Update documentation immediately in the same logical unit of work:
     - Record the entry in [`twow project/docs/BACKPORT_HISTORY.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/BACKPORT_HISTORY.md).
     - Update [`twow project/docs/COMMITS_UPLOADED.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMITS_UPLOADED.md).
     - Update [`twow project/docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md) status to `PORTED`.
  2. Commit changes using the standardized format:
     ```powershell
     git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" add <affected_files>
     git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" commit -m "Port(Subsystem): <Summary>

     Donor: VMaNGOS <full_sha>
     Turtle base: Penqle <sha>
     Compatibility: DIRECT / ADAPTED
     Ledger: COMPAT-xxx (if applicable)

     Preserved Turtle:
     - <important invariant preserved>

     Adapted donor:
     - <foreign assumption adapted>"
     ```
  3. Commit candidate changes to dedicated candidate branch: `port/PORT-XXXX-<sha>` inside isolated worktree.
  4. **Remote Push Authorization**:
     - Fixes remain on candidate branches.
     - Never push directly to `origin/main` or `extended/main` without explicit user authorization in the current session.
  5. Cleanly prune worktree via `Remove-IsolatedWorktree`. Working tree remains pristine. Only after this candidate is committed to its branch and state store is updated may the next candidate begin.

---

## 2. Conflict Resolution Playbooks

### Scenario A: Heavily Diverged Code
- **Problem**: The target function in Tortoise-WoW has been rewritten or substantially altered compared to VMaNGOS.
- **Action**:
  1. Identify the *underlying bug condition* being solved in VMaNGOS (e.g. integer overflow, off-by-one, null pointer dereference, invalid state transition).
  2. Examine if the rewrite in Tortoise-WoW already resolved the condition or introduced a different handling path.
  3. If still vulnerable, implement the equivalent logical check tailored to the new Tortoise-WoW architecture.
  4. Document the architectural difference in the commit description.

### Scenario B: Turtle WoW Custom Class/Spell Overrides
- **Problem**: VMaNGOS modifies a spell mechanic in `SpellEffects.cpp` or `SpellAuras.cpp` that conflicts with a custom Turtle WoW spell modification (e.g. Turtle Paladin Holy Strike, Druid preservation talents).
- **Action**:
  1. Query the forum archive for design documents and patch notes:
     ```powershell
     .\tools\porting\Search-ForumArchive.ps1 -Query "<spell_name>" -Category Spells
     ```
  2. Check `src/scripts/spells/spells_turtle.cpp` and `src/game/Spells/` for Turtle spell overrides.
  3. If the upstream fix applies to standard vanilla spells, apply it guarded by spell ID checks, ensuring custom Turtle spell IDs (>40000) retain their custom logic.
  4. Never overwrite custom spell behavior with vanilla spell behavior if Turtle intentionally altered it for class balance.

### Scenario C: Database Primary Key Collision & Schema Mismatches
- **Problem**: An upstream migration inserts a new row with an ID that collides with a custom Turtle WoW entity, or references a column that does not exist in the Nostalrius schema, or is missing a column required by the C++ engine.
- **Action**:
  1. Check target tables in `twow project/tortoise-wow/sql/base/` and `sql/create_databases.sql`.
  2. Run differential extraction via `task scalp [type] <id> -Diff` against Brotalnia `world_full_14_june_2021.sql` (Main Historic DB for original vanilla baseline), `vmangos/core db_latest` (`mangos.sql`, Backup DB), and `tortoise-db-viewer`.
  3. Verify against official 1.18.1 client data using `task 6 <id>` or `task dashboard <id>` (`https://xian55.github.io/tortoise-db-viewer/`).
  4. If progressive columns (`` `patch` ``, `` `build` ``) are present, strip them using `-ExportSql`.
  5. If an entry ID is $\ge 300000$ and collides with custom Turtle content, re-map the ID into vanilla space (< 300000) or isolate the insertion.
  6. If the C++ engine queries a column that is absent from base SQL (e.g. `spell_template.script_name`), add the column to the base definition and provide an idempotent `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` migration.
  7. Run `.\tools\porting\Audit-DatabaseMigrations.ps1` to confirm zero violations.

---

## 3. Emergency Rollback & Quarantine Protocol

If a newly backported change introduces crashes, memory corruptions, or client desyncs:
1. **Revert Immediately**:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" revert <commit_hash> -m "Revert: Port(<Subsystem>) due to regression <issue_description>"
   ```
2. **Flag in Roadmap**:
   Update [`twow project/docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md) status to `QUARANTINED`.
3. **Open Investigation**:
   File an issue describing the exact reproduction steps, crash dump, or client desync packet log.
