# Upstream Porting Policy & Engineering Standards

Current interpretation: ADR-009 permits fast or batch verification to defer full linking. The strict per-commit ladder below describes full-link mode. Deferred checks remain pending until run against the recorded revision; they are not evidence of a completed port. See [documentation map](DOCUMENTATION_MAP.md).

## 1. Guiding Principles

1. **Intent Over Literal Text**:
   Upstream commits are evidence of bugfixes, performance enhancements, and behavioral corrections. They are not drop-in patches. The target codebase diverges in module organization, threading rules, and custom content. Reimplement the fix natively.
2. **Smallest Native Patch**:
   Prefer the minimal changes necessary in the target's native files to resolve the defect. Do not import surrounding refactors or foreign coding conventions.
3. **No Foreign Architectural Intrusion**:
   Do not introduce alien frameworks or dependencies (e.g. CMaNGOS database stores, non-standard threading models) when existing target facilities accomplish the objective.
4. **Preserve Turtle WoW Contracts**:
   - 10 playable races (IDs 1-10; exclusive bound 11) (`MAX_RACES = 11`, including High Elf & Goblin).
   - Protected custom entities: Spells $\ge 40000$, Creatures/Objects/Items/Quests $\ge 300000$.
   - custom debuff streaming (`sTWDebuff`).
   - Protected managers: `sLFTMgr`, `sTransmogMgr`, `sCustomMerchantMgr`.
5. **Strict Vanilla / Classic Exclusivity (Absolute Prohibition on TBC & WotLK)**:
   - This project is **strictly Vanilla** (Classic 1.12.1 / Turtle WoW 1.18.1 Classic+).
   - Porting **ANY** mechanics, spells, talents, strategies, items, or opcodes from TBC, WotLK, or later expansions is **STRICTLY PROHIBITED**.
   - Only changes directly relevant to Vanilla / Classic are allowed.
   - Any upstream commit targeting or relying on post-Vanilla mechanics must be completely disqualified (`EXPANSION_INCOMPATIBLE`).

---

## 2. Lane-Specific Porting Methodology

### 2.1. CMaNGOS PlayerBots Lane (`playerbots`)
CMaNGOS is actively developed and frequently incorporates enhancements spanning Classic, TBC, and WotLK.
- **Always a Native Manual Port**.
- **Audit Steps**:
  1. Inspect upstream diff, commit subject, and commit body.
  2. **Mandatory Vanilla Filter**: Inspect multi-expansion branches (`MANGOSBOT_ONE`, `MANGOSBOT_TWO`, TBC/WOTLK guards). Port only a separable Classic-relevant correction, omitting later-expansion behavior; mark a fix that requires those mechanics `EXPANSION_INCOMPATIBLE`. The presence of an expansion guard alone does not disqualify independent Classic code.
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

- **Strict 1-to-1 Commit Granularity (Batch Audit Allowed, Batch Commits Prohibited)**:
  - You MAY audit and triage candidate commits in batches for scanning efficiency.
  - Porting, adapting, verifying, committing, and pushing must occur strictly **commit-by-commit**.
  - **1 Upstream Donor Commit = 1 Target Git Commit = 1 Remote Push**.
  - Multiple upstream donor commits must **NEVER** be batched, squashed, or combined into a single target commit.
  - Every individual commit must be verified (`modules.lib` and `mangosd.exe`) and pushed to `playerbots` before proceeding to the next commit.
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
