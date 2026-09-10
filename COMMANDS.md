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

## 2. Strict Vanilla / Classic Exclusivity Mandate

All commands and automated pipelines operate under a strict, non-negotiable **Vanilla / Classic Exclusivity Invariant**:
- **Target Lineage**: Vanilla WoW (Classic 1.12.1 / Turtle WoW 1.18.1 Classic+).
- **Absolute Prohibition on TBC & WotLK**: Porting **ANY** features, spells, talents, combat mechanics, or opcodes from The Burning Crusade (TBC 2.x), Wrath of the Lich King (WotLK 3.x), or any later expansion is **STRICTLY PROHIBITED**.
- **Permitted Scope**: Only changes, bugfixes, and AI enhancements directly relevant to Vanilla and Classic mechanics are eligible for porting.
- **Automated Rejection**: Any upstream candidate commit that targets or requires post-Vanilla expansion systems is automatically classified as `EXPANSION_INCOMPATIBLE` (P3) and excluded from synchronization.

---

## 3. Command Specifications

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

### 2.7. VERIFY FAST, VERIFY FULL & VERIFY BATCH (BUILD EXECUTION OPTIONS)
```powershell
.\task.ps1 verify-fast   # (Alias: verify-quick) Rapid compilation of modules.lib (~3s)
.\task.ps1 verify-full   # Complete target server link (mangosd.exe, ~2-3m)
.\task.ps1 verify-batch  # Batch verification pass across multi-commit series
```
- **Option 1: Fast Incremental (Recommended Default)**: Run `verify-fast` after each individual commit. Eliminates 95% of token bloat and build wait time (~1.7s per commit, 12 cores, quiet). Run `verify-full` once at the end of the batch/phase.
- **Option 2: Batch Verification**: Commit candidate fixes sequentially to git to preserve 1-to-1 provenance and git bisectability. Defer compilation and run `verify-batch` (or `verify-full`) once all commits in the batch are applied.
- **Option 3: Strict Full-Link**: Run `verify-full` after each individual commit. Reserved for P0 core threading and engine refactors.

---

### 2.8. COMMIT AND PUSH (AUTOMATED 1-TURN PORT CYCLE)
```powershell
.\task.ps1 commit-and-push -DonorSha <sha> -Message "<commit message>" -Subsystem <name> -Priority <P0|P1> -Rationale "<notes>"
```
Executes the full post-edit atomic cycle in a single automated step:
1. Compiles target `modules.lib` with quiet flags (`/nologo /v:q`) across all 12 cores (~1.7s).
2. Stages changes (`git add -A`) and creates an atomic target Git commit on `mantech-turtle`.
3. Pushes the single commit immediately to `origin/mantech-turtle` via `--quiet`.
4. Updates `state/porting-ledger.json` and generates `docs/commits/PORT-XXXX_<sha>.md` automatically from template.

---

### 2.9. RECORD PORT (MANUAL LEDGER & DOSSIER GENERATION)
```powershell
.\task.ps1 record-port -DonorSha <sha> [-TargetSha <sha>] -Subsystem <name> -Priority <P0|P1> -Subject "<text>" -Rationale "<notes>"
```
Directly records a completed port in `state/porting-ledger.json` and synthesizes the standard markdown dossier in `docs/commits/` without running a build or git push.

---

### 2.10. BUILD OPTIONS
```powershell
.\task.ps1 build-options
```
Displays the active ADR-009 verification modes, parallelism settings, and token optimization rules.

---

### 2.11. ROADMAP
```powershell
.\task.ps1 roadmap
```
Displays current phase progress, prioritized backlog, and active porting tracks.

---

### 2.12. LEDGER
```powershell
.\task.ps1 ledger [cmangos|vmangos]
```
Displays tabular status of all audited, ported, skipped, duplicate, and rejected commits from `state/porting-ledger.json`.

---

### 2.13. UPDATE-UPSTREAMS (UPSTREAM SYNCHRONIZATION)
```powershell
.\task.ps1 update-upstreams [cmangos|vmangos|all]
```
*(Aliases: `sync-upstreams`, `pull-upstreams`)*

Fetches and fast-forwards upstream donor clones in `reference-upstreams/` (`core` and `playerbots`):
- Runs `git fetch --all --prune --tags` and `git pull --ff-only` on the upstream tracking branch.
- Displays the count and log of newly arrived commits so developers/agents can immediately inspect upstream changes with `git show <sha>`.
- **Safety**: Working project `tortoise-wow-extended` is strictly excluded from checkout/pull operations to protect active development.


