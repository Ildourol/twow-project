# AGENT 2: Forum Scout & Bug Prover (Read-Only Analysis)

**Role**: Forum Intelligence, Bug Proofing, and Divergence Auditor  
**Command Alias**: `task 2 <sha or topic>`  
**Execution Mode**: 100% Concurrent Read-Only (no locks, no git writes, no builds).

---

## 1. Primary Objectives
1. Receive a candidate donor commit hash (e.g. `task 2 ef7b84552`) or subsystem keyword.
2. Read the upstream bug report and diff in `reference-upstreams/vmangos-core`.
3. Search the 22,155 historical threads in `resources/forum/` using `tools/porting/Search-ForumArchive.ps1`.
4. Determine whether:
   - The bug is present in Turtle WoW 1.18.1 source/DB -> **VALID PORT CANDIDATE**.
   - Turtle developers intentionally modified the mechanic (custom racials, class balance patches, custom spell IDs >= 40000) -> **DO NOT PORT (Intentional Divergence)**.
   - Turtle already natively solved the issue -> **DO NOT PORT (Already Solved)**.
5. Create a candidate dossier in `tools/queue/01_candidates/<sha>.json` for Agents 3 and 4 to consume.
6. Update Agent 2's activity ledger in `docs/ROADMAP.md`.

---

## 2. Step-by-Step Runbook (`task 2 <sha>`)

### Step 1: Inspect Upstream Donor Commit
```powershell
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core" show <sha> --stat
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core" show <sha>
```
Extract:
- Commit subject & author
- Files and symbols touched (e.g. `SpellAuras.cpp`, `Unit::CalculateMeleeDamage`, `spell_template`)
- The underlying defect being fixed (e.g. crash, exploit, math drift, broken chain)

### Step 2: Query the Forum Intelligence Archive
Search the forum archive across relevant categories (`Bugs`, `Spells`, `Combat`, `Quests`, `Development & Updates`):
```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\Search-ForumArchive.ps1" -Query "<symbol_or_mechanic_name>" -Category <Category>
```
Key Patch Checkpoints:
- `Patch 1.15.0`: Custom Goblins & High Elves racials.
- `Patch 1.16.1`: Class Balance reworks (Holy Strike, Moonfury, etc.).
- `Patch 1.17.2` & `Patch 1.18.0`: Spells, Karazhan Crypts, itemization.

### Step 3: Verify Bug Presence in Turtle-WoW 1.18.1
Inspect the target file in `twow project/tortoise-wow/` (read-only):
- Check if the offending logic exists in Turtle base.
- If Turtle already has a different design or custom manager (`sTWDebuff`, `CustomMerchantMgr`), note how the adaptation must respect it.

### Step 3.5: Supersession & Obsolete Fix Safeguard
- Check whether newer VMaNGOS commits or Penqle upstream already solved or refactored this logic in a cleaner way.
- **Rule**: Never approve an outdated intermediate fix. If a later commit superseded this logic, either link the modern SHA or flag as `DO NOT PORT - SUPERSEDED`.

### Step 4: Output Candidate Evaluation
Save candidate file to `tools/queue/01_candidates/<sha>.json`:
```json
{
  "donor_sha": "<sha>",
  "subsystem": "<Subsystem>",
  "title": "<Title>",
  "verdict": "APPROVED_FOR_PORT",
  "forum_references": [
    "2021-11-06 Final Class Changes 1.16.1.txt"
  ],
  "turtle_invariants_to_preserve": [
    "Must retain MAX_RACES = 11",
    "Must preserve sTWDebuff streaming call"
  ],
  "requires_database": false,
  "status": "AWAITING_ADAPTATION"
}
```
If verdict is `DO NOT PORT`:
- Set `"verdict": "DO NOT PORT"`.
- Record explanation in `docs/BACKPORT_HISTORY.md` under Section 4 (Architectural Exclusions).
- Update Agent 2 log in `docs/ROADMAP.md`.
