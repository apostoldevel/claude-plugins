[![ru](https://img.shields.io/badge/lang-ru-green.svg)](README.ru-RU.md)

# agent-team

An [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills), packaged as a Claude Code plugin, for delivering a
product **with** a team of agents in specialised roles — a coordinator, one agent per language layer, QA and an auditor
when the load calls for them — in Claude Code, Codex or any agent CLI that reads instructions and runs commands.

The portable unit of the team is the **card**, not the session: a card that carries its goal, criteria, scope and
continuation lets any fresh session of any client take the role and continue. Long-lived named sessions, peer
messaging and context guards are accelerators of one client, kept in separate runtime profiles.

The skill is invoked as `/agent-team`. The companion `/agent-onboarding` covers the documents a project needs; this one
covers the people.

## What the agent gets

- **Product before mechanics:** success is accepted increments and the owner's coordination effort, not agent count or
  message traffic; four signals measured from git tell when the team's records have outgrown its product.
- **A portable core and thin adapters:** roles, the card contract, gates and commit policy in the core; messaging,
  monitors, context counters and reset rituals in a per-client profile. The minimum that works anywhere is the core,
  the card and one launch line — «Continue as `<role>` on `T<nnn>`».
- **Evidence-gated transitions:** `review` carries the evidence output; `done` carries an acceptance matrix written by
  someone other than the author — `pass` / `fail` / `not verified`, where `not verified` is not `pass`.
- **Handoffs sufficient to resume:** seven fields in the card, from allowed paths to the exact continuation point.
- **Runtime profiles:** Claude Code, Codex, and any other execution-capable CLI (no transport required; an optional file
  mailbox).
- **The field guide:** the original twelve rules of a named Claude Code team, each with the price that bought it —
  kept as experience, not as mandatory startup reading.
- **Hook templates** for Claude Code, tested: a per-role write barrier with its acceptance test, a session briefing, a
  context guard, an output filter, `settings.json` for a coordinator and a layer.
- **Verified pitfalls:** barriers, hooks, validators, trees and numbers.

## Install

From the [apostoldevel marketplace](../../README.md#install):

```
/plugin marketplace add apostoldevel/claude-plugins
/plugin install agent-team@apostoldevel
```

The skill itself is the directory [`skills/agent-team/`](skills/agent-team/). The hook templates are **not** installed
as plugin hooks: a barrier is per component and per role, so each project copies them into its own `.claude/hooks/`
and configures them (`skills/agent-team/hooks.md`).

## Use

Call `/agent-team` when setting up a team, or when an existing one has one of the symptoms in the description. The
agent reads the rules in `SKILL.md` and opens the references as the task needs them.

## Layout

Paths are relative to `skills/agent-team/`.

| File | What it holds |
|---|---|
| `SKILL.md` | The rules: working relationship, knowledge carriers, roles, stages and gates, handoffs, recovery, the smallest runtime, the portable core, product-versus-mechanics signals |
| `references/claude-code.md` | Claude Code runtime profile |
| `references/codex.md` | Codex runtime profile |
| `references/other-clients.md` | Any other CLI: the core with nothing added |
| `references/field-guide.md` | The original twelve rules and bootstrap checklist of a named Claude Code team, as experience |
| `day.md` | The owner-controlled working day: `DAY`, opening, closing steps, fixing state |
| `hooks.md` | Claude Code harness examples: what each template does, how to configure, register and test it |
| `pitfalls.md` | Verified pitfalls: barrier and hooks, roles and trees, board and cards, instruments, the owner's word |
| `apostol.md` | Applying the skill in the Apostol ecosystem (libapostol + db-platform) |
| `templates/` | Claude Code hooks and their test, `settings.json` examples, a card, `PRIORITIES.md`, `DAY` |

## Assumptions

- The rules need only files, git and a client that runs commands. The runtime profiles describe what Claude Code and
  Codex add; a profile states which of its levels were actually observed.
- The hook templates are Claude Code examples and need `bash`, `jq` and GNU `realpath`.
- The measurements in the text come from production projects of the Apostol ecosystem, August–November 2026. Numbers
  such as context thresholds are those teams' settings, not universal limits.

## Feedback

Issues and pull requests are welcome. The skill keeps only what holds for **any** team; a rule of one project
belongs in that project's charter.

History: [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](../../LICENSE)
