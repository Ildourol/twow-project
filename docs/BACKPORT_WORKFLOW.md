# Commit-by-Commit Backporting Workflow & AI Runbook

This document defines the authoritative, step-by-step engineering runbook for backporting upstream bugfixes and restoring native Turtle-WoW specifications in **Tortoise-WoW Extended** (`twow project/tortoise-wow`).

---

## 1. Core Engineering Philosophy: Strict Commit-by-Commit

The foundational architecture of Tortoise-WoW Extended is built on:

```
STRICT COMMIT-BY-COMMIT BACKPORTING & VERIFICATION
```

Every single bugfix follows an isolated, atomic lifecycle:

```
1 BUG DIAGNOSIS
    --> 1 DONOR COMMIT
    --> 1 AI SEMANTIC CONTEXT DOSSIER
    --> 1 TURTLE-NATIVE ADAPTATION (Preserving Invariants)
    --> 1 MSVC 2022 RELEASE COMPILE GATE (Exit Code 0)
    --> 1 ATOMIC GIT COMMIT WITH ATTRIBUTION
    --> 1 REMOTE PUSH TO EXTENDED MAIN
    --> NEXT FIX
```

### Prohibited Practices:
- **NO BATCH SQUASHING**: Never group multiple donor fixes into a single git commit. Each bugfix must stand alone.
- **NO GENERIC TITLES**: Never commit with messages like "Misc fixes", "Batch 5", or "Various cleanups".
- **NO BLIND CHERRY-PICKING**: Never use naive `git apply` without semantic verification; Turtle-WoW contains custom race limits (`MAX_RACES = 11`), 64-bit debuff streaming (`UI64LIT`), custom arena parameters (`inGurubashiArena`), and custom content IDs ($\ge 300,000$) that must never be clobbered.
- **NO DOCUMENTATION COMMITS TO GIT**: All dossiers, runbooks, and ledgers are maintained locally in `twow project/docs/`. Git history contains **strictly production code and database migrations**.

---

## 2. Priority Hierarchy: The 5 Semantic Tiers

When pulling candidate donor commits from [`tools/porting/CRUCIAL_COMMITS_QUEUE.csv`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/CRUCIAL_COMMITS_QUEUE.csv), prioritize candidates across the five semantic tiers:

1. **Tier 1 — Server Crashes, Memory Leaks & Security**:
   - Null pointer dereferences, heap buffer overflows, use-after-free, memory leaks, iterator invalidation, password brute force attacks.
2. **Tier 2 — Combat Accuracy, Formulas & Spells**:
   - Melee/ranged formulas, spell aura stacking, wand formulas, swing timers, resists, damage calculations, off-hand procs.
3. **Tier 3 — Bounds Checks, Exploits & Packet Integrity**:
   - Boundary clamping, packet size guards, duplication exploits, trade cancellation race conditions, permission validation.
4. **Tier 4 — Pet, AI, Movement & Spline Pathing**:
   - Escort follow angles, pet stabling/revival, confused movement speeds, creature evade loops, VMap line-of-sight bounds.
5. **Tier 5 — Quests, Dungeons, Raids, Core & General Systems**:
   - Encounter resets, event triggers, gameobject interactions, boss AI stability, and core system cleanups.

---

## 3. The 4-Phase AI Backporting Runbook

### Phase 1: AI Semantic Context Assembly (`task ai-audit <sha>`)
1. **Context Extraction**:
   - Run `& "...\tools\task.ps1" ai-audit <sha>` (or `task 4 <sha>`).
   - The engine pulls the full diff, checks which files exist in `tortoise-wow`, and extracts surrounding line context.
2. **Forum Intelligence Mining**:
   - Mines the 22,155-thread Turtle forum archive for related staff notes, custom changes, or reported bugs.
3. **Dossier Generation**:
   - Assembles a structured AI Dossier in `tools/queue/ai_dossiers/<sha>.md` diagnosing clean apply vs. context divergence.

### Phase 2: AI Semantic Adaptation (`task port <sha>`)
1. **Divergence Analysis**:
   - If clean apply passes: Stages directly as `READY_FOR_BUILD`.
   - If context diverged: Identifies Turtle-specific additions (e.g. `inGurubashiArena` in `Formulas.h` or debuff hooks in `SpellAuras.cpp`).
2. **Semantic Patch Synthesis**:
   - Synthesizes an adapted `.patch` in `tools/queue/staging_patches/<sha>.patch` preserving all Turtle invariants.
3. **Manifest Assembly**:
   - Generates `PORT-XXXX.json` in `tools/queue/02_ready_to_build/`.

### Phase 3: Builder & Single-Writer Compile Gate (`task 1`)
1. **Invariant Verification**:
   - Runs `Verify-TurtleCompatibility.ps1` to assert `MAX_RACES = 11`, `sTWDebuff`, and no progressive SQL columns.
2. **MSVC 2022 Release Compilation**:
   - Compiles both `mangosd.exe` and `realmd.exe` via CMake (`--config Release`).
   - Gate requirement: **Exit Code 0** (0 compiler errors, 0 linker errors).
   - If build fails: Automatically rolls back via `git checkout .` to preserve repository integrity.
3. **Atomic Git Commit & Immediate Remote Push**:
   - Formats standardized message: `Port(<Subsystem>): <Subject> (vmangos/core@<sha>)`.
   - Pushes commit immediately to `https://github.com/Ildourol/tortoise-wow-extended.git` branch `main`.
4. **Archive & Metrics Update**:
   - Moves package to `tools/queue/03_completed/` and patch to `03_completed/patches/`.
   - Updates [`docs/COMMITS_UPLOADED.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/COMMITS_UPLOADED.md) and [`docs/commits/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/docs/commits/).

### Phase 4: Native Core Feature Restoration (`task restore <topic>`)
When restoring custom Turtle specifications that are missing from the leaked core:
1. Run `& "...\tools\task.ps1" restore "<topic>" -StageTemplate`.
2. Evaluates official staff patch notes in `resources/forum/`.
3. Checks `tortoise-wow` codebase for existing stubs or missing handlers.
4. Generates `CORE-XXXX.json` in `02_ready_to_build/` ready for C++ synthesis.
5. Instant cache verification (`restoration_history.json`) guarantees zero double-checking of previously analyzed topics.
6. Once synthesized, compiled via `task 1`.

### Phase 5: Database Scalping & Entity Extraction (`task scalp` / `task extract`)
When extracting or comparing items, creatures, or spells against historical baselines:
1. Run `& "...\tools\task.ps1" scalp <entity_type> <id_or_name> -Diff`.
2. Automatically parses monolithic SQL dumps (`world_full_14_june_2021.sql` / `mangos.sql`), strips progressive columns (`patch`, `build`), and highlights divergences against `tortoise-wow/sql/base/world.sql`.
3. Preserves Turtle-exclusive custom columns (`is_custom_turtle_item`).
4. With `-ExportSql`, generates clean `REPLACE INTO` migrations in `tools/queue/staging_sql/`.

### Phase 6: Online Database Oracle Verification (`task 6 <id>` / `task db-viewer`)
1. Run `& "...\tools\task.ps1" 6 <id>` to cross-reference with official 1.18.1 client data (`https://xian55.github.io/tortoise-db-viewer/`).
2. Run `& "...\tools\task.ps1" 6 changelog` to track live CDN database deltas.
3. Pass `-OpenBrowser` to inspect 3D models and rendered item tooltips interactively.

---

## 4. Operational Command Cheat Sheet

```powershell
# 1. Inspect live pipeline status
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" status

# 2. Run AI Semantic Audit on candidate
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" ai-audit 84f1bbccd

# 3. Stage candidate for build
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" port 84f1bbccd

# 4. Full Autonomous Port (Audit -> Adapt -> Compile -> Commit -> Push)
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" port 84f1bbccd -AutoBuild

# 5. Hands-off batch of next 10 crucial commits
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" port-batch 10 -AutoBuild

# 6. Restore native Turtle feature from forum notes (zero double-checking)
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" restore "Holy Strike" -StageTemplate

# 7. Batch restore multiple features
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" restore-batch 5

# 8. Scalp & compare entity from historical DB
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" scalp item 19019 -Diff

# 9. Scalp and export sanitized SQL migration
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" scalp item 19019 -ExportSql

# 10. Query Online Database Viewer (with 3D browser view)
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" 6 19019 -OpenBrowser

# 11. Compile, verify, and push staged packages (Single-Writer Gate)
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" 1

# 12. Regenerate master printable documentation PDF
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" pdf
```
