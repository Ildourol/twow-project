# Dungeon Clear Compatibility & Integration Policy

## 1. Protected Status

**Dungeon Clear** (`modules/mod-dungeon-clear`) is a protected target subsystem providing automated, coordinated bot dungeon progression, encounter routing, boss strategy execution, wipe recovery, and hazard mitigation across all classic dungeons.

Upstream CMaNGOS and vMaNGOS do not natively include `mod-dungeon-clear`. Therefore, **no upstream commit may silently break, bypass, or degrade Dungeon Clear functionality**.

---

## 2. Integration Seams with PlayerBots

Dungeon Clear integrates directly into the PlayerBots AI lifecycle via the following contracts:

### 2.1. Value Context Extensions (`DungeonClearValueContext.h`)
Dungeon Clear registers custom value providers into `AiObjectContext`:
- `DcKey::LiveBoss` / `DcKey::SeenBosses` / `DcKey::StickyBoss`: Encounter tracking.
- `DcKey::RunState` / `DcKey::RunInstance` / `DcKey::Phase`: Instance state machine.
- `DcKey::PartyTank` / `DcKey::FollowedTank`: Role and leadership hierarchy.
- `DcKey::Hazards` / `DcKey::GroundHazards` / `DcKey::TrapHazards`: Spatial awareness.
- `DcKey::BlockingDoor` / `DcKey::CurrentHop` / `DcKey::LongPath`: Navigation through instance doors and obstacles.
- `DcKey::LootSkip` / `DcKey::LootCampGuid`: Controlled loot coordination preventing group stragglers.

### 2.2. Gossip & Dialog Interactions
- Gossip selection must resolve to valid offered options.
- Turtle's select packet contains `[GUID, OptionIndex]` without a separate menu ID.
- Upstream changes to `GossipAction` or gossip triggers must not alter this packet contract.

### 2.3. Teleportation, Wipe Recovery, and Repop
- When a party wipes or a member dies in an instance, `DcRezRecovery` and `StayDeadAction` coordinate resurrection or spirit run.
- Teleportation guards must ensure that bots transitioning instances revalidate session and player existence without discarding live players mid-teleport.

---

## 3. Mandatory Compatibility Checklist for Upstream Ports

Before any upstream PlayerBots commit is integrated, evaluate the following risk vectors:

| Upstream Change Category | Dungeon Clear Risk | Verification Requirement |
| :--- | :--- | :--- |
| **Movement / Follow** | Bots refusing to follow tank into boss room or breaking formation. | Verify follower lifecycle and leader signal in `DcMovement.cpp`. |
| **Targeting / Threat** | DPS bots pulling unengaged trash packs ahead of the designated party tank. | Check `DcKey::PartyTank` and `DcPullDecision.cpp`. |
| **Loot Handling** | Bots lingering on corpses during active boss encounters. | Ensure `DcKey::LootSkip` overrides generic loot strategies. |
| **Teleport / Repop** | Stale bot pointers or dropped sessions during instance entrance. | Check `PlayerbotHolder::UpdateAllHolderSessions` and near/far teleport ACK handlers. |
| **Strategy Clears** | Upstream commits resetting or wiping active strategies (`removeStrategy`). | Prevent strategy-reset storms that discard active `dungeon` strategy. |
| **Combat Stances** | Dynamic stance switching conflicting with assigned dungeon roles. | Ensure dungeon role assignments take precedence over ad-hoc combat stances. |
