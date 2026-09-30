<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. Split verbatim from SKILL.md on 30.09.2026 (owner word: CSMS DECISIONS.md:8016); later corrections are listed in apostol-csms/audit/work/apostol-project-skill/changes.md. -->
## Step 1 — Mandatory Reading at Session Start

Reading is **task-tiered**. The deeper the work, the more you must read first. Skipping reading is the single largest cause of low-quality output in this ecosystem.

### Tier 0 — Every session, before any other tool call

```
<project>/CLAUDE.md                                  — project overview (root, if exists)
<project>/backend/CLAUDE.md                          — C++ layer guide (build, modules, request flow)
<project>/backend/db/CLAUDE.md                       — DB coding conventions, commands, REST patterns
<project>/backend/db/INDEX.md                        — DB layer map (entities, modules, relationships)
<project>/backend/db/sql/configuration/<dbname>/INDEX.md  — Configuration entity tree
```

**Don't assume `backend/db/` blindly — check for a top-level `<project>/db/` first.**
Two layouts live side by side (surveyed 30.09.2026): the v2 projects keep SQL in a sibling
repo `<project>/db/` (apostol-csms, ship-safety/v2 — `db/CLAUDE.md`, `db/INDEX.md`,
`db/sql/configuration/<dbname>/INDEX.md`); the v1 projects keep it under `backend/db/` (plugme,
copyfrog, debt-master, campus/cors, talking-to-ai); others differ again (apostol-arb: `crm/db/`).
A project's own root `CLAUDE.md` always says which layout is current — read that first.

### Tier 1 — Before creating, modifying, or reviewing any entity

The platform's entity system has its own contracts. Skipping any of these reads guarantees anti-patterns in the output.

> **The wiki below lags the code.** It lives only in the mirror `~/DevSrc/Projects/db/platform/wiki/` — a separate git repo inside the mirror, in no project's `sql/platform/`. Its last change is 23.08.2026, while the mirror's code is at 1.2.31 (26.09.2026) and project pins run from 1.1.4a to 1.2.31: the code moves, the wiki does not. **Where the wiki and the installed code disagree, the code wins.** Read [`facts-2026-09.md`](facts-2026-09.md) (Step 17) before trusting a wiki claim — it lists the known disagreements.

**db-platform wiki — concept:**
- `04-Workflow.md` — entity / class / state / action / method / transition / event
- `12-Dynamic-Methods.md` — how methods are exposed via REST (3 invocation styles)
- `13-Query-Parameters.md` — 20 compare operators, search/filter/orderby JSON
- `64-Access-Control.md` — ACU / AMU / AOU / AOM / OMA + area-based scoping for documents
- `65-Observer-PubSub.md` — 7 registered publishers (6 served), 4 delivery types, hooks for event-driven automation

**db-platform wiki — practical:**
- `70-Configuration-Guide.md` — directory structure, master scripts, init chain
- `71-Creating-Entity.md` — file-by-file template (table/view/routine/api/rest/event/init)
- `72-Creating-Document.md` — Document-specific (area-based access, sub-classing)
- `73-Creating-Reference.md` — Reference-specific (scope-based, seed data)
- `74-Workflow-Customization.md` — multi-state-per-type, custom actions, ChangeObjectState
- `75-REST-Endpoint-Guide.md` — dispatcher pattern, batch support, field projection
- `76-Event-Handler-Guide.md` — event order rules, cascade, EventDrop pattern

**Production reference (`~/DevSrc/Projects/apostol-csms/db/sql/configuration/csms/`):**
- `entity/object/document/client/` — production sub-classing chain (4 sub-classes: tenant, employee, driver, partner) using single-table inheritance. 7 files + INDEX.md.
- `entity/object/document/charge_point/` — production multi-table entity (1 master + 6 child sub-tables) with 3-state-per-`enabled`-type workflow (available/unavailable/faulted), custom actions, auto-ACL via triggers, SCD-2 history. 7 files + INDEX.md.

> **Both csms examples illustrate different valid inheritance patterns.** Pick the right one for your domain:
> - **Single-table** when subclasses share the same fields (tenant/employee/driver/partner all have code/name/phone/email).
> - **Multi-table** when subclasses have substantially different fields (bridge_journal vs engine_journal).

**Companion reference for REPORT-related work:**
- `~/.claude/skills/apostol-project/report-subsystem.md` — full reference for db.report (definition) vs db.report_ready (instance), sync/async report_ready as UX-label, InitReport/InitObjectReport difference, rpc_/rcb_ pipeline for async-microservice integration. **Mandatory** before creating reports or integrating doc-generation services.

### Tier 2 — Before writing or modifying a C++ module / process

```
<project>/backend/src/modules/Workers/<Name>/README.md  — module-specific contract
~/DevSrc/Projects/libapostol/wiki/Architecture.md       — event loop, process model, module dispatch, exec_sql, PgPool, LISTEN/NOTIFY
~/DevSrc/Projects/libapostol/wiki/Configuration.md      — JSON config, env expansion, hot reload, PG roles
```

The libapostol pages hold for **v2** projects (`src/lib/libapostol/`). The v1 projects (plugme, copyfrog,
debt-master, campus/cors, talking-to-ai) run on libdelphi (`src/lib/delphi/`, C++14, INI config) —
their `backend/CLAUDE.md` is the guide there.

### Tier 3 — Before frontend ↔ backend integration

```
<project>/frontend/CLAUDE.md                                          — app stack, hooks, patterns
<project>/docs/webapp-backend-integration.md (if exists)              — auth, REST, WebSocket
<project>/backend/src/modules/Workers/AuthServer/README.md            — cookie-based auth, X-Auth-Context
<project>/backend/src/modules/Workers/WebSocketAPI/README.md          — JSON-RPC over WS, observer subscribe
```

### Don't skip reading "to save context"

The fix for "this PR has anti-patterns and needs rework" is reading the wiki **first**. Rework costs more context than thorough reading. **Quality > context budget**.

> **NEVER edit files in `apostol-repo-v2/`.** These are read-only mirrors of upstream repos. Edit only in the project itself (after `git submodule update --init --recursive`).

## Step 3 — How the Framework Works (Read Before You Write)

**RULE: Never guess. Never invent fields, endpoints, or parameters. Read the source.**

The db-platform is a complete backend framework with its **own** patterns for REST API, query parameters, workflow, and entities. It is **not** a generic RESTful API. Before writing any code — backend or frontend — you must understand how the framework works.

### Navigation: from general to specific

```
wiki/Home.md                          → understand the framework (concepts, ~52 pages)
    ↓
db/INDEX.md (or backend/db/INDEX.md) → navigate the project's DB layer
    ↓
configuration/<dbname>/INDEX.md       → navigate project entities
    ↓
entity/.../<name>/                    → specific entity source (the truth)
    ├── table.sql   → actual columns, types, constraints
    ├── view.sql    → 3 views (basic / Access / Object)
    ├── api.sql     → 6 functions + view (api.<entity>)
    ├── rest.sql    → 6 routes + ELSE → ExecuteDynamicMethod
    ├── event.sql   → event handlers (9 standard + custom)
    ├── init.sql    → entity / class / type / methods / transitions / events / route
    └── routine.sql → CreateXxx / EditXxx / GetXxx + business logic
```

**Always go: wiki (concept) → INDEX.md (navigate) → entity source (specifics) → then write code.**

### When you need to understand a CONCEPT

Read the wiki page:

```
~/DevSrc/Projects/db/platform/wiki/
├── 04-Workflow.md                — state machine: entity/class/state/action/method/transition/event
├── 12-Dynamic-Methods.md         — 3 ways to invoke a method via REST
├── 13-Query-Parameters.md        — 20 compare operators (filter / search / orderby)
├── 40-Workflow-Endpoints.md      — REST endpoints for workflow operations
├── 41-Object-Endpoints.md        — REST CRUD for any entity object
├── 60-Schema-Overview.md         — DB schema architecture
├── 61-Database-Tables.md         — all platform tables
├── 62-Function-Reference.md      — all platform functions
├── 63-Entity-System-Internals.md — entity hierarchy internals
├── 64-Access-Control.md          — ACU/AMU/AOU/AOM/OMA + area scoping
├── 65-Observer-PubSub.md         — 7 publishers, 4 delivery types
├── 70-Configuration-Guide.md     — configuration directory + master scripts
├── 71-Creating-Entity.md         — full entity creation tutorial
├── 72-Creating-Document.md       — Document specifics + sub-classing
├── 73-Creating-Reference.md      — Reference specifics + seed data
├── 74-Workflow-Customization.md  — custom states / methods / transitions
├── 75-REST-Endpoint-Guide.md     — REST dispatcher patterns
├── 76-Event-Handler-Guide.md     — event handler patterns + order rules
└── Home.md                       — full index (52 pages)
```

### When you need to understand a SPECIFIC ENTITY

Read the entity's source files:

| Question | Read this file |
|----------|----------------|
| What REST endpoints does this entity have? | `rest.sql` |
| What states, methods, transitions exist? | `init.sql` |
| What happens on create/edit/delete? | `event.sql` |
| What API views/functions are available? | `api.sql` |
| What business logic functions exist? | `routine.sql` |
| What's the table schema? | `table.sql` |
| What views exist (basic, access, object)? | `view.sql` |
| What is this entity for? Dependencies? | `INDEX.md` (if present) |

### When you need to understand a C++ MODULE

```
<project>/backend/src/modules/Workers/<Name>/README.md     — for project's copy
~/DevSrc/Projects/apostol-repo-v2/module-<Name>/README.md  — upstream README (read-only)
```

### When you need to understand the REPORT SUBSYSTEM

The platform's report subsystem has its own non-obvious model — `db.report`
(definition, static) vs `db.report_ready` (instance, dynamic), `sync.report_ready`
vs `async.report_ready` as a UX label not a workflow distinction,
`InitReport()` vs `InitObjectReport()` for different UI placement, `rpc_*` +
`rcb_*` pipeline for async-microservice integration (DOCX/PDF/Excel
generation through external services with callback).

Read the dedicated reference document:

```
~/.claude/skills/apostol-project/report-subsystem.md
```

Mandatory before:
- Creating a new report (or adding output to one)
- Integrating an async file-generating microservice (docx-service,
  docx-generator, custom)
- Modifying `rpc_<code>` / `rcb_<code>` functions
- Debugging report state stuck in `progress`
- Choosing between `sync.report_ready` vs `async.report_ready` for new UX

## Step 2 details (moved from the core 30.09.2026)

### Why

A subagent without platform fluency works "blind" — handles rote steps but breaks on the non-obvious decisions that **always** come up mid-task (the plan never covers everything). Anti-patterns get caught by the code-reviewer agent, but that's reactive — better to prevent via adequate briefing of the implementer.

### What to ban from subagent prompts

- "Just do X, you'll figure it out" — guarantees junk output for non-trivial work.
- "Use your knowledge of Apostol" — the subagent's knowledge is what's in the prompt + skills. You must explicitly invoke them.
- One-line commands for multi-decision tasks.
