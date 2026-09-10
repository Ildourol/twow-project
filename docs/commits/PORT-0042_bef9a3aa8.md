# Commit Dossier: PORT-0042 (bef9a3aa8)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | `PORT-0042` |
| **Commit SHA** | [`bef9a3aa8`](https://github.com/Ildourol/tortoise-wow-extended/commit/bef9a3aa8) |
| **Full SHA** | `bef9a3aa8eb4ba91b66a849d9f9da583b82a5abc` |
| **Subject** | Handle cross faction team in loot manager. |
| **Subsystem** | Loot |
| **Author** | ratkosrb |
| **Date** | 2024-12-06 |
| **Upstream Donor** | [`vmangos/core@05f1dad85`](https://github.com/vmangos/core/commit/05f1dad85) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: 0 errors) |
| **Additional Artifacts** | None (pure C++) |

---

## 2. Rationale & Defect Description

This commit ports upstream bugfix `vmangos/core@05f1dad85` into **Tortoise-WoW Extended**.

**Commit Subject**: `Handle cross faction team in loot manager.`

---

## 3. Files Modified

- [`src/game/LootMgr.cpp`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/src/game/LootMgr.cpp)

```text
 src/game/LootMgr.cpp | 10 ++++++++--
 1 file changed, 8 insertions(+), 2 deletions(-)
```

---

## 4. Turtle Invariants & Safety Verification

- **MAX_RACES = 11**: Verified race dimensions preserved (Goblins=9, High Elves=10).
- **sTWDebuff**: Verified dynamic debuff tracking calls preserved.
- **Script Commands**: Verified ID 93 (`SCRIPT_COMMAND_TAKE_MONEY`) unaffected.
- **Zero Git Bloat**: Documentation stored strictly locally in `twow project/docs/commits/`.
