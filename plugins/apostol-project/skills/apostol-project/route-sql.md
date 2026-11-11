<!-- Route of the /apostol-project skill: one role's reading order, opened from the routing table in SKILL.md. -->
# Route — SQL / configuration (`configuration/<dbname>/`)

**Read now:** [`decision-rules.md`](decision-rules.md) (Step 14).

**Open when the task needs it:** [`reading.md`](reading.md) Tiers 0–1 · [`db-architecture.md`](db-architecture.md) ·
[`entity.md`](entity.md) · [`workflow.md`](workflow.md) · [`access-control.md`](access-control.md) ·
[`anti-patterns.md`](anti-patterns.md) · [`facts-2026-09.md`](facts-2026-09.md) · before a commit
[`conventions.md`](conventions.md) · a fresh base [`install-pitfalls.md`](install-pitfalls.md) · [`design.md`](design.md) when a platform construct
fights you (a right you cannot express, a state that does not change, a filter that silently disappears) — check the
design before you bend the configuration.

**Skip unless asked:** [`frontend.md`](frontend.md); [`processes.md`](processes.md) unless you touch `http` / PGFetch / jobs.

**The specification:** Part II and your project's Part.

## Rules of this layer

- **A configuration overrides platform functions in practice** — by `CREATE OR REPLACE` later in the load order
  (`facts-2026-09.md` § Extension mechanism; every project redefines dozens). A platform fix then does not reach that
  project, and a rule kept in both copies drifts silently. Before you rely on a platform function or change one,
  `grep -n "FUNCTION <name>"` in both `sql/platform/` and `configuration/<dbname>/`, and verify on a fresh install, where
  the load order decides which copy wins.
- **`WriteToEventLog` 6-arg `(pType, pCode, pScope, pEvent, pText, pObject)`** is the canonical form; the 4- and 5-arg
  wrappers exist, production code uses 6-arg with an explicit scope (`entity.md`).
- **`gen_kernel_uuid()` for primary keys**, never `gen_random_uuid()` directly.
- **Areas are not seeded** — the lifecycle events of the entity that owns them create them (a tenant's create event
  creates its area; `tenant.code = area.code`); do not pre-create them in `FillDataBase` (`db-architecture.md`).

## Before committing

- [ ] `./runme.sh --update` runs cleanly (no errors, no warnings).
- [ ] A changed signature or a new trigger on an existing table → the patch is written **and applied** (`--patch`); `--update` alone leaves the base in the "not unique" state.
- [ ] No anti-patterns from [`anti-patterns.md`](anti-patterns.md).
- [ ] `INDEX.md` updated for the new entity.
- [ ] If anything in shared layer was touched: STOP, push upstream first.
- [ ] Evidence-based completion claim — never "should work" or "looks right". Run it.
