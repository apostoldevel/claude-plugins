<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 14 — Decision Rules

When solving a problem or implementing a feature, ask in this order:

1. **Does the platform already provide this?**
   - Auth/OAuth2/JWT → AuthServer + `admin`/`oauth2`
   - REST API → AppServer + `daemon`/`rest`/`api`
   - Real-time events → WebSocketAPI + `observer`
   - Background jobs → TaskScheduler + `api.job` + `scheduler` module
   - Email/push/SMS → MessageServer + `notice`/`message`
   - Files → FileServer + PGFile + `file` (S3-backed)
   - External HTTP from DB → PGFetch + `http`
   - Custom HTTP routes (webhooks) → PGHTTP + `http`
   - State machine → platform `workflow`
   - Access control → ACU/AMU/AOU + Access views
   - Localization → `locale` module + `db.<entity>_text` tables
   - Reports → ReportServer + `report` module
   - Audit log → `WriteToEventLog(...)` + `db.log`
   - Pub/sub → observer + 7 publishers + LISTEN/NOTIFY
   - Delivery to one consumer at a time (at least once), with a lease and repeats → the `notify` module (1.2.37+, `processes.md`)

2. **Am I editing the right layer?**
   - Business logic → `configuration/<dbname>/` (this project)
   - Project-specific C++ process → `backend/src/processes/<Name>/` (this project)
   - Anything in `db/sql/platform/` → STOP. Use `/apostol` skill for framework work.
   - Anything in `src/lib/libapostol/` or upstream module sources → STOP.

3. **Does INDEX.md describe what I need?**
   - Always check the project's DB-layer INDEX.md (`backend/db/INDEX.md` or a top-level `db/INDEX.md` — [`reading.md`](reading.md), Tier 0) and `configuration/<dbname>/INDEX.md` before exploring code.

4. **Has someone already solved this in another configuration project?**
   - Look at the most mature configuration you can read first. If there's a similar entity (a client, a device, a payment…), copy its structure — as an example, not as a rule: a rule comes from the platform or from PostgreSQL, and a decision recorded in one project binds that project only.

5. **Will my approach pass the Hall of Shame?**
   - Run through [`anti-patterns.md`](anti-patterns.md). If your code matches a ❌ row, change the approach.

6. **Is there a companion skill that automates this?**
   - Creating a new entity (Document or Reference) → invoke **`/new-db-entity`** for the full 7-file scaffold wired into create.psql/update.psql.
   - Generating `INDEX.md` for an entity / module → invoke **`/index`** for the platform-standard format.
   - Code review or audit of an Apostol project → invoke **`/apostol-review`** (security, dead code, duplication with libapostol, hard-coded values).
   - Row-level access (`Access<Entity>` / `api.sql()`) behaving oddly, or the project still on the old static AOU model → invoke **`/apostol-new-aou`** (migration to the dynamic mechanism, drop patch, verification protocol, pre-deployment data audit).
   - Working on the framework itself (libapostol, db-platform, shared modules) → STOP project work and invoke **`/apostol`** (framework-development skill, separate scope).

