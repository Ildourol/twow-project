# Commit Dossier: PORT-0025 (ccdea97cd)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | `PORT-0025` |
| **Commit SHA** | [`ccdea97cd`](https://github.com/Ildourol/tortoise-wow-extended/commit/ccdea97cd) |
| **Full SHA** | `ccdea97cdd9173e8392b138956e2d59792118ea1` |
| **Subject** | Prevent pickpocketing humanoids and undead with no pickpocket loot (#2729) |
| **Subsystem** | World |
| **Author** | Simp-N |
| **Date** | 2026-07-20 |
| **Upstream Donor** | [`vmangos/core@80d3b7bee`](https://github.com/vmangos/core/commit/80d3b7bee) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: 0 errors) |
| **Additional Artifacts** | None (pure C++) |

---

## 2. Rationale & Defect Description

This commit ports upstream bugfix `vmangos/core@80d3b7bee` into **Tortoise-WoW Extended**.

**Commit Subject**: `Prevent pickpocketing humanoids and undead with no pickpocket loot (#2729)`

---

## 3. Files Modified

- [`src/game/Spells/Spell.cpp`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/src/game/Spells/Spell.cpp)

```text
 src/game/Spells/Spell.cpp | 3 +--
 1 file changed, 1 insertion(+), 2 deletions(-)
```

---

## 4. Turtle Invariants & Safety Verification

- **MAX_RACES = 11**: Verified race dimensions preserved (Goblins=9, High Elves=10).
- **sTWDebuff**: Verified dynamic debuff tracking calls preserved.
- **Script Commands**: Verified ID 93 (`SCRIPT_COMMAND_TAKE_MONEY`) unaffected.
- **Zero Git Bloat**: Documentation stored strictly locally in `twow project/docs/commits/`.
