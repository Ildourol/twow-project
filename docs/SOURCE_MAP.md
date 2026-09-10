# Module-playerbots Source Map & Subsystem Topology

## 1. Repository Register

| Repository Role | Local Path | Git Remote URL | Branch | Initial HEAD SHA | Lineage & Architecture |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TARGET (Turtle WoW Server)** | `tortoise-wow-extended` | `https://github.com/Ildourol/tortoise-wow-extended.git` | `mantech-turtle` | `a80ca1d1d4d5ac71573e9d06f5b80c4068c910ef` | Turtle WoW 1.18.1 / vMaNGOS core. Modular architecture. Writable target. |
| **UPSTREAM (CMaNGOS PlayerBots)** | `reference-upstreams/playerbots` | `https://github.com/cmangos/playerbots.git` | `master` | `89a4e5aebd6aa41ee87f6e65d89b66fff5c5c7c1` | Standalone CMaNGOS PlayerBots module. High-velocity development. |
| **UPSTREAM (vMaNGOS PlayerBots Core)** | `reference-upstreams/core` | `https://github.com/ileboii/core.git` | `vmangos-ike3-playerbots` | `2ff8489f74b82617591f9ada3bab2772bf849da2` | vMaNGOS core fork with ike3 PlayerBots integrated under `src/game/PlayerBots`. |

---

## 2. Target Subsystem Layout

In the target repository (`tortoise-wow-extended`), PlayerBots operates as an integrated module within the server architecture:

### 2.1. PlayerBots Module (`modules/mod-playerbots`)
- `src/playerbot/`: Core bot AI implementation:
  - `PlayerbotAI.cpp` / `PlayerbotAI.h`: Central bot controller and lifecycle manager.
  - `PlayerbotMgr.cpp` / `PlayerbotMgr.h`: Player-owned and master-driven bot manager.
  - `RandomPlayerbotMgr.cpp` / `RandomPlayerbotMgr.h`: World bot population, random bot generator, and account pool manager.
  - `PlayerbotFactory.cpp`: Leveling, gear, spell, and inventory synthesizer.
  - `strategy/`: AI strategy engine:
    - Actions (`Action.h`, `ActionBasket.h`, class action implementations).
    - Triggers (`Trigger.h`, trigger implementations).
    - Contexts (`AiObjectContext.h`, class and value contexts).
    - Multipliers (`Multiplier.h`).
    - Values (`Value.h`, dynamic bot perception: health, mana, threats, party members, loot, travel targets).
  - `TravelNode.cpp` / `TravelMgr.cpp`: MMAP-based navigation, transport traversal, and world exploration.
- `src/ahbot/`: Auction House bot engine.
- `src/loader/`: Dynamic/static module script loader (`Addmod_playerbotsScripts`).
- `cmangos-compat-shim.h`: Architectural compatibility bridge defining CMaNGOS-compatible typedefs (`GuidSet -> ObjectGuidSet`, `AreaTableEntry -> AreaEntry`, `GenericTransport -> Transport`, `UnitAI -> CreatureAI`) and missing STL headers.
- `botpch.h`: Precompiled header wrapper ensuring the compatibility shim reaches every compilation unit.
- `mod-playerbots.cmake`: Build configuration linking Boost (`thread`, `filesystem`, `system`) and passing `-DCMANGOS -DMANGOSBOT_ZERO -DENABLE_PLAYERBOTS`.
- `sql/`: Database definitions for playerbots (`sql/world/`, `sql/characters/`).

### 2.2. Protected Subsystem: Dungeon Clear (`modules/mod-dungeon-clear`)
- Located at `modules/mod-dungeon-clear`.
- Provides deterministic bot dungeon-running, boss routing, trash clearing, encounter progression, role management, and hazard evasion.
- Deeply couples with PlayerBots values via `src/Ai/Dungeon/DungeonClear/DungeonClearValueContext.h` (`dungeon_clear_live_boss`, `dungeon_clear_run_state`, `dungeon_clear_hazards`, etc.).
- Any changes to bot movement, group leadership, teleportation, or gossip must verify compatibility with Dungeon Clear.

### 2.3. Core Integration Points
- `src/game/World.cpp`: Startup hook `World::InitPlayerbotsAtStartup()`.
- `src/game/PlayerbotStubs.cpp`: Fallback stubs compiled when `BUILD_PLAYERBOTS=OFF`.
- `src/game/ScriptMgr.h`: Script hooks providing bot interaction points without polluting core headers.
- `src/game/Player.cpp` / `Unit.cpp`: Core entity integration with bot safety guards.

---

## 3. Path Translation Matrix

When evaluating commits from either upstream source, file paths must be mapped to target locations:

| Subsystem Component | Upstream CMaNGOS Path (`playerbots`) | Upstream vMaNGOS Path (`core`) | Target Path (`tortoise-wow-extended`) |
| :--- | :--- | :--- | :--- |
| **PlayerBot Core AI** | `playerbot/PlayerbotAI.cpp` | `src/game/PlayerBots/playerbot/PlayerbotAI.cpp` | `modules/mod-playerbots/src/playerbot/PlayerbotAI.cpp` |
| **PlayerBot Manager** | `playerbot/PlayerbotMgr.cpp` | `src/game/PlayerBots/playerbot/PlayerbotMgr.cpp` | `modules/mod-playerbots/src/playerbot/PlayerbotMgr.cpp` |
| **Random Bot Manager** | `playerbot/RandomPlayerbotMgr.cpp` | `src/game/PlayerBots/playerbot/RandomPlayerbotMgr.cpp` | `modules/mod-playerbots/src/playerbot/RandomPlayerbotMgr.cpp` |
| **AI Strategies** | `playerbot/strategy/*` | `src/game/PlayerBots/playerbot/strategy/*` | `modules/mod-playerbots/src/playerbot/strategy/*` |
| **Travel & Pathing** | `playerbot/TravelMgr.cpp` | `src/game/PlayerBots/playerbot/TravelMgr.cpp` | `modules/mod-playerbots/src/playerbot/TravelMgr.cpp` |
| **Auction House Bot** | `ahbot/*` | N/A (or `src/game/AuctionHouseBot/*`) | `modules/mod-playerbots/src/ahbot/*` |
| **SQL Migrations** | `sql/*` | `sql/*` | `modules/mod-playerbots/sql/*` or `sql/database_updates/*` |
| **Configuration** | `playerbot/aiplayerbot.conf.dist.in` | `src/mangosd/mangosd.conf.dist.in` | `modules/mod-playerbots/src/playerbot/aiplayerbot.conf.dist.in` |
| **Dungeon Clear** | N/A | N/A | `modules/mod-dungeon-clear/*` |

---

## 4. Porting Lane Characteristics

### Lane A: CMaNGOS PlayerBots (`playerbots`)
- **Nature**: External repository containing modern improvements.
- **Porting Method**: **Native Manual Port**.
- **Key Adaptations**:
  - Strip TBC/WotLK code (`#ifndef MANGOSBOT_ONE`, `#ifndef MANGOSBOT_TWO`).
  - Adapt CMaNGOS-specific memory containers, packet structures, and storage accessors (`sMapStorage` vs `sMapStore`).
  - Check `cmangos-compat-shim.h` to see if name mappings exist or require call-site adaptation.

### Lane B: vMaNGOS PlayerBots (`core`)
- **Nature**: Core fork based on vMaNGOS.
- **Porting Method**: **Adapted Port**.
- **Key Adaptations**:
  - Translate paths from `src/game/PlayerBots/` to `modules/mod-playerbots/src/`.
  - Check for Turtle WoW custom content differences (e.g. 11 playable races, custom spells $\ge 40000$, custom creatures $\ge 300000$).
  - Preserve Turtle module hooks.
