<!-- Route of the /apostol-project skill: one role's reading order, opened from the routing table in SKILL.md. -->
# Route — C++ transport without db-platform (own processes on bare libapostol, e.g. an OCPP Central System)

**Open when the task needs it:** the libapostol wiki `Architecture.md`, `Configuration.md` ([`reading.md`](reading.md)
Tier 2); [`processes.md`](processes.md) for PgPool, the `module.<Name>.enable` / `.leader` keys, the stop order and the
master's respawn — its modules are the CRM stack's, not a bare `CustomProcess`.

**Skip unless asked:** Steps 6–10 and 13 — [`db-architecture.md`](db-architecture.md), [`entity.md`](entity.md),
[`workflow.md`](workflow.md), [`access-control.md`](access-control.md), [`frontend.md`](frontend.md),
[`conventions.md`](conventions.md).

**The specification:** Part I `libapostol` blocks.

A task here rarely needs more than the core and [`verification.md`](verification.md). A fix in `libapostol` itself is
framework work — `/apostol`.

## Rules of this layer

- **Workers are processes.** IPC between them (`gather` includes the asker), node metrics, the stop order, `workers: 0`,
  a 0 ms timer, `${VAR}` in the config, CORS origins on bare libapostol — `processes.md` § Process lifecycle. Before
  adding cross-worker coordination, find what already arbitrates the same fact and keep one.
- **A build without the database** is checked in a scratch build directory of its own (`cmake -S . -B <scratch> …`), not
  in the tree's `cmake-build-*`; run both branches.
- **A pure header beside the module** (payload in, payload out) gives a stateless unit that a test reaches without the
  event loop.
- **A framework change consumed through a pin is a seam**: it can turn a neighbour's closed checks red (a label
  allow-list in another layer's harness) — name it before the gate.
- **A fake peer reproduces the real stop shape** (a Close frame followed by a reset), not a polite close
  (`verification.md` § 6).
