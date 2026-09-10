# Upstream Compatibility Ledger

This document serves as the authoritative, permanent ledger tracking architectural adaptations, conflict resolutions, invariant rules, and research-identified risks between upstream donor repositories (**VMaNGOS**, **Elysium**, **Light's Hope**) and the authoritative host (**Turtle WoW / Penqle**).

---

## 1. Status Taxonomy & Lifecycle

Every tracked adaptation or risk is categorized under one of the following lifecycle states:

| Status Tag | Meaning & Scope |
| :--- | :--- |
| **`Research-known risk`** | Identified during codebase audits. Documented to prevent regressions or collisions when relevant donor commits are processed. |
| **`Active local adaptation`** | Actively implemented in the current codebase to accommodate Turtle-specific features or architecture while applying an upstream fix. |
| **`Resolved persistent adaptation`** | Permanently established architectural convention or pattern stabilized, verified, and accepted into the baseline. |
| **`AI-Adaptable divergence`** | Syntactic or signature divergence where upstream diff requires intelligent adaptation (preserving Turtle custom arguments/enums). |
| **`Hard Incompatibility (Do Not Port)`** | Fundamentally divergent subsystem architecture that cannot be ported without breaking Turtle's core design. |

---

## 2. Active Local Adaptations & Resolved Persistent Adaptations

### ADAPT-001: OpenSSL 3.x / ARC4 Windows Toolchain Linker Compatibility

- **Subsystem**: Build System / Cryptography / Windows Toolchain
- **Status**: `Resolved persistent adaptation` (`BUILD-0001`, `053cb501f`)
- **Scope**: CMake build system and ARC4 cryptographic provider initialization on Windows MSVC 2022.
- **Problem Resolved**:
  - Stock Penqle `b8f24bef6` linked legacy bundled OpenSSL 1.1 static libraries on Windows (`dep/windows/lib`).
  - When compiling on MSVC 2022 using modern vcpkg packages (OpenSSL 3.x), `mangosd.exe` failed with unresolved external symbols: `SSL_get1_peer_certificate` and `OSSL_PROVIDER_load`.
  - ARC4 cipher routines (used by Warden anticheat and network crypto) require OpenSSL 3 legacy provider loading (`OSSL_PROVIDER_load(NULL, "legacy")`), but on Windows the DLL path (`OPENSSL_MODULES`) must point to the server executable directory.
- **Implemented Adaptation**:
  - `CMakeLists.txt`: Detects vcpkg OpenSSL 3.x libraries (`C:/vcpkg/installed/x64-windows/lib/libssl.lib` and `libcrypto.lib`) and sets `OPENSSL_INCLUDE_DIR` and `OPENSSL_LIBRARIES` accordingly.
  - `src/shared/Auth/ARC4.cpp`: Implemented `EnsureOpenSSLProviders()` which dynamically configures `OPENSSL_MODULES` to the executable directory on Windows, loads both `"legacy"` and `"default"` providers via `OSSL_PROVIDER_load()`, and adds defensive null checks on cipher context pointers.
- **Verification**: Clean build and link of both `realmd.exe` and `mangosd.exe` (Exit Code 0).

---

### ADAPT-002: Online Turtle Database Viewer & SQLite/WASM Verification Matrix

- **Subsystem**: Database / World Content / Client 1.18.1 Parity
- **Status**: `Resolved persistent adaptation` (`AGENT-6`, `task 6`)
- **Scope**: Authoritative entity verification against [`https://xian55.github.io/tortoise-db-viewer/`](https://xian55.github.io/tortoise-db-viewer/) and live GitHub CDN changelogs (`xian55/tortoise-db-viewer` branches `cdn`, `cdn-dev`).
- **Problem Resolved**:
  - When porting upstream database fixes from VMaNGOS or Light's Hope, donor migrations frequently alter item stats, spell effects, creature armor/health cohorts, vendor item lists, or quest rewards to match Vanilla 1.12.1 Blizzard retail behavior.
  - However, Turtle-WoW 1.18.1 has thousands of intentional balance adjustments, custom items, modified spell coefficients, custom vendor currencies, and 3D assets that must never be blindly reverted by upstream migrations.
  - Previously, determining if a Turtle DB change was intentional required tedious manual multi-file searching across dozens of `.sql` scripts.
- **Implemented Adaptation**:
  - Established `task 6 <query_or_id>` (Agent 6: Online Database Oracle) using `tools/porting/Query-OnlineDbViewer.ps1`.
  - Enables instant cross-referencing against the compiled Turtle-WoW 1.18.1 SQLite/WASM database and live CDN changelogs (`cdn-dev/data/changelog.json`).
  - Provides direct browser URLs (`?item=`, `?npc=`, `?spell=`, `?quest=`, `?object=`) and interactive 3D model/tooltip verification before staging database migrations.
- **Verification**: Verified live lookup on item `19019`, spell searches, and live CDN delta tracking.

---

### ADAPT-003: High-Performance Database Scalper & Progressive Column Stripper Engine

- **Subsystem**: Database / World Content / Schema Normalization
- **Status**: `Resolved persistent adaptation` (`AGENT-3`, `task scalp`, `task extract`)
- **Scope**: Multi-source SQL row extraction, field-by-field diffing, and automated progressive column stripping (`patch`, `patch_min`, `patch_max`, `build`) via `tools/porting/Extract-DbEntity.ps1`.
- **Problem Resolved**:
  - Upstream VMaNGOS and historical reference dumps structure template tables with progressive columns (e.g. `item_template` has column 1 as `patch` indexing patches 0..10; `creature_loot_template` has `patch_min` and `patch_max`).
  - Blindly copying raw `INSERT INTO` lines into Turtle-WoW 1.18.1 shifts every subsequent column by 1 or fails on schema constraints, silently corrupting data or throwing database errors.
  - Manual entity lookups across 150+ Turtle base SQL files and 143MB monolithic dumps took significant time and manual arithmetic.
- **Implemented Adaptation**:
  - Implemented `task scalp <table_alias> <entry_or_name> [-Diff] [-ExportSql] [-OpenViewer]`.
  - Seamlessly fuses Turtle-WoW base SQL schemas (`tortoise-wow/sql/base/tw_world_<table_name>.sql`), Brotalnia `brotalnia/database` (`world_full_14_june_2021.sql` from `world_full_14_june_2021.7z`, Main Historic DB for unchanged vanilla entities), and `vmangos/core db_latest` (backup donor DB), with `tortoise-db-viewer` (REST API `api.tortoiseclothing.org`, local catalog `scripts/data/vanilla-ids.json`, and web dashboard).
  - Employs a zero-allocation streaming tokenizer and structured API deserializer that accurately parses quoted strings with commas and escaped quotes.
  - Maps donor values to Turtle-WoW schema columns, automatically strips progressive columns, selects the 1.12.1 final baseline, and preserves Turtle exclusive columns (`mount_display_id`, `wrapped_gift`, `script_name`).
  - Provides side-by-side colorized diffs and generates clean, sanitized `REPLACE INTO` SQL patches directly into `tools/queue/staging_sql/`.
- **Verification**: Verified on `item 19019` (Thunderfury, 126 matching columns, 2 diffs, 1 progressive column stripped), `creature 10184` (Onyxia, 73 matching columns, 2 diffs, 1 progressive column stripped), and `spell 20925` (Holy Shield).

---

## 3. Research-Known Compatibility Risks & Invariant Rules

### RISK-001: Script Command Collision — `SCRIPT_COMMAND_FOLLOW_ESCORT` vs `SCRIPT_COMMAND_TAKE_MONEY`
- **Subsystem**: Script Engine / Escort AI
- **Status**: `Research-known risk` (Candidate: vmangos/core@`ef7b84552`, `1246926c8`)
- **Conflict**: In VMaNGOS, enum value `93` is defined as `SCRIPT_COMMAND_FOLLOW_ESCORT`. In Turtle WoW (`src/game/ScriptMgr.h`), enum value `93` was natively assigned by Penqle to `SCRIPT_COMMAND_TAKE_MONEY`.
- **Binding Invariant Rule**: **Penqle owns the numeric enum space.** Never overwrite `SCRIPT_COMMAND_TAKE_MONEY = 93`. When porting escort follow angles, assign `SCRIPT_COMMAND_FOLLOW_ESCORT` to the next available unallocated ID (e.g. 94+).

---

### RISK-002: Race Array Bounds & Custom Races (`MAX_RACES = 11`)
- **Subsystem**: Core Engine / Character / DBC
- **Status**: `Research-known risk`
- **Conflict**: Vanilla WoW 1.12.1 and VMaNGOS define `MAX_RACES = 10`. Turtle WoW natively implements Goblins (`RACE_GOBLIN = 9`) and High Elves (`RACE_HIGHELF = 10`), establishing `MAX_RACES = 11`.
- **Binding Invariant Rule**: Any ported formula, character creation validator, DBC array allocation, or bitmask must strictly maintain `MAX_RACES = 11`. Allocations sized to 10 cause memory corruptions when a High Elf player is processed.

---

### RISK-003: Custom Dynamic Debuff Limit Manager (`sTWDebuff`)
- **Subsystem**: Spells / Auras / Combat
- **Status**: `Research-known risk`
- **Conflict**: Standard vanilla cores hardcode 8 or 16 debuff slots. Turtle WoW implements a dynamic debuff expansion subsystem managed by `sTWDebuff` (`src/game/TWDebuff/TWDebuff.h`).
- **Binding Invariant Rule**: Upstream fixes modifying aura application or priority queues must maintain lifecycle hooks with `sTWDebuff` and must not revert dynamic debuff tracking to static arrays.

---

### RISK-004: Custom Spell ID Space ($\ge 40000$) & Class Balance
- **Subsystem**: Spells / Combat Balance / DBC
- **Status**: `Research-known risk`
- **Conflict**: Turtle WoW introduces custom class spells, racials, and balance redesigns in spell ID range $\ge 40000$ (e.g. Paladin Taunt, Druid balance adjustments).
- **Binding Invariant Rule**: Never overwrite Turtle custom class balancing with vanilla 1.12.1 behavior. Keep custom spell IDs ($\ge 40000$) fully intact.

---

### RISK-005: World Database Custom ID Range ($\ge 300000$) & Progressive Columns
- **Subsystem**: Database / World Content / Migrations
- **Status**: `Research-known risk`
- **Conflict**: Turtle WoW reserves entity entry IDs $\ge 300000$ for custom quests, items, creatures, and gameobjects. Upstream VMaNGOS migrations frequently reference progressive columns (`patch`, `build`).
- **Binding Invariant Rule**: Strip all progressive columns (`patch`, `build`). Verify that entity IDs reside in vanilla ID space ($< 300000$) and do not collide with Turtle content.

---

### RISK-006: OpenSSL 3.x / ARC4 Windows Toolchain Linker Compatibility
- **Status**: `Resolved persistent adaptation` (See `ADAPT-001` in Section 2 above).

---

### RISK-007: Custom Function Signatures & Arena Parameters (`inGurubashiArena`)
- **Subsystem**: Formulas / PvP / World
- **Status**: `AI-Adaptable divergence` (Candidate: vmangos/core@`84f1bbccd`, `Formulas.h`)
- **Conflict**: Upstream VMaNGOS functions often have vanilla signatures, whereas Turtle WoW has added custom arguments (e.g., `GetHonorGain` in `Formulas.h` includes `bool inGurubashiArena = false`).
- **Binding Invariant Rule**: Never overwrite Turtle function signatures. When porting calculations, adapt the upstream logic into Turtle's signature and preserve zone-specific parameters.

---

### RISK-008: 64-Bit Debuff Streaming Masks (`UI64LIT`)
- **Subsystem**: Spells / Auras / Network
- **Status**: `AI-Adaptable divergence`
- **Conflict**: Turtle WoW extends debuff bitmasks to 64-bit integer literals using the `UI64LIT` macro in `SpellAuras.cpp` and `Unit.cpp`.
- **Binding Invariant Rule**: When porting upstream aura stack or removal fixes, preserve `UI64LIT` and debuff streaming calls.

---

## 4. Architectural Classification: Hard Incompatibilities vs. AI-Adaptable

The AI Semantic Engine distinguishes between **Hard Incompatibilities** (which must be skipped) and **Soft Context Divergences** (which the AI can adapt):

### 4.1. Hard Architectural Incompatibilities (DO NOT PORT)

| Subsystem | Upstream Pattern | Why It Cannot Be Ported |
| :--- | :--- | :--- |
| **Network IO** | `IO::ReadableBuffer`, `IO::AsyncSocket` | VMaNGOS rewritten async socket layer. Turtle-WoW uses the ACE network stack (`MangosSocket` / `WorldSocket`). |
| **Authentication** | `sAuthLogonChallengeBody` static struct | VMaNGOS static struct. Turtle uses dynamic vector buffer resizing (`std::vector<uint8> buf`) for custom TOTP/PIN authentication. |
| **Transports** | `m_passengerMutex` recursive locking | Resolves self-deadlock in VMaNGOS multi-threaded transports. Turtle-WoW transport updates are single-threaded on the map update loop. |
| **Bot Framework** | `partybot add`, `IsSavingDisabled` | Targets VMaNGOS internal GM bot subsystem. Turtle-WoW does not include these commands. |
| **Client Shims** | `#if SUPPORTED_CLIENT_BUILD <= CLIENT_BUILD_1_5_1` | Pre-1.6 vanilla client shims. Turtle-WoW targets 1.12.1 client (`build 5875` / `1.18.1`). |

---

### 4.2. Soft Context Divergences (AI-ADAPTABLE)

| Pattern | Upstream Form | Turtle WoW Form | AI Adaptation Strategy |
| :--- | :--- | :--- | :--- |
| **Zone Parameters** | `GetHonorGain(killer, victim, rank, kills, group)` | `GetHonorGain(..., group, inGurubashiArena)` | Keep `inGurubashiArena`, adapt internal math. |
| **Debuff Masks** | Standard uint32 aura bitmasks | `UI64LIT(1) << slot` (64-bit debuff streaming) | Preserve `UI64LIT` macro and debuff streaming calls. |
| **Race Limits** | `MAX_RACES = 10` | `MAX_RACES = 11` (Goblin & High Elf) | Enforce array bounds of 11 in all loops and DBC lookups. |
| **Float Precision** | Legacy double/int mixed constants (`45`, `2.5`) | Explicit float literals (`45.f`, `2.5f`) | Apply clean float typing across all math routines. |
| **Branch Simplification** | Deeply nested `else if` ladders | Early-return guard clauses (`if (...) return 0.0f;`) | Adopt early exits while maintaining all Turtle branch outcomes. |
