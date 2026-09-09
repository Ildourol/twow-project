# AGENT 6: Online Database Oracle & 1.18.1 Asset Auditor

**Role**: Online Database Verification, 1.18.1 Client Parity, Live CDN Delta Tracking & Asset Inspection  
**Command Aliases**:
- `task 6 <id or name>` — Cross-reference item, NPC, spell, or quest with online DB viewer
- `task 6 changelog` — View live database deltas and spawn updates from online CDN
- `task db-viewer <query>` — Full named alias  
**Execution Mode**: Concurrent Read-Only & Web Cross-Referencing (zero locks, zero builds).

---

## 1. Primary Objectives

1. **Verify Database Entities against Official Turtle Database**:
   - Query [`https://xian55.github.io/tortoise-db-viewer/`](https://xian55.github.io/tortoise-db-viewer/) to verify items, spells, creature stats, quest relations, and gameobjects.
   - Cross-reference live Turtle-WoW 1.18.1 values (damage, armor, drop chances, vendor prices, stats) before applying any database migrations from upstream donors.
2. **Track Live Database Deltas**:
   - Query online CDN changelog (`cdn-dev/data/changelog.json`) to see what has recently changed in the official Turtle-WoW database.
3. **Interactive 3D Visual & Tooltip Audit**:
   - Use `-OpenBrowser` to inspect 3D models, armor textures, NPC appearances, and rendered in-game tooltips directly in the browser.
4. **Local vs. Online Parity**:
   - Compare values between `tortoise-wow/sql/base/*.sql` and the online SQLite database compiled from official server dumps.

---

## 2. Online URLs & API Mapping

| Entity Type | Direct Online Viewer URL Format | Purpose |
| :--- | :--- | :--- |
| **Item** | `https://xian55.github.io/tortoise-db-viewer/?item=<id>` | Stats, drop rate, vendor cost, 3D model |
| **Creature / NPC** | `https://xian55.github.io/tortoise-db-viewer/?npc=<id>` | Health, damage, loot table, spawn locations |
| **Spell / Aura** | `https://xian55.github.io/tortoise-db-viewer/?spell=<id>` | Spell attributes, coefficients, rank progression |
| **Quest** | `https://xian55.github.io/tortoise-db-viewer/?quest=<id>` | Quest giver, turn-in, XP, item rewards |
| **GameObject** | `https://xian55.github.io/tortoise-db-viewer/?object=<id>` | Traps, chests, doors, interactive objects |
| **Live Search** | `https://xian55.github.io/tortoise-db-viewer/?search=<query>` | Substring search across all entities & gossip |
| **Changelog** | `https://xian55.github.io/tortoise-db-viewer/?changelog` | Live diff between vanilla and Turtle-WoW |

---

## 3. Step-by-Step Runbook (`task 6`)

### Scenario A: Verifying an Item Template (`task 6 19019`)
```powershell
& "...\tools\task.ps1" 6 19019
```
1. Searches `tortoise-wow/sql/base/` for matching SQL rows.
2. Generates the exact online URL: `https://xian55.github.io/tortoise-db-viewer/?item=19019`.
3. Verifies that the upstream donor item attributes match official Turtle 1.18.1 client tooltips.

### Scenario B: Checking Live Official DB Deltas (`task 6 changelog`)
```powershell
& "...\tools\task.ps1" 6 changelog
```
1. Connects to `raw.githubusercontent.com/xian55/tortoise-db-viewer/cdn-dev/data/changelog.json`.
2. Displays recent additions and spawn deltas.

### Scenario C: Visual Inspection in Browser (`task 6 <id> -OpenBrowser`)
```powershell
& "...\tools\task.ps1" 6 19019 -OpenBrowser
```
Launches Microsoft Edge or default browser directly to the interactive 3D viewer.

---

## 4. Architectural Notes & Operational Guidance

### 4.1. Why Agent 6 / SQL Tasks Do NOT Use `-AutoBuild`
- **Read-Only Oracle Nature**: Agent 6 is an analytical research oracle designed to inspect web data and SQLite CDN schemas. It does not author C++ code.
- **SQL Does Not Require MSVC Compilation**: Database migrations (`sql/database_updates/world/`) are pure SQL scripts applied directly to MySQL; they do not require compiling `mangosd.exe` or `realmd.exe`.
- **Compiler Lock Collisions**: Running an unsupervised `-AutoBuild` during database lookups or scalper queries would unnecessarily invoke MSVC, monopolizing the compiler lock and colliding with Agent 1's single-writer build gate.

### 4.2. Integration with the Database Scalper (`task scalp -OpenViewer`)
When scalping an entity from `brotalnia/database` or `vmangos/core`:
```powershell
& "...\tools\task.ps1" scalp item 19019 -Diff -OpenViewer
```
This triggers Agent 6 to launch the official Turtle database viewer in Microsoft Edge simultaneously, allowing the engineer to visually inspect the 3D model, drop rates, and rendered tooltips alongside the differential SQL analysis.
