---
name: turtle-core-porting
description: Port AzerothCore, CMaNGOS, vMaNGOS and Turtle-fork changes into this Turtle WoW core, scripts, modules and SQL using native APIs, isolated worktrees and project verification.
---

# Turtle core porting

Use this skill for native implementation, donor adaptation and compatibility review in this project. This is chiefly C++ API, CMake and SQL translation, not conversion between programming languages.

## Establish the target

Read the project-root `AGENTS.md` and [documentation map](../../../docs/DOCUMENTATION_MAP.md). Resolve `tortoise-wow-extended` inside this project; inspect its applicable instructions, current branch, HEAD and uncommitted changes. Never infer the current target from a web comparison branch.

Implement candidate server changes only in this project's dedicated worktrees, following `tools/modules/WorktreeManager.ps1`. The main server checkout is a read-only baseline for this workflow. Project documentation and skill edits belong in the management repository.

## Select the relevant reference

- [API, syntax, module and SQL translation](references/api-and-data.md): read for C++, CMake, scripts, config or database adaptations.
- [Project architecture and commands](references/project-workflow.md): read for file mapping, build configuration, ownership and local tool use.
- [Source register](references/sources.md): use to resolve donor lineage, pinned baseline and external evidence.

## Execute a port

1. Pin donor repository, branch and full commit SHA; read its diff and prerequisites. Stay within active source watermarks for scheduled donor scans.
2. State the defect or desired behavior and demonstrate target relevance. Classify already-fixed, absent-system and intentional Turtle divergence cases without applying a patch.
3. Map symbols through declarations and real callers, not filenames alone. Identify game version, ownership, thread, config and schema differences.
4. Implement the smallest native change. Keep one donor commit per target commit when performing donor integration. Preserve license and upstream provenance; original custom work should be identified as native work rather than assigned a fictitious donor.
5. Review Turtle custom-content contracts, script bindings and module hooks. Do not broaden a fix into a foreign subsystem rewrite.
6. Run appropriate checks under the selected verification mode. Associate evidence with the exact target SHA, build directory, effective module settings and dataset. A fast compile is not a full link or gameplay pass.
7. Update the project ledger/dossier for an actual port. Report behavior, target-native adaptations, checks passed and remaining runtime uncertainty. Follow existing publishing authorization; reading this skill or editing docs does not itself invoke a push workflow.

For an uncertain mapping, inspect the owner and one working native caller. If semantics still cannot be established, document the missing contract and keep the candidate unverified rather than adding no-op compatibility code.
