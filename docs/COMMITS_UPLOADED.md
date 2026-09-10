# Uploaded Commits History & Artifact Requirements Ledger

This document is the authoritative record of all commits uploaded to the remote repository [`Ildourol/tortoise-wow-extended`](https://github.com/Ildourol/tortoise-wow-extended) (branch [`extended`](https://github.com/Ildourol/tortoise-wow-extended/tree/extended)), tracking commit hashes, donor references, affected files, safety invariants, and whether additional files (SQL migrations, configurations, client DBC/maps, or build toolchain files) were required.

> [!NOTE]
> **LOCAL-ONLY DOCUMENTATION POLICY**
> All documentation, runbooks, and ledgers are maintained **strictly locally** in `twow project/docs/`.
> The git repository contains **ONLY code changes, bugfixes, and necessary build patches**.

---

## 1. Uploaded Commit Registry Summary

- **Target Remote**: [`https://github.com/Ildourol/tortoise-wow-extended.git`](https://github.com/Ildourol/tortoise-wow-extended.git)
- **Target Branch**: [`extended`](https://github.com/Ildourol/tortoise-wow-extended/tree/extended)
- **Base Baseline SHA**: `b8f24bef6cfc69feafc5870ac6a8918a521253d7` ([`Penqle/tortoise-wow`](https://github.com/Penqle/tortoise-wow) + upstream quest/vmap fixes)
- **Current Head SHA**: `bf93e36d9f38251eb6ee2f5faf157bca29e3a00f`
- **Total Uploaded Commits**: **42** (1 Build Toolchain Fix + 41 VMaNGOS Donor Ports)
- **Build Status**: PASS (MSVC 2022 x64 Release: `mangosd.exe` and `realmd.exe` Exit Code 0)

| # | Commit SHA | ID | Subsystem | Commit Subject | Upstream Donor | Additional Files Needed? | Status |
|---|:---|:---|:---|:---|:---|:---|:---|
| 1 | [`9030d70fe`](https://github.com/Ildourol/tortoise-wow-extended/commit/9030d70fe) | `PORT-0001` | Core | Fix memory leak of hardcoded events in GameEventMgr | `vmangos/core@5887d67fe` | None (pure C++) | Verified |
| 2 | [`7a47d0b8f`](https://github.com/Ildourol/tortoise-wow-extended/commit/7a47d0b8f) | `PORT-0013` | Maps | Prevent crash in MoveMap.cpp (#3007) | `vmangos/core@2f1c62680` | None (pure C++) | Verified |
| 3 | [`d45d91429`](https://github.com/Ildourol/tortoise-wow-extended/commit/d45d91429) | `PORT-0014` | Movement | Fix crash in WaypointMovementGenerator (#2938) | `vmangos/core@666371ac3` | None (pure C++) | Verified |
| 4 | [`ce99f8854`](https://github.com/Ildourol/tortoise-wow-extended/commit/ce99f8854) | `PORT-0015` | Core | Fix startup crash on arm | `vmangos/core@3d61a81da` | None (pure C++) | Verified |
| 5 | [`82257a747`](https://github.com/Ildourol/tortoise-wow-extended/commit/82257a747) | `PORT-0016` | Core | Use close() instead of freopen() to stop readline leaks (#2573) | `vmangos/core@301150737` | None (pure C++) | Verified |
| 6 | [`6913c8666`](https://github.com/Ildourol/tortoise-wow-extended/commit/6913c8666) | `PORT-0017` | Creature | Fix a crash in PetAI | `vmangos/core@6db7724a6` | None (pure C++) | Verified |
| 7 | [`23c45bf70`](https://github.com/Ildourol/tortoise-wow-extended/commit/23c45bf70) | `PORT-0018` | Quest | Fix unable to turn in quests with required items after crash | `vmangos/core@61d328822` | None (pure C++) | Verified |
| 8 | [`77e2d4fb4`](https://github.com/Ildourol/tortoise-wow-extended/commit/77e2d4fb4) | `PORT-0019` | Core | Fix who list crash on 1.8.4 | `vmangos/core@a48f38333` | None (pure C++) | Verified |
| 9 | [`76e03b1ad`](https://github.com/Ildourol/tortoise-wow-extended/commit/76e03b1ad) | `PORT-0020` | Mail | Prevent crash on spoofed packet taking nonexistent mail item (#140) | `vmangos/core@f3944cf8b` | None (pure C++) | Verified |
| 10 | [`ec31c253f`](https://github.com/Ildourol/tortoise-wow-extended/commit/ec31c253f) | `PORT-0021` | CMake | Add cmake variable to change configuration directory (#1634) | `vmangos/core@061b03bd2` | None (CMake) | Verified |
| 11 | [`21b3bc36d`](https://github.com/Ildourol/tortoise-wow-extended/commit/21b3bc36d) | `PORT-0022` | World | Change war effort condition into generic save variable check | `vmangos/core@76b458922` | `sql/migrations/20220316214137_world.sql` | Verified |
| 12 | [`d960a10fe`](https://github.com/Ildourol/tortoise-wow-extended/commit/d960a10fe) | `BUILD-0001` | Build / Crypto | Fix(Build): Configure OpenSSL 3.x detection & ARC4 provider | Internal MSVC toolchain | `CMakeLists.txt`, `src/shared/Auth/ARC4.cpp` | Verified |
| 13 | [`4285dcfe2`](https://github.com/Ildourol/tortoise-wow-extended/commit/4285dcfe2) | `PORT-0023` | Movement | Creatures should flee in a random direction | `vmangos/core@9839bd2e2` | None (pure C++) | Verified |
| 14 | [`39db83a57`](https://github.com/Ildourol/tortoise-wow-extended/commit/39db83a57) | `PORT-0024` | Movement | Delay Mograine's death so Forgiveness visual displays properly (#3503) | `vmangos/core@9e006e0ce` | None (pure C++) | Verified |
| 15 | [`ccdea97cd`](https://github.com/Ildourol/tortoise-wow-extended/commit/ccdea97cd) | `PORT-0025` | World | Prevent pickpocketing humanoids and undead with no pickpocket loot (#2729) | `vmangos/core@80d3b7bee` | None (pure C++) | Verified |
| 16 | [`a2337fc88`](https://github.com/Ildourol/tortoise-wow-extended/commit/a2337fc88) | `PORT-0026` | Exploits | Clamp auction time left to client signed 32-bit millisecond range (#3497) | `vmangos/core@6f9d86f66` | None (pure C++) | Verified |
| 17 | [`9c06dffa2`](https://github.com/Ildourol/tortoise-wow-extended/commit/9c06dffa2) | `PORT-0027` | Maps / VMap | GetHeightStatic: Add delta to Z before choosing vmap height over map height (#3487) | `vmangos/core@46d789256` | None (pure C++) | Verified |
| 18 | [`7d89387cf`](https://github.com/Ildourol/tortoise-wow-extended/commit/7d89387cf) | `PORT-0028` | Movement | Fix GetRandomPoint for flying units (#3390) | `vmangos/core@59cf5cc3b` | None (pure C++) | Verified |
| 19 | [`bdcd7adf2`](https://github.com/Ildourol/tortoise-wow-extended/commit/bdcd7adf2) | `PORT-0029` | Core | Update utf8cpp (#3383) | `vmangos/core@454afdc0b` | None (pure C++) | Verified |
| 20 | [`2dd7d2e99`](https://github.com/Ildourol/tortoise-wow-extended/commit/2dd7d2e99) | `PORT-0030` | PlayerBots | Only add bot to cache after adding to map | `vmangos/core@781c639f5` | None (pure C++) | Verified |
| 21 | [`372f7cf80`](https://github.com/Ildourol/tortoise-wow-extended/commit/372f7cf80) | `PORT-0031` | Network | Improve accuracy of packed XYZ by rounding instead of truncating (#3206) | `vmangos/core@080ab2106` | None (pure C++) | Verified |
| 22 | [`c5461f130`](https://github.com/Ildourol/tortoise-wow-extended/commit/c5461f130) | `PORT-0032` | Loot | Fix iterator invalidation in loot notification functions (#3181) | `vmangos/core@f9686f443` | None (pure C++) | Verified |
| 23 | [`b3e91063e`](https://github.com/Ildourol/tortoise-wow-extended/commit/b3e91063e) | `PORT-0033` | Combat & Spells | Creature aoe should put you in combat for 5 seconds | `vmangos/core@2ab471ee3` | None (pure C++) | Verified |
| 24 | [`566d12e2c`](https://github.com/Ildourol/tortoise-wow-extended/commit/566d12e2c) | `PORT-0034` | Combat & Spells | Fix boolean logic in HostileReference::updateOnlineStatus (#3115) | `vmangos/core@6d94153b0` | None (pure C++) | Verified |
| 25 | [`00255a01a`](https://github.com/Ildourol/tortoise-wow-extended/commit/00255a01a) | `PORT-0035` | AI & Movement | Fix despawn time for non hunter pets | `vmangos/core@27698c426` | None (pure C++) | Verified |
| 26 | [`7024fb8bf`](https://github.com/Ildourol/tortoise-wow-extended/commit/7024fb8bf) | `PORT-0036` | AI & Movement | Fix chain heal ordering (#3060) | `vmangos/core@e2314a59f` | None (pure C++) | Verified |
| 27 | [`ed1ac4c56`](https://github.com/Ildourol/tortoise-wow-extended/commit/ed1ac4c56) | `PORT-0037` | General Systems | Possible fix to XP per kill rounding issue (#3032) | `vmangos/core@47c79c8d3` | None (pure C++) | Verified |
| 28 | [`1757e919b`](https://github.com/Ildourol/tortoise-wow-extended/commit/1757e919b) | `PORT-0038` | Combat & Spells | Cancel immediately channeled spells that are about to fail due to no more valid targets | `vmangos/core@296fbe04b` | None (pure C++) | Verified |
| 29 | [`58c2d6c43`](https://github.com/Ildourol/tortoise-wow-extended/commit/58c2d6c43) | `PORT-0039` | Auth | Realmd: Fix masking of login string if password is empty (#3016) | `vmangos/core@4591fce5c` | None (pure C++) | Verified |
| 30 | [`727942744`](https://github.com/Ildourol/tortoise-wow-extended/commit/727942744) | `PORT-0040` | Combat & Spells | Implement SPELL_FAILED_EQUIPPED_ITEM_CLASS_MAINHAND and OFFHAND | `vmangos/core@30e335309` | None (pure C++) | Verified |
| 31 | [`39d47bd47`](https://github.com/Ildourol/tortoise-wow-extended/commit/39d47bd47) | `PORT-0041` | Mail | Name unknown field in SMSG_MAIL_LIST_RESULT | `vmangos/core@491191deb` | None (pure C++) | Verified |
| 32 | [`bef9a3aa8`](https://github.com/Ildourol/tortoise-wow-extended/commit/bef9a3aa8) | `PORT-0042` | Loot | Handle cross faction team in loot manager | `vmangos/core@05f1dad85` | None (pure C++) | Verified |
| 33 | [`8c5750b4d`](https://github.com/Ildourol/tortoise-wow-extended/commit/8c5750b4d) | `PORT-0043` | General Systems | Fix orientation being used as teleport flags parameter | `vmangos/core@0c1f343f1` | None (pure C++) | Verified |
| 34 | [`be302d223`](https://github.com/Ildourol/tortoise-wow-extended/commit/be302d223) | `PORT-0044` | Encounters & World | Add end script for quest Cycle of Rebirth | `vmangos/core@cc05c0cf8` | None (pure C++) | Verified |
| 35 | [`c8b53b868`](https://github.com/Ildourol/tortoise-wow-extended/commit/c8b53b868) | `PORT-0045` | AI & Movement | Improve follow movement (#2758) | `vmangos/core@d58f8f6b0` | None (pure C++) | Verified |
| 36 | [`f0b9e2679`](https://github.com/Ildourol/tortoise-wow-extended/commit/f0b9e2679) | `PORT-0046` | General Systems | Fix g3d build issue on arm | `vmangos/core@1f65583b3` | None (pure C++) | Verified |
| 37 | [`8499ac9f9`](https://github.com/Ildourol/tortoise-wow-extended/commit/8499ac9f9) | `PORT-0047` | General Systems | Fix Scarshield Portal | `vmangos/core@076f32b41` | `sql/database_updates/world/20231223204218_world.sql` | Verified |
| 38 | [`facc2d80b`](https://github.com/Ildourol/tortoise-wow-extended/commit/facc2d80b) | `PORT-0048` | General Systems | Fix GeoLocking config check (#2010) | `vmangos/core@2169f8207` | None (pure C++) | Verified |
| 39 | [`55917af55`](https://github.com/Ildourol/tortoise-wow-extended/commit/55917af55) | `PORT-0049` | Core Architecture | Small refactor of Player::_ApplyItemBonuses (#1894) | `vmangos/core@fdbf40b59` | None (pure C++) | Verified |
| 40 | [`6165991d5`](https://github.com/Ildourol/tortoise-wow-extended/commit/6165991d5) | `PORT-0050` | Combat & Spells | Fix AddAura negative flag (#1782) | `vmangos/core@e57139e9c` | None (pure C++) | Verified |
| 41 | [`3aea69a69`](https://github.com/Ildourol/tortoise-wow-extended/commit/3aea69a69) | `PORT-0051` | AI & Movement | Fix mount id fallback for creatures (#1736) | `vmangos/core@c80feeff2` | None (pure C++) | Verified |
| 42 | [`bf93e36d9`](https://github.com/Ildourol/tortoise-wow-extended/commit/bf93e36d9) | `PORT-0052` | Combat & Spells | Damaged items should sell for reduced price (#1676) | `vmangos/core@74b99554a` | None (pure C++) | Verified |

---

## 2. Additional File Requirements Analysis

When porting donor bugfixes from VMaNGOS into Tortoise-WoW Extended, each port is evaluated across four artifact dimensions:

1. **Database Migrations (`sql/database_updates/world/`)**:
   - Evaluated for each port. All progressive columns (`patch`, `build`) must be stripped. Custom entities (`spell_template` $\ge 40000$ and world templates $\ge 300000$) must be preserved.

2. **Server Configuration Files (`mangosd.conf`, `realmd.conf`)**:
   - Evaluated for each port. Preserves server defaults.

3. **Build Toolchain & Cryptography Files (`CMakeLists.txt`, `dep/`)**:
   - `BUILD-0001` (`053cb501f`) configured OpenSSL 3.x detection and ARC4 provider loading for Windows MSVC 2022.

4. **Client-Side Data Files (`client-data-1.18.1/` - DBC, Maps, VMaps, MMaps)**:
   - Server data dependencies reside in `twow project/reference-upstreams/client-data-1.18.1/`.
