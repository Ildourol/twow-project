# AGENTS.md: Autonomous Agent Operating Protocol for Tortoise-WoW Extended

This document establishes the binding architectural principles, agent operational guidelines, verification gates, authority order, and upstream backporting rules for AI agents and developers working on **Tortoise-WoW Extended** (`twow project/tortoise-wow`).

---

## 1. Repository Authority Hierarchy

When conflicting technical requirements or code patterns arise, agents must strictly follow the nine-tier machine-readable authority order (`config/authority-policy.json`):

1. **Tier 1: Explicit Current User Requirement** - Direct commands, constraints, or instructions provided by the user in the current session.
2. **Tier 2: Target Tortoise-WoW Checked-Out Source** (`tortoise-wow`) - Real code, CMakeLists.txt, and runtime evidence in the target repo.
3. **Tier 3: Turtle-WoW / Penqle Reference Source & Docs** (`Penqle/tortoise-wow`) - Matching-revision Turtle 1.12.1/1.18.1 mechanics.
4. **Tier 4: Turtle 1.18.1 Client Data / DBC Evidence** (`reference-upstreams/client-data-1.18.1/dbc`) - Authoritative client data (`ChrRaces.dbc`, `Spell.dbc`, etc.).
5. **Tier 5: Current vMaNGOS Donor Source & Commit History** (`reference-upstreams/vmangos-core`) - Bugfix mechanics and donor diffs.
6. **Tier 6: Shyalya References** (`Shyalya/tortoise-wow`) - PlayerBots and Turtle bot integrations.
7. **Tier 7: TortoiseBots & Knowledge-Base Materials** - Supporting documentation and issue notes.
8. **Tier 8: Historical & Vanilla Reference Databases** (Main Historic DB: `brotalnia/database` with `world_full_14_june_2021.7z` / `.sql` for original vanilla entities unchanged by Turtle WoW; Backup: `vmangos/core db_latest` `mangos.sql` for modern updates; Viewer & Scalper: `tortoise-db-viewer`).
9. **Tier 9: Conceptual References** (AzerothCore, TrinityCore, CMaNGOS).

---

## 2. Fundamental Safety & Operational Rules

### 2.1. Single-Writer & Worktree Isolation Rule
- **Candidate modifications occur ONLY in dedicated Git worktrees**: `.worktrees/PORT-XXXX/`.
- **Target working tree purity**: The user's checked-out working tree (`tortoise-wow`) must remain clean. Never perform file modifications, patch applications, or build executions directly in the primary working tree.
- **Single-Writer Lock**: Compilation via MSVC 2022 / Ninja acquires exclusive execution. Never launch concurrent `-AutoBuild` runs across multiple terminals.

### 2.2. No Destructive Rollbacks
- Never execute destructive rollback commands on the target repository:
  - `git checkout .` (FORBIDDEN)
  - `git reset --hard` (FORBIDDEN)
  - `git clean -fd` (FORBIDDEN)
- If an isolated worktree fails compilation or tests, remove the worktree via `Remove-IsolatedWorktree`. The main working tree is never touched.

### 2.3. Repository Targets & Commit Safety
- **Primary Server Target**: All fixes, investigations, and commits target **Tortoise-WoW Extended** (`https://github.com/Ildourol/tortoise-wow-extended`). Candidates are committed strictly to candidate branches: `worktree/PORT-XXXX`.
- **Local Orchestration Workspace**: All orchestration tooling, scripts, and state management operate exclusively as a local workspace. It has no remote connections, and all workflows run strictly on the local machine.
- **Strict Remote Push Policy**:
  - Remote pushes to `extended` are **strictly restricted**: they trigger **ONLY** via `task auto-pilot`, `task auto-port`, commands explicitly passing `-AutoCommit`, or the explicit operator command `task push-extended`.
  - When triggered, all certified, passing candidate commits are automatically integrated and pushed directly to the remote development branch: [`https://github.com/Ildourol/tortoise-wow-extended/tree/extended`](https://github.com/Ildourol/tortoise-wow-extended/tree/extended).
  - Manual triage and staging commands (`task port`, `task port-batch`, `task build-packages`, dry runs) will **NEVER** push to remote.
  - Never push or commit to remote `main` without explicit, separate user authorization in the current session.

### 2.4. Read-Only Research Agents
- Agents 2 (Forum Scout), 3 (DB Scalper), 4 (AI Context Assembler), 5 (Core Restorer), and 6 (Online DB Oracle) are **strictly read-only**. They inspect, scalp, assemble evidence, and stage package manifests in `tools/queue/02_ready_to_build/`.
- Only the single-writer build pipeline may modify isolated candidate worktrees.

### 2.5. Structured JSON Contracts
- Every pipeline stage produces a machine-readable JSON result conforming to `config/schemas/stage_result.schema.json`.
- Standardized exit codes are mandatory:
  - `0`: PASS
  - `1`: VALIDATION / COMPATIBILITY FAILURE
  - `2`: TOOL / ENVIRONMENT FAILURE
  - `3`: SCHEMA / INTERNAL FAILURE

### 2.6. Canonical Configuration & State Store
- System configuration is central: `config/twow-project.json`.
- All candidate lifecycle states, active run IDs (`RUN-yyyyMMdd-HHmmss-xxxx`), baseline cache, and AI cache are persisted in `tools/state/state_store.json`.
- No stage may use informal free-text files as programmatic state.

### 2.7. Batch Auditing & Discovery with Atomic Commit-by-Commit Execution
- **Batch Auditing & Triage Permitted**: Upstream candidate commits may be evaluated, scanned, and triaged in batches (e.g. 10–50 candidates per pass via `task auto-pilot [N]`, `task port-batch [N]`, or `task rank`) to maximize discovery speed (5x–10x faster backlog processing) and detect multi-commit dependencies early.
- **Strict Commit-by-Commit Porting, Filing & Pushing**:
  - Target code adaptations occur strictly one candidate at a time in dedicated isolated worktrees (`.worktrees/PORT-XXXX/`).
  - Target compilation and link verification are executed strictly per candidate.
  - Every candidate receives its own individual documentation dossier in `docs/commits/PORT-XXXX_<sha>.md` and its own stage completion record in `tools/queue/03_completed/`.
  - Every passing candidate generates exactly one atomic target git commit.
  - Remote pushes to `extended` are executed strictly commit-by-commit (1 donor commit = 1 atomic target commit = 1 remote push).
  - Batching multiple upstream donor commits into a single git commit or bulk push is strictly prohibited.

---

## 3. Deterministic Bug Prover & Verification Modes

### 3.1. Bug-Presence Proof Required Before Porting
Before writing code or applying patches, the deterministic bug prover (`task prove <sha>`) must prove the candidate state:
- `BUG_PRESENT`: Defect pattern confirmed in target; porting may proceed.
- `ALREADY_FIXED`: Fix already present; candidate terminal clean.
- `NOT_APPLICABLE`: Target does not contain the affected system; candidate terminal clean.
- `TURTLE_INTENTIONAL_DIVERGENCE`: Code diverges intentionally for Turtle custom mechanics; candidate preserved.
- `UNCERTAIN`: Context diverged; requires human or advisory AI review.

### 3.2. Verification Modes & Automatic Escalation
- **Fast Mode**: Deterministic diff and schema checks; skipped builds.
- **Normal Mode**: AST context analysis, patch-aware compilation (`world`/`auth`), and disposable startup smoke check.
- **Deep Mode**: Full call-graph trace, full solution compilation, disposable smoke test, and reproducer verification.

#### Escalation Triggers:
- Fast $\rightarrow$ Normal: Database migration detected, dependencies detected, or bug confidence $< 0.85$.
- Normal $\rightarrow$ Deep: Security/crash keywords (`crash`, `packet`, `opcode`, `mutex`, `auth`), networking, or concurrency.
- **No Downgrade Rule**: Higher requested verification modes are never downgraded.

### 3.3. Smart Path Mapping & Target Tree Normalization
Upstream VMaNGOS and Tortoise-WoW have diverged directory hierarchies (e.g., `src/scripts/eastern_kingdoms/<zone>/<dungeon>/` vs `src/scripts/dungeons/<dungeon>/`, `contrib/` vs `tools/`, and `cmake/find/` vs `cmake/`).
- The pipeline utilizes [`tools/modules/PathMapper.ps1`](tools/modules/PathMapper.ps1) to dynamically and statically translate donor file paths into the canonical Tortoise-WoW layout across 519+ tracked file reorganizations.
- `BugProver.ps1`, `EncodingHelper.ps1`, and `Invoke-PortPipeline.ps1` automatically normalize patch headers and file lookups during `task auto-pilot`, preventing false `NOT_APPLICABLE` or `No such file or directory` rejections for valid upstream bugfixes.

### 3.4. AI-Powered Semantic Conflict & Regression Audit Gate
Static keyword matching is insufficient to catch subtle semantic divergence. Every candidate backport is subjected to an active **AI Semantic Conflict Audit** ([`tools/modules/AiConflictAuditor.ps1`](tools/modules/AiConflictAuditor.ps1)) across six invariant dimensions:
1. **Race Dimension**: Bounded loops/arrays must accommodate Turtle's 11 races (`MAX_RACES = 11`, High Elf & Goblin).
2. **Debuff Dimension**: Aura masks must preserve Turtle's 64-bit `sTWDebuff` streaming without truncating to 32-bit.
3. **Manager & Opcode Dimension**: Protected managers (`sLFTMgr`, `sTransmogMgr`, `sCustomMerchantMgr`) and opcodes (`SCRIPT_COMMAND_TAKE_MONEY = 93`) must never be clobbered.
4. **Entity Range Dimension**: Custom spell IDs ($\ge 40,000$) and world entity IDs ($\ge 300,000$) are strictly protected.
5. **AST & Call-Site Signature Dimension**: Validates that donor call-sites do not omit Turtle custom parameters (such as `inGurubashiArena`, teleport flags, or broadcaster guards).
6. **Concurrency & Threading Dimension**: Checks lock acquisition ordering (`m_mapLock`, `m_objectLock`) to eliminate potential AB-BA deadlocks.

If any semantic conflict is detected, the candidate is automatically rejected with `AI_SEMANTIC_CONFLICT` before staging or compiling.

---

## 4. Invariant Policies: Compatibility & Database

### 4.1. Turtle Compatibility Manifest
All patches are scanned against `config/turtle-compatibility.json`:
- **MAX_RACES = 11**: Hardcoded limits $< 11$ (such as vanilla loops `< 8` or `< 9`) or reassignments to 10 are rejected.
- **sTWDebuff**: Removal or disruption of `sTWDebuff` streaming is strictly rejected.
- **SCRIPT_COMMAND_TAKE_MONEY = 93**: Custom packet opcode value must be preserved.
- **Protected Managers**: `sLFTMgr`, `sTransmogMgr`, `sCustomMerchantMgr` must not be deleted.

### 4.2. Database Safety & Entity Provenance
- Scanned against 413 tables cached in `config/schema_catalog.json`.
- **Forbidden Progressive Columns**: `patch`, `build`, `min_patch`, `max_patch` are rejected.
- **Custom Spell ID Protection**: `spell_template` IDs $\ge 40000$ are reserved for Turtle custom spells.
- **Custom World Entity Protection**: `creature_template`, `item_template`, `quest_template`, `gameobject_template` IDs $\ge 300000$ are reserved for Turtle custom entities.
- **Entity Provenance**: All modified entity records must document source commit, source table, original value, proposed value, and confidence rating.

### 4.3. Stale Package Invalidation
- Packages staged in `02_ready_to_build/` store `target_base_sha`.
- If target repository HEAD moves before the package is built, the package is flagged as `STALE` and must be re-audited against the new base.

---

## 5. Build, Link, Startup & Runtime Distinctions

Agents must distinguish between four distinct levels of verification:
1. **Compile Success**: Source compiles to object files (`.obj`).
2. **Link Success**: Binaries link without unresolved symbols (`mangosd.exe`, `realmd.exe`).
3. **Startup Success**: Binaries launch in disposable environment, initialize DBCs, connect to DB, and report ready without crashing.
4. **Runtime Success**: In-game player/creature/spell interaction reproduces expected vanilla mechanics.

> Compile and link pass do NOT prove startup or runtime health!

---

## 6. AI Token Budgeting & Advisory Role

1. **Deterministic Safety Always Wins**: Deterministic filters and bug provers run before AI.
2. **Never Call AI for Deterministic Conclusions**: Do not invoke AI for `ALREADY_FIXED`, `NOT_APPLICABLE`, or syntax validation.
3. **Bounded Context Assembly**: Prompts must include only touched files/functions capped at $\le 200$ surrounding lines. Full repositories must never be sent.
4. **Composite Cache Key**: Cache AI evaluations by `DonorSha|TargetBaseSha|ManifestVersion|ContextHash`. Identical requests return cached verdicts instantly.
5. **AI is Advisory Only**: AI proposals must be verified by deterministic gates and compilers. AI cannot certify its own output.
6. **No Secrets**: Never expose credentials, auth tokens, or private user data in prompts or logs.

---

## 7. Definition of Done

A candidate fix or topic restoration is officially **DONE** when:
1. Deterministic bug proof verifies `BUG_PRESENT` (or native core restoration requirements verified against forum lore).
2. Compatibility invariants and database safety checks pass (Exit Code 0).
3. **AI Semantic Conflict Audit certifies `PASS` with zero conflicts or regressions across all 6 invariant dimensions.**
4. Candidate compiles cleanly in an isolated worktree with 0 errors, 0 fatal warnings under the resolved build profile.
5. Disposable startup smoke test passes without assert or crash.
6. Fix is committed cleanly to isolated candidate branch `port/PORT-XXXX-<sha>`.
7. State store (`tools/state/state_store.json`) updates candidate state to `COMPLETE`.
8. Candidate manifest and dossier are saved locally to `docs/commits/` and `docs/BACKPORT_HISTORY.md`.
9. Orchestration test suite (`task test`) passes 39/39 tests.

---

## 8. CLI Dispatcher & Autonomous Operation Commands

Agents and operators execute workflows through the canonical dispatcher ([`tools/task.ps1`](tools/task.ps1)):

| Purpose | Command Syntax | Description |
| :--- | :--- | :--- |
| **System Pre-Flight Audit** | `task system-check [light\|full]` | Validates total project health (docs, locations, goals, instructions, configs, worktrees, tests) before operating. |
| **Autonomous Batch Porting** | `task auto-pilot [N] [Tier]` | Runs complete pipeline (triage, DB audit, MSVC build, candidate commit, and auto-push passing fixes to GitHub `extended` branch) for $N$ candidates. |
| **Autonomous Single Porting** | `task auto-port <sha>` | Runs complete pipeline for single commit and auto-pushes verified fix to GitHub `extended` branch. |
| **Push Passed Commits** | `task push-extended [branch]` | Integrates and pushes all verified passing candidate commits to remote `extended` branch (`extended/extended`). |
| **Deterministic Bug Proof** | `task prove <sha>` | Verifies defect pattern exists in target without modifying files. |
| **Target Build Execution** | `task build <profile>` | Compiles server under specified profile (`world`, `auth`, `sql-only`, `playerbots`). |
| **Worktree Build & Commit** | `task build-packages` | Compiles and commits all ready staged packages in isolated worktrees (local only, never auto-pushes). |
| **Invariant & State Audit** | `task compatibility`, `task db-audit`, `task parity` | Verifies hard compatibility, DB ID ranges, and client DBC alignment. |
| **Automated Verification** | `task test` | Runs the full 39-suite orchestration test suite. |
| **Pipeline State & Queue** | `task status`, `task next`, `task rank` | Displays backlog metrics, candidate ranking, and optimal next target. |

