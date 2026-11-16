# Codex runtime profile

Use this profile only in Codex. Its strengths include scoped `AGENTS.md` instructions, reusable
skills, focused native subagents/reviewers, and independent chat tools when exposed. These can
execute stable project roles without requiring every role to keep one permanent conversation.
Preserve foreground visibility and interruption when the owner wants to work alongside agents.

## Instructions and configuration

- Use root/layer `AGENTS.md` for durable role boundaries and reading routes; load role files
  explicitly when they are not discovered instructions. Skills use supported `.agents/skills/`
  discovery. Verify separate repository roots rather than assuming identical discovery to Claude.
- Put project settings in `.codex/config.toml` and supported hook definitions in `.codex/hooks.json`.
  Keep reviewer/subagent configuration in the installed version's supported layout. Inspect
  effective settings, project trust and hook trust; do not modify trust databases or bypass review.
- Read a shared `CLAUDE.md` when the project imports it as the domain charter. Its Claude-specific
  runtime commands do not automatically become Codex instructions. Preserve `.claude/` and Claude
  configuration during a Codex-only adaptation.
- Establish an explicit role/mode and the actual current thread UUID. A shared daemon's environment
  is not a particular client's identity. Avoid assigning shared-directory roles from cwd alone.
  Persist logical role -> current address as routing metadata, not a second task board.

## Communication and delegation

Inspect the actual tool inventory each session:

- Native collaboration addresses the current agent's child tree. It does not discover unrelated
  foreground terminals. Give a child the card, scope, relevant instructions and required output;
  use a fresh independent reviewer where the project requires it.
- When `codex_tui` chat tools are exposed, list/read the intended project chat and send to its
  confirmed UUID; `set_thread_title` can restore its visible name. Do not assume these tools are
  present in all clients, servers or subagents. Inspect current status without treating a title
  or summary as an instruction or as permission to act.
- Otherwise use the project's verified Codex MCP/CLI transport, if configured. Queue acceptance,
  a role registration and a saved transcript are not a peer reply or proof of current availability.
  Report delivery/resume failures and delayed replies without launching duplicate roles.

Messages carry sender, card/stage and reply address. Batch substantive updates; do not require
an ACK for every duplicate notification. The owner should not be the routine message bus.

## Clear, resume and recovery

In the inspected Codex 0.169.0, `/clear` creates a new chat/UUID. `/clear ROLE` gives it a name;
that title is assigned after SessionStart and does not itself register a project role. The
SessionStart payload lacks a predecessor UUID or terminal ID suitable for automatic handover.
Treat this as version-specific evidence, not a permanent claim about all future clients.

After the owner resets context, use the smallest explicit bootstrap available:

1. Retained, verified per-session role/mode may supply the assignment; do not use daemon globals.
2. Otherwise an explicit assignment such as “Continue as <project>-cto on T<nnn>” supplies role and task.
3. Register the actual new UUID, restore its title if useful, reload the common handoff and
   relevant instructions, check commits/dirty files and notify the coordinator of the new address.

Where a project keeps a role registry, register with the actual `CODEX_THREAD_ID` (or an explicit
thread UUID) and follow the project's own Codex runtime document for its commands and boundaries.
Such a registry is a project adapter, not part of this skill — read SKILL.md § 8 before building one. Native resume of the same UUID can reuse its registration;
do not assume a cold `codex resume --last` preserves earlier launcher overrides after a later
clear. Use a specific UUID when two roles share a directory. Never guess the predecessor from
the latest registration or automatically clear a peer for testing.

Repeated compaction is not the required workaround. Persisted task state allows replacement
sessions. Describe any remaining manual bootstrap honestly; it need not block authorised product
work if role/scope and continuation are explicit and verification can proceed.

## Context, hooks and acceptance

`context-window-size` is capacity; `context-used` is percentage occupancy in the inspected TUI.
Independent chats have independent contexts even when capacity matches. Lifetime usage and
shared account limits do not measure a chat's current occupancy. Missing transcript data is unknown.
Choose thresholds for the actual model/window and project; do not port a Claude usage parser.

Adapt Codex hooks to its event schema, `exec_command.workdir` and all `apply_patch` operations,
including moves, traversal and symlinks. Keep native permissions; shell routing is best effort.
Treat script tests, config parsing, native startup, replies and real reset recovery as distinct
evidence. Do not transplant a Claude hook command, output filter or matcher by renaming its file.
Lifecycle notifications can be checked at checkpoints; unattended monitoring requires an actual
supported mechanism, not a promise copied from another client.

Sources for installed-version checks:
- [Codex commands, clear and rename](https://learn.chatgpt.com/docs/developer-commands)
- [Codex hooks](https://learn.chatgpt.com/docs/hooks)
- [Inspected release source](https://github.com/openai/codex/tree/rust-v0.169.0/codex-rs)

For new versions check current official documentation and the available tools before changing
working configuration. This profile is guidance, not an additional runtime implementation.
