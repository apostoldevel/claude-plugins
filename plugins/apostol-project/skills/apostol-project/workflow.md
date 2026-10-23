<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 8 — Workflow Customization

Use this when the standard 4-state lifecycle (created/enabled/disabled/deleted) doesn't fit. Read `wiki/74-Workflow-Customization.md` first.

### State helpers — never compare UUIDs by hand

The platform exposes a complete set of state-checking and state-transition helpers. Use them — never compare `db.object.state_type` against magic UUIDs, never call `ExecuteObjectAction(..., GetAction('xxx'))` with the action name in two places.

**Reading state** (returns boolean):

| Helper | Meaning |
|---|---|
| `IsCreated(pObject)` | `state_type = 'created'` |
| `IsEnabled(pObject)` | `state_type = 'enabled'` (any sub-state: available/unavailable/faulted/...) |
| `IsDisabled(pObject)` | `state_type = 'disabled'` |
| `IsDeleted(pObject)` | `state_type = 'deleted'` |
| `IsActive(pObject)` | `state_type IN ('created', 'enabled')` — convenience |

For finer-grained checks: `GetObjectStateCode(pObject)` returns the **state** code ('available', 'unavailable', 'faulted', ...). `GetObjectStateTypeCode(pObject)` returns the **state-type** code ('enabled', 'disabled', ...).

**Driving transitions** (each is a thin wrapper over `ExecuteObjectAction(pObject, GetAction('xxx'))`):

| Helper | Action |
|---|---|
| `DoCreate(pObject)` | `'create'` |
| `DoEnable(pObject)` | `'enable'` |
| `DoDisable(pObject)` | `'disable'` |
| `DoDelete(pObject)` | `'delete'` |
| `DoRestore(pObject)` | `'restore'` |
| `DoDrop(pObject)` | `'drop'` |
| `DoAction(pObject, pCode text)` | any action by code (e.g. `DoAction(uObj, 'available')`) |

Idempotent restore-or-promote pattern (e.g. recreating an entity that may already exist in `deleted` or `disabled`):

```sql
IF IsDeleted(uObj) THEN PERFORM DoRestore(uObj); END IF;
IF IsCreated(uObj) OR IsDisabled(uObj) THEN PERFORM DoEnable(uObj); END IF;
IF GetObjectStateCode(uObj) <> 'available' THEN PERFORM DoAction(uObj, 'available'); END IF;
```

### Atomicity, swallowed errors, one `Now()`, removing a method

- **A state gate plus an action means a row lock.** Reading the state and then calling `DoAction` is not atomic under
  READ COMMITTED: `ExecuteMethod` reads `db.object.state` without a lock (`entity/object/routine.sql:813`, 1.2.35), so a
  concurrent webhook can move the object after your read. Take `SELECT … FROM db.object WHERE id = … FOR UPDATE` before
  reading the state, at every door of the action. Test with two real sessions — one session cannot see the race.
- **`DoTryAction` swallows every exception** — it logs the diagnostics and returns NULL
  (`entity/object/routine.sql:1052–1066`). A handler that writes another object under the caller's session can
  "succeed" and change nothing: check the resulting state. Write foreign objects under a user that holds the update bit on them — `EnterSystemContext`
  changes the user, not the object write trigger (`access-control.md` § What the layer names promise).
- **All state changes of one transaction share one `Now()`**, and `AddObjectState` overwrites the earlier history row
  (`entity/object/routine.sql:495–510`). A unique index over a `DEFAULT Now()` column refuses two rows with one key in one
  transaction. A test that needs distinct history steps runs them as separate committed transactions.
- **`DeleteMethod` removes the method's transitions and AMU too** — through the BEFORE DELETE trigger
  `t_method_before_delete` (`workflow/table.sql:518–535`), not in its own body. Count what disappears before and after.

### Multi-state per state type

A state **type** is one of 4 fixed: created, enabled, disabled, deleted. A **state** belongs to a state type and a class. You can have N states per state type.

Example (a charge point in `enabled`): 3 sub-states `available`, `unavailable`, `faulted`.

```sql
WHEN 'enabled' THEN
  uState := AddState(pClass, rec_type.id, 'available', 'Available');
    PERFORM AddMethod(null, pClass, uState, GetAction('heartbeat'),    null, 'Heartbeat',    null, false);  -- hidden
    PERFORM AddMethod(null, pClass, uState, GetAction('available'),    null, 'Available',    null, false);
    PERFORM AddMethod(null, pClass, uState, GetAction('unavailable'),  null, 'Unavailable',  null, false);
    PERFORM AddMethod(null, pClass, uState, GetAction('faulted'),      null, 'Faulted',      null, false);
    PERFORM AddMethod(null, pClass, uState, GetAction('disable'),      null, 'Disable');
  uState := AddState(pClass, rec_type.id, 'unavailable', 'Unavailable');  -- ... methods ...
  uState := AddState(pClass, rec_type.id, 'faulted',     'Faulted');      -- ... methods ...
```

Then `DefaultMethods(pClass)` + `DefaultTransition(pClass)` for the global ones, plus custom `AddTransition(rec_state.id, rec_method.id, GetState(pClass, '<target_state>'))` for each custom transition.

### Hidden methods (programmatic-only)

`pVisible = false` keeps a method out of the UI. Use for:

- Auto-triggered status updates (heartbeat, status sync)
- Background processes
- Methods the user shouldn't see/click

```sql
PERFORM AddMethod(null, pClass, uState, GetAction('heartbeat'), null, 'Heartbeat', null, false);
```

### No-transition actions

Some custom actions execute event handlers but don't change state (e.g. `submit`, `confirm`, `reconfirm`):

```sql
PERFORM AddMethod(null, pClass, uState, GetAction('submit'), pVisible => false);
-- No AddTransition call — stays in same state
```

### Immutable entity workflow (journals, audit logs, hash-chains)

For entities where rows must never be modified after creation (e.g. logbook journal entries, financial ledger entries, audit logs):

```sql
CREATE FUNCTION Add<Entity>Methods(pClass uuid) RETURNS void AS $$
DECLARE uState uuid;
BEGIN
  -- DO NOT call AddDefaultMethods — it would add edit/save/update/enable/disable/restore.

  -- Only one state: 'created'. Object never leaves it.
  uState := AddState(pClass, GetStateType('created'), 'created', 'Created');

  -- Only allowed actions:
  PERFORM AddMethod(null, pClass, uState, GetAction('correction'), null, 'Correction');  -- creates new correction row
  -- Optionally: a 'verify' action for hash-chain validation, also no-transition.

  -- No transitions — entry stays in 'created' forever.
END $$ ...;
```

In `Add<Entity>Events`: register only `create` and the custom action(s). Skip `edit`, `save`, `update`, `enable`, `disable`, `restore`. The corresponding methods don't exist in this class.

In `event.sql`: implement only the events you registered. Drop is the one exception — even immutable entities sometimes need administrative cleanup (with elevated audit logging).

---
