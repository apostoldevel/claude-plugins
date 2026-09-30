# db-platform Report Subsystem — Reference

> Companion document for `SKILL.md` (skill `/apostol-project`).
>
> Полная справка по подсистеме отчётов db-platform: типы отчётов, готовых
> отчётов, workflow, async-микросервисная интеграция, ReportServer, pattern
> `rpc_*` + `rcb_*` + callback.
>
> **When to read:** перед тем как создавать новый отчёт, дорабатывать
> существующий, интегрировать async-микросервис генерации файлов (DOCX/PDF/Excel),
> или разобраться откуда берётся `Reports UI` и «История отчётов».

---

## 1. Двухуровневая модель отчётов

Platform различает **две сущности с разной семантикой**, и путать их —
основная причина ошибок:

| Уровень | Сущность | Зачем |
|---|---|---|
| **Definition** | `db.report` (reference) | Статичный «каталог» отчётов: что существует, где висит в UI, какая форма параметров, какая процедура выполняется |
| **Ready** | `db.report_ready` (document) | Динамический экземпляр запуска: конкретные параметры из формы, состояние выполнения, готовый файл-результат |

Один definition → много ready (по одному на каждый запуск пользователем).

### 1.1 Definition (статичный)

Создаётся **один раз** в `init.sql` через `InitReport()` / `InitObjectReport()`
/ `CreateReport()`. Это REFERENCE-сущность (entity = `report`, parent = `reference`).

```
db.report
├── id         uuid
├── reference  uuid  → db.reference (наследование)
├── tree       uuid  → ReportTree (узел в дереве UI)
├── form       uuid  → ReportForm  (параметры формы)
├── binding    uuid  → class_tree   (NULL для global, class для object-scoped)
└── info       jsonb
```

**Definition types** (`db.type` на классе `report`):

| Type code | Применение | Где видно в UI |
|---|---|---|
| `report.report` | Стандартный отчёт в дереве | Reports UI tree, форма параметров |
| `object.report` | Отчёт привязан к классу объекта (через `binding`) | В карточке объекта данного класса (как контекстная кнопка) |
| `import.report` | Отчёт-импорт | Reports UI tree, специальная обработка с upload |

### 1.2 Ready (динамичный)

Создаётся **каждым запуском** через `BuildReport()` → `CreateReportReady()`.
Это DOCUMENT-сущность (entity = `report_ready`, parent = `document`).

```
db.report_ready
├── id        uuid       → db.document (наследование)
├── document  uuid
├── report    uuid       → исходный definition
└── form      jsonb      → snapshot параметров запуска
```

**Ready types** (`db.type` на классе `report_ready`):

| Type code | UX эффект |
|---|---|
| **`sync.report_ready`** (default в `BuildReport`) | Юрист ждёт результат прямо на форме (loading + polling, бэк формирует → завершает → форма показывает) |
| **`async.report_ready`** | Юрист сразу видит «формируется», уходит в «Историю отчётов», polling переносится туда |

**КЛЮЧЕВОЕ:** workflow report_ready (state machine: `created → progress →
completed/failed/canceled/deleted`) **идентичен** для обоих типов. На уровне
DB разницы нет — это семантическая метка для frontend UX, ничего больше.

---

## 2. Workflow report_ready

```
                    create
        ┌──────────────────────────┐
        ▼                          │
   ┌─────────┐  execute   ┌─────────────┐  complete  ┌────────────┐
   │ created │ ─────────▶ │  progress   │ ─────────▶ │ completed  │
   └─────────┘            └─────┬───────┘            └────────────┘
        │                       │ fail
        │ delete                ▼            ┌────────────┐
        ▼                ┌──────────┐        │  failed    │
   ┌─────────┐           │ canceled │  ◀─────┴────────────┘
   │ deleted │           └──────────┘
   └─────────┘                 │ abort
                               ▼
                          ┌──────────┐
                          │ aborted  │
                          └──────────┘
```

Создаётся в state `created`. Чтобы запустить — выполнить action `execute` →
переход в `progress` → срабатывает `EventReportReadyExecute()` →
вызывается `ExecuteReportReady(pReady)`.

### 2.1 ExecuteReportReady (platform)

```sql
-- backend/db/sql/platform/report/ready/routine.sql:148
ExecuteReportReady(pId uuid)
  → FOR routine IN SELECT definition FROM db.report_routine WHERE report = uReport
                     ORDER BY sequence
    LOOP
      EXECUTE 'SELECT report.<routine_code>($1, $2);' USING pId, jForm;
    END LOOP;
```

Находит все `report_routine` привязанные к definition (обычно одна — `rpc_<code>`),
выполняет каждую с параметрами `(pReady, pForm)`. Они и формируют результат.

### 2.2 Action mapping

| Action | Triggered by | Эффект |
|---|---|---|
| `create` | `CreateReportReady()` | INSERT row, state=created |
| `execute` | `BuildReport()` или явный `api.execute_report_ready()` | → progress + запуск `rpc_*` |
| `complete` | `DoAction(pReady, 'complete')` из `rpc_*` или callback-цепочки | → completed |
| `fail` | `DoAction(pReady, 'fail')` при exception | → failed |
| `cancel` | Пользователь отменил | → canceled |
| `delete` / `restore` / `drop` | Стандартные lifecycle | — |

---

## 3. Создание отчёта — три точки входа

### 3.1 `InitReport()` — отчёт в дереве (стандартный)

```sql
-- platform/report/routine.sql:147
InitReport(pParent, pType, pTree, pCode, pName, pDescription) RETURNS uuid
```

Создаёт **тройку**: form + report definition + routine.

- Form: `CreateReportForm()` с `code = 'rfc_' || pCode` (frontend ожидает функцию `report.rfc_<code>(pForm uuid, pParams jsonb)`)
- Definition: `CreateReport(pType, pTree, uForm, ...)` с переданным `pType`
- Routine: `CreateReportRoutine()` с `code = 'rpc_' || pCode` (обязательно должна существовать как `report.rpc_<code>(pReady uuid, pForm jsonb)`)

Применение: отчёт виден в дереве Reports UI как отдельный пункт.

**Пример:**
```sql
PERFORM InitReport(null, GetType('report.report'), uNode_debt,
                   'debt_notification',
                   'Уведомление о задолженности',
                   'Формирование уведомлений о задолженности.');
-- => создаются rfc_debt_notification + rpc_debt_notification (нужно реализовать)
```

### 3.2 `InitObjectReport()` — контекстный отчёт на классе

```sql
-- platform/report/routine.sql:187
InitObjectReport(pParent, pTree, pForm, pBinding, pCode, pName, pDescription) RETURNS uuid
```

Создаёт definition с **фиксированным** `type=GetType('object.report')` и
`binding=<class_uuid>`. Форма передаётся **снаружи** (`pForm`) — обычно
общая для всех object-отчётов (`rfc_identifier_form`). Routine создаётся
автоматически с `code = 'rpc_' || pCode`.

Применение: отчёт виден **из карточки объекта** этого класса (контекстная кнопка).

**Пример:**
```sql
uForm := CreateReportForm(null, GetType('json.report_form'),
                          'rfc_identifier_form', 'Object identifier form',
                          'rfc_identifier_form', '...');

PERFORM InitObjectReport(null, uRoot, uForm, GetClass('trial'),
                         'court_order',
                         'Заявление о вынесении судебного приказа', null);
-- => rpc_court_order должна быть реализована, форма rfc_identifier_form общая
```

### 3.3 `CreateReport()` — низкоуровневый

```sql
-- platform/report/routine.sql:20
CreateReport(pParent, pType, pTree, pForm, pBinding, pCode, pName, pDescription, pInfo) RETURNS uuid
```

Прямое создание definition без авто-генерации формы и routine. Использовать
если форма и routine создаются отдельно или переиспользуются.

---

## 4. Запуск отчёта — два варианта UX

### 4.1 `BuildReport()` — главная точка запуска

```sql
-- platform/report/routine.sql:224
BuildReport(pReport, pType DEFAULT NULL, pForm DEFAULT NULL,
            pName DEFAULT NULL, pDescription DEFAULT NULL) RETURNS uuid
  → pType := coalesce(pType, GetType('sync.report_ready'))
  → RETURN CreateReportReady(pReport, pType, pReport, pForm, ...)
```

`pType` определяет UX-режим:
- **NULL / `sync.report_ready`** (default) — юрист ждёт результат в форме
- **`async.report_ready`** — юрист уходит в «Историю отчётов»

### 4.2 Через REST `/report/build`

Стандартный flow Reports UI. Frontend выбирает пункт в дереве, заполняет
форму, нажимает «Продолжить» → `POST /report/build {report_id, form}` →
backend вызывает `BuildReport(uReport, NULL, jForm)` → default sync.

### 4.3 Через REST entity-специфичный endpoint (контекстная кнопка)

Когда нужен async-режим и pre-filled параметры:

```sql
-- В rest.trial:
WHEN '/trial/court_order/generate' THEN
  uReport := GetReport('court_order');  -- existing object.report definition
  uReady  := BuildReport(
    uReport,
    GetType('async.report_ready'),                  -- ← async
    jsonb_build_object('debt_id', r.id)             -- pre-filled form
  );
  RETURN NEXT row_to_json(t) FROM (SELECT uReady AS report_ready_id, 'progress' AS status) t;
```

Frontend получает `report_ready_id`, не делает polling — пользователь видит
результат позже в «Истории отчётов».

---

## 5. Pattern `rpc_*` (обязательная) + `rcb_*` (опциональная для async)

### 5.1 `rpc_<code>(pReady, pForm)` — обязательная

Сигнатура: `(pReady uuid, pForm jsonb DEFAULT NULL) RETURNS void`.

Вызывается через `ExecuteReportReady` после `execute` action. Реализует **всё
формирование отчёта**:

```sql
CREATE OR REPLACE FUNCTION report.rpc_debt_notification(
  pReady  uuid,
  pForm   jsonb default null
) RETURNS void AS $$
DECLARE
  vHTML      text;
  html_file  bytea;
  houses     jsonb;
BEGIN
  -- 1. Извлекаем параметры из формы
  -- 2. Запрашиваем данные из БД
  -- 3. Формируем HTML-content
  vHTML := '...';
  html_file := convert_to(vHTML, 'UTF8');

  -- 4. Сохраняем HTML в файл (всегда — для preview/просмотра)
  PERFORM SetObjectFile(pReady, null, 'index.html', null,
    length(html_file), localtimestamp, html_file,
    encode(digest(html_file, 'md5'), 'hex'),
    'Уведомление о задолженности', 'data:text/html;base64,');

  -- 5. Если нужен async docx через микросервис — вызываем rcb_*
  IF houses IS NOT NULL THEN
    PERFORM report.rcb_debt_notification(pReady,
      jsonb_build_object('meta', meta, 'houses', houses));
    -- DoAction(complete) НЕ ВЫЗЫВАЕМ — это сделает callback flow
  ELSE
    -- Иначе сразу завершаем (только HTML, без docx)
    PERFORM DoAction(pReady, 'complete');
  END IF;

EXCEPTION WHEN others THEN
  -- error → SetObjectFile с error.html + DoAction(fail)
  PERFORM DoAction(pReady, 'fail');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, public, pg_temp;
```

### 5.2 `rcb_<code>(pObject, pPayload, pMetadata)` — опциональная

Сигнатура: `(pObject uuid, pPayload jsonb, pMetadata jsonb DEFAULT NULL) RETURNS void`.

Вызывается из `rpc_*` когда нужна async-генерация файла внешним микросервисом
(docx-service, docx-generator, custom). Это «callback» в смысле «делегирование
работы через HTTP с callback'ом обратно».

```sql
CREATE OR REPLACE FUNCTION report.rcb_debt_notification(
  pObject       uuid,         -- = pReady из rpc_*
  pPayload      jsonb,
  pMetadata     jsonb DEFAULT null
) RETURNS void AS $$
DECLARE
  vCallback  text;
  vAPI       text;
  headers    jsonb;
BEGIN
  vCallback := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Backend')
               || '/api/v1/callback/<service-name>';
  vAPI := RegGetValueString('CURRENT_CONFIG', 'CONFIG\Service\<service>\API', 'URL');

  headers := jsonb_build_object('Content-Type', 'application/json');

  PERFORM http.fetch(
    format('%s/generate?callback=%s/%s', vAPI, vCallback, pObject),
    'POST', headers, pPayload,
    'api.<service>_done',     -- on 2xx
    'api.<service>_fail',     -- on connect/error
    '<service>', 'default', 'generate', null, 'curl', pMetadata);
EXCEPTION WHEN others THEN
  -- error → SetObjectFile с error.html + DoAction(fail)
  PERFORM DoAction(pObject, 'fail');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, public, pg_temp;
```

`rcb_*` **только запускает** http.fetch и возвращает управление. Реальное
завершение workflow (`DoAction(complete)`) произойдёт **после** того как
async-микросервис пришлёт callback и файл будет скачан PGFile'ом.

### 5.3 Когда нужна `rcb_*`

- ✅ Нужна docx/pdf-генерация во внешнем сервисе (async, с callback)
- ✅ Нужна PDF-конверсия (LibreOffice headless)
- ✅ Нужен внешний расчёт/обработка
- ❌ Не нужна для чисто-SQL отчётов (HTML-генерация в `rpc_*` → `DoAction(complete)` сразу)

---

## 6. Полный pipeline async-генерации (DOCX через микросервис)

```
Frontend                Backend (PL/pgSQL)              Микросервис
─────────                ──────────────────              ───────────

POST /report/build  ───▶ rest.report dispatcher
                         BuildReport(uReport,
                           pType=sync.report_ready,    -- или async
                           pForm)
                         CreateReportReady(...)
                         → state=created
                         → execute action

                         EventReportReadyExecute
                         → ExecuteReportReady(pReady)
                         → SELECT routines WHERE report=uReport
                         → EXECUTE rpc_<code>(pReady, pForm)
                         │
                         ├── rpc_<code>:
                         │   1. Извлечь pForm параметры
                         │   2. Запрос данных из БД
                         │   3. Сформировать payload
                         │   4. SetObjectFile(pReady, 'index.html', html)
                         │   5. rcb_<code>(pReady, payload)
                         │      │
                         │      └── http.fetch(
                         │            <service>/generate
                         │            ?callback=<backend>/.../<pReady>,
                         │            POST, headers, payload)
                         │          → NOTIFY 'http'
                         │
              (управление вернулось)
                                                        PGFetch (C++ helper)
                                                        picks up 'http' notify
                                                        POST <service>/generate ─▶ микросервис
                                                                                   принимает task
                                                                                   возвращает 200 OK
                                                                                   (или 202 queued)
                                                        ← 2xx
                                                        → api.<service>_done(uFetch)
                                                          (не финиширует workflow,
                                                           только пометка что fetch ушёл)

(пользователь ждёт... 3-30s)                            Микросервис формирует файл

                         POST callback ◀───────────────  POST <backend>/api/v1/callback/<service>/<pReady>
                         (PGHTTP принимает)              body: {status, result: {file_name, download_url}, ...}
                         → rest.callback
                         → api.<service>_callback(pReady, pPayload)
                         │
                         ├── api.<service>_callback:
                         │   if status='failed':
                         │     WriteToEventLog(E)
                         │     DoAction(pReady, 'fail')
                         │     RETURN
                         │   if status='completed':
                         │     SetObjectFile(
                         │       pReady,
                         │       file_name,
                         │       '/public/report_ready/<pReady>/',
                         │       size=0, mtime=now,
                         │       data=convert_to(<service>/download_url),
                         │       sum=null, file_name,
                         │       mime='text/x-uri',  -- ← URL, не bytes
                         │       'api.<service>_download_done',
                         │       'api.<service>_download_fail')
                         │     -- NOTIFY 'file' уйдёт триггером
                         │
                                                        PGFile (C++ helper)
                                                        picks up 'file' notify
                                                        видит mime='text/x-uri'
                                                        GET <service>/download_url ─▶ микросервис
                                                                                       streams file
                                                        ← file bytes
                                                        сохраняет в db.file
                                                        + /file/public/report_ready/<pReady>/<file_name>

                         api.<service>_download_done(pReady)
                         → DoAction(pReady, 'complete')
                         → state=completed
                         → EventReportReadyComplete фиксирует в лог

Frontend polling /report/ready/get
видит state=completed
получает ссылку на /file/public/report_ready/<pReady>/<file_name>
показывает пользователю
```

### 6.1 Ключевые моменты

1. **`SetObjectFile` с `mime='text/x-uri'`** — особый маркер для PGFile:
   - Поле `data` содержит **URL** (а не bytes файла)
   - PGFile делает GET по этому URL и сохраняет ответ как файл
   - Это и есть «download_url proxy» pattern

2. **Два callback'а на стороне backend:**
   - `api.<service>_done/_fail` — для http.fetch (от PGFetch): попал ли запрос в микросервис
   - `api.<service>_callback` — для callback от микросервиса (через PGHTTP): результат генерации
   - `api.<service>_download_done/_fail` — для PGFile: скачался ли файл

3. **`DoAction(pReady, 'complete')` срабатывает только после download** — это гарантирует что к моменту complete файл уже в `db.file`.

4. **Если callback не пришёл за разумное время** — нет автоматического timeout-механизма в платформе. Frontend может определить «stuck progress» сам.

---

## 7. Memory: уже зафиксированный feedback

Из памяти агента проекта debt-master (урок о завершении асинхронного отчёта):

> **Async report complete:** DoAction('complete') on report_ready fires
> immediately on 200/202 (т.е. PGFetch_done), not after callback — releases
> frontend spinner

Это **тонкость production-оптимизации**: некоторые проекты делают
`DoAction(pReady, 'complete')` уже на стадии `api.<service>_done` (200/202
ответ от микросервиса), чтобы фронт отпустился сразу. Файл пришёл попозже —
видно через `SetObjectFile`-обновление. Это **частный случай для UX** где
важно не блокировать пользователя.

**Default pattern** (см. §6) — complete после download.

---

## 8. Anti-patterns в работе с отчётами

| ❌ Anti-pattern | ✅ Правильно |
|---|---|
| `CreateReport(pType=>GetType('async.report'))` | Такого типа нет на уровне definition. `async/sync` — только на уровне report_ready через `BuildReport(uReport, GetType('async.report_ready'), ...)` |
| Прямой `http.fetch` к docx-service из `rpc_*` минуя `rcb_*` | Соблюдай `rpc_* → rcb_* → http.fetch` пайплайн; rcb-функция изолирует HTTP-detail |
| `DoAction(pReady, 'complete')` в `rpc_*` сразу после `rcb_*` | Не делать! Complete должен прийти из callback flow после реальной готовности файла |
| Хардкод URL микросервиса в `rcb_*` | Через registry: `RegGetValueString('CURRENT_CONFIG', 'CONFIG\Service\<service>\API', 'URL')` |
| Хардкод callback path | Через registry: `RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Backend') || '/api/v1/callback/<service>'` |
| Создание `db.report` строки руками (INSERT) | Только через `CreateReport()` / `InitReport()` / `InitObjectReport()` — они вызывают workflow events |
| `BuildReport` без `pForm` когда `rpc_*` ожидает параметры | Frontend должен передать pForm в `POST /report/build`; backend проксирует в BuildReport |
| Полагаться на sync/async-тип в `rpc_*` для разной логики | rpc — одинаковая для обоих. Sync/async — только UX. Если нужна разная логика — передавай через `pForm` |
| Забыть `r.code='execute'` event с `'ChangeObjectState();'` | Этот event обязателен для перехода created→progress (для custom workflow extension) |
| Создавать новый `db.report_ready` руками вместо `BuildReport` | Workflow events не сработают — отчёт зависнет в `created`. Всегда через `BuildReport()` |

---

## 9. Reference: чек-лист «новый отчёт через async-микросервис»

1. **Schema:** добавить колонки (если нужно) через patch + DDL
2. **Builder:** `api.build_<code>_context(pSourceObject)` — собирает payload для микросервиса
3. **Routine:** `report.rpc_<code>(pReady, pForm)` — извлекает params, вызывает builder, SetObjectFile HTML preview, вызывает `rcb_<code>(pReady, payload)`
4. **Callback wrapper:** `report.rcb_<code>(pObject, pPayload, pMetadata)` — обёртка через abstraction layer (`docx.generate()` в проекте debt-master) или прямой http.fetch
5. **Callback handler:** `api.<service>_callback(pObject, pPayload)` — обработка success/failed/warnings, SetObjectFile с download_url
6. **Download handlers:** `api.<service>_download_done(pObject)` + `_download_fail(pObject)` — `DoAction(complete/fail)` после PGFile
7. **REST callback route:** регистрация `/api/v1/callback/<service>` → `rest.callback` → `api.<service>_callback`
8. **Definition (init.sql):** `InitReport()` (для дерева) или `InitObjectReport()` (для карточки объекта) — создаст автоматически rfc_/rpc_ заглушки, их нужно реализовать (см. шаги 2-3)
9. **Registry:** `RegSetValueString` для URL микросервиса + (опц.) per-type routing
10. **Frontend:** для контекстной кнопки — entity-специфичный endpoint типа `/<entity>/<report_code>/generate`, передавать `BuildReport(..., GetType('async.report_ready'), ...)`. Для дерева — стандартный flow Reports UI без изменений на фронте.
11. **Smoke:** test `api.build_*_context` → curl test микросервис → polling до complete → проверка `/file/public/report_ready/<pReady>/<file_name>` доступен

---

## 10. Reference: файлы платформы для углубления

- `backend/db/sql/platform/report/routine.sql` — `CreateReport`, `InitReport`, `InitObjectReport`, `BuildReport`
- `backend/db/sql/platform/report/ready/routine.sql` — `CreateReportReady`, `ExecuteReportReady`
- `backend/db/sql/platform/report/ready/init.sql` — workflow `report_ready` (states/methods/transitions/events)
- `backend/db/sql/platform/report/ready/event.sql` — все Event handlers (Create/Execute/Complete/Fail/Cancel/Abort/...)
- `backend/db/sql/platform/report/api.sql` — `api.report_*` REST wrappers
- `backend/db/sql/platform/report/ready/api.sql` — `api.report_ready_*` + `api.execute_report_ready`
- `~/DevSrc/Projects/db/platform/wiki/` — wiki-страницы, при наличии раздела про отчёты

## 11. Reference: пример из debt-master

Самый полный production-пример — `debt_notification`:

- Definition: `backend/db/sql/configuration/debt/report/init.sql:29`
  (через `InitReport(null, GetType('report.report'), uNode_debt, 'debt_notification', ...)`)
- `rfc_debt_notification` (form): `backend/db/sql/configuration/debt/entity/object/document/debt/training/report.sql:89`
- `rpc_debt_notification` (main): `report.sql:176` — генерация HTML + опциональный вызов rcb для docx
- `rcb_debt_notification` (callback to docx-service): `report.sql:19` — http.fetch с callback
- Callback handler: `backend/db/sql/configuration/debt/entity/object/document/debt/training/callback.sql:9`
  (`api.docx_service_callback`)
- Download handlers: `callback.sql:64` / `:105` (`api.docx_service_download_done/_fail`)

Просмотр в этом порядке даёт полное понимание pipeline на реальном production-коде.
