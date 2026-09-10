# MULTI_AGENT_WORKFLOW.md: 6-Agent Concurrent Engineering System

This document is the master operational guide for running **6 simultaneous CLI agents** on the **Tortoise-WoW Extended** project without git conflicts, compiler locks, or history regressions.

---

## 1. System Architecture: The 6-Agent Pipeline

The system separates **Concurrent Read-Only Research & Staging (Agents 2, 3, 4, 5, 6)** from **Sequential Single-Writer Execution (Agent 1)** via an asynchronous, zero-lock staging queue:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              READ-ONLY REFERENCE SOURCES                               │
│   • vmangos-core (donor C++ & SQL)          • tortoise-db-viewer (Dashboard & API)     │
│   • client-data-1.18.1 (158 DBCs & Maps)    • resources/forum/ (22,155 threads)        │
│   • tortoise-db-viewer (Online 1.18.1 CDN)  • official Turtle staff changelogs         │
└────────────────────────────────────────────────────────────────────────────────────────┘
        │                 │                 │                 │                 │
        ▼                 ▼                 ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   AGENT 2    │  │   AGENT 3    │  │   AGENT 4    │  │   AGENT 5    │  │   AGENT 6    │
│ Forum Scout  │  │ DB Engineer  │  │ AI Adapter   │  │ Core Restor. │  │ DB Oracle    │
│  & Bug Proof │  │  & Scalper   │  │ & Context    │  │ & Parity Aud.│  │ & 3D Viewer  │
│ Alias: task 2│  │ Alias: task 3│  │ Alias: task 4│  │ Alias: task 5│  │ Alias: task 6│
│- Mined 22k   │  │- Scalp entity│  │- Assemble C++│  │- Turtle patch│  │- Query online│
│  threads     │  │  item/NPC/spl│  │  code context│  │  changelogs  │  │  1.18.1 DB   │
│- Bug triage  │  │- Strip patch │  │- MAX_RACES=11│  │- Check core  │  │- Track live  │
│- DO NOT PORT │  │- Protect IDs │  │- sTWDebuff   │  │  discrepancy │  │  CDN deltas  │
│  divergences │  │  >= 300,000  │  │- AI Dossiers │  │- Zero double-│  │- 3D model    │
│              │  │- Sanitize SQL│  │  in queue/   │  │  check cache │  │  inspection  │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
        │                 │                 │                 │                 │
        └─────────────────┴────────┬────────┴─────────────────┴─────────────────┘
                                   ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               ASYNCHRONOUS STAGING QUEUE                               │
│               twow project/tools/queue/02_ready_to_build/ (PORT-XXXX.json / CORE-XXXX)  │
│               twow project/tools/queue/staging_patches/   (.patch files)               │
│               twow project/tools/queue/staging_sql/       (.sql sanitized migrations)  │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                        AGENT 1                                         │
│                                Builder & Candidate Committer                           │
│                     Invocations: task auto-pilot, task build-packages                  │
│        - Single-writer lock on MSVC 2022 build system & candidate worktree             │
│        - Builds exclusively in isolated worktree: .worktrees/PORT-XXXX/                │
│        - Runs compile & link gate: mangosd.exe & realmd.exe with 0 errors              │
│        - Runs disposable startup smoke test verification                               │
│        - Commits to candidate branch: port/PORT-XXXX-<sha>                             │
│        - Moves package to 03_completed/ and updates canonical state                    │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Directory Map: Where to Find What

| Purpose | Local Absolute Path | Description |
| :--- | :--- | :--- |
| **Project Workspace** | [`twow project/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/) | Parent directory housing all tools, docs, and repositories |
| **Server Git Repository** | [`twow project/tortoise-wow/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/) | Active code repository (Branch: `main`, Remote: `extended`) |
| **Visual Studio Solution** | [`twow project/tortoise-wow/build/TurtleWoW.sln`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/build/TurtleWoW.sln) | MSVC 2022 Solution for x64 Release builds |
| **Compiled Binaries** | [`twow project/tortoise-wow/bin/Release/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/bin/Release/) | Location of `mangosd.exe` and `realmd.exe` |
| **Agent Rulebooks** | [`twow project/tools/tasks/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/tasks/) | Fixed instruction files for Agents 1, 2, 3, and 4 |
| **Staging Queue** | [`twow project/tools/queue/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/queue/) | Asynchronous handoff directories (`ready_to_build/`, etc.) |
| **Master Roadmap** | [`twow project/docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md) | Progress metrics, complete commit list, and upcoming backlog |
| **Commits Dossiers Archive** | [`twow project/docs/commits/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/commits/) | Individual structured dossiers for every backported commit |
| **Crucial Action Queue** | [`twow project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv) | Curated 5-tier deduplicated action queue (5,092 unported bugfixes) |
| **Reference Catalogue** | [`tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv) | Full historical reference catalogue across all 7,339 upstream commits |
| **Backport History** | [`twow project/docs/BACKPORT_HISTORY.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/BACKPORT_HISTORY.md) | Deep provenance history for all ported commits |
| **Uploaded Ledger** | [`twow project/docs/COMMITS_UPLOADED.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMITS_UPLOADED.md) | Remote upload status table |
| **Command Reference** | [`twow project/docs/COMMAND_REFERENCE.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMAND_REFERENCE.md) | Master command reference, executable from any directory |
| **Printable Reference**| [`twow project/docs/COMMAND_REFERENCE.pdf`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMAND_REFERENCE.pdf) | High-quality offline PDF export generated via `task pdf` |
| **Forum Archive** | [`twow project/resources/forum/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum/) | 22,155 historical Turtle-WoW official forum threads |
| **Primary Donor Repo** | [`twow project/reference-upstreams/vmangos-core/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/vmangos-core/) | VMaNGOS source code and database dumps |
| **Historical Reference DB** | [`twow project/reference-upstreams/lights-hope-database-history/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/lights-hope-database-history/) | Brotalnia database history (`world_full_14_june_2021.sql` from `.7z`) for unchanged vanilla items |
| **Database Viewer** | [`twow project/tortoise-db-viewer/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-db-viewer/) | Interactive dashboard, SQLite engine & REST API (`https://xian55.github.io/tortoise-db-viewer/`) |
| **Client DBC/Maps** | [`twow project/reference-upstreams/client-data-1.18.1/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/reference-upstreams/client-data-1.18.1/) | Physical folder with 158 DBCs and map assets |

---

## 3. Agent Aliases & Command Reference

When you open an Antigravity CLI terminal, simply use the shorthand command for that agent (or run via full path from any directory):

### Primary: Unified Auto-Pilot Pipeline (Default Hands-Free)
* **Batch Auto-Pilot**: `task auto-pilot <N> [Tier]` (e.g., `task auto-pilot 10 1`)
* **Single Commit Auto-Port**: `task auto-port <sha>`
* **What it does**: Fully autonomous end-to-end pipeline. Automatically mines forum lore (Task 2), audits database migrations against the schema catalog (Task 3), extracts surrounding context & evaluates invariants via the AI Semantic Engine (Task 4), and immediately compiles under isolated worktree and commits to candidate branch (`task build-packages`).

### Review Mode Pipeline:
* **Command**: `task port <sha>` (or `task port-batch <N>`)
* **What it does**: Stages candidates to `02_ready_to_build/` for review before compiling.
* **Build Staged Packages**: `task build-packages`
* **What it does**: Reads [`tools/tasks/AGENT_1_BUILDER.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/tasks/AGENT_1_BUILDER.md). Takes ready packages from `tools/queue/02_ready_to_build/`, verifies freshness against target base SHA, applies patch & SQL in isolated `.worktrees/candidate-PORT-XXXX/`, compiles via MSVC 2022, runs startup smoke test, commits to candidate branch `port/PORT-XXXX-<sha>`, and records state.

#### CLI 2: Agent 2 (Forum & Bug Scout)
* **Command**: `task 2 <sha or topic>`
  * *Examples*: `task 2 84f1bbccd` or `task 2 "Holy Strike"`
* **What it does**: Reads [`tools/tasks/AGENT_2_FORUM_SCOUT.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/tasks/AGENT_2_FORUM_SCOUT.md). Queries the 22k forum archive to check if Turtle intentionally diverged or if the bug exists, and outputs an evaluation file to `tools/queue/01_candidates/<sha>.json`.

#### CLI 3: Agent 3 (Database Engineer, Entity Scalper & Sentinel)
* **Commands**:
  * `task scalp [table/type] <id/name> [-Diff] [-ExportSql] [-OpenViewer]` — Scalp items, NPCs, or spells: compares Turtle base (Host) against Brotalnia `world_full_14_june_2021.sql` (Main Historic DB) and vmangos `db_latest` (backup), cross-referenced with `tortoise-db-viewer` dashboard/API, strips progressive columns, and generates sanitized SQL.
  * `task extract <table/type> <id/name>` — Scalp entity alias.
  * `task 3 <sha>` — Author and sanitize database migration for donor commit (strips `patch`/`build`, protects custom IDs < 300000, outputs to `staging_sql/`).
  * `task 3-dbc <dbc_name or id>` — Inspect and audit 1.18.1 client DBC tables (`reference-upstreams/client-data-1.18.1/dbc/`).
  * `task 3-sentinel` — Run `Track-UpstreamTortoise.ps1` to detect incoming commits from `Penqle/tortoise-wow` and audit the 14 collision-sensitive files.
* **What it does**: Reads [`tools/tasks/AGENT_3_DB_ENGINEER.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/tasks/AGENT_3_DB_ENGINEER.md). Manages all server SQL, entity scalping, DBC schemas, and collision safeguards.

#### CLI 4: Agent 4 (AI Context Assembler & C++ Semantic Adapter)
* **Command**: `task ai-audit <sha>` (alias: `task 4 <sha>`)
  * *Example*: `task ai-audit 84f1bbccd`
* **What it does**: Runs `Invoke-AiAudit.ps1` to assemble commit diff, target code in `tortoise-wow`, surrounding lines, and forum intelligence into `tools/queue/ai_dossiers/<sha>.md`.

#### CLI 5: Agent 5 (Core Restorer & Patch Parity Auditor)
* **Commands**:
  * `task restore <topic> [-StageTemplate]` (alias: `task 5 <topic>`)
  * `task restore-batch <N>` (or `task restore-batch "Topic1,Topic2"`)
* **What it does**: Reads [`tools/tasks/AGENT_5_CORE_RESTORER.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/tasks/AGENT_5_CORE_RESTORER.md). Audits official staff patch notes, scans codebase/DB for missing features, reports parity, and maintains zero double-checking cache in `restoration_history.json` and `docs/CORE_RESTORATION_LEDGER.md`.

#### CLI 6: Agent 6 (Online Database Oracle)
* **Command**: `task 6 <id or name>` (alias: `task db-viewer`)
  * *Examples*: `task 6 19019`, `task 6 changelog`, `task 6 19019 -OpenBrowser`
* **What it does**: Reads [`tools/tasks/AGENT_6_ONLINE_DB_ORACLE.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/tasks/AGENT_6_ONLINE_DB_ORACLE.md). Cross-references local database tables against official Turtle-WoW 1.18.1 online viewer (`https://xian55.github.io/tortoise-db-viewer/`) and live CDN changelogs.

#### CLI Documentation: PDF Generator
* **Command**: `task pdf`
* **What it does**: Runs `Export-CommandReferencePdf.ps1` using headless Microsoft Edge to regenerate `docs/COMMAND_REFERENCE.html` and `docs/COMMAND_REFERENCE.pdf`.

---

## 4. Execution Order: In Which Order to Run Each Task

### Flow 1: Unified AI Upstream Backporting Pipeline (Default)
```
task port <sha>  ──(viable)──►  task build-packages (or run: task auto-port <sha>)
      │
      └──(diverged)──► tools/queue/ai_dossiers/<sha>.md ──► AI adaptation ──► task build-packages
```
1. **Pick Candidate**: Check [`docs/ROADMAP.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/ROADMAP.md) (Section 2) or `CRUCIAL_COMMITS_QUEUE.csv` (e.g. `448df9ba0`).
2. **Execute AI Port**: Type `task port 448df9ba0` (or `task auto-port 448df9ba0`).
   - Runs AI context assembly, forum scouting, SQL sanitization, and patch check.
   - If viable, packages into `tools/queue/02_ready_to_build/PORT-XXXX.json`.
3. **Execute Build Gate**: If not running via auto-pilot, type `task build-packages`.
   - The build engine applies package in `.worktrees/PORT-XXXX/`, runs MSVC 2022 compile gate & smoke test, commits to candidate branch `port/PORT-XXXX-<sha>`, and updates canonical state store.

### Flow 2: Core Specification Restoration Pipeline
```
task restore "<topic>"  ──(discrepancy)──►  -StageTemplate (CORE-XXXX.json)  ──►  task build-packages
```
1. Run `task restore "Holy Strike"` (or `task restore-batch 5`).
2. Instant cache check ensures zero double-checking of already verified topics.
3. If a discrepancy exists and needs C++ implementation, pass `-StageTemplate` to create `CORE-XXXX.json` in `02_ready_to_build/`.
4. Run `task build-packages` to compile and seal the restoration commit.

### Flow 3: Database Entity Scalping & Extraction Pipeline
```
task scalp [type] <id> -Diff  ──►  -ExportSql  ──►  sql/database_updates/world/  ──►  task 3
```
1. **Scalp & Diff**: `task scalp item 19019 -Diff` compares `tortoise-db-viewer` authoritative baseline vs. local Turtle base.
2. **Online Verification**: `task scalp item 19019 -OpenViewer` (or `task 6 19019` / `task dashboard`) cross-references official 1.18.1 client tooltips and 3D models.
3. **Export Sanitized SQL**: Pass `-ExportSql` to generate ready-to-run `REPLACE INTO` SQL with stripped `patch`/`build` columns in `tools/queue/staging_sql/`.

### Flow 4: Granular Multi-Terminal Workflow
```
[ Step 1: Agent 2 ] ──► [ Step 2: Agent 3 & 4 ] ──► [ Step 3: Agent 1 ]
   Triage & Forum           DB & C++ Adaptation          Build, Commit & Push
```

---

## 5. Non-Negotiable Invariants & Safety Rules

1. **Local-Only Documentation**: Never stage or commit any markdown file (`.md`), documentation, or queue file into `tortoise-wow`. The remote git repository contains ONLY code (`src/`), database migrations (`sql/`), and `CMakeLists.txt`.
2. **Single-Writer Lock**: Only **Agent 1** is permitted to run `git commit`, `git push`, or trigger the MSVC compiler on `tortoise-wow`. Agents 2, 3, and 4 must strictly operate in read-only / staging mode.
3. **Zero Errors Compilation Gate**: Both `mangosd.exe` and `realmd.exe` must compile with 0 compiler and 0 linker errors before any commit is pushed.
4. **Preservation Invariants**:
   - `MAX_RACES = 11` (Goblins=9, High Elves=10).
   - Dynamic debuff streaming (`sTWDebuff->AddDebuff()` / `RemoveDebuff()`).
   - Reserved script commands (`SCRIPT_COMMAND_TAKE_MONEY = 93`).
   - Custom parameters (`inGurubashiArena`, `UI64LIT`).
   - ID boundaries: Entity IDs $\ge 300,000$ and spell IDs $\ge 40,000$ are reserved for Turtle custom content.
5. **Concurrency & AutoBuild Mutual Exclusion**: Never run two commands with `-AutoBuild` concurrently in separate terminals. Running multiple simultaneous MSVC builds or `git commit`/`push` operations on `tortoise-wow` causes fatal compiler lock collisions and Git index corruption. You **CAN** run staging tasks (`task restore`, `task restore-batch`, `task port`, `task port-batch`) concurrently without `-AutoBuild`, and then trigger `task build-packages` once to compile and push all ready packages sequentially.
