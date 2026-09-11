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
| Compatibility aliases documented backwards, and Action::Execute shown by value | Corrected donor-to-native alias direction and `Event&` signature |
| Root junction ban contradicted the documented local donor topology | Clarified existing in-project compatibility junctions; no cross-project dependencies |
| Multi-expansion donor filtering contradicted separable Classic adaptations | Preserve the Classic-only target while evaluating separable shared fixes |

## Tooling limitations retained for visibility

- `tools/task.ps1` verification helpers return booleans; a caller must not assume a failing compile produces a failing process exit status. The skill supplies a direct CMake invocation with an explicit native exit-code check.
- `commit-and-push` has mutating staging/publishing behavior. Its name and documentation are not proof of a full executable link. The existing optimized modes remain available; their deferred checks must be reported honestly.
- `batch-compile-and-audit` scans and updates ledger data, then invokes builds. It does not implement all candidate adaptations automatically.
- The existing compatibility shim contains no-op/zero-valued fallbacks. They need semantic review whenever a new port depends on them; this documentation task did not modify them.
- The target's own core-preservation guide is useful and explicitly identifies dated evidence. Keep consulting it alongside current callers.

No server code, database, source watermarks, build configuration, branches or remotes were changed for this review. Donor sources were inspected without fetching or integrating new history. The web knowledge-base and historical comparison pages could not be retrieved; the source register records that limitation.

## Maintenance rule

Validation: skill-creator's `quick_validate.py` passed. Relative links across 21 current guidance files resolved, `git diff --check` passed, and the new skill contains no external project-folder references. The server checkout remained unchanged. Example C++ fragments were checked against declarations; they were not built as standalone translation units.

For future edits, update the smallest authoritative document and link it from the map. Preserve actual user policy while identifying dated claims and technical contradictions. Avoid turning advisory optimization claims into correctness guarantees.
