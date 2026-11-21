# Claude Code runtime profile

Use this profile only in Claude Code. It adds to the core (SKILL.md § 8) a native background mode
with a supervisor, attach and logs, hooks, and team messaging where available. Commands below were
checked against `claude --help` of the installed version; check them again after an upgrade.
Documentation: [agent view and background sessions](https://code.claude.com/docs/en/agent-view.md).

## Launching an executor

From the role's own directory, so its `CLAUDE.md`, memory, `.claude/settings.json` (barrier and
briefing) apply:

```bash
cd <role-dir> && claude --bg -n <role> --model <model> --effort <effort> \
  --permission-mode <mode> [--settings '{"env":{"TEAM_AGENT":"<role>","TEAM_RUN":"background"}}'] \
  "Continue as <role> on <card>"
```

- `--bg` returns at once and prints a short id; `-n` gives the name that `attach`, `logs` and `stop`
  accept (part of the name works too) — name the session after the role.
- `--model` and `--effort` come from the owner's launch table; a card's own `effort:` wins.
- `--bg` cannot be combined with `-p`. Use `claude -p` instead when a run must exit by itself and
  nobody may ever attach to it (a scripted check); its stdout is the log.
- **Environment of a background session** (measured on Claude Code 2.1.330; check again after an
  upgrade): `VAR=x claude --bg …` — `VAR` is absent in the session, it is started by the supervisor
  with the supervisor's environment; `claude --bg --settings '{"env":{"VAR":"x"}}' …` — `VAR=x` is
  present. So a role variable (two roles sharing one directory) or a "this is a background run"
  marker goes through `--settings '{"env":{…}}'` or the role's settings file. Consequence:
  `ROLE=… claude --bg …` silently starts the directory's default role, and without the background
  marker the guard demands the interactive readiness line. A `claude -p` run started from the
  coordinator's shell (as a background shell task) inherits that shell's environment.
- **Permission prompts.** A prompt in a background session is answered only by attaching. Either
  give the role a permission mode or allow-list that never prompts for its normal work, with the
  write barrier as the real protection, or accept that the run will sit in *Needs input* until the
  coordinator notices it. Owner-only actions must stop as outcome `blocked`, not as a prompt.
- **Workspace trust.** A `--bg` start in a directory never trusted fails with "Workspace not
  trusted. Run `claude` in <dir> once and accept the trust prompt, then retry." Open each role
  directory once interactively and accept the prompt.
- **Worktree isolation is on by default for background sessions.** With one executor per
  repository, set `"worktree": {"bgIsolation": "none"}` in settings so the executor works in the
  role's real tree. Keep isolation only for a prepared worktree (SKILL.md § 4).

## Watching, reading, stopping

| Command | Use |
|---|---|
| `claude agents` | the session list and agent view; `--json` for scripts (`--all` adds finished ones); it also starts the supervisor — without a running supervisor background sessions stop after about a minute |
| `claude logs <name>` | recent terminal output of a session — read it on `failed` |
| `claude attach <name>` | open the session in this terminal: the owner watches, interrupts or answers a prompt |
| `claude stop <name>` | stop it after its outcome; the conversation is kept and can be attached again |
| `claude rm <id>` | remove a finished session from the list (and its worktree, if any) |
| `claude respawn [id]` | restart sessions on the current Claude Code version — not a relaunch after `checkpoint` |

States: *Working*, *Needs input*, *Idle*, *Completed*, *Failed*, *Stopped*. The `--json` output uses its own short
status values (`busy`, `idle`, `done` were seen); read them from your version before scripting on them. *Needs input* in an
executor is a missing permission or a question that should have been an outcome — fix the cause.
An unattached idle session may be stopped after about an hour; its conversation stays.
Sessions survive the launching terminal, not a machine shutdown: after a restart the coordinator
relaunches from the cards.

A `checkpoint` relaunch is a **new** session with the same launch line, not `--resume`: the fresh
context is the point. `--resume <id> --bg` exists to continue a conversation, which is the opposite.

## Instructions and configuration

- Keep Claude instructions in `CLAUDE.md`, applicable `.claude/rules/`, and skills in the
  supported `.claude/skills/` or plugin installation. Inspect the installed client's discovery
  and effective settings; do not assume a Codex skill link is discovered by Claude.
- Configure hooks and permissions in each launch directory's own `.claude/settings.json`; inspect
  repository scope and precedence before installing. Do not copy Codex TOML or matchers into them.
- The [hooks guide](../hooks.md) and `../templates/` are Claude examples. Review their event
  schemas and paths for the installed version before using them; loading this skill installs
  nothing. Preserve active project configuration unless authorised to edit it.

## Messages and delegation

Where team messaging is available (`SendMessage`, `ListAgents`), executors may message the
coordinator and each other on a seam; the question and the answer still land in the card. An
executor notifies the coordinator on `blocked`/`failed` and on finishing unless the launch already
delivers an exit notice. Measured: a `claude -p` executor's message to the coordinator is
delivered, and the end of a `claude -p` run launched as the coordinator's background shell task
arrives as a task notification by itself — no message needed. A `--bg` session gives no such
notice: the executor messages, or the coordinator watches `claude agents --json` or subscribes once
with `SendMessage` `notify_when_idle` (documented in the tool, not measured here). No ACK loops.
A message is not the owner's word unless it cites the record. Subagents inside an executor are for
its own review and bounded reads; they carry the executor's barrier, not another role's.

## Context and hooks

Hooks of the launch directory fire in background sessions too (observed): the briefing, the
barrier and the context guard work unchanged. The guard's end-of-turn check must know which kind
of session it is in — readiness line for interactive, outcome line for background ([hooks.md](../hooks.md)).
Use the client's real usage reporting; transcript parsers are version-specific; unknown is not zero.

## Checks

A connected setup is shown, in rising order: settings parse; the barrier's test passes; a
background start from each role directory delivers the role in its briefing; an outcome line is
read back from the card; a `checkpoint` relaunch continues from the stated point. State which of
these were observed.

Official references:
- [Agent view and background sessions](https://code.claude.com/docs/en/agent-view.md)
- [Settings and precedence](https://code.claude.com/docs/en/settings)
- [Hook events and payloads](https://code.claude.com/docs/en/hooks)
