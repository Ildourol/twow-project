# Commit Selection & Triage Policy

## 1. Priority Classification Hierarchy

Upstream commits are categorized and triaged strictly by impact, correctness, and risk:

| Tier | Priority Level | Defect / Enhancement Classes | Action Policy |
| :--- | :--- | :--- | :--- |
| **P0** | **CRITICAL** | Crashes, memory corruption, `std::future_error`, assertions, use-after-free, deadlocks, infinite loops, broken persistence, bot lifecycle failures, group desync. | Immediate triage and port. Port with adaptation if required. |
| **P1** | **HIGH** | AI combat correctness, targeting failures, healer priority (tank over DPS), threat handling, movement/pathing stalls, stuck bots, resurrection validation, spell cast failures. | Standard port candidate under `NORMAL` mode. |
| **P2** | **MEDIUM** | Quality-of-life enhancements, useful new bot strategies, player chat commands, loot optimizations, travel target distribution. | Evaluated under `NORMAL` and `DEEP` modes. |
| **P3** | **LOW / OPTIONAL**| Large speculative features, complex new subsystems, or heavy architectural changes. | Defer until stability parity is proven. |

---

## 2. Rejection & Disqualification Criteria

Commits exhibiting any of the following traits are automatically disqualified:

1. **Strict Vanilla Mandate & Expansion Incompatibility (`EXPANSION_INCOMPATIBLE`)**:
   - **Absolute Prohibition**: Target is strictly Vanilla / Classic (1.12.1 / Turtle WoW 1.18.1 Classic+). Any commit from TBC (2.x), WotLK (3.x), or later expansions is **STRICTLY DISQUALIFIED**.
   - Disqualified traits include: post-Vanilla spells, talents, combat ratings, resilience, jewelcrafting, Arena teams, flying mounts, Death Knights, post-Vanilla dungeon/raid scripts (Karazhan, Gruul, Naxx-80, Ulduar, ICC), and multi-expansion conditional code.
   - Only changes that are strictly Vanilla / Classic relevant are eligible for porting.
2. **Architecturally Incompatible (`ARCHITECTURALLY_INCOMPATIBLE`)**:
   - Upstream changes assuming foreign core memory layouts, alien packet formats, or external third-party libraries not in target.
3. **Cosmetic / Formatting / Noise (`REJECTED`)**:
   - Pure whitespace, code reformatting, or comment reorganization without behavioral changes.
4. **Already Present / Semantically Duplicate (`ALREADY_PRESENT` / `DUPLICATE`)**:
   - The bug is already fixed in target under a different commit SHA, or covered by existing Turtle native logic.
5. **Superseded by Follow-Up (`SUPERSEDED`)**:
   - Upstream commit that was subsequently reverted or refined by a later upstream commit. Only the final clean state is ported.
6. **Defect Not Present (`NOT_APPLICABLE`)**:
   - Target does not implement the affected code path or uses a fundamentally different subsystem.

---

## 3. Status Taxonomy

Every candidate commit evaluated is assigned one of the following statuses in `state/porting-ledger.json`:

- `CRITICAL`: High-severity P0 fix eligible for immediate priority port.
- `RECOMMENDED`: High-value P1 fix or mature P2 improvement meeting all safety criteria.
- `OPTIONAL`: Valid P2/P3 enhancement deferred for later consideration.
- `PORT_WITH_ADAPTATION`: Fix requires rewriting using target-native contracts or `cmangos-compat-shim.h`.
- `PORTED`: Implemented and committed to the target branch.
- `VERIFIED`: Confirmed passing MSVC 2022 x64 compilation and linking `mangosd.exe`.
- `PUSHED`: Pushed to remote target branch `playerbots`.
- `ALREADY_PRESENT`: Semantic equivalence already identified in target.
- `DUPLICATE`: Identical to another ported candidate.
- `SUPERSEDED`: Replaced by a more comprehensive downstream/follow-up commit.
- `NOT_APPLICABLE`: System does not exist or apply to target.
- `EXPANSION_INCOMPATIBLE`: Post-Vanilla mechanics invalid for Turtle WoW 1.18.1.
- `ARCHITECTURALLY_INCOMPATIBLE`: Conflicts with target modular/threading design.
- `REJECTED`: Disqualified due to risk, regression hazard, or lack of value.
- `BLOCKED`: Awaiting dependency resolution or external clarification.
