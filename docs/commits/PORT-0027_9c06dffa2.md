# Commit Dossier: PORT-0027 (9c06dffa2)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | `PORT-0027` |
| **Commit SHA** | [`9c06dffa2`](https://github.com/Ildourol/tortoise-wow-extended/commit/9c06dffa2) |
| **Full SHA** | `9c06dffa25051500d88890cfd76be902df9a9cff` |
| **Subject** | GetHeightStatic: Add a delta to Z before choosing vmap height over map height (#3487) |
| **Subsystem** | Maps / VMap |
| **Author** | Gamemechanic |
| **Date** | 2026-07-17 |
| **Upstream Donor** | [`vmangos/core@46d789256`](https://github.com/vmangos/core/commit/46d789256) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: 0 errors) |
| **Additional Artifacts** | None (pure C++) |

---

## 2. Rationale & Defect Description

This commit ports upstream bugfix `vmangos/core@46d789256` into **Tortoise-WoW Extended**.

**Commit Subject**: `GetHeightStatic: Add a delta to Z before choosing vmap height over map height (#3487)`

---

## 3. Files Modified

- [`src/game/Maps/GridMap.cpp`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/src/game/Maps/GridMap.cpp)

```text
 src/game/Maps/GridMap.cpp | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

---

## 4. Turtle Invariants & Safety Verification

- **MAX_RACES = 11**: Verified race dimensions preserved (Goblins=9, High Elves=10).
- **sTWDebuff**: Verified dynamic debuff tracking calls preserved.
- **Script Commands**: Verified ID 93 (`SCRIPT_COMMAND_TAKE_MONEY`) unaffected.
- **Zero Git Bloat**: Documentation stored strictly locally in `twow project/docs/commits/`.
