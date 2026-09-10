# Backport History & Candidate Provenance Ledger

This document serves as the permanent, authoritative changelog, provenance ledger, and candidate queue for all upstream bugfixes and toolchain fixes backported into **Tortoise-WoW Extended**.

> [!NOTE]
> **LOCAL-ONLY DOCUMENTATION POLICY**
> All documentation, runbooks, candidate queues, and progress ledgers are maintained **strictly locally** in `twow project/docs/`.
> The git repository `tortoise-wow` contains **ONLY code changes, bugfixes, and necessary build patches**. No documentation bloat is committed to git.

---

## 1. Project Baseline & Methodology

- **Authoritative Remote**: [`https://github.com/Ildourol/tortoise-wow-extended.git`](https://github.com/Ildourol/tortoise-wow-extended.git) (branch [`extended`](https://github.com/Ildourol/tortoise-wow-extended/tree/extended))
- **Base Baseline SHA**: `b8f24bef6cfc69feafc5870ac6a8918a521253d7` ([`Penqle/tortoise-wow`](https://github.com/Penqle/tortoise-wow) + upstream quest/vmap fixes)
- **Current Head SHA**: `bf93e36d9f38251eb6ee2f5faf157bca29e3a00f`
- **Active Backport Count**: **1 Build Toolchain Fix + 41 VMaNGOS Ports (42 Commits Total)**
- **Methodology**: Strict **commit-by-commit backporting** (individual verification, MSVC 2022 compile gate, automated push).

---

## 2. Active Backport Log

### BUILD-0001 - Configure OpenSSL 3.x detection and ARC4 provider loading for Windows MSVC
- **Date**: 2026-09-08
- **Commit SHA**: [`d960a10fe`](https://github.com/Ildourol/tortoise-wow-extended/commit/d960a10fe)
- **Type**: Build Toolchain & Cryptography Fix Patch
- **Files Modified**: `CMakeLists.txt`, `src/shared/Auth/ARC4.cpp`, `.gitignore`
- **Summary**: Resolved stock baseline linker errors on Windows MSVC by detecting vcpkg OpenSSL 3.x libraries and loading the OpenSSL legacy provider for ARC4 cipher initialization with defensive null checks.

### PORT-0001 through PORT-0022 - Tier 1 Crucial Security, Crash & Exploit Fixes
1. **PORT-0001** ([`9030d70fe`](https://github.com/Ildourol/tortoise-wow-extended/commit/9030d70fe) / `5887d67fe`): Fix memory leak of hardcoded events in GameEventMgr.
2. **PORT-0013** ([`7a47d0b8f`](https://github.com/Ildourol/tortoise-wow-extended/commit/7a47d0b8f) / `2f1c62680`): Prevent crash in MoveMap.cpp (#3007).
3. **PORT-0014** ([`d45d91429`](https://github.com/Ildourol/tortoise-wow-extended/commit/d45d91429) / `666371ac3`): Fix crash in WaypointMovementGenerator (#2938).
4. **PORT-0015** ([`ce99f8854`](https://github.com/Ildourol/tortoise-wow-extended/commit/ce99f8854) / `3d61a81da`): Fix startup crash on ARM.
5. **PORT-0016** ([`82257a747`](https://github.com/Ildourol/tortoise-wow-extended/commit/82257a747) / `301150737`): Use close() instead of freopen() to stop readline leaks (#2573).
6. **PORT-0017** ([`6913c8666`](https://github.com/Ildourol/tortoise-wow-extended/commit/6913c8666) / `6db7724a6`): Fix a crash in PetAI.
7. **PORT-0018** ([`23c45bf70`](https://github.com/Ildourol/tortoise-wow-extended/commit/23c45bf70) / `61d328822`): Fix unable to turn in quests with required items after crash.
8. **PORT-0019** ([`77e2d4fb4`](https://github.com/Ildourol/tortoise-wow-extended/commit/77e2d4fb4) / `a48f38333`): Fix who list crash on 1.8.4.
9. **PORT-0020** ([`76e03b1ad`](https://github.com/Ildourol/tortoise-wow-extended/commit/76e03b1ad) / `f3944cf8b`): Prevent crash on spoofed packet taking nonexistent mail item (#140).
10. **PORT-0021** ([`ec31c253f`](https://github.com/Ildourol/tortoise-wow-extended/commit/ec31c253f) / `061b03bd2`): Add cmake variable to change configuration directory (#1634).
11. **PORT-0022** ([`21b3bc36d`](https://github.com/Ildourol/tortoise-wow-extended/commit/21b3bc36d) / `76b458922`): Change war effort condition into generic save variable check (with SQL migration).

### PORT-0023 through PORT-0032 - Natural Priority Batch 1 (Movement, Spells, Architecture, Exploits)
12. **PORT-0023** ([`4285dcfe2`](https://github.com/Ildourol/tortoise-wow-extended/commit/4285dcfe2) / `9839bd2e2`): Creatures should flee in a random direction.
13. **PORT-0024** ([`39db83a57`](https://github.com/Ildourol/tortoise-wow-extended/commit/39db83a57) / `9e006e0ce`): Delay Mograine's death so Forgiveness visual displays properly (#3503).
14. **PORT-0025** ([`ccdea97cd`](https://github.com/Ildourol/tortoise-wow-extended/commit/ccdea97cd) / `80d3b7bee`): Prevent pickpocketing humanoids and undead with no pickpocket loot (#2729).
15. **PORT-0026** ([`a2337fc88`](https://github.com/Ildourol/tortoise-wow-extended/commit/a2337fc88) / `6f9d86f66`): Clamp auction time left to the client's signed 32-bit millisecond range (#3497).
16. **PORT-0027** ([`9c06dffa2`](https://github.com/Ildourol/tortoise-wow-extended/commit/9c06dffa2) / `46d789256`): GetHeightStatic: Add a delta to Z before choosing vmap height over map height (#3487).
17. **PORT-0028** ([`7d89387cf`](https://github.com/Ildourol/tortoise-wow-extended/commit/7d89387cf) / `59cf5cc3b`): Fix GetRandomPoint for flying units (#3390).
18. **PORT-0029** ([`bdcd7adf2`](https://github.com/Ildourol/tortoise-wow-extended/commit/bdcd7adf2) / `454afdc0b`): Update utf8cpp (#3383).
19. **PORT-0030** ([`2dd7d2e99`](https://github.com/Ildourol/tortoise-wow-extended/commit/2dd7d2e99) / `781c639f5`): Only add bot to cache after adding to map.
20. **PORT-0031** ([`372f7cf80`](https://github.com/Ildourol/tortoise-wow-extended/commit/372f7cf80) / `080ab2106`): Improve accuracy of packed XYZ by rounding instead of truncating (#3206).
21. **PORT-0032** ([`c5461f130`](https://github.com/Ildourol/tortoise-wow-extended/commit/c5461f130) / `f9686f443`): Fix iterator invalidation in loot notification functions (#3181).

### PORT-0033 through PORT-0042 - Natural Priority Batch 2 (Combat, Spells, Pets, Cross-Faction)
22. **PORT-0033** ([`b3e91063e`](https://github.com/Ildourol/tortoise-wow-extended/commit/b3e91063e) / `2ab471ee3`): Creature aoe should put you in combat for 5 seconds.
23. **PORT-0034** ([`566d12e2c`](https://github.com/Ildourol/tortoise-wow-extended/commit/566d12e2c) / `6d94153b0`): Fix boolean logic in HostileReference::updateOnlineStatus (#3115).
24. **PORT-0035** ([`00255a01a`](https://github.com/Ildourol/tortoise-wow-extended/commit/00255a01a) / `27698c426`): Fix despawn time for non hunter pets.
25. **PORT-0036** ([`7024fb8bf`](https://github.com/Ildourol/tortoise-wow-extended/commit/7024fb8bf) / `e2314a59f`): Fix chain heal ordering (#3060).
26. **PORT-0037** ([`ed1ac4c56`](https://github.com/Ildourol/tortoise-wow-extended/commit/ed1ac4c56) / `47c79c8d3`): Possible fix to XP per kill rounding issue (#3032).
27. **PORT-0038** ([`1757e919b`](https://github.com/Ildourol/tortoise-wow-extended/commit/1757e919b) / `296fbe04b`): Cancel immediately channeled spells that are about to fail due to no more valid targets.
28. **PORT-0039** ([`58c2d6c43`](https://github.com/Ildourol/tortoise-wow-extended/commit/58c2d6c43) / `4591fce5c`): Realmd: Fix masking of login string if password is empty (#3016).
29. **PORT-0040** ([`727942744`](https://github.com/Ildourol/tortoise-wow-extended/commit/727942744) / `30e335309`): Implement SPELL_FAILED_EQUIPPED_ITEM_CLASS_MAINHAND and OFFHAND.
30. **PORT-0041** ([`39d47bd47`](https://github.com/Ildourol/tortoise-wow-extended/commit/39d47bd47) / `491191deb`): Name unknown field in SMSG_MAIL_LIST_RESULT.
31. **PORT-0042** ([`bef9a3aa8`](https://github.com/Ildourol/tortoise-wow-extended/commit/bef9a3aa8) / `05f1dad85`): Handle cross faction team in loot manager.

### PORT-0043 through PORT-0052 - Natural Priority Batch 3 (Movement, Quests, ARM Compatibility, Auction Mechanics)
32. **PORT-0043** ([`8c5750b4d`](https://github.com/Ildourol/tortoise-wow-extended/commit/8c5750b4d) / `0c1f343f1`): Fix orientation being used as teleport flags parameter.
33. **PORT-0044** ([`be302d223`](https://github.com/Ildourol/tortoise-wow-extended/commit/be302d223) / `cc05c0cf8`): Add end script for quest Cycle of Rebirth.
34. **PORT-0045** ([`c8b53b868`](https://github.com/Ildourol/tortoise-wow-extended/commit/c8b53b868) / `d58f8f6b0`): Improve follow movement (#2758).
35. **PORT-0046** ([`f0b9e2679`](https://github.com/Ildourol/tortoise-wow-extended/commit/f0b9e2679) / `1f65583b3`): Fix g3d build issue on arm.
36. **PORT-0047** ([`8499ac9f9`](https://github.com/Ildourol/tortoise-wow-extended/commit/8499ac9f9) / `076f32b41`): Fix Scarshield Portal (with SQL migration).
37. **PORT-0048** ([`facc2d80b`](https://github.com/Ildourol/tortoise-wow-extended/commit/facc2d80b) / `2169f8207`): Fix GeoLocking config check (#2010).
38. **PORT-0049** ([`55917af55`](https://github.com/Ildourol/tortoise-wow-extended/commit/55917af55) / `fdbf40b59`): Small refactor of Player::_ApplyItemBonuses (#1894).
39. **PORT-0050** ([`6165991d5`](https://github.com/Ildourol/tortoise-wow-extended/commit/6165991d5) / `e57139e9c`): Fix AddAura negative flag (#1782).
40. **PORT-0051** ([`3aea69a69`](https://github.com/Ildourol/tortoise-wow-extended/commit/3aea69a69) / `c80feeff2`): Fix mount id fallback for creatures (#1736).
41. **PORT-0052** ([`bf93e36d9`](https://github.com/Ildourol/tortoise-wow-extended/commit/bf93e36d9) / `74b99554a`): Damaged items should sell for reduced price (#1676).

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
