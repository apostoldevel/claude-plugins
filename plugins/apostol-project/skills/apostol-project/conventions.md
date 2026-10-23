<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 13 — Strict Conventions Checklist

Use this as a final pass before committing. Each line is non-negotiable.

### Schema discipline

- [ ] DDL goes in `db.<table>` — never `kernel`, `api`, `rest`.
- [ ] Functions in `kernel.*` / `api.*` / `rest.*` / `daemon.*` always declare `LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, pg_temp` (or domain-appropriate).
- [ ] Tables have comments (`COMMENT ON TABLE`, `COMMENT ON COLUMN`).
- [ ] BEFORE INSERT trigger copies parent.id → entity.id when entity.id is NULL.

### Entity discipline

- [ ] 7-file structure: table.sql + view.sql + routine.sql + api.sql + rest.sql + event.sql + init.sql.
- [ ] 3 views: `<Entity>` + `Access<Entity>` + `Object<Entity>`.
- [ ] `Object<Entity>` does **not** join `Access<Entity>`; `api.<entity>` joins it by id; `list_`/`count_` call `api.sql('kernel', 'Object<Entity>', …)`.
- [ ] 6 api functions: add/update/set/get/count/list (+ `api.<entity>` view).
- [ ] 6 REST routes: type/method/count/set/get/list + ELSE → ExecuteDynamicMethod.
- [ ] 9 standard event handlers (or subset for immutable entities, with explicit explanation in comments).
- [ ] init.sql has Add<Entity>Events + Add<Entity>Methods + CreateClass<Entity> + CreateEntity<Entity>.
- [ ] Wire-up: `\ir './<entity>/create.psql'` in parent `create.psql`; `PERFORM CreateEntity<Entity>(uParent);` in `InitConfigurationEntity()`.

### Workflow discipline

- [ ] Standard 4-state lifecycle → `AddDefaultMethods()`. Custom workflow → write `Add<Entity>Methods` explicitly.
- [ ] Custom actions register `'ChangeObjectState();'` event for transitions.
- [ ] Event order: parent FIRST for create/edit/save/enable/disable/restore; **entity FIRST for delete/drop**.
- [ ] Hidden methods (`pVisible=false`) for programmatic-only actions (heartbeat, sync).
- [ ] State / method codes accessed via `GetState`, `GetMethod`, `GetAction` — never hardcoded UUIDs.

### REST dispatcher discipline

- [ ] Top of every dispatcher: `IF pPath IS NULL THEN PERFORM RouteIsEmpty();` + `IF current_session() IS NULL THEN PERFORM LoginFailed();`.
- [ ] Every route validates payload keys via `CheckJsonbKeys(pPath, arKeys, pPayload)`.
- [ ] Batch support: `IF jsonb_typeof(pPayload) = 'array' THEN ... jsonb_to_recordset ELSE jsonb_to_record END IF`.
- [ ] Field projection: `JsonbToFields(r.fields, GetColumns('<entity>', 'api'))`.
- [ ] `/<entity>/set` uses `GetRoutines('set_<entity>', 'api', ...)` introspection.
- [ ] ELSE clause: `RETURN NEXT ExecuteDynamicMethod(pPath, pPayload);`.
- [ ] Before narrowing what a route accepts, measure what callers send (`db.api_log`, the request log). Generated clients
  send every key of the signature, mostly `null`, and admin lists send `filter: {}` — refuse a **non-null value**, not
  the presence of a key. Reuse an existing error (`IncorrectJsonKey`) before registering a new code.

### Edit discipline

- [ ] All update parameters default NULL; use `coalesce(pNew, existing_col)` to preserve existing values.
- [ ] Use `CheckNull(coalesce(...))` to allow clearing fields with empty input.
- [ ] Pass `{old, new}` jsonb to `ExecuteMethod` for edit events.

### Localization discipline

- [ ] Locale-aware queries: `WHERE locale = current_locale()` in views.
- [ ] All Edit*Text calls done for every supported locale (project-specific list).

### Auth & session discipline

- [ ] Use `current_userid()`, `current_session()`, `current_area()`, `current_scope()`, `current_locale()` — never hardcode.
- [ ] Cookie-only auth in frontend (`credentials: 'include'`).
- [ ] Guest endpoints are called anonymously (`credentials: 'omit'`) and executed server-side by AppServer (`guest_routes`); **no** `client_credentials` or `X-Auth-Context: service` from the browser (RFC 6749 §4.4).

### Frontend discipline

- [ ] No `localStorage` / `sessionStorage` for tokens.
- [ ] No `expires_in` tracking in JS — AppServer (`/api/v1`) or GatewayAPI (`/api/v2`) refreshes; a SPA with neither behind it refreshes itself on 403 ([`anti-patterns.md`](anti-patterns.md), Frontend).
- [ ] CORS origins in `conf/oauth2/<provider>.json` `javascript_origins`.
- [ ] Use real field names from `view.sql` / `api.sql` — never invent.

### Testing code that calls out (PGFetch)

- [ ] Assert on the body of the queued `http.request`, not only on the table row.
- [ ] Feed the answer to the handler with the id of the request that was really queued — otherwise the test skips the
  "unknown outcome" branch.
- [ ] On a stack where PGFetch runs, every request a test queues goes to the real host — including follow-ups queued
  after a refusal. Stub the host, or drop the requests.
- [ ] One case of a scene per sub-block that raises its observation with its own SQLSTATE and rolls back. If the old and
  the new body give the same result, the scene is broken, not the code.

## Writing Rule — README files

When writing or editing a README that mentions **Apostol CRM**:

1. Replace any `[Apostol CRM](https://github.com/apostoldevel/apostol-crm)` link with: `**Apostol CRM**[^crm]`
2. Add footnote at the bottom of the file:

   ```
   [^crm]: **Apostol CRM** — a template project built on the [A-POST-OL](https://github.com/apostoldevel/libapostol) (C++20) and [PostgreSQL Framework for Backend Development](https://github.com/apostoldevel/db-platform) frameworks.
   ```

   For Russian READMEs:

   ```
   [^crm]: **Apostol CRM** — шаблон-проект построенный на фреймворках [A-POST-OL](https://github.com/apostoldevel/libapostol) (C++20) и [PostgreSQL Framework for Backend Development](https://github.com/apostoldevel/db-platform).
   ```

## Verification commands (Step 15, SQL layer; moved from the core 30.09.2026)

Don't claim "done" without running these.

### After `runme.sh --install` (first session in a project)

```bash
# Schema sanity
psql -d <dbname> -c '\dn'                      # list schemas
psql -d <dbname> -c '\df WriteToEventLog'      # confirm signature (5-arg or 6-arg?)
psql -d <dbname> -c "SELECT * FROM db.action ORDER BY code"  # confirm available actions
```

### After creating a new entity

```bash
./runme.sh --update                            # safe re-run

# In psql:
\dn                                            # schemas exist
\dt db.<entity>                                # table created
\df api.add_<entity>                           # api functions exist
SELECT api.add_<entity>(...);                  # smoke create
SELECT * FROM api.<entity> LIMIT 1;            # view returns data
SELECT * FROM api.list_<entity>('{}', '{}');   # list works

# Or via REST:
curl -b cookie.jar -X POST http://localhost:4977/api/v1/<entity>/list \
     -H 'Content-Type: application/json' -d '{"reclimit": 5}'
```

### After modifying workflow

```sql
SELECT * FROM Method WHERE class = GetClass('<entity>');
SELECT * FROM Transition t INNER JOIN Method m ON t.method = m.id WHERE m.class = GetClass('<entity>');
SELECT * FROM Event WHERE class = GetClass('<entity>') ORDER BY action, sequence;
```
