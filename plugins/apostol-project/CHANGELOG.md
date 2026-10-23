# Changelog

Versions follow [semver](https://semver.org); the current one is in `.claude-plugin/plugin.json`. Dates are the
author's working days.

## 1.1.0 — 2026-10-23

From the agents' ratings of 03–23.10.2026 (about 120 entries; what holds on every project only).

- **Step 15 moved to `verification.md`**, with a one-line digest of each technique left in the core (31.1 → 29.5 KB).
  The earlier techniques are kept, two of them corrected (below). New ones: mutate the guard; a negative check needs proof that its branch ran;
  checks that are green for the wrong reason; fixtures that are explicit and isolated; gating on a throwaway fresh install
  and on two pins; re-measuring on volume; two roads of arrival; waiting for `rc=`; an empty search needs a control; never
  printing a secret; runbooks and subagent reports are claims.
- **Public text only.** Removed from the old text as well: card numbers, internal decision records, private repository
  paths and the names of one team's projects and agents. The wikis are referenced by their public GitHub addresses; "the
  reference project" is now "the most mature configuration you can read".
- **Corrections:**
  - the refusal's identifier names a family, not a guard;
  - a `STABLE` function sees its caller's snapshot — a cause, besides the select-list order, behind "two dependent calls in one `SELECT`";
  - the session context and what clears it now (PgPool `postgres.reset`, `ResetGatewayVars`, `ROLLBACK`);
  - "level 3 never modifies level 2": configurations do override platform functions, so check both copies;
  - the Go / `/api/v2` row: access also lives in the `rest.*` route, and `/api/v2` skips it.
- **Access:** the create bit `c` guards nothing (`CheckClassAccess` has no caller); the object write trigger is the last
  barrier, and `kernel` skips it; `IsSystem()` holds for every `client_credentials` session; probing rights honestly;
  every door to an object; the `/api/v2` identity in `gateway.request`; restoring a temporary grant.
- **Workflow and DB:** a state gate plus an action needs a row lock; `DoTryAction` swallows errors; one `Now()` per
  transaction; `DeleteMethod` also removes transitions and AMU (through a trigger); patch names collide silently; a guard
  in the function or in a trigger; where a document is born; a generic reference has no state; derived grants are a cache.
- **Anti-patterns, pitfalls, processes:** `array_length` loop bounds; seeded passwords; `WHEN OTHERS` and secrets;
  PL/pgSQL resolves names at run time; psql prints secrets; a base restored from a dump; the server `search_path`;
  "Login is not possible"; `PgPool::execute()` can throw; `postgres.log` is always at debug; the `fetch.*` filter;
  PGHTTP keeps the sender's spelling of header names; observer cost; measuring callers before narrowing a route; testing
  code that calls out; the client mirrors the server's decision.

## 1.0.0 — 2026-09-30

- **Packaged as a plugin** of the `apostoldevel` marketplace. The repository `apostoldevel/skill-apostol-project` is
  now `apostoldevel/claude-plugins`, and the skill lives in `plugins/apostol-project/skills/apostol-project/`. Its
  text has not changed since the first release below.
- Install: `/plugin marketplace add apostoldevel/claude-plugins`, then
  `/plugin install apostol-project@apostoldevel`. A clone of the old repository root into
  `~/.claude/skills/apostol-project` no longer works as a skill directory: link
  `plugins/apostol-project/skills/apostol-project` instead.

## 2026-09-30 — first public release (commit `c28294f`)

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
