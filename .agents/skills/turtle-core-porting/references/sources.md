# Evidence register

Reviewed 2026-09-11. Local paths are relative to this project. These SHAs are an inspection snapshot, not a requirement to reset branches.

| Role | Local repository | Inspected HEAD |
| --- | --- | --- |
| Target | `tortoise-wow-extended` | `eb740e6f64436fe63dfec962bb34361826f5e8b3` |
| vMaNGOS donor | `reference-upstreams/vmangos-core` | `448df9ba06d2b2b1678fcfd782a77e1e3ebf26b9` |


Primary local evidence: target `CMakeLists.txt`, `modules/README.md`, `modules/templates/basic/src/module.cpp.in`, `src/game/SharedDefines.h`, `src/game/Objects/Object.h`, `src/game/Spells/SpellMgr.h`, `src/shared/Config/Config.h`, `src/game/ObjectMgr.cpp`, `src/game/TWDebuff/TWDebuff.hpp`, and the declarations/callers relevant to each change.


## Upstream roles and links

- [Turtle base](https://github.com/Penqle/tortoise-wow) redirects to [tortoise-wow/tortoise-wow](https://github.com/tortoise-wow/tortoise-wow). Use the matching revision's [modules guide](https://github.com/Penqle/tortoise-wow/tree/main/modules) and [basic template](https://github.com/Penqle/tortoise-wow/tree/main/modules/templates/basic).
- [Shyalya](https://github.com/Shyalya/tortoise-wow) and [T-imothy](https://github.com/T-imothy/tortoise-wow) are integration references. Discover branch names rather than treating their default branches as interchangeable.
- [TortoiseBots](https://github.com/tortoise-wow-stack/TortoiseBots) redirects to [Sagiroth/TortoiseBots](https://github.com/Sagiroth/TortoiseBots). Treat it as a distinct bot implementation, not a drop-in IKE3 module.
- [vMaNGOS core](https://github.com/vmangos/core), [IKE3 donor branch](https://github.com/ileboii/core/tree/vmangos-ike3-playerbots), and [CMaNGOS PlayerBots](https://github.com/cmangos/playerbots) provide donor code.
- [AzerothCore WotLK](https://github.com/azerothcore/azerothcore-wotlk) supplies conceptual and API comparisons; inspect exact donor source before claiming an equivalent.
- [Module topic](https://github.com/topics/tortoise-module) is a discovery index, not an architectural guarantee.
- [Brotalnia database](https://github.com/brotalnia/database/tree/master) and [vMaNGOS release databases](https://github.com/vmangos/core/releases) are Vanilla reference data, not replacements for Turtle data.
- [DB viewer](https://xian55.github.io/tortoise-db-viewer/) and its [source](https://github.com/Xian55/tortoise-db-viewer) support content lookup. Verify schema and gameplay against the target.
- [Knowledge base](https://github.com/tortoise-wow-stack/TortoiseWoWKnowledgeBase): web retrieval failed during this review; no uninspected content was used as implementation evidence.
- [Target repository](https://github.com/Ildourol/tortoise-wow-extended): branch and SHA from local Git remain authoritative.
- [Requested historical fork comparison](https://github.com/T-imothy/tortoise-wow/compare/mantech-turtle...Ildourol:tortoise-wow-extended:mantech-turtle): web retrieval failed during this review. Do not infer its delta or change the local integration branch from this URL.

Malformed supplied hostnames for TortoiseBots and vMaNGOS were resolved to the GitHub URLs above and opened successfully. External pages were checked for identity and role; detailed API recipes derive from inspected local target source. Reopen current upstream source for each actual port.
