<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. Split verbatim from SKILL.md on 28.09.2026 (SERP T338; owner words: SERP DECISIONS.md 28.09, CSMS DECISIONS.md:6687). -->
## Step 5 — Module Pairing & LISTEN/NOTIFY

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
| **TaskScheduler** | Process | scheduler / api.job | poll | scheduled SQL execution (cron) |
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
| Push to client | WebSocketAPI | `POST /ws/<code>` with any body |
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
| `notify` | (observer) | object state transitions |
| `replication` | (observer) | replication entry created |
| `replication_cmd` | Replication | operator command (mode/channel/sync) |
| (any project-defined) | WebSocketAPI dynamic | `pg_notify(channel, payload)` for project pub/sub |

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
| `single` (default) | `process.master=false` | Everything in one process |
| `master` | `process.master=true` | Supervisor (forks, signals, crash recovery) |
| `worker` (N) | `workers: N` | HTTP/WebSocket — registered modules |
| `helper` (1) | `process.helper=true` | PGFetch/PGFile background |
| `custom` (N) | `add_custom_process()` in `main.cpp` | TaskScheduler, MessageServer, Replication, project-specific (NMEA, Modbus, ESign, Print, ...) |
| `signaller` | CLI `-s stop|quit|reload|reopen` | Signal sender, exits |

### Project-Specific Custom Processes

When a project needs a custom background process (e.g. ship-safety needs `process-NMEA`), it's written **in the project repo** under `backend/src/processes/<Name>/`, inheriting the `ProcessModule` pattern:

```
Application
  └── ModuleProcess (generic shell: signals, EventLoop, PgPool)
        └── <Name> (ProcessModule: business logic only)
```

The shell handles lifecycle; the project's class only contains domain logic. Heartbeat (1 sec) drives periodic work.

### Configuration Profiles (e.g. shore vs edge)

For projects that deploy in multiple modes (Ship Safety: shore + edge), keep multiple JSON configs:

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

### Facts from the ratings of 28–30.09.2026 (v2 stack; measured on the apostol-csms pins — check yours)

- **One key starts a module and its namesake process.** `Application::module_enabled(name)` reads
  `module.<Name>.enable` (libapostol `src/core/application.cpp:95–97`), and both `Workers.hpp` and `Processes.hpp` ask it
  by the same name: enabling "only the module" starts the process too (apostol-csms `LicenseServer`: `Workers.hpp:36`,
  `Processes.hpp:42`).
- **`http.create_request` creates the request in `state 1`** (`platform/http/routine.sql:106–107`); `0` is only the
  table default. `state 1` without a response means "not delivered", not "in PGFetch's hands".
- **PGFetch callbacks** (`Helpers/PGFetch`, pin `60ba319`, 30.09.2026 — the contract changed three times that week, read
  `PGFetch.cpp` `do_done` / `do_fail` of your pin): `done` and `fail` are `schema.func` names, called as
  `SELECT schema.func('<id>')` (`:573`) and `SELECT schema.func('<id>', '<message>')` (`:622`) — untyped literals, so
  the **arity** must match: a `fail` declared `(uuid)` is never called (apostol-csms T582 — 12 such callbacks). The
  callback runs in one transaction with the stored response / fail mark; if it throws, both roll back and the request
  is stored again as failed with the reason. On the pin of 28.09 a callback error was swallowed (csms-qa, T594).
- **A request sent twice.** Without `http.take` (db-platform 1.2.31) two helpers can pick the same request by id — the
  far end sees two calls, `http.response` holds one. PGFetch uses `http.take` where it exists
  (`to_regprocedure('http.take(uuid)')`, `PGFetch.cpp:167`).
- **PgPool gives no order between its connections.** Two `execute` calls in a row may commit in either order; order per
  object is the caller's (a queue by key). A query lost with its connection after it was sent whole is **not** resent
  by default since libapostol `f697776` (`PgRetry::never`, `include/apostol/pg.hpp:100–116`, T627); `PgRetry::if_lost`
  resends — the old behaviour — and is chosen at the call site where a repeat is harmless.
- **Background roles may have their own path to the base.** Helper and custom-process pools can connect to PostgreSQL
  directly while workers go through pgbouncer — a project setting (apostol-csms: `postgres.helper.host = $PGHOSTAPI`,
  `backend/docker/conf/default.json:125`); attribute a query in the postgres log to its process by `%r`.

## Step 12 — Replication (Distributed Deployment)

For projects with shore↔edge or master↔replica topology (Ship Safety, PlugMe).

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

**Per-batch signing** (e.g. ed25519 for auditability) is **not platform default** — projects that need it (Ship Safety) must add custom payload signing in their fork of Replication or via observer hook.

---
