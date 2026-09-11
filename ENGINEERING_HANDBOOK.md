# ENGINEERING_HANDBOOK.md: Technical Implementation Guide

Documentation status: test totals, timings, line numbers and case-study defect claims below are historical snapshots. Recheck the current source and run results; use [the documentation audit](docs/DOCUMENTATION_AUDIT_2026-09-11.md) for known corrections and limitations.

This handbook provides developers and AI agents with technical specifications, architectural comparisons, preservation invariants, concrete porting recipes, and coding standards for backporting fixes from **VMaNGOS** (`reference-upstreams/vmangos-core`, aliased via `core`) to **Tortoise-WoW** (`twow project/tortoise-wow-extended`, junction at `tortoise-wow`).

---

## 1. Architectural Comparison: VMaNGOS vs. Tortoise-WoW

While both servers share a common codebase root dating back to the Nostalrius/Elysium era (2016–2017), their architectural evolution has diverged in fundamental ways:

| Feature / System | VMaNGOS (`core`) | Tortoise-WoW (`tortoise-wow-extended`) | Engineering Implications |
| :--- | :--- | :--- | :--- |
| **C++ Standard** | `C++14` (`-std=c++14`) | `C++17` (`-std=c++17`) | Tortoise supports C++17 features (`std::string_view`, structured bindings, `std::optional`, `if constexpr`). VMaNGOS code can be modernized during porting. |
| **Client Version** | `1.12.1.5875` | `1.18.1.7272` | Packet structures, DBC field definitions, and opcodes may differ. Never assume packet layouts are identical. |
| **Playable Races** | 8 races (`MAX_RACES = 9`) | 10 races (`MAX_RACES = 11`) | Goblins (9) and High Elves (10) are playable. Static arrays sized to 8 or 9 will cause buffer overflows in Tortoise-WoW. |
| **Debuff Limits** | Vanilla 16 debuffs via update fields | Unlimited debuffs via `TWDebuff` streaming | Aura application/removal hooks must notify `sTWDebuff`. Standard update masks only convey the first 16 to unmodded clients. |
| **Module System** | Monolithic core build | AzerothCore module system (`modules/`) | Feature hooks and CMake module registration must remain intact. |
| **Database Migrations** | `sql/migrations/` | `sql/database_updates/world/` | SQL updates must be translated into Tortoise-WoW naming and format. |
| **Custom Features** | None (strict blizzlike) | LFT, Transmog, Mounts, Toys, Guild Bank, Shop, Dynamic Visibility, Optick | Custom managers must never be modified or bypassed by ported vanilla code. |

---

## 2. Danger Zones & Preservation Rules

Every developer and agent modifying Tortoise-WoW **must obey the following preservation invariants**:

### Danger Zone 1: The 10-Race System
In VMaNGOS, code frequently uses hardcoded race limits:
```cpp
// VMaNGOS (DANGEROUS IN TORTOISE-WOW)
for (int i = 0; i < 9; ++i) { ... }
uint32 raceArray[9];
```
In Tortoise-WoW, races include:
```cpp
enum Races
{
    RACE_HUMAN              = 1,
    RACE_ORC                = 2,
    RACE_DWARF              = 3,
    RACE_NIGHTELF           = 4,
    RACE_UNDEAD             = 5,
    RACE_TAUREN             = 6,
    RACE_GNOME              = 7,
    RACE_TROLL              = 8,
    RACE_GOBLIN             = 9,
    RACE_HIGH_ELF           = 10
};
#define MAX_RACES 11
```
**Rule**: Always check all ported race-dependent code for `MAX_RACES`. Ensure loops iterate up to `MAX_RACES` and arrays are sized to `MAX_RACES`. Verify that race masks (`RACEMASK_ALL_PLAYABLE`) include Goblins and High Elves.

---

### Danger Zone 2: `TWDebuff` Debuff Streaming Architecture
Vanilla WoW only supports 16 debuffs on a unit. Turtle-WoW bypasses this limit using a custom streaming manager:
`src/game/TWDebuff/TWDebuff.hpp`
In `src/game/Objects/Unit.cpp`:
```cpp
// Upon adding an aura:
sTWDebuff->AddDebuff(this, holder);

// Upon removing an aura:
sTWDebuff->RemoveDebuff(this, holder);
```
**Rule**: If porting aura application, aura expiration, or debuff dispelling logic from VMaNGOS, **never omit or relocate these `sTWDebuff` calls**. Doing so will cause debuffs beyond slot 16 to disappear from player client frames.

---

### Danger Zone 3: AzerothCore Module System
Tortoise-WoW includes an AzerothCore-derived module subsystem under `modules/` configured via:
- `src/cmake/macros/ConfigureModules.cmake`
- `modules/ModulesScriptLoader.h`
- `modules/ModulesLoader.cpp.in.cmake`

**Rule**: Never alter the hook call sites or CMake macro definitions that load modules. Modules can be built statically or dynamically; do not introduce non-modular dependencies into core files that modules depend on.

---

### Danger Zone 4: Custom Turtle Managers
Tortoise-WoW adds several custom singleton managers located in `src/game/`:
- `LFTMgr.h` / `LFTMgr.cpp` (Looking For Turtle / Dungeon Finder)
- `TransmogMgr.h` / `TransmogMgr.cpp` (Transmogrification)
- `MountManager.hpp` & `CompanionManager.hpp` & `ToyManager.hpp` (Collections)
- `CustomMerchantMgr.h` / `CustomMerchantMgr.cpp` (Custom currency vendors)
- `DynamicVisibilityMgr.h` / `DynamicVisibilityMgr.cpp` (Dynamic player visibility scaling)
- `DiscordBot/` & `HttpApi/` (External communications)

**Rule**: When porting changes to `WorldSession.cpp`, `Player.cpp`, `ChatHandler.cpp`, or `ObjectMgr.cpp`, preserve all calls and addon message routers directing traffic to these managers.

---

### Danger Zone 5: Client Protocol & Addon Messages
Turtle-WoW 1.18.1 relies heavily on hidden addon messages transmitted over `CMSG_MESSAGECHAT` / `SMSG_MESSAGECHAT` with special prefixes (e.g. `LFT`, `TW_TRANSMOG`, etc.).
**Rule**: Do not alter `ChatHandler.cpp` message filtering or packet lengths in ways that interfere with addon message prefixes. Always verify that opcode modifications in `src/game/Protocol/` align with the 1.18.1 client.

---

### Danger Zone 6: DBC Overrides (`SkillRaceClassInfo.dbc`)
Tortoise-WoW uses a custom DBC store for `SkillRaceClassInfo.dbc` (`sSkillRaceClassInfoStore`) to manage new race/class skill combinations:
```cpp
SkillRaceClassInfoEntry const* GetSkillRaceClassInfo(uint32 skill, uint8 race, uint8 class_);
```
**Rule**: When porting trainer or skill validation fixes from VMaNGOS, ensure skill checks evaluate `GetSkillRaceClassInfo` so new Goblin and High Elf class combinations are recognized.

---

### Danger Zone 7: Database Relational Schema & Migration Invariants
Tortoise-WoW operates on a Nostalrius-derived world database schema and preserves custom content ranges (`entry >= 300000`). Upstream VMaNGOS databases differ fundamentally in schema design:
1. **No Progressive Versioning Columns**: VMaNGOS tables frequently use `` `patch` ``, `` `build` ``, `` `patch_min` ``, `` `patch_max` `` to support dynamic progressive patches. In Tortoise-WoW, these columns **do not exist**. Never include them in `INSERT`, `UPDATE`, or `REPLACE` queries.
2. **Entity-Specific Range Protection**: Custom Turtle-WoW entities have distinct boundary spaces:
   - `spell_template` entries $\ge 40000$ are reserved for Turtle custom spells (e.g. Holy Strike, Moonfury, custom racials).
   - World template IDs $\ge 300000$ in `item_template`, `creature_template`, `gameobject_template`, and `quest_template` belong exclusively to custom Turtle content (e.g. High Elf / Goblin items, custom quests, new dungeons). Never overwrite or delete entries within these ranges during vanilla backporting.
3. **Reference Database Hierarchy**:
   - **Choice 1**: `tortoise-db-viewer` (`tortoise-db-viewer/` / `https://xian55.github.io/tortoise-db-viewer/`) — supporting reference for Turtle entities, tooltips and drops; target schema, migrations and native loaders remain authoritative.
   - **Choice 2**: `vmangos/core db_latest` (`reference-upstreams/vmangos-core/db_latest/mysql-dump/mangos.sql`) — donor comparison only; verify all column definitions against the target schema and loaders.
4. **C++ Engine Schema Alignment**: Ensure any column actively queried by the C++ engine (such as `SELECT DISTINCT(script_name) FROM spell_template`) is present in both `sql/base/` and the migration pipeline.
5. **Mandatory Automated Audit**: All migration files must be validated using `.\tools\porting\Audit-DatabaseMigrations.ps1` before committing.

---

## 3. Empirical Intelligence & Historical Verification (`resources/forum/`)

Before adapting any code from VMaNGOS into Tortoise-WoW, developers and AI agents must differentiate between:
1. **A True Vanilla Bug**: A mechanic broken in standard 1.12.1 that is also broken in Tortoise-WoW and should be fixed.
2. **An Intentional Turtle Divergence**: A mechanic intentionally redesigned or rebalanced by the Turtle-WoW design team (e.g. custom hybrid talents, racial passives, debuff limits, custom quest lines).

The authoritative source of truth for all intentional divergences is the **Turtle-WoW Official Forum Archive** located in [`resources/forum/`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/resources/forum) (22,155 threads, 2018–2026).

### 3.1. The Empirical Triage Protocol
Before modifying formulas, spells, creature scripts, or item stats:
1. Query the archive with [`tools/porting/Search-ForumArchive.ps1`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tools/porting/Search-ForumArchive.ps1):
   ```powershell
   .\tools\porting\Search-ForumArchive.ps1 -Query "<mechanic_name>" -Category <Subsystem>
   ```
2. Check for relevant **Major Patch Documents** (e.g. `Patch 1.15.0 - Goblins & High Elves`, `Patch 1.16.1 Class Changes`, `Patch 1.17.2 & Beyond - Class & Gameplay Changes`, `Patch 1.18.1 - Nightmares of Ursol`).
3. Check for **Developer Hotfix Threads** (`YYYY — Month DD.txt`) authored by `Torta [Turtle WoW Team]`.

### 3.2. Real-World Case Study: Spell Power Scaling Order
- **Upstream VMaNGOS behavior**: Modifiers applied multiplicatively before spell power bonuses.
- **Turtle-WoW Developer Hotfix** (`2023-04-08-14-49-12_2023 — April 8.txt`):
  > *"The damage bonus from the Moonfury talent now applies after spell power."*
  > *"The damage bonus from the Improved Curse of Agony talent now applies after spell power."*
- **Porting Action**: If porting aura/damage calculation improvements from VMaNGOS in `Unit::SpellDamageBonus`, the engineer must **preserve** the post-spellpower calculation order for Moonfury and Improved Curse of Agony rather than overwriting them with vanilla code.

---

## 4. Concrete Porting Recipes

### Recipe 1: Porting an Inventory / Player Fix
**Case Study: Buyback Slot Overwrite Bug** (VMaNGOS Commit `c78268059`)

#### Step 1: Analyze Upstream Commit
In VMaNGOS (`core`):
```diff
--- a/src/game/Objects/Player.cpp
+++ b/src/game/Objects/Player.cpp
@@ -11491,7 +11491,7 @@ void Player::AddItemToBuyBackSlot(Item* pItem, uint32 money, ObjectGuid vendorGu
             // found empty
             if (!m_items[i])
             {
-                slot = i;
+                oldest_slot = i;
                 break;
             }
```

#### Step 2: Locate in Tortoise-WoW
Search for `AddItemToBuyBackSlot` in `tortoise-wow/src/game/Objects/Player.cpp` (around line 13418).
Notice that Tortoise-WoW contains the exact same bug:
```cpp
        for (uint32 i = BUYBACK_SLOT_START + 1; i < BUYBACK_SLOT_END; ++i)
        {
            // found empty
            if (!m_items[i])
            {
                slot = i;  // <-- BUG: Gets overwritten below by slot = oldest_slot!
                break;
            }
            ...
        }
        // find oldest
        slot = oldest_slot;
```

#### Step 3: Apply & Adapt
Replace `slot = i;` with `oldest_slot = i;`.
Ensure variable naming and formatting match Tortoise-WoW standards.

#### Step 4: Verify
Ensure no other buyback methods were altered and compile.

---

### Recipe 2: Porting a Vendor Validation Fix
**Case Study: Vendor Template Validation** (VMaNGOS Commit `7b601d1c4`)

#### Upstream Fix:
```diff
- VendorItemData const* tItems = isTemplate ? nullptr : GetNpcVendorTemplateItemList(vendor_entry);
+ VendorItemData const* tItems = (!isTemplate && cInfo->vendor_id) ? GetNpcVendorTemplateItemList(cInfo->vendor_id) : nullptr;
```

#### Tortoise-WoW Location:
`tortoise-wow/src/game/ObjectMgr.cpp` in `ObjectMgr::IsVendorItemValid` (around line 8638).
Apply the correction while ensuring `CustomMerchantMgr` vendor templates are not obstructed.

---

### Recipe 3: Porting an Escort or Movement AI Fix
**Case Study: Pet Follower Speed & Escort Follow Angle** (VMaNGOS `a11272f8b`, `ef7b84552`)

1. Inspect `src/game/Movement/FollowMovementGenerator.cpp`.
2. Ensure angle formulas respect NPC vs Pet checks:
   ```cpp
   if (unit.IsPet())
       unit.UpdateSpeed(MOVE_RUN, true);
   ```
3. Check `src/scripts/world/` for escort quests and verify waypoint arrival distances.

---

### Recipe 4: Porting and Validating a Database Migration
**Case Study: Porting Creature / GameObject / Spell Fixes to Database**

#### Step 1: Analyze Upstream Migration
Inspect the upstream migration in `reference-upstreams/vmangos-core/sql/migrations/YYYYMMDDHHMMSS_world.sql`. Identify target tables, affected columns, and entity IDs.

#### Step 2: Cross-Reference Reference Databases
1. Consult **Main / Authoritative Database**: Turtle-WoW base catalog (`tortoise-wow/sql/base/`).
2. Consult **Choice 1 (Main Historic DB)**: Brotalnia `brotalnia/database` (`reference-upstreams/lights-hope-database-history/world_full_14_june_2021.sql` from `world_full_14_june_2021.7z`) for original vanilla entities unchanged by Turtle WoW.
3. Consult **Choice 2 (Backup Updated Donor DB)**: `vmangos/core db_latest` (`reference-upstreams/vmangos-core/db_latest/mysql-dump/mangos.sql`) for updated column definitions, constraints, and vanilla defaults.
4. Consult **Interactive Viewer & Dashboard**: `tortoise-db-viewer` (`task scalp <tbl> <id> -Diff` or `task dashboard <id>`) for instant tooltips and 3D assets.

#### Step 3: Sanitize Schema & Strip Progressive Columns
1. Strip all progressive columns (`` `patch` ``, `` `build` ``, `` `patch_min` ``, `` `patch_max` ``) from `INSERT` and `UPDATE` statements.
2. Strip stored procedure wrappers (`CALL AddMigration(...)`) and `DELIMITER` blocks.
3. Verify that table names match Tortoise-WoW catalog (tables with `tw_world_` prefix in base SQL map to standard table names in update scripts).

#### Step 4: Protect Turtle-WoW Custom Range & C++ Engine Parity
1. Verify that no custom IDs are clobbered: ensure `spell_template` IDs are $< 40000$ (reserve $\ge 40000$ for custom spells) and world templates (`item_template`, `creature_template`, `gameobject_template`, `quest_template`) are $< 300000$ (reserve $\ge 300000$ for custom world content).
2. If C++ code references a database column (e.g. `spell_template.script_name`), ensure the column is created via `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` if absent from base schema.

#### Step 5: Save & Validate Migration
1. Save the sanitized migration to:
   `twow project/tortoise-wow/sql/database_updates/world/YYYYMMDDHHMMSS_world.sql`
2. Execute the automated database audit script:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "tools\porting\Audit-DatabaseMigrations.ps1"
   ```
   Ensure the script outputs `ALL MIGRATIONS COMPLIANT: 0 Schema, Invariant, or Column Violations!`.

---

### Recipe 5: Scalping & Entity Extraction from Historical Databases (`task scalp` / `task extract`)
**Case Study: Extracting Vanilla Baseline & Reconciling with Turtle 1.18.1**

When restoring or fixing an item, creature, or spell where local SQL data is missing or diverged:

#### Step 1: Query the Scalper with Differential Analysis
Execute the scalper engine from any directory:
```powershell
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" scalp item 19019 -Diff
```
- The engine queries Turtle base SQL as primary, cross-references Brotalnia's `world_full_14_june_2021.sql` (Main Historic DB) for original vanilla values, and falls back to `mangos.sql` (VMaNGOS Choice 2 backup).
- Simultaneously fetches live model, tooltip, and relation metadata from `tortoise-db-viewer` (`https://api.tortoiseclothing.org`).
- Automatically compares every single column against `tortoise-wow/sql/base/`.
- Disambiguates rows by comparing column counts and parsing table schema definitions.

#### Step 2: Progressive Column Stripping & Turtle Column Preservation
1. Automatically detects and strips progressive versioning columns (`` `patch` ``, `` `build` ``).
2. Flags Turtle-exclusive custom columns (e.g. `` `is_custom_turtle_item` ``, custom debuff slots) so they are never clobbered.
3. Reports identical vs. diverged column counts.

#### Step 3: Online Verification
Cross-reference live client tooltips and 3D models via the official Turtle Database Viewer:
```powershell
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" scalp item 19019 -OpenViewer
```
Or directly query Agent 6:
```powershell
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" 6 19019
```

#### Step 4: Export Sanitized SQL
Generate a ready-to-run migration:
```powershell
& "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\task.ps1" scalp item 19019 -ExportSql
```
Outputs sanitized `REPLACE INTO` SQL to `tools/queue/staging_sql/<table_name>_<id>_<name>_sanitized.sql` with zero progressive column leaks and valid column backtick escaping.

---

## 5. Coding Standards & Best Practices

1. **C++17 Usage**:
   - Prefer `nullptr` over `NULL` or `0`.
   - Use `const` references for non-trivial objects.
   - Use `std::string_view` for read-only string parameters.
   - Use RAII guards for locking (e.g. `std::lock_guard<std::mutex>`).
2. **Assertions & Errors**:
   - Use `MANGOS_ASSERT(...)` for internal invariants.
   - Use `sLog.outError(...)` or `sLog.outErrorDb(...)` for recoverable errors.
3. **Memory Safety**:
   - Avoid manual pointer arithmetic.
   - Always check pointers returned by `LookupEntry`, `GetPlayer()`, `GetCreature()`.
   - Never retain raw pointers across async map updates or thread boundaries.

---

## 6. Git Commit Message Standard

All commits backporting VMaNGOS changes into Tortoise-WoW must follow this template:

```
Port(<Subsystem>): <Concise imperative description>

Backported from vmangos/core@<full_or_short_sha>
Upstream PR: #<number> (if applicable)
Compatibility Notes:
- Verified MAX_RACES handling.
- Verified sTWDebuff preservation.
- Checked against custom Turtle managers.
- Cross-referenced with Turtle forum archive (resources/forum/).
- Database Verified: Checked against Brotalnia (world_full_14_june_2021.sql), vmangos db_latest & tortoise-db-viewer; Audit-DatabaseMigrations.ps1 PASS.
```
