# AGENTS.md: Autonomous Operating Protocol for Module-playerbots

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
- No symbolic links, NTFS junctions, submodules, shared runtime files, shared databases, or cross-workspace references are permitted.
- All persistent configuration resides within `Module-playerbots/`.

### 2.2. Single-Writer & Worktree Safety
- Only one agent or task may modify target files at any given time.
- The working tree must be kept clean. Never run destructive reset commands (`git reset --hard`, `git clean -fd`) against a tree containing uncommitted user changes.
- If isolated experimentation is needed, use dedicated Git worktrees.

### 2.3. Repository Targets & Commit Safety
- **Writable Target**: Modifications occur strictly in `tortoise-wow-extended`.
- **Target Integration Branch**: `mantech-turtle`.
- **Read-Only Sources**: `playerbots` and `core` are read-only source repositories. Never commit or push to them.
- **Push Policy**: Pushes to `mantech-turtle` are authorized only after complete Level 3 verification (`mangosd.exe` links cleanly). Force-pushes are strictly forbidden.

### 2.4. Protected Subsystems
- **Dungeon Clear (`modules/mod-dungeon-clear`)**: Protected subsystem. No port may break, bypass, or desync Dungeon Clear value contexts, routes, or encounter states.
- **Turtle WoW 1.18.1 Mechanics**: 11 playable races (`MAX_RACES = 11`), custom entities (spells $\ge 40000$, objects $\ge 300000$), 64-bit debuff streaming (`sTWDebuff`).

### 2.5. Scope Widening Prohibition & Mandatory Double-Confirmation Gate
- **Strict Scope Prohibition**: Widening the scan scope to historical bulk backlogs beyond the established active watermarks is **STRICTLY PROHIBITED**.
- **Double-Confirmation Requirement**: If the user or operator ever requests widening the scan scope or moving watermarks further into historical history, the agent **MUST NOT** execute it immediately. The agent is strictly required to pause, reject automatic execution, explain the risks of scope explosion and regression hazards, and explicitly request a second, separate confirmation ("double ask") before altering watermarks.

### 2.6. Strict Commit-by-Commit Porting & Pushing Workflow (Batch Audit Allowed, Batch Commit Prohibited)
- **Batch Auditing Permitted**: Agents and tasks MAY scan, evaluate, and triage multiple upstream donor commits in batches (up to 50 candidate commits per batch) to maintain high audit efficiency.
- **Batch Commits Strictly Prohibited**: Multiple upstream donor commits must **NEVER** be grouped, combined, or squashed into a single target git commit.
- **1-to-1 Atomic Porting Cycle**: Every single ported commit must execute its own isolated atomic cycle:
  `1 Donor Commit -> 1 Adaptation -> 1 Build Verification (modules.lib + mangosd.exe) -> 1 Atomic Target Git Commit -> 1 Remote Git Push -> 1 Ledger Update`.
- Each commit pushed to `mantech-turtle` must correspond to exactly one upstream donor commit with full individual provenance (source repository, upstream commit SHA, subsystem, priority).
- **No Batch Pushing**: Every individual commit must be pushed immediately to `mantech-turtle` upon passing verification before moving to the next candidate commit.

### 2.7. Absolute Vanilla / Classic Exclusivity Mandate (Strict Prohibition on TBC and WotLK)
- **Strict Vanilla / Classic Target**: This project targets exclusively **Vanilla / Classic WoW** (Classic 1.12.1 / Turtle WoW 1.18.1 Classic+).
- **Absolute Prohibition on TBC & WotLK**: Porting **ANY** mechanics, spells, talents, strategies, items, opcodes, or assumptions from The Burning Crusade (TBC 2.x), Wrath of the Lich King (WotLK 3.x), or any later expansion is **STRICTLY PROHIBITED**.
- **Vanilla-Only Permitted Changes**: Only changes, bugfixes, and enhancements directly relevant to Vanilla / Classic are permitted.
- **Handling Multi-Expansion Upstream Code**: If an upstream commit contains multi-expansion branching (`#if defined(MANGOSBOT_ONE) || defined(MANGOSBOT_TWO)`, `#ifdef TBC`, WotLK checks, etc.):
  1. All non-Vanilla branches, post-Vanilla spells, talents, arenas, flying mounts, and expansion logic must be completely stripped out.
  2. If an upstream fix exists primarily for or relies upon TBC/WotLK mechanics, it is immediately **DISQUALIFIED** with status `EXPANSION_INCOMPATIBLE` and priority `P3`.
- **Zero Tolerance**: Under no circumstances may any TBC or WotLK content enter `modules/mod-playerbots` or target branch `mantech-turtle`.

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
4. **Cache Invalidation**: Cache entries are invalidated whenever target `mantech-turtle` HEAD moves or donor watermarks advance.

---

## 5. Definition of Done
 
A candidate port is officially **DONE** when:
1. Candidate bug or enhancement is proven relevant to the target and not already present.
2. Code is ported natively conforming to target module and threading architecture.
3. Dungeon Clear compatibility checklist passes.
4. Target compilation of `modules.lib` succeeds with 0 errors.
5. Target binary `mangosd.exe` links cleanly with 0 unresolved symbols.
6. Commit is recorded in `state/porting-ledger.json` with full upstream provenance and individual target commit SHA.
7. Verified commit is committed and pushed individually to `mantech-turtle` (commit-by-commit, 1-to-1 with upstream donor commit).
