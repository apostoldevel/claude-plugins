# Changelog

Versions follow [semver](https://semver.org); the current one is in `.claude-plugin/plugin.json`. Dates are the
author's working days.

## 1.0.0 — 2026-09-30

First public release, brought up to date with the practice of the team it was written on.

- **Split for the cost of loading.** `SKILL.md` keeps Parts I–III, the rules; the detail moved verbatim into
  references: the working-day regulation → `day.md`, the verified pitfalls → `pitfalls.md`, the Apostol
  ecosystem → `apostol.md`.
- **Roles:** QA (tests every layer, fixes none) and auditor (requirement → `file:line` → test → deviation, fixes
  nothing); a role is promoted from a repeated load, not from the roster.
- **Harness:** `settings.json` in every launch directory, shared hooks found by walking up, a layer keeps only its
  barrier; a registration check in the acceptance; temporary barrier exceptions carry their removal condition.
- **Templates (`templates/`):** the write barrier with a positive allow, role by launch directory, fail-closed for an
  unknown role, `NotebookEdit` by `notebook_path`, Bash checks for `cd`, in-place flags, `git apply`/`patch` — and its
  self-contained acceptance test; the session briefing with a lifecycle log; the context guard; the output filter;
  `settings.json` for a coordinator and a layer; a card; `PRIORITIES.md`; `DAY`.
- **Context rule:** one working day per context; 300k / 450k / idle rules enforced by the context guard; weekly limit
  rules.
- **Readiness:** one form — a line to the coordinator and `Ready for compaction or clear` as the last terminal line.
- **Clears are watched:** a lifecycle log and the coordinator's monitor; a brief after every clear.
- **Board:** priorities as groups and queues; questions to the owner live in the card; `review → done` is the
  coordinator's or the owner's; the external board is mirrored git → board.
- **Commit and push:** code — the agent's own decision after review, by path; documents — the agent itself when idle;
  push and tag — by the owner's recorded word, centralised in the release role.
- **The owner's word:** a recorded relay is the word; "in your own terminal" only for live deployments and the
  agent's own configuration; a word said to an agent directly is relayed to the coordinator in the same turn.
- **Norms:** three grounds for changing a working mechanism; loads into the owner's acceptance contour announced
  beforehand; the shared skill rated after each card.
