# AGENT 4: AI Context Assembler & C++ Semantic Adapter

**Role**: AI Semantic Context Assembly, C++ Adaptation, Invariant Enforcement, and Patch Authoring  
**Command Alias**: `task ai-audit <sha>` (alias: `task 4 <sha>`)  
**Execution Mode**: Concurrent Reader & AI Dossier / Patch Author (generates isolated AI dossiers in `tools/queue/ai_dossiers/` and `.patch` files without modifying `tortoise-wow` working tree).

---

## 1. Primary Objectives
1. Take a candidate donor commit SHA (e.g. `task ai-audit 84f1bbccd` or `task 4 84f1bbccd`).
2. Run `tools/porting/Invoke-AiAudit.ps1` to assemble commit diff, target source files in `tortoise-wow/src/`, surrounding code lines, and 22,155-thread forum intelligence into an AI Dossier (`tools/queue/ai_dossiers/<sha>.md`).
3. Adapt the fix from donor C++14 to Turtle-WoW C++17:
   - Modernize syntax (`nullptr`, `std::string_view`, structured bindings).
   - Enforce **MAX_RACES = 11** (Goblins=9, High Elves=10; race arrays must be sized to 11).
   - Enforce **sTWDebuff** (never omit or relocate `sTWDebuff->AddDebuff()` or `RemoveDebuff()` calls).
   - Enforce **Script Enums** (preserve `SCRIPT_COMMAND_TAKE_MONEY = 93`; remap foreign commands to >93).
   - Enforce **Custom Zone Parameters** (preserve `inGurubashiArena`, custom racials, etc.).
   - Enforce **Broadcaster Safety** (always guard `m_broadcaster` with null checks).
   - Preserve **Turtle Custom Managers** (`LFTMgr`, `TransmogMgr`, `Shop`, `CustomMerchantMgr`).
4. Generate a verified, clean git patch file and save to `tools/queue/staging_patches/<sha>.patch`.
5. Assemble the final package in `tools/queue/02_ready_to_build/PORT-XXXX.json` so Agent 1 can immediately build and push.
6. Update Agent 4 ledger in `docs/ROADMAP.md`.

---

## 2. Step-by-Step Runbook (`task 4 <sha>`)

### Step 1: Inspect Upstream Donor C++ Diff
```powershell
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core" show <sha> -- "src/*"
```
Identify:
- Exact modified functions, classes, and logic.
- Any foreign headers or modern C++20/C++23 features that need translation.

### Step 1.5: Supersession & Modern State Check (Crucial Safeguard)
Verify that this donor fix was not subsequently superseded or rewritten by a later VMaNGOS commit:
```powershell
# Check git log of the modified file in vmangos-core after <sha>
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core" log <sha>..HEAD -n 5 -L :<FunctionName>:<FilePath>
```
* **Rule**: If a later commit rewrote or improved this fix, **adopt the modern final version**, or flag the candidate as `DO NOT PORT - SUPERSEDED BY <NEWER_SHA>`. Never backport an outdated intermediate fix.

### Step 2: Locate Target in `tortoise-wow`
Search for target symbols in `tortoise-wow/src/`:
```powershell
Select-String -Path "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow\src\*" -Pattern "<FunctionName>"
```
*Note: Due to code divergence, locate by symbol or method name rather than line numbers.*

### Step 3: Apply Turtle Invariants
Review the proposed code against the 5 Danger Zones:
1. **Races**: If race loops or arrays are touched, is `MAX_RACES` (11) used?
2. **Debuffs**: If aura application/removal is touched, are `sTWDebuff` streaming calls retained?
3. **Modules**: Are AzerothCore module hooks preserved?
4. **Broadcaster**: Is `player->m_broadcaster` guarded against `nullptr`?
5. **C++17**: Is the code clean C++17 compliant without deprecated macros?

### Step 4: Author the Patch File
Generate a unified git diff patch file and save to:
`tools\queue\staging_patches\<sha>.patch`

Verify patch applicability (dry-run):
```powershell
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" apply --check "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\queue\staging_patches\<sha>.patch"
```

### Step 5: Assemble Ready-to-Build Package
Create the package in `tools/queue/02_ready_to_build/PORT-XXXX.json`:
```json
{
  "donor_sha": "<sha>",
  "subsystem": "<Subsystem>",
  "title": "<Title>",
  "patch_file": "tools/queue/staging_patches/<sha>.patch",
  "sql_file": "tools/queue/staging_sql/<sha>_world.sql",
  "commit_msg": "Port(<Subsystem>): <Title> (vmangos/core@<short_sha>)\n\nBackported from vmangos/core@<sha>\n- Adapted to Turtle C++17\n- Preserved Turtle invariants",
  "status": "READY_FOR_BUILD"
}
```

Record completed adaptation in `docs/ROADMAP.md`.

Output the completion notification banner:
```text
================================================================================
[PACKAGE STAGED — READY FOR AGENT 1]
--------------------------------------------------------------------------------
Package PORT-XXXX (<sha>) is assembled in 'tools/queue/02_ready_to_build/'.
C++ patch: tools/queue/staging_patches/<sha>.patch
SQL status: Attached (or pure C++)

>>> ACTION REQUIRED: You can now run 'task 1' in CLI 1 to compile and push! <<<
================================================================================
```
