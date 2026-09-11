# AGENTS.md: Autonomous Operating Protocol for Module-playerbots

## Project skill and interpretation

For donor adaptation or native implementation, read [.agents/skills/turtle-playerbots-porting/SKILL.md](.agents/skills/turtle-playerbots-porting/SKILL.md). Use [the documentation map](docs/DOCUMENTATION_MAP.md) to select supporting references.

Current source signatures and actual command implementations take precedence over dated API examples and performance claims. Fast/batch verification means deferred checks remain pending: a module compile is not executable link, startup, or gameplay evidence. Preserve existing one-donor/one-commit policy and authorized execution modes. Reading instructions or editing documentation does not invoke publishing workflows.

ADR-009 execution modes qualify the older per-commit full-link wording below and in the porting/build guides. Record the selected mode and exact SHA tested; do not mark deferred link checks complete.

This document establishes the binding architectural principles, authority order, agent operational roles, verification gates, and porting policies for AI agents operating on **Module-playerbots**.

---

## 1. Authority Hierarchy

When conflicting technical information or implementation patterns arise, agents must strictly follow the nine-tier authority hierarchy:

1. **Tier 1: Explicit Current User Requirement** - Direct commands, constraints, or instructions provided by the user in the current session.
2. **Tier 2: Target Checked-Out Source** (`tortoise-wow-extended`) - Real code, CMakeLists, and runtime evidence in the target repository.
3. **Tier 3: Target Repository AGENTS.md & Engineering Policies** (`tortoise-wow-extended/AGENTS.md`) - Core-preservation requirements and native change contracts.
4. **Tier 4: Target CMakeCache / Build / Runtime Evidence** (`tortoise-wow-extended/build/CMakeCache.txt`).
5. **Tier 5: Target Same-Revision Documentation & Call Sites** (`CORE_SYSTEMS_GUIDE.md`, declarations, real callers).
6. **Tier 6: The Exact Upstream Commit Being Evaluated** - Specific donor commit diff, author intent, and commit metadata.
7. **Tier 7: Current Source Repositories** (`playerbots`, `core`).
8. **Tier 8: Public Documentation of the Same Lineage** - MaNGOS, CMaNGOS, and vMaNGOS historical references.
9. **Tier 9: Copied / Adapted Project-Management Methodology**.

---

## 2. Fundamental Safety & Operational Rules

### 2.1. Absolute Project Isolation
- This project operates in **complete isolation**.
- No cross-project links, shared runtime files, shared databases, or cross-workspace dependencies are permitted. Existing root donor junctions are local compatibility aliases into this project; use canonical reference-upstreams paths and verify resolved paths remain inside this project.
- All persistent configuration resides within `Module-playerbots/`.

### 2.2. Single-Writer & Worktree Safety
- Only one agent or task may modify target files at any given time.
- The working tree must be kept clean. Never run destructive reset commands (`git reset --hard`, `git clean -fd`) against a tree containing uncommitted user changes.
- If isolated experimentation is needed, use dedicated Git worktrees.

### 2.3. Repository Targets & Commit Safety
- **Writable Target**: Modifications occur strictly in `tortoise-wow-extended`.
- **Target Integration Branch**: `playerbots`.
- **Read-Only Sources**: `playerbots` and `core` are read-only source repositories. Never commit or push to them.
- **Push Policy**: Pushes to `playerbots` are authorized only after complete Level 3 verification (`mangosd.exe` links cleanly). Force-pushes are strictly forbidden.

### 2.4. Protected Subsystems
- **Dungeon Clear (`modules/mod-dungeon-clear`)**: Protected subsystem. No port may break, bypass, or desync Dungeon Clear value contexts, routes, or encounter states.
- **Turtle WoW 1.18.1 Mechanics**: 10 playable races (IDs 1-10; exclusive bound 11) (`MAX_RACES = 11`), custom entities (spells $\ge 40000$, objects $\ge 300000$), custom debuff streaming (`sTWDebuff`).

### 2.5. Scope Widening Prohibition & Mandatory Double-Confirmation Gate
- **Strict Scope Prohibition**: Widening the scan scope to historical bulk backlogs beyond the established active watermarks is **STRICTLY PROHIBITED**.
- **Double-Confirmation Requirement**: If the user or operator ever requests widening the scan scope or moving watermarks further into historical history, the agent **MUST NOT** execute it immediately. The agent is strictly required to pause, reject automatic execution, explain the risks of scope explosion and regression hazards, and explicitly request a second, separate confirmation ("double ask") before altering watermarks.

### 2.6. Strict Commit-by-Commit Porting & Pushing Workflow (Batch Audit Allowed, Batch Commit Prohibited)
- **Batch Auditing Permitted**: Agents and tasks MAY scan, evaluate, and triage multiple upstream donor commits in batches (up to 50 candidate commits per batch) to maintain high audit efficiency.
- **Batch Commits Strictly Prohibited**: Multiple upstream donor commits must **NEVER** be grouped, combined, or squashed into a single target git commit.
- **1-to-1 Atomic Porting Cycle**: Every single ported commit must execute its own isolated atomic cycle:
  `1 Donor Commit -> 1 Adaptation -> 1 Build Verification (modules.lib + mangosd.exe) -> 1 Atomic Target Git Commit -> 1 Remote Git Push -> 1 Ledger Update`.
- Each commit pushed to `playerbots` must correspond to exactly one upstream donor commit with full individual provenance (source repository, upstream commit SHA, subsystem, priority).
- **No Batch Pushing**: Every individual commit must be pushed immediately to `playerbots` upon passing verification before moving to the next candidate commit.

### 2.7. Absolute Vanilla / Classic Exclusivity Mandate (Strict Prohibition on TBC and WotLK)
- **Strict Vanilla / Classic Target**: This project targets exclusively **Vanilla / Classic WoW** (Classic 1.12.1 / Turtle WoW 1.18.1 Classic+).
- **Absolute Prohibition on TBC & WotLK**: Porting **ANY** mechanics, spells, talents, strategies, items, opcodes, or assumptions from The Burning Crusade (TBC 2.x), Wrath of the Lich King (WotLK 3.x), or any later expansion is **STRICTLY PROHIBITED**.
- **Vanilla-Only Permitted Changes**: Only changes, bugfixes, and enhancements directly relevant to Vanilla / Classic are permitted.
- **Handling Multi-Expansion Upstream Code**: If an upstream commit contains multi-expansion branching (`#if defined(MANGOSBOT_ONE) || defined(MANGOSBOT_TWO)`, `#ifdef TBC`, WotLK checks, etc.):
  1. All non-Vanilla branches, post-Vanilla spells, talents, arenas, flying mounts, and expansion logic must be completely stripped out.
  2. If an upstream fix exists primarily for or relies upon TBC/WotLK mechanics, it is immediately **DISQUALIFIED** with status `EXPANSION_INCOMPATIBLE` and priority `P3`.
### 2.8. Build & Verification Execution Modes & Token Optimizations (ADR-009)
To prevent context token exhaustion and avoid lengthy build wait times (linking `mangosd.exe` takes 2–3 minutes and injects hundreds of lines of linker output into context per turn), agents are authorized to operate under three defined verification modes and five high-efficiency execution optimizations:

#### Five High-Efficiency Execution Optimizations:
1. **Dynamic CPU Parallelism**: Build invocations use `--parallel $env:NUMBER_OF_PROCESSORS` dynamically (utilizing all 12 logical CPU cores on the host machine, providing a 2.5x–3x compilation speedup).
2. **MSBuild Quiet Verbosity (`/nologo /v:q`)**: Suppresses routine `.cpp` progress listings (~150–200 lines). A passing build emits a single status line (`[PASS] modules.lib compiled cleanly in 1.7s (12 cores, quiet)`) consuming 0 prompt tokens. Errors and exact line numbers are printed only on failure.
3. **Automated Single-Turn Port Loop (`task commit-and-push`)**: Compiles with quiet flags, creates atomic git commit, pushes to remote, and registers ledger/dossier in a single automated step. Reduces tool roundtrips from 5 down to 1 per commit.
4. **Automated Ledger & Dossier Helper (`task record-port`)**: Updates `state/porting-ledger.json` and generates the standardized `docs/commits/PORT-XXXX.md` dossier instantly from a template.
5. **Concise Git Operations (`--quiet`)**: Uses `-q` flags during automated git operations to keep context clean.

#### Three Authorized Execution Modes:
1. **Option 1: Fast Incremental Mode (Recommended Default)**:
   - **Per-Commit Verification**: Compile only the module target `modules` via `.\task.ps1 verify-fast` (~1.7 seconds, 1 status line).
   - **Atomic Git Commit & Push**: Commit and push each donor fix individually to `playerbots` via `.\task.ps1 commit-and-push` (preserving ADR-007 1-to-1 provenance).
   - **Milestone Link Check**: Run the full executable linker (`mangosd.exe`) once at the conclusion of the phase or batch via `.\task.ps1 verify-full` to verify global symbol resolution.
   - **Token & Time Savings**: Eliminates ~95% of compiler context bloat and saves 10–15 minutes per batch.

2. **Option 2: Batch Verification Mode (Maximum Token Efficiency)**:
   - **Sequential Atomic Commits**: Apply changes, draft dossiers, and commit to git individually in sequence to preserve git bisectability and 1-to-1 donor tracking.
   - **Deferred Compilation**: Run a single comprehensive compile and link pass (`verify-batch`) at the conclusion of the batch.
   - **Debugging & Error Isolation**: If compilation fails, MSVC compiler output specifies the exact file, line number, and error identifier, helping locate the failing code; interacting commits may require further isolation. For runtime regressions, atomic git commits ensure `git bisect` functions identically to per-commit builds. A passing batch tip does not prove each intermediate commit builds; binary reproducibility requires separate evidence.

3. **Option 3: Strict Full-Link Mode (P0 Maximum Paranoia)**:
   - Recompile `modules.lib` and fully link `mangosd.exe` after every single commit. Recommended only when modifying core engine headers, threading primitives, or global object models.

### 2.9. Reference Upstreams Organization, Synchronization & Ecosystem Links
All upstream donor repositories are organized under `reference-upstreams/` (with root junctions maintained for backwards compatibility):
- `reference-upstreams/core`: Cloned from `https://github.com/ileboii/core.git` (branch `vmangos-ike3-playerbots`). Primary donor for PlayerBots AI fixes, healing priorities, and movement mechanics.
- `reference-upstreams/playerbots`: Cloned from `https://github.com/cmangos/playerbots.git` (branch `master`). Reference donor for CMaNGOS bot logic.

#### Automated Upstream Synchronization (`task update-upstreams`):
To fetch and integrate new upstream donor commits locally without touching the working project:
```powershell
.\tools\task.ps1 update-upstreams           # Fast-forwards all reference upstreams
.\tools\task.ps1 update-upstreams vmangos   # Updates only vMaNGOS PlayerBots core
.\tools\task.ps1 update-upstreams cmangos   # Updates only CMaNGOS PlayerBots
```
- **Local Commits Inspection**: When new commits are detected, `task update-upstreams` outputs the commit count and recent git oneline logs, allowing immediate inspection with `git -C reference-upstreams/core show <sha>`.
- **Target Repository Exclusion & Protection**: Active target repo `tortoise-wow-extended` (branch `playerbots`) is **strictly excluded** from automated pulls or checkouts to prevent dirtying or overwriting active development work.

### 2.10. Batch Compile and Audit Policy & Commit/Push Standard (ADR-010)
- **Batch Compile and Audit Command**: `.\tools\task.ps1 batch-compile-and-audit [source] [mode]` executes high-throughput batch auditing and single-pass compilation. It allows auditing multiple candidates in batch and compiling once at the end of the batch, avoiding lengthy repetitive MSVC Whole-Program Optimization / Link-Time Code Generation passes (`/GL` / `/LTCG`).
- **NEVER Batch-Commit to Git**: Multiple upstream donor commits must **NEVER** be squashed or batched into a single target git commit. Each donor commit must be applied and committed to Git individually (1 donor commit = 1 git commit) to ensure complete provenance and `git bisect` capability.
- **Push One-by-One as Default**: Every commit must be pushed to `origin/playerbots` individually (`git push origin <sha>:playerbots`) as default. Do not push composite batch SHAs.

#### Essential Ecosystem Links & Comparison References:
- **Turtle WoW Original**: [Penqle/tortoise-wow](https://github.com/Penqle/tortoise-wow)
- **Turtle WoW with IKE3 Bots**: [Shyalya/tortoise-wow](https://github.com/Shyalya/tortoise-wow) &bull; [T-imothy/tortoise-wow](https://github.com/T-imothy/tortoise-wow)
- **Turtle WoW with AC Bots**: [tortoise-wow-stack/TortoiseBots](https://github.com/tortoise-wow-stack/TortoiseBots)
- **Turtle WoW Knowledge DB**: [tortoise-wow-stack/TortoiseWoWKnowledgeBase](https://github.com/tortoise-wow-stack/TortoiseWoWKnowledgeBase)
- **Turtle Module Topics & Template**: [tortoise-module Topic](https://github.com/topics/tortoise-module) &bull; [Turtle Module Template](https://github.com/Penqle/tortoise-wow/tree/main/modules/templates/basic)
- **vMaNGOS Core & Upstream**: [vmangos/core](https://github.com/vmangos/core) &bull; [vMaNGOS Releases (db_latest)](https://github.com/vmangos/core/releases)
- **vMaNGOS with PlayerBots (IKE3)**: [ileboii/core (vmangos-ike3-playerbots)](https://github.com/ileboii/core/tree/vmangos-ike3-playerbots)
- **vMaNGOS Database**: [brotalnia/database](https://github.com/brotalnia/database/tree/master)
- **cMaNGOS PlayerBots**: [cmangos/playerbots](https://github.com/cmangos/playerbots)
- **Turtle DB Viewer**: [Online DB Viewer](https://xian55.github.io/tortoise-db-viewer/?) &bull; [Xian55/tortoise-db-viewer](https://github.com/Xian55/tortoise-db-viewer)
- **User Working Target Repository**: [Ildourol/tortoise-wow-extended](https://github.com/Ildourol/tortoise-wow-extended)
- **Fork Comparison**: [T-imothy vs Ildourol:playerbots Comparison](https://github.com/T-imothy/tortoise-wow/compare/playerbots...Ildourol:tortoise-wow-extended:playerbots)

---

## 3. Specialized Agent Roles

1. **COORDINATOR**: Owns task sequencing, source watermarks, scan modes, batch planning, and final reporting.
2. **CMANGOS AUDITOR** (Read-Only): Audits `cmangos/playerbots` commits against target contracts, filters expansion noise, and drafts native adaptation requirements.
3. **VMANGOS AUDITOR** (Read-Only): Audits `ileboii/core` (`vmangos-ike3-playerbots`) commits, identifies file mappings, and checks for semantic equivalence.
4. **TARGET COMPATIBILITY ANALYST** (Read-Only): Investigates target call sites, verifies Dungeon Clear interaction, and detects existing fixes.
5. **IMPLEMENTER** (Single Writer): Adapts and applies selected commits natively into `tortoise-wow-extended`.
6. **VERIFIER**: Executes the multi-tier verification ladder (`modules.lib` compile and `mangosd.exe` link).
7. **LEDGER MAINTAINER**: Persists durable state in `state/porting-ledger.json` and `state/source-watermarks.json`.

---

## 4. AI Token, Context & Cache Budgets

1. **Bounded Context Assembly**: Prompts and file inspections must include only touched files and functions capped at $\le 200$ surrounding lines. Full repositories must never be ingested.
2. **Budget Caps**:
   - Max AI input tokens per candidate evaluation: 16,000.
   - Max AI output tokens per candidate evaluation: 4,000.
   - Max candidate batch size: 50.
   - Build timeout: 900 seconds.
3. **Deterministic First**: Evaluate syntax, file presence, and keyword filters deterministically before invoking AI analysis.
4. **Cache Invalidation**: Cache entries are invalidated whenever target `playerbots` HEAD moves or donor watermarks advance.

---

## 5. Definition of Done
 
A candidate port is officially **DONE** when:
1. Candidate bug or enhancement is proven relevant to the target and not already present.
2. Code is ported natively conforming to target module and threading architecture.
3. Dungeon Clear compatibility checklist passes.
4. Target compilation of `modules.lib` succeeds with 0 errors.
5. Target binary `mangosd.exe` links cleanly with 0 unresolved symbols.
6. Commit is recorded in `state/porting-ledger.json` with full upstream provenance and individual target commit SHA.
7. Verified commit is committed and pushed individually to `playerbots` (commit-by-commit, 1-to-1 with upstream donor commit).
