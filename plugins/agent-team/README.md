[![ru](https://img.shields.io/badge/lang-ru-green.svg)](README.ru-RU.md)

# agent-team

An [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills), packaged as a Claude Code plugin, for running
development **with** a team of named Claude Code agents rather than handing it over. The agents are long-lived
foreground sessions: a coordinator and one agent per language layer, plus QA and an auditor when the load calls for
them. Each has its own memory. They coordinate over a git board, not a chat, and the working day is opened and closed
on the owner's word.

The skill is invoked as `/agent-team`. The companion `/agent-onboarding` covers the documents a project needs; this one
covers the people.

## What the agent gets

- **The choice that comes first:** a visible named team or an autonomous fleet. They are not variations of one
  thing.
- **Twelve rules, each with the price that bought it:**
  - roles by language and toolchain;
  - the launch directory as identity;
  - four carriers of knowledge (wiki, history by day, cards, memory as a pointer);
  - a board in git with priorities as groups and queues;
  - review started by the author;
  - work in flight limited by people;
  - sharding;
  - a write barrier per component;
  - the cost of what is always read;
  - a working day opened and closed by the owner's word;
  - the owner's word carried by record.
- **A bootstrap checklist** for a new project.
- **Hook templates**, tested:
  - a per-role write barrier with a positive allow and its self-contained acceptance test;
  - a session briefing by launch directory, with a lifecycle log;
  - a context guard enforcing the 300k / 450k / idle rules;
  - an output filter for test runs and builds;
  - `settings.json` for a coordinator and for a layer.
- **Verified pitfalls:** barriers, hooks, validators, trees and numbers. Each one was found by testing.

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
| `SKILL.md` | Part I, the choice; Part II, the twelve rules and the norms; Part III, the bootstrap checklist |
| `day.md` | The working day: `DAY`, opening, the seven closing steps, fixing state, the summaries check |
| `hooks.md` | The harness: what each template does, how to configure, register and test it |
| `pitfalls.md` | Verified pitfalls: barrier and hooks, roles and trees, board and cards, instruments, the owner's word |
| `apostol.md` | Applying the skill in the Apostol ecosystem (libapostol + db-platform) |
| `templates/` | The hooks and their test, `settings.json` examples, a card, `PRIORITIES.md`, `DAY` |

## Assumptions

- **Claude Code** with cross-session messaging (`SendMessage`, `ListAgents`) and hooks (`PreToolUse`,
  `SessionStart`, `PostCompact`, `UserPromptSubmit`, `PostToolUse`, `Stop`).
- The hook templates need `bash`, `jq` and GNU `realpath`.
- The measurements in the text come from one production project of the Apostol ecosystem, August–September 2026.
  Numbers such as the context thresholds are that team's settings. Treat them as defaults.

## Feedback

Issues and pull requests are welcome. The skill keeps only what holds for **any** named team; a rule of one project
belongs in that project's charter.

History: [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](../../LICENSE)
