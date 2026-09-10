# Commit Dossier: PORT-0037 (ed1ac4c56)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | `PORT-0037` |
| **Commit SHA** | [`ed1ac4c56`](https://github.com/Ildourol/tortoise-wow-extended/commit/ed1ac4c56) |
| **Full SHA** | `ed1ac4c56f532a387aa9d711786c9ce1cb613bf3` |
| **Subject** | Possible fix to XP per kill rounding issue (#3032) |
| **Subsystem** | General Systems |
| **Author** | cpevors |
| **Date** | 2025-05-17 |
| **Upstream Donor** | [`vmangos/core@47c79c8d3`](https://github.com/vmangos/core/commit/47c79c8d3) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: 0 errors) |
| **Additional Artifacts** | None (pure C++) |

---

## 2. Rationale & Defect Description

This commit ports upstream bugfix `vmangos/core@47c79c8d3` into **Tortoise-WoW Extended**.

**Commit Subject**: `Possible fix to XP per kill rounding issue (#3032)`

---

## 3. Files Modified

- [`src/game/Formulas.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/src/game/Formulas.h)

```text
 src/game/Formulas.h | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```

---

## 4. Turtle Invariants & Safety Verification

- **MAX_RACES = 11**: Verified race dimensions preserved (Goblins=9, High Elves=10).
- **sTWDebuff**: Verified dynamic debuff tracking calls preserved.
- **Script Commands**: Verified ID 93 (`SCRIPT_COMMAND_TAKE_MONEY`) unaffected.
- **Zero Git Bloat**: Documentation stored strictly locally in `twow project/docs/commits/`.
