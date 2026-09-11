# Core architecture and commands

Run PowerShell commands from the management-project root unless specified otherwise. Replace example SHA and candidate ID values with inspected values.

## Source ownership

| Area | Target source relative to server root | Porting concern |
| --- | --- | --- |
| World startup/ticks | `src/game/World.cpp` | Update ordering, managers, configuration and thread joins |
| Player, unit, object | `src/game/Objects/` | GUIDs, lifetime, race masks, persistence and visibility |
| Spells and auras | `src/game/Spells/`, `src/game/TWDebuff/` | Custom metadata, caster provenance and aura notifications |
| Movement and maps | `src/game/Movement/`, `Maps/`, `Transports/` | Map ownership, terrain, passenger lifecycle and teleport state |
| Network handlers | `src/game/Handlers/`, `Protocol/` | Exact client packet fields, addon routes and socket state |
| Scripts | `src/scripts/` | Binding, registration, EventAI versus C++ AI, instance state |
| Optional features | `modules/` | Hook subscription, sanitized loader and CMake mode |
| Persistent data | `sql/base/`, `sql/migrations/` | Target columns, custom entities and updater tracking |

A donor path under `src/scripts/eastern_kingdoms` may live under target `src/scripts/dungeons`. `tools/modules/PathMapper.ps1` assists lookup; validate the mapped function and its call sites. A mapped filename does not establish defect presence.

## Inspect without integrating

```powershell
$targetRepo = Join-Path $PWD 'tortoise-wow-extended'
$donorRepo = Join-Path $PWD 'reference-upstreams/vmangos-core'
git -C $targetRepo status --short
git -C $targetRepo branch --show-current
git -C $targetRepo rev-parse HEAD
git -C $donorRepo show --stat --oneline <donor-sha>
git -C $donorRepo show <donor-sha> -- <donor-path>
rg -n 'AffectedSymbol' "$targetRepo/src" "$targetRepo/modules"
git -C $targetRepo log -S 'AffectedSymbol' --all -- <target-path>
```

The inspected target branch was `extended`. WorktreeManager constructs `worktree/<sanitized-candidate-id>` branches. Read its function parameters before creating a candidate; older `port/...` examples describe other pipeline versions.

## Project commands and effects

| Command from project root | Purpose / side effects |
| --- | --- |
| `.\tools\task.ps1 status` | Read pipeline status |
| `.\tools\task.ps1 prove <sha>` | Candidate analysis; inspect called script for report/state writes |
| `.\tools\task.ps1 system-check light` | Project checks; inspect implementation before treating as read-only |
| `.\tools\task.ps1 compatibility` | Compatibility heuristics; not semantic proof |
| `.\tools\task.ps1 db-audit` | Project SQL audit; confirm selected migration inputs |
| `.\tools\task.ps1 parity` | Client-data consistency checks against configured assets |
| `.\tools\task.ps1 test` | Orchestration tests; does not exercise server gameplay |
| `.\tools\task.ps1 build-ready -FastBuild` | Calls Build-ReadyPackages.ps1; can build/commit queued work, not a harmless compile probe |
| `.\tools\task.ps1 build-packages` | Same package builder alias; inspect queue and build/commit behavior first |
| `auto-port`, `auto-pilot`, `push-extended`, `-AutoCommit` | Integration/publishing workflows under existing project policy |
| `.\tools\task.ps1 update-upstreams vmangos-core` | Fetch / fast-forward donor checkout; changes local references |

The dispatcher `tools/task.ps1` is the syntax authority. Do not assume `-DryRun` suppresses every side effect; inspect the selected branch and delegated script. Keep build execution serialized.

## Direct build in an isolated candidate

Read the worktree's resolved build profile and CMakeCache. Never reuse the main source cache for a candidate worktree. Example after the candidate has a correctly configured build directory:

```powershell
$candidateBuild = Join-Path $PWD '.worktrees/PORT-EXAMPLE/build'
Get-Content "$candidateBuild/CMakeCache.txt" |
    Select-String 'CMAKE_HOME_DIRECTORY:|CMAKE_GENERATOR:|CMAKE_COMMAND:|MODULE.*:'
$cmakePath = ((Get-Content "$candidateBuild/CMakeCache.txt" |
    Where-Object { $_ -match '^CMAKE_COMMAND:INTERNAL=' }) -split '=', 2)[1]
& $cmakePath --build $candidateBuild --target mangosd --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Candidate build/link failed' }
```

Use actual available CPU/memory capacity. MSBuild flags such as `/v:q` belong only after `--` for a Visual Studio generator; they are not Ninja options. Select realmd as well for auth changes. Do not report a cached build as testing a different SHA.

## Completion evidence

Use the current project modes; deferred checks stay explicitly pending. For a completed core port, retain the donor diff, target base, adaptation rationale, compatibility/SQL review, compile/link logs, required disposable smoke test and relevant regression evidence in the candidate dossier and ledger. Fixed test counts in old docs are historical snapshots. Do not mark startup successful from compilation or from a process merely starting.
