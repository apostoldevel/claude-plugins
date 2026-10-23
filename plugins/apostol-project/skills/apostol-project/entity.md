<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 7 — Entity Creation (Production-Ready Patterns)

This is where most of the work happens in a configuration project. The patterns below are extracted from the wiki **and** validated against production code + db-platform sources.

### The File Convention — 7 core + 4 optional (production reality)

Each entity lives under `configuration/<dbname>/entity/object/{document,reference}/<name>/`. Wiki tutorial shows 7 files; production code regularly uses up to **11**:

| File | --create | --update | Purpose |
|------|:--------:|:--------:|---------|
| **Core 7 (every entity):** | | | |
| `table.sql` | ✓ | — | DDL: `CREATE TABLE`, indexes, BEFORE INSERT trigger (copies parent.id → entity.id) |
| `view.sql` | ✓ | ✓ | 3 views: `<Entity>` (basic), `Access<Entity>` (RLS), `Object<Entity>` (full metadata) |
| `routine.sql` | ✓ | ✓ | `Create<Entity>`, `Edit<Entity>`, `Get<Entity>` + helpers |
| `api.sql` | ✓ | ✓ | `api.<entity>` view + 6 functions: add / update / set / get / count / list |
| `rest.sql` | ✓ | ✓ | `rest.<entity>` dispatcher: 6 routes + ELSE → ExecuteDynamicMethod |
| `event.sql` | ✓ | ✓ | 9 standard `Event<Entity><Action>` handlers + custom |
| `init.sql` | ✓ | — | `Add<Entity>Events` + `Add<Entity>Methods` + `CreateClass<Entity>` + `CreateEntity<Entity>` |
| **Optional 4 (when needed):** | | | |
| `exception.sql` | ✓ | ✓ | Domain-specific error functions: `MyEntityNotFound()`, `InvalidStateForAction()` |
| `security.sql` | ✓ | — | Custom access-control overrides (rare; default ACU/AMU/AOU usually sufficient) |
| `do.sql` | ✓ | ✓ | Configuration hooks: `DoCreate<Entity>`/`DoEdit<Entity>` extension points called by event handlers (allows sub-classes to override behavior without editing parent) |
| `sequence.sql` | ✓ | — | Integer sequences (OCPP-style numeric IDs, ticket numbers) |
| **Master scripts:** | | | |
| `create.psql` | — | — | wiring: `\ir table; \ir view; \ir routine; \ir api; \ir rest; \ir event; \ir init` (+ optional includes) |
| `update.psql` | — | — | wiring: `\ir view; \ir routine; \ir api; \ir rest; \ir event` (+ `\ir do` if present) |

**Sub-directories** for sub-entities or sub-classes — each with own complete file set, included from parent's `create.psql`/`update.psql`.

### `WriteToEventLog` — 3 overloads (resolved ambiguity)

db-platform `log/routine.sql` defines three overloads. Production code uses the canonical 6-arg version; the others are convenience wrappers.

```sql
-- 6-arg CANONICAL — use this in production code
WriteToEventLog(pType, pCode, pScope, pEvent, pText, pObject);
--   pType:   'M' (message) | 'W' (warning) | 'E' (error) | 'D' (debug) | 'N' (raise notice)
--   pCode:   integer (1000=normal, 2000=elevated severity)
--   pScope:  subsystem identifier — 'lifecycle' | 'workflow' | 'audit' | domain-specific
--   pEvent:  detail within scope — usually action code ('create', 'enable', etc.)
--   pText:   human-readable message
--   pObject: optional uuid — auto-resolves category via GetClassCode(class)

-- 5-arg wrapper — calls 6-arg with NULL scope (wiki tutorial uses this)
WriteToEventLog(pType, pCode, pEvent, pText, pObject);

-- 4-arg wrapper — calls 6-arg with default scope='log' and pEvent passed as pText
WriteToEventLog(pType, pCode, pText, pObject);
```

**Use 6-arg in production for all events.** Examples:
```sql
PERFORM WriteToEventLog('M', 1001, 'lifecycle', 'create', 'Vessel created.', pObject);
PERFORM WriteToEventLog('M', 2001, 'workflow',  'enable', 'Tenant enabled.', pObject);
PERFORM WriteToEventLog('W', 2005, 'workflow',  'drop',   'Client destroyed.', pObject);
PERFORM WriteToEventLog('E', 4001, 'audit',     'tamper', 'Hash chain mismatch.', pObject);
```

### Where shared modules really live (and the StreamServer pitfall)

The directory layout — `src/processes/<Name>/` vs `src/modules/Workers/<Name>/` — does **not** strictly determine the module type. There is one notable exception:

| Module | Location | Type | Registration |
|---|---|---|---|
| `MessageServer`, `Replication`, `ReportServer`, `TaskScheduler` | `src/processes/` | `ProcessModule` (separate event loop + PgPool) | `app.add_custom_process(std::make_unique<X>())` in `Processes.hpp` |
| **`StreamServer` / `PgStreamServer`** | **`src/processes/StreamServer/`** | **`Worker Module`** (UDP socket attached to worker's EventLoop) | **`app.module_manager().add_module(std::make_unique<StreamServer>(app))`** in **`Workers.hpp`** |
| `AppServer`, `AuthServer`, `WebSocketAPI`, `PGHTTP`, `FileServer`, `WebServer` | `src/modules/Workers/` | `Worker Module` | `app.module_manager().add_module()` in `Workers.hpp` |
| `PGFetch`, `PGFile` | `src/modules/Helpers/` | `Worker Module` (helper process) | `app.module_manager().add_module()` in `Helpers.hpp` |

**The pitfall:** trying to register `StreamServer` via `add_custom_process(std::make_unique<StreamServer>())` fails because `StreamServer` requires `Application&` in its constructor — it's not a process. Always check the class signature: `: public Module` (Worker) vs `: public ProcessModule` (custom process).

**Implication for projects extending StreamServer** (e.g. a telemetry process such as `process-NMEA`): your module derives from `PgStreamServer` (with PG dispatch) or `StreamServer` (raw UDP), and registers in `Workers.hpp` — not `Processes.hpp`.

### View Convention (3 views — strictly)

**1. `<Entity>` (basic):** joins entity table + parent (object/document/reference) + state + type. Used internally by other functions.

**2. `Access<Entity>` (RLS via AOU):**

```sql
CREATE OR REPLACE VIEW Access<Entity>
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid
  UNION
  SELECT userid FROM db.member_group WHERE member = current_userid()
)
SELECT object
  FROM db.<entity> t INNER JOIN db.aou       a ON a.object = t.id
                     INNER JOIN _membergroup m ON a.userid = m.userid
 GROUP BY object
 HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100';

GRANT SELECT ON Access<Entity> TO administrator;
```

**3. `Object<Entity>` (full metadata for API):** denormalized view with entity / class / type / state / owner / oper / area (for documents) or scope (for references).

> **The access model is dynamic — `Object<Entity>` must NOT reference `Access<Entity>`.** In the
> current db-platform the join is attached **at runtime by `api.sql('kernel', 'Object<Entity>', …)`**,
> and skipped for administrators. The older static shape — `Object<X>` joining `Access<X>` inside —
> still exists in legacy code and in code donated from earlier generations; **it is not merely
> slower, it is a different security model**, and porting it as-is is the single most expensive
> mistake in this ecosystem. `/new-db-entity` states the current rule correctly; if two skills seem
> to disagree, that one wins.
>
> **The tell to grep for: `api.sql('api', …)`.** With schema `api` the access join is **not attached
> at all** — the query runs, returns rows, filters nothing. For a reference that is a leaked
> catalogue; for a journal entry it is another vessel's records.

### `routine.sql` — Universal Create / Edit / Get

**`Create<Entity>` pattern:**

```sql
1. Validate type belongs to entity:    GetEntityCode(uClass) <> '<entity>' → IncorrectClassType()
2. Call parent factory:                 CreateDocument(...) | CreateReference(...) → uId
3. INSERT specialized row              (id = uId, document/reference = uId, ...)
4. Get + execute create method:        uMethod := GetMethod(uClass, GetAction('create'));
                                        PERFORM ExecuteMethod(uId, uMethod);
5. RETURN uId
```

**`Edit<Entity>` pattern:**

```sql
1. Call parent edit:                    EditDocument(...) | EditReference(...)
2. UPDATE specialized via               coalesce(pNew, existingCol) → preserves NULL = "keep current"
3. CheckNull() для clearing:            metadata = CheckNull(coalesce(pMetadata, metadata, '{}'::jsonb))
4. Execute edit method (with old/new):  uMethod := GetMethod(GetObjectClass(pId), GetAction('edit'));
                                        PERFORM ExecuteMethod(pId, uMethod,
                                          jsonb_build_object('old', row_to_json(old), 'new', row_to_json(new)));
```

**The generic reference road leaves no state.** `CreateReference` (and through it `api.add_reference` / a generic
`/reference/set`) does not run the `create` method, so the object has `state IS NULL`
(`entity/object/reference/routine.sql:77–115`, 1.2.35); the reference views join `db.state` with an INNER JOIN
(`reference/view.sql:82`) — the row exists and appears in no `/list`. Typed `Create<Entity>` constructors do run
`create`. To check what such a road created, or to clean up after it, query `db.object` (`state IS NULL`), never a list.

### `api.sql` — Strict 6 Functions + 1 View

| Function | Returns | Body |
|----------|---------|------|
| `api.<entity>` (view) | — | `SELECT * FROM Object<Entity>;` |
| `api.add_<entity>(...)` | `uuid` | wraps `Create<Entity>(...)` with type defaulting + `CheckJsonbKeys` |
| `api.update_<entity>(pId, ...)` | `void` | checks existence → `EditXxx(...)` |
| `api.set_<entity>(pId, ...)` | `SETOF api.<entity>` | upsert: if pId NULL → `add_`, else → `update_` |
| `api.get_<entity>(pId)` | `SETOF api.<entity>` | `SELECT * FROM api.<entity> WHERE id = pId` |
| `api.count_<entity>(pSearch, pFilter)` | `SETOF bigint` | `EXECUTE api.sql('kernel', 'Object<Entity>', pSearch, pFilter, 0, null, '{}', '["count(id)"]')` |
| `api.list_<entity>(pSearch, pFilter, pLimit, pOffset, pOrderBy)` | `SETOF api.<entity>` | `EXECUTE api.sql('kernel', 'Object<Entity>', pSearch, pFilter, pLimit, pOffset, pOrderBy)` |

> **Schema `kernel` + view `Object<Entity>` is not a style choice.** `api.sql()` attaches the access join only when `pScheme = 'kernel'`, `GetAccessMode()` is true and a view named `replace(lower(pTable),'object','access')` exists. `api.sql('api', '<entity>', …)` returns every row with **no filtering and no error** — measured 2026-09: four of seven configurations route all lists this way and their 11–31 `Access<X>` views have no effect at all.

**All `api.*` functions:** `LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, pg_temp`.

### `rest.sql` — Dispatcher with 6 Standard Routes + ELSE

```sql
CREATE OR REPLACE FUNCTION rest.<entity>(pPath text, pPayload jsonb DEFAULT null)
RETURNS SETOF json
AS $$
DECLARE
  r record; e record; arKeys text[];
BEGIN
  IF pPath IS NULL THEN PERFORM RouteIsEmpty(); END IF;
  IF current_session() IS NULL THEN PERFORM LoginFailed(); END IF;

  CASE pPath
    WHEN '/<entity>/type'   THEN ...   -- list types for this entity
    WHEN '/<entity>/method' THEN ...   -- workflow methods available for an object
    WHEN '/<entity>/count'  THEN ...   -- count by search/filter
    WHEN '/<entity>/set'    THEN ...   -- upsert (uses GetRoutines for introspection)
    WHEN '/<entity>/get'    THEN ...   -- get by id (with field projection)
    WHEN '/<entity>/list'   THEN ...   -- list (search/filter/orderby/reclimit/recoffset)
    -- ... custom routes for this entity ...
  ELSE
    RETURN NEXT ExecuteDynamicMethod(pPath, pPayload);   -- handles /enable, /disable, /<custom_action>
  END CASE;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, pg_temp;
```

**Each route must:**
- Validate payload keys via `CheckJsonbKeys(pPath, arKeys, pPayload)`.
- Support batch (array payload) via `jsonb_typeof(pPayload) = 'array'` → `jsonb_to_recordset` vs `jsonb_to_record`.
- Use `JsonbToFields(r.fields, GetColumns('<entity>', 'api'))` for field projection.

**ELSE → `ExecuteDynamicMethod`** automatically handles:
- `/<entity>/enable`, `/disable`, `/delete`, `/restore`, `/drop` (standard lifecycle)
- Any custom action you registered (e.g. `/<entity>/submit`, `/heartbeat`, `/correction`)

### `event.sql` — 9 Standard Handlers + Custom

Standard:

```
EventCreate, EventOpen, EventEdit, EventSave, EventEnable, EventDisable, EventDelete, EventRestore, EventDrop
```

**Function signature:**

```sql
CREATE OR REPLACE FUNCTION Event<Entity>Create(pObject uuid DEFAULT context_object())
RETURNS void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', '<Entity> created.', pObject);
END;
$$ LANGUAGE plpgsql;
-- NOTE: no SECURITY DEFINER; runs in caller's context.
```

**For Edit (receives old/new):**

```sql
CREATE OR REPLACE FUNCTION Event<Entity>Edit(
  pObject uuid DEFAULT context_object(),
  pParams jsonb DEFAULT context_params()
) RETURNS void AS $$ ... $$ ...;
-- pParams contains {old: {...}, new: {...}}
```

**EventDrop must:**
1. Capture label for logging **before** deletion: `SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();`
2. For child objects: cascade through lifecycle (`DoDisable` → `DoDelete` → `DoDrop`), not direct DELETE.
3. Clean up `db.object_link`, `db.object_file` if applicable.
4. `DELETE FROM db.<entity> WHERE id = pObject;`
5. `WriteToEventLog('W', 2000, 'drop', '...destroyed.', pObject)` — note category `'W'` and elevated priority.

> **`WriteToEventLog` signature uncertainty:** The wiki shows `(category, priority, action, message, object)` (5 args). Production code uses `(category, priority, scope, action, message, object)` (6 args, with a `scope` like `'lifecycle'` or `'workflow'` between priority and action). **Check the actual signature** in your project after install: `\df WriteToEventLog` in psql. Use the form your platform version expects.

### `init.sql` — Entity / Class / Methods / Events / Route

Three functions, in order:

**1. `Add<Entity>Events(pClass)`** — registers events for each action.

**Critical event order rules:**

| Action | Order |
|--------|-------|
| `create`, `open`, `edit`, `save`, `enable`, `disable`, `restore` | parent FIRST → entity SECOND (parent initializes/operates first) |
| `delete`, `drop` | **entity FIRST → parent SECOND** (entity cleans up specialized rows before parent FK cascade) |

```sql
FOR r IN SELECT * FROM Action LOOP
  IF r.code = 'create' THEN
    PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    PERFORM AddEvent(pClass, uEvent, r.id, '<Entity> created', 'Event<Entity>Create();');
  END IF;
  -- ... etc ...
  IF r.code = 'delete' THEN
    PERFORM AddEvent(pClass, uEvent, r.id, '<Entity> will be deleted', 'Event<Entity>Delete();');
    PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
  END IF;
  IF r.code = 'drop' THEN
    PERFORM AddEvent(pClass, uEvent, r.id, '<Entity> will be destroyed', 'Event<Entity>Drop();');
    PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
  END IF;
END LOOP;
```

**For custom actions** (e.g. `submit`, `available`, `correction`):

```sql
IF r.code = 'submit' THEN
  PERFORM AddEvent(pClass, uEvent, r.id, '<Entity> submitted', 'Event<Entity>Submit();');
  PERFORM AddEvent(pClass, uEvent, r.id, 'Change state', 'ChangeObjectState();');  -- REQUIRED for state transition
END IF;
```

> **`ChangeObjectState();` is mandatory for any custom action that transitions state.** Without it, the action fires its event but the object stays in the same state. Standard actions (enable/disable/delete/restore) handle this internally; custom ones don't.

**2. `Add<Entity>Methods(pClass)`** — usually `AddDefaultMethods(pClass)` for entities with the standard 4-state lifecycle. For complex workflows (multi-state-per-type, custom actions), write the function explicitly (see Step 8).

**3. `CreateClass<Entity>(pParent, pEntity)` + `CreateEntity<Entity>(pParent)`:**

```sql
CREATE OR REPLACE FUNCTION CreateClass<Entity>(pParent uuid, pEntity uuid) RETURNS uuid AS $$
DECLARE uClass uuid; BEGIN
  uClass := AddClass(pParent, pEntity, '<entity>', '<Entity>', false);  -- false = concrete
  PERFORM EditClassText(uClass, '<Локализованный>', GetLocale('ru'));   -- localization (see below)
  PERFORM AddType(uClass, 'default.<entity>', 'Default', 'Default <entity>.');
  PERFORM Add<Entity>Events(uClass);
  PERFORM Add<Entity>Methods(uClass);  -- or AddDefaultMethods(uClass)
  RETURN uClass;
END $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, pg_temp;

CREATE OR REPLACE FUNCTION CreateEntity<Entity>(pParent uuid) RETURNS uuid AS $$
DECLARE uEntity uuid; BEGIN
  uEntity := AddEntity('<entity>', '<Entity>');
  PERFORM EditEntityText(uEntity, '<Локализованный>', null, GetLocale('ru'));
  PERFORM CreateClass<Entity>(pParent, uEntity);
  PERFORM RegisterRoute('<entity>', AddEndpoint('SELECT * FROM rest.<entity>($1, $2);'));
  RETURN uEntity;
END $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, pg_temp;
```

Then in `configuration/<dbname>/entity/init.sql` `InitConfigurationEntity()`:

```sql
PERFORM CreateEntity<Entity>(GetClass('document'));   -- or 'reference'
```

### Sub-classing (Inheritance Patterns)

Two valid patterns. Pick by domain shape.

**Single-table inheritance** (e.g. a `client`): one table `db.client` holds all subclasses (`tenant`, `employee`, `driver`, `partner`) with a discriminator column (`tenant boolean`). Subclasses differ in `o.class` lookup, not in tables.

```sql
-- In tenant/init.sql:
CREATE FUNCTION CreateClassTenant(pParent uuid, pEntity uuid) RETURNS uuid AS $$
BEGIN
  -- pParent is GetClass('client'), pEntity is GetEntity('client') — REUSE, don't AddEntity again
  RETURN AddClass(pParent, pEntity, 'tenant', 'Tenant', false);
END $$ ...;
```

**Multi-table inheritance** (e.g. a `charge_point`): each subclass has its own table with FK to the parent entity's table. Used when subclasses have substantially different fields.

```sql
-- charge_point.id -> document.id (NOT through device.id; charge_point is a direct subclass of document in the configuration this example comes from)
-- For deeper hierarchies (e.g. station extending device extending document):
CREATE TABLE db.station (
  id        uuid PRIMARY KEY,
  device    uuid NOT NULL REFERENCES db.device(id) ON DELETE CASCADE,  -- FK to parent ENTITY table
  ...
);
```

**Sub-class entity registration:**

```sql
-- IMPORTANT: GetEntity, NOT AddEntity. Reuse the parent's entity.
CREATE FUNCTION CreateEntityStation(pParent uuid /* = GetClass('device') */) RETURNS uuid AS $$
DECLARE uEntity uuid; BEGIN
  uEntity := GetEntity('device');                  -- reuse, don't create new entity
  PERFORM CreateClassStation(pParent, uEntity);    -- new class under device
  PERFORM RegisterRoute('station', ...);
  RETURN uEntity;
END $$ ...;
```

### Auto-ACL Provisioning via Triggers (production pattern)

For entities where ownership matters (charge_point, vessel, etc.), `AFTER INSERT/UPDATE` triggers grant `db.aou` rights to the linked user:

```sql
CREATE OR REPLACE FUNCTION db.ft_<entity>_after_insert() RETURNS trigger AS $$
DECLARE uOwner uuid; uUserId uuid;
BEGIN
  IF NEW.client IS NOT NULL THEN
    SELECT owner INTO uOwner FROM db.object WHERE id = NEW.document;
    uUserId := GetClientUserId(NEW.client);
    IF uOwner <> uUserId THEN
      UPDATE db.aou SET allow = allow | B'110' WHERE object = NEW.document AND userid = uUserId;
      IF NOT FOUND THEN
        INSERT INTO db.aou SELECT NEW.document, uUserId, B'000', B'110';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$ ...;
```

Without this, the linked user has no row-level access to their own object.

**Derived grants are a cache.** Grants derived from a relationship (membership, a booking, an ownership link) live in
`db.aou`; their writer must also **revoke or re-grant when the relationship changes**, not only grant on insert. On an
object in a default-typed area AOU alone decides visibility (`access-control.md` § DocumentAreaTree), so a class-level
read for a broad group there means "everyone in the scope".

### Multi-Tenant Pattern: Area ↔ Tenant Binding

**Tenant code = area code** by convention. When a tenant client is created, an area with the same code is created (or already exists). `current_tenant()` resolves the tenant from the session's area:

```sql
CREATE FUNCTION current_tenant() RETURNS uuid AS $$
  SELECT c.id FROM db.client c
   INNER JOIN db.area a ON a.code = c.code
   WHERE c.tenant AND a.id = current_area();
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = kernel, pg_temp;
```

For documents: area-based scoping is automatic. `DocumentAreaTree` recursive CTE expands the area hierarchy; `AccessDocument` filters AOU ∩ area membership. Hierarchy works as expected (parent area sees child documents).

### Localization Boilerplate

Every `EditClassText` / `EditStateText` / `EditMethodText` / `EditTypeText` / `EditEntityText` should be repeated for each locale the project supports:

```sql
PERFORM EditClassText(uClass, 'Russian text', GetLocale('ru'));
PERFORM EditClassText(uClass, 'English text', GetLocale('en'));
-- Cover every locale the project ships; ru + en is the usual minimum.
```

This is heavy boilerplate but required for production. Skipping it leaves UI labels in only one language.

---
