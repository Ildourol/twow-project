# Reference Upstreams, Synchronization & Ecosystem Directory

This document details the upstream reference repositories, local directory structures, synchronization workflows, and related community links for the **Module-playerbots** project.

---

## 1. Local Directory Organization

To ensure clean project organization and parity across workspaces, all read-only upstream donor clones are stored inside `reference-upstreams/` with root directory junctions maintained for backwards compatibility:

```
Module-playerbots/
├── reference-upstreams/
│   ├── core/                  # ileboii/core (branch: vmangos-ike3-playerbots)
│   └── playerbots/            # cmangos/playerbots (branch: master)
├── core/                      # Junction -> reference-upstreams/core
├── playerbots/                # Junction -> reference-upstreams/playerbots
└── tortoise-wow-extended/     # Active product repository (branch: mantech-turtle)
```

| Subdirectory / Junction | Git Remote URL | Branch | Role in Porting |
|:---|:---|:---|:---|
| `reference-upstreams/core` | `https://github.com/ileboii/core.git` | `vmangos-ike3-playerbots` | Primary donor for bot lifecycle, stance, and healing fixes |
| `reference-upstreams/playerbots` | `https://github.com/cmangos/playerbots.git` | `master` | CMaNGOS donor for bot strategies, combat, and travel nodes |
| `tortoise-wow-extended` | `https://github.com/Ildourol/tortoise-wow-extended.git` | `mantech-turtle` | Active target product repository (Protected) |

---

## 2. Upstream Synchronization Command

To fetch and fast-forward all reference upstream repositories locally without touching or dirtying the working project:

```powershell
# Update all reference upstreams
.\tools\task.ps1 update-upstreams

# Update only vMaNGOS playerbots core
.\tools\task.ps1 update-upstreams vmangos

# Update only CMaNGOS playerbots
.\tools\task.ps1 update-upstreams cmangos
```

### Safety & Exclusion Invariants:
1. **Target Repo Protected**: `tortoise-wow-extended` is **strictly excluded** from automated checkout and pull operations. Your active working tree and uncommitted changes will never be touched.
2. **Fast-Forward Only**: All pulls use `--ff-only` to guarantee no accidental merge commits or merge conflicts are created in upstream donor trees.
3. **Local Inspection**: When new commits are detected, `task update-upstreams` reports the number of new commits and outputs their log summaries. Developers can immediately inspect them using:
   ```powershell
   git -C reference-upstreams/core show <sha>
   git -C reference-upstreams/playerbots show <sha>
   ```

---

## 3. Comprehensive Ecosystem Reference Directory

| Resource / System | URL | Description & Notes |
|:---|:---|:---|
| **Turtle WoW Original** | [Penqle/tortoise-wow](https://github.com/Penqle/tortoise-wow) | Upstream core engine repository. |
| **Turtle WoW with IKE3 Bots** | [Shyalya/tortoise-wow](https://github.com/Shyalya/tortoise-wow)<br>[T-imothy/tortoise-wow](https://github.com/T-imothy/tortoise-wow) | Turtle-adapted playerbots reference implementations. |
| **Turtle WoW with AC Bots** | [tortoise-wow-stack/TortoiseBots](https://github.com/tortoise-wow-stack/TortoiseBots) | Alternative bot system implementation. |
| **Turtle WoW Knowledge DB** | [tortoise-wow-stack/TortoiseWoWKnowledgeBase](https://github.com/tortoise-wow-stack/TortoiseWoWKnowledgeBase) | Turtle WoW technical notes, packet structure, opcode tables. |
| **Turtle Module Topics & Template** | [tortoise-module Topic](https://github.com/topics/tortoise-module)<br>[Basic Module Template](https://github.com/Penqle/tortoise-wow/tree/main/modules/templates/basic) | Modular architecture standards and templates. |
| **vMaNGOS Core** | [vmangos/core](https://github.com/vmangos/core)<br>[vMaNGOS Releases (db_latest)](https://github.com/vmangos/core/releases) | Upstream vanilla 1.12.1 reference emulator and modern DB dumps. |
| **vMaNGOS PlayerBots (IKE3)** | [ileboii/core (vmangos-ike3-playerbots)](https://github.com/ileboii/core/tree/vmangos-ike3-playerbots) | Primary donor repository for AI bugfixes and party improvements. |
| **vMaNGOS Database** | [brotalnia/database](https://github.com/brotalnia/database/tree/master) | Historical database reference snapshots. |
| **cMaNGOS PlayerBots** | [cmangos/playerbots](https://github.com/cmangos/playerbots) | CMaNGOS bot mechanics donor repository. |
| **Turtle DB Viewer** | [Web Dashboard](https://xian55.github.io/tortoise-db-viewer/?)<br>[Xian55/tortoise-db-viewer](https://github.com/Xian55/tortoise-db-viewer) | Interactive online database search and schema comparison. |
| **User Product Repository** | [Ildourol/tortoise-wow-extended](https://github.com/Ildourol/tortoise-wow-extended) | Active target repository (branch: `mantech-turtle`). |
| **Fork Comparison** | [T-imothy vs Ildourol:mantech-turtle](https://github.com/T-imothy/tortoise-wow/compare/mantech-turtle...Ildourol:tortoise-wow-extended:mantech-turtle) | Live GitHub diff comparing upstream bot changes with target fork. |