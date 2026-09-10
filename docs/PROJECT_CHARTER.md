# Module-playerbots Project Charter

## 1. Executive Summary & Objective

**Module-playerbots** is an autonomous, evidence-driven upstream porting, stabilization, and verification framework for **Turtle WoW 1.18.1 / vMaNGOS** PlayerBots.

The project systematically harvests, audits, adapts, verifies, documents, and integrates useful PlayerBots fixes and features from two active upstream source families:
1. **CMaNGOS PlayerBots** (`cmangos/playerbots`): High-velocity donor repository containing modern AI improvements, stability fixes, combat/travel corrections, and strategies.
2. **vMaNGOS PlayerBots** (`ileboii/core` on `vmangos-ike3-playerbots`): Lineage-adjacent donor repository containing focused Vanilla fixes, lifecycle stability, and performance improvements.

Target Server:
- **Repository**: `https://github.com/Ildourol/tortoise-wow-extended.git`
- **Integration Branch**: `mantech-turtle`
- **Protected Core Contracts**: Turtle WoW 1.18.1 mechanics, custom content/races, client build 7272, and **Dungeon Clear** integration.

This is **not a blind cherry-picking project**. Upstream commits represent evidence and source material; the target checkout and its contracts are authoritative.

---

## 2. Core Invariants & Protected Systems

1. **Core-Preservation Invariant**:
   Never replace native Turtle / vMaNGOS systems or data structures with foreign upstream architecture merely to simplify a patch. Port behavior and intent, not alien dependencies.
2. **Dungeon Clear Protection**:
   `modules/mod-dungeon-clear` is a critical protected target subsystem. All bot changes touching instance lifecycle, reset, group composition, movement, follower states, death/repop, teleportation, or gossip must preserve Dungeon Clear contracts.
3. **Vanilla / Turtle Expansion Invariant**:
   TBC/WotLK assumptions (e.g. post-Vanilla spells, talents, item classes, or arenas) must be adapted or rejected. Target supports Vanilla/Turtle 1.18.1 mechanics.
4. **Single-Writer Safety**:
   Target repository modifications follow a strict single-writer lock. No concurrent tasks may edit the same target files.
5. **Durable Ledger Principle**:
   Every upstream commit evaluated receives a permanent audit record in `state/porting-ledger.json`. Commits marked `REJECTED`, `ALREADY_PRESENT`, or `SUPERSEDED` are preserved so the engine never wastes tokens re-evaluating rejected history.
6. **Absolute Workspace Isolation**:
   The Module-playerbots project operates with complete independence. No symlinks, junctions, shared caches, or cross-workspace links are permitted.
7. **Strict Scope Boundary & Double-Confirmation Gate**:
   Unbounded widening of the scan scope into historical bulk donor backlogs is **prohibited**. The project operates strictly within the focused, high-signal active watermark ranges. If scope expansion is requested, the system must double-ask and require explicit user re-confirmation before adjusting watermarks.

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
- **Push Policy**: Commits are pushed only to `mantech-turtle` after complete link verification.
- **Database Safety**: Schema migrations are generated in source only; no live database modification without explicit user authorization.
- **Config Safety**: `.conf.dist` templates are maintained; live configuration files are never overwritten.
