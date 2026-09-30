[![ru](https://img.shields.io/badge/lang-ru-green.svg)](https://github.com/apostoldevel/skill-apostol-project/blob/master/README.ru-RU.md)

# skill-apostol-project

An [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills) for Claude Code. It gives an AI agent working
context for projects built on the Apostol ecosystem:
[libapostol](https://github.com/apostoldevel/libapostol) (C++20 transport) +
[db-platform](https://github.com/apostoldevel/db-platform) (PostgreSQL framework) + the project's own configuration.

The skill is invoked as `/apostol-project`. Work on the frameworks themselves (libapostol, db-platform, shared
modules) belongs to a separate skill, `/apostol`. Don't load both in one session.

## What the agent gets

- **The three-layer model and its boundaries.** What is shared and what belongs to the project. Where a fix belongs.
  What has to go upstream first.
- **A reading route for each of nine roles:** SQL, C++ modules, C++ transport without db-platform, front-end, Go
  gateway, QA, devops, audit, coordinator. The agent reads a ~30 KB core and opens only the references its task
  needs.
- **Platform patterns:**
  - entities and workflow;
  - access control: ACU / AMU / AOU, areas, the `Access<Entity>` barrier;
  - processes: PGFetch, LISTEN/NOTIFY, replication;
  - reports;
  - install pitfalls.
- **Anti-patterns:** the Hall of Shame, collected in code review across projects.
- **Verification techniques** that work the same in every layer: how to make sure a check actually checks
  something.
- **Measured facts** where code and wiki disagree. Each count or version states the platform version it was measured
  on.

## Install

The repository root is the skill directory. Clone it under the skill's name:

```bash
# personal: available in every project
git clone https://github.com/apostoldevel/skill-apostol-project.git ~/.claude/skills/apostol-project

# or for one project only
git clone https://github.com/apostoldevel/skill-apostol-project.git <project>/.claude/skills/apostol-project
```

To update: `git -C ~/.claude/skills/apostol-project pull`. Keep the directory name `apostol-project`, the same as
`name:` in `SKILL.md`.

## Use

Claude Code loads the skill by itself when a task matches its description. You can also call it explicitly with
`/apostol-project`. The agent then:

1. reads the core;
2. finds its row in **Read by role**;
3. opens the listed references as the task needs them.

When briefing a subagent, start the brief with `Activate skill /apostol-project before any work.`

## Layout

| File | What it holds |
|---|---|
| `SKILL.md` | Core, read in full: roles, design vs implementation, three layers, naming, must-know, Steps 2, 4, 14, 15, TL;DR |
| `anti-patterns.md` | The full Hall of Shame, with the note on the planner and Nested Loop |
| `reading.md` | Steps 1 and 3: what to read by depth of task, wiki pages, how to navigate an entity; details of Step 2 |
| `processes.md` | Steps 5, 11, 12: module pairing, LISTEN/NOTIFY, process model, PgPool, PGFetch, replication |
| `db-architecture.md` | Step 6: schemas, roles, load order, patches, triggers on platform tables |
| `entity.md` | Step 7: creating an entity |
| `workflow.md` | Step 8: states, methods, actions, events |
| `access-control.md` | Step 9: access control in full |
| `frontend.md` | Step 10: cookies, tokens, WebSocket, signing out |
| `conventions.md` | Step 13 checklist, SQL verification commands, README rule |
| `install-pitfalls.md` | Step 16: pitfalls of a live install and of exporting by pins |
| `facts-2026-09.md` | Step 17: facts from the 2026-09 inventory; they override older text |
| `report-subsystem.md` | The report subsystem |

## Assumptions

- **Workspace paths.** The text points to the author's layout:
  - framework mirrors in `~/DevSrc/Projects/{libapostol,db/platform,apostol-repo-v2}`;
  - `apostol-csms` as the production reference project.

  If your layout differs, read these paths as pointers, not requirements.
- **Two generations.**
  - v2 projects run on libapostol and keep SQL in `<project>/db/`.
  - v1 projects run on libdelphi and keep SQL in `backend/db/`.

  The C++ parts of the skill describe v2.
- **Versions.** Counts and claims about functions state the db-platform version they were measured on: 1.2.20 for
  the inventory, 1.2.31 as of 30.09.2026. Check your pin with `cat <sql>/platform/VERSION`.

## Feedback

After each task, agents rate the skill:
- what got in the way;
- what is wrong or stale, with the `file:line` of the truth;
- what is superfluous;
- what they had to work out themselves.

Issues and pull requests are welcome on the same terms. When editing, keep only what holds on **every** project. A
rule of a single project belongs in that project's `CLAUDE.md` or wiki.

History: [CHANGELOG.md](CHANGELOG.md).

## Related

- [libapostol](https://github.com/apostoldevel/libapostol): the C++20 framework (A-POST-OL)
- [db-platform](https://github.com/apostoldevel/db-platform): the PostgreSQL framework for backend development
- **Apostol CRM**[^crm]: the template project that brings the two together

## License

[MIT](LICENSE)

[^crm]: **Apostol CRM** — a template project built on the [A-POST-OL](https://github.com/apostoldevel/libapostol) (C++20) and [PostgreSQL Framework for Backend Development](https://github.com/apostoldevel/db-platform) frameworks.
