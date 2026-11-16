# Claude Code runtime profile

Use this profile only in Claude Code. Its strengths include project instructions, contextual
skills, hooks and, when available, team communication and specialist subagents. Preserve a
working visible team rather than replacing it solely to match another client's implementation.
These features support either a related series in one session or bounded delegated work.

## Instructions and configuration

- Keep Claude instructions in `CLAUDE.md`, applicable `.claude/rules/`, and skills in the
  supported `.claude/skills/` or plugin installation. Inspect the installed client's discovery
  and effective settings; do not assume a Codex skill link is discovered by Claude.
- Configure Claude hooks/permissions in its own `.claude/settings.json` and applicable local,
  user or managed settings. Inspect repository/worktree scope and precedence before installing.
  Do not copy Codex TOML, hook registrations or tool matchers into them.
- Role selection can use an explicit launcher selector and scoped briefing. A directory is a
  useful locator, but shared-directory roles require disambiguation. Private project memory
  can help navigation; the task must remain recoverable from shared project records.
- The existing [hooks guide](../hooks.md) and `../templates/settings.*.json`, `guard-write.sh`,
  `session-start.sh`, `context-guard.sh` and `team.conf` are Claude examples. Review/adapt their
  event schemas and paths for the installed version before using them. They are not automatically
  installed by loading this skill. Preserve active project configuration unless authorised to edit.

## Communication and delegation

Inspect available tools and the team's actual mode. Use native team messaging/agent discovery
when provided; do not assume every unrelated CLI terminal has joined the same team. Existing
named-team extensions may provide additional transport; distinguish them from native features.
Use a confirmed destination, require a reply to establish delivery, and keep task facts in cards.
Do not enable an experimental team mode, create duplicates or migrate working terminals merely
to reproduce an example. Subagents are useful for focused work and independent checks; respect
the project's delegation rules and preserve a human-visible session when requested.

## Context and recovery

Persist the common handoff before clear, compaction, shutdown or a task boundary. Load the
applicable role, card and day after recovery. Verify that the actual configured start/compaction
hook delivered the right role; a hook file existing on disk is not evidence it executed.
Do not assume display names, transport IDs or memory scope survive every reset/version. Repair
the explicit binding when needed rather than recovering from the latest unrelated session.

Use the installed client's real usage/context reporting. Transcript parsers are version-specific;
do not infer Codex occupancy from Claude cache fields or promise a fixed cache lifetime, billing
ratio or free recovery. Choose clear versus compaction by persisted state and remaining work.
A watcher/Monitor may be useful if actually available; do not invent one or wake idle roles to
simulate monitoring. Owner-controlled context resets remain the owner's action.

## Checks and sources

Check hook registration, allowed/denied paths and useful briefing, then observe native startup
and a bounded recovery/message exchange when needed. Native tool names and message delivery
timing are facts to inspect, not requirements imposed by the shared workflow.
The original output-rewriting filter is optional historical machinery: review its approval
effects before use; preserve failures and exit status without weakening permission gates.

Official references for current capability checks:
- [Settings and precedence](https://code.claude.com/docs/en/settings)
- [Hook events and payloads](https://code.claude.com/docs/en/hooks)
- [Agent teams and limitations](https://code.claude.com/docs/en/agent-teams)

These references guide verification, not a claim that native reset/team acceptance was run here.
