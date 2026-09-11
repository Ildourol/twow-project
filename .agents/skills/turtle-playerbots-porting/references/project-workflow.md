# PlayerBots architecture and commands

Run commands from this management-project root. All source paths below are relative to its own `tortoise-wow-extended`.

## Map donor code

| Donor | Donor path | Target |
| --- | --- | --- |
| CMaNGOS | `playerbot/...` | `modules/mod-playerbots/src/playerbot/...` |
| CMaNGOS | `ahbot/...` | `modules/mod-playerbots/src/ahbot/...` |
| IKE3 vMaNGOS | `src/game/PlayerBots/playerbot/...` | `modules/mod-playerbots/src/playerbot/...` |
| Host lifecycle | Core session/world edits | Trace `src/game/World.cpp`, native session pump and `HostHooks.cpp`; do not paste into the AI strategy |
| Dungeon behavior | Actions, values, movement | Inspect `modules/mod-dungeon-clear` consumers before modifying bot contracts |

## Decision engine and exact signatures

Trace `PlayerbotAI` -> AI object contexts -> values/triggers -> strategy action proposals -> multipliers/action basket -> action execution. A new class is insufficient: register its exact action/trigger/value key in the appropriate context, attach its trigger to a strategy, and verify the bot activates that strategy in the intended state.

The checked-out `strategy/Action.h` declares `virtual bool Execute(Event& event)`. Preserve the reference and use `override`; a donor's `Event` by value can create the wrong overload. Match `isPossible()` and `isUseful()` contracts as well.

Illustrative declaration matching the target; implement and register it before use:

```cpp
#include "playerbot/strategy/Action.h"
namespace ai
{
    class NativeAction : public Action
    {
    public:
        NativeAction(PlayerbotAI* ai) : Action(ai, "native action") {}
        bool Execute(Event& event) override;
        bool isUseful() override;
    };
}
```

Validate requester/master identity and engine duration/cooldown behavior. Returning success without performing the action can starve alternatives.

## Compatibility boundary

Read `cmangos-compat-shim.h` and `botpch.h`. Actual alias direction is donor-visible name -> native type:

| Donor-visible name | Target native type |
| --- | --- |
| `GenericTransport` | `Transport` |
| `UnitAI` | `CreatureAI` |
| `GuidSet` | `ObjectGuidSet` |
| `AreaTableEntry` | `AreaEntry` |
| `AreaTrigger` | `AreaTriggerEntry` |

These describe the current shim, not universal CMaNGOS naming. The `sSpellTemplate.LookupEntry<SpellEntry>(id)` proxy forwards to `sSpellMgr.GetSpellEntry(id)`. Inspect each proxy's behavior; do not introduce parallel global stores.

Existing compatibility code includes a zero-valued `UNIT_FLAG_CLIENT_CONTROL_LOST`, a no-op `BarGoLink`, and a minimal `InstanceTemplate`. They do not prove control-state or instance behavior exists. When a port depends on a stub, trace its callers and implement the responsible native behavior or classify the feature unsupported. Do not add another no-op merely to compile.

## Lifecycle invariants

`PlayerbotHolder::UpdateAllHolderSessions` runs on the world owner after map jobs join. Its snapshot/generation checks prevent dispatch against replaced holders. Preserve them. Do not move the session pump into a module/map tick simply because the donor does so.

Never carry holder/registry locks through native packet handlers or teleport ACK callbacks without validating reentrancy and lock ordering. Bot sessions can be socketless. Revalidate player/session ownership after near/far teleport completion, logout or callback-driven removal. Provisioning async futures and character saves need bounded outstanding work and checked completion.

For movement or group changes, verify Dungeon Clear run state, value keys/types, routes, live-boss selection, leader/follower behavior, hazards, death/wipe recovery and interrupted travel. Use its existing contexts instead of a competing dungeon state machine.

## Build configuration

`mod-playerbots.cmake` supplies `CMANGOS`, `MANGOSBOT_ZERO`, `ENABLE_PLAYERBOTS`, Boost dependencies and PCH/forced inclusion. Keep the shim available when PCH is disabled. Check public include paths consumed by Dungeon Clear.

At the inspected baseline, the cache has:
- `BUILD_PLAYERBOTS=ON`
- `MODULES=disabled`
- `MODULE_MOD_PLAYERBOTS=static`
- `MODULE_MOD_DUNGEON_CLEAR=static`
- Visual Studio 17 2022 generator.

Per-module overrides explain why a globally disabled module setting still builds these modules. Confirm current values before interpreting success. For a loader/PCH/dependency change, test relevant static/dynamic and PCH-disabled variants in separate build directories; preserve the core fallback when bots are disabled.

## Commands and effects

```powershell
$targetRepo = Join-Path $PWD 'tortoise-wow-extended'
git -C $targetRepo status --short
git -C $targetRepo branch --show-current
git -C $targetRepo rev-parse HEAD
git -C reference-upstreams/playerbots show --stat <donor-sha>
git -C reference-upstreams/core show <donor-sha> -- <donor-path>
rg -n 'AffectedSymbol' "$targetRepo/modules/mod-playerbots" "$targetRepo/modules/mod-dungeon-clear" "$targetRepo/src"
.\tools\task.ps1 status
```

| Command | Effect |
| --- | --- |
| `.\tools\task.ps1 verify-fast` | Compiles target `modules`; no executable link proof |
| `.\tools\task.ps1 verify-full` | Builds/links `mangosd` |
| `.\tools\task.ps1 verify-batch` | Runs module compile followed by full link |
| `.\tools\task.ps1 batch-compile-and-audit cmangos Normal` | Scans and changes ledger state, then builds; its name does not mean it implements ports |
| `.\tools\task.ps1 record-port` | Writes ledger/dossier; inspect required metadata parameters |
| `.\tools\task.ps1 commit-and-push` | Stages/commits/pushes through its helper; inspect scope and selected verification first |
| `.\tools\task.ps1 update-upstreams cmangos` | Fetches and fast-forwards donor checkout |

Current verification helpers return booleans and are not sufficient evidence that the enclosing shell exits nonzero. Inspect output and the native build exit code. For reliable direct checks, resolve CMake from `state/sources.json` / the cache:

```powershell
$buildDir = Join-Path $targetRepo 'build'
$cmakePath = ((Get-Content "$buildDir/CMakeCache.txt" |
    Where-Object { $_ -match '^CMAKE_COMMAND:INTERNAL=' }) -split '=', 2)[1]
& $cmakePath --build $buildDir --target mangosd --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'PlayerBots build/link failed' }
```

Respect the one-donor/one-commit policy and the selected ADR-009 execution mode. Deferred link verification stays pending; a passing batch tip does not prove each intermediate commit builds. Keep per-commit provenance separate from batch validation evidence. Build results do not prove gameplay or authorize a runtime deployment.
