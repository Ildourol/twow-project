# AGENT 1: Builder & Committer (Single Writer Execution)

**Role**: Builder, Compiler, and Git Committer  
**Command Alias**: `task 1`  
**Execution Mode**: Strictly sequential single-writer (holds exclusive lock on `tortoise-wow/` and MSVC build system).

---

## 1. Primary Objectives
1. Check `tools/queue/02_ready_to_build/` for the next available pre-vetted candidate package.
2. Apply the C++ patch and SQL migration to `twow project/tortoise-wow/`.
3. If database migrations were added, validate using `tools/porting/Audit-DatabaseMigrations.ps1`.
4. Compile the server using the MSVC 2022 x64 toolchain (achieving 0 compiler errors and 0 linker errors on both `realmd.exe` and `mangosd.exe`).
5. Stage ONLY source code (`src/`), database migrations (`sql/`), or toolchain files (`CMakeLists.txt`). **Never stage markdown documentation into git.**
6. Create an atomic git commit with standardized upstream donor attribution.
7. Push immediately to `extended main`.
8. Move the processed candidate package from `02_ready_to_build/` to `03_completed/`.
9. Update the local tracking ledgers: `docs/COMMITS_UPLOADED.md`, `docs/BACKPORT_HISTORY.md`, and `docs/ROADMAP.md`.

---

## 2. Step-by-Step Runbook (`task 1`)

### Step 1: Scan for Ready Package
Inspect `tools/queue/02_ready_to_build/`.
- **If empty**: Output the following clear message and stop:
  ```text
  ================================================================================
  [QUEUE STATUS: IDLE — NOTHING TO COMMIT]
  --------------------------------------------------------------------------------
  No candidate packages found in 'tools/queue/02_ready_to_build/'.
  The Git working tree is clean at baseline BUILD-0001 (053cb501f).
  
  Next Steps:
  1. Check docs/ROADMAP.md for the next candidate SHA (e.g. 448df9ba0).
  2. Run AI Port: & "...\tools\task.ps1" port <sha> (or task port <sha> -AutoBuild).
  3. Or run granular agents: task 2 <sha> (forum), task 3 <sha> (DB), task ai-audit <sha> (AI).
  4. Once package is staged, run 'task 1' to compile and push.
  ================================================================================
  ```
- **If package found** (e.g. `PORT-0001.json` or `CORE-0001.json`), read the package metadata:
  - `status`: If status is `AWAITING_AI_ADAPTATION` or `AWAITING_CODE`, Agent 1 safely skips this package without error until an AI agent or developer adapts the code.
  - `donor_sha`: Full and short donor commit SHA (for PORT packages) or topic name (for CORE packages).
  - `subsystem`: Target subsystem (e.g. `Combat`, `Spells`, `Inventory`, `Custom`).
  - `title`: Imperative commit title or restoration feature name.
  - `patch_file`: Path to the `.patch` in `tools/queue/staging_patches/`.
  - `sql_file`: Path to the `.sql` in `tools/queue/staging_sql/` (if applicable).
  - `commit_msg`: Formatted commit message.

### Step 2: Apply Changes to `tortoise-wow`
1. Check that the working tree is clean:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" status --short
   ```
2. Apply the C++ patch:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" apply --ignore-whitespace "<patch_path>"
   ```
3. If an SQL migration is included:
   Copy `<sql_file>` into:
   `C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow\sql\database_updates\world\`

### Step 3: Run Pre-Build Audits
1. If SQL migration was added, run:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Audit-DatabaseMigrations.ps1"
   ```
   Ensure output reports `0 Errors, 0 Warnings`.
2. Run Turtle compatibility audit:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Verify-TurtleCompatibility.ps1" -TargetRepo "tortoise-wow"
   ```

### Step 4: Execute MSVC 2022 x64 Compilation Gate
Build using CMake and MSVC:
```powershell
& "C:\vcpkg\downloads\tools\cmake-4.4.2-windows\cmake-4.4.2-windows-x86_64\bin\cmake.exe" --build "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow\build" --config Release
```
* **Gate Requirement**: Must produce Exit Code 0 with 0 errors on both `realmd.exe` and `mangosd.exe`.
* **If build fails**:
  - Do NOT commit or push.
  - Investigate the compiler error.
  - If introduced by adaptation syntax, fix it directly.
  - If unresolvable blocker, run `git checkout .`, flag candidate as `BLOCKED`, and move to quarantine.

### Step 5: Stage, Commit & Push
1. Stage ONLY code and SQL:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" add src/ sql/ CMakeLists.txt
   ```
2. Commit with standardized donor attribution:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" commit -m "<formatted_commit_message>"
   ```
3. Push immediately to remote:
   ```powershell
   git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" push extended main
   ```

### Step 6: Execute Mandatory Documentation Gate & Advance Queue
Before proceeding to any next fix or closing the task, Agent 1 must complete the synchronized documentation steps:

1. **Move Manifest to Completed**:
   ```powershell
   Move-Item "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\queue\02_ready_to_build\<package_file>" "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\queue\03_completed\"
   ```

2. **Update Uploaded Commits Ledger (`docs/COMMITS_UPLOADED.md`)**:
   Append a row to the table with commit number, SHA, ID, subsystem, subject, donor link, additional files, and `Verified` status.

3. **Update Deep Backport History (`docs/BACKPORT_HISTORY.md`)**:
   Append a detailed entry with date, commit SHA, donor upstream, subsystem, modified files, and defect summary.

4. **Update Commits Dossier Archive (`docs/commits/`)**:
   Run the dossier generator to create `docs/commits/<ID>_<shortSha>.md` and update `docs/commits/README.md`:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Generate-CommitDossiers.ps1"
   ```

5. **Update Master Roadmap (`docs/ROADMAP.md`)**:
   - Increment `Total Uploaded Commits` count.
   - Update `Current Head SHA`.
   - Update Agent 1 ledger with the newly completed commit ID and SHA.
