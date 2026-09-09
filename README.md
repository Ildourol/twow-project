# Turtle-WoW Orchestration & AI Multi-Agent Engineering Framework

This repository houses the **complete autonomous multi-agent engineering framework, porting toolchain, reverse engineering tools, and operational methodology** for **Tortoise-WoW Extended** (targeting Turtle-WoW 1.18.1, Build 7272).

To maintain repository purity and zero Git bloat, **server code, compiled binaries, heavy reference dumps, and raw forum archives are tracked in separate dedicated repositories**. This repository contains the orchestration engine, CLI dispatcher, AI context assemblers, database scalpers, safety invariant checkers, and full technical documentation ledgers.

---

## 1. External Component Architecture & Setup Mini-Guide

To achieve full operational parity locally, the toolchain interfaces with several modular external assets. Clone or link each asset into its designated folder within this project root:

```text
twow project/
├── .gitignore
├── AGENTS.md
├── MULTI_AGENT_WORKFLOW.md
├── ENGINEERING_HANDBOOK.md
├── ORCHESTRATION_WORKFLOW.md
├── PORTING_PLAN.md
├── README.md
├── docs/                                  [Master documentation, ledgers & PDF reference]
├── tools/                                 [Unified task.ps1 CLI, agent task rulebooks & scripts]
│
├── tortoise-wow/                          [LOCAL CLONE: Server source code repository]
├── resources/
│   ├── FORUM_RESOURCE_GUIDE.md
│   └── forum/                             [LOCAL CLONE: 22,155 archived forum threads]
└── reference-upstreams/                   [LOCAL CLONE: Upstream donors & client assets]
    ├── vmangos-core/                      [LOCAL CLONE: VMaNGOS donor C++ & SQL]
    ├── client-data-1.18.1/                [LOCAL CLONE: 158 DBCs, maps, vmaps, mmaps]
    ├── lights-hope-database-history/      [LOCAL CLONE: Brotalnia historical world DB]
    └── elysium-core/                      [LOCAL CLONE: Nostalrius/Elysium reference core]
```

### Companion Repositories & Download Sources

| Component | Target Local Path | Repository URL / Upstream Source | Description |
| :--- | :--- | :--- | :--- |
| **Server Code Repository** | `tortoise-wow/` | [`Ildourol/tortoise-wow-extended`](https://github.com/Ildourol/tortoise-wow-extended) | Active Turtle-WoW 1.18.1 C++ source tree (branch `main`). |
| **Forum Intelligence Archive** | `resources/forum/` | [`Ildourol/turtle-wow-forum-archive`](https://github.com/Ildourol/turtle-wow-forum-archive) | 22,155 historical official forum threads (2018–2026). |
| **Client Assets (1.18.1)** | `reference-upstreams/client-data-1.18.1/` | [`Ildourol/Twow_data-1.18.1`](https://github.com/Ildourol/Twow_data-1.18.1) | 158 DBCs, 2,805 maps, 2,133 mmaps, 6,921 vmaps. |
| **Historical World Database** | `reference-upstreams/lights-hope-database-history/` | [`Ildourol/database`](https://github.com/Ildourol/database) | Authoritative Brotalnia vanilla DB (`world_full_14_june_2021.sql`). |
| **Primary Donor Core** | `reference-upstreams/vmangos-core/` | [`vmangos/core`](https://github.com/vmangos/core) | Upstream vanilla 1.12.1 emulator (development branch). |
| **Historical Core Reference** | `reference-upstreams/elysium-core/` | [`lduguid/core`](https://github.com/lduguid/core) | Historical Nostalrius/Elysium core reference. |

### Quick Setup Commands (PowerShell)
To clone and connect all companion assets in one step:
```powershell
# 1. Clone server core repository
git clone https://github.com/Ildourol/tortoise-wow-extended.git tortoise-wow

# 2. Clone forum intelligence archive
git clone https://github.com/Ildourol/turtle-wow-forum-archive.git resources/forum

# 3. Create reference upstreams directory
New-Item -ItemType Directory -Path "reference-upstreams" -Force | Out-Null

# 4. Clone donor and reference repositories
git clone https://github.com/vmangos/core.git reference-upstreams/vmangos-core
git clone https://github.com/Ildourol/Twow_data-1.18.1.git reference-upstreams/client-data-1.18.1
git clone https://github.com/Ildourol/database.git reference-upstreams/lights-hope-database-history
git clone https://github.com/lduguid/core.git reference-upstreams/elysium-core
```

---

## 2. The 6-Agent Concurrent Pipeline Architecture

The framework separates **Concurrent Read-Only Research & Staging** from **Sequential Single-Writer Execution**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              READ-ONLY REFERENCE SOURCES                               │
│   • vmangos-core (donor C++ & SQL)          • lights-hope-database-history (Brotalnia) │
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
│                                Builder & Git Committer                                 │
│                                     Alias: task 1                                      │
│        - Single-writer lock on tortoise-wow/ and MSVC 2022 build system                │
│        - Applies .patch and .sql migration                                             │
│        - Runs compile gate: mangosd.exe & realmd.exe with 0 errors                     │
│        - Atomic git commit & immediate remote push to extended main                    │
│        - Moves package to 03_completed/ and updates ledgers                            │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Master Command Reference (`tools/task.ps1`)

Run any task directly from any directory without needing to `cd`:

```powershell
# 1. Pipeline Status & Metrics
& "...\tools\task.ps1" status

# 2. Unified AI Upstream Backport (Audit -> Adapt -> Stage)
& "...\tools\task.ps1" port 84f1bbccd

# 3. Autonomous End-to-End Backport (Audit -> Adapt -> Compile -> Commit -> Push)
& "...\tools\task.ps1" port 84f1bbccd -AutoBuild

# 4. Batch Autonomous Porting (Next 10 crucial commits)
& "...\tools\task.ps1" port-batch 10 -AutoBuild

# 5. Database Entity Scalper & Differential Analysis (Items, NPCs, Spells)
& "...\tools\task.ps1" scalp item 19019 -Diff

# 6. Export Sanitized SQL Migration (Strips patch/build columns)
& "...\tools\task.ps1" scalp item 19019 -ExportSql

# 7. Online Database Oracle & 3D Interactive Viewer
& "...\tools\task.ps1" 6 19019 -OpenBrowser

# 8. Track Live Official CDN Database Deltas
& "...\tools\task.ps1" 6 changelog

# 9. Native Turtle Core Feature Restorer (Zero double-checking cache)
& "...\tools\task.ps1" restore "Holy Strike" -StageTemplate

# 10. Single-Writer Build & Commit Gate
& "...\tools\task.ps1" 1

# 11. Regenerate Printable Master PDF Guide
& "...\tools\task.ps1" pdf
```

---

## 4. Documentation Index

Detailed engineering documentation is maintained in `docs/`:

0. **[`docs/COMMAND_REFERENCE.md`](docs/COMMAND_REFERENCE.md)** — Master CLI reference with Goal-Oriented Decision Matrix. Also available as printable PDF: **[`docs/COMMAND_REFERENCE.pdf`](docs/COMMAND_REFERENCE.pdf)**.
1. **[`MULTI_AGENT_WORKFLOW.md`](MULTI_AGENT_WORKFLOW.md)** — 6-Agent Concurrent Engineering System operational guide.
2. **[`docs/ROADMAP.md`](docs/ROADMAP.md)** — Master roadmap & live ledger across 5,092 deduplicated crucial candidates.
3. **[`docs/commits/`](docs/commits/)** — Individual commit dossiers archive.
4. **[`tools/porting/CRUCIAL_COMMITS_QUEUE.csv`](tools/porting/CRUCIAL_COMMITS_QUEUE.csv)** — 5-tier deduplicated crucial candidate queue.
5. **[`tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv`](tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv)** — Reference archive across all 7,339 upstream commits.
6. **[`AGENTS.md`](AGENTS.md)** — Autonomous agent operating protocol, invariants, and local documentation rules.
7. **[`docs/BACKPORT_WORKFLOW.md`](docs/BACKPORT_WORKFLOW.md)** — 6-Phase commit-by-commit engineering runbook.
8. **[`docs/BACKPORT_HISTORY.md`](docs/BACKPORT_HISTORY.md)** — Deep provenance history for all ported commits.
9. **[`docs/UPSTREAM_COMPATIBILITY_LEDGER.md`](docs/UPSTREAM_COMPATIBILITY_LEDGER.md)** — Compatibility invariants (`MAX_RACES = 11`, `sTWDebuff`, `UI64LIT`, custom IDs).
10. **[`docs/UPSTREAM_REFERENCE_SOURCES.md`](docs/UPSTREAM_REFERENCE_SOURCES.md)** — Authority hierarchy and upstream source inventory.
11. **[`ENGINEERING_HANDBOOK.md`](ENGINEERING_HANDBOOK.md)** — Technical handbook, safety danger zones, and concrete porting recipes.
12. **[`docs/CORE_RESTORATION_LEDGER.md`](docs/CORE_RESTORATION_LEDGER.md)** — Parity audit ledger for Turtle custom specifications.
13. **[`docs/PORTING_TROUBLESHOOTING_AND_SAFEGUARDS.md`](docs/PORTING_TROUBLESHOOTING_AND_SAFEGUARDS.md)** — Toolchain, database scalping, and crash troubleshooting playbooks.
