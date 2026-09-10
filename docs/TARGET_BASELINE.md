# Target Baseline Specification

## 1. Target Repository Baseline

- **Repository Directory**: `C:\Users\Admin\AntigravityProfiles\Projects\Module-playerbots\tortoise-wow-extended`
- **Git Remote**: `origin -> https://github.com/Ildourol/tortoise-wow-extended.git`
- **Integration Branch**: `mantech-turtle`
- **Baseline HEAD SHA**: `a80ca1d1d4d5ac71573e9d06f5b80c4068c910ef`
- **Working Tree Cleanliness**: `Clean` (0 uncommitted changes, 0 untracked files)
- **Client Protocol Target**: Turtle WoW 1.18.1 (Client Build 7272)

---

## 2. Toolchain & Build Baseline

### 2.1. Environment Configuration
- **Host OS**: Windows 11 Enterprise (x86_64)
- **Compiler**: Microsoft Visual Studio 2022 Build Tools (MSVC 19.44.35228.0)
- **Generator**: `Visual Studio 17 2022` (x64 architecture)
- **CMake Version**: 4.4.2 (`C:/vcpkg/downloads/tools/cmake-4.4.2-windows/cmake-4.4.2-windows-x86_64/bin/cmake.exe`)
- **Package Manager**: `vcpkg` (`C:/vcpkg`)
- **External Dependencies**:
  - ACE: 7.x/8.x headers & lib located at `C:/vcpkg/installed/x64-windows`
  - Boost: 1.92.0 (`thread`, `filesystem`, `system`) at `C:/vcpkg/installed/x64-windows`
  - Bundled Dependencies: OpenSSL, MySQL, Recast, G3D under `dep/windows` and `dep/`

### 2.2. CMake Configuration Flags
```powershell
cmake -S tortoise-wow-extended -B tortoise-wow-extended/build `
  -G "Visual Studio 17 2022" -A x64 `
  -DCMAKE_BUILD_TYPE=Release `
  -DBUILD_PLAYERBOTS=ON `
  -DMODULE_MOD_DUNGEON_CLEAR=static `
  -DALLOW_TURTLE_ADDONS=ON `
  -DBUILD_ELUNA=OFF `
  -DACE_ROOT="C:/vcpkg/installed/x64-windows" `
  -DBOOST_ROOT="C:/vcpkg/installed/x64-windows" `
  -DOPENSSL_LIBRARIES="C:/vcpkg/installed/x64-windows/lib/libssl.lib;C:/vcpkg/installed/x64-windows/lib/libcrypto.lib" `
  -DOPENSSL_INCLUDE_DIR="C:/vcpkg/installed/x64-windows/include"
```

### 2.3. CMakeCache Inspection Evidence
Inspection of `build/CMakeCache.txt` confirmed:
- `BUILD_PLAYERBOTS:BOOL=ON`
- `MODULE_MOD_DUNGEON_CLEAR:UNINITIALIZED=static`
- `CMAKE_GENERATOR:INTERNAL=Visual Studio 17 2022`
- `CMAKE_BUILD_TYPE:STRING=Release`
- Module compilation mode: Static aggregation into target `modules.lib` linked directly into `mangosd.exe`.

---

## 3. Subsystem Architecture

### 3.1. PlayerBots Subsystem (`modules/mod-playerbots`)
- Relocated from `src/modules/PlayerBots` to `modules/mod-playerbots` in commit `8415f1b9`.
- Aggregated into static `modules` target with compiler defines `CMANGOS`, `MANGOSBOT_ZERO`, `ENABLE_PLAYERBOTS`.
- Precompiled header and compatibility shim via `botpch.h` / `cmangos-compat-shim.h`.
- Core hooks registered via `ScriptMgr` and `World::InitPlayerbotsAtStartup()`.
- Threading & session pump: `PlayerbotHolder::UpdateAllHolderSessions` runs strictly on the world owner thread.

### 3.2. Protected Dungeon Clear (`modules/mod-dungeon-clear`)
- Static module compiling alongside PlayerBots in the `modules` library.
- Consumes PlayerBots headers (`playerbot/playerbot.h`, `strategy/values/*`).
- Extends bot decision-making via `DungeonClearValueContext` and custom triggers/actions.
- Tests available under `modules/mod-dungeon-clear/t/`.

---

## 4. Verification Baseline

- **Compilation**: Static library `modules.lib` compiles with 0 errors.
- **Linkage**: `mangosd.exe` links without unresolved external symbols.
- **Verification Rule**: Any candidate port must verify successful linkage of `mangosd` before consideration as completed.
