# Upstream Porting Policy & Engineering Standards

## 1. Guiding Principles

1. **Intent Over Literal Text**:
   Upstream commits are evidence of bugfixes, performance enhancements, and behavioral corrections. They are not drop-in patches. The target codebase diverges in module organization, threading rules, and custom content. Reimplement the fix natively.
2. **Smallest Native Patch**:
   Prefer the minimal changes necessary in the target's native files to resolve the defect. Do not import surrounding refactors or foreign coding conventions.
3. **No Foreign Architectural Intrusion**:
   Do not introduce alien frameworks or dependencies (e.g. CMaNGOS database stores, non-standard threading models) when existing target facilities accomplish the objective.
4. **Preserve Turtle WoW Contracts**:
   - 11 playable races (`MAX_RACES = 11`, including High Elf & Goblin).
   - Protected custom entities: Spells $\ge 40000$, Creatures/Objects/Items/Quests $\ge 300000$.
   - 64-bit debuff streaming (`sTWDebuff`).
   - Protected managers: `sLFTMgr`, `sTransmogMgr`, `sCustomMerchantMgr`.

---

## 2. Lane-Specific Porting Methodology

### 2.1. CMaNGOS PlayerBots Lane (`playerbots`)
CMaNGOS is actively developed and frequently incorporates enhancements spanning Classic, TBC, and WotLK.
- **Always a Native Manual Port**.
- **Audit Steps**:
  1. Inspect upstream diff, commit subject, and commit body.
  2. Filter out multi-expansion branches (`#if defined(MANGOSBOT_ONE) || defined(MANGOSBOT_TWO)`).
  3. Map affected symbols using `cmangos-compat-shim.h` or target-native equivalents (`ObjectGuidSet`, `AreaEntry`, `Transport`).
  4. Implement changes within `modules/mod-playerbots/src/playerbot/`.
  5. Check impact on `modules/mod-dungeon-clear`.
  6. Compile and link `mangosd`.

### 2.2. vMaNGOS PlayerBots Lane (`core`)
vMaNGOS is structurally closer to the target's underlying core.
- **Adapted Port**.
- **Audit Steps**:
  1. Inspect diff in `src/game/PlayerBots/`.
  2. Map file paths to target location `modules/mod-playerbots/src/playerbot/`.
  3. Verify whether target already contains the fix under another revision or commit message.
  4. Ensure no core regressions or conflict with Turtle module interfaces.
  5. Compile and link `mangosd`.

---

## 3. Commit Granularity & Provenance

- **One Logical Fix = One Target Commit**: Do not create bloated batches containing unrelated fixes.
- **Combined Fix Chains**: When upstream fixes a bug in commit A and immediately patches a flaw in commit B, port the consolidated, correct solution in a single commit.
- **Commit Message Standard**:
  ```git
  playerbots: <concise summary of fix/enhancement>

  Upstream: <cmangos|vmangos>
  Upstream Commit: <source-sha>
  Subsystem: <Movement|Combat|Travel|Item|Spell|Dungeon|Lifecycle>

  Intent:
  <Description of problem and fix>

  Turtle Adaptations:
  <Details on target-specific API mappings or Dungeon Clear considerations>

  Verification:
  Build target modules and linked mangosd (Release x64 MSVC 2022).
  ```
- **Provenance Rules**: Upstream provenance (CMaNGOS/vMaNGOS SHAs) must be accurately stated. Never mention internal workspace or temporary references.
