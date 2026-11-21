# Changelog

Versions follow [semver](https://semver.org); the current one is in `.claude-plugin/plugin.json`. Dates are the
author's working days.

## 3.0.1 — 2026-11-21

- **Background-session environment, measured.** On Claude Code 2.1.330 a variable set in the launching shell is
  absent in a `--bg` session and one passed through `--settings '{"env":{…}}'` is present; the client sets
  `CLAUDE_CODE_SESSION_ATTENDED=0` there while `CLAUDE_CODE_ENTRYPOINT` stays `cli`; a `claude -p` run started from
  the coordinator's shell inherits its environment; the exact untrusted-workspace message. `ROLE=… claude --bg …`
  silently starts the directory's default role. Stated as measured with the version in
  `references/claude-code.md` and `hooks.md`; check again after an upgrade.
- **Messages between executors are allowed (§ 3, § 5).** Executors may message each other on a seam; the question
  and the answer still land in the card. An executor notifies the coordinator on `blocked`/`failed` and on finishing
  unless the launch already delivers an exit notice — a `claude -p` background shell task does, a `--bg` session
  does not (`claude agents --json` or a one-shot `notify_when_idle` subscription). No ACK loops. Same wording in the
  Claude Code and Codex profiles.

## 3.0.0 — 2026-11-21

The coordinator becomes the control bus; executors run in the background. Breaking: the executor is no longer an
interactive session the owner resets by hand, and the default working day is the calendar day.

- **One window (§ 1).** At most two interactive sessions — the coordinator and, optionally, a technical lead; the owner
  talks to them only. Executors are background sessions, one per card, launched by the coordinator from the role's own
  directory so its instructions, memory, barrier and briefing apply. Model and effort per role from one table the owner
  controls; a card may raise effort.
- **The outcome instead of a readiness line (§ 5).** An executor ends every run with
  `Outcome: review|blocked|checkpoint|failed — …` as the last line of the card's work log. The coordinator launches an
  independent check on `review`, decides or asks one question on `blocked`, relaunches the same line on `checkpoint`
  (a fresh context replaces a clear; at most two relaunches without progress), reads the log on `failed`, and sends the
  owner one status line per outcome.
- **Authority in three tiers (§ 4).** A coordinator's message citing a recorded owner decision is the owner's word;
  regulated actions performed before proceed without asking again; destructive, irreversible or unregulated actions stop
  whoever asks. Own configuration changes only on the owner's word in the agent's own terminal. Unattended, an owner-only
  decision ends the run as `blocked`.
- **Messages are an accelerator (§ 5).** An executor may knock on the coordinator; the content is always in the card.
  No executor-to-executor messaging; across teams, coordinator to coordinator.
- **One executor per repository (§ 4)** unless worktrees are prepared — the trade-off is documented: a fresh worktree
  lacks submodules, ignored files and build cache, and a test stack that mounts the main checkout gives a false green.
- **Context (§ 6).** Thresholds and the guard stay; for an executor "record the state and stop" is `checkpoint`.
- **Calendar day by default (`day.md`).** The first session of a date opens it and closes the previous one; the
  owner-word day is an option.
- **Adapters.** Claude Code: `claude --bg` with `-n`, `--model`, `--effort`, `--permission-mode`; `claude agents`
  (`--json`), `attach`, `logs`, `stop`, `rm`, `respawn`; states; trust, supervisor, idle stop, worktree isolation and
  `worktree.bgIsolation: none`. Codex and other clients: a detached non-interactive run with a log outside git.
- **Hooks (`hooks.md`).** Hooks fire in background sessions too; the guard checks the outcome line there instead of the
  readiness line, told apart by a marker passed at launch — through `--settings` env, since a variable of the launching
  shell does not reach a `--bg` session.
- **Pitfalls.** The worktree false green, `-p` versus `--bg`, `-n` names, the launch variable that never arrives,
  workspace trust, the supervisor, idle stop, hooks in background sessions, the unanswered permission prompt, the
  relaunch loop.
- **Card template:** the outcome line and an optional `effort:` field.
- `references/field-guide.md`: statements the new model contradicts removed (foreground-only sessions, one context per
  day, the rejected session-per-card, the calendar-day prohibition, live-state changes only in the executor's terminal).

## 2.0.0 — 2026-11-16

The team's process no longer stands on one client. Breaking: `SKILL.md` is a new, shorter rule set; the 1.0.0 rules
moved to `references/field-guide.md` as experience.

- **The card is the portable unit, not the session.** Long-lived named sessions, peer messaging, monitors and context
  guards are a client's accelerators; the process works without them.
- **Portable core and thin adapters (§ 8).** Roles, card contract, gates and commit policy in the core; transport,
  lifecycle, context counting and reset rituals in a profile per client. Minimum for any CLI: the core, the card, one
  launch line. A stop rule against rebuilding one client's runtime inside another.
- **Product before mechanics (§ 9).** Four signals from git: records versus product, user-visible increments versus
  self-found defects, the owner as message bus, always-read size. Each release plan names its product goal.
- **Evidence-gated transitions (§ 4).** `done` needs an acceptance matrix by someone other than the author —
  `pass` / `fail` / `not verified`; minimal output per role; approval gates explicit, "auto" bounded to a named segment.
- **Runtime profiles:** `references/claude-code.md`, `references/codex.md`, `references/other-clients.md` (no transport
  required; optional file mailbox).
- **Card template:** "who gains what", numbered criteria, the stage-and-handoff section, the acceptance matrix.
- `day.md`, `hooks.md`, `pitfalls.md`, `apostol.md`: a header on which client each applies to; hooks marked as Claude
  Code examples.

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
