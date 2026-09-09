# AGENTS.md: Autonomous Agent Operating Protocol for Tortoise-WoW Extended

This document establishes the binding architectural principles, agent operational guidelines, verification gates, and upstream backporting rules for AI agents and developers working on **Tortoise-WoW Extended** (`Ildourol/tortoise-wow-extended`).

---

## 1. Fresh Inception & Repository Purity Invariant

> [!IMPORTANT]
> **REPOSITORY PURITY & LOCAL-ONLY DOCUMENTATION POLICY**
> - **The Git repository (`tortoise-wow`) and remote branch (`extended/main`) must contain ONLY actual code fixes, SQL migrations, and toolchain configurations.**
> - **NO DOCUMENTATION IN THE REPOSITORY**: Never commit markdown documentation files, guides, or `docs/` directories into `tortoise-wow`.
> - **All instructions, candidate queues, workflows, and ledgers are maintained STRICTLY LOCALLY** in the parent workspace directory:
>   - [`twow project/MULTI_AGENT_WORKFLOW.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/MULTI_AGENT_WORKFLOW.md)
>   - [`twow project/docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md)
>   - [`twow project/docs/commits/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/commits/) (Individual per-commit dossiers)
>   - [`twow project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv)
>   - [`twow project/tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv)
>   - [`twow project/tools/tasks/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/tasks/)
>   - [`twow project/AGENTS.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/AGENTS.md)
>   - [`twow project/README.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/README.md)
>   - [`twow project/PORTING_PLAN.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/PORTING_PLAN.md)
>   - [`twow project/ENGINEERING_HANDBOOK.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/ENGINEERING_HANDBOOK.md)
>   - [`twow project/ORCHESTRATION_WORKFLOW.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/ORCHESTRATION_WORKFLOW.md)
>   - [`twow project/docs/BACKPORT_HISTORY.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/BACKPORT_HISTORY.md)
>   - [`twow project/docs/COMMITS_UPLOADED.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMITS_UPLOADED.md)
>   - [`twow project/docs/BACKPORT_WORKFLOW.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/BACKPORT_WORKFLOW.md)
>   - [`twow project/docs/UPSTREAM_COMPATIBILITY_LEDGER.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/UPSTREAM_COMPATIBILITY_LEDGER.md)
>   - [`twow project/docs/UPSTREAM_REFERENCE_SOURCES.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/UPSTREAM_REFERENCE_SOURCES.md)
>   - [`twow project/docs/DELETED_CODE_AND_DELTA_AUDIT.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/DELETED_CODE_AND_DELTA_AUDIT.md)
>   - [`twow project/docs/CONFLICT_PREVENTION_AND_RESOLUTION_MATRIX.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/CONFLICT_PREVENTION_AND_RESOLUTION_MATRIX.md)
>   - [`twow project/docs/PORTING_TROUBLESHOOTING_AND_SAFEGUARDS.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/PORTING_TROUBLESHOOTING_AND_SAFEGUARDS.md)
> - **Zero bloat in Git history**: Every commit on GitHub must be an attributable technical fix or VMaNGOS donor backport.

---

## 2. Core Operational Rules

### 2.1. Strict Commit-by-Commit Backporting
The project operates under a strict single-commit backporting model. Batched commits, grouped PRs, and bulk cherry-picks are strictly prohibited:

```
1 BUG DIAGNOSIS
    --> 1 DONOR COMMIT
    --> 1 INVESTIGATION
    --> 1 TURTLE-NATIVE ADAPTATION
    --> 1 VERIFICATION CYCLE (MSVC 2022 build: 0 errors)
    --> 1 ATOMIC GIT COMMIT (Code/SQL only)
    --> 1 REMOTE PUSH
    --> 1 MANDATORY PROGRESS HISTORY UPDATE (COMMITS_UPLOADED, BACKPORT_HISTORY, docs/commits/, ROADMAP.md)
    --> NEXT FIX
```

Every donor backport must be handled individually:
1. **Never port multiple donor commits together.**
2. **Never begin a new donor commit until the previous commit is completely verified, documented locally, committed, and pushed.**
3. **Never create generic commits** (e.g. "Misc fixes", "Batch fixes", "VMaNGOS updates").
4. **Stage ONLY code files (`src/`, `sql/`, `CMakeLists.txt`)**: Never stage or commit markdown documentation files to git.
5. **Mandatory Progress History Update After EACH Commit**: Immediately upon pushing to git, all 4 progress history files (`docs/COMMITS_UPLOADED.md`, `docs/BACKPORT_HISTORY.md`, `docs/commits/PORT-XXXX_<sha>.md`, and `docs/ROADMAP.md`) MUST be updated so the user has an unbroken chronological history of project progress. Never leave history updates pending or batched.

### 2.2. Authority & Hierarchy
1. **Turtle WoW (`Penqle/tortoise-wow`) is Authoritative**:
   - Owns all identifiers, enum values, database schemas, and custom mechanics.
   - If a conflict arises between donor code and Turtle WoW, **Turtle WoW always wins**.
   - Never renumber or overwrite Turtle identifiers to accommodate donor code.
2. **Prove the Bug Exists First**:
   - Do not assume Turtle WoW has a bug just because an upstream repo fixed it.
   - Always verify that the bug is present in Turtle WoW source or database before proposing a port.
3. **Accept "DO NOT PORT" as a Legitimate Result**:
   - If Turtle already fixed it, if Turtle's architecture differs intentionally, or if the fix applies to features Turtle does not use, document as `DO NOT PORT` in local docs and do not apply.

### 2.3. AI Semantic Engine & Multi-Agent Architecture
The porting toolchain defaults to the **AI Semantic Context Engine**, pairing automated contextual code assembly with human/AI paired engineering:
- **Unified AI Porting (`task port <sha>`, `task port-batch <N>`)**: Automatically runs the AI Semantic Context Assembler, mining forum lore, target source files, surrounding lines, and staging as `READY_FOR_BUILD` (or `AWAITING_AI_ADAPTATION` for context divergences like `inGurubashiArena`).
- **Autonomous Build Gate (`task port <sha> -AutoBuild`)**: Runs the AI porting checks, verifies clean application, and automatically invokes the single-writer compile and push gate.
- **Agent 1 (`task 1`)**: Builder & Committer (Single-writer MSVC compilation & git push gate).
- **Agent 2 (`task 2`)**: Forum Scout & Bug Prover (Searches 22k forum threads, validates divergence).
- **Agent 3 (`task 3`, `task scalp`, `task extract`, `task 3-dbc`, `task 3-sentinel`)**: Database Engineer, Entity Scalper, DBC Auditor & Upstream Sentinel (Scalps items/NPCs/spells from monolithic historical databases, sanitizes progressive columns, and generates clean SQL).
- **Agent 4 (`task ai-audit <sha>`, alias: `task 4 <sha>`)**: AI Semantic Context Assembler (Assembles target files, surrounding context, forum lore, and outputs AI dossiers in `tools/queue/ai_dossiers/`).
- **Agent 5 (`task restore <topic>`, `task restore-batch <N>`, alias: `task 5`)**: Core Restorer & Patch Parity Auditor (Logs to `docs/CORE_RESTORATION_LEDGER.md` with zero double-checking).
- **Agent 6 (`task 6 <id/query>`, alias: `task db-viewer`)**: Online Database Oracle (Verifies entities against `https://xian55.github.io/tortoise-db-viewer/` and live CDN changelogs).
- **Documentation (`task pdf`)**: Exports `docs/COMMAND_REFERENCE.html` and `docs/COMMAND_REFERENCE.pdf` via headless Microsoft Edge.

**Unified Audited Mining & Deduplication Architecture**:
1. **Crucial Action Queue ([`tools/porting/CRUCIAL_COMMITS_QUEUE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv))**: Mined and deduplicated across the **entire 7,339 upstream commit history of VMaNGOS (2017–2026)**. Older superseded bugfixes are automatically eliminated (eliminating duplicate fixes so no bug is fixed twice), organizing the **5,092 crucial candidates** into 5 strict severity tiers:
   - **Tier 1**: Server Crashes, Memory Leaks & Security Vulnerabilities (395 commits)
   - **Tier 2**: Combat Mechanics, Retail Formulas, Spells & World State (1,304 commits)
   - **Tier 3**: Bounds Checks, Duplication Exploits & Packet Guards (80 commits)
   - **Tier 4**: Pet, AI, Movement & Spline Pathing (974 commits)
   - **Tier 5**: Quests, Dungeons, Raids, Events & World Content (2,339 commits)
2. **Complete Reference Catalogue ([`tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv))**: Full catalogue of all 7,339 upstream commits with status (`PORTED` / `PENDING`), crucial classification (`YES` / `NO`), subsystem category, and metadata.
3. **Automated Upstream Scanning & Maintenance ([`tools/porting/Build-CrucialRoadmap.ps1`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/Build-CrucialRoadmap.ps1))**: Run with `-FetchLatest` to pull and fast-forward new commits from upstream VMaNGOS, re-audit them, eliminate duplicates, and update both CSV files and [`docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md) automatically.

---

## 3. Mandatory Safety & Compatibility Invariants

All agents must strictly verify the following invariants before any code change is accepted:

1. **`MAX_RACES = 11`**:
   - Turtle WoW natively supports Goblins (`9`) and High Elves (`10`).
   - Never decrease race array dimensions or loop bounds to 10.
2. **Script Commands (`SCRIPT_COMMAND_TAKE_MONEY = 93`)**:
   - Enum ID 93 is reserved in Turtle for `SCRIPT_COMMAND_TAKE_MONEY`.
   - Donor script command `SCRIPT_COMMAND_FOLLOW_ESCORT` must be adapted to the next available unallocated ID (>93).
3. **Dynamic Debuff Limit (`sTWDebuff`)**:
   - Turtle WoW uses dynamic debuff tracking via `sTWDebuff`. Never revert aura handling to static 16 debuff limits.
4. **Custom Content ID Space**:
   - Spells >= 40000 and World entities >= 300000 are reserved for Turtle custom content.
   - Never place donor entities or scripts into custom ID spaces without explicit mapping.
5. **Progressive Database Columns**:
   - VMaNGOS columns like `patch` and `build` do not exist in Turtle. Always strip them from ported SQL migrations.

---

## 4. Verification & QA Protocol

1. **Clean Compilation**:
   - Target build: MSVC 2022 x64 (`vcvars64.bat`), CMake toolchain with vcpkg.
   - Must achieve 0 compiler errors and 0 linker errors on both `realmd` and `mangosd`.
2. **Failure Protocol**:
   - If a build error occurs, remain on that commit. Do not proceed to another donor commit.
   - Fix only the error introduced by the port.
   - If an unresolvable blocker is found, revert the changes, document locally, and quarantine the candidate.
3. **Runtime Verification**:
   - Do not claim gameplay success based only on compilation.
   - Record `runtime verification pending` if live server testing was not performed.

---

## 5. Structured Plan of Documenting Our Work & Synchronized Tracking

> [!IMPORTANT]
> **MANDATORY PROGRESS HISTORY POLICY: UPDATE AFTER EVERY COMMIT**
> After **EVERY SINGLE COMMIT**, all progress history files MUST be immediately updated.
> No commit is considered complete, and NO agent may ever begin the next commit, until all 4 history files are synchronized:
> 1. **[`docs/COMMITS_UPLOADED.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMITS_UPLOADED.md)**: Append sequential table row with SHA, donor link, and verification status.
> 2. **[`docs/BACKPORT_HISTORY.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/BACKPORT_HISTORY.md)**: Append deep technical provenance section with root cause, diff summary, and invariants.
> 3. **[`docs/commits/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/commits/)**: Create individual commit dossier `PORT-XXXX_<sha>.md` and update index.
> 4. **[`docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md)**: Increment uploaded count, update current HEAD SHA, and advance unported tiers.
>
> This guarantees the operator always has an unbroken, transparent record of project progress.

### 5.1. The 6-Agent Unified Engineering Lifecycle

```
[Phase 1: Triage & Lore]     --> Agent 2 (task 2) mines 22k forum threads & creates 01_candidates/<sha>.json
                                 Agent 6 (task 6) queries online DB viewer (https://xian55.github.io/tortoise-db-viewer/)
[Phase 2: Entity Extraction] --> Agent 3 (task scalp / task extract) scalps items/NPCs/spells from Brotalnia DB
                                 Stages sanitized SQL in tools/queue/staging_sql/
[Phase 3: Context & Restor.] --> Agent 4 (task ai-audit / task 4) outputs ai_dossiers/<sha>.md & staging_patches/
                                 Agent 5 (task restore / task restore-batch) restores native Turtle specs
                                 Manifest staged in tools/queue/02_ready_to_build/ (PORT-XXXX.json / CORE-XXXX.json)
[Phase 4: Build & Push Gate] --> Agent 1 (task 1) executes single-writer MSVC 2022 compile gate (Exit Code 0),
                                 commits code/SQL to git, pushes to extended/main
[Phase 5: Documentation]     --> Mandatory 5-step local documentation gate BEFORE picking next fix:
                                   1. Update docs/COMMITS_UPLOADED.md
                                   2. Update docs/BACKPORT_HISTORY.md (or CORE_RESTORATION_LEDGER.md)
                                   3. Update docs/commits/ dossier & README index
                                   4. Update docs/ROADMAP.md metrics & HEAD SHA
                                   5. Advance queue manifest to tools/queue/03_completed/
```

#### Step 1: Update the Uploaded Commits Ledger (`docs/COMMITS_UPLOADED.md`)
Immediately append a new row to the table in [`docs/COMMITS_UPLOADED.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMITS_UPLOADED.md):
- `#`: Sequential upload number (e.g. `2`).
- `Commit SHA`: Clickable link to commit on GitHub: `[`<short_sha>`](https://github.com/Ildourol/tortoise-wow-extended/commit/<short_sha>)`.
- `ID`: Sequential ID (e.g. `PORT-0001`).
- `Subsystem`: Affected subsystem (e.g. `Spells`, `Combat`, `Dungeons`).
- `Commit Subject`: Full commit subject.
- `Upstream Donor`: Donor commit reference (e.g. `vmangos/core@<donor_sha>`).
- `Additional Files Needed?`: E.g. `None (pure C++)` or list of SQL migrations / DBCs.
- `Status`: `Verified`.

#### Step 2: Update Deep Backport Provenance (`docs/BACKPORT_HISTORY.md`)
Append a structured section to [`docs/BACKPORT_HISTORY.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/BACKPORT_HISTORY.md):
```markdown
### PORT-XXXX — <Commit Subject>
- **Date**: YYYY-MM-DD
- **Commit SHA**: `<short_sha>`
- **Donor Upstream**: vmangos/core@`<full_or_short_donor_sha>`
- **Subsystem**: <Subsystem>
- **Files Modified**: `<file_1>`, `<file_2>`
- **Summary**: <Detailed explanation of defect, root cause, and how Turtle invariants (MAX_RACES=11, sTWDebuff, etc.) were respected>.
```

#### Step 3: Update the Commits Dossier Folder (`docs/commits/`)
Every ported commit must have its own isolated, structured technical dossier in the dedicated commits archive:
- Create file: [`docs/commits/PORT-XXXX_<short_sha>.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/commits/):
  - **Overview Table**: ID, commit SHA, full SHA, subject, subsystem, author, date, donor link, build verdict, and additional artifacts.
  - **Rationale & Defect Description**: Why the bug existed, how it was diagnosed, and why it applies to Turtle WoW.
  - **Files Modified**: List of modified files with git diffstat.
  - **Turtle Invariants & Safety Verification**: Explicit verification of `MAX_RACES = 11`, `sTWDebuff`, Script ID 93, and zero repository git bloat.
- Re-sync and update the index: Run [`tools/porting/Generate-CommitDossiers.ps1`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/Generate-CommitDossiers.ps1) to automatically update [`docs/commits/README.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/commits/README.md).

#### Step 4: Update the Master Roadmap (`docs/ROADMAP.md`)
Update [`docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md):
- Increment **Total Uploaded Commits** count (e.g. 1 -> 2).
- Update **Current Head SHA** to the newly pushed commit hash.
- Decrement the **Total Crucial Unported Commits in Queue** count.
- Update Agent 1, 2, 3, and 4 status ledgers under Section 3.

#### Step 5: Advance Staging Queue
- Move the manifest from `tools/queue/02_ready_to_build/PORT-XXXX.json` to `tools/queue/03_completed/`.
- The commit is now fully sealed, documented, and traceable.

---

### 5.2. Upstream Scanning Protocol: Monitoring VMaNGOS Core for New Commits

To ensure **Tortoise-WoW Extended** stays continuously synchronized with upstream VMaNGOS developments:

1. **When to Scan**:
   - At the beginning or end of each porting sprint.
   - Whenever upstream VMaNGOS releases new commits or bugfix PRs on GitHub.
   - On explicit operator command.
2. **Execution Command**:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Build-CrucialRoadmap.ps1" -FetchLatest
   ```
3. **What the Automated Scanner Does**:
   - Connects to the upstream VMaNGOS git remote and advances the local `development` branch via `git merge --ff-only origin/development`.
   - Re-evaluates all commits in `reference-upstreams/vmangos-core` against the current `tortoise-wow` commit history (via donor SHA matching).
   - Audits any newly added upstream commits for crucial keywords (crashes, leaks, exploits, combat formulas, movement, quests).
   - **Automated Deduplication**: Compares newly discovered fixes against known subsystem topics; automatically discards older superseded iterations so no bug is ever fixed twice.
   - Updates [`tools/porting/CRUCIAL_COMMITS_QUEUE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv) with prioritized candidates across the 5 severity tiers.
   - Updates [`tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv) marking newly ported vs. pending commits.
   - Automatically regenerates [`docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md) with updated executive metrics and upcoming candidate tables.

---

## 6. Project Asset & Reference Locations

All core files, code repositories, and reference assets reside at verified local paths:
- **Server Code Repository**: [`twow project/tortoise-wow`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow) (branch `main`, remote `extended/main`)
- **Primary Donor**: [`twow project/reference-upstreams/vmangos-core`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/vmangos-core) (`vmangos/core` development)
- **Historical Core Reference**: [`twow project/reference-upstreams/elysium-core`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/elysium-core) (`lduguid/core` master)
- **Main Historical DB Reference**: [`twow project/reference-upstreams/lights-hope-database-history`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/lights-hope-database-history) (`brotalnia/database` master, `world_full_14_june_2021.sql` uncompressed)
- **Client Data (Physical Folder)**: [`twow project/reference-upstreams/client-data-1.18.1`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/client-data-1.18.1) (158 DBCs, 2,805 maps, 2,133 mmaps, 6,921 vmaps)
- **Forum Intelligence Archive**: [`twow project/resources/forum`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum) (22,155 historical threads)
