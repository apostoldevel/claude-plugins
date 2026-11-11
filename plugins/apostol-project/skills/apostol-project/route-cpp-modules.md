<!-- Route of the /apostol-project skill: one role's reading order, opened from the routing table in SKILL.md. -->
# Route — C++ modules of the CRM stack (AppServer, PGFetch, own Workers / processes)

**Read now:** [`decision-rules.md`](decision-rules.md) (Step 14).

**Open when the task needs it:** [`processes.md`](processes.md) · [`reading.md`](reading.md) Tier 2 ·
[`anti-patterns.md`](anti-patterns.md) (Process) · [`design.md`](design.md) when a platform construct fights you.

**Skip unless asked:** [`entity.md`](entity.md), [`workflow.md`](workflow.md), [`frontend.md`](frontend.md),
[`conventions.md`](conventions.md).

**The specification:** Part I module blocks, clause 05 (transport ↔ database), Annex B (keys).

## Rules of this layer

- **`StreamServer` is a Worker Module** despite living in `src/processes/`: register it in `Workers.hpp` via
  `module_manager().add_module()`, not `add_custom_process()`. The same holds for anything deriving from
  `StreamServer` / `PgStreamServer` (`entity.md` § Where shared modules really live).
- **Authentication in C++, authorization in SQL** (SKILL.md, Step 4): the business decision on data stays in SQL.

**The project's own C++ side:** `conf/` holds `default.json` (modules, processes, DB), `default.<profile>.json`,
`oauth2/` (providers) and `sites/` (per-hostname routing); `backend/configure` downloads and pins the shared components.
