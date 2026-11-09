<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 9 — Access Control (full picture)

### Three independent dimensions of visibility

A document is visible to a user **only when ALL THREE** conditions hold:

1. **AOU/AOM (object permission)** — an AOU row `(object, the user or one of their groups)` carries the select bit, or the AOM fallback grants select by UNIX logic (owner/group/other).
2. **DocumentAreaTree (organisational scope)** — `db.document.area` is in the area tree visible from the current session.
3. **Scope (multi-tenant partition)** — `db.object.scope = current_scope()`.

The three checks are **independent and cumulative**. AOU without the right area = the document is invisible. The right area without AOU = the document is invisible.

### What the layer names promise and what they actually do

**Verified 2026-08-24 by two accounts in one run — read this before building any gate on permissions.**

- **AMU is a permission on a CLASS method, not on an object's method.** `db.oma` is a cache of the
  same class-level mask spread over objects, not an independent check. Consequence: **`/<entity>/method`
  answers identically to everyone who holds the class right** — a foreign tenant's user gets
  `visible/enable/execute = true` on an object they cannot even see. **Never build a gate on it.**
  Use `decode_object_access` instead.
- **`decode_object_access` returns `null/null/null` for an object that does not exist.** That is
  "no such object", not "no rights" — "no rights" comes back as `false`. They look alike on the
  wire and mean different things.
- **A state transition is a write to the object.** `enable` changes `db.object.state`, so it needs
  the update bit; read is not enough. Therefore "let them read but still run actions" **cannot be
  expressed by a class mask** — if you need it, guard the *fields* in your `Edit<Entity>` instead.
- **`chmodc` also spreads the mask over methods:** granting read produces AMU `010` — "method
  visible, not executable".
- **Class rights are `bit_or`-ed across the user AND their groups, and everyone is in group
  `user`.** So granting a role `B'0000010100'` does **not** make it read-only — effectively it is
  `11100`, with create. Whatever the platform seeds onto `user` is always mixed in.
- **Defaults differ by kind of class.** On class creation the platform grants group `user`:
  reference → `B'10100'` (access+read), document → `B'11000'` (access+create, **no read**).
  **A document is invisible until role grants are issued explicitly**; a reference reads
  immediately. Miss this and the entity is visible to nobody but the administrator — and you will
  not notice, because you test as the administrator.

> **Under `admin` the barrier is not attached at all.** Any permission check run as administrator
> is meaningless and looks successful. **Check permissions with two accounts in one run** — one who
> has the right, one who does not. "The stranger could not" without "the owner could" looks exactly
> the same when the barrier works and when there is simply no data. A real case: a missing role
> grant (nobody but the administrator could see any vessel) survived a whole slice unnoticed,
> because every check ran as `admin`.

> **`SubstituteUser` from an admin session is unusable for permission checks** — it drags the
> admin's rights along. The only honest path is through the `daemon` role, the way the backend
> itself connects. Two agents independently almost reported two non-existent findings on this in a
> single day.

- **The ACU create bit `c` guards nothing by itself.** `CheckClassAccess` has no caller in the platform
  (`workflow/routine.sql:651`, 1.2.35), and an object INSERT checks no class right: only the configuration's
  `api.add_*` / `Create<Entity>` decides who may create.
- **The last barrier on writing an existing object is the trigger `db.ft_object_before_update`**
  (`CheckObjectAccess(…, B'010')`, `entity/object/table.sql:217`), not AMU — and it is skipped when `session_user` is
  `kernel` or `postgres`. Holes therefore sit in **creation** that references someone else's object, where there is no
  object yet to check.
- **Signing in is an ACL bit too.** `Login()` checks the last bit of `db.acl` (`B'…0001'`) **before** the password and
  refuses with `AccessDenied` (`ERR-400-001`), not with a login error (`admin/routine.sql:6690`, password at `:6714`, 1.2.35).
  An account barred from signing in is a `deny` of that bit (`chmod`), and a test of it expects the access family.
- **Recovery tickets carry a type since 1.2.36** (`db.recovery_ticket.type`: `R` reset, `V` registration).
  `NewRecoveryTicket` sets no type, so the column default `R` applies; a door that issues another kind sets the type in the same transaction. Each door checks
  its own type with `CheckRecoveryTicket(id, code, type)` — the two-argument form is deprecated and accepts any type
  (`admin/routine.sql:324–426`, 1.2.38). A wrong code costs an attempt; a wrong type answers "not found" and costs none,
  so `attempts = 0` on a refused ticket tells a type refusal from a code refusal. The answer is write-once: the trigger
  skips an `UPDATE` that changes `securityAnswer` — the whole row, 0 rows, no error (`admin/table.sql:708–745`) — so a
  test reads the real code from the message it was sent, never sets it.
- **`db.user.readonly`** is read by `UpdateUser`, `UpdateGroup`, `SetPassword` and `SignIn` (`admin/routine.sql:3959`,
  `:4066`, `:4338`, `:6819`) and set on insert for the system names and the OAuth2 audiences (`admin/table.sql:245–246`).
  `UpdateUser` and `SetPassword` skip both the right and the flag when `session_user = 'kernel'` (`:3952`, `:4331`): a test
  under `kernel` never sees the flag, and an install that runs as `admin` must set `readonly` **after** `SetPassword`.
- **A server-imposed bound on a list goes into `pFilter`, never into `pSearch`.** `api.sql()` builds
  `WHERE (<search>) AND <filter>`: the filter is applied to the result of the whole search whatever `AND` / `OR` the caller
  sends, and a bound with nothing in it (null, `''`, `[]`) admits no row (`api/api.sql:240–245`, `:383–389`; db-platform
  1.2.35 from commit `02c5ff8`). On an older pin check before you rely on it: `grep -n "'bound'" sql/platform/api/api.sql`.
- **`IsSystem()` does not mean "our own code".** A configuration's `oauth2.sql` creates one user per OAuth2 audience (name
  = client code) and puts it in group `system` — so every `client_credentials` session is `IsSystem()`. A guard on
  administrative writes uses `IsAdmin()`.
- **`oauth2.audience.code` is unique only per provider** (`oauth2/table.sql:123`): look it up together with the provider.

### Probing rights honestly

Measure rights under the role the request really uses, inside a rolled-back transaction. A `kernel` / `postgres`
connection skips the object write trigger, and `admin` skips the barrier: neither proves anything about a user. Call
`daemon.fetch` / `authorized_fetch` (v1) or `daemon.begin` / `call` / `end` (v2) as `daemon` with the role's token — and as
`apibot` where background code writes — inside `BEGIN … ROLLBACK`. `daemon` cannot read `api` / `kernel` / `db` (some
kernel helpers and `oauth2.*` do not resolve under it by bare name): fetch the ids you need before switching role
(`\gset`), and read the outcome as an administrator through the same `daemon.fetch` in the same transaction. Roles
outside the grant get `permission denied for schema daemon` — use `\set ON_ERROR_ROLLBACK on`, not `ON_ERROR_STOP`.
`apibot` has `api`, `daemon` and `rest` but not `kernel` (`kernel/schema.sql:14–16`): set the platform session and look up
type and class ids before `SET SESSION AUTHORIZATION apibot`. A guard on `session_user` (e.g. "`kernel` only") cannot be
probed through the `daemon` road at all — `daemon` has USAGE on `daemon` alone (`kernel/schema.sql:13`); call the
function directly as `admin` and as `apibot`, and prove an administrator's refusal with an administrator user on a
non-`kernel` connection.

The platform's administrative writes are guarded by `session_user <> 'kernel' AND NOT IsAdmin()` (`workflow/api.sql`,
`error/api.sql`, …; `resource/api.sql` since `75152fe`, after the 1.2.38 bump): a `kernel` connection passes by construction, so probe them under
`SET SESSION AUTHORIZATION daemon` with a user's session, the way AppServer connects. A test harness that opened a
session as an administrator makes `IsAdmin()` true for every later call on that connection — before a refusal test,
assert `IsAdmin()` is false on the connection you use. Test your own read doors for one more property: for a
non-administrator a foreign object should answer as a missing one (`NotFound`) — a different error (a refusal naming
it, an ambiguity of names) tells the caller it exists. The platform's method doors do not keep it: existence is checked
in unfiltered `db.object`, then refused with `-003` / `-001`.

### Every door to an object

An object has more doors than its entity's routes. Besides `/<entity>/…`, these act on it by id: `/method/run|execute`,
`/action/execute`, `/object/method/execute`, `/object/action/execute`, `/object/delete/force`, `/object/access/set`,
`/object/data/set`, `/document/change/area` (1.2.35). The generic setters `/object/set`, `/document/set`, `/reference/set`
are gone since commit `eac160a`, and `api.add_` / `api.update_` of `object`, `document` and `reference` refuse every
connection but `kernel`'s — a pin before it still has them. `/object/data/set` is the door of the object write bit:
`api.set_object_data` asks `CheckObjectAccess(…, B'010')` itself (`entity/object/api.sql:1384`), while an entity's own
`/…/set` refuses by its own rules even behind an open door. Treat every door as able to run any action of
the object's class: a door that runs a method by id reaches the object's events, not your route and not your
`Edit<Entity>`. So put a gate in the events and in `Create` / `Edit`, which every door reaches — not in one route. A function may also be reached over PGHTTP and over REST:
grep its callers, not the door named in the task. A before/after reader covers the state, `db.aou` and `db.object_data`.
A guard by a list of classes, or "everyone except the administrator", is not a guard for a family of doors: every class
added later, and the excepted role, keep the door open — close the road itself.

Data reaches a WebSocket by the observer road: each worker LISTENs on the publishers' channels and calls
`daemon.observer(publisher, code, identity, …)` for every socket marked verified, filtered by `EventListener` /
`FilterListener` per (publisher, session code, identity) (`observer/routine.sql`). A socket becomes verified by a Bearer
whose `sub` is the session code, or by `OPEN` with the session's secret or token; other headers authorise calls but do
not verify. An older WebSocketAPI also pushed by `POST /ws/<code>`: list every road to the socket on your pin and measure
each before and after a gate — a fix of one road leaves the other as it was.

### `/api/v2` identity (measured on 1.2.35 — check that your pin has `gateway.request`)

On `/api/v2` the verified identity is the request's row in `gateway.request`: `daemon.begin` writes it, and no role but
`kernel` may (`gateway/table.sql:153,168`). A `daemon` connection can set the `current.*` GUCs itself — a guard that
branches on `session_user` or reads the GUCs judges the connection, not the person (`IsGatewayRequest` in `ExecuteMethod`).

### Layer table

| Layer | Table | Bits | What it sets | Filled by |
|-------|-------|------|--------------|-----------|
| **ACU** | `db.acu` | `{a c s u d}` 5 | class rights (template for new objects) | `t_class_tree_insert` (defaults) + `chmodc` + configuration init |
| **AMU** | `db.amu` | `{x v e}` 3 | method rights (template) | `t_method_after_insert` (from ACU) + `chmodm` |
| **AOU** | `db.aou` | `{s u d}` 3 | per-row rights (a copy of ACU + owner=B'111') | `t_object_after_insert` (once) + custom triggers + `chmodo` |
| **AOM** | `db.aom` | 9: `{u:sud}{g:sud}{o:sud}` | UNIX-style fallback for the object | default `B'111100000'`, rarely edited |
| **OMA** | `db.oma` | `{x v e}` 3 | method rights on one object for one user (cache) | **lazily** by `CheckObjectMethodAccess` |

### Critical formulas

- **Effective mask:** `bit_or(allow) & ~bit_or(deny)` — aggregated over the user and all their groups (`db.member_group`). **A deny in one group overrides an allow in another.**
- **AOU first, AOM fallback:** `coalesce(GetObjectAccessMask, GetObjectMask) & required = required`. If there is **any** AOU row for (object, the user or a group), AOM is ignored.
- **Owner override:** `t_object_after_insert` always inserts `AOU(object, owner, deny=B'000', allow=B'111')` (`ON CONFLICT UPDATE`). For the owner to have NO rights, either change the owner or run `chmodo(obj, B'111000', owner)` after creation.
- **ACU → AOU copy:** `t_object_after_insert` takes `SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3)` from ACU for each `userid` where `(allow & ~deny) FROM 3 FOR 3 <> B'000'`. The copy is made once, at insert: **a change of class rights must be carried to existing objects by `chmodc(…, pObjectSet => true)`**, the one call that rewrites their AOU.

### Auto-population at class creation (`t_class_tree_insert`)

```
NEW.parent IS NULL                  → ACU(class, administrator, B'00000', B'11111')
                                    + ACU(class, apibot, B'00000', B'01110')
NEW.parent IS NOT NULL              → INHERIT every ACU row of the parent
  + NEW.code = 'document'           → ACU(class, user-group, B'00000', B'11000')  ← access + create
  + NEW.code = 'reference'          → ACU(class, user-group, B'00000', B'10100')  ← access + select
  + NEW.code = 'message'            → ACU(class, mailbot, B'00000', B'01110')
  + NEW.code = 'agent'              → ACU(class, mailbot, B'00000', B'01100')
```

For a **specific role** (driver, employee, partner) add the rights yourself — `INSERT INTO db.acu` or `chmodc(...)` in `init.sql` after the class is created and **before** its first objects (otherwise their AOU will not get that userid).

### DocumentAreaTree — exact semantics (important)

```sql
WITH RECURSIVE area_tree(id, parent) AS (
  -- BASE 1: EVERY default-typed area of current_scope (except current_area)
  SELECT id, parent FROM db.area WHERE type = '<default-area-type-uuid>'
                                  AND scope = current_scope()
                                  AND id <> current_area()
  UNION
  -- BASE 2: current_area itself
  SELECT id, parent FROM db.area WHERE id = current_area()
  UNION
  -- RECURSION DOWN: non-default children
  SELECT a.id, a.parent FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
   WHERE a.type <> '<default-area-type-uuid>'
     AND a.scope = current_scope()
)
SELECT * FROM db.area INNER JOIN area_tree USING (id);
```

**Semantics:** a document is visible when its `area` ∈ {current_area + EVERY default area of the scope + their non-default descendants}.

**Implication:** **`area = <default-typed-area>` = visible to every user in the scope**, whatever their current_area. A document put in the default area is seen by every tenant of the scope, not only by its own. This is not a bug — it is the built-in mechanism for shared/public documents. To narrow it:
- (a) move the documents to a tenant-specific area (visible only in that tenant);
- (b) override DocumentAreaTree in the configuration (by a "public" flag or a new area type).

### Membership (`IsMemberArea`) — inherited **upwards**

```sql
WITH RECURSIVE area_tree(id, parent) AS (
  SELECT id, parent FROM db.area WHERE id = pArea
  UNION ALL
  SELECT a.id, a.parent FROM db.area a, area_tree t WHERE a.id = t.parent
) SELECT count(...) FROM db.member_area m INNER JOIN area_tree a ON m.area = a.id
   WHERE member IN (pMember + their groups)
```

A user is a member of `pArea` when they have a `member_area` row on `pArea` **or on any ancestor** (upwards along the tree). So **member of <dbname> → member of every tenant area under <dbname>** — which is why the system administrator sees every tenant by default.

### Two view patterns (Access<Entity>)

**Production pattern (fast):**
```sql
CREATE OR REPLACE VIEW AccessInvoice
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
)
SELECT object
  FROM db.aou t INNER JOIN _membergroup m ON t.userid = m.userid
 WHERE t.entity = GetEntity('invoice')               ← aou.entity is denormalised
 GROUP BY object
HAVING (bit_or(t.allow) & ~bit_or(t.deny)) & B'100' = B'100';
```

Uses the index `db.aou (entity, userid, mask)`. It does not join the entity table — the entity filter goes through the denormalised column `aou.entity`.

**Wiki-pattern (RLS.md):**
```sql
SELECT a.object FROM db.<entity_table> t INNER JOIN db.aou a ON a.object = t.id
                                         INNER JOIN _membergroup m ON a.userid = m.userid
                                  GROUP BY object
                                    HAVING (...) & B'100' = B'100';
```

Equivalent; the production pattern is faster.

### `Object<Entity>` — mandatory composition

```sql
-- Object<Entity>: data + metadata + area/scope, WITHOUT Access<Entity> (dynamic model)
SELECT t.*, ... FROM db.<entity_table> t
  INNER JOIN db.object       o ON t.document = o.id        -- common part
  INNER JOIN db.document     d ON t.document = d.id
  ...
  INNER JOIN DocumentAreaTree a ON d.area = a.id           -- (2) AREA visibility
  INNER JOIN db.scope        sc ON o.scope = sc.id;

-- api.<entity>: read by id — a static join with Access<Entity>
CREATE OR REPLACE VIEW api.<entity> AS
  SELECT t.* FROM Object<Entity> t INNER JOIN Access<Entity> a ON t.id = a.object;

-- api.list_/count_: the join is added by api.sql('kernel', 'Object<Entity>', …) at run time
```

Three rules: (1) `Object<Entity>` does **not** reference `Access<Entity>` — the join is added by `api.sql()` and skipped for an administrator; the old form with the join inside is a different security model, do not port it; (2) `Object<X>`/`Access<X>` are one to one, the name is derived as a string (`object`→`access`), and a missing pair silently switches the filter off; (3) **never skip `DocumentAreaTree`** for documents. For **references** (no area) — `Access<Entity>` through `api.<entity>`/`api.sql('kernel',…)` + the filter `r.scope = current_scope()`.

### Method access (AMU/OMA)

- `CheckObjectMethodAccess(obj, method, mask)` fills `db.oma` from AMU (the user and their groups) on the first call for an (object, method, user); later calls read the cached row.
- `chmodm(method, mask, user)` changes AMU and clears `db.oma` for that method (`workflow/routine.sql:2217`).
- **Change method rights through `chmodm`.** A direct write to `db.amu`, or a change of the groups a user belongs to, does not reach rows already in `db.oma`: when your code moves a user between groups that hold different method rights, clear that user's `db.oma` rows in the same transaction.
- `ExecuteDynamicMethod` (REST dispatcher fallback) also checks `CheckObjectMethodAccess` before running.

### db.acl ≠ ACU/AOU

**`db.acl` (admin module)** is a **17-bit** mask of **administrative operations**: login/logout/create user/delete area/substitute/... Do not confuse it with entity-level rights on classes and objects. It is used by `CheckAccessControlList(B'...', userid)` in login/SignIn/CreateArea/etc.

### chmod functions

| Function | What it does |
|---------|------------|
| `chmodc(class, mask10, user, recursive, objectSet)` | INSERT/UPDATE ACU. With `pObjectSet=true` cascades to the AOU of every object of the class. With `pRecursive=true` — down the class_tree. |
| `chmodm(method, mask6, user)` | INSERT/UPDATE/DELETE AMU; clears `db.oma` for the method |
| `chmodo(object, mask6, user)` | INSERT/UPDATE/DELETE AOU. `mask6 = {deny:sud}{allow:sud}`. `B'000000'` or NULL → DELETE. |

All three require `session_user = 'kernel'` or `IsUserRole('administrator')`.

**`objectSet => true` means every existing object of the class**, not only future ones: the loop
`FOR r IN SELECT id FROM db.object WHERE class = pClass AND owner <> pUserId` (`platform/workflow/routine.sql:786`, 1.2.31) —
root and seeded objects get the mask too. Look at what the call will land on before making it.

**`CheckClassAccess` has no exemption for admin/system** — it is a bare check of the ACU mask (`workflow/routine.sql:651–658`),
and in platform 1.2.35 nothing calls it (see "What the layer names promise").
The seed of class `document` gives the group `user` the bits `a` and `c` (`B'11000'`, `workflow/table.sql:112`), and subclasses copy
the parent's ACU (`:108`): a gate of "check bit `c`" on a document closes nothing for signed-in users — give the class its own rights.

**`mask` of `db.acu`, `db.amu`, `db.acl` is derived as `allow & ~deny`** by a BEFORE trigger
(`workflow/table.sql:195`, `:572`; `admin/table.sql:1279`). A mutant on `mask` is empty — change `allow` / `deny`.

**A temporary per-object grant** (an extra bit in `db.aou` for one action, then removed) restores the **previous mask**:
clearing the bit (`allow & ~bit`) also takes it from a legitimate holder.

---
