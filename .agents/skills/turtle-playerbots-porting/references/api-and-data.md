# C++, build, and data translation

## Port behavior, not a core's vocabulary

These engines predominantly use C++, CMake, and SQL. This target selects C++17 in its root CMakeLists.txt. A port translates APIs, ownership, lifecycle, schema, and game rules. Do not raise the language standard just to paste a donor implementation.

| Donor family | Useful evidence | Translation boundary |
| --- | --- | --- |
| AzerothCore WotLK | Modular feature design, isolated fixes | WotLK mechanics, script hooks, config, spell and database APIs require target-specific implementation |
| CMaNGOS/playerbots | AI decisions, actions, triggers, values, travel | Expansion branches, type/store aliases, action signatures and host lifecycle |
| vMaNGOS | Vanilla core fixes, movement, spells, SQL intent | Reorganized paths, progressive data, target parameters and Turtle custom behavior |
| Turtle forks | Similar module and client integration | Exact branch and SHA still matter; shared ancestry does not prove API equivalence |

Use the checked-out target declarations and callers over this table. The primary links and pinned local evidence are in [sources.md](sources.md).

## Actual target syntax

Paths below are relative to the server source root.

| Concern | Donor pattern to investigate | Target evidence and translation |
| --- | --- | --- |
| Configuration | AzerothCore `sConfigMgr` and typed options | `src/shared/Config/Config.h`: `sConfig.GetBoolDefault("Feature.Enabled", false)`, `sConfig.GetIntDefault("Feature.Limit", 5)`; preserve defaults and reload behavior |
| Spell metadata | `SpellInfo`, expansion-specific spell stores | `src/game/Spells/SpellMgr.h`: `SpellEntry const*` from `sSpellMgr.GetSpellEntry(id)`; null-check and compare each accessed field |
| Object identity | `GetGUID()` or low GUID used as an object | `src/game/Objects/Object.h`: `GetObjectGuid()` returns typed `ObjectGuid const&`; this target's `GetGUID()` returns raw `uint64 const&` |
| Casting | Donor trigger flags / overloads | Target `Object.h` includes `CastSpell(Unit*, uint32, bool, ...)`; preserve original caster, item, aura provenance and LOS semantics; a nonzero bitmask is not equivalent to boolean `true` |
| SQL results | Donor prepared-statement IDs, result wrappers | Follow native callers, e.g. `std::unique_ptr<QueryResult> result(WorldDatabase.Query(...))` in `ObjectMgr.cpp`; inspect field order, result ownership, escaping and transaction semantics |
| Script registration | Donor loader names and hook constructors | Read `ScriptObjects.h`, `ScriptMgr.h` and the local module template; match virtual signatures with `override` |
| Build helpers | `AC_*` helper calls | Target module documentation uses `TW_*`; inspect each helper declaration rather than replace every prefix mechanically |

Illustrative target fragment, with `player` and `spellId` supplied by the enclosing function:

```cpp
#include "Player.h"
#include "SpellMgr.h"

SpellEntry const* spell = sSpellMgr.GetSpellEntry(spellId);
if (!spell)
    return; // Adapt to the enclosing return type and error handling.
ObjectGuid casterGuid = player->GetObjectGuid();
player->CastSpell(player, spell, false); // Normal cast only if the intended semantics require it.
```

Do not replace a failing cast with a triggered cast merely to make a bot succeed. Investigate power, cooldown, range, target validity, movement and cast result first.

## Turtle contracts to preserve

- `SharedDefines.h` defines race IDs 1 through 10, including Goblin 9 and High Elf 10. `MAX_RACES = 11` is an exclusive bound / array size, not eleven playable races. Use `race < MAX_RACES`, skip invalid IDs, and use the target playable mask; race masks use `1u << (race - 1)`.
- Preserve `TWDebuff` registration, aura add/remove and client message paths. Inspect actual integer and packet types before making width claims; custom debuff streaming is not automatically a 64-bit bitmask.
- `SCRIPT_COMMAND_TAKE_MONEY = 93` is a database-script command identifier, not a network packet opcode. Keep the script command ABI and packet ABI distinct.
- Preserve native LFT, transmog, custom merchant, collection and addon dispatch. Preserve optional parameters and side effects in modified call chains.
- Custom spell IDs >= 40000 and world template IDs >= 300000 are project protection thresholds. IDs below those thresholds can also be customized; inspect every affected row.
- Later-expansion donor code is usable only for a separable, target-relevant correction. Do not import arenas, flying, later spell IDs, talents, opcodes, or expansion data. Turtle's documented custom mechanics take precedence over stock Vanilla behavior.

## CMake and module structure

The target's `modules/README.md` and `modules/templates/basic` are the starting point:

```text
modules/mod-example/
  src/mod-example.cpp
  conf/mod-example.conf.dist
  data/sql/auth/
  data/sql/character/
  data/sql/world/
  mod-example.cmake
```

A `src/` directory enables discovery. The sanitized loader for `mod-example` is `Addmod_exampleScripts`. A minimal target-native startup hook:

```cpp
#include "ScriptObjects.h"
class ExampleWorldScript : public WorldScript
{
public:
    ExampleWorldScript() : WorldScript("example_world", { WORLDHOOK_ON_STARTUP }) {}
    void OnStartup() override {}
};
void Addmod_exampleScripts()
{
    new ExampleWorldScript();
}
```

Preserve the local hook subscription and loader convention. Do not edit generated loader output. Inspect `modules/CMakeLists.txt` and `src/cmake/macros/ConfigureModules.cmake` when adding integration.

Global `MODULES=static|dynamic|disabled` can be overridden by `MODULE_MOD_EXAMPLE=static|dynamic|disabled|default`. Inspect effective per-module values, compile definitions, source lists and dependencies. A successful build with the module disabled proves nothing about that module. Use separate build directories for configuration variants; do not repoint an existing cache at another source tree.

## SQL port recipe

1. Read donor SQL and explain the intended row-level behavior. Identify world, character or auth ownership.
2. Inspect target `sql/base`, applied migrations, native SELECT statements and (when available) read-only live schema. Cached catalogs and web viewers may be stale.
3. Map table names, explicit columns, primary keys, script bindings, spell IDs and spawn/template IDs. Never infer a target column from donor DDL.
4. Re-express progressive-patch donor conditions for the fixed Turtle baseline. Do not just drop an unsupported `patch` predicate: it can turn a narrow update into a broad overwrite.
5. Place migrations in the route actually consumed by the target updater. Legacy module `sql/` assets are not necessarily auto-discovered `data/sql/` migrations. Confirm the allowed-module configuration.
6. Preview affected rows with a SELECT using the same predicate. Preserve preimages and design rollback from those values. Test on disposable data; MySQL DDL is not generally transaction-rollback safe.
7. Record source SHA, entity provenance, schema baseline, expected row count, apply result and rerun behavior. Preserve author/license attribution.

Prefer narrow UPDATE statements and explicit INSERT columns. Avoid donor REPLACE statements that may delete/recreate rows and trigger cascading effects. A viewer helps find an entity; it does not certify the installed schema or the engine's behavior.

## Native design and validation

Trace input -> handler/hook -> owner -> data mutation -> persistence/client notification. Fix the responsible layer; do not add a parallel scheduler, spell store or movement engine. Re-resolve GUIDs after delayed work, respect world/map thread ownership, and do not hold locks across callbacks without proving their lock and lifetime contracts.

Use the verification level required by the selected project mode. Record compile, link, startup, migration and gameplay outcomes separately, including the tested SHA and configuration. Test the failing case, an unaffected case and a relevant boundary (missing target, disconnect, repeated request, custom race or invalid data). Compiler output and regex filters are evidence, not proofs of semantic correctness.
