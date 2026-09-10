# Commit Dossier: PORT-0048 (facc2d80b)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | `PORT-0048` |
| **Commit SHA** | [`facc2d80b`](https://github.com/Ildourol/tortoise-wow-extended/commit/facc2d80b) |
| **Full SHA** | `facc2d80b62079dfceb33da559c15315ffb7b652` |
| **Subject** | Fix GeoLocking config check (#2010) |
| **Subsystem** | General Systems |
| **Author** | coolzoom |
| **Date** | 2023-07-01 |
| **Upstream Donor** | [`vmangos/core@2169f8207`](https://github.com/vmangos/core/commit/2169f8207) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: 0 errors) |
| **Additional Artifacts** | None (pure C++) |

---

## 2. Rationale & Defect Description

This commit ports upstream bugfix `vmangos/core@2169f8207` into **Tortoise-WoW Extended**.

**Commit Subject**: `Fix GeoLocking config check (#2010)`

---

## 3. Files Modified

- [`src/realmd/AuthSocket.cpp`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/src/realmd/AuthSocket.cpp)

```text
 src/realmd/AuthSocket.cpp | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

---

## 4. Turtle Invariants & Safety Verification

- **MAX_RACES = 11**: Verified race dimensions preserved (Goblins=9, High Elves=10).
- **sTWDebuff**: Verified dynamic debuff tracking calls preserved.
- **Script Commands**: Verified ID 93 (`SCRIPT_COMMAND_TAKE_MONEY`) unaffected.
- **Zero Git Bloat**: Documentation stored strictly locally in `twow project/docs/commits/`.
