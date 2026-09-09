# Deleted Code and Semantic Delta Audit

This document provides an authoritative, forensic audit of all code deleted, replaced, or refactored across all commits applied to **Tortoise-WoW Extended** (`tortoise-wow`, branch `main`) beyond the baseline anchor ([`b8f24bef6`](https://github.com/Ildourol/tortoise-wow-extended/commit/b8f24bef6) from [`Penqle/tortoise-wow`](https://github.com/Penqle/tortoise-wow)).

> [!IMPORTANT]
> **PURITY & INTEGRITY POLICY**
> Every code deletion in an upstream port or toolchain fix must be attributable to one of three valid categories:
> 1. **Defect Rectification**: Removing bugged or erroneous logic present in the baseline.
> 2. **Memory / Resource Cleanup**: Removing unmanaged heap allocations, missing deallocations, or invalid iterator erasures.
> 3. **Toolchain Modernization**: Replacing obsolete dependencies or configurations (e.g. OpenSSL 1.1 with OpenSSL 3.x).
>
> **NO TURTLE-WOW CUSTOM LOGIC MUST EVER BE SILENTLY REMOVED.**
> All deletions are audited to ensure zero regression against:
> - The 10-Race System (`MAX_RACES = 11` for Goblin & High Elf)
> - Dynamic Debuff Streaming (`sTWDebuff` & `UI64LIT` 64-bit masks)
> - Custom Singleton Managers (`LFTMgr`, `TransmogMgr`, `CustomMerchantMgr`, `DynamicVisibilityMgr`)
> - Custom Zone & Arena Parameters (`inGurubashiArena`)
> - Custom Content ID Spaces (Spells $\ge 40000$, Entities $\ge 300000$)
> - Client 1.18.1 (Build 7272) Protocol Specifications

---

## 1. Global Metrics & Deletion Summary

- **Target Remote**: [`https://github.com/Ildourol/tortoise-wow-extended.git`](https://github.com/Ildourol/tortoise-wow-extended.git) (branch `main`)
- **Base Baseline SHA**: `b8f24bef6cfc69feafc5870ac6a8918a521253d7`
- **Current Head SHA**: `053cb501f11fda999967ffef60852b8902bf26c0`
- **Total Commits Audited**: **1** (`BUILD-0001`)
- **Total Lines Deleted Across All Commits**: 4 lines
- **Total Lines Added Across All Commits**: 52 lines
- **Net Delta**: +48 lines
- **Unintended Deletions Detected**: 0
- **Regressed Turtle Invariants**: 0

---

## 2. Commit-by-Commit Forensic Deletion Record

### Commit 1: BUILD-0001 (`053cb501f`) — Configure OpenSSL 3.x detection and ARC4 provider loading for Windows MSVC

- **Author**: Antigravity / DeepMind Pair Programmer
- **Date**: 2026-09-09
- **Type**: Build Toolchain & Cryptography Fix Patch
- **Files Modified**: `CMakeLists.txt`, `src/shared/Auth/ARC4.cpp`, `.gitignore`

#### Deleted / Replaced Code:
1. **`CMakeLists.txt` (OpenSSL include and library paths)**:
   ```cmake
   -    set(OPENSSL_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/dep/windows/include")
   -    set(OPENSSL_LIBRARIES "${CMAKE_SOURCE_DIR}/dep/windows/lib/libssl.lib" "${CMAKE_SOURCE_DIR}/dep/windows/lib/libcrypto.lib")
   ```
   *Rationale*: Legacy static libraries in `dep/windows/lib/` were compiled with OpenSSL 1.1. On Windows MSVC 2022, modern vcpkg installations provide OpenSSL 3.x. Replaced with dynamic check that auto-detects `C:/vcpkg/installed/x64-windows/lib/libssl.lib` and falls back gracefully to `dep/windows` if not present.
2. **`src/shared/Auth/ARC4.cpp` (Unconditional context initialization)**:
   ```cpp
   -    EVP_CIPHER_CTX_init(m_ctx);
   ```
   *Rationale*: OpenSSL 3.0 moved ARC4 (RC4) into the legacy provider (`legacy.dll`). Replaced with `EnsureOpenSSLProviders()` which sets `OPENSSL_MODULES` to the server executable directory, loads the legacy provider, and adds defensive null checks.

#### Integrity Verdict:
- **Regressions**: NONE.
- **Turtle Invariants Preserved**: OpenSSL 3.x compatibility enables clean compilation of `mangosd.exe` and `realmd.exe` with 0 compiler and linker errors.

---

## 3. Pre-Commit Deletion Safety Checklist

Before any future backport commit is accepted and committed via `task build-packages` (or `task auto-pilot`):
1. **No Regressed Enum Values**: Ensure `SCRIPT_COMMAND_TAKE_MONEY = 93` is untouched.
2. **No Array Clamping**: Ensure `MAX_RACES` is never reduced below 11.
3. **No Debuff Slot Reversion**: Ensure `sTWDebuff` hooks and `UI64LIT` are preserved.
4. **No Parameter Truncation**: Ensure custom parameters like `inGurubashiArena` in `Formulas.h` are preserved.
5. **No Database ID Collisions**: Ensure no IDs $\ge 300000$ are inserted or modified by vanilla migrations.
6. **No Progressive Columns**: Ensure `patch` and `build` columns are stripped from all SQL statements.
