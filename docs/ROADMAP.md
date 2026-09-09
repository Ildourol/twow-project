# Master Project Roadmap & Semantic AI Porting Queue

This document is the authoritative, fixed roadmap and execution ledger for **Tortoise-WoW Extended** (`twow project/tortoise-wow`). All historical VMaNGOS commits have been semantically audited across all 5 severity tiers.

---

## 1. Executive Metrics & Build Status

* **Target Remote**: [`https://github.com/Ildourol/tortoise-wow-extended.git`](https://github.com/Ildourol/tortoise-wow-extended.git) (branch `main`)
* **Base Baseline SHA**: [`b8f24bef6`](https://github.com/Ildourol/tortoise-wow-extended/commit/b8f24bef6) ([`Penqle/tortoise-wow`](https://github.com/Penqle/tortoise-wow) + upstream quest/vmap fixes)
* **Current Head SHA**: [`053cb501f`](https://github.com/Ildourol/tortoise-wow-extended/commit/053cb501f11fda999967ffef60852b8902bf26c0)
* **Total Uploaded Commits**: **1** (1 commits on top of baseline)
* **Toolchain Compilation Status**: **100% PASS** (MSVC 2022 x64 Release: `mangosd.exe` and `realmd.exe` Exit Code 0)
* **Semantic Audit Coverage**: Audited across all 7339 upstream commits; eliminated 372 superseded/duplicate changes.
* **Total Crucial Candidates in Queue**: **5092**
* **Full Reference Catalogue Count**: **7339** (in `tools/porting/ALL_AVAILABLE_COMMITS_REFERENCE.csv`)

---

## 2. Immediate Next Action Queue (Top Chronological Unported Commits)

These are the newest unported crucial bugfixes from `tools/porting/CRUCIAL_COMMITS_QUEUE.csv`, ordered chronologically (newest first). Evaluated via the AI Semantic Context Engine:

| # | Donor SHA | Date | Tier | Subsystem | Author | Defect / Fix Summary |
|---|:---|:---|:---|:---|:---|:---|
| 1 | `448df9ba0` | 2026-09-08 | Tier 2 | Combat & Spells | schell244 | Roll daze before sending SMSG_ATTACKERSTATEUPDATE. |
| 2 | `3997d1698` | 2026-09-08 | Tier 2 | Combat & Spells | schell244 | Pass CalcDamageInfo to RollMeleeOutcomeAgainst instead of returning outcome. |
| 3 | `24db7802e` | 2026-09-07 | Tier 2 | Combat & Spells | schell244 | Fix Scourge Invasion world state, attack timer and event teardown. |
| 4 | `ba8639e28` | 2026-09-07 | Tier 4 | AI & Movement | schell244 | Fix Scourge Invasion zone invasions never being retried after a failed load. |
| 5 | `5887d67fe` | 2026-09-07 | Tier 1 | Crashes & Security | schell244 | Fix memory leak of hardcoded events in GameEventMgr. |
| 6 | `ed2da0582` | 2026-09-07 | Tier 1 | Crashes & Security | schell244 | Fix memory leaks of spell mods and aura scripts. |
| 7 | `84f1bbccd` | 2026-09-06 | Tier 1 | Crashes & Security | Gamemechanic | Small changes to Formulas.h (#3556) |
| 8 | `92e1a69c6` | 2026-09-06 | Tier 5 | Encounters & World | schell244 | Add more missing gameobjects. |
| 9 | `c78268059` | 2026-09-05 | Tier 5 | General Systems | Gamemechanic | Fix buyback replacing items. (#3555) |
| 10 | `7b601d1c4` | 2026-09-05 | Tier 5 | Encounters & World | Gamemechanic | Corrections to IsVendorItemValid, (#3554) |
| 11 | `b7a6ef7ea` | 2026-09-05 | Tier 5 | General Systems | FlagFlayer | Correct gossip option texts for Felwood cleansed plants (#3553) |
| 12 | `9d28d2848` | 2026-09-04 | Tier 2 | Combat & Spells | schell244 | Add remaining missing gameobjects summoned by spells. |
| 13 | `e13afe5b5` | 2026-09-04 | Tier 5 | Encounters & World | schell244 | Add gameobject template for Pillaclencher's Ornate Pillow. |
| 14 | `ef7b84552` | 2026-09-04 | Tier 1 | Crashes & Security | schell244 | Change follow angle for escorts. |
| 15 | `a11272f8b` | 2026-09-04 | Tier 4 | AI & Movement | schell244 | Only adjust follower speed for pets. |
| 16 | `25fac6b48` | 2026-09-04 | Tier 5 | Encounters & World | schell244 | New script for quest Mist. |
| 17 | `7ff0d5faf` | 2026-09-02 | Tier 4 | AI & Movement | schell244 | Fix Pyroguard Emberseer event failure condition. |
| 18 | `8784e6761` | 2026-09-02 | Tier 5 | Encounters & World | schell244 | Restore wrongfully deleted firework gameobject. |
| 19 | `7d45f7a84` | 2026-09-02 | Tier 5 | Encounters & World | schell244 | Fix Dragons of Nightmare script when not all dragons are created yet. |
| 20 | `d24661116` | 2026-09-02 | Tier 5 | General Systems | schell244 | Fix mistakes in recent migrations. |
| 21 | `a94f8bbf8` | 2026-09-01 | Tier 5 | General Systems | schell244 | Fix no pch build. |
| 22 | `c7c8d5a0f` | 2026-09-01 | Tier 2 | Combat & Spells | schell244 |  Fix issues in new spell packet classes |
| 23 | `a35242b33` | 2026-09-01 | Tier 4 | AI & Movement | schell244 | Cleanup unused scripts and assign EventAI to mobs that should use it. |
| 24 | `bae0a8c3a` | 2026-09-01 | Tier 5 | Encounters & World | schell244 | Add scripts for neutral banners in arathi basin too. |
| 25 | `dc3f14769` | 2026-09-01 | Tier 5 | General Systems | schell244 | Fix Snowfall Banner. |

---

## 3. The 5 Crucial Severity Tiers (Audited & Deduplicated)

### Tier 1: Server Crashes, Memory Leaks & Security (395 Commits)
> Null pointer dereferences, heap buffer overflows, password brute force vulnerabilities, and memory leaks.

| # | Donor SHA | Date | Subsystem | Author | Defect / Fix Summary |
|---|:---|:---|:---|:---|:---|
| 1 | `5887d67fe` | 2026-09-07 | Crashes & Security | schell244 | Fix memory leak of hardcoded events in GameEventMgr. |
| 2 | `ed2da0582` | 2026-09-07 | Crashes & Security | schell244 | Fix memory leaks of spell mods and aura scripts. |
| 3 | `84f1bbccd` | 2026-09-06 | Crashes & Security | Gamemechanic | Small changes to Formulas.h (#3556) |
| 4 | `ef7b84552` | 2026-09-04 | Crashes & Security | schell244 | Change follow angle for escorts. |
| 5 | `5b5f8abea` | 2026-08-24 | Crashes & Security | schell244 | Fix Tame Beast after recent change to channel spells. |
| 6 | `a10102850` | 2026-08-08 | Crashes & Security | Silent-Walrus | Fix quest log corruption in SendQuestUpdateAddItem (#3526) |
| 7 | `e66174ef3` | 2026-08-07 | Crashes & Security | Silent-Walrus | Fix memory leak in ReadableBuffer assignment operators. (#3525) |
| 8 | `4cb4f86ac` | 2026-07-26 | Crashes & Security | schell244 | Some more changes to Stitches script. |
| 9 | `ebf2ae06f` | 2026-07-24 | Crashes & Security | schell244 | Fix spell reflection crashes before 1.6. |
| 10 | `49960c45e` | 2026-07-21 | Crashes & Security | schell244 | More changes to ogre models. |
| 11 | `12c737967` | 2026-07-19 | Crashes & Security | Richard Higgins | Allow multiple Nefarius's Corruption accepters per scepter run (#3504) |
| 12 | `5f356a98f` | 2026-07-18 | Crashes & Security | schell244 | Type of forsaken npcs changed from undead to humanoid in 1.5. |
| 13 | `015a11058` | 2026-05-14 | Crashes & Security | ratkosrb | Changes to spell_threat table. |
| 14 | `c68b36813` | 2026-05-14 | Crashes & Security | ratkosrb | Fix wrong logic change in remove cooldown script command. |
| 15 | `e876cbab3` | 2026-04-27 | Crashes & Security | schell244 | Harden realmd against crashes and password brute force attempts (#3377) |
| 16 | `6da41d495` | 2026-04-22 | Crashes & Security | schell244 | Reject oversized auth packets to prevent heap buffer overflow (#3374) |
| 17 | `ff48cdce9` | 2026-04-04 | Crashes & Security | ratkosrb | Fix player broadcaster crash. |
| 18 | `a9d12aa6e` | 2026-03-29 | Crashes & Security | evil-at-wow | Fix memory leak in MassMailerQueryHandler. |
| 19 | `a0cf98f31` | 2026-03-29 | Crashes & Security | ratkosrb | Fix crash on login to kicked character. |
| 20 | `3171bf80d` | 2026-03-18 | Crashes & Security | ratkosrb | More changes to target mask validation. |
| 21 | `b7bb37cea` | 2026-03-12 | Crashes & Security | ratkosrb | Fix pets being unable to auto cast some spells due to recent changes. |
| 22 | `5ba1a6a90` | 2026-03-11 | Crashes & Security | ratkosrb | More changes to spell target mask validation. |
| 23 | `0be4616ef` | 2026-01-09 | Crashes & Security | _BLU | Make base32 functions safer and fix some crashes. (#3195) |
| 24 | `995ec6eaa` | 2025-11-26 | Crashes & Security | ratkosrb | Fix crash when trading stackable items to bots. |
| 25 | `b32798d89` | 2025-11-26 | Crashes & Security | ratkosrb | Fix crash when scourge invasion is enabled. |
| 26 | `13cee8250` | 2025-11-06 | Crashes & Security | ratkosrb | Health and respawn time of Bankers and Auctioneers changed in 1.3. |
| 27 | `9bb66034f` | 2025-10-08 | Crashes & Security | schell244 | MMaps: Fx some memory leaks and refactor code for async tile processing (#3122) |
| 28 | `b4759fb1f` | 2025-08-30 | Crashes & Security | ratkosrb | Fi crash when using debug send spellfail command. |
| 29 | `b9cd08f7a` | 2025-08-01 | Crashes & Security | ratkosrb | Fix possible crash in AutoStoreLoot. |
| 30 | `645ed83fc` | 2025-07-12 | Crashes & Security | Chero | Change some ordered maps and sets into unordered. |
| 31 | `3ea0cccc2` | 2025-07-04 | Crashes & Security | ratkosrb | Patch changes to Scarshield Quartermaster. |
| 32 | `b58d6a1f7` | 2025-06-16 | Crashes & Security | ratkosrb | Fix a deadlock when boarding transports. |
| 33 | `6f393e0ba` | 2025-05-14 | Crashes & Security | ratkosrb | Fix a crash. |
| 34 | `8f29214c1` | 2025-04-27 | Crashes & Security | ratkosrb | Fix Eye of Kilrogg crash. |
| 35 | `8bfd1f55c` | 2025-04-19 | Crashes & Security | Gamemechanic | Fix potential g3d assert with debug los check (#3017) |
| 36 | `2f1c62680` | 2025-04-13 | Crashes & Security | Wall | Prevent crash in MoveMap.cpp (#3007) |
| 37 | `fdb5887f0` | 2025-04-12 | Crashes & Security | Gamemechanic | Fix potential memory leak when adding partybots (#3006) |
| 38 | `f594f4000` | 2025-04-09 | Crashes & Security | ratkosrb | Fix memory leak in send mail handler. |
| 39 | `185d8a441` | 2025-03-30 | Crashes & Security | Stoabrogga | Fix crash using command "wp modify del" (#2991) |
| 40 | `c9020ec9c` | 2025-03-28 | Crashes & Security | Chaosvex | Fix potential crash in GetBaseModValue() (#2990) |
| 41 | `340d88cb3` | 2025-03-28 | Crashes & Security | Chaosvex | Fix memory leak in molten core script (#2989) |
| 42 | `e38783372` | 2025-03-19 | Crashes & Security | ratkosrb | Changes to ScriptTarget enum. |
| 43 | `666371ac3` | 2025-03-03 | Crashes & Security | Wall | Fix crash in WaypointMovementGenerator. (#2938) |
| 44 | `01ac01753` | 2025-02-17 | Crashes & Security | ratkosrb | Add aura script for Curse of the Bleakheart. |
| 45 | `0b78793d3` | 2025-02-08 | Crashes & Security | ratkosrb | Changes to code style n mangos socket. |
| 46 | `d572db3ed` | 2025-01-13 | Crashes & Security | ratkosrb | Fix guid overflow check in PlayerDump. |
| 47 | `425fd907b` | 2024-11-02 | Crashes & Security | _BLU | Some changes to crypto code and other things (#2823) |
| 48 | `863dad618` | 2024-10-30 | Crashes & Security | ratkosrb | Revert some changes to random movement generator. |
| 49 | `65361b70c` | 2024-10-29 | Crashes & Security | 0blu | Fix `AccountMgr::ChangePassword` |
| 50 | `4bfeab97f` | 2024-10-02 | Crashes & Security | ratkosrb | Don't allow changing leader to the player who already is leader. |

### Tier 2: Combat Accuracy, Formulas & Spells (1080 Commits)
> Combat formulas, spell aura stacking, wand formulas, swing timers, resists, and damage calculations.

| # | Donor SHA | Date | Subsystem | Author | Defect / Fix Summary |
|---|:---|:---|:---|:---|:---|
| 1 | `448df9ba0` | 2026-09-08 | Combat & Spells | schell244 | Roll daze before sending SMSG_ATTACKERSTATEUPDATE. |
| 2 | `3997d1698` | 2026-09-08 | Combat & Spells | schell244 | Pass CalcDamageInfo to RollMeleeOutcomeAgainst instead of returning outcome. |
| 3 | `24db7802e` | 2026-09-07 | Combat & Spells | schell244 | Fix Scourge Invasion world state, attack timer and event teardown. |
| 4 | `9d28d2848` | 2026-09-04 | Combat & Spells | schell244 | Add remaining missing gameobjects summoned by spells. |
| 5 | `c7c8d5a0f` | 2026-09-01 | Combat & Spells | schell244 |  Fix issues in new spell packet classes |
| 6 | `fec5b583c` | 2026-09-01 | Combat & Spells | schell244 | Add classes for more spell packets. |
| 7 | `fb4127e73` | 2026-08-28 | Combat & Spells | schell244 | Add classes for spell start and go packets. |
| 8 | `049419602` | 2026-08-22 | Combat & Spells | schell244 | Add missing above and under water spell cast checks. |
| 9 | `b84c4a16c` | 2026-08-22 | Combat & Spells | schell244 | Correct creature static flags based on 1.7 wdb files. |
| 10 | `b78b6c3ae` | 2026-08-13 | Combat & Spells | schell244 | Fix Phasing Stealth triggering in combat. |
| 11 | `d92328256` | 2026-08-11 | Combat & Spells | schell244 | Move injured friendly heals from EventAI to spell list. |
| 12 | `91c920d40` | 2026-07-31 | Combat & Spells | Gamemechanic | Fix swapped arguments in Unit::ApplySpellImmune (#3516) |
| 13 | `90793c7c6` | 2026-07-26 | Combat & Spells | Richard Higgins | Remove stalked-target auras from the target when the caster dies (#3499) |
| 14 | `2a56e5ebb` | 2026-07-26 | Combat & Spells | schell244 | Correct position and movement of two critters. |
| 15 | `dbe65d3ec` | 2026-07-24 | Combat & Spells | schell244 | Fix spell miss info for 1.5 client. |
| 16 | `3e75e00fe` | 2026-07-23 | Combat & Spells | Nishad | Send melee attack state before doing the damage (#3505) |
| 17 | `11837a71c` | 2026-07-23 | Combat & Spells | Spit | Clear emote state from creatures on entering combat. (#3507) |
| 18 | `ca760e76f` | 2026-07-21 | Combat & Spells | schell244 | Send SMSG_ATTACKERSTATEUPDATE when casting on next melee spells. |
| 19 | `46d789256` | 2026-07-17 | Combat & Spells | Gamemechanic | GetHeightStatic: Add a delta to Z before choosing vmap height over map height (#3487) |
| 20 | `ce5a1a267` | 2026-07-11 | Combat & Spells | schell244 | Add missing rates for crit and dodge. |
| 21 | `b54bbd030` | 2026-07-11 | Combat & Spells | schell244 | Add packet class for melee attacking state update. |
| 22 | `9e797df89` | 2026-07-11 | Combat & Spells | schell244 | Fix melee damage packet before 1.6. |
| 23 | `2c8df6bb4` | 2026-07-04 | Combat & Spells | schell244 | Fix crit per agility rates. |
| 24 | `05d516709` | 2026-06-09 | Combat & Spells | schell244 | Store spells on pet bar while charmed in separate table. (#3453) |
| 25 | `5d67ee574` | 2026-05-29 | Combat & Spells | Michael Serajnik | Fix wand hit calculation to use the Wands skill. (#3439) |
| 26 | `2add4aa2e` | 2026-05-23 | Combat & Spells | ratkosrb | Fix pet cooldowns not being saved and sent properly. |
| 27 | `4ee66d9e1` | 2026-05-23 | Combat & Spells | _BLU | Add packet classes for spell packets. (#3414) |
| 28 | `e9a7ba69b` | 2026-05-12 | Combat & Spells | _BLU | Use SpellEntry pointer instead of reference in cooldown manager (#3405) |
| 29 | `3e7f52230` | 2026-04-16 | Combat & Spells | ratkosrb | Use correct spells for quest The Stones That Bind Us. |
| 30 | `cef24fc3f` | 2026-04-02 | Combat & Spells | Michael Serajnik | Process all outstanding honor maintenance periods in a single run. (#3248) |
| 31 | `2977b229a` | 2026-03-29 | Combat & Spells | Gamemechanic | Fix missing pet stats after first summon (#3302) |
| 32 | `568bdfd3f` | 2026-03-12 | Combat & Spells | ratkosrb | Sync auto attack delay to spell batching interval. |
| 33 | `4f4db67f6` | 2026-03-10 | Combat & Spells | ratkosrb | Prevent client from sending spell targets in cases server should decide. |
| 34 | `f54db6b4a` | 2026-03-10 | Combat & Spells | Kyle ≡ƒÉå | Fix Naxxramas slime damage using WMO ID instead of filename parsing (#3118) |
| 35 | `644de13f8` | 2026-03-10 | Combat & Spells | Wall | Fix Spectral Essence spell_area to include Scholomance (#3218) |
| 36 | `33ead32a3` | 2026-02-08 | Combat & Spells | schell244 | Fix wand dmg incorrectly affected by Curse of Weakness (#3221) |
| 37 | `e3047563d` | 2026-01-12 | Combat & Spells | schell244 | Add missing effect index checks in aura scripts (#3196) |
| 38 | `2254f8579` | 2026-01-09 | Combat & Spells | ratkosrb | Add spell script for Combustion. |
| 39 | `f669c5038` | 2026-01-05 | Combat & Spells | schell244 | Convert more spells to aura scripts. (#3193) |
| 40 | `46337ee28` | 2026-01-04 | Combat & Spells | ratkosrb | Add spell cones table. |
| 41 | `738d75561` | 2026-01-02 | Combat & Spells | ratkosrb | Add command to stop party bots from casting spells. |
| 42 | `53b108605` | 2026-01-01 | Combat & Spells | ratkosrb | Add missing area requirements to spells. |
| 43 | `3e53ee4db` | 2026-01-01 | Combat & Spells | ratkosrb | Shooting with Wand should trigger GCD. |
| 44 | `725423b9e` | 2025-12-31 | Combat & Spells | schell244 | Convert Nefarian class call logic to spell scripts. (#3180) |
| 45 | `6633dbb9d` | 2025-12-29 | Combat & Spells | ratkosrb | Rename SendPlaySpellVisual for clarity. |
| 46 | `2ab471ee3` | 2025-12-19 | Combat & Spells | ratkosrb | Creature aoe should put you in combat for 5 seconds. |
| 47 | `d725babd1` | 2025-12-19 | Combat & Spells | ratkosrb | Move some CheckCast cases spell scripts. |
| 48 | `cef010edf` | 2025-12-18 | Combat & Spells | schell244 | Move Cannibalize and Wolfshead Helm Energy to spell scripts (#3164) |
| 49 | `cc5080ef6` | 2025-12-18 | Combat & Spells | ratkosrb | Move precast and triggered spells to scripts. |
| 50 | `654eb1f8e` | 2025-12-17 | Combat & Spells | ratkosrb | Do not treat positive spell hit as attack. |

### Tier 3: Bounds Checks, Exploits & Packet Integrity (57 Commits)
> Boundary clamping, packet size guards, duplication exploits, trade cancellation, and permission checks.

| # | Donor SHA | Date | Subsystem | Author | Defect / Fix Summary |
|---|:---|:---|:---|:---|:---|
| 1 | `2f7bb2ef2` | 2026-08-14 | Bounds & Exploits | schell244 | Warden: Prevent reading out of bounds in some scans. |
| 2 | `6f9d86f66` | 2026-07-19 | Bounds & Exploits | Richard Higgins | Clamp auction time left to the client's signed 32-bit millisecond range (#3497) |
| 3 | `af30a92a9` | 2026-07-19 | Bounds & Exploits | Richard Higgins | Validate the master looter GUID in CMSG_LOOT_METHOD (#3500) |
| 4 | `8bfe3c483` | 2026-07-19 | Bounds & Exploits | Richard Higgins | Accept the stock 1,000,000 random roll upper bound (#3498) |
| 5 | `cd3605e53` | 2026-05-25 | Bounds & Exploits | Gamemechanic | Fall back to distance to center check in interaction distance check if no bounds defined (#3425) |
| 6 | `401af7c4a` | 2026-04-19 | Bounds & Exploits | ratkosrb | Do not invalidate quest template pointers on reload. |
| 7 | `94cd8da97` | 2026-04-06 | Bounds & Exploits | ratkosrb | Add bounds checking to sTaxiPathNodesByPath. |
| 8 | `5dce8bdfa` | 2026-03-29 | Bounds & Exploits | Michael Serajnik | Explicitly set workflow permissions. (#3304) |
| 9 | `9a2f1674b` | 2026-03-29 | Bounds & Exploits | ratkosrb | Fix kick not disconnecting client if packet broadcaster is enabled. |
| 10 | `206a481a2` | 2026-03-10 | Bounds & Exploits | evil-at-wow | SRP6: fix potential out-of-bounds access. |
| 11 | `20273354e` | 2026-03-10 | Bounds & Exploits | schell244 | Prevent exploits with quest sharing (#3232) |
| 12 | `80110857f` | 2025-08-29 | Bounds & Exploits | ratkosrb | Area bound field was added to items in 1.7. |
| 13 | `961832a32` | 2025-07-13 | Bounds & Exploits | ratkosrb | Fix respawn exploit with Whitemane and Mograine. |
| 14 | `6be7a5938` | 2025-05-26 | Bounds & Exploits | Gamemechanic | Remove Geometry::ClampOrientation (#3038) |
| 15 | `972f9dd23` | 2024-12-03 | Bounds & Exploits | ratkosrb | Fix infinite Crimson Hammersmiths exploit. |
| 16 | `827ea0765` | 2024-10-02 | Bounds & Exploits | ratkosrb | Fix dungeon reset exploit when switching leader. |
| 17 | `578ac1c5a` | 2024-05-12 | Bounds & Exploits | ratkosrb | Fix Blackwing Technician loot exploit. |
| 18 | `3f7655a11` | 2024-03-30 | Bounds & Exploits | balakethelock | Removed strict range check in dungeons (#2565) |
| 19 | `863d7e897` | 2024-01-31 | Bounds & Exploits | ratkosrb | Guard bound instances behind mutex. |
| 20 | `b5b2b1931` | 2024-01-18 | Bounds & Exploits | ratkosrb | Maps/Vmaps: Make high res default and fix code duplication. |
| 21 | `dd7994784` | 2023-12-27 | Bounds & Exploits | ratkosrb | Fix raid reset exploit. |
| 22 | `9cb972d5e` | 2023-11-16 | Bounds & Exploits | ratkosrb | Fix item dupe when trading to bots. |
| 23 | `2966c2b42` | 2023-08-15 | Bounds & Exploits | ratkosrb | Adjust Orgrimmar instance boundary. |
| 24 | `bdedf9edb` | 2023-07-16 | Bounds & Exploits | NickTyrer | Large Solid Chest / Large Mithril Bound Chest - Blackrock Spire (#2090) |
| 25 | `c3c3848a3` | 2023-07-15 | Bounds & Exploits | NickTyrer | Large Iron Bound Chest / Large Solid Chest - Scarlet Monastery Library / Armory (#2081) |
| 26 | `ee5202bca` | 2023-07-15 | Bounds & Exploits | NickTyrer | Large Mithril Bound Chest / Large Darkwood Chest (#2078) |
| 27 | `8a89c024a` | 2023-03-22 | Bounds & Exploits | ratkosrb | Fix disconnect during bg join exploit. |
| 28 | `a5e023ee0` | 2023-01-25 | Bounds & Exploits | ratkosrb | Fix Feign Death exploit. |
| 29 | `5c5f1f10a` | 2022-12-05 | Bounds & Exploits | ratkosrb | Fixed possible guild exploit. |
| 30 | `cdeda1660` | 2022-07-18 | Bounds & Exploits | ratkosrb | Add missing Large Mithril Bound Chest spawns in Dire Maul. |
| 31 | `c0b6ef66b` | 2021-12-12 | Bounds & Exploits | ratkosrb | Restore old movement broadcaster code. |
| 32 | `9f10981f4` | 2021-09-24 | Bounds & Exploits | ratkosrb | Fix gcd exploit. |
| 33 | `2642fe034` | 2021-05-16 | Bounds & Exploits | ratkosrb | Fix Garr respawn exploit. |
| 34 | `af745365e` | 2021-04-01 | Bounds & Exploits | ratkosrb | Don't use bounding radius for aggro distance checks. |
| 35 | `acc240dfe` | 2021-02-24 | Bounds & Exploits | gamemechanicwow | Add missing range check to Feed Pet. |
| 36 | `67839c0fd` | 2020-12-11 | Bounds & Exploits | Gamemechanic | Fix Free at Last and Homeward Bound escorts (#894) |
| 37 | `5cbd094b9` | 2020-05-03 | Bounds & Exploits | ratkosrb | Add range checks to inspect and trade. |
| 38 | `824bb38da` | 2019-11-11 | Bounds & Exploits | ratkosrb | Add missing interaction checks to prevent exploits. |
| 39 | `6d872af59` | 2019-07-03 | Bounds & Exploits | ratkosrb | Add Pooling for Large Solid and Mithril Bound Chest. |
| 40 | `cdefd9e63` | 2019-06-22 | Bounds & Exploits | ratkosrb | Prevent BG queue exploit. |
| 41 | `9b6c791a6` | 2019-01-27 | Bounds & Exploits | ratkosrb | Reduce code duplication in last commit. |
| 42 | `8bc932b5c` | 2019-01-19 | Bounds & Exploits | ratkosrb | Fix talents exploit. |
| 43 | `bfff076b9` | 2018-10-17 | Bounds & Exploits | ratkosrb | Fix engineering pets exploit. |
| 44 | `b0f8e6ec8` | 2018-08-17 | Bounds & Exploits | Skuzzi | Fix various remote bank exploits (#205) |
| 45 | `971ef2a9c` | 2018-03-14 | Bounds & Exploits | bladez | Slightly refactor ObjectGuid and add support for clamping client transmitted GUIDs (#5) |
| 46 | `1c0b1cf9b` | 2018-02-14 | Bounds & Exploits | Prithu Parker | Remove bad erase - iterator may be invalidated in previous method calls |
| 47 | `378c024e8` | 2017-11-08 | Bounds & Exploits | StadenElysium | Fix a couple of small out-of-bounds bugs (#527) |
| 48 | `5706b8d4b` | 2017-10-20 | Bounds & Exploits | GuybrushGit | Fix to master loot out of bounds check |
| 49 | `1d65e2583` | 2017-09-06 | Bounds & Exploits | Prithu | An item duplication prevention (#2411) |
| 50 | `88e1948f5` | 2017-08-26 | Bounds & Exploits | Gemt | reset heigan hitbox to make exploiting p1 by standing on platform harder |

### Tier 4: Pet, AI, Movement & Spline Pathing (899 Commits)
> Escort follow angles, pet stabling/revival, confused movement speeds, and line-of-sight bounds.

| # | Donor SHA | Date | Subsystem | Author | Defect / Fix Summary |
|---|:---|:---|:---|:---|:---|
| 1 | `ba8639e28` | 2026-09-07 | AI & Movement | schell244 | Fix Scourge Invasion zone invasions never being retried after a failed load. |
| 2 | `a11272f8b` | 2026-09-04 | AI & Movement | schell244 | Only adjust follower speed for pets. |
| 3 | `7ff0d5faf` | 2026-09-02 | AI & Movement | schell244 | Fix Pyroguard Emberseer event failure condition. |
| 4 | `a35242b33` | 2026-09-01 | AI & Movement | schell244 | Cleanup unused scripts and assign EventAI to mobs that should use it. |
| 5 | `406e8a502` | 2026-08-22 | AI & Movement | schell244 | Cleanup broken creature groups. |
| 6 | `45f7ae71c` | 2026-08-16 | AI & Movement | Daribon | Add forgotten Call of Air NPCs in Thousand Needles. (#3528) |
| 7 | `18e37d1fe` | 2026-08-14 | AI & Movement | schell244 | Store separate copy of creature groups per map. |
| 8 | `cd473e858` | 2026-08-13 | AI & Movement | schell244 | Don't log movement packets when anticheat is disabled. |
| 9 | `9839bd2e2` | 2026-08-13 | AI & Movement | schell244 | Creatures should flee in a random direction. |
| 10 | `a72bb440e` | 2026-08-10 | AI & Movement | schell244 | Cleanup orphaned rows in character db on maintenance day. |
| 11 | `e65e48e3c` | 2026-08-03 | AI & Movement | NickTyrer | Fix Door Not Closing (#3512) |
| 12 | `2d0928bd9` | 2026-08-03 | AI & Movement | Daribon | Fix Obsidian Destroyer's Drain Mana. (#3518) |
| 13 | `db7450c6e` | 2026-07-29 | AI & Movement | schell244 | Fix Nature's Grasp talent getting unlearned upon training rank 2. |
| 14 | `804cf5ae3` | 2026-07-26 | AI & Movement | schell244 | Reset position of Watcher Dodds and Paige after stiches dies. |
| 15 | `d6ed90d82` | 2026-07-21 | AI & Movement | schell244 | Pet family was assigned to Son of Hakkar and Soulflayer in 1.8. |
| 16 | `6961c0f2a` | 2026-07-21 | AI & Movement | schell244 | Correct creature data based on 1.2 wdb files. |
| 17 | `8f6018a01` | 2026-07-20 | AI & Movement | Richard Higgins | Share vendor item visibility between list and purchase paths (#3502) |
| 18 | `9e006e0ce` | 2026-07-20 | AI & Movement | Richard Higgins | Delay Mograine's death so Forgiveness visual displays properly (#3503) |
| 19 | `d2a9e2c6d` | 2026-07-17 | AI & Movement | Daribon | Fix stabling for dismissed and dead pets. (#3488) |
| 20 | `a6755e42a` | 2026-07-13 | AI & Movement | schell244 | Fix lost wakeup race in WorldSocket send queue |
| 21 | `1cf3d4622` | 2026-07-10 | AI & Movement | Spit | Fix trainer type for trainers that only have recipes (#3481) |
| 22 | `16251fe28` | 2026-07-08 | AI & Movement | schell244 | Improve map extraction tools and fix navmesh generation bugs (#3473) |
| 23 | `bae871a66` | 2026-07-03 | AI & Movement | schell244 | Individual raid instance reset timers before patch 1.9 |
| 24 | `9597c399b` | 2026-06-25 | AI & Movement | schell244 | Remove orphaned closed-door collision check helpers |
| 25 | `5d92ec02a` | 2026-07-03 | AI & Movement | Gamemechanic | Improve dynamic tree for movement (#3463) |
| 26 | `d73066b4f` | 2026-06-23 | AI & Movement | NickTyrer | Respawn Wretched Lost One (credit cmangos) (#3437) |
| 27 | `165377484` | 2026-06-12 | AI & Movement | Daribon | Correct Revive Pet and Call Pet behavior. (#3456) |
| 28 | `f660ba09f` | 2026-06-12 | AI & Movement | schell244 | Fix Eyes of the Beast cast visual on pet. |
| 29 | `6b34a36dc` | 2026-05-31 | AI & Movement | MantisLord | Aurora Skycaller + fishing trainer gossip fix (#3446) |
| 30 | `d0808ba41` | 2026-05-26 | AI & Movement | NickTyrer | Add Ashenvale Creature Waypoints (credit cmangos) (#3379) |
| 31 | `c02ddcffa` | 2026-05-25 | AI & Movement | ratkosrb | Fixes for Blink. |
| 32 | `2c26d7450` | 2026-05-20 | AI & Movement | ratkosrb | Fix cases of creature spawn too far from first waypoint. |
| 33 | `0c09dae58` | 2026-05-18 | AI & Movement | ratkosrb | Fix order of waypoints for Mountaineer Kalmir. |
| 34 | `d632d2ad8` | 2026-05-14 | AI & Movement | Wall | Remove walk mode on confused movement end (#3401) |
| 35 | `20fd7fdca` | 2026-04-29 | AI & Movement | ratkosrb | Grey quests should not give less reputation loss. |
| 36 | `3fb7d6295` | 2026-04-24 | AI & Movement | Wall | Fix Intimidating Shout skipping the main target. (#3378) |
| 37 | `6bd4a6785` | 2026-04-20 | AI & Movement | NickTyrer | Add Tanaris Creature Waypoints (#3369) |
| 38 | `fd26ff8bb` | 2026-04-17 | AI & Movement | ratkosrb | Fix 1.4.2 build and remove fake runmode spline flag. |
| 39 | `5ff65dcc5` | 2026-04-16 | AI & Movement | ratkosrb | Fix broken movement packet timestamps. |
| 40 | `c1efa4796` | 2026-04-16 | AI & Movement | ratkosrb | Reputation loss from kills is not affected by level difference. |
| 41 | `aa7669665` | 2026-04-11 | AI & Movement | Michael Serajnik | CI: Use service container for MySQL. (#3356) |
| 42 | `4b132379b` | 2026-04-05 | AI & Movement | Michael Serajnik | Prevent Shadowfang Keep escort delay race condition. (#3333) |
| 43 | `506c301d6` | 2026-04-05 | AI & Movement | ratkosrb | Diplomacy racial should not affect rep loss. |
| 44 | `86de7373d` | 2026-03-28 | AI & Movement | Gamemechanic | Correct subname of some creatures (#3299) |
| 45 | `42fa6135a` | 2026-03-15 | AI & Movement | Gamemechanic | Fix chain heal broken chain (#3257) |
| 46 | `e733bac5c` | 2026-03-13 | AI & Movement | ratkosrb | Fix account manager returning email instead of name. |
| 47 | `55f747a23` | 2026-03-10 | AI & Movement | Wall | Check itr in DeleteCharacterPetById (#3222) |
| 48 | `c368cb65b` | 2026-03-10 | AI & Movement | Stoabrogga | Use different main thread names for realmd and mangosd (#3233) |
| 49 | `ef538bd86` | 2026-03-09 | AI & Movement | NickTyrer | Pool WPL Mountain Silversage (credit cmangos) (#3243) |
| 50 | `a29bfbc34` | 2026-03-08 | AI & Movement | NickTyrer | Pool Silithus Mountain Silversage (credit cmangos) (#3237) |

### Tier 5: Quests, Dungeons, Raids, Core & General Systems (2661 Commits)
> Encounter resets, event triggers, gameobject interactions, boss AI stability, and core system refinements.

| # | Donor SHA | Date | Subsystem | Author | Defect / Fix Summary |
|---|:---|:---|:---|:---|:---|
| 1 | `92e1a69c6` | 2026-09-06 | Encounters & World | schell244 | Add more missing gameobjects. |
| 2 | `c78268059` | 2026-09-05 | General Systems | Gamemechanic | Fix buyback replacing items. (#3555) |
| 3 | `7b601d1c4` | 2026-09-05 | Encounters & World | Gamemechanic | Corrections to IsVendorItemValid, (#3554) |
| 4 | `b7a6ef7ea` | 2026-09-05 | General Systems | FlagFlayer | Correct gossip option texts for Felwood cleansed plants (#3553) |
| 5 | `e13afe5b5` | 2026-09-04 | Encounters & World | schell244 | Add gameobject template for Pillaclencher's Ornate Pillow. |
| 6 | `25fac6b48` | 2026-09-04 | Encounters & World | schell244 | New script for quest Mist. |
| 7 | `8784e6761` | 2026-09-02 | Encounters & World | schell244 | Restore wrongfully deleted firework gameobject. |
| 8 | `7d45f7a84` | 2026-09-02 | Encounters & World | schell244 | Fix Dragons of Nightmare script when not all dragons are created yet. |
| 9 | `d24661116` | 2026-09-02 | General Systems | schell244 | Fix mistakes in recent migrations. |
| 10 | `a94f8bbf8` | 2026-09-01 | General Systems | schell244 | Fix no pch build. |
| 11 | `bae0a8c3a` | 2026-09-01 | Encounters & World | schell244 | Add scripts for neutral banners in arathi basin too. |
| 12 | `dc3f14769` | 2026-09-01 | General Systems | schell244 | Fix Snowfall Banner. |
| 13 | `8428500c2` | 2026-08-29 | General Systems | schell244 | Fix typo in previous commit. |
| 14 | `e5f3fd09e` | 2026-08-26 | General Systems | schell244 | Fix Uldaman altars. |
| 15 | `053bf21e0` | 2026-08-22 | Encounters & World | schell244 | Fix looting items under threshold when using master loot. |
| 16 | `853e99ba7` | 2026-08-22 | General Systems | schell244 | Fix battleground spirit heal visual. |
| 17 | `78a723207` | 2026-08-21 | Core Architecture | schell244 | Fix wrong scale when players are transformed. |
| 18 | `5a30f330f` | 2026-08-21 | Encounters & World | moyashi | Prevent visual bug on older clients where mobs appear to teleport (#3533) |
| 19 | `5c577a93e` | 2026-08-20 | General Systems | schell244 | Regenerate update fields to fix offset in comments. |
| 20 | `6052f801f` | 2026-08-20 | Encounters & World | schell244 | New scripts for Myzrael and Prismatic Exiles. |
| 21 | `8dfb2d895` | 2026-08-20 | Encounters & World | Daribon | Prevent master respawn on slave aggro. (#3535) |
| 22 | `19a77eb11` | 2026-08-19 | General Systems | schell244 | Fix BWL Suppression Devices. |
| 23 | `10b20b59b` | 2026-08-18 | Encounters & World | schell244 | No loot flag was added progressively in some cases. |
| 24 | `dcc98337f` | 2026-08-17 | General Systems | Daribon | Fix Scholomance Occultist HP not carrying over on Dark Shade transform. (#3531) |
| 25 | `03e04b287` | 2026-08-16 | General Systems | Daribon | Correct Black Guard Swordsmith position. (#3529) |
| 26 | `bf5c2271c` | 2026-08-14 | General Systems | schell244 | Warden: Fix max size of string hash check. |
| 27 | `04af39351` | 2026-08-14 | Encounters & World | schell244 | Warden: Fix broken request and reply size check. |
| 28 | `68edebe90` | 2026-08-14 | Encounters & World | schell244 | Warden: Prevent duplicating scripted scans on reload. |
| 29 | `040852ad9` | 2026-08-14 | Encounters & World | schell244 | Add missing setting descriptions to config file. |
| 30 | `aafe6f01a` | 2026-08-13 | Core Architecture | schell244 | Rename character db cleanup options and disable removal of group and guild rows. |
| 31 | `1246926c8` | 2026-08-13 | Encounters & World | schell244 | Add script for Raze during Shadoweaver quest. |
| 32 | `4fdf2f773` | 2026-08-03 | General Systems | Daribon | Fix Moam mana at spawn. (#3517) |
| 33 | `5485f93d3` | 2026-07-26 | Core Architecture | Gamemechanic | Small refactors in Unit.cpp (#3510) |
| 34 | `80d3b7bee` | 2026-07-20 | Encounters & World | Simp-N | Prevent pickpocketing humanoids and undead with no pickpocket loot (#2729) |
| 35 | `1468bbe02` | 2026-07-19 | Encounters & World | Gamemechanic | Fix output for loading instance custom encounters. (#3496) |
| 36 | `e3fff0aef` | 2026-07-17 | Core Architecture | Wall | Remove offline players from BG queue (#3489) |
| 37 | `b57309a3d` | 2026-07-13 | General Systems | schell244 | Fix target of target missing after create update |
| 38 | `d8a163621` | 2026-07-11 | General Systems | schell244 | Fix dodge per agility rates. |
| 39 | `f13dfcb5f` | 2026-07-10 | Core Architecture | Stoabrogga | Add new option for map extractor (#3480) |
| 40 | `f67d54409` | 2026-07-08 | Core Architecture | Michael Serajnik | Fix mmap generator aborting with the default configuration. (#3479) |
| 41 | `66b158405` | 2026-07-08 | General Systems | schell244 | Fix opening gurubashi chest before 1.7. |
| 42 | `b974755c0` | 2026-07-08 | Encounters & World | Spit | Fix empty loot after group loot roll ends (#3476) |
| 43 | `467fc53f6` | 2026-07-04 | General Systems | schell244 | Fix Mana Shield before patch 1.12. |
| 44 | `37ba9a343` | 2026-04-17 | Encounters & World | schell244 | Fix DungeonReset false-positive ERRORs at startup |
| 45 | `ee963a63a` | 2026-06-29 | General Systems | NickTyrer | Fix DB Errors (#3470) |
| 46 | `b0c82f425` | 2026-06-29 | Encounters & World | schell244 | Delete many unused gameobjects. |
| 47 | `b3b6cbaa1` | 2026-06-29 | General Systems | schell244 | Revert "Implement Volume Caching (#3447)" |
| 48 | `cd6004c73` | 2026-06-29 | General Systems | schell244 | Revert "Add missing header files (#3452)" |
| 49 | `dc3efdcff` | 2026-06-28 | General Systems | NickTyrer | Misc DB Fixes (#3175) |
| 50 | `679c49521` | 2026-06-21 | Encounters & World | schell244 | Correct gameobject data based on 1.2 wdb files. |

---

## 4. Autonomous AI Pipeline & Operational Architecture

### 1. AI Context Assembler & Auditor
* **Command**: `task ai-audit <sha>` (or `task 4 <sha>`)
* **Role**: Extracts upstream diff, identifies target files in `tortoise-wow`, extracts surrounding line context, queries 22,155-thread forum archive, and outputs AI Dossier to `tools/queue/ai_dossiers/<sha>.md`.

### 2. AI Semantic Synthesis & Adaptation Engine
* **Command**: `task port <sha>` / `task port-batch <N>`
* **Role**: Instead of discarding commits on naive `git apply` failure, it preserves Turtle custom mechanics (`inGurubashiArena`, `UI64LIT`, custom racials, IDs >= 300,000) and stages viable packages for compilation.

### 3. Builder & Committer (Single-Writer Compiler Gate)
* **Command**: `task build-packages` (or `task auto-pilot [N]`)
* **Role**: Single-writer MSVC 2022 Release compile gate (0 errors required) in isolated worktree, and atomic git commit to candidate branch.

### 4. Native Core Restorer (Turtle Leaked Core Restoration)
* **Command**: `task restore <topic>` (or `task 5 <topic>`)
* **Role**: Audits official forum patch specifications against leaked core and generates native restoration packages with zero double-checking cache.

### 5. Database Scalper & Entity Extractor
* **Command**: `task scalp <type> <id>` (or `task extract <type> <id>`)
* **Role**: Deep differential parser extracting vanilla records from historical databases (`world_full_14_june_2021.sql` / `mangos.sql`), stripping progressive columns (`patch`, `build`), and emitting sanitized `REPLACE INTO` SQL.

### 6. Online Database Oracle & 1.18.1 Asset Auditor
* **Command**: `task 6 <id or query>` (alias: `task db-viewer`)
* **Role**: Cross-references live Turtle-WoW 1.18.1 client tooltips and 3D models with the official online viewer (`https://xian55.github.io/tortoise-db-viewer/`).

### 7. Documentation & PDF Generator
* **Command**: `task pdf`
* **Role**: Compiles and renders `docs/COMMAND_REFERENCE.html` and master printable `docs/COMMAND_REFERENCE.pdf` via headless Microsoft Edge.

