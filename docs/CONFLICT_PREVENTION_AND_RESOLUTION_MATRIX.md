# Conflict Prevention and Resolution Matrix

This document provides a comprehensive technical guide, collision heatmap, invariant enforcement protocols, and resolution playbooks for all categories of conflicts that may occur during the development, synchronization, and backporting lifecycle of **Tortoise-WoW Extended**.

---

## 1. Multi-Upstream Topology & Collision Architecture

Tortoise-WoW Extended exists at the confluence of multiple evolving upstream codebases:

```
                  +---------------------------------------+
                  |         Turtle-WoW Upstream           |
                  |     (Penqle/tortoise-wow @ main)      |
                  |     Authoritative Host & Features     |
                  +---------------------------------------+
                                      |
                                      v [HOST SYNC]
+--------------------------+     +--------------------------+     +--------------------------+
|       VMaNGOS Core       |     |  Tortoise-WoW Extended   |     |    Module-playerbots     |
| (vmangos/core @ develop) | ==> | (Ildourol/tortoise-wow)  | <== | (Shyalya / ManTech /     |
|   Modern Vanilla Fixes   |     |    Active Porting Hub    |     |  cmangos playerbots)     |
+--------------------------+     +--------------------------+     +--------------------------+
             ^                                |
             | [Archaeology]                  v [Protocol & Assets]
+--------------------------+     +--------------------------+
|      Elysium Core &      |     | Client Data 1.18.1 (DBC, |
|  Light's Hope DB History |     | Maps, VMaps, MMaps 7272) |
+--------------------------+     +--------------------------+
```

Because these repositories evolve independently, conflicts occur across **four distinct fault lines**:
1. **Penqle Host Synchronization**: When upstream `Penqle/tortoise-wow` modifies files touched by our 34 backports.
2. **VMaNGOS Donor Invariants**: When VMaNGOS donor commits violate Turtle's 10-race system, dynamic debuff limits, script enums, or database schemas.
3. **Module-Playerbots Coexistence**: When core modifications alter combat timing, movement, or packet broadcasters relied on by Playerbots.
4. **Client 1.18.1 Protocol Divergence**: When 1.12.1 vanilla packet structures, opcodes, or DBC layouts clash with Turtle client Build 7272.

---

## 2. Collision Heatmap: Critical Source Files & AI Adaptation Targets

The following table identifies high-risk collision zones across the core server where Turtle-WoW has custom implementations that the AI must preserve during semantic synthesis:

| File Path | Collision Risk | High-Risk Methods / Blocks | AI Preservation & Adaptation Strategy |
| :--- | :---: | :--- | :--- |
| `src/game/Formulas.h` | **CRITICAL** | `GetHonorGain`, `BaseGain`, `XP::BaseGainLevelFactor` | Preserve Turtle's custom parameters (`bool inGurubashiArena = false`); adapt early-return formulas and float constants cleanly without touching signature. |
| `src/game/Objects/Unit.cpp` | **CRITICAL** | `AttackerStateUpdate`, `CalculateMeleeDamage`, `SendMeleeAttackStop`, `setDeathState` | Preserve `SendAttackStateUpdate` *before* `DealMeleeDamage`; retain `HITINFO_BLOOD_SPURT`; retain `isDead` boolean parameter in `SendMeleeAttackStop`. |
| `src/game/Objects/Player.cpp` | **CRITICAL** | `AddItemToBuyBackSlot`, `SendQuestUpdateAddItem`, `RepopAtGraveyard`, `SwapItem`, `sTaxiPathNodesByPath` bounds | Keep `oldest_slot = i`; preserve quest slot offset index; keep East facing (`facing == 0.0f`) check; keep bag capacity check. |
| `src/game/Spells/Spell.cpp` | **HIGH** | `SetTargetMap` (Chain Heal), `CheckCasterAuras` (Blink stunned check), `CheckCast` (Water checks) | Retain Chain Heal `continue` (not `break`); retain `!(unitflag & UNIT_FLAG_STUNNED)` in silence check; retain falling blink Z-clamp. |
| `src/game/Spells/SpellAuras.cpp` | **HIGH** | `HandleModResistMissChance`, `HandleAuraTransform`, `Aura::~Aura()`, dynamic debuff hooks | Retain spell modifier heap deallocation; retain `m_auraScripts` cleanup in destructor; protect `sTWDebuff` streaming hooks and `UI64LIT` 64-bit masks. |
| `src/game/Objects/GameObject.cpp` | **MEDIUM** | `GetInteractionPoint`, `IsInLineOfSight`, `HasBoundingBox` | Maintain fallback to center point + 1.0f Z when display info has zero bounding box. |
| `src/game/LootMgr.cpp` | **MEDIUM** | `NotifyLootList`, `NotifyItemRemoved`, master loot threshold checks | Ensure `i = m_playersLooting.erase(i)` is preserved; do not revert to Nostalrius hack. |
| `src/game/WorldSession.cpp` | **MEDIUM** | `WorldSession::Update`, `LogoutPlayer` | Ensure broadcaster is detached via `ChangeSocket(nullptr)` rather than premature destruction. |
| `src/game/Maps/Map.cpp` | **LOW** | `Map::Add`, `Map::Remove`, `Map::ExistingPlayerLogin` | Ensure `m_broadcaster` null checks remain around `SetInstanceId` and `RemoveListener`. |
| `src/shared/Auth/ARC4.cpp` | **HIGH** | `EnsureOpenSSLProviders`, OpenSSL 3.x provider loading | Never revert to hardcoded `dep/windows` OpenSSL 1.1 paths without modern vcpkg fallback (`BUILD-0001`, `053cb501f`). |
| `CMakeLists.txt` | **HIGH** | OpenSSL search block | Preserve vcpkg OpenSSL 3.x detection block. |

---

## 3. Invariant Conflict Catalog & Binding Rules

### Conflict INV-01: The 10-Race System (`MAX_RACES = 11`)
- **Nature of Conflict**: Vanilla 1.12.1 and VMaNGOS define 8 playable races (`MAX_RACES = 9` or `10`). Turtle WoW natively supports Goblins (`RACE_GOBLIN = 9`) and High Elves (`RACE_HIGH_ELF = 10`), setting `#define MAX_RACES 11`.
- **Symptoms of Violation**:
  - Buffer overflow or heap corruption when a High Elf or Goblin character is created, logs in, or casts spells.
  - Silent failure in racial stat modifiers or skill evaluations.
- **Enforcement Rule**:
  ```cpp
  // FORBIDDEN (VMaNGOS assumption):
  for (uint8 r = 0; r < 9; ++r) { ... }
  uint32 racialData[9];

  // MANDATORY IN TORTOISE-WOW:
  for (uint8 r = 0; r < MAX_RACES; ++r) { ... }
  uint32 racialData[MAX_RACES];
  ```
- **Automated Guard**: Checked by `.\tools\porting\Verify-TurtleCompatibility.ps1`.

---

### Conflict INV-02: Script Command Collision (`SCRIPT_COMMAND_TAKE_MONEY` vs `SCRIPT_COMMAND_FOLLOW_ESCORT`)
- **Nature of Conflict**:
  - Upstream VMaNGOS assigned enum ID `93` to `SCRIPT_COMMAND_FOLLOW_ESCORT` (commits `ef7b84552`, `1246926c8`).
  - Turtle WoW (`Penqle/tortoise-wow` @ `c478cdad`) natively assigned enum ID `93` to `SCRIPT_COMMAND_TAKE_MONEY`.
- **Symptoms of Violation**:
  - Overwriting `93` causes quests or gossip scripts that charge player money to instead execute escort follow commands!
- **Resolution Playbook**:
  1. Inspect `src/game/ScriptMgr.h`:
     ```cpp
     SCRIPT_COMMAND_TAKE_MONEY       = 93, // Natively owned by Turtle WoW
     SCRIPT_COMMAND_FOLLOW_ESCORT    = 94, // ADAPTED: Allocated next unassigned ID
     ```
  2. In `src/game/ScriptCommands.cpp`, route case `94` to the escort follow handler.
  3. If database scripts use command 93 for taking money, they will continue functioning flawlessly.

---

### Conflict INV-03: Dynamic Debuff Limit (`sTWDebuff`) vs Vanilla 16-Slot Auras
- **Nature of Conflict**:
  - Vanilla WoW cores store only 16 debuffs in standard unit update fields.
  - Turtle WoW bypasses this restriction with a dedicated streaming manager `sTWDebuff` (`src/game/TWDebuff/TWDebuff.hpp`).
- **Symptoms of Violation**:
  - Porting VMaNGOS aura application logic that replaces `Unit::AddAura` or `Unit::RemoveAura` without invoking `sTWDebuff->AddDebuff` / `RemoveDebuff` causes debuffs beyond slot 16 to vanish from client unit frames.
- **Resolution Playbook**:
  - Whenever porting changes to `Unit.cpp` or `SpellAuras.cpp`:
    ```cpp
    // Ensure these calls remain at all aura entry/exit points:
    sTWDebuff->AddDebuff(this, holder);
    sTWDebuff->RemoveDebuff(this, holder);
    ```

---

### Conflict INV-04: Custom ID Space Reservation ($\ge 40000$ & $\ge 300000$)
- **Nature of Conflict**:
  - Turtle WoW reserves Spells $\ge 40000$ and World Database entities $\ge 300000$ for custom content (High Elf/Goblin racials, custom talents, custom dungeon loot, survival equipment).
- **Symptoms of Violation**:
  - Upstream donor commits introducing new spells or items into these ID ranges will clobber Turtle custom items or spells.
- **Resolution Playbook**:
  - All vanilla entity fixes must reside strictly in vanilla ID space ($< 40000$ for spells, $< 300000$ for world entities).
  - Any upstream donor ID $\ge 300000$ must be re-mapped into an unallocated vanilla slot.

---

### Conflict INV-05: Database Progressive Columns & Schema Alignment
- **Nature of Conflict**:
  - VMaNGOS uses progressive versioning columns (`` `patch` ``, `` `build` ``, `` `patch_min` ``, `` `patch_max` ``).
  - Tortoise-WoW uses a static Nostalrius-derived world database schema where these columns **do not exist**.
  - Additionally, modern migrations often reference columns like `spell_template.script_name` that may be missing from stock `sql/base/` definitions.
- **Symptoms of Violation**:
  - `Audit-DatabaseMigrations.ps1` reports `UNKNOWN COLUMN: Column 'patch' does not exist in table '...'` or `Column 'script_name' does not exist in table 'spell_template'`.
- **Resolution Playbook**:
  1. Strip all progressive columns from ported SQL statements.
  2. If the C++ engine queries a column (e.g. `script_name` in `spell_template`), provide an idempotent DDL update:
     ```sql
     ALTER TABLE `spell_template` ADD COLUMN IF NOT EXISTS `script_name` VARCHAR(64) NOT NULL DEFAULT '' AFTER `Name`;
     ```
  3. Validate with `.\tools\porting\Audit-DatabaseMigrations.ps1`.

---

## 4. Cross-Suite Conflicts with Module-playerbots

The adjacent suite in `C:\Users\Admin\AntigravityProfiles\Projects\Module-playerbots` provides autonomous bot companions. Several core subsystems modified by our backports directly touch Playerbot hooks:

```
[ Tortoise-WoW Core Fixes ]             [ Module-playerbots Subsystem ]
PORT-0033: Attack State Dispatch  <--->  Bot Threat & Combat Trigger Logic
PORT-0022: 3D Spherical Points    <--->  Bot Flying / Roaming Generators
PORT-0014: Master Loot Threshold  <--->  Bot Master Loot Evaluation
PORT-0026: Broadcaster Detachment <--->  Bot Virtual Session Lifecycles
```

### 1. Combat Attack State Timing (`PORT-0033`, `f91a73c21`)
- **Core Change**: `SendAttackStateUpdate(&damageInfo)` is dispatched *before* `DealMeleeDamage(&damageInfo, true)`.
- **Bot Impact**: Playerbot AI monitors `AttackerStateUpdate` and damage hooks to calculate threat, aggro switches, and reaction heals. Because damage is dealt immediately after packet dispatch, Bot event listeners in `DealDamage` receive the exact same values without timing delays.
- **Compatibility Verdict**: **Fully compatible**. Bots receive timely death events without packet desync.

### 2. 3D Spherical Coordinate Generation (`PORT-0022`, `a23ddec56`)
- **Core Change**: Replaced biased 2D polar formula with mathematically correct 3D spherical generation in `WorldObject::GetRandomPoint`.
- **Bot Impact**: Playerbots running flying mounts or airborne pet pathing now receive valid spherical waypoints rather than biased diagonal paths or coordinates clamped inside mountains.
- **Compatibility Verdict**: **Enhanced stability**.

### 3. Packet Broadcaster Detachment (`PORT-0025` / `PORT-0026`)
- **Core Change**: `ChangeSocket(nullptr)` is used during session teardown instead of deleting the broadcaster.
- **Bot Impact**: Playerbots use simulated virtual sessions (`WorldSession` without real network sockets). Ensuring that `m_broadcaster` pointers are safely guarded against `nullptr` prevents crashes when bots leave maps or disband groups.
- **Compatibility Verdict**: **Essential stability guard**.

---

## 5. Client 1.18.1 Protocol & DBC Conflicts

| Protocol / Asset Dimension | Vanilla 1.12.1 (Build 5875) | Turtle WoW 1.18.1 (Build 7272) | Conflict Prevention Invariant |
| :--- | :--- | :--- | :--- |
| `SMSG_ATTACKSTOP` Packet | Packet often sent with 0 in second field or missing GUID. | Requires target GUID + `uint32(isDead ? 1 : 0)` flag (`PORT-0027`). | Never revert `isDead` parameter in `Unit::SendMeleeAttackStop`. |
| `SMSG_ATTACKERSTATEUPDATE` | Often batched or sent post-death in legacy cores. | Requires victim resolution before death state (`PORT-0033`). | Keep `SendAttackStateUpdate` ahead of `DealMeleeDamage`. |
| Coordinate Packing | Float truncation (`int(val / 0.25f)`). | Requires float rounding (`int(std::round(val * 4.0f))`) (`PORT-0009`). | Prevents client-side micro-jitter and terrain desync. |
| `SkillRaceClassInfo.dbc` | Vanilla has 8 races. | 10 races with new race/class combinations (Goblin Hunter, High Elf Paladin, etc.). | Always use `GetSkillRaceClassInfo()` helper rather than vanilla DBC row math. |
| `WorldSafeLocs.dbc` | Vanilla orientation handling. | Facing = 0.0 radians represents East (`PORT-0016`). | Use `sObjectMgr.HasWorldSafeLocFacing()` rather than truthy float check. |

---

## 6. Git Synchronization & Conflict Resolution Runbooks

### Runbook A: Synchronizing with Upstream Penqle (`origin/main`)

When `Penqle/tortoise-wow` releases new commits on GitHub:

```powershell
# 1. Fetch latest changes from authoritative host
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" fetch origin main

# 2. Check for overlapping files between our 34 commits and incoming commits
$localCommits = git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" rev-list origin/main..main
$incomingCommits = git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" rev-list main..origin/main

# 3. Perform a rebase or merge
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow" rebase origin/main
```

#### If Conflict Occurs During Rebase:
1. Run `git status` to identify conflicting files.
2. Open the conflicting file and locate the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
3. Cross-reference `docs/DELETED_CODE_AND_DELTA_AUDIT.md` to identify which portion belongs to our backport.
4. **Resolution Criteria**:
   - If Penqle implemented their own fix for the same bug, inspect both. If Penqle's fix is functionally equivalent or superior, adopt Penqle's version and record the commit as `SUPERSEDED_BY_PENQLE` in `BACKPORT_HISTORY.md`.
   - If Penqle changed surrounding context, adapt our minimal semantic fix into their new structure.
   - **Never discard our invariants** (`MAX_RACES = 11`, `sTWDebuff`, OpenSSL 3.x detection).
5. Stage the resolved files: `git add <file>`
6. Continue rebase: `git rebase --continue`
7. Run build verification: Compile `realmd` and `mangosd` on MSVC 2022 x64.
8. Run compatibility audit: `.\tools\porting\Verify-TurtleCompatibility.ps1`.

---

### Runbook B: Handling Candidate Port Conflicts

When investigating a candidate commit from `reference-upstreams/vmangos-core`:

```powershell
# 1. Inspect donor commit
git -C "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core" show <donor_sha>

# 2. Run Forum Intelligence check
cd "C:\Users\Admin\AntigravityProfiles\Projects\twow project"
.\tools\porting\Search-ForumArchive.ps1 -Query "<mechanic_or_spell>" -Category Spells

# 3. Check for Intentional Turtle Divergences:
#    - If forum thread or patch notes confirm Turtle intentionally changed this mechanic:
#      MARK AS "DO NOT PORT - INTENTIONAL TURTLE DIVERGENCE" in BACKPORT_HISTORY.md.
#    - If verified as a true vanilla bug present in Turtle:
#      Extract minimal semantic diff and apply.
```