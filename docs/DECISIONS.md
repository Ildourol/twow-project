# Architectural Decision Records (ADR)

## ADR-001: Independent Standalone Project-Management Architecture
- **Status**: Accepted
- **Context**: The project coordinates upstream porting, auditing, and verification for PlayerBots across multiple Git repositories.
- **Decision**: Establish an independent, self-contained project-management layer directly under `Module-playerbots/` containing its own documentation, durable JSON state (`state/sources.json`, `state/porting-ledger.json`, `state/source-watermarks.json`), reports, and PowerShell task dispatcher.
- **Consequences**: Zero dependencies on external workspaces, ensuring high reproducibility and clean workspace isolation.

---

## ADR-002: Upstream Source Lineage & Porting Lanes
- **Status**: Accepted
- **Context**: Two donor repositories are available: CMaNGOS (`playerbots`) and vMaNGOS (`core`).
- **Decision**:
  - `cmangos/playerbots` is classified as **Native Manual Port Lane**: Port behavior and intent natively; adapt to target modular layout; filter out post-Vanilla code.
  - `ileboii/core` (`vmangos-ike3-playerbots`) is classified as **Adapted Port Lane**: Closer lineage; translate `src/game/PlayerBots/` to `modules/mod-playerbots/src/`; preserve Turtle extensions.
- **Consequences**: Avoids corrupting Turtle core contracts with foreign architectural assumptions.

---

## ADR-003: Target Canonical PlayerBots Path
- **Status**: Accepted
- **Context**: Historical documentation (`PLAYERBOTS_QUICKSTART.md`) referenced `src/modules/PlayerBots`, whereas commit `8415f1b9` restructured the repository into `modules/mod-playerbots`.
- **Decision**: Designate `modules/mod-playerbots` as the canonical target path for all PlayerBots modifications.
- **Consequences**: Eliminates path confusion and aligns with target CMake build configuration.

---

## ADR-004: Multi-Tier Verification Gate
- **Status**: Accepted
- **Context**: A compiling object file does not guarantee binary linkability or runtime correctness.
- **Decision**: Every ported commit or sync batch must compile `modules.lib` and successfully link `mangosd.exe` using MSVC 2022 x64 before marking as `VERIFIED` in the ledger.
- **Consequences**: Prevents broken builds and unresolved externals from being pushed to `playerbots`.

---

## ADR-005: Preserved Context, Token & Cache Budgets
- **Status**: Accepted
- **Context**: AI agents require strict bounds to prevent context window explosion and unnecessary API expenditures.
- **Decision**: Preserve exact budgeted constraints:
  - Context snippet limit: $\le 200$ surrounding lines.
  - Input token cap: 16,000 tokens.
  - Output token cap: 4,000 tokens.
  - Maximum candidates per batch: 50.
  - Build timeout: 900 seconds.
- **Consequences**: Guarantees deterministic, focused, and token-efficient evaluations.

---

## ADR-006: Prohibition of Unbounded Scope Widening & Mandatory Double-Confirmation Gate
- **Status**: Accepted (Binding Directive)
- **Context**: Donor repositories contain thousands of historical commits spanning multiple years and unrelated subsystems. Unbounded historical widening risks token bloat, regression hazards, and divergence from Turtle contracts.
- **Decision**: Strictly prohibit widening the scan scope into historical bulk donor commits. The project remains locked to the active recent watermark ranges. If scope widening is ever requested again, the agent must not execute it automatically; it must reject immediate execution, warn of scope explosion risks, and require an explicit double-confirmation from the operator before altering any watermarks.
- **Consequences**: Protects project focus, ensures high signal-to-noise ratio, and guarantees operator sovereignty over historical scope adjustments.

---

## ADR-007: Mandatory Commit-by-Commit Porting & Remote Pushing Architecture
- **Status**: Accepted (Binding Directive)
- **Context**: Porting multiple fixes in batched commits complicates regression attribution, git bisect operations, upstream provenance tracking, and cherry-picking between branches (`extended` and `playerbots`).
- **Decision**: While candidate commits may be audited and triaged in batches during scanning passes, all actual ports, code adaptations, build verifications, git commits, and remote pushes must be executed strictly **commit-by-commit** (1 upstream donor commit = 1 target git commit = 1 remote push). Grouping, combining, or squashing multiple upstream donor fixes into a single target git commit or single push is strictly prohibited.
- **Consequences**: Guarantees clean git history, precise regression isolation, full auditability, and 1-to-1 provenance traceability back to upstream donor repositories.

---

## ADR-008: Strict Vanilla / Classic Exclusivity Mandate (Absolute Prohibition on TBC & WotLK)
- **Status**: Accepted (Binding Directive)
- **Context**: Upstream donor repositories (especially `cmangos/playerbots`) actively develop across Classic, The Burning Crusade (TBC 2.4.3), and Wrath of the Lich King (WotLK 3.3.5a). Ingesting post-Vanilla spells, talents, combat mechanics, or expansion-specific logic introduces severe corruption, compile failures, and game balance disruption on Turtle WoW 1.18.1.
- **Decision**: Formally establish the **Strict Vanilla / Classic Exclusivity Invariant**. Porting ANY mechanics, features, spells, talents, strategies, or assumptions from TBC or WotLK is **STRICTLY PROHIBITED**. Only changes directly relevant to Vanilla and Classic (1.12.1 / Turtle WoW 1.18.1 Classic+) are permitted. Any candidate commit that touches or requires post-Vanilla systems must be either strictly stripped of all non-Vanilla code or completely disqualified with status `EXPANSION_INCOMPATIBLE` (P3).
- **Consequences**: Guarantees pristine Vanilla / Classic game mechanics, prevents TBC/WotLK code pollution, and ensures seamless compatibility with Turtle WoW contracts.

---

## ADR-009: Verification Pipeline Execution Modes for Token and Latency Optimization
- **Status**: Accepted (Binding Directive)
- **Context**: Compiling and linking `mangosd.exe` with MSVC 2022 on Windows requires 2–3 minutes per run and emits hundreds of lines of output into active context. Performing a full link cycle for every single commit incurs massive token waste and 10–15 minutes of idle waiting across small batches.
- **Decision**: Authorize two optimized verification modes alongside Strict Full-Link Mode:
  1. **Option 1: Fast Incremental Mode (Recommended Default)**: Compile the isolated library target `modules` / `modules_playerbots` per commit (~3s, ~3 lines of output). Push the atomic commit immediately to `playerbots`. Execute the full `mangosd.exe` link once at the batch or milestone boundary.
  2. **Option 2: Batch Verification Mode**: Apply and commit code changes sequentially in git to maintain 1-to-1 provenance and git bisectability, but execute a single compile and link pass (`modules` + `mangosd.exe`) at the conclusion of the batch.
  3. **Option 3: Strict Full-Link Mode**: Retained as an explicit option for P0 core architectural overhauls.
- **Consequences**: Yields ~90% reduction in context token consumption and build latency while preserving 1-to-1 git commit granularity, bisectability, and compiler diagnostic precision.
