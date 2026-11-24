<!-- Route of the /apostol-project skill: one role's reading order, opened from the routing table in SKILL.md. -->
# Route — QA / cross-layer acceptance

**Read before you claim done:** [`verification.md`](verification.md) — in full; it is the method of this role.

**Open when the task needs it:** [`processes.md`](processes.md) (PGFetch, PgPool, background paths) ·
[`access-control.md`](access-control.md) (ACL bits, for mutation checks) · [`install-pitfalls.md`](install-pitfalls.md) ·
[`facts-2026-09.md`](facts-2026-09.md).

**Skip unless asked:** [`entity.md`](entity.md), [`workflow.md`](workflow.md), [`conventions.md`](conventions.md).

**The specification:** the deviation tables and the `90` clauses — a known deviation is a test that must fail until
the fix lands.

## Rules of this layer

- **Build the image under test from the pins** (`verification.md` § 6; `install-pitfalls.md` § U), and run a front-end
  suite inside the project's image.
- **The session is part of the input:** `verification.md` § 1, "Green for the wrong reason because of the connection",
  and the mutant checklist.
- **A new guard reorders the refusals of the old ones:** run the whole suite on the merged tree of what ships together
  (`verification.md` § 2).
