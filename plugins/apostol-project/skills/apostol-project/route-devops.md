<!-- Route of the /apostol-project skill: one role's reading order, opened from the routing table in SKILL.md. -->
# Route — devops / release

**Open when the task needs it:** [`install-pitfalls.md`](install-pitfalls.md) (install, `--init`, export by pins) ·
[`processes.md`](processes.md) (which key starts what, stop deadlines, the `notify` channel modes) ·
[`facts-2026-09.md`](facts-2026-09.md) § Which platform you stand on.

**Skip unless asked:** Steps 6–10 and 13 — [`db-architecture.md`](db-architecture.md), [`entity.md`](entity.md),
[`workflow.md`](workflow.md), [`access-control.md`](access-control.md), [`frontend.md`](frontend.md),
[`conventions.md`](conventions.md).

**The specification:** Part I Annex B (keys); `drift.py` in a release.

A task outside the code — shell, compose, hooks, CI — needs the core and [`verification.md`](verification.md) only.

**The project's own C++ side:** `conf/` holds `default.json` (modules, processes, DB), `default.<profile>.json`,
`oauth2/` (providers) and `sites/` (per-hostname routing); `backend/configure` downloads and pins the shared components.
