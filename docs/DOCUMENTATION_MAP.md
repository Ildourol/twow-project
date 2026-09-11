# Documentation map

Start here for navigation. Read only the subsystem references needed for the task.

| Question | Maintained entry point |
| --- | --- |
| What is the project and where is its target? | [README](../README.md) |
| What instructions apply? | [AGENTS.md](../AGENTS.md), then applicable instructions in the target checkout |
| How do I adapt donor C++, SQL or a module? | [turtle-playerbots-porting](../.agents/skills/turtle-playerbots-porting/SKILL.md) |
| What commands exist? | [COMMANDS.md](../COMMANDS.md); verify syntax/effects in [dispatcher](../tools/task.ps1) |
| What architecture must I preserve? | [PlayerBots architecture](PLAYERBOTS_ARCHITECTURE.md), [source map](SOURCE_MAP.md), [Dungeon Clear compatibility](DUNGEON_CLEAR_COMPATIBILITY.md) |
| What is planned or already integrated? | [Roadmap](../ROADMAP.md), project state ledger and commit dossiers |
| Which claims were reviewed? | [Documentation audit](DOCUMENTATION_AUDIT_2026-09-11.md) |

## Evidence and maintenance

Current user requirements and checked-out source remain authoritative. Skill references contain dated source anchors and practical recipes; they do not replace project policy. Configuration and runtime evidence must match the SHA being changed. Historical ADRs and dossiers explain past decisions, not current build health.

Keep reusable adaptation mechanics in the skill, stable constraints in AGENTS, detailed subsystem findings in architecture docs, and per-change evidence in the ledger/dossier. Avoid duplicating CLI implementations or declaring permanent passing test counts in prose. When a native signature or hook changes, update the corresponding skill reference and architecture note.

ADR-009's execution modes qualify older per-commit full-link wording: fast and batch modes defer checks, not their eventual completion. Record which commits were compiled individually and which SHA was linked.

## Skill availability

The project skill lives in `.agents/skills/turtle-playerbots-porting/SKILL.md`, with references loaded as needed. Open this management project as the working folder for automatic repository skill discovery, or explicitly ask the agent to read that file. A separately opened nested Git repository may not discover skills above its repository root; use the explicit skill path in that case. No global installation is needed.

See [official skill discovery documentation](https://learn.chatgpt.com/docs/build-skills). Project AGENTS and README also link the skill for agents that do not implement automatic discovery.
