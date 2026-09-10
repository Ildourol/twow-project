# Known Risks & Architectural Hazards Register

This register identifies known failure modes, architectural traps, and regression hazards encountered when porting PlayerBots features into Turtle WoW.

---

## 1. Subsystem Risk Catalog

### KR-01: TBC / WotLK Expansion Contamination
- **Source**: CMaNGOS `playerbots` develops across Classic, TBC, and WotLK simultaneously.
- **Hazard**: Code paths guarded by `#ifdef MANGOSBOT_ONE` or `#ifdef MANGOSBOT_TWO` contain post-Vanilla abilities (e.g. Crusader Strike for Paladins, Steady Shot for Hunters, Misdirection, Cloak of Shadows, TBC Shaman Flame Shock changes).
- **Mitigation**: Filter all candidate diffs for expansion macros. Port only Vanilla 1.12 / Turtle 1.18.1 mechanics.

### KR-02: Mid-Teleport Object Visibility Race
- **Hazard**: When a bot teleports (e.g. entering an instance, hearthstoning, or unstuck), `Player` is temporarily unlinked from `sObjectMgr` during grid reattachment. Naive null checks or stale-pointer guards will treat the player as offline or dead, prematurely terminating the bot session.
- **Evidence**: Target commit `8415f1b9` explicitly notes: *"A Player mid-teleport is briefly not findable through sObjectMgr... check discarded live bots (188 'tank did not arrive', 84 'bot vanished before teleport')"*.
- **Mitigation**: Never add unconditional `sObjectMgr.GetPlayer(guid)` guards across teleport transitions without handling the mid-teleport state.

### KR-03: Strategy-Reset Storms & Dungeon Clear Desync
- **Hazard**: Upstream commits that aggressively wipe or reset active strategies (`removeStrategy()`, clearing strategy baskets on respawn or target change) inadvertently wipe Dungeon Clear's active run state.
- **Mitigation**: Protect `dungeon`, `dungeon_clear`, and `custom` strategies from global resets.

### KR-04: Lock Ordering & Asynchronous Deadlocks
- **Hazard**: Acquiring PlayerBot manager locks or internal mutexes while calling into core functions that lock `m_mapLock` or `m_objectLock`.
- **Mitigation**: Ensure bot synthetic session ticks execute solely under `PlayerbotHolder::UpdateAllHolderSessions` on the main world thread. Never retain raw entity pointers across worker threads.

### KR-05: Account & Character Provisioning Future Exhaustion
- **Hazard**: Creating cohorts of random bots creates database threads. Calling `std::future::get()` multiple times or keeping unbound thread pools causes `std::future_error`.
- **Mitigation**: Maintain the bounded 8-task future windows established in `RandomPlayerbotFactory::CreateRandomBots`.

### KR-06: Gossip Menu ID Packet Divergence
- **Hazard**: Upstream MaNGOS/CMaNGOS gossip selection packets frequently include a menu ID field. Turtle WoW 1.18.1 client packet format transmits `[GUID, OptionIndex]` without a menu ID.
- **Mitigation**: Do not port foreign gossip action handlers that expect menu ID payloads.
