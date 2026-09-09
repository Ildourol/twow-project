# Backport History & Candidate Provenance Ledger

This document serves as the permanent, authoritative changelog, provenance ledger, and candidate queue for all upstream bugfixes and toolchain fixes backported into **Tortoise-WoW Extended**.

> [!NOTE]
> **LOCAL-ONLY DOCUMENTATION POLICY**
> All documentation, runbooks, candidate queues, and progress ledgers are maintained **strictly locally** in `twow project/docs/`.
> The git repository `tortoise-wow` contains **ONLY code changes, bugfixes, and necessary build patches**. No documentation bloat is committed to git.

---

## 1. Project Baseline & Methodology

- **Authoritative Remote**: [`https://github.com/Ildourol/tortoise-wow-extended.git`](https://github.com/Ildourol/tortoise-wow-extended.git) (branch `main`)
- **Base Baseline SHA**: `b8f24bef6cfc69feafc5870ac6a8918a521253d7` ([`Penqle/tortoise-wow`](https://github.com/Penqle/tortoise-wow) + upstream quest/vmap fixes)
- **Current Head SHA**: `053cb501f11fda999967ffef60852b8902bf26c0`
- **Active Backport Count**: **1 Build Toolchain Fix + 0 VMaNGOS Ports (1 Commit Total)**
- **Methodology**: Strict **commit-by-commit backporting** (individual verification, MSVC 2022 compile gate, immediate push).

---

## 2. Active Backport Log

### BUILD-0001 - Configure OpenSSL 3.x detection and ARC4 provider loading for Windows MSVC
- **Date**: 2026-09-09
- **Commit SHA**: [`053cb501f`](https://github.com/Ildourol/tortoise-wow-extended/commit/053cb501f)
- **Type**: Build Toolchain & Cryptography Fix Patch
- **Files Modified**: `CMakeLists.txt`, `src/shared/Auth/ARC4.cpp`, `.gitignore`
- **Summary**: Resolved stock Penqle baseline linker errors on Windows MSVC by detecting vcpkg OpenSSL 3.x libraries and loading the OpenSSL legacy provider for ARC4 cipher initialization with defensive null checks.

---

## 3. Prioritized Candidate Backlog (Next Up)

The following candidates are queued for upcoming commit-by-commit backporting from `tools/porting/CRUCIAL_COMMITS_QUEUE.csv`:

### Tier 1: Server Crashes, Memory Leaks & Security
- `5887d67fe`: schell244 - Fix memory leak of hardcoded events in GameEventMgr
- `ed2da0582`: schell244 - Fix memory leaks of spell mods and aura scripts
- `84f1bbccd`: Gamemechanic - Small changes to Formulas.h (PvP honor gain formulas; preserve `inGurubashiArena`)
- `ef7b84552`: schell244 - Change follow angle for escorts (`M_PI_F`; preserve `SCRIPT_COMMAND_TAKE_MONEY = 93`)
- `5b5f8abea`: schell244 - Fix Tame Beast after recent change to channel spells

### Tier 2: Combat Mechanics, Spells & World State
- `448df9ba0`: schell244 - Roll daze before sending SMSG_ATTACKERSTATEUPDATE
- `3997d1698`: schell244 - Pass CalcDamageInfo to RollMeleeOutcomeAgainst instead of returning outcome
- `24db7802e`: schell244 - Fix Scourge Invasion world state, attack timer and event teardown
- `9d28d2848`: schell244 - Add remaining missing gameobjects summoned by spells
- `4220a521c`: Spells - Float drift prevention in periodic aura tick timers

### Tier 3: Bounds, Collision Guards & Exploits
- `3de62e0be`: Spells / Creatures - Guard against duplicate guardian summons
- `18e37d1fe`: Creatures - Map creature group bounds and lifecycle validation

### Tier 4: Pets, AI & Movement Systems
- `ba8639e28`: schell244 - Fix Scourge Invasion zone invasions never being retried after a failed load
- `a11272f8b`: schell244 - Only adjust follower speed for pets
- `7ff0d5faf`: schell244 - Fix Pyroguard Emberseer event failure condition
- `a35242b33`: schell244 - Cleanup unused scripts and assign EventAI to mobs that should use it
- `1246926c8`: Script Engine - Motion master escort follow target handling
- `d2a9e2c6d`: Pets - Support stabling and unstabling for dismissed and dead pets
- `165377484`: Pets - Revive / Call Pet lifecycle and aura persistence
- `c38151e02`: AI - Naxxramas gargoyle leashing and combat reset
- `b9be669ee`: AI - Closed door blink check and line-of-sight pathing
- `7ae72b32e`: Movement - Pathfinder coordinate bounds verification

### Tier 5: Encounters, Quests & World Content
- `92e1a69c6`: schell244 - Add more missing gameobjects
- `c78268059`: Gamemechanic - Fix buyback replacing items
- `7b601d1c4`: Gamemechanic - Corrections to IsVendorItemValid
- `b7a6ef7ea`: FlagFlayer - Correct gossip option texts for Felwood cleansed plants
- `e13afe5b5`: schell244 - Add gameobject template for Pillaclencher's Ornate Pillow
- `25fac6b48`: schell244 - New script for quest Mist
- `8784e6761`: schell244 - Restore wrongfully deleted firework gameobject
- `7d45f7a84`: schell244 - Fix Dragons of Nightmare script when not all dragons are created yet

---

## 4. Architectural Exclusions (Do Not Port)

Upstream commits matching any of the following criteria are evaluated and classified as **DO NOT PORT**:
1. **Already Present in Turtle WoW**: Features or fixes natively implemented in Penqle (e.g. dynamic debuff tracking, custom item prototypes).
2. **Mass Resource Pooling Migrations**: Broad automated pooling scripts touching thousands of spawns, which conflict with Turtle's regional creature densities and custom spawn nodes.
3. **Database Schema Divergence**: Upstream commits depending on progressive columns (`patch`, `build`) or table redesigns (`creature_template_movement`) incompatible with Turtle's schema.
4. **Contradicting Turtle Intentional Design**: Changes reverting custom racials, class balancing, or custom features intentionally introduced by Turtle WoW.
5. **Architectural Divergence**: Commits introducing third-party dependencies, modern C++20 paradigms, or asynchronous thread models incompatible with Turtle's core structure.

### 4.1. Evaluated Exclusions Ledger (Tier 1 Crash & Security Audit)

| Donor SHA | Subsystem | Author | Subject | Reason & Architectural Rationale |
|:---|:---|:---|:---|:---|
| `e66174ef3` | Network / Memory | Silent-Walrus | Fix memory leak in ReadableBuffer assignment operators | **Architectural Divergence**: Fix applies to VMaNGOS-specific `IO::ReadableBuffer` / async socket layer (`src/shared/IO/ReadableBuffer.h`). Turtle-WoW uses the ACE network stack (`MangosSocket` / `WorldSocket`) without `ReadableBuffer`. |
| `ebf2ae06f` | Spells / Combat | schell244 | Fix spell reflection crashes before 1.6 | **Client Version Not Applicable**: Compatibility shims (`#if SUPPORTED_CLIENT_BUILD <= CLIENT_BUILD_1_5_1`) for pre-1.6 clients. Turtle-WoW targets 1.12.1 client (`build 5875` / `1.18.1`) where `SPELL_MISS_REFLECT` is fully supported. |
| `e876cbab3` | Auth / Security | schell244 | Harden realmd against crashes and password brute force attempts | **Architectural & DB Divergence**: Rewrites realmd challenge parsing, drops `account.failed_logins`, and replaces auth pipeline with modern VMaNGOS SRP6 abstraction. Incompatible with Turtle-WoW custom auth (PIN, TOTP, dynamic MPQ patching). |
| `6da41d495` | Auth / Security | schell244 | Reject oversized auth packets to prevent heap buffer overflow | **Not Applicable / Already Protected**: Protects static `sAuthLogonChallengeBody` struct in VMaNGOS. Turtle-WoW uses dynamic vector buffer resizing (`std::vector<uint8> buf`) with explicit size bounds. |
| `0be4616ef` | Crypto / Encoding | _BLU | Make base32 functions safer and fix some crashes | **Already Solved / Divergent Implementation**: Fixes unbuffered C base32 library. Turtle-WoW already uses Google's standard bounded `base32_decode(..., int bufSize)` in `src/shared/Auth/base32.cpp`. |
| `995ec6eaa` | Inventory / Trading | ratkosrb | Fix crash when trading stackable items to bots | **Not Applicable**: Fixes use-after-free in VMaNGOS bot trading architecture where `IsSavingDisabled()` checked item pointers after `MoveItemToInventory`. Turtle-WoW does not have `IsSavingDisabled()`. |
| `b32798d89` | World Events / Stability | ratkosrb | Fix crash when scourge invasion is enabled | **Architectural Divergence**: Fixes null map dereference in VMaNGOS rewritten Scourge Invasion architecture (`CityAttack`, `SummonPallid`, `mouthPos`). Turtle-WoW retains classic `ScourgeInvasionEvent` structures. |
| `b4759fb1f` | Commands / Debug | ratkosrb | Fi crash when using debug send spellfail command | **Not Applicable**: Fixes token parsing crash in debug GM command `.debug send spellfail`. This command does not exist in Turtle-WoW. |
| `b58d6a1f7` | Transports / Concurrency | ratkosrb | Fix a deadlock when boarding transports | **Not Applicable**: Resolves self-deadlock on `m_passengerMutex` in VMaNGOS multi-threaded transport subsystem. Turtle-WoW transport updates are single-threaded on the map update loop without `m_passengerMutex`. |
| `6f393e0ba` | Movement / Spline | ratkosrb | Fix a crash | **Not Applicable**: Fixes duration math in `MoveSpline::ComputePositionAfterTime`. This method was added in VMaNGOS `b661ec6cc` for chase movement prediction and does not exist in Turtle-WoW. |
| `fdb5887f0` | PlayerBots / Memory | Gamemechanic | Fix potential memory leak when adding partybots | **Not Applicable**: Fixes memory leak in GM commands `partybot add` and `partybot clone` when bot spawn fails. These commands do not exist in Turtle-WoW. |
