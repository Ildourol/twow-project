# Porting Troubleshooting and Engineering Safeguards

This guide provides developers, engineers, and autonomous AI agents with diagnostic playbooks, toolchain safeguards, schema validation recipes, and crash triage procedures for **Tortoise-WoW Extended** (`twow project/tortoise-wow`).

---

## 1. MSVC 2022 Toolchain & Build Troubleshooting

### Issue 1.1: Unresolved External Symbol `OSSL_PROVIDER_load` or `SSL_get1_peer_certificate`
- **Root Cause**: The project is being compiled on Windows using modern vcpkg packages (OpenSSL 3.x), but CMake defaulted to the legacy bundled static libraries in `dep/windows/lib/`, which were built with OpenSSL 1.1.
- **Diagnostic Check**:
  Inspect `CMakeCache.txt` or CMake configure output for:
  ```
  OPENSSL_INCLUDE_DIR: C:/Users/.../dep/windows/include/openssl
  ```
- **Solution (`BUILD-0001`, `316b0dccf`)**:
  In `CMakeLists.txt`, verify that the vcpkg auto-detection block is active:
  ```cmake
  if (EXISTS "C:/vcpkg/installed/x64-windows/include/openssl/ssl.h")
      set(OPENSSL_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
      set(OPENSSL_LIBRARIES "C:/vcpkg/installed/x64-windows/lib/libssl.lib" "C:/vcpkg/installed/x64-windows/lib/libcrypto.lib")
  ```
  Delete CMake cache and reconfigure:
  ```powershell
  cmake -B build -S "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" -DCMAKE_TOOLCHAIN_FILE="C:/vcpkg/scripts/buildsystems/vcpkg.cmake"
  ```

---

### Issue 1.2: ARC4 Provider Initialization Failure at Server Startup
- **Symptoms**: `mangosd.exe` crashes immediately on startup or throws an assertion error during Warden initialization:
  ```
  Assertion failed: m_ctx != nullptr in ARC4.cpp
  ```
- **Root Cause**: OpenSSL 3.0 moved ARC4 (RC4) into the `legacy` provider DLL (`legacy.dll`). On Windows, `OSSL_PROVIDER_load(NULL, "legacy")` fails if the environment variable `OPENSSL_MODULES` does not point to the folder containing `legacy.dll`.
- **Solution (`src/shared/Auth/ARC4.cpp`)**:
  `EnsureOpenSSLProviders()` dynamically locates the server binary directory and explicitly configures `OPENSSL_MODULES`:
  ```cpp
  #if defined(_WIN32)
  char exePath[MAX_PATH];
  GetModuleFileNameA(NULL, exePath, MAX_PATH);
  PathRemoveFileSpecA(exePath);
  _putenv_s("OPENSSL_MODULES", exePath);
  #endif
  OSSL_PROVIDER_load(NULL, "legacy");
  OSSL_PROVIDER_load(NULL, "default");
  ```
  Ensure `legacy.dll` and `libcrypto-3-x64.dll` are placed in the directory where `mangosd.exe` runs.

---

## 2. Database Migration Audit & Schema Safeguards

All SQL migrations placed into `tortoise-wow/sql/database_updates/world/` must be validated using:
```powershell
powershell.exe -ExecutionPolicy Bypass -File "tools\porting\Audit-DatabaseMigrations.ps1"
```

### Issue 2.1: `UNKNOWN COLUMN: Column 'script_name' in UPDATE SET does not exist in table 'spell_template'`
- **Root Cause**: Modern VMaNGOS donor migrations assign script names directly via `UPDATE spell_template SET script_name = '...' WHERE entry = ...`. However, in some baseline Nostalrius schemas, `spell_template` does not define `script_name` by default.
- **Diagnostic Check**:
  Check `sql/base/world.sql` or run the audit script:
  ```
  Filename : 20260825052735_world.sql
  Status   : FAIL
  Issues   : {UNKNOWN COLUMN: Column 'script_name' in UPDATE SET does not exist in table 'spell_template'}
  ```
- **Safe Resolution Recipe**:
  If the C++ engine actively queries `script_name` (e.g. `SELECT entry, script_name FROM spell_template`), add an idempotent column creation header at the top of the migration:
  ```sql
  ALTER TABLE `spell_template` ADD COLUMN IF NOT EXISTS `script_name` VARCHAR(64) NOT NULL DEFAULT '' AFTER `Name`;
  ```
  Alternatively, update the base schema definition in `sql/base/world.sql` so that clean installations create the column.

---

### Issue 2.2: Progressive Versioning Columns (`patch`, `build`)
- **Root Cause**: Upstream VMaNGOS uses progressive database versioning to support client patches 1.2 through 1.12. Statements like:
  ```sql
  INSERT INTO `creature_template` (`entry`, `patch`, `build`, `name`) VALUES (12345, 0, 5875, 'Defias Pillager');
  ```
  will fail on Tortoise-WoW because `patch` and `build` columns do not exist in Turtle's schema.
- **Remediation**:
  Use `.\tools\porting\Convert-VmangosMigration.ps1` or manually strip `patch` and `build` columns from the `INSERT` or `UPDATE` statements prior to committing.

---

### Issue 2.3: Custom Content Entity ID Collision (IDs >= 300000)
- **Root Cause**: Turtle-WoW reserves entry IDs $\ge 300000$ for custom content:
  - Custom Items: 300000+ (High Elf items, fashion items, dungeon rewards)
  - Custom Creatures: 300000+ (Turtle unique NPCs, Goblin vendors)
  - Custom Quests: 300000+ (Turtle custom storylines)
- **Remediation**:
  Never accept an upstream migration that modifies or deletes an ID $\ge 300000$. If a donor commit introduces a new entity with ID $\ge 300000$, re-map that entity to the next available vanilla slot ($< 300000$).

---

## 3. Runtime Crash Patterns & Triage Playbooks

### Pattern 3.1: Null Pointer Dereference in Packet Broadcaster (`m_broadcaster`)
- **Symptom**: Crash dump with access violation in `Map::Remove(Player*)` or `CharacterHandler::HandlePlayerLoginOpcode`.
- **Mechanism**: If a player disconnected while their session was pending logout delay, or if an account was kicked while logging in, `pPlayer->m_broadcaster` was accessed without checking for `nullptr`.
- **Defensive Invariant (`PORT-0024`, `PORT-0026`)**:
  ```cpp
  // Always guard broadcaster dereference:
  if (player->m_broadcaster)
      player->m_broadcaster->SetInstanceId(GetInstanceId());
  ```

---

### Pattern 3.2: Floating Point Bias & Out-of-Bounds in `GetRandomPoint`
- **Symptom**: Airborne creatures (flying mounts, bats, dragonhawks) cluster along a 45-degree angle or path through terrain.
- **Mechanism**: Baseline contained a duplicate multiplication bug (`sin(randAngle2) * sin(randAngle2)`).
- **Defensive Invariant (`PORT-0022`)**:
  Ensure true 3D spherical math is used:
  ```cpp
  float randAngle1 = rand_norm_f() * 2 * M_PI;
  float randAngle2 = rand_norm_f() * M_PI - (M_PI / 2.0f);
  rand_x = x + randDist * cos(randAngle1) * cos(randAngle2);
  rand_y = y + randDist * sin(randAngle1) * cos(randAngle2);
  rand_z = z + randDist * sin(randAngle2);
  ```

---

### Pattern 3.3: Iterator Invalidation in Concurrent Loot Notifications
- **Symptom**: Intermittent segfault / crash in `LootMgr.cpp` during 40-man raid boss looting.
- **Mechanism**: Modifying `m_playersLooting` using post-increment iteration (`i_next = i; ++i_next; m_playersLooting.erase(i); i = i_next;`).
- **Defensive Invariant (`PORT-0008`)**:
  Always use the iterator returned by `erase()`:
  ```cpp
  for (auto i = m_playersLooting.begin(); i != m_playersLooting.end(); )
  {
      if (ShouldRemove(*i))
          i = m_playersLooting.erase(i);
      else
          ++i;
  }
  ```

---

## 4. Forum Intelligence Query Recipes (`resources/forum/`)

Before adapting any donor commit touching combat formulas, talents, spells, or item stats, query the 22,155 archived forum threads in `twow project/resources/forum/`:

```powershell
# Query for class changes:
cd "C:\Users\Admin\AntigravityProfiles\Projects\twow project"
.\tools\porting\Search-ForumArchive.ps1 -Query "Holy Strike" -Category Spells

# Query for bug reports:
.\tools\porting\Search-ForumArchive.ps1 -Query "Chain Heal" -Category Bugs

# Query for developer hotfix changelogs:
.\tools\porting\Search-ForumArchive.ps1 -Query "Moonfury" -Category "Development & Updates"
```

### Interpretation Rule:
- If a forum thread by `Torta [Turtle WoW Team]` or an official patch document (e.g. `Patch 1.15.0`, `Patch 1.16.1 Class Changes`, `Patch 1.17.2`) explicitly designed the mechanic to differ from vanilla:
  - **DO NOT OVERWRITE WITH VANILLA CODE.**
  - Document the candidate as `DO NOT PORT - Intentional Turtle Divergence` in `docs/BACKPORT_HISTORY.md`.

---

## 5. Worktree Cleanup & Candidate Quarantine Runbook

Because all candidate adaptations and builds execute inside isolated Git worktrees (`.worktrees/PORT-XXXX/`), errors never corrupt the user's primary working tree:

```powershell
# 1. Cleanly prune the failed candidate worktree
powershell.exe -ExecutionPolicy Bypass -File "tools\task.ps1" worktree-cleanup

# 2. If already committed to a candidate branch and needs retraction
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" branch -D port/PORT-XXXX-<sha>

# 3. Update canonical state store
# Candidate state transitions to REJECTED in tools/state/state_store.json

# 4. Strict Safety Principle
# NEVER run 'git checkout .' or 'git reset --hard' on the target repository!
# The primary checked-out tree is always kept clean and protected.
```

---

## 6. AI Semantic Adaptation Diagnostics & Staging Triage

When `task port <sha>` or `task port-batch <N>` stages a package with status `AWAITING_AI_ADAPTATION`:

### Diagnostic Procedure:
1. **Open the AI Dossier**:
   Inspect `tools/queue/ai_dossiers/<sha>.md` to review:
   - Target files and lines in `tortoise-wow`.
   - The exact reason naive `git apply` failed (e.g. `Formulas.h:82 patch does not apply`).
   - Any forum intelligence hits.
2. **Identify the Divergence**:
   Compare the upstream donor diff with the local Turtle file. Common causes:
   - Custom parameter additions (e.g. `bool inGurubashiArena = false`).
   - 64-bit debuff streaming masks (`UI64LIT`).
   - Custom spell or race ID bounds (`MAX_RACES = 11`).
3. **Synthesize & Author Adapted Patch**:
   - Write the adapted patch to `tools/queue/staging_patches/<sha>.patch`.
   - Verify it applies cleanly:
     ```powershell
     git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" apply --check "tools/queue/staging_patches/<sha>.patch"
     ```
4. **Compile & Gate (`task 1`)**:
   - Run `task 1` to execute the MSVC 2022 compile gate, git commit, and push!

---

## 7. Database Scalping, Entity Extraction & Caching Safeguards

### Issue 7.1: Monolithic SQL Multi-Table Row Collisions
- **Symptom**: Extracting an item (e.g. ID `19019`) from `world_full_14_june_2021.sql` matches unrelated rows from other tables sharing the same primary key ID (e.g. `quest_template`, `gameobject_template`).
- **Root Cause**: Monolithic MySQL dumps contain unpartitioned `INSERT INTO` statements across 300+ tables.
- **Defensive Safeguard (`Extract-DbEntity.ps1`)**:
  - The scalper parses table schemas dynamically to count expected column tokens ($N_{ref}$).
  - Candidate rows are strictly filtered where `tokens.Count >= $refCols.Count - 5`.
  - For progressive databases (Choice 2: `mangos.sql`), the script validates the `patch` column via `[int]::TryParse`.

---

### Issue 7.2: Progressive Column Stripping (`patch`, `build`)
- **Symptom**: Importing scalped SQL into `tortoise-wow` fails with:
  ```
  ERROR 1054 (42S22): Unknown column 'patch' in 'field list'
  ```
- **Remediation**:
  The scalper engine (`task scalp <type> <id> -ExportSql`) automatically strips `patch`, `build`, `patch_min`, and `patch_max` before emitting `REPLACE INTO` statements. Always use `-ExportSql` or verify via `Audit-DatabaseMigrations.ps1`.

---

### Issue 7.3: PowerShell Quoting and Backtick Escaping in Dynamic SQL
- **Symptom**: Generated SQL contains truncated column names or unmatched quotes like `` `col` `` becoming `` `col" ``.
- **Root Cause**: PowerShell interprets backtick (`` ` ``) as the escape character when inside double-quoted string literals.
- **Engineering Invariant**:
  Always use explicit character codes:
  ```powershell
  $bt = [char]96
  $escapedCol = "$bt$colName$bt"
  ```

---

### Issue 7.4: Zero Double-Checking Cache Validation (`restoration_history.json`)
- **Symptom**: Re-auditing the same topic or running batch restoration wastes time re-scanning thousands of files.
- **Safeguard**:
  `Invoke-CoreRestore.ps1` maintains an atomic persistent ledger in `tools/queue/restoration_history.json`. Topics with verified `PARITY` are returned from cache in <0.05 seconds. To force a full re-scan, pass `-Force`.

---

### Issue 7.5: Concurrency Safety & `-AutoBuild` Mutual Exclusion
- **Question**: Can `-AutoBuild` be run concurrently in multiple terminals?
- **Answer**: **NO.** `-AutoBuild` triggers MSVC compilation and `git push` on `tortoise-wow`. Multiple simultaneous builds create compiler file locks on `.obj` / `.pdb` files and can corrupt the Git index.
- **Safe Concurrent Practice**: Run research and staging tasks (`task scalp`, `task 6`, `task ai-audit`, `task restore-batch`, `task port`) concurrently across multiple terminals without `-AutoBuild`, then execute `task 1` once to compile and commit all staged packages sequentially.