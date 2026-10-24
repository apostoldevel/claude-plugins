<!-- Reference of the /apostol-project skill: every role reads it before claiming done (Step 15 in SKILL.md keeps a digest). -->
## Step 15 — Verification Before Completion (full text)

Collected 2026-08-24 from a day where **every finding came from a technique, not from knowing the
architecture**, and extended from the agents' ratings since. This file is deliberately about *checking*, because the
rest of this skill is about writing.

### 1. Both directions, and checks that are green for the wrong reason

**Run both directions, always.** A check exercised only against a healthy input is not a check — it
only shows that it does not crash. It must pass, and it must **fail** on a deliberately broken
input. Three ways this bites in one day: a grep over a bundle that reported "fixed" for both
builds; an acceptance criterion that missed bare text because it looked for quotes; four convention
tests that were green because they iterated over zero rows.

**A test that skips is not exempt** — prove it bites before you trust the skip.

**Checks that are green for the wrong reason:** an aggregate over zero rows; `bool_and` / `bool_or` skipping NULL (wrap in
`coalesce(…, false)`); a text match on a jsonb string without `#>> '{}'` (the text starts with a quote); a row inserted by
a function called in the same statement, which that statement's snapshot cannot see (§ 5).

**Mutate the guard, not only the input.** Break the code under test — drop the check, add an early `RETURN`, swap two
arguments, remove the lock — and count the red tests. In SQL a mutant is built inside a transaction from
`pg_get_functiondef` + `regexp_replace` and rolled back. If a mutant dies only on another test's tag, your test does not
pin it: make the rest of the input valid, so the mutant dies on its own tag. Run a mutant across the whole suite before
you name who kills it. A shared component's guarantee is pinned by its own test, not by a consumer's. Argue an
equivalent mutant instead of chasing it. For a sanitiser, fuzz against an oracle on the *shape* of the output, not on
"it did not crash".

**A check that something did NOT happen needs proof that the branch ran** — a counter on the branch, a printed canary, the
allowed role passing the same request. Two mutants: "branch broken" and "branch not reached" must both go red. Give the
setup a positive control too: the same run with correct input passes.

- **"Nothing was created" needs proof that the event reached the branch.** With an asynchronous answer an empty table
  proves nothing: `http.fetch` returns at once, the far end's answer comes later via PGFetch — a callback and an event,
  not the REST response.
- **After an exception, look after the next step.** A call that throws rolls back its own work; claim "no side effects"
  after the following step, not right after the refusal.

**A change meant to touch exactly N rows of a shared mechanism is tested from both sides**: the N changed, and their
neighbours unchanged — a mutant "barred three more accounts" survives a test that looks only at the three. An invariant
of the change itself ("the patch does not touch passwords") is proven inside the change — a fingerprint before and after
under `REPEATABLE READ` — not by a test of the result.

**Test a rule in its own words.** "Refuse an unknown type" is tested with a type that does not exist today (create it in
the test's transaction), not with today's single case.

### 2. What a refusal proves

**Look at the identifier of the refusal, then prove which guard gave it.** `ERR-400-001` versus `ERR-400-032` separated an
access barrier from a workflow rule; taking "it refused" at face value nearly produced a wrong policy. But one identifier
is a family, not a guard: `ERR-400-001/-002/-003` are all category `access` (`platform/error/init.sql:144–160`, 1.2.35)
and are raised by the object write trigger, by project gates and by the method right — which one answers can depend on
the object. Name the guard only after an A/B with the guard removed. Assert "refused **and** state unchanged", and that
the allowed role passes the same request.

- **`ERR-400-091` (route not found, `error/init.sql:736`) comes from a typo and from a removed branch alike.** A test that a
  route is closed needs a positive control: a live neighbouring route of the same dispatcher answers on the same request.
- **A status code alone is not an answer.** A module can return HTTP 200 with an error in the body; check the body and
  which module answered (`X-Request-Id`, headers).
- **A refusal that must not need the database — test it on a dead database port.** If it still refuses, it refused
  before the database.
- **Error texts are localized.** `RegisterError` keeps a message per locale and returns the session's
  (`platform/error/routine.sql:189`, `:143`); the wording of `PG_EXCEPTION_CONTEXT` follows `lc_messages`. Check the
  error code and the invariant part (the quoted key), never an English phrase.
- **Compare the state code, not the state type.** `IsEnabled` is true for every state of type `enabled`
  (`in_progress`, `failed`, …) — "enabled" is not "in work".

### 3. Paths, roads and doors

**Look at what stands BEFORE the check, not at what the check verifies.** A CSRF gate on an OAuth
callback was correct and complete — and the error branch returned earlier, so it was never reached.
Reviewing "does the gate work" would never have found it.

**Count the paths yourself.** An author wrote "both branches"; there were three. "Both" over three
paths is the ordinary place where one stays forgotten.

**Closing one input closes only that input.** Before "done", list every field of the route, not just the one in the task,
and every road to the same effect: sibling dispatchers, the generic object routes (`access-control.md` § Every door to an
object), `/api/v2` (GatewayAPI reaches the same `api.*`), PGHTTP, other protocols. A guard in `rest.<x>` covers `/api/v1`
only; put it in `api.*` or deeper unless internal callers need the value — then name the roads left open.

**An outcome that arrives by two roads** (a webhook, and the answer to your own call) **is tested in every order of
arrival.** A regression hid in "the answer came before the webhook", not in either road's logic.

**Measure the path the client really takes.** A browser app runs on cookies (`__Secure-AT/RT`); a Bearer measurement takes
another branch (sign-out, for one, answers differently on each). Rights are measured under the role the request really
uses (`access-control.md` § Probing rights honestly).

### 4. Data, fixtures and bases

**A test that picks "the first suitable row" tests the data, not the code.** `ORDER BY id LIMIT 1` is green on one base and
red on another, may pick a row that trips a neighbouring guard, and a dev base reaches rows through grants a fresh tenant
lacks. Make fixtures explicit, real and isolated: build them through the real creation paths (sign-up, registration), not
as hand-made rows; give a fixture the hole could spoil its own user or file; name the base the test ran on. On old code
read the **first** red — the rest may be a cascade.

**Gate on a throwaway fresh install, not on a dev base.** A dev base lags the repository — missing patches turn a
before/after into zeros, and the load order decides which copy of a function wins (`facts-2026-09.md` § Extension
mechanism). Load each changed file **whole** with `psql -v ON_ERROR_STOP=1`, with a positive control (a broken copy must
fail); per-function loading does not see a lost `/**`. A change to `init.sql` / `FillDataBase` / `table.sql` gets
`--install` on a throwaway base; a patch runs on a copy of an existing base, built from the **previous release tag** with
data in it — an empty base proves nothing. The two roads differ (`db-architecture.md`).

**Before/after by two pins.** Two fresh installs (pin before, pin after) on named volumes, one script on both, each attempt
in a rolled-back transaction, a matrix actor × action × object. "0 differences" proves something only if the matrix has
cells where the filter cuts rows; for an access boundary add a deliberately leaky variant that must show extra rows.

**After narrowing a selection by access, re-measure on volume** — against an existing list of similar size, not against
"as before". A fix that closed a hole on a small base made an admin list 300× slower on 40k rows.

**Probe hypotheses inside a transaction with `ROLLBACK`**, and verify the counters afterwards — on
a shared stand someone else is working next to you. Count a side effect **scoped to your own rows**, or inside your own
rolled-back sub-transaction: a whole-base count picks up other commits, and a whole-base invariant fails after another
suite leaves rows behind. "Refused before X" is proven by a counter of X, not by the HTTP answer after the refusal.

### 5. Transactions, snapshots and time

**A `STABLE` function sees the snapshot of the statement that calls it.** `GetX(NewX(…))`, `GetProvider('x')` next to
`AddProvider('x')` in one `SELECT`, or a STABLE getter in a `WHERE` does not see a row created by the same statement — it
returns NULL, or raises if the getter raises on a miss (`GetGroup`). Split the work into two statements — the order of calls in a select list is not guaranteed either, whatever the
volatility. It works on an existing base, where the row is already there, and fails in the installation script.

**Inside one transaction `now()` is constant.** Writing a timestamp again writes the same value, so "unchanged" proves
nothing — age the field first. All state changes of one transaction share one `Now()` (`workflow.md`).

**A check→write race needs two sessions**: A holds the row until `COMMIT` while B calls. Use a no-lock mutant as the
control; a test inside one transaction cannot show the race.

**PL/pgSQL resolves names when a statement first runs**, not at `CREATE` — a call is proven by running it
(`install-pitfalls.md` § R).

### 6. Builds, environments and long runs

**Build what you accept, from the pins** — not from a shared working tree: `git archive <sha>` of the tree plus
`git archive <pin>` of each submodule. Untracked files (per-environment bundles) stay out — add them by hand.

**When credentials are missing, build a stub instead of waiting.** A cookie-clearing branch that
"needs a real token exchange" turned out to be reachable through a third code path that touches
neither the database nor the provider.

**In A/B measurement, alternate the order.** The first run in a session is slower regardless of
mode; a "6% win" turned out to be warm-up handed to whichever mode went first.

**Wait for the process, not the wrapper.** End a long background run with a line `rc=$?` in its output file and wait for
that line (`until grep -q '^rc=' f`) — not for a wrapper's "done", not for `pgrep -f` with a pattern that matches your own
command line. Capture `rc` into a variable at once: `echo "$(cmd) rc=$?"` reports the substitution's code.

### 7. Searching, and secrets

**An empty search proves nothing until a control hits.** `git grep` does not enter submodules without
`--recurse-submodules` — and `sql/platform` and the C++ modules are submodules; tools that honour ignore files skip what
you need; an empty pattern (`grep -F "$v"` with `v=""`) matches everything; `wc -l` of an empty string is 1. Run each
pattern on a synthetic positive first, and say which perimeter you searched (tracked files are not the untracked `.env`).
Callers of a SQL function are listed from `pg_proc.prosrc` on a base installed at the pin — it holds what really loaded,
overrides included — and the tree is searched by explicit paths.

**Never print a secret to find it.** On a shared base or tree print setting and env **names** (`cut -d= -f1`), never
values — a `PASSWORD|SECRET` filter misses a password inside a DSN. Classify hits by `file:line`, length and character
class. A value passed in argv is visible in `/proc/<pid>/cmdline`. A search by key shape misses `password = login` and
`process.env.X || '<default>'`: search by shape *and* by value, without printing the value. psql prints what `SELECT`
returns, secrets included (`install-pitfalls.md` § F).

### 8. Documents, reports and reviews

**Compare the comment with the code.** "The check is unconditional" over a conditional check;
`tests/README.md` that spent three days discouraging a working path because of a defect that had
been retracted. A document promising a guarantee that does not exist is worse than no document.

**A document with SQL (a runbook, a README, a task note) is code.** Check every field and function against
`table.sql` / `view.sql` and run each query on a throwaway base — one audit found 28 of 66 runbook queries wrong. A console
query needs a platform session (as `kernel`: `SessionIn(…)`); without one, views filtered by the session return nothing
and raise nothing.

**A subagent's report is a claim.** Recount its numbers from its own table; re-run its measurement on a broken input; check
an audit's "wrong" against the code before you edit. Changes made after a review go to a second pass — a result the
reviewer did not see is not reviewed. Brief a reviewer with "what else reaches the same state", not only "is the diff
right".

**Who started it is read from the object, not from the clock.** A coincidence in time is not a cause: read the object's
`owner` and `oper` (`entity/object/table.sql:16`) and its state history before naming who acted.

**"Not read" is not "not said".** When a page-reading tool does not return an anchored section of a large reference
(`#some_call`), record that the section was not read — never that the documentation is silent.

**Citations a subagent wrote are checked by a script against the pins** (`component:path:line` resolves at its commit) —
line numbers shift after `cat -n` of several files.

**"Could not reproduce" is part of a finding, not its absence.** It narrows the risk and names the
boundary; "did not check" leaves a hole later mistaken for a check.

### 9. The meta-lesson

**Written knowledge does not protect you from a trap.** An agent stepped into
two traps he had personally documented an hour earlier. What worked was **a precondition check
inside the tool** — "did the stub actually come up?", "is this the binary I just built?". Put the
guard in the instrument, not in the reader.

SQL layer — the `psql` / `curl` checks after install, a new entity and a workflow change: [`conventions.md`](conventions.md),
§ Verification commands; testing code that calls out (PGFetch): `conventions.md` § Testing code that calls out.
