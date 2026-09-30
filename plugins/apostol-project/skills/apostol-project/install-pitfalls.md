<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. Split verbatim from SKILL.md on 28.09.2026 (SERP T338; owner words: SERP DECISIONS.md 28.09, CSMS DECISIONS.md:6687). -->
## Step 16 — Pitfalls discovered during live install

### Q. `db.user` holds users *and* groups

`username` is not unique between them — the unique index is on the pair `(type, username)`. A
subquery matching by name alone fails with "more than one row returned", and the message points at
the subquery, saying nothing about groups. Filter by `type = 'U'`.

### R. Column/variable ambiguity in PL/pgSQL is not caught at creation

It fails at **runtime**. In a function with an `OUT id` parameter, `WHERE id = …` resolves to the
parameter, and the function is created happily — `--update` passes, the first real call breaks.
Alias the table.

### S. The platform text is only half the picture

Projects override `CheckObjectAccess` and `CheckObjectMethodAccess` in
`configuration/<dbname>/admin/routine.sql` — that is, they change the semantics of exactly the
functions you would read to judge security. **Reading `sql/platform/` in isolation produces
confident wrong conclusions in both directions**: a barrier that looks absent may be enforced by
the project layer, and a barrier you rely on may live in an override that a platform run can
overwrite. Grep the configuration layer before concluding anything about access, and guard an
override with a test rather than with hope.



These are battle-tested gotchas — every one caused a failed `runme.sh --init` for an agent that didn't know about them. Memorise before starting any new entity/configuration.

### A. `SELECT InitConfiguration()` does NOT belong in `configuration/<dbname>/init.sql`

`configuration/<dbname>/init.sql` only **defines** `InitConfiguration()` and `FillDataBase()`. The actual call lives in **top-level** `db/sql/configuration/init.sql`:

```sql
SELECT SignIn(CreateSystemOAuth2(), 'admin', :'admin');
SELECT InitConfiguration();
SELECT SignOut();
```

Why: `configuration/<dbname>/init.sql` is loaded during the **DDL create phase**, before `platform/init.sql` runs. Calling `InitConfiguration()` here fires `CreateEntity*() → CreateClass*() → AddDefaultMethods() → DefaultMethods() → AddMethod(GetAction('create'), ...)` — but `db.action` is still empty, `GetAction('create')` returns NULL, install crashes on NOT NULL violation.

Top-level `configuration/init.sql` runs in the seed phase, after `platform/init.sql` populated `db.action` (54 rows), `db.entity` (16 rows), `db.state_type` (4 rows), default areas. **Then** your `InitConfiguration()` runs.

### B. `DoEnable(pObject)` in `EventCreate` causes `MethodActionNotFound`

csms `EventCountryCreate` ends with `PERFORM DoEnable(pObject);` to auto-activate seeded refs. **Current platform: parent class events already transition `created → enabled` via `ExecuteMethod(create)`.** Your DoEnable then fires `enable` on already-enabled object → `ERR-400-032: Object [...] method not FOUND, for action: enable. Current state: enabled.`

Fix: drop `DoEnable(pObject)` from `EventCreate`. Reference rows are `enabled` after creation regardless — `Object<Entity>` view returns them through `Access<Entity>` based on AOU permissions, not state.

### C. `AddAction()` is 4-arg with pre-assigned UUID, namespace `b003`

```sql
AddAction(pId uuid, pCode text, pName text, pDescription text DEFAULT null) RETURNS uuid
```

Platform actions occupy `00000000-0000-4000-b003-000000000000+` (54 of them). Configuration projects reserve their own slot — ship-safety uses `b003-000000000100+`. Use **fixed UUID**, not `gen_kernel_uuid()` — actions need cross-install reproducibility for regulatory binary-hash audit.

```sql
PERFORM AddAction(
  '00000000-0000-4000-b003-000000000100'::uuid,
  'correction',
  'Correction',                                       -- EN name (default for all locales)
  'Append-only journal entry correction event.');

PERFORM EditActionText(
  GetAction('correction'),
  'Корректировка',                                    -- name in target locale
  'Событие корректировки append-only записи.',         -- description in target locale
  GetLocale('ru'));
```

`EditActionText` is **4-arg** `(action, name, description, locale)`. csms sometimes uses 3-arg form — production-correct is 4-arg.

### D. `SetSessionLocale('en')` before any `AddMethod`/`AddState`/`AddType`

```sql
PERFORM SetSessionLocale(GetLocale('en'));
PERFORM InitConfigurationEntity();
PERFORM Init<Reference>();   -- seed data
PERFORM FillDataBase();
PERFORM SetSessionLocale(GetLocale(current_setting('project.locale')));   -- restore at end
```

Why: `AddMethod`/`AddState`/`AddType` copy `GetActionName(action)` (or label) **for `current_locale()`** into every `db.locale` row at insert time. Registering under `ru` would copy Russian into the en/de/fr/it/es rows of `method_text`. Switching to `en` first keeps non-EN rows clean — `EditClassText`/`EditTypeText`/`EditMethodText` then explicitly sets ru/de/fr/it/es with proper translations.

### E. PL/pgSQL function call is ONE transaction unit

`SELECT InitConfiguration();` (one psql statement, one PL/pgSQL function call) wraps the **entire** function body in one transaction. If anything inside raises — duplicate UN/LOCODE, NULL action, FK violation — **all function work rolls back**, including the early `AddAction('correction')` that already succeeded.

Symptom: after failed `runme.sh --init`, `db.action count = 54` (just platform seed) instead of `55` (with custom action), even though `AddAction` ran first in function.

Implication: **validate uniqueness manually before install** — duplicate codes/UN/LOCODEs/alpha2 waste full install cycles. Quick grep:

```bash
grep -oE "'RU[A-Z]{3}'" entity/object/reference/port/init.sql | sort | uniq -c | awk '$1 > 1'
```

### F. Required env bundle: `db/sql/.env/<dbname>/`

`sets.psql` does `\ir './.env/.env.psql'` — per-database dispatcher resolving via `\set dbname`. Required structure:

```
db/sql/.env/
├── .env.psql                — dispatcher: \ir ./:dbname/.env.psql
└── <dbname>/                — e.g. csms/, ship_safety/
    ├── .env.psql            — bundle: \ir passwords + \ir oauth2 + project.* GUCs
    ├── passwords.psql       — \set kernel/admin/daemon/apibot + set_config('password.*')
    └── oauth2.psql          — set_config('secret.web/service/android/ios/...')
```

**Gitignored** — passwords/secrets never go to git. Each developer/brand maintains their bundle locally; production uses ansible-vault / Vault. Skeleton stage projects often forget — symptom: `psql: ERROR: file ".env/.env.psql" does not exist` on `runme.sh --init`. Always create before installing.

### G. `configuration/<dbname>/oauth2.sql` is required, not optional

Platform `init.sql` calls `CreateSystemOAuth2()` which expects a **system audience** (audience.code = `current_database()`, secret from `GetSecretKey()`). If `configuration/<dbname>/oauth2.sql` is empty, `CreateSystemOAuth2()` returns NULL → `db.oauth2` insert fails on `audience NOT NULL`.

Minimum viable structure: `AddAlgorithm` (HS256/384/512) → `AddProvider` (system + default internal) → `AddApplication` (system/service/web/android/ios) → `AddIssuer` (default) → `CreateAudience` × 5 (system + service/web/android/ios reading secrets from `current_setting('secret.*')`) → `AddMemberToGroup` for created users. Runs **during DDL create phase**, before workflow seeds — don't try to call `GetAction()`/`AddDefaultMethods()` from oauth2.sql.

### H. `configuration/<dbname>/make.psql` is required (even if empty)

`configuration/make.psql` does `\ir ./<dbname>/make.psql`. If file missing: `psql: ERROR: file "configuration/<dbname>/make.psql": No such file or directory`. Create at minimum a placeholder. csms uses this for domain modules (ocpp/make.psql, ocpi/make.psql).

### I. Default 5 areas auto-created on install

After `runme.sh --init`, `db.area` contains:

| code | UUID | meaning |
|---|---|---|
| `root` | `a000-000000000000` | корневая |
| `system` | `a000-000000000001` | system |
| `guest` | `a000-000000000002` | guest |
| `all` | `a001-000000000000` | superset |
| `<dbname>` | `a001-000000000001` | project default (= PGDATABASE) |

Tenant areas + vessel areas are **NOT seeded** — created via tenant/vessel client lifecycle (`EventTenantEnable`, `EventVesselEnable`). Don't seed in `FillDataBase` before entity classes registered.

### J. Reference view requires `r.scope = current_scope()` filter

```sql
FROM db.<entity> t INNER JOIN db.reference r ON t.reference = r.id AND r.scope = current_scope()
```

Without scope filter, view returns rows from **all** project scopes (multi-brand deployments leak cross-brand data). `db.reference.scope` is the multi-tenant boundary at reference layer; documents use area-based scoping (DocumentAreaTree) instead.

### K. `Get<Entity>(pCode)` wraps `GetReference(pCode, '<entity>')`

For references, canonical code-to-uuid lookup:

```sql
CREATE OR REPLACE FUNCTION GetFlagState(pCode text) RETURNS uuid
AS $$ BEGIN RETURN GetReference(pCode, 'flag_state'); END; $$
LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER SET search_path = kernel, pg_temp;
```

`pCode` is the **full reference code** (`'ISO 3166-1:RU'`), not short alpha-2. For UI lookup by short form, add separate `Get<Entity>By<Field>(pField)` (e.g. `GetFlagStateByAlpha2('RU')`). Then `api.get_<entity>_id(pCode)` tries short form first, falls back to full ref code.

### L. BEFORE INSERT trigger normalises codes

For references with case-sensitive standards (UN/LOCODE, ISO 3166):

```sql
CREATE OR REPLACE FUNCTION db.ft_port_insert() RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN SELECT NEW.reference INTO NEW.id; END IF;
  NEW.unlocode := upper(NEW.unlocode);   -- UN/LOCODE standard requires uppercase
  NEW.country  := upper(NEW.country);
  RETURN NEW;
END $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, pg_temp;
```

Without normalisation, mixed-case seeds break unique indexes (`'rusp'` vs `'RUSP'`).

### M. The full configuration directory tree dispatch chain

```
configuration/<dbname>/create.psql
  └─ \ir './entity/create.psql'
       └─ \ir './object/create.psql'
            ├─ \ir './reference/create.psql'
            │    └─ \ir './<entity>/create.psql'  (table+view+routine+api+rest+event+init)
            └─ \ir './document/create.psql'
                 └─ \ir './<entity>/create.psql'
       └─ \ir init.sql                — entity/init.sql defines InitConfigurationEntity()
  └─ \ir oauth2.sql                   — audiences (Pitfall G)
  └─ \ir routine.sql                  — shared routines
  └─ \ir init.sql                     — defines InitConfiguration() + FillDataBase() (Pitfall A)
```

`update.psql` mirrors but excludes `table.sql` and `init.sql` per entity. Each subdirectory needs both `create.psql` and `update.psql`, even if just `\ir` lines for child entities.

### N. csms version drift on small details

`apostol-csms` has patterns **correct for older platform** but broken now:

| csms pattern | Current behaviour |
|---|---|
| `EventCountryCreate { ...; PERFORM DoEnable(pObject); }` | DoEnable double-fires; remove it (Pitfall B) |
| `EditActionText(action, name, locale)` 3-arg | Use 4-arg `(action, name, description, locale)` |
| `AddDefaultMethods(uClass, ARRAY['Created', ...], ARRAY[...])` | 1-arg `AddDefaultMethods(uClass)` works — defaults are sensible |

When csms pattern breaks: try simplest form first; then consult `platform/workflow/init.sql` for current `AddDefaultMethods` / `DefaultMethods` source. **Platform version is the truth, not csms.**

### O. Verification checklist for first install of new project

After `runme.sh --init` (10s on dev machine):

```bash
# Action seed (54 platform + your custom)
PGPASSWORD=kernel psql -h localhost -U kernel -d <dbname> \
  -tc "SELECT count(*) FROM db.action"
# Expect: 54 + N (your AddAction count)

# Entity seed (platform + your additions — the platform count depends on the version; measure it once on a bare install)
PGPASSWORD=kernel psql -h localhost -U kernel -d <dbname> \
  -tc "SELECT count(*) FROM db.entity"
# Expect: <platform count> + N

# Default 5 areas (auto-created)
PGPASSWORD=kernel psql -h localhost -U kernel -d <dbname> \
  -c "SELECT code, name FROM db.area"
# Expect: root, system, guest, all, <dbname>

# Default 15 users (5 admins/system + 5 audience-derived + 5 anon/role)
PGPASSWORD=kernel psql -h localhost -U kernel -d <dbname> \
  -tc "SELECT username FROM db.user"

# Your reference seed (replace with your refs)
PGPASSWORD=kernel psql -h localhost -U kernel -d <dbname> \
  -c "SELECT * FROM db.<reference> ORDER BY <natural_sort>"

# Live signature check (pitfall reminder)
PGPASSWORD=kernel psql -h localhost -U kernel -d <dbname> \
  -c "\df WriteToEventLog"
# Expect: 3 overloads (4-arg, 5-arg, 6-arg with scope)
```

If any count is 0 when you expect data — most likely Pitfall E (transaction rollback). Read `db/log/init.log` for the actual error.

### P. Platform table-name collision — `db.event_type` and friends

NEVER name a configuration entity the same as a platform-owned table. Symptom is install-fatal but cryptic: *«столбец X не существует»* / *«cannot rename column X to Y in view»* fired on a `CREATE OR REPLACE VIEW <Name>` long before your code ever runs the seed.

Mechanism: `db.<your_entity>` shadows `db.<platform_entity>` in the same schema. Then platform's `CREATE OR REPLACE VIEW <PlatformView>` (e.g. `EventType`, defined later in `platform/workflow/view.sql`) tries to read columns from your shadowing table, gets a different schema, and PostgreSQL refuses the ALTER.

**Reserved platform table names — do NOT use as entity names** (incomplete; always grep before naming):

```
event_type            (workflow event-type classifier: parent/event/transition/action)
state_type            (created/enabled/disabled/deleted)
action                (workflow actions: create/edit/save/enable/disable/delete/restore/drop/...)
method                (workflow methods)
transition            (workflow transitions)
entity                (entity registry)
class                 (class hierarchy)
type                  (entity types)
scope                 (multi-tenant scopes)
locale                (i18n locales)
area                  (multi-tenant area tree)
user / group / member_group / session
reference / document / object / object_text / object_link
registry / message / notice / notification / verification
file / log / job / report / acl / acu / amu / aou / aom / oma
endpoint / route / api
```

**Detection (before creating new entity):**

```bash
cd ~/DevSrc/Projects/<project>/db
grep -lr "CREATE TABLE db\.<your_name>\b" sql/platform/   # must return empty
grep -lr "CREATE OR REPLACE VIEW <YourName>\b" sql/platform/   # must return empty
```

**Fix pattern:** prefix with domain qualifier — `journal_event_type` (not `event_type`), `vessel_certificate` (not `certificate`), `document_template` (not `template`). The prefix conveys domain meaning **and** prevents collision.

In ship-safety this pitfall fired during W5 task 010 — initial `event_type/` entity collided with platform `db.event_type` workflow classifier. The install crashed inside `journal_template/view.sql` (sibling entity) with «cannot rename column code to reference» because the platform `EventType` view was being recompiled against a now-shadowed `db.event_type`. Renamed entity `event_type` → `journal_event_type`. Lesson: a sibling reference table named identically to a platform table is a guaranteed install crash.

---

### T. `install.psql` runs `configuration/init.sql` as `admin`, not `kernel` (SERP T305, 28.09.2026)

`install.psql` does `\connect :dbname admin` before `\ir './platform/init.sql'` and `\ir './configuration/init.sql'`
(apostol-csms `db/sql/install.psql:67–71`). A guard exempting `session_user = 'kernel'` misses the install path; one
exempting `admin` blinds the test harness and the migrations. Working form: a transaction-scoped GUC set only by
`init.sql`, paired with `session_user = 'admin'`; `set_config(…, true)` inside an explicit `BEGIN … COMMIT` — in psql
autocommit it is gone by the next statement.

### U. `git archive` leaves out untracked files (CSMS T592, 29.09.2026)

An export by pins (`git archive <sha>` of the tree and of each submodule) carries tracked files only. A per-environment
bundle kept untracked (F: `db/sql/.env/<dbname>/`) is missing from it, and the first script that reads it fails
(apostol-csms: `db-init` exit 3 on `sets.psql`). Add such bundles to the export by hand.
