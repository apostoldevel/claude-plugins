# Changelog

Dates are the author's working days. The skill has no version number; a pin is a commit of this repository.

## 2026-09-30 — first public release

- **Core halved (56 → ~31 KB).** Moved verbatim into references:
  - the Hall of Shame → `anti-patterns.md`;
  - Steps 1 and 3 → `reading.md`;
  - Step 13 and the README rule → `conventions.md`.

  Every moved step keeps its number and a heading in `SKILL.md` that points to the new place.
- **Read by role** now covers nine roles instead of four. Every role reads the same core:
  - design vs implementation;
  - the three layers;
  - naming;
  - a ten-line **Must-know**;
  - Steps 4 and 15.
- **Facts re-measured on db-platform 1.2.31:**
  - 28 modules (`gateway` added);
  - 41 `rest.*` dispatchers with ~450 routes;
  - the wiki lags, not the code;
  - project pins range from 1.1.4a to 1.2.31;
  - v1 and v2 use different layouts;
  - who refreshes the token: AppServer on `/api/v1`, GatewayAPI on `/api/v2`, a standalone SPA itself;
  - upstream has fixed the planner issue since 1.2.20.
- **Added from agents' ratings:**
  - access: `chmodc(objectSet)`, `CheckClassAccess`, the derived `mask`;
  - platform `Do*` hooks see only an id;
  - triggers on platform tables go in a patch: `CREATE OR REPLACE TRIGGER`, `lock_timeout`, alphabetical order;
  - signature changes and `DEFAULT` → "function … is not unique";
  - the `module.<Name>.enable` key;
  - the PGFetch callback contract;
  - `http.create_request` in `state 1`, and `http.take`;
  - ordering and resend in PgPool;
  - `install.psql` runs as `admin`;
  - `git archive` leaves out untracked files;
  - signing out via `POST /oauth2/revoke`;
  - seven new verification techniques in Step 15.

## 2026-09-28 — core and references

- Steps 5–12, 16 and 17 moved verbatim into references. `SKILL.md` became the core read at session start.
- Both teams now rate the skill after each task.
