# db-platform Report Subsystem — Reference

> Companion document for `SKILL.md` (skill `/apostol-project`).
>
> Full reference for the db-platform report subsystem: report types, ready
> reports, workflow, async microservice integration, ReportServer, the
> `rpc_*` + `rcb_*` + callback pattern.
>
> **When to read:** before creating a new report, changing an existing one,
> integrating an async file-generation microservice (DOCX/PDF/Excel),
> or working out where `Reports UI` and "Report history" come from.

---

## 1. Two-level report model

The platform distinguishes **two entities with different semantics**, and mixing
them up is the main source of errors:

| Level | Entity | Purpose |
|---|---|---|
| **Definition** | `db.report` (reference) | Static "catalog" of reports: what exists, where it sits in the UI, which parameter form, which procedure runs |
| **Ready** | `db.report_ready` (document) | Dynamic run instance: the concrete parameters from the form, execution state, the resulting file |

One definition -> many ready (one per each run by a user).

### 1.1 Definition (static)

Created **once** in `init.sql` through `InitReport()` / `InitObjectReport()`
/ `CreateReport()`. This is a REFERENCE entity (entity = `report`, parent = `reference`).

```
db.report
├── id         uuid
├── reference  uuid  → db.reference (inheritance)
├── tree       uuid  → ReportTree (node in the UI tree)
├── form       uuid  → ReportForm  (form parameters)
├── binding    uuid  → class_tree   (NULL for global, class for object-scoped)
└── info       jsonb
```

**Definition types** (`db.type` on the `report` class):

| Type code | Use | Where visible in the UI |
|---|---|---|
| `report.report` | Standard report in the tree | Reports UI tree, parameter form |
| `object.report` | Report bound to an object class (through `binding`) | In the card of an object of that class (as a context button) |
| `import.report` | Import report | Reports UI tree, special handling with upload |

### 1.2 Ready (dynamic)

Created by **every run** through `BuildReport()` → `CreateReportReady()`.
This is a DOCUMENT entity (entity = `report_ready`, parent = `document`).

```
db.report_ready
├── id        uuid       → db.document (inheritance)
├── document  uuid
├── report    uuid       → source definition
└── form      jsonb      → snapshot of the run parameters
```

**Ready types** (`db.type` on the `report_ready` class):

| Type code | UX effect |
|---|---|
| **`sync.report_ready`** (default in `BuildReport`) | The user waits for the result right on the form (loading + polling, the backend generates → completes → the form shows it) |
| **`async.report_ready`** | The user immediately sees "generating", goes to "Report history", and polling moves there |

**KEY POINT:** the report_ready workflow (state machine: `created → progress →
completed/failed/canceled/deleted`) is **identical** for both types. There is no
difference at the DB level — it is a semantic label for the frontend UX, nothing more.

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

Created in state `created`. To run it, perform the `execute` action →
transition to `progress` → `EventReportReadyExecute()` fires →
`ExecuteReportReady(pReady)` is called.

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

Finds all `report_routine` rows bound to the definition (usually one — `rpc_<code>`)
and executes each with the parameters `(pReady, pForm)`. They produce the result.

### 2.2 Action mapping

| Action | Triggered by | Effect |
|---|---|---|
| `create` | `CreateReportReady()` | INSERT row, state=created |
| `execute` | `BuildReport()` or an explicit `api.execute_report_ready()` | → progress + `rpc_*` launch |
| `complete` | `DoAction(pReady, 'complete')` from `rpc_*` or the callback chain | → completed |
| `fail` | `DoAction(pReady, 'fail')` on exception | → failed |
| `cancel` | The user cancelled | → canceled |
| `delete` / `restore` / `drop` | Standard lifecycle | — |

---

## 3. Creating a report — three entry points

### 3.1 `InitReport()` — report in the tree (standard)

```sql
-- platform/report/routine.sql:147
InitReport(pParent, pType, pTree, pCode, pName, pDescription) RETURNS uuid
```

Creates a **triple**: form + report definition + routine.

- Form: `CreateReportForm()` with `code = 'rfc_' || pCode` (the frontend expects a function `report.rfc_<code>(pForm uuid, pParams jsonb)`)
- Definition: `CreateReport(pType, pTree, uForm, ...)` with the passed `pType`
- Routine: `CreateReportRoutine()` with `code = 'rpc_' || pCode` (must exist as `report.rpc_<code>(pReady uuid, pForm jsonb)`)

Use: the report is visible in the Reports UI tree as a separate entry.

**Example:**
```sql
PERFORM InitReport(null, GetType('report.report'), uNode_docs,
                   'invoice_notice',
                   'Payment reminder',
                   'Generation of payment reminders.');
-- => creates rfc_invoice_notice + rpc_invoice_notice (must be implemented)
```

### 3.2 `InitObjectReport()` — context report on a class

```sql
-- platform/report/routine.sql:187
InitObjectReport(pParent, pTree, pForm, pBinding, pCode, pName, pDescription) RETURNS uuid
```

Creates a definition with a **fixed** `type=GetType('object.report')` and
`binding=<class_uuid>`. The form is passed **from outside** (`pForm`) — usually
shared by all object reports (`rfc_identifier_form`). The routine is created
automatically with `code = 'rpc_' || pCode`.

Use: the report is visible **from the card of an object** of this class (context button).

**Example:**
```sql
uForm := CreateReportForm(null, GetType('json.report_form'),
                          'rfc_identifier_form', 'Object identifier form',
                          'rfc_identifier_form', '...');

PERFORM InitObjectReport(null, uRoot, uForm, GetClass('item'),
                         'object_statement',
                         'Statement for an object', null);
-- => rpc_object_statement must be implemented, the rfc_identifier_form form is shared
```

### 3.3 `CreateReport()` — low-level

```sql
-- platform/report/routine.sql:20
CreateReport(pParent, pType, pTree, pForm, pBinding, pCode, pName, pDescription, pInfo) RETURNS uuid
```

Direct creation of a definition without auto-generating the form and routine. Use it
when the form and routine are created separately or reused.

---

## 4. Running a report — two UX variants

### 4.1 `BuildReport()` — the main entry point for a run

```sql
-- platform/report/routine.sql:224
BuildReport(pReport, pType DEFAULT NULL, pForm DEFAULT NULL,
            pName DEFAULT NULL, pDescription DEFAULT NULL) RETURNS uuid
  → pType := coalesce(pType, GetType('sync.report_ready'))
  → RETURN CreateReportReady(pReport, pType, pReport, pForm, ...)
```

`pType` determines the UX mode:
- **NULL / `sync.report_ready`** (default) — the user waits for the result on the form
- **`async.report_ready`** — the user goes to "Report history"

### 4.2 Through REST `/report/build`

The standard Reports UI flow. The frontend picks an entry in the tree, fills in the
form, presses "Continue" → `POST /report/build {report_id, form}` →
the backend calls `BuildReport(uReport, NULL, jForm)` → default sync.

### 4.3 Through an entity-specific REST endpoint (context button)

When async mode and pre-filled parameters are needed:

```sql
-- In rest.item:
WHEN '/item/object_statement/generate' THEN
  uReport := GetReport('object_statement');  -- existing object.report definition
  uReady  := BuildReport(
    uReport,
    GetType('async.report_ready'),                  -- ← async
    jsonb_build_object('invoice_id', r.id)             -- pre-filled form
  );
  RETURN NEXT row_to_json(t) FROM (SELECT uReady AS report_ready_id, 'progress' AS status) t;
```

The frontend receives `report_ready_id` and does not poll — the user sees the
result later in "Report history".

---

## 5. Pattern `rpc_*` (mandatory) + `rcb_*` (optional for async)

### 5.1 `rpc_<code>(pReady, pForm)` — mandatory

Signature: `(pReady uuid, pForm jsonb DEFAULT NULL) RETURNS void`.

Called through `ExecuteReportReady` after the `execute` action. Implements **the whole
report generation**:

```sql
CREATE OR REPLACE FUNCTION report.rpc_invoice_notice(
  pReady  uuid,
  pForm   jsonb default null
) RETURNS void AS $$
DECLARE
  vHTML      text;
  html_file  bytea;
  items      jsonb;
BEGIN
  -- 1. Extract the parameters from the form
  -- 2. Query the data from the DB
  -- 3. Build the HTML content
  vHTML := '...';
  html_file := convert_to(vHTML, 'UTF8');

  -- 4. Save the HTML to a file (always — for preview/viewing)
  PERFORM SetObjectFile(pReady, null, 'index.html', null,
    length(html_file), localtimestamp, html_file,
    encode(digest(html_file, 'md5'), 'hex'),
    'Payment reminder', 'data:text/html;base64,');

  -- 5. If an async docx through a microservice is needed — call rcb_*
  IF items IS NOT NULL THEN
    PERFORM report.rcb_invoice_notice(pReady,
      jsonb_build_object('meta', meta, 'items', items));
    -- DoAction(complete) is NOT called — the callback flow does that
  ELSE
    -- Otherwise complete immediately (HTML only, no docx)
    PERFORM DoAction(pReady, 'complete');
  END IF;

EXCEPTION WHEN others THEN
  -- error → SetObjectFile with error.html + DoAction(fail)
  PERFORM DoAction(pReady, 'fail');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, public, pg_temp;
```

### 5.2 `rcb_<code>(pObject, pPayload, pMetadata)` — optional

Signature: `(pObject uuid, pPayload jsonb, pMetadata jsonb DEFAULT NULL) RETURNS void`.

Called from `rpc_*` when async file generation by an external microservice is needed
(docx-service, docx-generator, custom). This is a "callback" in the sense of "delegating
the work over HTTP with a callback back".

```sql
CREATE OR REPLACE FUNCTION report.rcb_invoice_notice(
  pObject       uuid,         -- = pReady from rpc_*
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
  -- error → SetObjectFile with error.html + DoAction(fail)
  PERFORM DoAction(pObject, 'fail');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = kernel, public, pg_temp;
```

`rcb_*` **only starts** http.fetch and returns control. The real
completion of the workflow (`DoAction(complete)`) happens **after** the
async microservice sends its callback and the file is downloaded by PGFile.

### 5.3 When `rcb_*` is needed

- ✅ docx/pdf generation in an external service is needed (async, with callback)
- ✅ PDF conversion is needed (LibreOffice headless)
- ✅ External calculation/processing is needed
- ❌ Not needed for pure-SQL reports (HTML generation in `rpc_*` → `DoAction(complete)` immediately)

---

## 6. Full async generation pipeline (DOCX through a microservice)

```
Frontend                Backend (PL/pgSQL)              Microservice
─────────                ──────────────────              ────────────

POST /report/build  ───▶ rest.report dispatcher
                         BuildReport(uReport,
                           pType=sync.report_ready,    -- or async
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
                         │   1. Extract pForm parameters
                         │   2. Query data from the DB
                         │   3. Build the payload
                         │   4. SetObjectFile(pReady, 'index.html', html)
                         │   5. rcb_<code>(pReady, payload)
                         │      │
                         │      └── http.fetch(
                         │            <service>/generate
                         │            ?callback=<backend>/.../<pReady>,
                         │            POST, headers, payload)
                         │          → NOTIFY 'http'
                         │
              (control returned)
                                                        PGFetch (C++ helper)
                                                        picks up 'http' notify
                                                        POST <service>/generate ─▶ microservice
                                                                                   accepts the task
                                                                                   returns 200 OK
                                                                                   (or 202 queued)
                                                        ← 2xx
                                                        → api.<service>_done(uFetch)
                                                          (does not finish the workflow,
                                                           only marks that the fetch went out)

(the user waits... 3-30s)                               The microservice generates the file

                         POST callback ◀───────────────  POST <backend>/api/v1/callback/<service>/<pReady>
                         (PGHTTP accepts)                body: {status, result: {file_name, download_url}, ...}
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
                         │       mime='text/x-uri',  -- ← URL, not bytes
                         │       'api.<service>_download_done',
                         │       'api.<service>_download_fail')
                         │     -- NOTIFY 'file' is sent by a trigger
                         │
                                                        PGFile (C++ helper)
                                                        picks up 'file' notify
                                                        sees mime='text/x-uri'
                                                        GET <service>/download_url ─▶ microservice
                                                                                       streams file
                                                        ← file bytes
                                                        saves into db.file
                                                        + /file/public/report_ready/<pReady>/<file_name>

                         api.<service>_download_done(pReady)
                         → DoAction(pReady, 'complete')
                         → state=completed
                         → EventReportReadyComplete records it in the log

Frontend polling /report/ready/get
sees state=completed
gets the link to /file/public/report_ready/<pReady>/<file_name>
shows it to the user
```

### 6.1 Key points

1. **`SetObjectFile` with `mime='text/x-uri'`** — a special marker for PGFile:
   - The `data` field contains a **URL** (not the file bytes)
   - PGFile makes a GET to this URL and saves the response as the file
   - This is the "download_url proxy" pattern

2. **Three callbacks on the backend side:**
   - `api.<service>_done/_fail` — for http.fetch (from PGFetch): whether the request reached the microservice
   - `api.<service>_callback` — for the callback from the microservice (through PGHTTP): the generation result
   - `api.<service>_download_done/_fail` — for PGFile: whether the file was downloaded

3. **`DoAction(pReady, 'complete')` fires only after the download** — this guarantees that by the time of complete the file is already in `db.file`.

4. **If the callback does not arrive within a reasonable time** — the platform has no automatic timeout mechanism. The frontend can detect a "stuck progress" on its own.

---

## 7. A known variation: completing early

A lesson from one project about completing an async report:

> **Async report complete:** DoAction('complete') on report_ready fires
> immediately on 200/202 (i.e. PGFetch_done), not after callback — releases
> frontend spinner

This is a **subtlety of production optimization**: some projects call
`DoAction(pReady, 'complete')` already at the `api.<service>_done` stage (the 200/202
response from the microservice), so that the frontend is released at once. The file arrives
a bit later — visible through the `SetObjectFile` update. This is a **special case for UX** where
not blocking the user matters.

**Default pattern** (see §6) — complete after download.

---

## 8. Anti-patterns when working with reports

| ❌ Anti-pattern | ✅ Correct |
|---|---|
| `CreateReport(pType=>GetType('async.report'))` | There is no such type at the definition level. `async/sync` exists only at the report_ready level through `BuildReport(uReport, GetType('async.report_ready'), ...)` |
| A direct `http.fetch` to docx-service from `rpc_*`, bypassing `rcb_*` | Keep the `rpc_* → rcb_* → http.fetch` pipeline; the rcb function isolates the HTTP detail |
| `DoAction(pReady, 'complete')` in `rpc_*` right after `rcb_*` | Do not do this! Complete must come from the callback flow after the file is really ready |
| Hardcoded microservice URL in `rcb_*` | Through the registry: `RegGetValueString('CURRENT_CONFIG', 'CONFIG\Service\<service>\API', 'URL')` |
| Hardcoded callback path | Through the registry: `RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Backend') || '/api/v1/callback/<service>'` |
| Creating a `db.report` row by hand (INSERT) | Only through `CreateReport()` / `InitReport()` / `InitObjectReport()` — they invoke workflow events |
| `BuildReport` without `pForm` when `rpc_*` expects parameters | The frontend must pass pForm in `POST /report/build`; the backend proxies it to BuildReport |
| Relying on the sync/async type in `rpc_*` for different logic | rpc is the same for both. Sync/async is UX only. If different logic is needed — pass it through `pForm` |
| Forgetting the `r.code='execute'` event with `'ChangeObjectState();'` | This event is mandatory for the created→progress transition (for a custom workflow extension) |
| Creating a new `db.report_ready` by hand instead of `BuildReport` | Workflow events will not fire — the report will hang in `created`. Always through `BuildReport()` |

---

## 9. Reference: checklist "new report through an async microservice"

1. **Schema:** add columns (if needed) through a patch + DDL
2. **Builder:** `api.build_<code>_context(pSourceObject)` — assembles the payload for the microservice
3. **Routine:** `report.rpc_<code>(pReady, pForm)` — extracts params, calls the builder, SetObjectFile HTML preview, calls `rcb_<code>(pReady, payload)`
4. **Callback wrapper:** `report.rcb_<code>(pObject, pPayload, pMetadata)` — a wrapper through an abstraction layer (for example, `docx.generate()`) or a direct http.fetch
5. **Callback handler:** `api.<service>_callback(pObject, pPayload)` — handles success/failed/warnings, SetObjectFile with download_url
6. **Download handlers:** `api.<service>_download_done(pObject)` + `_download_fail(pObject)` — `DoAction(complete/fail)` after PGFile
7. **REST callback route:** register `/api/v1/callback/<service>` → `rest.callback` → `api.<service>_callback`
8. **Definition (init.sql):** `InitReport()` (for the tree) or `InitObjectReport()` (for the object card) — automatically creates rfc_/rpc_ stubs, which must be implemented (see steps 2-3)
9. **Registry:** `RegSetValueString` for the microservice URL + (optional) per-type routing
10. **Frontend:** for a context button — an entity-specific endpoint like `/<entity>/<report_code>/generate`, passing `BuildReport(..., GetType('async.report_ready'), ...)`. For the tree — the standard Reports UI flow with no frontend changes.
11. **Smoke:** test `api.build_*_context` → curl test the microservice → polling until complete → check that `/file/public/report_ready/<pReady>/<file_name>` is available

---

## 10. Reference: platform files for going deeper

- `backend/db/sql/platform/report/routine.sql` — `CreateReport`, `InitReport`, `InitObjectReport`, `BuildReport`
- `backend/db/sql/platform/report/ready/routine.sql` — `CreateReportReady`, `ExecuteReportReady`
- `backend/db/sql/platform/report/ready/init.sql` — workflow `report_ready` (states/methods/transitions/events)
- `backend/db/sql/platform/report/ready/event.sql` — all Event handlers (Create/Execute/Complete/Fail/Cancel/Abort/...)
- `backend/db/sql/platform/report/api.sql` — `api.report_*` REST wrappers
- `backend/db/sql/platform/report/ready/api.sql` — `api.report_ready_*` + `api.execute_report_ready`
- `github.com/apostoldevel/db-platform/wiki` — wiki pages, if there is a section on reports

## 11. Reference: how to read a production example

In your own configuration find a report that calls an external service, and read in this order: definition
(`report/init.sql`, `InitReport`) → `rfc_<code>` (form) → `rpc_<code>` (main) → `rcb_<code>` (callback to the service) →
the callback handler → the download handlers (`_download_done` / `_fail`). This order gives a full understanding of the pipeline.
