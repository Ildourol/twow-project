# Uploaded Commits History & Artifact Requirements Ledger

This document is the authoritative record of all commits uploaded to the remote repository [`Ildourol/tortoise-wow-extended`](https://github.com/Ildourol/tortoise-wow-extended) (branch `main`), tracking commit hashes, donor references, affected files, safety invariants, and whether additional files (SQL migrations, configurations, client DBC/maps, or build toolchain files) were required.

> [!NOTE]
> **LOCAL-ONLY DOCUMENTATION POLICY**
> All documentation, runbooks, and ledgers are maintained **strictly locally** in `twow project/docs/`.
> The git repository contains **ONLY code changes, bugfixes, and necessary build patches**.

---

## 1. Uploaded Commit Registry Summary

- **Target Remote**: [`https://github.com/Ildourol/tortoise-wow-extended.git`](https://github.com/Ildourol/tortoise-wow-extended.git)
- **Target Branch**: `main`
- **Base Baseline SHA**: `b8f24bef6cfc69feafc5870ac6a8918a521253d7` ([`Penqle/tortoise-wow`](https://github.com/Penqle/tortoise-wow) + upstream quest/vmap fixes)
- **Current Head SHA**: `053cb501f11fda999967ffef60852b8902bf26c0`
- **Total Uploaded Commits**: **1** (1 Build Toolchain Fix + 0 VMaNGOS Donor Ports)
- **Build Status**: PASS (MSVC 2022 x64 Release: `mangosd.exe` and `realmd.exe` Exit Code 0)

| # | Commit SHA | ID | Subsystem | Commit Subject | Upstream Donor | Additional Files Needed? | Status |
|---|:---|:---|:---|:---|:---|:---|:---|
| 1 | [`053cb501f`](https://github.com/Ildourol/tortoise-wow-extended/commit/053cb501f) | `BUILD-0001` | Build / Crypto | Configure OpenSSL 3.x detection & ARC4 provider | Internal MSVC toolchain | `CMakeLists.txt`, `src/shared/Auth/ARC4.cpp` | Verified |

---

## 2. Additional File Requirements Analysis

When porting donor bugfixes from VMaNGOS into Tortoise-WoW Extended, each port is evaluated across four artifact dimensions:

1. **Database Migrations (`sql/database_updates/world/`)**:
   - Evaluated for each port. All progressive columns (`patch`, `build`) must be stripped. Custom entities ($\ge 300,000$) must be preserved.

2. **Server Configuration Files (`mangosd.conf`, `realmd.conf`)**:
   - Evaluated for each port. Preserves server defaults.

3. **Build Toolchain & Cryptography Files (`CMakeLists.txt`, `dep/`)**:
   - `BUILD-0001` (`053cb501f`) configured OpenSSL 3.x detection and ARC4 provider loading for Windows MSVC 2022.

4. **Client-Side Data Files (`client-data-1.18.1/` - DBC, Maps, VMaps, MMaps)**:
   - Server data dependencies reside in `twow project/reference-upstreams/client-data-1.18.1/`.
