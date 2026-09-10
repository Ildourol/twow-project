# Command Reference Manual

This manual details the execution syntax, parameter semantics, and expected output for the **Module-playerbots** task dispatcher (`task.ps1`).

---

## 1. Global Parameters & Modes

All scan and synchronization commands support three execution modes. When omitted, the mode **defaults to NORMAL**:

| Mode | Depth Level | Scope of Evaluation |
| :--- | :--- | :--- |
| **FAST** | Surface / Heuristic | Scans newly unscanned commits since watermark. Evaluates commit subject and diff header. Selects only high-confidence P0/P1 bugfixes without speculative features. |
| **NORMAL** | Standard (Default) | Fully inspects all commits in the watermark range. Evaluates AST signatures, affected files, expansion compatibility, and select stability/correctness fixes. |
| **DEEP** | Exhaustive Semantic | Performs deep historical analysis, traces caller chains, compares donor implementations between CMaNGOS and vMaNGOS, searches for semantic duplicates, and audits larger feature ports. |

---

## 2. Command Specifications

### 2.1. STATUS
```powershell
.\task.ps1 status
```
Displays high-level health and repository state:
- Target checkout path, active branch, and HEAD SHA.
- Target working tree cleanliness.
- Upstream CMaNGOS and vMaNGOS HEAD SHAs.
- Current watermark positions and unscanned commit counts.
- Selected, pending, ported, and rejected counts from the ledger.
- Latest successful build baseline evidence.

---

### 2.2. SCAN
```powershell
.\task.ps1 scan [cmangos|vmangos|all] [fast|normal|deep]
```
Audits new commits from the specified upstream source without modifying target files.
- Reads commit range: `WATERMARK..UPSTREAM_HEAD`.
- Classifies each commit according to the selection policy (`PORT`, `CRITICAL`, `RECOMMENDED`, `ALREADY_PRESENT`, `EXPANSION_INCOMPATIBLE`, `REJECTED`, etc.).
- Writes structured audit records into `reports/commit-audits/` and updates `state/porting-ledger.json`.
- Advances `source-watermarks.json` scan timestamp.

---

### 2.3. SYNC
```powershell
.\task.ps1 sync [cmangos|vmangos|all] [fast|normal|deep]
```
Executes the full automated backporting pipeline:
1. Fetches remote upstream updates.
2. Audits unscanned commits in the watermark range (batch auditing is permitted).
3. Selects eligible candidates meeting P0/P1 criteria.
4. Executes an atomic **commit-by-commit** porting loop for each selected candidate:
   a. Ports candidate natively into `tortoise-wow-extended`.
   b. Runs verification ladder (`modules.lib` compile and `mangosd.exe` link).
   c. Creates an individual, formatted target git commit with full provenance.
   d. Pushes the single commit immediately to remote branch `mantech-turtle`.
   e. Records the individual commit in `state/porting-ledger.json`.
   *(Batch commits and batch pushes are strictly prohibited.)*

---

### 2.4. IMPORT CRITICAL
```powershell
.\task.ps1 import-critical [cmangos|vmangos|all] [fast|normal|deep]
```
Filters specifically for high-severity P0 fixes:
- Server crashes and memory corruption.
- Assertions and invalid lifetimes.
- Critical bot lifecycle and provisioning failures.
- Severe dungeon/group AI breakdowns.
Ports and verifies only P0 candidates.

---

### 2.5. AUDIT
```powershell
.\task.ps1 audit <cmangos|vmangos> <commit-sha>
```
Performs a standalone audit of a single specified upstream commit without changing target code.
- Produces a comprehensive audit report detailing:
  - Commit author, date, and intent.
  - Affected files mapped to target paths.
  - Bug presence analysis in target.
  - Compatibility and Dungeon Clear assessment.
  - Recommended action and adaptation steps.
- Saves report to `reports/commit-audits/<source>-<sha>.json`.

---

### 2.6. PORT
```powershell
.\task.ps1 port <cmangos|vmangos> <commit-sha>
```
Directly ports an explicitly requested commit and its required dependencies.
- Applies necessary adaptations natively.
- Runs verification ladder (`modules.lib` and `mangosd.exe`).
- Updates `state/porting-ledger.json`.

---

### 2.7. VERIFY QUICK & VERIFY FULL
```powershell
.\task.ps1 verify-quick
.\task.ps1 verify-full
```
- `verify-quick`: Rapid syntax and module compilation (`modules.lib`).
- `verify-full`: Complete target server link (`mangosd.exe`) and test execution.

---

### 2.8. ROADMAP
```powershell
.\task.ps1 roadmap
```
Displays current phase progress, prioritized backlog, and active porting tracks.

---

### 2.9. LEDGER
```powershell
.\task.ps1 ledger [cmangos|vmangos]
```
Displays tabular status of all audited, ported, skipped, duplicate, and rejected commits from `state/porting-ledger.json`.
