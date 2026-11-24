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

## Rules of this layer

- **A guard fails closed.** Every "could not look" is a stop, never a pass; a diagnostic turns every failed read into a
  flag, never into a clean report. Re-run a preflight right before the step it guards.
- **A public template or repository is cleaned by class, not by a list:** task ids, names of projects, brands and
  sites, dates, incident figures, internal pointers — found by reading as well as by `grep`, base64 and JWT samples
  decoded. The removed text stays in history.
- **Secrets and images:** `docker compose config` prints the interpolated `.env`; only the `.dockerignore` at the root of
  the build context counts (`frontend.md`); `postgres:18` keeps its data under `/var/lib/postgresql`
  (`install-pitfalls.md` § AA); `workers: 0` means the host's cores, not the container's quota (`processes.md`).
