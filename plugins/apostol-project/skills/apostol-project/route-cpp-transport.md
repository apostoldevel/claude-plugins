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
