<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 9 — Access Control (full picture)

### Three independent dimensions of visibility

Документ становится виден пользователю **только если выполнены ВСЕ ТРИ** условия:

1. **AOU/AOM (object permission)** — есть AOU-запись `(object, user или его группы)` с select bit, или AOM fallback даёт select по UNIX-логике (owner/group/other).
2. **DocumentAreaTree (organisational scope)** — `db.document.area` входит в видимое дерево area от текущей сессии.
3. **Scope (multi-tenant partition)** — `db.object.scope = current_scope()`.

Эти три проверки **независимы и кумулятивны**. Дать AOU без правильного area = документ невидим. Подходящий area без AOU = документ невидим.

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

### Every door to an object

An object has more doors than its entity's routes. Besides `/<entity>/…`, these act on it by id: `/method/run|execute`,
`/action/execute`, `/object/method/execute`, `/object/action/execute`, `/object/set`, `/object/delete/force`,
`/object/access/set`, `/object/data/set`, `/document/set`, `/document/change/area` (1.2.35). `ExecuteDynamicMethod` resolves
only the action segment of the path and does not check the entity segment against the object's class
(`api/routine.sql:450`), and a method run by id bypasses `Edit<Entity>`. So put a gate in the events and in
`Create` / `Edit`, which every door reaches — not in one route. A function may also be reached over PGHTTP and over REST:
grep its callers, not the door named in the task. A before/after reader covers the state, `db.aou` and `db.object_data`.

### `/api/v2` identity (measured on 1.2.35 — check that your pin has `gateway.request`)

On `/api/v2` the verified identity is the request's row in `gateway.request`: `daemon.begin` writes it, and no role but
`kernel` may (`gateway/table.sql:153,168`). A `daemon` connection can set the `current.*` GUCs itself — a guard that
branches on `session_user` or reads the GUCs judges the connection, not the person (`IsGatewayRequest` in `ExecuteMethod`).

### Layer table

| Layer | Table | Bits | Что задаёт | Заполняется |
|-------|-------|------|------------|-------------|
| **ACU** | `db.acu` | `{a c s u d}` 5 | права класса (template для новых объектов) | `t_class_tree_insert` (defaults) + `chmodc` + configuration init |
| **AMU** | `db.amu` | `{x v e}` 3 | права метода (template) | `t_method_after_insert` (из ACU) + `chmodm` |
| **AOU** | `db.aou` | `{s u d}` 3 | per-row права (snapshot ACU + owner=B'111') | `t_object_after_insert` (один раз) + custom triggers + `chmodo` |
| **AOM** | `db.aom` | 9: `{u:sud}{g:sud}{o:sud}` | UNIX-style fallback на объект | default `B'111100000'`, редко редактируется |
| **OMA** | `db.oma` | `{x v e}` 3 | права метода на конкретном объекте (cache) | **lazy** в `CheckObjectMethodAccess` |

### Critical formulas

- **Effective mask:** `bit_or(allow) & ~bit_or(deny)` — агрегация по user + всем его группам (`db.member_group`). **Deny в одной группе перекрывает allow в другой**.
- **AOU first, AOM fallback:** `coalesce(GetObjectAccessMask, GetObjectMask) & required = required`. Если есть **любая** AOU-запись для (object, user или группа) — AOM игнорируется.
- **Owner override:** `t_object_after_insert` всегда вставляет `AOU(object, owner, deny=B'000', allow=B'111')` (`ON CONFLICT UPDATE`). Чтобы owner НЕ имел прав — нужно либо сменить owner, либо явно сделать `chmodo(obj, B'111000', owner)` после создания.
- **ACU → AOU копирование:** `t_object_after_insert` берёт `SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3)` из ACU для каждого `userid` где `(allow & ~deny) FROM 3 FOR 3 <> B'000'`. Изменение ACU **не влияет на существующие AOU**.
- **chmodc(class, mask, user, pRecursive, pObjectSet)** — единственный быстрый способ перепрошить AOU всех существующих объектов после изменения ACU (`pObjectSet=true`).

### Auto-population at class creation (`t_class_tree_insert`)

```
NEW.parent IS NULL                  → ACU(class, administrator, B'00000', B'11111')
                                    + ACU(class, apibot, B'00000', B'01110')
NEW.parent IS NOT NULL              → INHERIT все ACU родителя
  + NEW.code = 'document'           → ACU(class, user-group, B'00000', B'11000')  ← access + create
  + NEW.code = 'reference'          → ACU(class, user-group, B'00000', B'10100')  ← access + select
  + NEW.code = 'message'            → ACU(class, mailbot, B'00000', B'01110')
  + NEW.code = 'agent'              → ACU(class, mailbot, B'00000', B'01100')
```

Для **специфической роли** (driver, employee, partner) — нужно вручную `INSERT INTO db.acu` или `chmodc(...)` в `init.sql` после создания класса, **до** создания первых объектов (иначе AOU не получит этот userid).

### DocumentAreaTree — точная семантика (важно!)

```sql
WITH RECURSIVE area_tree(id, parent) AS (
  -- БАЗА 1: ВСЕ default-typed areas current_scope (исключая current_area)
  SELECT id, parent FROM db.area WHERE type = '<default-area-type-uuid>'
                                  AND scope = current_scope()
                                  AND id <> current_area()
  UNION
  -- БАЗА 2: сам current_area
  SELECT id, parent FROM db.area WHERE id = current_area()
  UNION
  -- РЕКУРСИЯ ВНИЗ: non-default дети
  SELECT a.id, a.parent FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
   WHERE a.type <> '<default-area-type-uuid>'
     AND a.scope = current_scope()
)
SELECT * FROM db.area INNER JOIN area_tree USING (id);
```

**Семантика:** видимы документы у которых `area` ∈ {current_area + ВСЕ default-area scope + non-default потомки}.

**Импликация:** **`area = <default-typed-area>` = глобально видимо для всех users в scope**, независимо от их current_area. Это и есть причина «когда станции в Default area, водители их видят, но и все CPO тоже». Это не баг — это встроенный механизм для shared/public документов. Альтернативы: 
- (a) сменить area документов на специфический tenant-area (видны только в этом tenant'е);
- (b) переопределить DocumentAreaTree в configuration (по логике «public boolean» или новому area-type).

### Membership (`IsMemberArea`) — наследование **вверх**

```sql
WITH RECURSIVE area_tree(id, parent) AS (
  SELECT id, parent FROM db.area WHERE id = pArea
  UNION ALL
  SELECT a.id, a.parent FROM db.area a, area_tree t WHERE a.id = t.parent
) SELECT count(...) FROM db.member_area m INNER JOIN area_tree a ON m.area = a.id
   WHERE member IN (pMember + его группы)
```

User считается членом `pArea` если у него есть `member_area`-запись на `pArea` **или на любом предке** (т.е. вверх по дереву). То есть **member of <dbname> → member of всех tenant-area под <dbname>**. Это причина «администратор системы видит все тенанты по умолчанию».

### Two view patterns (Access<Entity>)

**Production pattern (fast):**
```sql
CREATE OR REPLACE VIEW AccessChargePoint
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
)
SELECT object
  FROM db.aou t INNER JOIN _membergroup m ON t.userid = m.userid
 WHERE t.entity = GetEntity('charge_point')          ← денормализация aou.entity
 GROUP BY object
HAVING (bit_or(t.allow) & ~bit_or(t.deny)) & B'100' = B'100';
```

Использует индекс `db.aou (entity, userid, mask)`. Не JOIN'ит entity-table — entity-фильтр через денормализованное поле `aou.entity`.

**Wiki-pattern (RLS.md):**
```sql
SELECT a.object FROM db.<entity_table> t INNER JOIN db.aou a ON a.object = t.id
                                         INNER JOIN _membergroup m ON a.userid = m.userid
                                  GROUP BY object
                                    HAVING (...) & B'100' = B'100';
```

Эквивалентны, производственный вариант быстрее.

### `Object<Entity>` — обязательная композиция

```sql
-- Object<Entity>: данные + метаданные + area/scope, БЕЗ Access<Entity> (динамическая модель)
SELECT t.*, ... FROM db.<entity_table> t
  INNER JOIN db.object       o ON t.document = o.id        -- общая часть
  INNER JOIN db.document     d ON t.document = d.id
  ...
  INNER JOIN DocumentAreaTree a ON d.area = a.id           -- (2) AREA visibility
  INNER JOIN db.scope        sc ON o.scope = sc.id;

-- api.<entity>: чтение по id — статический join с Access<Entity>
CREATE OR REPLACE VIEW api.<entity> AS
  SELECT t.* FROM Object<Entity> t INNER JOIN Access<Entity> a ON t.id = a.object;

-- api.list_/count_: join добавляет api.sql('kernel', 'Object<Entity>', …) в рантайме
```

Три правила: (1) `Object<Entity>` **не** ссылается на `Access<Entity>` — join добавляется `api.sql()` и пропускается для администратора; старая форма с join внутри — другая модель безопасности, не переносить; (2) пара `Object<X>`/`Access<X>` — один к одному, имя выводится строкой (`object`→`access`), отсутствие пары молча выключает фильтр; (3) **никогда не пропускать `DocumentAreaTree`** для documents. Для **references** (нет area) — `Access<Entity>` через `api.<entity>`/`api.sql('kernel',…)` + фильтр `r.scope = current_scope()`.

### Method access (AMU/OMA)

- `CheckObjectMethodAccess(obj, method, mask)` — **lazy populates** `db.oma` из AMU при первом вызове. Дальше — индексный лукап.
- `chmodm(method, mask, user)` — изменение AMU. Меняется только template; уже закэшированные OMA-записи остаются. Удалить кэш: `DELETE FROM db.oma WHERE method = ... AND userid = ...`.
- `ExecuteDynamicMethod` (REST dispatcher fallback) тоже проверяет `CheckObjectMethodAccess` перед запуском.

### db.acl ≠ ACU/AOU

**`db.acl` (admin module)** — это **17-битная** маска **административных операций**: login/logout/create user/delete area/substitute/...  Не путать с entity-level правами на классы и объекты. Используется в `CheckAccessControlList(B'...', userid)` в функциях login/SignIn/CreateArea/etc.

### chmod-функции

| Функция | Что делает |
|---------|------------|
| `chmodc(class, mask10, user, recursive, objectSet)` | INSERT/UPDATE ACU. С `pObjectSet=true` каскадно обновляет AOU всех объектов класса. С `pRecursive=true` — вглубь class_tree. |
| `chmodm(method, mask6, user)` | INSERT/UPDATE AMU |
| `chmodo(object, mask6, user)` | INSERT/UPDATE/DELETE AOU. `mask6 = {deny:sud}{allow:sud}`. `B'000000'` или NULL → DELETE. |

Все три требуют `session_user = 'kernel'` или `IsUserRole('administrator')`.

**`objectSet => true` — это все уже существующие объекты класса**, не только будущие: цикл
`FOR r IN SELECT id FROM db.object WHERE class = pClass AND owner <> pUserId` (`platform/workflow/routine.sql:786`, 1.2.31) —
корневые и засевные объекты получают маску тоже. Смотрите, на что ляжет вызов, до вызова.

**`CheckClassAccess` обхода для admin/system не имеет** — это голая проверка маски ACU (`workflow/routine.sql:651–658`),
и в платформе 1.2.35 её никто не вызывает (см. «What the layer names promise»).
А засев класса `document` даёт группе `user` биты `a` и `c` (`B'11000'`, `workflow/table.sql:112`), и подклассы копируют
ACU родителя (`:108`): «проверить бит `c`» на документе ничего не закрывает для вошедших пользователей.

**`mask` у `db.acu`, `db.amu`, `db.acl` — производная `allow & ~deny`**, её ставит BEFORE-триггер
(`workflow/table.sql:195`, `:572`; `admin/table.sql:1279`). Мутант по `mask` пуст — меняйте `allow` / `deny`.

**A temporary per-object grant** (an extra bit in `db.aou` for one action, then removed) restores the **previous mask**:
clearing the bit (`allow & ~bit`) also takes it from a legitimate holder.

---
