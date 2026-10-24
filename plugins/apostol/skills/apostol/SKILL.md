---
name: apostol
description: Use ONLY when developing the frameworks themselves — libapostol (C++20), db-platform (PL/pgSQL), or shared C++ modules/processes (incl. GatewayAPI). For working on projects BUILT ON Apostol, use /apostol-project instead.
allowed-tools: Read
user-invocable: true
---

# /apostol — Framework Development (libapostol + db-platform + shared modules)

This skill is for changing the **shared infrastructure**: libapostol, db-platform and the reusable C++ modules and
processes. Working on a project built on Apostol, or only reading or auditing the frameworks without changing them —
use `/apostol-project`. Never both in one session.

After reading, announce: **"Apostol framework context loaded."**

> **Measured 24.10.2026.** libapostol `08ce5cc`; db-platform `eac160a` (`VERSION` 1.2.35); go-platform `d6e47e7`;
> AppServer `b806abd`, AuthServer `e8fa72e`, GatewayAPI `f9bc1e7`, WebSocketAPI `953bccf`, PGHTTP `aea510e`,
> FileServer `8646237`, WebServer `9f21162`, PGFetch `40e85c6`, PGFile `216df65`, MessageServer `0f3b93c`,
> TaskScheduler `f1127e7`, ReportServer `166f6f6`. Every count here was measured at these pins; the command is next to it. A later pin
> → measure again before you rely on a number.

---

## When to use this skill vs /apostol-project

| Working on... | Use |
|---------------|-----|
| libapostol core (Application, EventLoop, PgPool, HTTP/WebSocket, clients) | `/apostol` (this) |
| db-platform modules (kernel, admin, workflow, entity, api, gateway, …) | `/apostol` (this) |
| Shared C++ modules (AppServer, AuthServer, GatewayAPI, WebSocketAPI, PGHTTP, FileServer, WebServer, PGFetch, PGFile) | `/apostol` (this) |
| Shared processes (MessageServer, TaskScheduler, ReportServer, Replication, StreamServer) | `/apostol` (this) |
| Porting a project from v1 to v2 | `/apostol` (this) |
| Reading or auditing the frameworks **without editing them** | `/apostol-project` + the code at its pins |
| Any project's `configuration/` layer, its own C++ processes, frontend, Docker, deployment | `/apostol-project` |
| go-platform (`/api/v2`, Go) | the project's Go rules; its contracts with this skill's code are in Part III (§ go-platform below) |

---

## Step 0 — The specification is the map; the code is the evidence

The Apostol Specification (`github.com/apostoldevel/apostol-spec`, private to the organisation; in a project that
carries it, usually the submodule `docs/spec/`) describes the frameworks **as built at their pins** and cites the line behind every statement.

| Part | Covers | Read for framework work |
|---|---|---|
| 0 | the set, conventions, the request end to end (`06-request-flow.md`), strategic assessment (`07`) | `04-conventions.md` 4.3–4.7, 4.11; `06` |
| I | libapostol (blocks `APP` `EVL` `CFG` `LGR` `MOD` `NET` `HTP` `HCL` `WSK` `PGC` `LDR` `SEC` `DBP` `UTL`) and the shared modules/processes (`APS` `AUS` `GWA` `WSA` `PGH` `FLS` `WBS` `PGF` `PFL` `MSG` `TSK` `RPT`); Annex A build, Annex B every module config key | `04-architecture.md`, the block of the file you touch, Annex B |
| II | db-platform: object model, access control, **extension contract (`07`)**, **transport contract (`08`)**, API v1 (`09`), one block per module | `04-architecture.md`, `07`, `08`, the module's block |
| III | go-platform and API v2: gateway contract (`05`), database road (`06`) | when you touch `GatewayAPI`, `daemon.begin/call/end` or schema `gateway` |

Not specified: `Replication` and `StreamServer` (no block in Part I), the v1 transport.

**Before changing behaviour:**

```sh
python3 docs/spec/tools/where.py <file>[:<line>]   # blocks, requirement ids, known deviations, freshness of the file
python3 docs/spec/tools/drift.py                    # cited files changed after their pins → blocks that may be stale
python3 docs/spec/tools/citecheck.py                # after an edit of the spec: every citation resolves at its pin
```

- `unchanged since the pin` → the block describes the code you see; its requirements are what your change keeps, or
  changes on purpose and says so. `CHANGED in N commit(s)` → the code wins; note the disagreement.
- A fix of a known deviation names its id (`<CODE>.DEV.nn`) in the commit and the task (Part 0, 4.11).
- **A new pin makes the Part that cites it stale.** Moving a pin after your change → tell whoever keeps the spec
  which block your change touched; you do not edit the spec in the framework commit.
- **Deviation tables and `90` clauses hold unfixed security findings.** Never copy their text into an upstream
  commit message, issue, README or code comment — those repositories are public. Name the id and the class of defect.
- **Neutrality (Part 0, 4.7).** Upstream code, comments, commit messages and READMEs name no project, brand, host,
  deployment or a project's task number. An existing project word in upstream is itself a recorded deviation — do not add new ones.

---

## Step 1 — Where the code is, and what to read

**The truth is the submodule checkout inside a project at its pin, equal to `origin`.** A local mirror of an upstream
repository (a sibling clone kept "for reading") lags: on the workspace this skill was measured on, the libapostol
mirror was 4 commits behind, the db-platform mirror two versions behind, and the module mirrors had no `GatewayAPI`.
Compare before you read: `git -C <mirror> log -1 --format=%h` against `git ls-remote <upstream> HEAD`.

Mirrors are `git pull` only. Read the code where you will change it: `backend/src/lib/libapostol`,
`backend/src/modules/{Workers,Helpers}/*`, `backend/src/processes/*`, `db/sql/platform` (v2 layout).

Documents, in order of trust:

1. **The spec** (Step 0) — newest, cited.
2. **The headers and the code**: `include/apostol/*.hpp` (42 headers: `ls include/apostol/*.hpp | wc -l`); in
   db-platform `INDEX.md` → `<module>/INDEX.md`, `RLS.md`, `CLAUDE.md`.
3. **READMEs**: `libapostol/README.md` (quick start, benchmark), each `module-*/README.md` (config keys — Annex B is
   the checked list).
4. **Wikis — older than the code.** `github.com/apostoldevel/libapostol/wiki` (`Home`, `Getting-Started`,
   `API-Reference`, `Architecture`, `Configuration`, `Creating-Modules`, `Creating-Processes`) and
   `github.com/apostoldevel/db-platform/wiki` (52 numbered pages, e.g. `04-Workflow`, `64-Access-Control`,
   `71-Creating-Entity`, `74-Workflow-Customization`, `75-REST-Endpoint-Guide`, `76-Event-Handler-Guide`). Both last
   changed 23.08.2026 (`git -C <wiki clone> log -1 --format=%cs`); a project's `sql/platform/` carries no `wiki/`.
   A wiki page is a tutorial, not a statement of the current code.

> db-platform's own `CLAUDE.md` disagrees with the code in places (24.10): it says `security.sql` is create-only,
> but `entity/object/update.psql:2` re-runs it; it points at `wiki/`, which the repository does not carry; it says
> `runme.sh --test` runs pgTAP — `runme.sh` is the project's script and the platform ships no pgTAP suite. For file
> roles use Part II, Table 4.6.

---

## How framework work actually happens — the submodule loop

**The framework is patched INSIDE a project, in the submodule** (`backend/src/lib/libapostol`,
`backend/src/modules/*`, `backend/src/processes/*`, `db/sql/platform`) — never in the mirrors. The project is the
closed environment where the fix can be exercised together with real code before it becomes everyone's problem.

```
where.py on the file → patch in the submodule → build and verify together with the project's own code
                     → review → commit in the submodule → push upstream → move the pin in the project
```

**Commit and push BEFORE `git submodule update`,** or the work is silently discarded.

> **A push from a submodule can leave the work at home and still read like success.** On a detached HEAD, or from
> a local branch that does not carry the commit, nothing is published — and what git prints then depends on
> `push.default`, the git version and the state of the local branch, so no particular reply is a sign either way.
> Before calling anything published, verify **`HEAD == origin/<branch> == the pin recorded in the project tree`**
> — all three, whatever git answered.

**Every framework change ships to every project in the ecosystem.** Not "it works for us" but "it does not break
the others". Review happens **before the commit into the submodule**, not merely before the push — once it is
upstream it is already someone else's code.

db-platform specifics:

- **A version is a commit of its own**: `VERSION` bumped with the message `Version X.Y.Z.` (`git log --oneline`
  shows `d6b5807 Version 1.2.35.`). go-platform links to it by the constant `platform.DBPlatform`
  (`go-platform:version.go:10`, `"1.2.35"`), checked by the `-tags integration` test against
  `GO_TEST_DB_PLATFORM_VERSION` (the submodule's `VERSION`; skipped when unset, `version_integration_test.go:15–21`).
- **Platform patches**: `patch/v<x>.<y>/P<8 digits>.sql`. `migrate.sh` applies every one not in `db.patch_log`,
  recording it by **path** (`platform/<ver>/<name>`, `migrate.sh:103–109`), not by content: two different patches
  shipped under one path (parallel branches took the same number) — the second is skipped silently. `patch/patch.psql`
  is the manual road (`runme.sh --patch`); its shipped entries stand commented out.
- **Re-run files hold only `CREATE OR REPLACE`.** A dropped function, changed argument list or result type → a
  patch. Which file runs on update is Part II, Table 4.6 — the exceptions (`jwt.sql`, `admin/do.sql` create-only;
  `error/init.sql`, `report/init.sql` re-run) bite.
- **Configurations redefine platform functions** by `CREATE OR REPLACE` later in the load order (Part II, `EXT02`);
  nothing records which body is installed. Before changing a function's arguments, result or
  meaning, grep `sql/configuration/` of the projects you can reach for `FUNCTION <name>`: a redefinition keeps the old
  behaviour there, and a changed signature turns it into an overload.

### Hitting a framework fix in the middle of project work

Do **not** switch skills in place, and do not "just fix it quickly while the file is open". The two modes carry
opposite write permissions and opposite defaults about what is yours to change.

Correct move: stop, write down **where** the fix belongs (`file:line`), **what** it must do, **which spec block and
requirement** it touches (`where.py`), and **how it will be verified**, and hand that over — a new session in
framework mode picks it up. The handover is the deliverable.

---

## Golden Rule: Framework First

1. **Search libapostol first** — does the framework already solve this? Check the existing modules for the same
   pattern. If a pattern exists — use it.
2. **Evaluate reusability** — "Will other Apostol applications benefit?" If yes, the fix belongs in libapostol
   (`*_utils.hpp`, a base class, a core component), not in the module.
3. **Do no harm** — first don't break existing behaviour, second improve. When in doubt, keep the change in the
   module until you are confident.
4. **Know the API** — the block of Part I (its data types and interfaces tables) and the header, before writing.

Anti-patterns: a module-level patch for what libapostol already solves; duplicating logic from another standard
module; a workaround without checking whether it is a framework-level bug.

---

## libapostol — C++20 transport

**GitHub:** `github.com/apostoldevel/libapostol` (MIT). **A-POST-OL** = Asynchronous POST Orchestration Loop
(`README.md:8`). A static library (`apostol`); one thread and one epoll loop per process, shared by the HTTP/WebSocket
server, libpq connections, outbound clients and timers; parallelism by processes (Part I, 4.7). Two blocking calls
remain on the loop: DNS resolution in `TcpClient`/`UdpClient` and log compression at rotation. Inbound TLS is not offered — a
reverse proxy terminates it.

### Build and dependencies (Part I, Annex A; `CMakeLists.txt`)

CMake ≥ 3.25, C++20 without extensions; GCC 12+ / Clang 16+ per the README.

| Dependency | Pin | |
|---|---|---|
| nlohmann/json | git tag `v3.11.3` | FetchContent (`CMakeLists.txt:46`) |
| {fmt} | git tag `11.1.4` | FetchContent (`:55`) |
| llhttp | `release/v9.2.1` tarball | FetchContent (`:63`) |
| OpenSSL, libcurl, libpq, zlib, libdl | system | zlib always (`:85`) |
| jwt-cpp | vendored, modified | `src/lib/jwt-cpp` |

**The repository has no tests** (no `enable_testing`/`add_test`): verification is by building a project against
the change and running it.

| Flag | Default | Enables |
|------|---------|---------|
| `WITH_POSTGRESQL` | ON | PgPool, async queries, LISTEN/NOTIFY, leader lock, BotSession |
| `WITH_DB_PLATFORM` | ON (needs PostgreSQL) | `src/dbplatform/` — the only place db-platform function names live |
| `WITH_SSL` | ON | JWT, SmtpClient, TLS client sockets |
| `WITH_CURL` | ON | `CurlClient`; `FetchClient` selects it, else the built-in `HttpClient` |
| `APOSTOL_EPOLL_ET` | **OFF** | edge-triggered + one-shot epoll: handlers drain to `EAGAIN` and call `rearm_io()` |

The application must define the `APP_*` macros (`APP_NAME`, `APP_PREFIX`, `APP_DEFAULT_PORT`, …): the library
defines none, so the README's standalone `cmake -B build` does not compile; `template/CMakeLists.txt`
has the full set. `template/configure` defaults `WITH_POSTGRESQL` to OFF — pass `--with-postgresql`.

### Process model (Part I, `APP`, 4.3)

| Role | Selected by | Runs |
|---|---|---|
| `single` | `process.master=false`, `process.helper=false` (default) | worker modules only — **no helper, no custom processes** |
| `master` | `process.master=true` | binds the listener, forks helper (if `process.helper`), custom processes, `workers` workers; supervises |
| `worker` | child of master | worker modules on the inherited socket |
| `helper` | child of master (or stand-alone with `helper` only) | helper modules, heartbeat 1 s |
| `custom` | child of master, one per `add_custom_process` | one process module, a pool on `postgres.helper` |

`workers: 0` = number of online CPUs. Custom processes are registered once at start; a reload (SIGHUP) does not
re-evaluate the list. With `process.leader` (or `module.<Name>.leader` per custom process, `settings.hpp:76–79`) a background role runs
once per database across copies (`LDR`; needs a session-mode connection — not pgbouncer in transaction mode).

### Process lifecycle — what the framework does for you

- **An exception out of startup is the supported way to fail loudly.** A worker whose `on_worker_start` or a
  module's `on_start` throws logs `worker startup failed`, drops its pools and exits 1 (`application.cpp:1131–1142`);
  any child whose run throws logs `<role> '<name>' fatal: …` at `error` and exits with code 1
  (`application.cpp:1508–1530`). Only `std::exception` is caught. Prefer it to "log and continue", which yields a
  process that is up and does nothing.
- **The master respawns dead children with a backoff.** An exit less than 2 s after the child's previous exit is "rapid";
  from the 4th rapid exit since the last reset the respawn waits 2, 4, 8, 16, then 30 s (`application.cpp:1648–1656`),
  held at 30 s; only an exit more than 60 s after the previous one resets the count (`:1600`) — an exit 2–60 s after
  neither adds nor resets. A misconfigured process is therefore a repeating failure, not
  a one-off — mind its log volume over a day on an appliance nobody restarts.
- **Signals go through signalfd on the loop** (`event_loop.cpp:484`). SIGTERM/SIGINT → SIGTERM to children, SIGKILL
  after 5 s by a timer; SIGHUP → validate the new config, then rolling restart; SIGUSR1 → reopen logs.
- **Never sleep in a signal path.** The master stops reaping and stops handling `SIGTERM` for the duration. Use a
  **one-shot timer on the loop** — the respawn delay and the SIGKILL escalation already do. The one place left — a
  100 ms `usleep` in the master's rolling restart on SIGHUP — is a known defect, not a pattern.
- **Shutdown order**: `quiesce → drain → detach → on_stop → drain`; `Module::on_stop` runs after pending queries are
  drained — no query handler fires after it.
- **Resolve file paths with `app.resolve_path(value, default_name = "files")`** (patterns: `FileServer.cpp:32`,
  `PGFile.cpp:34`). A bare `ifstream(value)` resolves against the working directory, not the prefix.
- **Count processes by the master's `ppid`, not by a substring of the command line.** The title is rewritten to
  `<name>: <role> process (<modules>)` (`APP00.FR.05`), and on a host running containers `ps` shows other projects'
  workers too.
- **`worker_loop()` and `db_pool(role)` exist only in workers and `single`**: in a helper or custom process they
  fail at run time. Take the loop from `on_start(loop, app)`.

### Modules — the plug-in contract (Part I, 4.4; `MOD`)

The application's `Application` subclass plugs code in at three hooks (`application.hpp:233–246`):

| Hook | Runs in | Registers |
|---|---|---|
| `on_worker_start(loop)` | every worker and `single` | worker modules (`module_manager().add_module(...)`), then `start_http_server` |
| `on_helper_start(loop)` | the helper | helper modules |
| `create_custom_processes()` | master (or `single`), once | `add_custom_process(std::make_unique<…>())` — a `ProcessModule` or a `CustomProcess` |

- **Enable key: `module.<Name>.enable`** (`application.cpp:95–97`), default `true` unless the registering code
  passes another (the READMEs of `GatewayAPI`, `MessageServer`, `TaskScheduler`, `ReportServer` say `false`; the
  application's registration code decides, Part I, Annex B.1). Module
  settings live in `module.<Name>`, read by `app.module_config("<Name>")` — processes too: there is **no**
  `"modules"` or `"processes"` section.
- **First match wins** in registration order (`module.cpp:16`): narrow `check_location` first, the static-file
  server last.

| Kind | Base class | Constructor (as the shared modules do it) | Lives in |
|---|---|---|---|
| Worker module | `ApostolModule` (`check_location` + `init_methods` + `add_method`), or `RoutedModule` | `explicit X(Application& app)`; `name()` and `enabled()` are overrides — the base takes no arguments | `src/modules/Workers/` |
| Helper module | `Module` | `X(Application& app, EventLoop& loop)` (`PGFetch.cpp:67`) | `src/modules/Helpers/` |
| Process module | `ProcessModule` (`on_start(loop, app)`, `heartbeat(now)`, `on_stop()`), wrapped by `ModuleProcess` | default-constructed; gets `loop` and `app` in `on_start` | `src/processes/` |

**`RoutedModule`** (`RouteManager`: `{param}` segments, trailing wildcards, three passes — exact, parametric,
wildcard; OpenAPI 3.0 + Swagger UI at `/docs`) **is used by none of the twelve shared modules**
(`git -C <submodule> grep -n RoutedModule` is empty; positive control: `template/src/modules/Workers/WebService`).
Expect `check_location()` + `init_methods()` + `add_method("GET"/"POST", …)`.

Clients (`HCL`): `CurlClient` (libcurl multi on the loop), `HttpClient` (small HTTP/1.1, one request per
connection), **`FetchClient(loop, Backend = auto_select)`** — the façade modules use; `HttpProxy`; `WsClient`;
`SmtpClient`. Database (`PGC`): `PgPool::execute(sql, on_result, on_exception)`, `PgPool::listen(channel, cb)`,
`exec_sql(pool, req, resp, …)` (`pg_exec.hpp:24`); every pooled query is sent behind `RESET current.area` in one message (default list `pg.cpp:593`, changed by
`PgPool::set_reset`).

### The shared modules and processes (Part I, 4.4.3, Section 2)

| Component | Kind | Base | Database interface (Part II) | LISTEN |
|---|---|---|---|---|
| `AppServer` | worker | `ApostolModule` | `daemon.fetch`, `session_fetch`, `authorized_fetch`, `unauthorized_fetch`, `refresh_token` | — |
| `AuthServer` | worker | `ApostolModule` | `daemon.token`, `login`, `identifier`, `authorization_code`, `refresh_token` | — |
| `GatewayAPI` | worker, before `AppServer`; WebSocket handler of its control path | `AppServer` | inherited; `/api/v2` to Go modules (Part III) | `gateway`, `gateway_cmd` |
| `WebSocketAPI` | worker + WebSocket handler | `ApostolModule` | `daemon.observer`, `publisher_list`, the `fetch` family | from `daemon.publisher_list` |
| `PGHTTP` | worker | `ApostolModule` | `http.<method>` by endpoint | — |
| `FileServer` | worker | `ApostolModule` | `api.get_file`, `api.decode_file_access` via `BotSession` | — |
| `WebServer` | worker, last (catch-all) | `ApostolModule` | none — static files per site | — |
| `PGFetch` | helper | `Module` | `http.request`, `take`, `create_response`, `fail`, `sweep` | `http` |
| `PGFile` | helper | `Module` | `api.get_file` via `BotSession` | `file` |
| `MessageServer` | process | `ProcessModule` | `api.outbox`, `execute_object_action`, `set_object_label` | `outbox` |
| `TaskScheduler` | process | `ProcessModule` | `api.job`, `execute_object_action`, `set_object_label` | — (polls) |
| `ReportServer` | process | `ProcessModule` | `api.report_ready`, `execute_report_ready`, `execute_object_action` | `report` |

Each is its own repository (`github.com/apostoldevel/module-<Name>` / `process-<Name>`), consumed as a submodule.
`Replication` and `StreamServer` exist upstream but have no block in the spec. A change to the database names a module
calls is a change of the transport contract (Part II, `08`; Part I, `05`) — both sides move together.

---

## db-platform — PL/pgSQL framework

**GitHub:** `github.com/apostoldevel/db-platform`. Version: `cat VERSION` — the only reliable string (one tag,
`v1.0.0`). It lives as `sql/platform/` inside every project; the configuration is `sql/configuration/<dbname>/`.

### Modules — 28, in load order (Part II, Table 4.3)

`kernel → oauth2 → locale → admin → http → resource → exception → error → registry → log → api → replication →
daemon → session → current → workflow → kladr → file → entity → mq → notice → comment → notification → verification
→ observer → report → reports → gateway` (`grep -c '^\\ir' create.psql` → 28).

At `eac160a`, outside `patch/`: 124 tables (`git grep -h -E '^CREATE TABLE' -- '*.sql' ':!patch/*' | wc -l`), 1 895
function definitions (`'^CREATE (OR REPLACE )?FUNCTION'`), 41 `rest.*` dispatchers
(`'^CREATE OR REPLACE FUNCTION rest\.'`). The largest by functions: `entity` (547; 27 tables, 12 dispatchers), `admin` (314), `workflow` (181; 23 tables),
`report` (150). A plpgsql body may call a module loaded later; a view, a table or a `LANGUAGE SQL` function
may not (Part II, 4.5.1).

### Schemas and roles (Part II, 4.3–4.4)

| Schema | Holds | Reached by |
|---|---|---|
| `db` | every table | nobody but `kernel` |
| `kernel` | business logic, the views the API is built on | `administrator` |
| `api`, `rest` | API views/functions, `api.run`, `api.sql`; the dispatchers | `administrator`, `apibot` |
| `daemon` | the transport interface (`DMN`) | `daemon`, `apibot` |
| `http`, `gateway` | outbound/inbound HTTP records; `/api/v2` request record | `daemon`, `apibot`, `administrator` |
| `oauth2` | the OAuth 2.0 client registry | nobody but `kernel` |
| `registry`, `replication`, `mq`, `report` | their modules' tables | `administrator` |

Every function of `api`, `rest`, `daemon` — and most, not all, of `kernel` (e.g. `ChangePassword`,
`admin/routine.sql:4388`, is not) — is `SECURITY DEFINER` with `SET search_path = kernel[, public], pg_temp`; check
the one you change.
Roles: `kernel` (owner, all DDL), `admin` (member of `administrator`), `daemon` (worker pool: **no USAGE on `kernel`,
`api`, `rest`**), `apibot` (helper processes: `api`, `rest`, `daemon`, `http`, `gateway` — no `kernel`). The
application user is not a database role but the session context; three `session_user` names change behaviour by
themselves (`kernel`, `postgres`, `apibot` — Part II, 4.4).

### Life cycle (Part II, 4.6; `migrate.sh`)

| Script | Role | Runs |
|---|---|---|
| `kernel/users.sql` → `database.sql` → `schema.sql` | superuser | roles, database, schemas, grants |
| `create.psql` → configuration `create.psql` | `kernel` | 28 × module `create.psql` (a module's `init.sql` runs here) |
| `init.sql` → configuration `init.sql` | `admin` (after `SignIn`) | workflow, entity tree, routes, seeds |
| `update.psql` → configuration `update.psql` | `kernel` | the re-run files only (Table 4.6) |
| `migrate.sh [--status\|--dry-run\|--baseline\|--no-update]` | — | pending patches of both layers, then both `update.psql` — only if a patch was applied (`:214`) |

The `.psql` scripts carry no `BEGIN`/`COMMIT` and no `ON_ERROR_STOP` (`ARC-LC.05`); `migrate.sh` runs psql with
`-v ON_ERROR_STOP=1` (`:75`, `:193`, `:227`) — it stops on the first error but wraps nothing in a transaction.
`runme.sh` (`--update`, `--patch`, `--install`, `--init`, `--api`) is the **project's** wrapper around these.

### Contracts a platform change must keep

- **Extension contract (Part II, `07`)** — what every configuration calls: `AddEntity`, `AddClass`, `AddType`,
  `AddState`, `AddMethod`, `AddTransition`, `AddEvent` (the reaction is the fifth argument), `AddDefaultMethods`,
  `AddEndPoint`, `RegisterRoute`, `chmodc`, `CreateDocument`, `CreateReference`, `ExecuteMethod` — signatures in
  Table 7.1; none of the `Add*` is idempotent. The **15 hooks** (`Do*`, clause 7.3) are bodies configurations replace.
  The platform requires of a configuration an OAuth 2.0 audience named after the database (`EXT-R.01`) and, for some
  hooks, tables it does not define (`EXT-R.03`).
- **Transport contract (Part II, `08`)** — the entries the C++ side calls (`daemon.fetch` family, `token` family,
  `observer`, `begin/call/end` for API v2, `api.login`/`api.authorize` for bot sessions), the role each expects,
  where the session context lives, what a refusal looks like. Renaming or reshaping one breaks a transport module.
- **API v1 (Part II, `09`, Annex A)** — every route with its gate; Annex C — error codes `ERR-GGG-CCC`.

---

## go-platform and GatewayAPI — the `/api/v2` road

`github.com/apostoldevel/go-platform` (MIT, `go 1.26.7` in `go.mod`): out-of-process API modules in Go. `GatewayAPI`
(a C++ worker deriving from `AppServer`) proxies `/api/v2/*` over HTTP to a registered Go module; the module registers
over WebSocket on the control path (`/gateway` by default; keys in Part I, Annex B). In the database a request is
`daemon.begin` → `daemon.call` × n → `daemon.end` in one transaction the caller drives (Part II, Figure 8.2; Part III,
`05`–`06`). A change to `GatewayAPI`, to schema `gateway` or to `daemon.begin/call/end` crosses three repositories —
check Part III before you call it local.

---

## Verifying a framework change

The change ships to every project, so "it works here" is not a result.

- **Both directions, and the second is the harder half.** Showing that a backoff happens is easy; showing that **the
  master still answers during it** is the actual claim — send `SIGTERM` while the delay is pending and measure the
  stop time against the 5 s kill timeout.
- **Against the block.** `where.py` names the requirements of the lines you changed; each one either still holds
  (show it) or changed on purpose (say so in the commit and the task).
- **Every caller, not the one you came for.** A changed `daemon.*`/`api.*` function: list the modules that call it
  (`git -C <submodule> grep -n '<name>('` over all twelve) and the configurations that redefine or call it. A changed
  header: build a project that uses it.
- **`SameSite=Lax`, not `Strict`, for a cookie involved in a return from an external provider** — the return is a
  cross-site top-level navigation; a `Strict` cookie is not sent (AuthServer's reasoning: `AuthServer.cpp:99`, `:700`).
- **In nginx, `add_header` at a nested level cancels all inherited ones.** Verify along two paths: one that sets its
  own header and one that inherits.

---

## v1 → v2 porting guide

### Config: INI → JSON

| v1 (INI) | v2 (JSON) |
|-----------|-----------|
| `[main]` `master`, `helper`, `user`, `group`, `workers` | `"process": {"master", "helper", "user", "group"}`, top-level `"workers"` |
| `[module/AppServer]` | `"module": {"AppServer": {}}` |
| `[process/MessageServer]` | `"module": {"MessageServer": {}}` — processes use the same section |
| `[postgres/worker]`, `[postgres/helper]` | `"postgres": {"worker": {}, "helper": {}}` |

`${VAR}` (and `$VAR`) in string values is expanded from the environment when the file is loaded — again on SIGHUP
(`config.cpp:39`, `:54`, `:341`). The keys of every shared
module: Part I, Annex B.

### Code: libdelphi → C++20

| v1 | v2 |
|----|-----|
| `CString` / `CStringList` | `std::string` / `std::vector<std::string>` |
| `CHTTPRequest` / `CHTTPReply` | `HttpRequest` / `HttpResponse` (`http.hpp:65`, `:108`) |
| `CHTTPServerConnection` | `HttpConnection` |
| `CString::Format(...)` | `fmt::format(...)` |
| `CPQPollQuery` | `PgPool::execute(sql, on_result, on_exception)`; `exec_sql(...)` for the request → SQL → response case |
| `CApostolModule(AProcess)` | `ApostolModule` (no constructor arguments; `name()` / `enabled()` overrides) |
| `CurlApi` | `FetchClient` |
| `new` / `delete`, `CObject` / `CCollection` | RAII, standard containers |

| Build | v1 | v2 |
|-----|-----|-----|
| framework | `libdelphi` submodule | `libapostol` submodule |
| build | `cd cmake-build-release && make` | `./configure [--debug]` → `cmake --build cmake-build-<type> --parallel` |
| flags | none | `WITH_POSTGRESQL`, `WITH_DB_PLATFORM`, `WITH_SSL`, `WITH_CURL`, `APOSTOL_EPOLL_ET` |

Performance, as the README states it (`README.md:189–197`, not re-measured): `/ping` 507 K RPS v2 vs 128 K v1.

### Porting steps

1. Create from the template (`libapostol/install.sh`, `template/`) or copy an existing v2 project's `backend/`.
2. Add the shared modules and processes as submodules (`github.com/apostoldevel/module-*`, `process-*`); register
   them in `Workers.hpp` / `Helpers.hpp` / `Processes.hpp` in dispatch order.
3. Port custom modules (`ApostolModule` + `add_method`, `exec_sql`, `FetchClient`); background ones as `ProcessModule`.
4. Convert config INI → JSON.
5. `db/` is unchanged — db-platform serves both transports.

---

## Which projects are still v1

Measure, do not remember — from the workspace root:

```sh
find . -maxdepth 6 -type d \( -path '*/src/lib/delphi' -o -path '*/src/lib/libapostol' \) \
  -not -path '*/cmake-build*' -not -path '*/build*' -not -path '*/.git/*' -not -path '*/node_modules/*' | sort
```

`src/lib/delphi` — v1 (libdelphi, C++14, INI); `src/lib/libapostol` — v2. Several projects still run v1 in production.

---

## Writing Rule — README files

When writing or editing a README that mentions **Apostol CRM**:

1. Replace any `[Apostol CRM](https://github.com/apostoldevel/apostol-crm)` link with: `**Apostol CRM**[^crm]`
2. Add footnote:
   ```
   [^crm]: **Apostol CRM** — a template project built on the [A-POST-OL](https://github.com/apostoldevel/libapostol) (C++20) and [PostgreSQL Framework for Backend Development](https://github.com/apostoldevel/db-platform) frameworks.
   ```
