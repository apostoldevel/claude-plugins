---
name: apostol-project
description: Use when working on any project built on Apostol, Apostol CRM, or db-platform (Apostol CSMS, Ship Safety ERP, Campus CORS, PlugMe, CopyFrog, Talking-To-AI, DEBT-Master, etc.). Provides everything needed to work with the project — three-layer architecture, the design vs this PostgreSQL implementation of it, ecosystem boundaries, a reading route for each of nine roles (SQL, C++, transport, front-end, Go, QA, devops, audit, coordinator), module capabilities, database patterns, access control, workflow, anti-patterns, subagent briefing rules, verification techniques, and the facts measured by the 2026-09 inventory. NOT for framework development (use /apostol for that).
allowed-tools: Read
user-invocable: true
---

# /apostol-project — Working with Apostol-based Projects

This skill gives everything an agent needs to work on a project built on the Apostol ecosystem. It answers: what's available out of the box, where to write code, how things connect, what patterns to follow, what anti-patterns to avoid, and what to read first.

After reading, announce: **"Apostol project context loaded."**

---

## Read by role — nine roles load this skill

This file is the **core**. **Every role** reads: “The design, and this implementation of it”, the three layers,
Naming, **Must-know**, **Step 4** (boundaries) and **Step 15** (verification — the same for every layer). The rest
lives in references in this directory: open one when the task needs it.

| You are | Also in the core | Open when the task needs it | Skip unless asked |
|---|---|---|---|
| **SQL / configuration** (`configuration/<dbname>/`) | Step 14 | `reading.md` Tiers 0–1 · `db-architecture.md` · `entity.md` · `workflow.md` · `access-control.md` · `anti-patterns.md` · `facts-2026-09.md` · before commit `conventions.md` · fresh base `install-pitfalls.md` | `frontend.md`; `processes.md` unless you touch `http` / PGFetch / jobs |
| **C++ modules of the CRM stack** (AppServer, PGFetch, own Workers / processes) | Step 14 | `processes.md` · `reading.md` Tier 2 · `anti-patterns.md` (Process) | entity, workflow, front-end, conventions |
| **C++ transport without db-platform** (own processes on bare libapostol, e.g. an OCPP Central System) | — | libapostol wiki `Architecture.md`, `Configuration.md` (`reading.md` Tier 2); `processes.md` only for PgPool and the `module.<Name>.enable` key — its modules are the CRM stack's, not a bare `CustomProcess` | Steps 6–10, 13 |
| **Front-end** | — | `frontend.md` · `access-control.md` (what the barrier does to your data) · `anti-patterns.md` (Frontend) | Steps 6–8, 11–13 |
| **Go / `/api/v2` behind GatewayAPI** (where a project has one) | — | `frontend.md` (tokens, cookies) · `access-control.md` (access is decided inside `api.*`) · `facts-2026-09.md` | entity, workflow, conventions |
| **QA / cross-layer acceptance** | — | `processes.md` (PGFetch, PgPool, background paths) · `access-control.md` (ACL bits, for mutation checks) · `install-pitfalls.md` · `facts-2026-09.md` | entity, workflow, conventions |
| **devops / release** | — | `install-pitfalls.md` (install, `--init`, export by pins) · `processes.md` (which key starts what) | Steps 6–10, 13 |
| **Audit / review** | Step 14 | `anti-patterns.md` · `access-control.md` · `facts-2026-09.md`; a code review → `/apostol-review` | — |
| **Coordinator** | Steps 2, 14 | `reading.md` (what goes into a brief) | the implementation references |

### Where each step lives (split 28.09 and 30.09.2026)

Moved steps keep their numbers and a heading here, so "see Step 9" still resolves. All files sit in this directory:
`anti-patterns.md` — the Hall of Shame, planner callout · `reading.md` — Steps 1, 3 (what to read, wiki pages, entity
files) · `processes.md` — Steps 5, 11, 12 · `db-architecture.md` — 6, patches, triggers on platform tables · `entity.md` — 7 · `workflow.md` — 8 ·
`access-control.md` — 9 · `frontend.md` — 10 · `conventions.md` — 13, SQL checks, the README rule ·
`install-pitfalls.md` — 16 · `facts-2026-09.md` — 17, **read it before trusting a count, version or function claim:
its lines override older text** · `report-subsystem.md` — reports.

**After closing a card, rate the skill** (owner's word 28.09, both teams): what got in the way, what is wrong or stale
(`file:line` of the truth), what is superfluous, what you worked out yourself. SERP —
`ship-safety/v2/docs/wiki/common/apostol-project-skill-feedback.md`; CSMS —
`apostol-csms/docs/wiki/common/apostol-project-skill-feedback.md`. Whoever edits this skill reads both, and keeps here
only what holds on **every** project: one project's rule goes to that project's `CLAUDE.md` or wiki, framework
development goes to `/apostol`.

## The design, and this implementation of it

This skill describes **one implementation** of the Apostol platform — the PostgreSQL one (db-platform
1.2.x + libapostol). The design itself is older than PostgreSQL here (its first execution environment
was Oracle, 2010–2019) and is written down separately, environment-free:

- `~/DevSrc/Projects/apostol-csms/docs/clean-architecture/platform-concept.md` — the design: objects in a class
  tree, lifecycle as data, one universal executor, context “who / as whom / where / which workplace /
  which operating date”, three-dimensional access, a trace of every action with delivery, atomic action.
- `…/design-vs-implementation.md` — what stayed identical across Oracle and PostgreSQL (= the design) and
  what each environment dictated (= implementation).
- `…/kernel-notes.md` — the 17 places where this implementation strains against the design.

**Three boundaries fixed by the owner (12.09.2026) — do not re-argue them in project work:**

| First-generation slogan | Design (keep) | Implementation (this skill) |
|---|---|---|
| “One request — one transaction” | the **action** is atomic: object, state, history, trace, money in one commit | the unit of atomicity is the whole HTTP request, batch arrays included, session check included |
| “The database is an active participant” | the **system** initiates outbound work from its own data | the initiator is PostgreSQL itself: triggers → `pg_notify` → a C++ process with a polling fallback |
| “Behaviour as data, changed at runtime” | **the automaton and the rights are data** (states, methods, transitions, ACU/AMU, routes, registry) | reaction code is `EXECUTE`d text in `db.event.text`; in the design reaction code may be code bound to (class, action) by reference |

Why this matters for configuration work: when a platform construct fights you (a right you cannot
express, a state that does not change, a filter that silently disappears), check the design first.
If the design requires it and the implementation lacks it, that is framework work (`/apostol`), not
a reason to bend the configuration. If the design does not require it, you are free.

---
## The Three-Layer Architecture (Mental Model — Read First)

Apostol is a three-layer construction kit. The same stack runs seven (and counting) production projects — only the top layer changes.

| Level | What | You |
|---|---|---|
| **3 — Configuration** | YOUR project: Apostol CSMS · Campus CORS · Talking-To-AI · DEBT-Master · CopyFrog · PlugMe · Ship Safety ERP · … — the unique business logic; everything that distinguishes one project from another | **write here** |
| **2 — Platform** (db-platform) | shared by everyone, 100 % reuse: auth · OAuth 2.0 · workflow · entity · files (S3) · pub/sub · audit log · notifications · localization · reports · registry · KLADR · … — 28 modules, 41 `rest.*` dispatchers, ~450 routes (1.2.31) | read only — not one line by configuration projects |
| **1 — Transport** (libapostol; libdelphi on v1) | C++ server: HTTP / WebSocket / TLS / epoll, libpq async, one epoll loop — like nginx or PostgreSQL itself, not part of your project | read only |

Level 3 **extends** level 2 and never modifies it.

**The contract:**
- Configuration projects **extend** the platform via `AddEntity()`/`AddClass()`/`AddDefaultMethods()`/`AddEvent()`/`RegisterRoute()`. They **never** modify platform code.
- The platform is consumed via well-defined APIs: `db.*` tables, `kernel.*` functions, `api.*` views/wrappers, `daemon.*` interface.
- 28 platform modules (1.2.31; `gateway` joined 16.09.2026) give a **complete** production backend out of the box: REST API, auth, RBAC, files+S3, pub/sub, notifications, reports, localization, audit. **Nothing is missing** for a typical CRM-style project.
- A module written for one project (e.g. Stripe for CopyFrog) drops into another (Talking-To-AI, DEBT-Master) without modification — the only file that ever changes per-project is `configuration/<dbname>/`.

**Which platform you stand on:** `cat <sql>/platform/VERSION` — the only reliable version string (the repository
carries a single tag, `v1.0.0`, so `git describe` says nothing). Pins across the ecosystem run from 1.1.4a to 1.2.31
(30.09.2026); counts and function claims in this skill are measured on the version named next to them.

**Implication for the agent:** if you find yourself writing code that re-implements something the platform already provides — **stop and read the platform docs first**. The platform is far richer than it looks at first glance.

---
## Naming Disambiguation

Confusion here causes bad work. Get this straight before writing anything.

| Term | What it actually is |
|------|---------------------|
| **Apostol** | The whole ecosystem (framework + platform + projects). Casual umbrella name. |
| **libapostol** (a.k.a. **A-POST-OL**) | The Level-1 C++20 framework: HTTP/WebSocket/TLS/epoll/libpq async. One repo: `github.com/apostoldevel/libapostol`. |
| **db-platform** | The Level-2 PostgreSQL framework: 28 PL/pgSQL modules at 1.2.31 (`mq` added in 1.2.17, `gateway` on 16.09.2026), 41 `rest.*` dispatchers with ~450 routes, ~52-page wiki (**in the mirror `~/DevSrc/Projects/db/platform/wiki/` only** — a separate repo there, last changed 23.08.2026, so it lags the code; a project's `sql/platform/` ships no `wiki/`). One repo: `github.com/apostoldevel/db-platform`. |
| **Apostol v2** | The current major version of the framework (C++20, JSON config, libapostol). v1 is C++14, INI config, on libdelphi — legacy, **but still in production**: plugme, copyfrog, debt-master, campus/cors, talking-to-ai (30.09.2026). The C++ parts of this skill describe v2. |
| **Apostol CRM** | A **template project** that puts libapostol + db-platform together with a minimal scaffold. NOT itself a product. New projects copy this scaffold. |
| **Apostol CSMS** / **Ship Safety ERP** / **CopyFrog** / **PlugMe** / etc. | **Projects** built on the platform. Each has its own `configuration/<dbname>/` directory and adds project-specific C++ modules/processes. |
| **`<dbname>`** (lowercase: `csms`, `ship_safety`, `debt`, …) | The configuration namespace inside a project (`sql/configuration/<dbname>/`). NOT a separate project. |

**`apostol-csms`** as a reference repo: this is the most production-grade codebase in the ecosystem. When the wiki tutorial doesn't show a real-world pattern, look at `apostol-csms` for a production answer. It is an **example, not the norm**: a rule comes from the platform or from PostgreSQL, and a decision recorded in one project's `DECISIONS.md` binds that project only.

---
## Must-know — the short list (the full Hall of Shame is in [`anti-patterns.md`](anti-patterns.md))

Most rework here comes from **solving a problem the platform already solves**, or from not reading it first:

1. **Never edit shared code** — `sql/platform/`, `src/lib/libapostol/` (`src/lib/delphi/` on v1), upstream module
   sources, the mirrors in `~/DevSrc/Projects/` (`apostol-repo-v2/`, `db/platform/`). A fix there is framework work — `/apostol`.
2. **Never invent** routes, fields or types — read the entity's `rest.sql`, `view.sql`, `table.sql`. Query parameters
   are the platform's JSON `search` / `filter` / `orderby`, not `?status=active`. Before adding an endpoint, try the
   41 dispatchers / ~450 routes that exist: `/list` + filters, or an `observer` hook.
3. **Every `Object<Entity>` has its `Access<Entity>`**, and `list_` / `count_` go through
   `api.sql('kernel', 'Object<Entity>', …)`. A missing pair, or schema `api`, raises no error — access control silently
   disappears (the 2026-09 inventory found four of seven projects on schema `api`: `grep -rn "api.sql('api'" sql/configuration/`).
4. **Changing a function's parameters or OUT columns creates an overload.** The old form is dropped **in a patch**, never
   in the re-run files (`routine.sql`, `api.sql`, `view.sql`); details in `anti-patterns.md`. A trigger on an existing
   table goes in a patch too — `--update` never runs `table.sql` (`db-architecture.md`).
5. **Crypto, password checks and cron do not go into PL/pgSQL** — a C++ process, OAuth2 / AuthServer, the platform
   `scheduler` + `job`.
6. **A custom action needs a `'ChangeObjectState();'` event**; event order is parent first, except delete / drop — entity first.
7. **State, method and action codes via `GetState` / `GetMethod` / `GetAction`**, never UUIDs; when a class has several
   states of one type, compare the state **code**, not `IsEnabled`.
8. **Tokens are cookie-only** — no `localStorage`, no refresh logic in JS behind AppServer / GatewayAPI; guest routes are
   called anonymously, never with `client_credentials` from the browser.
9. **A slow `list` / `count`** — suspect the known planner shape (`anti-patterns.md`, the callout) before a bespoke fix;
   upstream materialises the access set since 1.2.20, a lower pin has no fix.
10. **Keep `INDEX.md` in sync** after adding an entity (`/index`, stale-scan mode).

---

## Step 1 — Mandatory Reading at Session Start

**Moved to [`reading.md`](reading.md)** — reading tiers 0–3 by depth of the task (see Read by role at the top).

## Step 2 — Subagent Briefing Rules

When delegating work to a subagent in an Apostol-based project, **only two formats are acceptable**:

### Format 1 — Trivial rote task with a precise plan

`mkdir`, `cp template`, `sed rebrand`, smoke test, `grep` lookup. The subagent does not need platform context. Brief: 2–3 sentences, exact commands.

### Format 2 — Substantive task requiring judgement

Entity creation, workflow design, REST dispatcher, business logic, refactor, debugging beyond a one-line fix. The brief **must include all of these**:

1. **Skill activation** in the first sentence:
   - `Activate skill /apostol-project before any work.`
   (For framework dev — never project work — use `/apostol`.)

2. **Mandatory reading list** specific to the task:
   - For entity creation: list the relevant 8 wiki pages (70-76, 13, 04, 12, 64) + the 2 production entity examples ([`reading.md`](reading.md), Tier 1).
   - For C++ module work: libapostol Architecture + Configuration + the specific module README.
   - For workflow customization: 04-Workflow + 74-Workflow-Customization + 76-Event-Handler-Guide.

3. **One or two concrete production examples** (from `apostol-csms` or the project itself) to imitate. Don't make the subagent search.

4. **Explicit anti-patterns checklist** for the task (relevant subset of [`anti-patterns.md`](anti-patterns.md)).

5. **Verification commands** the subagent should run before claiming completion (e.g. `./runme.sh --update`, `\df WriteToEventLog`, `curl /api/v1/<entity>/list`).

Why, and what to ban from a brief — [`reading.md`](reading.md), § Step 2 details.

---

## Step 3 — How the Framework Works (Read Before You Write)

**RULE: Never guess. Never invent fields, endpoints, or parameters. Read the source.** Wiki → `INDEX.md` → entity
source: **moved to [`reading.md`](reading.md)**.

---

## Step 4 — Ecosystem Boundaries

### What is shared vs what is yours

Two generations live side by side (surveyed 30.09.2026). **v2** (apostol-csms, ship-safety/v2): SQL in a sibling
repo `<project>/db/`, `sql/platform` and the C++ modules are git submodules, the transport is libapostol. **v1**
(plugme, copyfrog, debt-master, campus/cors, talking-to-ai): SQL under `backend/db/`, `sql/platform` is a gitignored
nested clone, the C++ side is Apostol v1 on libdelphi. Upstream is `github.com/apostoldevel` (a few v1 clones still
point at `ufocomp`). The project's root `CLAUDE.md` says which layout it has. The tree below is v2:

```
project/
├── backend/
│   ├── src/
│   │   ├── app/main.cpp                ← PROJECT: entry point (1 file)
│   │   ├── lib/libapostol/             ← SHARED: C++20 framework (submodule; v1: lib/delphi/)
│   │   ├── modules/Workers/            ← SHARED (submodules from GitHub): AppServer (REST, /api/v1) · AuthServer
│   │   │                                  (OAuth2 + JWT) · WebSocketAPI (JSON-RPC, pub/sub) · PGHTTP (HTTP → PL/pgSQL,
│   │   │                                  webhooks) · FileServer (files, JWT) · WebServer (static, Swagger UI)
│   │   ├── modules/Helpers/            ← SHARED: PGFetch (LISTEN → outbound HTTP) · PGFile (LISTEN → filesystem)
│   │   └── processes/                  ← SHARED: MessageServer (SMTP / FCM / push) · TaskScheduler (jobs) ·
│   │                                      ReportServer · StreamServer (UDP telemetry) · Replication (shore↔edge)
│   ├── conf/                           ← PROJECT: default.json (modules, processes, DB), default.<profile>.json,
│   │                                      oauth2/ (providers), sites/ (per-hostname routing)
│   └── configure                       ← downloads / pins shared components
└── db/sql/                             ← v1: backend/db/sql/
    ├── platform/                       ← SHARED: db-platform (DO NOT EDIT)
    └── configuration/<dbname>/         ← PROJECT: all business logic lives here
```

The module set differs per project (`.gitmodules`, `src/modules/`) — the tree is the common set, not a promise.

**Rule:** You write code ONLY in `configuration/<dbname>/`, `conf/`, project-specific C++ processes (e.g. `processes/NMEA/`), and `src/app/main.cpp`. Everything else is shared infrastructure.

**Authentication in C++, authorization in SQL** — the rule is about data. A route with no data behind it (a command
that goes on to a device, not into a view) has nothing in SQL to filter; checking the token's **audience** (`aud`) on it
in C++ does not break the rule — an audience is not a role. The business decision still lives in SQL.

### Impact of changes

| What you change | Impact | Action required |
|-----------------|--------|-----------------|
| `configuration/<dbname>/` | This project only | Standard PR |
| Project-specific C++ module/process (e.g. `processes/NMEA/`) | This project only | Standard PR |
| Shared C++ module code (AppServer, etc.) | All projects using this module | Push upstream first |
| `db-platform` code | All projects using db-platform | Push upstream, then `--update` everywhere |
| `libapostol` code | All Apostol projects | Push upstream, rebuild everywhere |

### Where does the fix belong?

| Symptom | Fix location |
|---------|--------------|
| Bug in business logic, wrong data | `configuration/<dbname>/` (this project) |
| Bug in REST dispatch routing, access control | `db-platform` (shared) |
| Bug in auth flow, cookies, JWT | C++ AuthServer module repo (shared) |
| Bug in HTTP parsing, event loop, PG pool | `libapostol` (shared, affects ALL) |

If a fix is in shared code, **stop project work** and use `/apostol` skill for framework work.

---

## Step 5 — Module Pairing & LISTEN/NOTIFY

**Moved to [`processes.md`](processes.md).**

## Step 6 — Database Architecture

**Moved to [`db-architecture.md`](db-architecture.md).**

## Step 7 — Entity Creation (Production-Ready Patterns)

**Moved to [`entity.md`](entity.md).**

## Step 8 — Workflow Customization

**Moved to [`workflow.md`](workflow.md).**

## Step 9 — Access Control (full picture)

**Moved to [`access-control.md`](access-control.md).**

## Step 10 — Frontend Integration

**Moved to [`frontend.md`](frontend.md).**

## Step 11 — Process Model & Runtime

**Moved to [`processes.md`](processes.md).**

## Step 12 — Replication (Distributed Deployment)

**Moved to [`processes.md`](processes.md).**

## Step 13 — Strict Conventions Checklist

**Moved to [`conventions.md`](conventions.md)** — the final pass before committing, together with the README writing rule (see Read by role at the top).

---

## Step 14 — Decision Rules

When solving a problem or implementing a feature, ask in this order:

1. **Does the platform already provide this?**
   - Auth/OAuth2/JWT → AuthServer + `admin`/`oauth2`
   - REST API → AppServer + `daemon`/`rest`/`api`
   - Real-time events → WebSocketAPI + `observer`
   - Background jobs → TaskScheduler + `api.job` + `scheduler` module
   - Email/push/SMS → MessageServer + `notice`/`message`
   - Files → FileServer + PGFile + `file` (S3-backed)
   - External HTTP from DB → PGFetch + `http`
   - Custom HTTP routes (webhooks) → PGHTTP + `http`
   - State machine → platform `workflow`
   - Access control → ACU/AMU/AOU + Access views
   - Localization → `locale` module + `db.<entity>_text` tables
   - Reports → ReportServer + `report` module
   - Audit log → `WriteToEventLog(...)` + `db.log`
   - Pub/sub → observer + 7 publishers + LISTEN/NOTIFY

2. **Am I editing the right layer?**
   - Business logic → `configuration/<dbname>/` (this project)
   - Project-specific C++ process → `backend/src/processes/<Name>/` (this project)
   - Anything in `db/sql/platform/` → STOP. Use `/apostol` skill for framework work.
   - Anything in `src/lib/libapostol/` or upstream module sources → STOP.

3. **Does INDEX.md describe what I need?**
   - Always check the project's DB-layer INDEX.md (`backend/db/INDEX.md` or a top-level `db/INDEX.md` — [`reading.md`](reading.md), Tier 0) and `configuration/<dbname>/INDEX.md` before exploring code.

4. **Has someone already solved this in another configuration project?**
   - Look at `apostol-csms` first. If there's a similar entity (client/charge_point/payment/etc.), copy its structure — as an example, not as a rule.

5. **Will my approach pass the Hall of Shame?**
   - Run through [`anti-patterns.md`](anti-patterns.md). If your code matches a ❌ row, change the approach.

6. **Is there a companion skill that automates this?**
   - Creating a new entity (Document or Reference) → invoke **`/new-db-entity`** for the full 7-file scaffold wired into create.psql/update.psql.
   - Generating `INDEX.md` for an entity / module → invoke **`/index`** for the platform-standard format.
   - Code review or audit of an Apostol project → invoke **`/apostol-review`** (security, dead code, duplication with libapostol, hard-coded values).
   - Row-level access (`Access<Entity>` / `api.sql()`) behaving oddly, or the project still on the old static AOU model → invoke **`/apostol-new-aou`** (migration to the dynamic mechanism, drop patch, verification protocol, pre-deployment data audit).
   - Working on the framework itself (libapostol, db-platform, shared modules) → STOP project work and invoke **`/apostol`** (framework-development skill, separate scope).

---
## Step 15 — Verification Before Completion

### How to be sure — the techniques, not the knowledge

Collected 2026-08-24 from a day where **every finding came from a technique, not from knowing the
architecture**. This section is deliberately about *checking*, because the rest of this skill is
about writing.

**Run both directions, always.** A check exercised only against a healthy input is not a check — it
only shows that it does not crash. It must pass, and it must **fail** on a deliberately broken
input. Three ways this bites in one day: a grep over a bundle that reported "fixed" for both
builds; an acceptance criterion that missed bare text because it looked for quotes; four convention
tests that were green because they iterated over zero rows.

**A test that skips is not exempt** — prove it bites before you trust the skip.

**Look at what stands BEFORE the check, not at what the check verifies.** A CSRF gate on an OAuth
callback was correct and complete — and the error branch returned earlier, so it was never reached.
Reviewing "does the gate work" would never have found it.

**Compare the comment with the code.** "The check is unconditional" over a conditional check;
`tests/README.md` that spent three days discouraging a working path because of a defect that had
been retracted. A document promising a guarantee that does not exist is worse than no document.

**Count the paths yourself.** An author wrote "both branches"; there were three. "Both" over three
paths is the ordinary place where one stays forgotten.

**Look at the identifier of the refusal, not at the fact of refusal.** `ERR-400-001` versus
`ERR-400-032` separated an access barrier from a workflow rule; taking "it refused" at face value
nearly produced a wrong policy.

**When credentials are missing, build a stub instead of waiting.** A cookie-clearing branch that
"needs a real token exchange" turned out to be reachable through a third code path that touches
neither the database nor the provider.

**"Could not reproduce" is part of a finding, not its absence.** It narrows the risk and names the
boundary; "did not check" leaves a hole later mistaken for a check.

**In A/B measurement, alternate the order.** The first run in a session is slower regardless of
mode; a "6% win" turned out to be warm-up handed to whichever mode went first.

**Probe hypotheses inside a transaction with `ROLLBACK`**, and verify the counters afterwards — on
a shared stand someone else is working next to you.

**Never put two dependent calls in one `SELECT`.** Evaluation order in a select list is not
guaranteed: `GetProvider('x')` next to `AddProvider('x')` returns null. It works nine times out of
ten and fails in the installation script.

**And the meta-lesson: written knowledge does not protect you from a trap.** An agent stepped into
two traps he had personally documented an hour earlier. What worked was **a precondition check
inside the tool** — "did the stub actually come up?", "is this the binary I just built?". Put the
guard in the instrument, not in the reader.

**More techniques, from the ratings of 28–29.09.2026** (CSMS and SERP, every layer):

- **"Nothing was created" needs proof that the event reached the branch.** With an asynchronous answer an empty table
  proves nothing: `http.fetch` returns at once, the far end's answer comes later via PGFetch — a callback and an event,
  not the REST response.
- **After an exception, look after the next step.** A call that throws rolls back its own work; claim "no side effects"
  after the following step, not right after the refusal.
- **Compare the state code, not the state type.** `IsEnabled` is true for every state of type `enabled`
  (`in_progress`, `failed`, …) — "enabled" is not "in work".
- **Error texts are localized.** `RegisterError` keeps a message per locale and returns the session's
  (`platform/error/routine.sql:189`, `:143`); the wording of `PG_EXCEPTION_CONTEXT` follows `lc_messages`. Check the
  error code and the invariant part (the quoted key), never an English phrase.
- **A status code alone is not an answer.** A module can return HTTP 200 with an error in the body; check the body and
  which module answered (`X-Request-Id`, headers).
- **A refusal that must not need the database — test it on a dead database port.** If it still refuses, it refused
  before the database.
- **Build what you accept, from the pins** — not from a shared working tree: `git archive <sha>` of the tree plus
  `git archive <pin>` of each submodule. Untracked files (per-environment bundles) stay out — add them by hand.



Don't claim "done" without running these.

SQL layer — the `psql` / `curl` checks after install, a new entity and a workflow change: [`conventions.md`](conventions.md), § Verification commands.

### Before committing

- [ ] `./runme.sh --update` runs cleanly (no errors, no warnings).
- [ ] A changed signature or a new trigger on an existing table → the patch is written **and applied** (`--patch`); `--update` alone leaves the base in the "not unique" state.
- [ ] No anti-patterns from [`anti-patterns.md`](anti-patterns.md).
- [ ] `INDEX.md` updated for the new entity.
- [ ] If anything in shared layer was touched: STOP, push upstream first.
- [ ] Evidence-based completion claim — never "should work" or "looks right". Run it.

---

## Writing Rule — README files

**Moved to [`conventions.md`](conventions.md)** — the Apostol CRM footnote for any README that mentions it.

## Step 16 — Pitfalls discovered during live install

**Moved to [`install-pitfalls.md`](install-pitfalls.md).**

## Step 17 — Facts established by the 2026-09 inventory (read before trusting older text)

**Moved to [`facts-2026-09.md`](facts-2026-09.md).**

## TL;DR for the impatient agent

The ten rules of **Must-know** above, plus:

1. **Three layers:** libapostol (C++; libdelphi on v1) → db-platform (PostgreSQL, 28 modules at 1.2.31) → configuration (your project). You write only in the top layer.
2. **Read first, write second.** Wiki + INDEX.md + entity sources before code. Skipping reading = anti-patterns = rework.
3. **`WriteToEventLog` 6-arg `(pType, pCode, pScope, pEvent, pText, pObject)`** is the canonical form. Wrappers exist (4-arg, 5-arg) but production code always uses 6-arg with explicit scope.
4. **`gen_kernel_uuid()` for primary keys**, never `gen_random_uuid()` directly.
5. **`StreamServer` is a Worker Module** despite living in `src/processes/`. Register in `Workers.hpp` via `module_manager().add_module()`, not `add_custom_process()`. Same applies to anything deriving from `StreamServer`/`PgStreamServer`.
6. **Areas are not seeded** — they're created by lifecycle event handlers of the entity that owns them (in `apostol-csms`, `CreateTenant` creates the matching area; `tenant.code = area.code`). Don't try to pre-create them in `FillDataBase`.
7. **Subagents need full briefing.** Skill activation + reading list + concrete examples + anti-patterns. Otherwise they work blind. **Read by role** at the top says which part of this skill is yours.
8. **Verify before claiming done.** `\df`, smoke `curl`, evidence — not "should work".
9. **Know the design from the implementation.** `platform-concept.md` says what the platform *is*; this skill says how PostgreSQL *does* it today, with the three owner-fixed boundaries in the section “The design, and this implementation of it”.
