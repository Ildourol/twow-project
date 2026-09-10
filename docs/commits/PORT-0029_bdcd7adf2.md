# Commit Dossier: PORT-0029 (bdcd7adf2)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | `PORT-0029` |
| **Commit SHA** | [`bdcd7adf2`](https://github.com/Ildourol/tortoise-wow-extended/commit/bdcd7adf2) |
| **Full SHA** | `bdcd7adf2373ba299ba785bec9d87a9c9d967203` |
| **Subject** | Update utf8cpp (#3383) |
| **Subsystem** | Core |
| **Author** | _BLU |
| **Date** | 2026-04-29 |
| **Upstream Donor** | [`vmangos/core@454afdc0b`](https://github.com/vmangos/core/commit/454afdc0b) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: 0 errors) |
| **Additional Artifacts** | None (pure C++) |

---

## 2. Rationale & Defect Description

This commit ports upstream bugfix `vmangos/core@454afdc0b` into **Tortoise-WoW Extended**.

**Commit Subject**: `Update utf8cpp (#3383)`

---

## 3. Files Modified

- [`dep/include/utf8cpp/LICENSE`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/LICENSE)
- [`dep/include/utf8cpp/README.md`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/README.md)
- [`dep/include/utf8cpp/doc/ReleaseNotes`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/doc/ReleaseNotes)
- [`dep/include/utf8cpp/doc/utf8cpp.html`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/doc/utf8cpp.html)
- [`dep/include/utf8cpp/utf8.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/utf8.h)
- [`dep/include/utf8cpp/utf8/checked.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/utf8/checked.h)
- [`dep/include/utf8cpp/utf8/core.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/utf8/core.h)
- [`dep/include/utf8cpp/utf8/cpp11.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/utf8/cpp11.h)
- [`dep/include/utf8cpp/utf8/cpp17.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/utf8/cpp17.h)
- [`dep/include/utf8cpp/utf8/cpp20.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/utf8/cpp20.h)
- [`dep/include/utf8cpp/utf8/unchecked.h`](file:///C:/Users/Admin/AntigravityProfiles/Projects/twow%20project/tortoise-wow/dep/include/utf8cpp/utf8/unchecked.h)

```text
 dep/include/utf8cpp/LICENSE          |   23 +
 dep/include/utf8cpp/README.md        |   14 +
 dep/include/utf8cpp/doc/ReleaseNotes |    9 -
 dep/include/utf8cpp/doc/utf8cpp.html | 1629 ----------------------------------
 dep/include/utf8cpp/utf8.h           |   12 +
 dep/include/utf8cpp/utf8/checked.h   |  236 +++--
 dep/include/utf8cpp/utf8/core.h      |  466 ++++++----
 dep/include/utf8cpp/utf8/cpp11.h     |   70 ++
 dep/include/utf8cpp/utf8/cpp17.h     |   96 ++
 dep/include/utf8cpp/utf8/cpp20.h     |  124 +++
 dep/include/utf8cpp/utf8/unchecked.h |  214 +++--
 11 files changed, 923 insertions(+), 1970 deletions(-)
```

---

## 4. Turtle Invariants & Safety Verification

- **MAX_RACES = 11**: Verified race dimensions preserved (Goblins=9, High Elves=10).
- **sTWDebuff**: Verified dynamic debuff tracking calls preserved.
- **Script Commands**: Verified ID 93 (`SCRIPT_COMMAND_TAKE_MONEY`) unaffected.
- **Zero Git Bloat**: Documentation stored strictly locally in `twow project/docs/commits/`.
