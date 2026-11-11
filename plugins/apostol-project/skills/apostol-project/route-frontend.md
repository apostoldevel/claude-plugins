<!-- Route of the /apostol-project skill: one role's reading order, opened from the routing table in SKILL.md. -->
# Route — Front-end

**Open when the task needs it:** [`frontend.md`](frontend.md) · [`access-control.md`](access-control.md) (what the
barrier does to your data) · [`anti-patterns.md`](anti-patterns.md) (Frontend).

**Skip unless asked:** Steps 6–8 and 11–13 — [`db-architecture.md`](db-architecture.md), [`entity.md`](entity.md),
[`workflow.md`](workflow.md), [`processes.md`](processes.md), [`conventions.md`](conventions.md).

**The specification:** Part II clause 09 with Annex A (routes and their gates), Part III clause 07, Part I `AUS`.

The rule that bites here is Must-know 8: tokens are cookie-only behind AppServer / GatewayAPI, guest routes are called
anonymously.
