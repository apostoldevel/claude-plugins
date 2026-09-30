<!-- Reference of the /agent-team skill, read on demand via the table in SKILL.md. Moved verbatim from SKILL.md (Part V) on 30.09.2026; later edits are listed in CHANGELOG.md. -->
# Applying this in the Apostol ecosystem

The layout repeats across these projects: a workplace/umbrella repo plus separate `backend`
(C++ on libapostol), `db` (PL/pgSQL on db-platform) and `frontend` repositories, with the
frameworks vendored as submodules (`db/sql/platform`, `backend/src/lib/libapostol`, shared
workers and processes).

The role split falls out of it directly:

| Agent | Starts from | Owns |
|---|---|---|
| `<p>-owner` | project root | coordination, board, STATE.md, docs, `DECISIONS.md`; writes no code |
| `<p>-backend` | `backend/` | in-tree C++ modules and processes, and shared C++ modules |
| `<p>-db` | `db/` | `configuration/<dbname>` **+ `db-platform`** |
| `<p>-frontend` | `frontend/` | the applications and shared packages |
| `<p>-qa` | `tests/` | the cross-layer test harness; tests every layer, fixes none |
| `<p>-audit` | `audit/` | conformance audit; fixes nothing, findings are cards |

The general rule is that the framework goes to whoever owns that language in the project. One
project has an exception worth knowing about: `libapostol` was given to a **separate named agent**
(`<p>-apostol`, launched from `backend/`, therefore sharing memory, hooks and the day tree with
the backend agent), because it ships to every project in the ecosystem and what leaves it cannot
be recalled. That is a decision for the owner, not a default — and if you make it, write down
**who moves the pin** (the layer agent whose tree carries it, after its own build and full test
run) and **whose word the push needs** (the owner's, by name, every time — Rule 12).

Skills per mode: `/apostol-project` for the project layer, `/apostol` for framework work — never
both in one session. `/apostol-project` installs from the same marketplace as this skill:
`/plugin install apostol-project@apostoldevel`. Route entity work through `/new-db-entity` and index upkeep through `/index`;
those are per-task skills the layer agent loads, not roles. A one-function fix in the
configuration layer that happens to touch a platform helper does not need a mode switch — the
owner said so when asked.

Read-only for everyone: the framework mirrors at the workspace root (`libapostol/`,
`db/platform/`, `apostol-repo-v2/`) and the reference projects (the ecosystem's production
projects, the db-platform wiki). `apostol-repo-v2` in particular is a mirror — `git pull` only.

**A production project of the ecosystem runs this setup, and the measurements in this skill come
from it.** Ten named agents launched from nine directories (coordinator, backend, db, frontend,
devops, framework, the OCPP server with its own console, QA, a Go gateway, the auditor), a git board
with a validator and a priorities file, per-agent history trees with a `DAY` file, a wiki split by
section, a write barrier per component, one shared briefing, context guard and output filter,
`DECISIONS.md` as the carrier of the owner's word, and a working day opened and closed on command. Components with no obvious
language twin went to the nearest language owner first; `brands/` grew into a named `devops` role,
and `ocpp/` into its own agent, only when their load became constant — exactly as Rule 8
describes.

What that project learned the expensive way, all now rules above: **production changes
everything** — with a live deployment "the database will be rebuilt" is never available, so
migration discipline is a condition of work and an agent reading a neighbour's charter will
inherit their latitude; **the harness itself has a running cost** (Rule 10) — that team's charter
reached 515 lines and the root `CLAUDE.md` 408 before anyone measured what every session was
paying for them, and a fortnight later the root `STATE.md` had grown a 240-line tail of closed
days; **a day ends on the owner's word** (Rule 11) — the seven-step closing was adopted from a
sibling project and caught a wrong production prediction on its first full run;
and **the owner's word travels by record** (Rule 12) — learned three times.
