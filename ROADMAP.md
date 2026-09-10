# Module-playerbots Porting & Stabilization Roadmap

This roadmap documents the prioritized implementation tracks and verified progression milestones for integrating upstream fixes into Turtle WoW Extended.

---

## Milestone Progress Overview

| Phase | Description | Status | Target Scope |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Repository Identity, Environment & Baseline Setup | **COMPLETE** | Bootstrap infrastructure, state stores, CMake verification. |
| **Phase 1** | vMaNGOS Stability & Combat Correctness Parity | **IN PROGRESS** | Port high-priority healer targeting, eating interrupts, resurrection fixes. |
| **Phase 2** | CMaNGOS High-Priority Crash & Null-Pointer Fixes | **IN PROGRESS** | Port corpse crashes, player location null checks, battleground teleport guards. |
| **Phase 3** | Dungeon Clear & Group AI Hardening | **PLANNED** | Multi-bot group synchronization, boss pulls, wipe recovery stability. |
| **Phase 4** | Mature Bot Features & Usability Enhancements | **PLANNED** | RTSC command fixes, food strategy improvements, travel target distribution. |
| **Phase 5** | Performance Optimization & Concurrency Audits | **PLANNED** | Profile high-population bot ticks (500+ bots), MMAP query efficiency. |
| **Phase 6** | Continuous Upstream Synchronization & Watermark Tracking | **PLANNED** | Recurring delta audits and maintenance scans. |

---

## Phase 0: Repository Identity & Baseline Setup (COMPLETE)
- [x] Identify target repository: `tortoise-wow-extended` (`mantech-turtle` @ `a80ca1d1d4d5ac71573e9d06f5b80c4068c910ef`).
- [x] Resolve CMaNGOS donor repository: `playerbots` (`master` @ `89a4e5aebd6aa41ee87f6e65d89b66fff5c5c7c1`).
- [x] Resolve vMaNGOS donor repository: `core` (`vmangos-ike3-playerbots` @ `2ff8489f74b82617591f9ada3bab2772bf849da2`).
- [x] Establish standalone project-management layer (`AGENTS.md`, `COMMANDS.md`, `ROADMAP.md`, `docs/`, `state/`, `reports/`).
- [x] Verify toolchain: CMake 4.4.2, MSVC 2022 (v143 x64), ACE 8.x, Boost 1.92.0.
- [x] Establish baseline CMake configuration with `BUILD_PLAYERBOTS=ON` and `MODULE_MOD_DUNGEON_CLEAR=static`.
- [x] Enforce absolute project isolation (zero cross-project links or runtime dependencies).

---

## Phase 1: vMaNGOS Stability & Combat Correctness Parity
- [ ] **Healer Prioritization**: Port tank healing priority over general DPS (`ac4c83adf`).
- [ ] **Eating/Drinking Interrupt**: Interrupt eating/drinking when master moves away (`2ff8489f7`).
- [ ] **Movement & Strategy Clears**: Fix stay/guard strategy clearing logic (`21c960e54`).
- [ ] **Resurrection Target Validation**: Fix bots accepting invalid resurrections and deadlocks (`e4d01b08b`, `bedf0725d`).
- [ ] **Cure & Dispel Logic**: Improve bot disease/poison/curse removal (`e52e28a45`).
- [ ] **Combat Stance Dynamic Switching**: Role-based combat stances (`b1910dcd6`, `2501cf795`).

---

## Phase 2: CMaNGOS High-Priority Crash & Null-Pointer Fixes
- [x] **Player Location Crash**: Prevent crash when getting object location of non-existent player (`46cec841` -> target `29a8df50`). *(PORTED & PUSHED commit-by-commit)*
- [x] **Corpse Location Crash**: Prevent crash when corpse does not exist or coordinates are `0,0,0,0` (`6ad783c9` -> target `7e5024c9`). *(PORTED & PUSHED commit-by-commit)*
- [ ] **Creature Data Description Crash**: Prevent crash when inspecting non-existent creature templates (`084a1368`).
- [ ] **Factionless Mind-Control Reaction**: Guard creature controlled by player without faction (`ddbbfeda`).
- [ ] **Stale Battleground Teleport**: Prevent bot teleporting to non-existent or concluded battlegrounds (`89a4e5ae`).
- [ ] **Filter Expansion Noise**: Reject TBC/WotLK commits (`993f1809`, etc.).

---

## Phase 3: Dungeon Clear & Group AI Hardening
- [ ] Audit Dungeon Clear follower states during long elevator and transition hops.
- [ ] Verify group tank assignment stability during multi-target pulls.
- [ ] Audit wipe recovery and spirit release actions (`DcRezRecovery`).

---

## Phase 4: Mature Bot Features & Usability Enhancements
- [ ] RTSC command persistence (`be2187e1c`).
- [ ] Food and drink consumption thresholds at critical health (`00131ee2`).
- [ ] World buff travel target priority adjustments (`6909d279e`).
- [ ] Bank inventory awareness corrections (`1980352c`).
