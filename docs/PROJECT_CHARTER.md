# Module-playerbots Project Charter

## 1. Executive Summary & Objective

**Module-playerbots** is an autonomous, evidence-driven upstream porting, stabilization, and verification framework for **Turtle WoW 1.18.1 / vMaNGOS** PlayerBots.

The project systematically harvests, audits, adapts, verifies, documents, and integrates useful PlayerBots fixes and features from two active upstream source families:
1. **CMaNGOS PlayerBots** (`cmangos/playerbots`): High-velocity donor repository containing modern AI improvements, stability fixes, combat/travel corrections, and strategies.
2. **vMaNGOS PlayerBots** (`ileboii/core` on `vmangos-ike3-playerbots`): Lineage-adjacent donor repository containing focused Vanilla fixes, lifecycle stability, and performance improvements.

Target Server:
- **Repository**: `https://github.com/Ildourol/tortoise-wow-extended.git`
- **Integration Branch**: `playerbots`
- **Protected Core Contracts**: Turtle WoW 1.18.1 mechanics, custom content/races, client build 7272, and **Dungeon Clear** integration.

This is **not a blind cherry-picking project**. Upstream commits represent evidence and source material; the target checkout and its contracts are authoritative.

---

## 2. Core Invariants & Protected Systems

1. **Core-Preservation Invariant**:
   Never replace native Turtle / vMaNGOS systems or data structures with foreign upstream architecture merely to simplify a patch. Port behavior and intent, not alien dependencies.
2. **Dungeon Clear Protection**:
   `modules/mod-dungeon-clear` is a critical protected target subsystem. All bot changes touching instance lifecycle, reset, group composition, movement, follower states, death/repop, teleportation, or gossip must preserve Dungeon Clear contracts.
3. **Strict Vanilla / Classic Exclusivity Invariant (Absolute Prohibition on TBC / WotLK)**:
   This project is strictly and exclusively dedicated to **Vanilla / Classic WoW** (Classic 1.12.1 / Turtle WoW 1.18.1 Classic+). Porting anything from TBC, WotLK, or any later expansion is **STRICTLY PROHIBITED**. Only changes, mechanics, and bugfixes directly related to Vanilla and Classic are permitted. All TBC/WotLK spells, talents, combat ratings, resilience, arenas, flying mounts, and expansion-specific logic must be completely rejected or stripped before any code is considered. Zero tolerance for post-Vanilla expansion pollution.
4. **Single-Writer Safety**:
   Target repository modifications follow a strict single-writer lock. No concurrent tasks may edit the same target files.
5. **Durable Ledger Principle**:
   Every upstream commit evaluated receives a permanent audit record in `state/porting-ledger.json`. Commits marked `REJECTED`, `ALREADY_PRESENT`, or `SUPERSEDED` are preserved so the engine never wastes tokens re-evaluating rejected history.
6. **Absolute Workspace Isolation**:
   The Module-playerbots project operates with complete independence. No symlinks, junctions, shared caches, or cross-workspace links are permitted.
7. **Strict Scope Boundary & Double-Confirmation Gate**:
   Unbounded widening of the scan scope into historical bulk donor backlogs is **prohibited**. The project operates strictly within the focused, high-signal active watermark ranges. If scope expansion is requested, the system must double-ask and require explicit user re-confirmation before adjusting watermarks.
8. **Mandatory Commit-by-Commit Porting & Pushing (Batch Audit Allowed, Batch Commits Prohibited)**:
   While candidate commits may be audited and triaged in batches for analysis efficiency, all porting, code adaptation, build verification, git committing, and remote pushing must be executed strictly **commit-by-commit** (1 upstream donor commit = 1 atomic target git commit = 1 remote push). Grouping, squashing, or batch-uploading multiple upstream commits into a single target commit is strictly prohibited.

---

## 3. Authority Order

When technical requirements or evidence conflict:
1. Current User Request.
2. Target checkout at current revision (`tortoise-wow-extended`).
3. Target `AGENTS.md` and target-specific engineering policies.
4. Target CMakeCache, build, and runtime evidence.
5. Target same-revision documentation and call sites.
6. The exact upstream commit being evaluated.
7. Current source repositories (`playerbots`, `core`).
8. Public documentation appropriate to the same lineage.
9. Copied/adapted project-management methodology.

---

## 4. Operational Boundaries

- **No Destructive Operations**: `git reset --hard`, `git clean -fd`, and force-push are strictly forbidden against repos with user changes.
- **Push Policy**: Commits are pushed only to `playerbots` after complete link verification.
- **Database Safety**: Schema migrations are generated in source only; no live database modification without explicit user authorization.
- **Config Safety**: `.conf.dist` templates are maintained; live configuration files are never overwritten.
