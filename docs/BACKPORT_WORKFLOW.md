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
    --> 1 SMART PATH MAPPING & TARGET TREE NORMALIZATION
    --> 1 AI SEMANTIC CONFLICT AUDIT GATE (6 Invariant Dimensions)
    --> 1 TURTLE-NATIVE ADAPTATION (Preserving Invariants)
    --> 1 MSVC 2022 RELEASE COMPILE GATE (Exit Code 0)
    --> 1 ATOMIC GIT COMMIT WITH ATTRIBUTION
    --> 1 REMOTE PUSH TO EXTENDED BRANCH (Auto-Pilot / AutoCommit only)
    --> NEXT FIX
```

### Prohibited Practices:
- **NO BATCH SQUASHING**: Never group multiple donor fixes into a single git commit. Each bugfix must stand alone.
- **NO GENERIC TITLES**: Never commit with messages like "Misc fixes", "Batch 5", or "Various cleanups".
- **NO BLIND CHERRY-PICKING**: Never use naive `git apply` without semantic verification; Turtle-WoW contains custom race limits (`MAX_RACES = 11`), custom debuff streaming (`UI64LIT`), custom arena parameters (`inGurubashiArena`), and custom content IDs ($\ge 300,000$) that must never be clobbered.
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

### Phase 1: Smart Path Mapping & AI Context Assembly (`task ai-audit <sha>`)
1. **Directory Normalization & Path Mapping**:
   - The engine automatically resolves donor file paths via `PathMapper.ps1` across 519+ tracked reorganizations (`eastern_kingdoms/<zone>/<dungeon>/` $\rightarrow$ `dungeons/<dungeon>/`, etc.).
2. **Context Extraction**:
   - The engine pulls the full diff, verifies mapped target files in `tortoise-wow`, and extracts surrounding line context.
3. **Forum Intelligence Mining**:
   - Mines the 22,155-thread Turtle forum archive for related staff notes, custom mechanics, or reported bugs.
4. **Dossier Generation**:
   - Assembles a structured AI Dossier in `tools/queue/ai_dossiers/<sha>.md` diagnosing clean apply vs. context divergence.

### Phase 2: AI Semantic Conflict Audit & Adaptation (`task port <sha>`)
1. **Mandatory AI Semantic Conflict Audit (`Invoke-AiSemanticConflictAudit`)**:
   - Leverages AI semantic reasoning across six core dimensions:
     - *Race Dimension*: Asserts support for Turtle's 11 races (`MAX_RACES = 11`, High Elf & Goblin).
     - *Debuff Dimension*: Guarantees 64-bit `sTWDebuff` streaming is never truncated to 32-bit.
     - *Manager Dimension*: Verifies protected managers (`sLFTMgr`, `sTransmogMgr`, `sCustomMerchantMgr`) remain untouched.
     - *Entity Range Dimension*: Prohibits overrides of custom IDs (spells $\ge 40000$, entities $\ge 300000$).
     - *Call-Site Signature Dimension*: Validates that donor call-sites retain custom parameters (e.g. `inGurubashiArena`).
     - *Concurrency Dimension*: Evaluates lock hierarchies for AB-BA deadlock prevention.
   - If any semantic conflict is detected, the candidate is immediately rejected before staging or compiling.
2. **Semantic Patch Synthesis & Staging**:
   - Synthesizes an adapted `.patch` in `tools/queue/staging_patches/<sha>.patch` preserving all Turtle invariants.
   - Generates package manifest `PORT-XXXX.json` in `tools/queue/02_ready_to_build/`.

### Phase 3: Single-Writer Compile Gate & Execution Modes (`task build-packages`)
1. **Invariant Verification**:
   - Runs `Verify-TurtleCompatibility.ps1` to assert `MAX_RACES = 11`, `sTWDebuff`, and no progressive SQL columns.
2. **Build & Verification Execution Modes (Token & Latency Optimization)**:
   - **Option 1: Fast Incremental Mode (Recommended Default)**:
     - Compile only the affected target module/library (e.g. `game.lib`, `modules.lib`, `shared.lib`) via `task build-packages -FastBuild` (~3–5s, ~3 lines of output).
     - Atomic commits are created and pushed to `extended` individually.
     - Full `mangosd.exe` link is run once at the batch or milestone boundary.
     - Saves ~90% of token consumption and avoids 10–15 minutes of idle waiting across multi-package series.
   - **Option 2: Batch Verification Mode (Maximum Token Efficiency)**:
     - Packages are adapted, documented, and committed sequentially in git to maintain 1-to-1 provenance and git bisectability.
     - Single compilation and full linking pass (`world` + `mangosd.exe`) is executed at the conclusion of the batch.
     - *Debugging Guarantee*: MSVC diagnostics pinpoint the exact file and line number on compilation failure; atomic git commits preserve effortless `git bisect` for runtime regressions. The resulting binaries are identical.
   - **Option 3: Strict Full-Link Mode (P0 Maximum Safety)**:
     - Full recompile and link of `mangosd.exe` and `realmd.exe` on every single package.
3. **Atomic Git Commit to Candidate Branch**:
   - Formats standardized message: `Port(<Subsystem>): <Subject> (vmangos/core@<sha>)`.
   - Commits cleanly to isolated candidate branch `port/PORT-XXXX-<sha>`.
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
6. Once synthesized, compiled via `task build-packages` (or `task auto-pilot`).

### Phase 5: Database Scalping & Entity Extraction (`task scalp` / `task extract`)
When extracting or comparing items, creatures, or spells against baselines:
1. Run `& "...\tools\task.ps1" scalp <entity_type> <id_or_name> -Diff`.
2. Queries Turtle base SQL as primary, cross-references Brotalnia `world_full_14_june_2021.sql` (Main Historic DB from `world_full_14_june_2021.7z`) for original vanilla entities unchanged by Turtle WoW, and `vmangos/core db_latest` (backup donor DB).
3. Connects with `tortoise-db-viewer` (REST API `api.tortoiseclothing.org`, local dataset `vanilla-ids.json`, and web dashboard), strips progressive columns (`patch`, `build`), and highlights divergences.
4. Preserves Turtle-exclusive custom columns (`is_custom_turtle_item`, `mount_display_id`, `wrapped_gift`, `script_name`).
5. With `-ExportSql`, generates clean `REPLACE INTO` migrations in `tools/queue/staging_sql/`.
6. Pass `-OpenViewer` or use `task dashboard <id>` to inspect directly in the official AoWoW-style web dashboard.

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

# 8. Scalp & compare entity via tortoise-db-viewer
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" scalp item 19019 -Diff

# 9. Scalp and export sanitized SQL migration
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" scalp item 19019 -ExportSql

# 10. Query Online Database Viewer (with 3D browser view)
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" 6 19019 -OpenBrowser

# 11. Compile and verify staged packages in isolated worktrees (local only)
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" 1

# 12. Push all verified passing candidate fixes to GitHub extended branch
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" push-extended

# 13. Regenerate master printable documentation PDF
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" pdf
```
