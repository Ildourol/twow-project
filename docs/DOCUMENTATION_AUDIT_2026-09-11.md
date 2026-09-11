# Documentation and architecture guidance audit - 2026-09-11

Scope: management-project instructions, overview, handbooks/architecture docs, command dispatcher, and selected source declarations and call sites. This is a documentation review, not a whole-core correctness certification or a new runtime/build result.

## Assessment

The separation of overview, policy, command reference, architecture and per-port evidence is useful. Navigation and repeated conflicting claims made it harder to apply reliably. Added a documentation map and a focused project skill with on-demand syntax, schema, build and source references. Existing detailed history remains available.

## Corrections and clarifications

| Finding | Resolution |
| --- | --- |
| `MAX_RACES=11` described as eleven playable races | Current guidance identifies ten playable race IDs and exclusive bound 11; declarations and masks remain authoritative |
| `sTWDebuff` described generically as 64-bit streaming | Use custom debuff streaming; inspect actual packet/field widths instead of assuming a bitmask |
| Fast/batch mode confused with completed verification | Explain deferred checks and record exact tested SHA/configuration; compile, link, startup and gameplay remain separate |
| Compilation assumed to locate the offending donor commit or yield identical binaries | Remove the guarantee; dependencies can span commits and reproducibility needs separate evidence |
| Core/module/SQL syntax left implicit | Added verified target API examples, module discovery/loader conventions, SQL adaptation procedure and source register |
| Script command 93 called a packet opcode | Clarified database-script command versus network protocol opcode |
| Handbook called external viewer/donor schema authoritative | Target schema/loaders are authoritative; external sources provide comparison evidence |
| Candidate branch naming inconsistent | Use WorktreeManager output; dated pipeline examples are not a branch naming contract |

## Tooling limitations retained for visibility

- Package build commands invoke workflows that can commit queued candidates. They must not be used as harmless inspection commands.
- Regex compatibility gates and AI audits cannot certify absence of all regressions. Check relevant source, callers and runtime behavior.
- Historical README test totals and workflow performance timings are snapshots, not live measurements.
- The current dispatcher and WorktreeManager own executable syntax and branch naming; architecture prose is explanatory.

No server code, database, source watermarks, build configuration, branches or remotes were changed for this review. Donor sources were inspected without fetching or integrating new history. The web knowledge-base and historical comparison pages could not be retrieved; the source register records that limitation.

## Maintenance rule

Validation: skill-creator's `quick_validate.py` passed. Relative links across 23 current guidance files resolved, `git diff --check` passed, and the new skill contains no external project-folder references. The server checkout remained unchanged. Example C++ fragments were checked against declarations; they were not built as standalone translation units.

For future edits, update the smallest authoritative document and link it from the map. Preserve actual user policy while identifying dated claims and technical contradictions. Avoid turning advisory optimization claims into correctness guarantees.
