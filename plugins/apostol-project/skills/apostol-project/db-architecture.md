<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 6 — Database Architecture

### Two-Layer Design

```
db/sql/
  platform/        ← Framework (28 modules at 1.2.31 — DO NOT EDIT)
  configuration/
    <dbname>/      ← Project business logic (EDIT HERE)
```

Execution order: **always platform first, then configuration.**

```
--install  →  platform/create.psql  →  configuration/create.psql    (DESTRUCTIVE)
--update   →  platform/update.psql  →  configuration/update.psql    (safe: CREATE OR REPLACE only)
--patch    →  platform/patch.psql   →  platform/update.psql
            → configuration/patch.psql → configuration/update.psql  (non-destructive DDL)
```

### Database Commands

```bash
cd db/
./runme.sh --init        # First-time: creates users + database + install
./runme.sh --update      # Safe: routines/views only (CREATE OR REPLACE)
./runme.sh --patch       # Tables + routines (non-destructive DDL via patch/)
./runme.sh --install     # DESTRUCTIVE: drop and recreate everything
```

### Schemas

| Schema | Purpose | Prefix needed in queries? |
|--------|---------|:---:|
| `db` | All tables (DDL) | Yes: `db.client`, `db.network` |
| `kernel` | Core business logic functions | No (in `search_path`) |
| `api` | API-facing views + CRUD wrappers | Yes: `api.get_client()`, `api.client` |
| `rest` | REST endpoint dispatchers | Yes: `rest.client(...)` |
| `oauth2` | OAuth2 infrastructure | Yes |
| `daemon` | C++ ↔ PL/pgSQL interface | Yes |
| `http` | HTTP module (PGHTTP/PGFetch) | Yes |
| `observer` | Pub/sub system | Yes |
| `replication` | App-level outbox + sync | Yes |

### Database Users (PG roles)

| User | Connects from | Purpose |
|------|---------------|---------|
| `kernel` | DDL scripts | Schema owner; SECURITY DEFINER functions run as this |
| `admin` | Admin tools | Application administrator |
| `daemon` | Worker processes | HTTP request handling (AppServer, AuthServer, etc.) |
| `apibot` | Helper / Custom processes | Background tasks (PGFetch, MessageServer, Replication, ...) |

### Platform Module Groups (28 at 1.2.31)

| Group | Modules |
|-------|---------|
| **Core** | `kernel` (types/JWT helpers), `oauth2`, `locale`, `admin` (users/auth/sessions/ACL), `exception`, `error` (the `ERR-GGG-CCC` catalog, 80 codes × 6 locales) |
| **Infrastructure** | `http`, `resource`, `registry`, `log`, `api` (REST routing helpers), `replication`, `daemon`, `gateway` (the GatewayAPI schema, since 16.09.2026) |
| **Session context** | `session` (setters: SetSessionUser, SetSessionArea, ...), `current` (getters: current_userid, current_locale, current_area, current_scope, current_session, ...) |
| **Business** | `workflow` (state machine: 23 tables), `entity` (object hierarchy: 27 tables), `file` (VFS + S3), `kladr` (tables empty in every known deployment), `mq` (store-and-forward between instances: 10 tables, 31 routes — **no C++ consumer and no caller anywhere yet**) |
| **Communication** | `notice`, `comment`, `notification`, `verification` (codes), `observer` (pub/sub) |
| **Reporting** | `report`, `reports` |

### Module load order (fixed dependency chain)

`platform/create.psql` and `update.psql` load modules in this exact order — your `configuration/<dbname>/` runs after all of them:

```
kernel → oauth2 → locale → admin → http → resource → exception → error
  → registry → log → api → replication → daemon → session → current
  → workflow → kladr → file → entity → mq → notice → comment → notification
  → verification → observer → report → reports
```

Knowing this matters when you reference a platform function from your configuration: it's guaranteed loaded if the module appears before `entity` (or before whatever you depend on). Don't reorder — dependencies break.

### UUID generation

Always use `gen_kernel_uuid()` (platform helper) for primary keys, never `gen_random_uuid()` directly. What it actually does (`kernel/general.sql`): `gen_random_uuid()` and, if a 1-char prefix is given (`gen_kernel_uuid('8')`), overwrites position 20 of the text form with it — an origin tag, not a salt and not a v7 ordering. Identifiers are random; there is no deterministic component.

### Patches and migrations (production)

For DDL changes after install, write a patch:

```
configuration/<dbname>/patch/v<major>.<minor>/P<8-digit>.sql
```

Example: `configuration/crm/patch/v1.0/P00000078.sql`. Uncomment in `patch/patch.psql` to activate.

**`migrate.sh`** is the automatic patch runner — preferred over manual `runme.sh --patch`. **Use the project's `db/migrate.sh`** (phase splitting, `db.patch_log`); the copy in `db/sql/platform/migrate.sh` is an older, shadowed variant still advertised by `platform/CLAUDE.md` — do not run it:

```bash
./migrate.sh             # apply unapplied patches + update routines   (from <project>/db/)
./migrate.sh --status    # show applied vs pending patches
./migrate.sh --dry-run   # preview without applying
./migrate.sh --baseline  # mark all patches as applied without executing
```

Tracks state in `db.patch_log` table. The `PSQL` env var overrides the default `sudo -u postgres -H psql` connection (useful in CI/Docker).

#### `runme.sh --patch` vs `migrate.sh` — they discover patches differently

This bites in CI: a patch can pass locally but break production (or vice versa).

- **`runme.sh --patch`** loads `configuration/<dbname>/patch/patch.psql`, which contains explicit `\ir Pxxxx.psql` directives. **Commented-out** `--\ir` lines are skipped. So uncommenting controls what runs locally.
- **`migrate.sh`** (used by Docker `db-migrate` containers in production) **scans the directory** with `find P*.psql`. It **ignores** the comment status in `patch.psql` — every file in the patch dir is a candidate.

Implication: a patch you only "intended" to expose locally will run on every production deploy regardless of `patch.psql` comments. Don't leave half-finished patch files in the directory.

#### Schema permissions in patches

The `kernel` user owns schemas `db`, `kernel`, `api`, `rest`, etc. and has DDL on all of them. **`admin` does NOT have DDL on `db`** — it can run application logic (SignIn / OAuth / RegSetValueString / api.run) but not `ALTER TABLE db.foo`.

- Patch is **DDL-only** (CREATE INDEX, ALTER TABLE, CREATE FUNCTION) → run as kernel, **no `\connect`** at all. The patch starts in kernel context and stays there.
- Patch needs **authenticated session** (RegSetValueString, SignIn-protected routines, api.run) → `\connect :dbname admin` + `SignIn(CreateSystemOAuth2(), 'admin', :'admin')` + the body + `SignOut()` + `\connect :dbname kernel` to return.

Mixing `\connect admin` with `ALTER TABLE db.<x>` is the classic "нет доступа к схеме db" failure.

#### Patch names collide silently

`db.patch_log` is keyed by the patch **path** (`config/<dbname>/<ver>/P….psql`), not by its content. If two branches both
take the next number, every base that ran the first skips the second silently (`Applied: 0`, exit 0). Take the number
right before push, against the remote's master. To repair a base that recorded the wrong patch under the name: delete its
`patch_log` row and run `migrate.sh` again.

#### Phased execution of `\connect`-bearing patches

`migrate.sh` splits any patch containing `\connect` into phases at each boundary, executes them as separate psql invocations, and **checkpoints each phase** as `<patch_name>#<n>` in `db.patch_log`. A failure in phase 2 leaves phases 0..1 marked applied; on retry, only phase 2+ re-runs.

Single-phase patches (no `\connect`) are tracked as plain `<patch_name>`. If you change a multi-phase patch into single-phase later, you'll get an orphan `<patch_name>#0` row in `patch_log` — harmless, just noise. Clean up manually if it bothers you:

```sql
DELETE FROM db.patch_log WHERE name LIKE 'config/<dbname>/P00000012#%';
```

### Triggers on platform tables; hooks that see only an id

- **Platform `Do*` hooks receive only the id** — no old values (`EditArea` → `DoUpdateArea(pId)`,
  `platform/admin/routine.sql:5157`, `admin/do.sql:70`). A sync "platform entity → configuration object" written in such
  a hook copies the whole record and reverts edits made from the object's side. When you need OLD / NEW, write a
  configuration trigger on the platform table.
- **Such a trigger goes in a patch**: `--update` does not run `table.sql`, so a trigger declared there never reaches an
  existing base.
- **`CREATE OR REPLACE TRIGGER`** (PostgreSQL 14+), not `DROP TRIGGER` + `CREATE TRIGGER`: `DROP TRIGGER` takes ACCESS
  EXCLUSIVE on the table — on `db.object` every read of the base queues behind it. Set `lock_timeout` in the patch.
- **BEFORE triggers of one table fire in alphabetical order of their names** (PostgreSQL) — the name decides whether the
  platform's own checks have already run.
- **Guard in the re-run function, or a trigger?** If every write goes through `Edit<X>` (a re-run file), put the guard
  there — no patch, no DDL. A trigger is for writes that bypass that function, and it goes in a patch. To change a rule
  without changing a signature, add a new core function and keep the old name as a wrapper with its old signature — no
  overload, no patch.
- **Close a bypass at the field's only writer**, not in its readers: find who writes the field after creation and put the
  door there. A refusal inside a reprocessing loop that has one `EXCEPTION` block rolls back every item of the pass —
  refusals belong at the doors, not in the batch.

### Where a document is born (area)

A document's area is stamped at birth from `current_area()` = `coalesce(GUC current.area, the session's area, guest)`
(`admin/routine.sql:2910`; `CreateDocument`, `entity/object/document/routine.sql:96`, 1.2.35). Code running in a system or
background session creates documents in **that session's** area unless it calls `SetCurrentArea` first — and restores it
on every exit (`facts-2026-09.md` § Context and session). That area is often the default one, which makes the document visible to the
whole scope (`access-control.md` § DocumentAreaTree). To tell "born here" from "moved here", read the object's `db.log`
trajectory.

### Tenant ↔ Area relationship (multi-tenant pattern)

> **`FillDataBase()` runs only on a fresh install, never on `--update`.** Anything you put there —
> class rights, groups, scheduled jobs, seed rows — will **never appear on an existing database**,
> while the edit itself looks like any other. Changing `FillDataBase` therefore requires a patch as
> well, or the change exists only for installations created after it. This is a silent divergence
> between a fresh install and an updated one, and it is the same family as the next trap.

> **`CREATE OR REPLACE VIEW` cannot change the column list** — it only appends at the end. So a
> view whose columns you reordered or dropped installs cleanly from scratch and **fails on
> `--update` over an existing database**. The two roads diverge quietly: CI on a fresh database
> stays green while every deployed instance breaks.

> **`db.patch_log` is created by `migrate.sh`, not by `install.psql`.** After `--init` the first
> command is `migrate.sh --baseline`, otherwise the migrator considers every patch unapplied and
> replays them over a schema that already contains them.

Areas are **NOT seeded in `FillDataBase`**. They are created automatically through the tenant lifecycle:

1. `CreateTenant(pParent, pType, pCode, ...)` creates the tenant `client` row + corresponding `db.area` row with the same `code` (typically inside `EventTenantCreate` or `routine.sql`).
2. `EventTenantEnable` adds the tenant's user to the area (`AddMemberToArea`), sets default area, assigns interfaces.
3. `current_tenant()` resolves: `SELECT id FROM db.client c INNER JOIN db.area a ON a.code = c.code WHERE c.tenant AND a.id = current_area()`.

Convention: **`tenant.code = area.code`**. Vessel area is a child area under tenant area (created the same way: `CreateVessel` → `CreateArea(parent=tenant_area)`).

When migrating multi-tenant designs from other systems: don't try to seed areas before tenants exist. Create the demo tenant in `FillDataBase` and let the event handlers do the rest.

---
