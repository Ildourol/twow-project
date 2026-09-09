# AGENT 1: Builder & Committer (Single Writer Execution)

**Role**: Builder, Compiler, and Candidate Branch Committer  
**Command Alias**: `task 1`  
**Execution Mode**: Strictly sequential single-writer (holds exclusive lock on MSVC build system and candidate worktree).

---

## 1. Primary Objectives
1. Check `tools/queue/02_ready_to_build/` for the next available pre-vetted candidate package.
2. Verify package freshness against current target base HEAD; invalidate stale packages whose base SHA does not match.
3. Spawn an isolated Git worktree at `.worktrees/PORT-XXXX/` on an isolated branch (`port/PORT-XXXX-<sha>`).
4. Apply the C++ patch and SQL migration inside the isolated worktree.
5. If database migrations were added, validate using `tools/porting/Audit-DatabaseMigrations.ps1`.
6. Compile the server using the MSVC 2022 x64 toolchain under the selected build profile (achieving 0 compiler errors and 0 linker errors on `realmd.exe` and `mangosd.exe`).
7. Execute disposable startup smoke test (`task smoke`).
8. Commit strictly code/SQL files to the isolated candidate branch. **Never commit directly to main without authorization.**
9. Cleanly remove the isolated worktree via `Remove-IsolatedWorktree`. Never execute `git checkout .` or `git reset --hard` on the target repo.
10. Update canonical state store (`tools/state/state_store.json`), move package to `03_completed/`, and update local tracking ledgers.

---

## 2. Step-by-Step Runbook (`task 1`)

### Step 1: Scan for Ready Package
Inspect `tools/queue/02_ready_to_build/`.
- **If empty**: Output idle message and stop.
- **If package found** (e.g. `PORT-0001.json` or `CORE-0001.json`), read the package metadata:
  - Check `target_base_sha`: Verify it matches `git -C tortoise-wow rev-parse HEAD`. If target HEAD moved, mark package `STALE` and trigger re-audit.
  - Check `status`: If `AWAITING_AI_ADAPTATION`, skip until adapted.

### Step 2: Create Isolated Worktree
```powershell
New-CandidateWorktree -TargetRepo "tortoise-wow" -CandidateId $packageId -BaseSha $targetBaseSha
```
* The user's main checkout is never dirtied or modified.
* All changes, compilation, and testing occur inside `.worktrees/$packageId/`.

### Step 3: Apply Changes Inside Worktree
1. Apply the patch:
   ```powershell
   git -C "$worktreePath" apply --ignore-whitespace "<patch_path>"
   ```
2. If SQL migration is included:
   Copy `<sql_file>` into:
   `$worktreePath\sql\database_updates\world\`

### Step 4: Run Pre-Build Invariant Audits
1. Run database migration audit (exit code must be 0):
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "tools/porting/Audit-DatabaseMigrations.ps1" -MigrationFile "<sql_path>"
   ```
2. Run Turtle compatibility audit (exit code must be 0):
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "tools/porting/Verify-TurtleCompatibility.ps1" -TargetRepo "$worktreePath"
   ```

### Step 5: Execute MSVC 2022 Compilation & Smoke Test
1. Select patch-aware build profile (`world`, `auth`, `playerbots`, `sql-only`).
2. Compile inside worktree build directory:
   ```powershell
   cmake --build "$worktreePath/build" --config Release --target mangosd
   ```
3. Run disposable server smoke test:
   ```powershell
   Invoke-ServerSmokeTest -TargetRepo "$worktreePath" -Mode Fast
   ```
4. **If build or smoke test fails**:
   - Do NOT commit.
   - Extract triage report via `task crash` or `task triage`.
   - Remove isolated worktree cleanly via `Remove-IsolatedWorktree`. Main working tree remains pristine.
   - Record failure in state store.

### Step 6: Commit to Candidate Branch
1. Stage only code and SQL inside worktree:
   ```powershell
   git -C "$worktreePath" add src/ sql/ CMakeLists.txt
   git -C "$worktreePath" commit -m "<formatted_commit_message>"
   ```
2. Prune and remove worktree:
   ```powershell
   Remove-IsolatedWorktree -WorktreePath "$worktreePath" -TargetRepo "tortoise-wow"
   ```

### Step 7: Update Canonical State & Local Ledgers
1. Update `tools/state/state_store.json` transition state to `COMPLETE`.
2. Move package from `02_ready_to_build/` to `03_completed/`.
3. Update `docs/COMMITS_UPLOADED.md`, `docs/BACKPORT_HISTORY.md`, and `docs/ROADMAP.md`.
