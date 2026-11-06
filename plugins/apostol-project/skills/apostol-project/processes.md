<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 5 — Module Pairing & LISTEN/NOTIFY

The whole path of a request through every layer, both directions (nginx → AppServer → `daemon.*` → `api.run` → `rest.*`;
GatewayAPI → Go → `daemon.begin/call/end`; `pg_notify` → PGFetch / MessageServer / PGFile), with one figure: the Apostol
Specification, Part 0 clause 6, where your project carries it.

### C++ ↔ PostgreSQL Module Pairing

Every C++ module is **paired** with db-platform PL/pgSQL modules. This is the core architectural pattern:

| C++ Module | Type | DB Module | LISTEN Channel | Key Functions |
|------------|------|-----------|----------------|---------------|
| **AppServer** | Worker | daemon + rest | — | `daemon.fetch()` → `rest.<entity>()` → `api.<func>()` |
| **AuthServer** | Worker | oauth2 + admin | — | OAuth2 6 grants, JWT (12 algos), cookie auth |
| **WebSocketAPI** | Worker | daemon + observer | (dynamic) | `daemon.observer()`, JSON-RPC, pub/sub |
| **PGHTTP** | Worker | http | — | `http.get/post/put/patch/delete()` for custom routes |
| **FileServer** | Worker | file + api | — | `api.get_file()` |
| **WebServer** | Worker | — | — | Static files + Swagger UI (no DB) |
| **PGFetch** | Helper | http | `"http"` | `http.fetch()` → outbound HTTP via curl |
| **PGFile** | Helper | file | `"file"` | filesystem sync from `db.file` |
| **MessageServer** | Process | notice / message | `"outbox"` | SMTP/FCM/push dispatch |
| **TaskScheduler** | Process | scheduler / api.job | poll; `"job"` in `single` mode (1.2.38) | scheduled SQL execution (cron) |
| **ReportServer** | Process | report | `"report"` | builds `report_ready` documents; the result is JSON/text in `db.file` — **no CSV/XLSX/PDF export exists in the platform** |
| **StreamServer** | Process | — | — | UDP listener (telemetry) |
| **Replication** | Process | replication | `"replication_cmd"` | shore↔edge sync (HTTP+gzip+OAuth2) |

### Module Capabilities Quick Reference

| Need | Module | How to use |
|------|--------|-----------|
| Auth token | AuthServer | `POST /oauth2/token` → `daemon.token()` |
| User lookup | AuthServer | `POST /oauth2/identifier` → `daemon.identifier()` |
| API request | AppServer | `GET/POST /api/v1/*` → `daemon.fetch()` → `rest.<entity>()` |
| Cookie auth | AppServer | `__Secure-AT/RT` cookies, auto-refresh via `daemon.refresh_token()` |
| WebSocket | WebSocketAPI | `wss://host/session/<code>[/<identity>]` |
| Subscribe events | WebSocketAPI | JSON-RPC `CALL` → `api.observer_subscribe()` |
| Push to client | WebSocketAPI + observer | an observer event, handed by each worker to `daemon.observer` for every verified socket (`POST /ws/<code>` is gone from current WebSocketAPI; an older pin may still serve it) |
| Serve files | FileServer | `GET /file/<path>` → `api.get_file()` |
| Static SPA | WebServer | per `conf/sites/*.json` |
| Send email/push | MessageServer | `SendMessage` / `SendMail` / `SendFCM` / `SendPush` (kernel) → `message.outbox` document → `submit` → LISTEN `outbox` (+ 60 s poll). `SendSMS` **bypasses** the message model and calls `http.fetch` directly |
| Schedule a periodic job | TaskScheduler | `CreateJob(...)` with a `scheduler` interval reference + a `program`; no cron syntax |
| Outbound HTTP from DB | PGFetch | `http.fetch()` → NOTIFY → curl → `http.create_response()` |
| File sync from DB | PGFile | INSERT/UPDATE `db.file` → NOTIFY `file` |
| Custom REST routes (webhooks) | PGHTTP | `http.get/post/put/patch/delete()` |
| State machine | platform `workflow` | `AddState`/`AddMethod`/`AddTransition`/`AddEvent` |
| RBAC / row-level security | platform | ACU/AMU/AOU + `Access<Entity>` view |
| Real-time events | platform `observer` + WebSocketAPI | 7 registered publishers (6 served; `file` never delivers), hook delivery |
| Audit log | platform `log` | `WriteToEventLog(...)` everywhere |

### LISTEN/NOTIFY Channels (default)

| Channel | Listener (C++) | Fires when (PL/pgSQL) |
|---------|----------------|----------------------|
| `http` | PGFetch | `http.fetch()` queues outbound request |
| `file` | PGFile | `db.file` row inserted/updated/deleted |
| `outbox` | MessageServer | message enters `prepared` state |
| `inbox` | **nobody** — MessageServer listens to `outbox` only | inbound message created |
| `report` | ReportServer | report enters `progress` state |
| `notice` | (observer) | `db.notice` row created |
| `log` | (observer) | `db.log` row created |
| `notify` | (observer) | a `db.notification` row after every executed method — the observer's channel, not the `notify` module |
| `job` | — (`single`: the subscriber is woken on its personal `job:<n>`) | `api.job_due()` queues a due job (1.2.38); in `legacy` mode TaskScheduler polls `api.job` |
| `replication` | (observer) | replication entry created |
| `replication_cmd` | Replication | operator command (mode/channel/sync) |
| (any project-defined) | WebSocketAPI dynamic | `pg_notify(channel, payload)` for project pub/sub |

Since 1.2.37 the producers send through `notify.send`, and every channel has a row in `notify.channel` (the seed,
`notify/init.sql`, lists the rest: `message`, `geo`, `gateway`, `mq`, …). A channel in `single` mode is not a
LISTEN/NOTIFY channel any more — next section.

### The `notify` module — delivery to one consumer (1.2.37+)

- **Modes per channel** (`notify.channel.mode`): `legacy` and `broadcast` send a plain `pg_notify(channel)`; `single`
  writes a `notify.queue` row and wakes one subscriber on its personal channel `<channel>:<n>` — the common channel is
  never notified (`notify/routine.sql`, `notify.send`). Every seeded channel starts `legacy` (`ON CONFLICT DO NOTHING`).
- **Consumers decide by the mode.** At their current heads PGFetch (`http`), PGFile (`file`), MessageServer (`outbox`),
  ReportServer (`report`) and TaskScheduler (`job`) read `notify.channel_policy` and subscribe through `NotifySubscriber`
  only when the channel is `single` and the base has the functions they probe for (`http.retake`,
  `http.try_create_response`, `notify.hold` — after the 1.2.38 bump, `75152fe`); otherwise they keep the old path.
  TaskScheduler bounds a job body by `statement_timeout` = 8/10 of the `job` channel's lease in every mode.
- **An older binary hears nothing on a `single` channel.** Switch a channel to `single` only when every instance that
  listens on it runs a consumer that subscribes — the database does not refuse the switch while old listeners remain.
- **Who writes `notify.queue.seen`:** `notify.take` and `notify.sweep_channel` — the latter runs from a subscriber's
  `notify.sweep` and from `api.sweep_notify_channel` in a job. Grace and expiry count from the first `seen`, so a row
  nobody looks at never starts to expire. A channel with no subscriber needs a periodic job whose program is
  `SELECT api.sweep_notify_channel('<channel>');` — the platform seeds none. Read who writes a column before you reason
  about when something fires.
- **`max_attempts` counts repeats** after the first delivery (N + 1 deliveries in all). `notify.close` calls `on_abandon` for
  a row that was handed out, or for any row when the channel's `on_expire` is set; repeats also need `resend_enabled`.
  Its exceptions are stored in `notify.queue.error`, not raised.
- Changing a seeded channel row on an existing base: `db-architecture.md` § Tenant ↔ Area, the note **Seeds**.

### Background Service Auth Pattern

All helpers and custom processes authenticate to PostgreSQL via the helper pool (`apibot` user) and to remote APIs via OAuth2:

1. OAuth2 `client_credentials` as `apibot` on startup → 24h access token
2. Re-authenticate every 24 hours
3. Retry after 10 seconds on failure
4. Use `postgres.helper` connection pool (libapostol JSON config)

---

## Step 11 — Process Model & Runtime

### Six Process Roles

```
                       ┌────────────────────┐
                       │   Master process    │  (signal handling, child supervision)
                       └─┬──────┬──────┬────┘
              ┌──────────┘  ┌───┘  ┌───┘
              ▼              ▼      ▼
       ┌────────────┐  ┌──────────┐  ┌────────────────┐
       │ Worker (N) │  │ Helper(1)│  │ Custom proc(N) │
       │ HTTP / WS  │  │ PGFetch  │  │ TaskScheduler  │
       │ via Modules│  │ PGFile   │  │ MessageServer  │
       │ user:daemon│  │user:apibot│ │ Replication... │
       └────────────┘  └──────────┘  └────────────────┘
```

| Role | Config | Purpose |
|------|--------|---------|
| `single` (default) | `process.master=false` | Worker modules in one process — no helper modules, no custom processes |
| `master` | `process.master=true` | Supervisor (forks, signals, crash recovery) |
| `worker` (N) | `workers: N` | HTTP/WebSocket — registered modules |
| `helper` (1) | `process.helper=true` | PGFetch/PGFile background |
| `custom` (N) | `add_custom_process()` in `main.cpp` | TaskScheduler, MessageServer, Replication, project-specific (NMEA, Modbus, ESign, Print, ...) |
| `signaller` | CLI `-s stop|quit|reload|reopen` | Signal sender, exits |

### Project-Specific Custom Processes

When a project needs a custom background process (e.g. an `NMEA` telemetry process), it's written **in the project repo** under `backend/src/processes/<Name>/`, inheriting the `ProcessModule` pattern:

```
Application
  └── ModuleProcess (generic shell: signals, EventLoop, PgPool)
        └── <Name> (ProcessModule: business logic only)
```

The shell handles lifecycle; the project's class only contains domain logic. Heartbeat (1 sec) drives periodic work.

### Configuration Profiles (e.g. shore vs edge)

For projects that deploy in multiple modes (e.g. shore + edge), keep multiple JSON configs:

```
conf/default.shore.json   — workers=8, all worker modules, shore-only processes
conf/default.edge.json    — workers=2, edge-only processes (NMEA, Modbus, ESign, ...)
```

Select at runtime: `./<binary> -c conf/default.<profile>.json`. Same binary, different profile.

### Drop Privileges (production)

```json
{
  "process": {
    "user": "<app-user>",
    "group": "<app-user>",
    "limit_nofile": 65536
  }
}
```

After binding ports, the process drops to `<app-user>`. Mandatory for production security.

### Hot Reload (SIGHUP)

`./<binary> -s reload` re-reads JSON, re-expands env vars, calls `on_reload` hook, rolling-restarts workers. **Port/listen/backlog changes require full restart** (the socket is already bound).

---

### Facts of the v2 stack (measured on one project's pins — check yours)

- **One key starts a module and its namesake process.** `Application::module_enabled(name)` reads
  `module.<Name>.enable` (libapostol `src/core/application.cpp:95–97`), and both `Workers.hpp` and `Processes.hpp` ask it
  by the same name: enabling "only the module" starts the process too.
- **`http.create_request` creates the request in `state 1`** (`platform/http/routine.sql:106–107`); `0` is only the
  table default. `state 1` without a response means "not delivered", not "in PGFetch's hands".
- **PGFetch callbacks** (`Helpers/PGFetch`, pin `60ba319`, 30.09.2026 — the contract changed three times that week, read
  `PGFetch.cpp` `do_done` / `do_fail` of your pin): `done` and `fail` are `schema.func` names, called as
  `SELECT schema.func('<id>')` (`:573`) and `SELECT schema.func('<id>', '<message>')` (`:622`) — untyped literals, so
  the **arity** must match: a `fail` declared `(uuid)` is never called (one project had 12 such callbacks). The
  callback runs in one transaction with the stored response / fail mark; if it throws, both roll back and the request
  is stored again as failed with the reason. On the pin of 28.09 a callback error was swallowed.
- **A request sent twice.** Without `http.take` (db-platform 1.2.31) two helpers can pick the same request by id — the
  far end sees two calls, `http.response` holds one. PGFetch uses `http.take` where it exists
  (`to_regprocedure('http.take(uuid)')`, `PGFetch.cpp:167`).
- **PgPool gives no order between its connections.** Two `execute` calls in a row may commit in either order; order per
  object is the caller's (a queue by key). A query lost with its connection after it was sent whole is **not** resent
  by default since libapostol `f697776` (`PgRetry::never`, `include/apostol/pg.hpp:100–116`); `PgRetry::if_lost`
  resends — the old behaviour — and is chosen at the call site where a repeat is harmless.
- **`PgPool::cancel()`** runs on its own loop-driven connection only with libpq ≥ 17 (`LIBPQ_HAS_ASYNC_CANCEL` from
  `libpq-fe.h`); with an older libpq it is a blocking `PQcancel` on the event loop (`include/apostol/pg.hpp:215–228`,
  libapostol `82e7485`). Until the cancel is done, the connection takes no other query.
- **`exec_sql()` answers errors itself** (`src/pg/pg_exec.cpp:12–36`): an SQL error, a lost connection or a query
  stranded at stop go to its `on_exception`, which sends HTTP 500 `{"error":{…}}` — a `!ok()` branch in the result
  handler is dead. A module whose answers must keep their own form does not use it. JSON error rows the platform returns
  from its own catch blocks are still `ok()`, so a check on them stays live.
- **`PgPool::execute()` can throw** — opening a connection or re-arming epoll fails — and then no callback follows
  (libapostol `src/pg/pg.cpp:1275–1284`). State set before the call and cleared only in the callback (a flag, a map
  entry, a slot count) then hangs forever. Catch **around the call**, not around the whole function, and release the
  state there. An exception from an I/O callback is caught by `dispatch_io`; a timer callback runs without `try`
  (`src/core/event_loop.cpp:217–225`, `:455`).
- **A dedicated `postgres.log` is written at debug whatever `log.level` says** (`src/core/application.cpp:2083–2091`):
  every statement text lands in it; without the file, statements go to stderr at `log.level`. A query that carries a
  secret literal is sent `quiet` (`PgQuery(sql, true)`, `exec_sql(…, quiet)`) — quiet also keeps the statement out of the
  error text.
- **`fetch.deny_internal` / `fetch.allow`** (off by default) filter only `CurlClient` and the built-in `HttpClient` — and
  `FetchClient`, which wraps them; not `HttpProxy`, not WebSocket clients (`include/apostol/fetch_policy.hpp`). In `allow`
  a name matches the URL host, an IP or CIDR the dialled address, an optional `:port` the port. Before you add an `allow`,
  find who actually dials the address.
- **PGHTTP passes request headers to SQL with the sender's spelling of each name** (`src/pg/pg_utils.cpp:202–208`). C++
  lookups ignore case, `->>'X-Real-IP'` in SQL does not: read both spellings. In a security function "`NULL` = skip the
  check" is a trap — refuse at the door when the header is absent. A webhook handler reachable over PGHTTP is often
  reachable over REST too: a check on one road costs nothing if the other is open to anonymous callers.
- **The observer pays per element × per subscriber.** A function it calls per notification is measured under the
  publisher's load, not as a one-off call; hoist session lookups such as `current_locale()` out of per-row joins.
- **Background roles may have their own path to the base.** Helper and custom-process pools can connect to PostgreSQL
  directly while workers go through pgbouncer — a project setting (e.g. `postgres.helper.host` pointing past pgbouncer); attribute a query in the postgres log to its process by `%r`.
  `max_connections` then covers the pooler's server limit, every direct connection and `superuser_reserved_connections`:
  raising one limit without the others moves the refusal elsewhere.
- **Watching a background role from SQL.** A role without `pg_read_all_stats` sees other roles' sessions in
  `pg_stat_activity` as `<insufficient privilege>`, and the platform grants no `pg_*` role — a watcher running as
  `kernel` is blind to `apibot`. Judge a consumer alive by whether it takes work (a request taken, a row answered).

### Process lifecycle (libapostol `82e7485`, `src/core/application.cpp`)

- **Custom processes run only under a master.** With `process.master: false` no custom process runs; with
  `process.helper: true` the process is a helper (it may lead, and warns that it has no master), otherwise it runs worker
  modules only (`:304–391`, `:1207–1293`, `:1442`, `:1660`).
- **The master respawns every child that exits**, whatever its exit code, with a back-off that grows to 30 s and never
  stops (`:1774`, `:1849–1873`). A refusal inside a worker — a throw from a module constructor or `on_start` —
  becomes a respawn loop, not a stopped service: validate configuration in the master, and in a worker only log.
- **Leadership of background roles.** The key is `module.<process name>.leader` — the custom process's own name
  (`task-scheduler`, `message-server`, `report-server`), defaulting to `process.leader` (false). `module.<ClassName>.leader`
  is accepted at load and does nothing, while `enable` is read under the class name (`module.TaskScheduler.enable`).
  The helper follows `process.leader` only; workers never lead (helper `:1442`, custom process `:1588`, `:1637–1683`). The lock is a session advisory
  lock on a dedicated connection opened with the helper's conninfo. A lost lock is logged, the process stops normally
  with exit code 1, and the master respawns it as a standby: enabling a leader on a single instance adds that stop path.
- **Stop order of a worker:** HTTP server stopped → `on_stopping()` (heartbeat off; `ModuleManager::stopped()` is true
  from here) → LISTEN muted → finishing work (queries, HTTP answers, `busy()`; budget `process.stop_timeout` − 3.5 s, at
  least 1.5 s) → `quiesce()` → `detach_db` → `on_stop()` → `drain_db` (only queries sent from some `on_stop`, at most
  1.5 s) → `stop_db`. A module that decides "stopping has begun" looks at `stopped()`, not at `quiesce()`.
- **Stop deadlines.** The master sends SIGKILL `process.stop_timeout` seconds (default 5) after its own SIGTERM; a
  graceful SIGQUIT arms no timer. A container's stop deadline (`stop_grace_period`) must exceed `process.stop_timeout`,
  or the runtime kills the process first and the log shows no cut-short stop.
- **Workers are processes.** Module state in memory — a registry of sockets, a cache — belongs to one worker: with
  N > 1 each worker sees only its own, and the cluster's truth is in the database. All workers share one listening socket
  inherited from the master; with edge-triggered epoll and several workers, a worker holding more live connections than
  the least loaded one defers its accept (`82e7485`). Distribution is not round robin: measure it over several rounds.
- **Booleans in the config.** `Config::get_bool` takes the strings `true|false|1|0|yes|no|on|off` (trimmed, any case);
  a missing key, `null` or an empty string give the default, a JSON number `1` throws (`src/config/config.cpp:253–295`) —
  an empty value from `envsubst` means "default".
- **The libpq environment reaches every connection of the process** — pool, LISTEN connection, leader session.
  libapostol sets `host`/`port`/`dbname`/`user`/`password`/`sslmode` from `PG*` itself, and libpq fills every other unset
  keyword from the service file and the environment (`PGSERVICEFILE`, `PGCONNECT_TIMEOUT`, `PGOPTIONS`, …)
  (`src/core/settings.cpp:196–366`). A setting tuned for the pool (`tcp_user_timeout`) also bounds the leader lock.
- **A project's `./configure` may update the submodules** (`git submodule update --init --recursive`, to the pins):
  building against an unpushed submodule change resets it to the pin. Read the script for its skip option and compare the
  submodule's `HEAD` after the build.

## Step 12 — Replication (Distributed Deployment)

For projects with shore↔edge or master↔replica topology (e.g. ship ↔ shore).

**Critical:** Apostol Replication is **app-level**, not native PostgreSQL logical replication wire-protocol.

> **Read before relying on anything below (verified 2026-09, `inventory/mechanisms/sync.md`).** The
> diagram describes the **design**, not the installed platform. `process-Replication` (C++) calls
> `replication.drain/fetch_outbox/apply_batch/ack` and POSTs to `/replication/sync` — **none of
> those exist in db-platform 1.2.20** (nor at 1.2.31, `grep outbox platform/replication` → empty); there is no `replication.outbox`, no `peer`, no priority
> column in `replication.list`. What exists is the older trigger-log path (`replication.log` /
> `relay` / `apply_relay`), which the C++ falls back to, and it is **enabled in no project**. The
> successor is module **`mq`** (1.2.17+: lanes, watermarks, dead letters, 31 routes) — complete in
> SQL and **without any consumer**: no `process-MQService` upstream, zero callers in all seven
> configurations, zero rows in production. A project that needs inter-instance sync today is doing
> framework work: route it through `/apostol`, and do not design a slice on the assumption that
> either subsystem delivers.

```
[Application] → INSERT/UPDATE/DELETE → [PostgreSQL WAL]
                                         │
[Publication: apostol_repl]              │
[Slot: apostol_repl]   ◄─────────────────┘
      │
[ReplicationServer.drain_slot()]
      │  pg_logical_slot_get_changes() → wal2json
      ▼
[replication.outbox]   ← priority from replication.list
      │
[sync()] ── FetchClient POST → remote /replication/sync
      │
      ▼
[apply_batch()] → INSERT/UPDATE/DELETE (DEFERRED constraints)
```

**Three modes:** `automatic` (heartbeat), `paused` (accumulate only), `manual` (only on NOTIFY command).

**Three channels** with different intervals and priority filters:

| Channel | Interval | Priority filter | Tables sent |
|---------|----------|-----------------|-------------|
| `lan` | 30s | all (1+2+3) | Everything |
| `wifi` | 60s | high+medium (1+2) | Most |
| `satellite` | 300s | high only (1) | Critical only |

`replication.list` table assigns priority per table. Switching channels at runtime:

```sql
NOTIFY replication_cmd, '{"action":"channel","channel":"satellite"}';
```

**PostgreSQL prerequisites** for Replication:

```
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10

CREATE PUBLICATION apostol_repl FOR ALL TABLES;
SELECT pg_create_logical_replication_slot('apostol_repl', 'wal2json');
```

**Per-batch signing** (e.g. ed25519 for auditability) is **not platform default** — projects that need it must add custom payload signing in their fork of Replication or via observer hook.

---
