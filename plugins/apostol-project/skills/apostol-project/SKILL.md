---
name: apostol-project
description: Use when working on any project built on Apostol, Apostol CRM, or db-platform. A short core every role reads — three layers, ecosystem boundaries, the must-know rules, verification — and a route for each of nine roles (SQL, C++ modules, transport, front-end, Go, QA, devops, audit, coordinator) that names the references the role opens: DB patterns, entities, workflow, access control, processes, front-end, install pitfalls, decision rules, subagent briefing, the facts of the 2026-09 inventory. NOT for framework development (use /apostol for that).
allowed-tools: Read
user-invocable: true
---

# /apostol-project — Working with Apostol-based Projects

This file is the **core**: every role reads it whole. Everything else lives in this directory and is opened by your
route. After reading, announce: **"Apostol project context loaded."**

## Your route — open it now

| You are | Route |
|---|---|
| SQL / configuration | [`route-sql.md`](route-sql.md) |
| C++ modules of the CRM stack (AppServer, PGFetch, own Workers) | [`route-cpp-modules.md`](route-cpp-modules.md) |
| C++ transport on bare libapostol, no db-platform | [`route-cpp-transport.md`](route-cpp-transport.md) |
| Front-end | [`route-frontend.md`](route-frontend.md) |
| Go / `/api/v2` behind GatewayAPI | [`route-go.md`](route-go.md) |
| QA / cross-layer acceptance | [`route-qa.md`](route-qa.md) |
| devops / release | [`route-devops.md`](route-devops.md) |
| Audit / review | [`route-audit.md`](route-audit.md) |
| Coordinator (no code) | [`route-coordinator.md`](route-coordinator.md) |

**Every session, first:** your project's `CLAUDE.md` files and `INDEX.md` ([`reading.md`](reading.md) Tier 0). Then open
your route **now**; it names the references to open **when the task needs them** and those to skip. **A task
outside SQL, C++ and the front-end** (shell, compose, hooks, CI, a legal or document audit): this core and
[`verification.md`](verification.md) are enough. **Briefing a subagent** on a task that needs judgement: skill
activation in the first sentence, a reading list, one or two production examples, the anti-patterns for the task, the
verification commands, what you will not take on trust — [`reading.md`](reading.md) § Step 2.

**The specification, where your project carries it** (the Apostol Specification, usually the submodule `docs/spec/`):
the as-built map — Part I `libapostol` and its modules, Part II `db-platform` and API v1, Part III `go-platform` and
API v2, one Part per project — every requirement citing its source line at a pin, every known
defect a row `<CODE>.DEV.nn`. About 2 MB — **read it by the code you touch, never whole**: before changing behaviour,
`python3 docs/spec/tools/where.py <file>[:<line>]` (or a function or route name), then the block it names with its
deviations; a fix of a deviation names its id. Where the file changed after its pin, the code wins. Where to start —
your route.

**Steps keep their numbers** wherever they moved: 1, 2, 3 → `reading.md` · 5, 11, 12 → `processes.md` · 6 →
`db-architecture.md` · 7 → `entity.md` · 8 → `workflow.md` · 9 → `access-control.md` · 10 → `frontend.md` · 13 and the
README rule → `conventions.md` · 14 → `decision-rules.md` · 15 in full → `verification.md` · 16 → `install-pitfalls.md` ·
17 → `facts-2026-09.md` — **read it before trusting a count, version or function claim: its lines override older text;
a project's specification, measured at a later pin, overrides both — at its pins** · the Hall of Shame →
`anti-patterns.md` · the design and this implementation → `design.md` · reports → `report-subsystem.md`.

**After a task, rate the skill**: what got in the way, what is wrong or stale (`file:line` of the truth), what is
superfluous, what you worked out yourself — in your project's feedback file, or as an issue on
`github.com/apostoldevel/claude-plugins`. An editor keeps in this core only what holds for every project and every
role: a role's rule goes to its route, a project's to its `CLAUDE.md`, framework work to `/apostol`.

---
## Three layers, and the names

| Level | Name | What | You |
|---|---|---|---|
| **3 — Configuration** | `configuration/<dbname>/` — `<dbname>` (e.g. `crm`) is the configuration namespace, not a project | the project's business logic: everything that distinguishes one project from another | **write here** |
| **2 — Platform** | **db-platform** (`github.com/apostoldevel/db-platform`) | PL/pgSQL, shared by everyone: auth · OAuth 2.0 · workflow · entity · files (S3) · pub/sub · audit log · notifications · locale · reports · registry · … — 29 modules, 42 `rest.*` dispatchers, ~456 routes (1.2.38) | read only |
| **1 — Transport** | **libapostol** (`github.com/apostoldevel/libapostol`; libdelphi on v1) | C++20 server: HTTP / WebSocket / TLS / epoll, libpq async — like nginx, not part of your project | read only |

**Apostol** is the umbrella name. **Apostol v2** is the current line (C++20, JSON config); v1 (C++14, INI config,
libdelphi) still runs in production. **Apostol CRM** is the template scaffold new projects copy — not a product.

A configuration **extends** the platform (`AddEntity()` / `AddClass()` / `AddDefaultMethods()` / `AddEvent()` /
`RegisterRoute()`) and consumes it through `db.*`, `kernel.*`, `api.*` and `daemon.*`; it never edits it. The platform
gives a complete backend out of the box — **if you are about to write something it may already do, stop and read it
first** (`decision-rules.md`). The version you stand on: `cat <sql>/platform/VERSION`, nothing else
(`facts-2026-09.md`). This skill describes the PostgreSQL implementation of an older design; three boundaries fixed by
the platform's author are not re-argued in project work — [`design.md`](design.md).

---
## Must-know — the short list (the full Hall of Shame is in [`anti-patterns.md`](anti-patterns.md))

Most rework here comes from **solving a problem the platform already solves**, or from not reading it first:

1. **Never edit shared code** — `sql/platform/`, `src/lib/libapostol/` (`src/lib/delphi/` on v1), upstream module
   sources, any local mirror of upstream (e.g. `apostol-repo-v2/`, `db/platform/`). A fix there is framework work — `/apostol`.
   Mirrors lag `origin`: read the project's submodule at its pin. Upstream repositories are public — no project task
   numbers or project details in their code comments and commit messages.
2. **Never invent** routes, fields or types — read the entity's `rest.sql`, `view.sql`, `table.sql`. Query parameters
   are the platform's JSON `search` / `filter` / `orderby`, not `?status=active`. Before adding an endpoint, try the
   42 dispatchers / ~456 routes that exist: `/list` + filters, or an `observer` hook.
3. **Every `Object<Entity>` has its `Access<Entity>`**, and `list_` / `count_` go through
   `api.sql('kernel', 'Object<Entity>', …)`. A missing pair, or schema `api`, raises no error — access control silently
   disappears (the 2026-09 inventory found four of seven projects on schema `api`: `grep -rn "api.sql('api'" sql/configuration/`).
4. **Changing a function's parameters or OUT columns creates an overload.** The old form is dropped **in a patch**, never
   in the re-run files (`routine.sql`, `api.sql`, `view.sql`); details in `anti-patterns.md`. A trigger on an existing
   table goes in a patch too — `--update` never runs `table.sql` (`db-architecture.md`). A form a running binary still
   calls stays callable through the rollout (`db-architecture.md` § The previous binary).
5. **Crypto, password checks and cron do not go into PL/pgSQL** — a C++ process, OAuth2 / AuthServer, the platform
   `scheduler` + `job`.
6. **A custom action needs a `'ChangeObjectState();'` event**; event order is parent first, except delete / drop — entity first.
7. **State, method and action codes via `GetState` / `GetMethod` / `GetAction`**, never UUIDs; when a class has several
   states of one type, compare the state **code**, not `IsEnabled`.
8. **Tokens are cookie-only** — no `localStorage`, no refresh logic in JS behind AppServer / GatewayAPI; guest routes are
   called anonymously, never with `client_credentials` from the browser.
9. **A slow `list` / `count`** — suspect the known planner shape (`anti-patterns.md`, the callout) before a bespoke fix;
   upstream materialises the access set since 1.2.17 and joins it as a semi-join since 1.2.34; a lower pin has no fix
   (`grep -c 'AS MATERIALIZED' sql/platform/api/api.sql`; the semi-join: `grep -c 'IN (SELECT object FROM aou)'`).
10. **Keep `INDEX.md` in sync** after adding an entity (`/index`, stale-scan mode).

---

## Step 4 — Ecosystem Boundaries

You write **only** in `configuration/<dbname>/`, `conf/`, project-specific C++ processes (e.g. `processes/NMEA/`) and
`src/app/main.cpp`. Everything else is shared: `sql/platform/` (db-platform), `src/lib/libapostol/` (v1:
`src/lib/delphi/`), the module submodules under `src/modules/` and `src/processes/` (AppServer, AuthServer, WebSocketAPI,
PGHTTP, FileServer, WebServer, PGFetch, PGFile, MessageServer, TaskScheduler, ReportServer, StreamServer, Replication —
`processes.md`). The module set differs per project (`.gitmodules`).

Two layouts (surveyed 30.09.2026): **v2** keeps SQL in a sibling repo `<project>/db/sql/`, `sql/platform` and the C++
modules are git submodules; **v1** keeps SQL under `backend/db/sql/`, `sql/platform` is a gitignored nested clone. Some v1
clones still point at an older upstream — `git remote -v`. The project's root `CLAUDE.md` says which layout it has.

| Symptom | Fix belongs in | Reaches |
|---|---|---|
| Business logic, wrong data | `configuration/<dbname>/` | this project |
| A project-specific C++ module / process | `src/processes/<Name>/` of the project | this project |
| REST dispatch routing, access control | `db-platform` | every project: push upstream, then `--update` everywhere |
| Auth flow, cookies, JWT | the AuthServer module repo | every project using the module |
| HTTP parsing, event loop, PG pool | `libapostol` | every Apostol project: push upstream, rebuild everywhere |

A fix in shared code: **stop project work** and use `/apostol`.

**Authentication in C++, authorization in SQL** — the rule is about data. A route with no data behind it (a command
that goes on to a device, not into a view) has nothing in SQL to filter; checking the token's **audience** (`aud`) on it
in C++ does not break the rule — an audience is not a role. The business decision still lives in SQL.

---
## Step 15 — Verification Before Completion

**Every role reads [`verification.md`](verification.md) before claiming done** — the techniques with the cases that taught
them. The digest, one line each:

1. **Both directions.** A check must pass, and must **fail** on a deliberately broken input; a skipped test proves nothing
   until you have seen it bite, and a gate counts a skip as a failure. The breaking action is in force before the reaction
   is measured.
2. **Green for the wrong reason:** zero rows, `bool_and` over NULL, a jsonb string compared as text, a row the statement's
   snapshot cannot see.
3. **Mutate the guard, count the reds.** A mutant that dies only on another test's tag is not pinned by yours; a mutant
   per case, not per code; a run that could not test exits as such, never as red.
4. **"It did NOT happen" needs proof the branch ran** — a counter, a canary, the allowed role passing. An answer through
   `http.fetch` comes later, via PGFetch, not in the REST response.
5. **The refusal's identifier, then the guard.** `ERR-400-001/-002/-003` is one family raised by many guards: name the
   guard after an A/B, assert "refused and state unchanged". A status code alone is not an answer; error texts are localized.
6. **Look before the check; count the paths, fields and roads yourself** — sibling routes, the generic object routes,
   `/api/v2`, PGHTTP. An outcome arriving by two roads is tested in every order. Measure the path the client really
   takes (cookies vs Bearer, the real role).
7. **Fixtures explicit, real and isolated** — never "the first suitable row"; name the base the test ran on.
8. **Gate on a throwaway fresh install**; a patch on a copy of the previous release with data; before/after by two pins;
   re-measure on volume after narrowing by access.
9. **Probe inside `BEGIN … ROLLBACK`** and count side effects on your own rows only.
10. **A `STABLE` function sees its caller's snapshot**; `now()` is constant within a transaction; a race needs two sessions
    with real commits, ordered by a lock, not by `sleep`; `pg_notify` is delivered at commit; PL/pgSQL resolves names at
    first run — prove a call by running it, under a session.
11. **Build from the pins**; stub missing credentials; alternate the order in A/B; wait for `rc=`, not for a wrapper. A
    mutant of code a job or a live binary runs is committed code — only on a throwaway base, on an explicit word; a fake
    peer reproduces the real failure shape.
12. **An empty search proves nothing until a control hits; never print a secret to find it.**
13. **Comments, runbooks and subagent reports are claims** — check against the code, re-run; "could not reproduce" is
    part of a finding.
14. **Put the guard in the instrument, not in the reader.**

Don't claim "done" without running these. **Before committing**, every role: shared code touched — stop, it goes
upstream first (Must-know 1); the claim rests on a run, never on "should work". The SQL checklist is in `route-sql.md`. SQL layer — the `psql` / `curl` checks: [`conventions.md`](conventions.md),
§ Verification commands.
