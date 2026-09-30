---
name: agent-team
description: Use when organising development as a named team of Claude Code agents — several long-lived foreground sessions with fixed roles (coordinator, one agent per language layer, QA, auditor), each with its own memory, coordinated over a git board instead of a chat, with a working day the owner opens and closes by command. Use when the owner wants to run development WITH agents rather than hand it over, when one agent's memory or STATE.md has bloated across a months-long project, when several agents working at once became unfollowable, when the owner is being sent from terminal to terminal to repeat a decision, when a weekly usage limit is being hit by long-lived or idle agents, or when setting this up in another project. Ships hook templates — a per-role write barrier with its acceptance test, a session briefing, a context guard, an output filter. Complements /agent-onboarding, which covers the documents rather than the people.
---

# /agent-team — development as a named team of agents

How to organise a project so several named agents work it like colleagues in an office: visible,
interruptible, each with a role, a memory and an accountable output. Not about writing code —
about who writes it, who assigns it, where the shared knowledge lives, what stops an agent from
writing where it must not, how a working day begins and ends, and how the owner's word reaches
an agent without the owner walking to its terminal.

After loading, announce: **"Agent team context loaded."**

Companion skill: `/agent-onboarding` covers the *documents* a project needs (CLAUDE.md, STATE.md,
INDEX.md tree). This one covers the *people*. A project usually wants both — do onboarding first
if `STATE.md` does not exist yet, because a team without a shared "where are we" re-derives it
four times over.

Everything below was bought on a live project (see `apostol.md`) between August and September 2026.
Where a rule has a price, the price is stated; a rule whose price you do not know is the one you
will weaken first.

**What to open next** — this file holds the rules; the detail is read when the task needs it:

| File | When |
|---|---|
| `day.md` | opening or closing a working day; the `DAY` file; readiness; the closing protocol |
| `hooks.md` | installing or changing the harness: barrier, briefing, context guard, output filter, `settings.json` per launch directory |
| `pitfalls.md` | before trusting a barrier, a validator, a hook or a number — each pitfall was found by testing |
| `apostol.md` | applying this to a project built on Apostol (libapostol + db-platform) |
| `templates/` | the hooks, their test, `settings.json` for a coordinator and a layer, a card, `PRIORITIES.md`, `DAY` |

---

## Part I — The choice that comes first

Two ways to put agents on a project, and they are not variations of one thing:

| | **Visible named team** | **Autonomous fleet** |
|---|---|---|
| Owner's role | works alongside; sees each agent, interrupts, corrects | writes the prompt, reads the result |
| Sessions | long-lived, foreground, one per role | background/headless, spawned per task |
| Coordination | a coordinator agent + a board in git | a queue and an orchestrator |
| Gate | the owner's presence; deliberate commits | PR review, CI |
| Fails when | the owner is absent | the work needs judgement the owner holds |

**Ask which one the owner wants before designing anything.** The tell: an owner who says "it
becomes a black box, I don't see what's happening, I'm a developer myself" is asking for the
visible team — and a superpowers-style autonomous pipeline with PR gates will be abandoned within
weeks. An owner who says "I want to check the results in the morning" is asking for the fleet.

This skill describes the **visible named team**. Everything below assumes agents run in the
foreground and the owner can stop any of them mid-sentence.

Do not bolt PR gates onto a visible team by reflex. Many owners develop directly on `master` with
deliberate commits: the review already happened, live, while they watched. Ask what the commit
policy is; do not assume.

**The owner holds the judgement; the team holds the work.** In a visible team the owner decides —
several times a day — and those decisions are the product of the day as much as the code is. A
team that asks the owner often is not failing; a team that *sends the owner around* to repeat one
decision in four terminals is (Rule 12).

---

## Part II — Twelve rules

### Rule 1 — Split roles by language and toolchain, not by repository or by "framework vs project"

The natural seam is the one a human team would use: a C++ developer, an SQL developer, a
front-end developer. Each owns their language **everywhere it appears** — in the project layer and
in the framework the project consumes.

Two tempting alternatives, both worse:

- **A separate "framework agent"** (one agent for all upstream code). It holds two languages at
  once, and it splits SQL knowledge in half: the project's SQL layer *extends* the platform's SQL
  and reads it daily, so two SQL agents end up messaging each other about the same code.
- **Framework work folded into whoever is free.** Then nobody accumulates the framework's scars,
  and every fix restarts from zero.

Mode is per task, not per agent: the language owner loads the framework skill when patching the
framework, and the project skill otherwise — **never both in one session**; switching means a new
session.

A coordinator role is separate and writes no code. It is the owner's single point of contact:
slices tasks, keeps the board, hands work out, accepts results, **records the owner's decisions**
(Rule 12).

A component with no obvious language twin (an OCPP server, an AI side-service) goes to the
nearest language owner until its load is constant; then it gets an agent of its own (Rule 8).

Two roles that are not languages earn their place on a long project:

- **QA** owns the cross-layer test harness and **tests every layer, fixes none**. A red test is
  evidence for a card to the layer's owner, not a fix.
- **Auditor** checks the premise under the code: requirement → `file:line` → the test that proves
  it → deviation. It re-runs installers and test sets on throwaway databases and uses the product
  with a stranger's eye. **It fixes nothing** — every layer is closed to it by the barrier, and a
  finding is a card to the layer's owner, marked with its source.

**A role is promoted from a real, repeated load — not invented from the roster.** QA appeared when
the test harness outgrew the SQL agent's slot; a Go role when a Go part of the architecture had no
owner.

### Rule 2 — The launch directory is the agent's identity

Two mechanisms, both keyed to where the session starts:

- **Memory store.** Per-project memory lives in `~/.claude/projects/<slug-of-cwd>/memory/`. Start
  an agent in `<project>/backend` and it gets its own store, separate from the one in
  `<project>/`. This is the whole mechanism behind per-agent memory — nothing else to configure.
- **Hooks and settings.** `.claude/settings.json` is read from the launch directory's repository
  and does **not** cross a repository boundary: an agent started in `<project>/db` never sees
  `<project>/.claude/settings.json`. So **every launch directory registers its hooks in its own
  `settings.json`** — including launch points inside the umbrella repo (`tests/`, `audit/`), which
  otherwise run without a barrier. The hook *scripts* are not copied: the shared ones (briefing,
  context guard, output filter) live once, with the coordinator, and a layer's `settings.json`
  finds them by walking **up** the directory tree. A layer keeps its own copy of the barrier only
  (`hooks.md`).

So the launch table *is* the design:

| Agent | Starts from | Gets |
|---|---|---|
| coordinator | `<project>/` | project store, project `.claude/` |
| backend | `<project>/backend/` | backend store, backend `.claude/` |
| db | `<project>/db/` | db store, db `.claude/` |
| frontend | `<project>/frontend/` | frontend store, frontend `.claude/` |
| qa | `<project>/tests/` | tests store, its own `settings.json` in the umbrella repo |
| auditor | `<project>/audit/` | audit store, its own `settings.json` in the umbrella repo |

Names are given at session start and are how `SendMessage` addresses them; `ListAgents` shows who
is up. If an existing store must be inherited by an agent whose directory differs, symlink the new
slug's `memory` to the old store rather than copying.

**The identity is delivered, not remembered.** A `SessionStart` hook decides the layer **from the
launch directory** (a `case` on the realpath), and prints in one screen: who you are, what is
yours, what is *not* yours, the reading order, and which working day is open (Rule 11). The same
text is printed by `PostCompact`. Measured reason: a briefing that printed the same text to
everyone gave `grep <agent-name>` zero hits — after `/clear` the agent had the day and the reading
order but *not its own boundaries*, and "recoverable by reading the charter" is not "delivered".
Two roles launched from one directory are told apart by a variable set at launch
(`<TEAM>_AGENT=<name>`) or by the session name, the first line of `ListAgents`. Template:
`templates/session-start.sh`.

**Pick the real root before anything else.** If development happens in `<workspace>/v2` and
`<workspace>/v1` is another generation, the root is `v2` — not the workspace above it. Getting
this wrong makes every barrier and every relative path point one level too high.

### Rule 3 — Four carriers: wiki, history by day, cards, and memory as a pointer

A months-long project kills a single shared memory store: it grows until every session pays for
every layer's trivia. Splitting it by layer (two levels) is the first fix and it is not enough —
because the *chronicle* keeps growing on the always-read path. Measured on a real project: a
`STATE.md` that answered both "where are we today" and "what is true about this project" reached
385 lines in **two days**, and private memory grew alongside it. Both were read at every session
start, so both were paid for at every session start.

Four carriers, and the rule that separates them:

**Memory holds a pointer · history holds the days · the card holds the task · the wiki holds the
thing itself.**

1. **Shared knowledge base = git.** `STATE.md`, the team charter, the board, `docs/plans/`,
   `DECISIONS.md`, `GOTCHAS.md`, `INDEX.md`, the layers' `CLAUDE.md`. Versioned, permanent,
   greppable. **Anything more than one agent needs to know goes here.**
2. **History = one tree per agent, one folder per working day**, in that agent's own root:

   ```
   <agent root>/docs/history/
   ├── INDEX.md              # mini-summary, a few lines per day, newest first
   ├── current -> 2026-08-25/    # symlink — memory points HERE, never at a date
   └── 2026-08-25/
       ├── STATE.md          # the day's answer to "where are we" — same sections as the root one
       └── <agent-name>.md   # that agent's chronicle for that day
   ```

   Put the coordinator's tree in the root that contains the others, and it can read every agent's
   history without being sent it. Nobody mails their day to anybody. A tree shared by two agents
   (same launch directory) carries **two** state files, `STATE.<agent>.md`, and one diary each.
3. **Wiki = `docs/wiki/`** — where things are, how they work, what will bite you. Its own rule
   below, because on a large project it is the carrier that does the most work.
4. **Private per-agent memory** = its own store, bound to its directory: its own scars and
   preferences, **plus a pointer to `docs/history/current` — never a date, never the facts.**

Writing rule for the charter: *what the thing is and how it bites → the wiki; what happened today
→ the day file; how a task was solved → its card; only my own scar → private memory; in doubt →
the shared carrier, where it gets seen.*

Two tests settle almost every case:

- **Would this still be true next month?** No → not the wiki; it is `STATE.md` or a day file.
- **Would someone look for this without knowing which task produced it?** Yes → the wiki. A trap
  found while doing a task belongs in the wiki *as a trap*; the story of finding it stays in the
  card. A card and a wiki page on the same subject are not duplication — the card says what we did
  about it, the page says what it is.

**Two `STATE.md` files, one question.** The root `STATE.md` answers "where are we in the project"
and is rewritten **only when a day closes**. The day's `STATE.md` answers the same question in the
frame of one day, with the same section numbers, and is rewritten before every compaction. At
close, what survived the day moves **section into section** upward; the rest stays in the day.
The root file must never accumulate day summaries at its tail: on a live project four "day X
closed" sections — 240 lines, 22 KB — sat there for a week and were read by seven agents at every
start, answering "where are we" with last week's state. A day's summary goes **into the day's
folder**.

**What a day file is for.** The chronicle of the *process*: which cards were taken and in what
order, what the owner ruled and when, dead ends, what broke and how the day recovered, the
outcome at close. **Not** how a task was solved — that is the card. Rule of thumb: a day file that
cannot be read in a minute is describing tasks, not the day. If a paragraph would still be true
next month, it belongs in the KB, not in a day.

**Regulation to write down once:**

- a new working day is a new folder, and `current` is moved to it — **on the owner's command**
  (Rule 11), never because the date rolled over;
- **state is fixed *within* the day** — context may be compacted several times in one day, and
  each compaction is preceded by an update of that day's file, not by starting a new day;
- **a day-scoped `STATE.md` is a shredder** — it is rewritten tomorrow, so a durable fact parked in
  it and nowhere else is gone. Move it out the same day. This bites within hours of introducing the
  regime, while everyone still trusts the old file: an agent pruning its memory cited `STATE.md`
  for part of a fact that lived only there, and the pruning was correct under the *old* rules;
- **the test for deleting a carrier is survivability, not existence.** Not "does this fact exist
  somewhere else" but **"will that carrier survive a week"**. `STATE.md`, a day file and the chat do
  not; a reference to one is grounds to relocate first, not to delete. And check *which part* of the
  fact each carrier holds — mechanism and status drift apart silently, and a grep for one word finds
  only one of them;
- nothing is deleted: days accumulate, the index gains a few lines a day, **memory gains nothing**.

When introducing this into a project that already has one fat store and a fat `STATE.md`: sort the
memory files by layer, leave cross-cutting ones with the coordinator, **move the chronicle into
dated day files and the durable sections into topical ones**, then rewrite each store's `MEMORY.md`
index — a store whose index still lists moved files is worse than no index. Move text rather than
re-summarising it; the point is that nothing is lost, only relocated off the hot path.

### Rule 4 — The wiki: where the explanation lives

The project is large and the framework beneath it is larger. `CLAUDE.md` holds the **rule** and is
read every session, so it must stay short; the **explanation** — where a thing is, how it works,
what will bite you — has nowhere else to go and ends up scattered across commit messages, closed
cards and one agent's private memory, findable only by whoever remembers the number.

**The wiki has no dates, no statuses, no "currently".** A page that would need editing because a
day passed is the wrong page: that content is `STATE.md` or a day file.

**Ownership — split it, or it does not get written.**

```
docs/wiki/
├── Home.md      # the map. coordinator
├── README.md    # this regulation, project-local. coordinator
├── common/      # cross-cutting: domain, regulation, architecture, glossary, silent-failures,
│                #   norms-earned. coordinator; another agent contributes THROUGH the coordinator
├── backend/     # its agents write and commit here directly
├── db/
└── frontend/
```

An agent's own section is **the single exception** to "the coordinator owns the umbrella repo's
docs" — treat it like that agent's cards. Cross-cutting pages go through the coordinator, not to
gatekeep but because a cross-cutting page is the one place two layers can quietly contradict each
other, and somebody has to hold the whole. Two agents sharing a launch directory share a section;
split it **by subject or by mode**, not by file prefix, and cross-link the seams.

**Copy nothing into it.** Files that already work — a `GOTCHAS.md`, an `INDEX.md` tree, design
docs — stay where they are, and the wiki *indexes and links* them. New material is written in the
wiki. A page migrates in only when somebody is rewriting it anyway. This is the whole difference
between a wiki and a second set of stale documents, and it is what lets the wiki start without a
migration project.

**What makes a page worth having:**

- **a coordinate** — a path, a function, a table. A page without one is an essay;
- **traps above description.** "Works but silently does the wrong thing" is worth ten paragraphs of
  narrative, and it is what people arrive looking for;
- **verified, not remembered.** Check against the source before writing, *especially* what you are
  sure of. Mark the rest explicitly unverified — a guess inside a written page is more dangerous
  than a guess in someone's head, because the page reads as knowledge. Price on a live project: a
  layer's `CLAUDE.md` described three configuration fields; the coordinator built a card on them;
  the fields did not exist in the code (0/0/0) — the file read every session was describing
  nothing;
- **no numbers that rot** — the command that counts them, not the count.

**Two pages every team ends up needing, so create them on day one:** `silent-failures.md` — the
catalogue of forms in which a thing looked done and was not (an instrument that answered a
different question than the one asked, a review by the diff "before the remarks", a comment
promising a guard that does not exist); and `norms-earned.md` — each norm with the incident that
bought it. The second is what keeps the charter short (Rule 10): the rule stays in the charter,
the story moves here, one link between them.

**It fills faster than you expect.** Told to write their sections, four agents produced fourteen
pages in an afternoon, because each had been carrying that material privately and had nowhere to
put it. Budget for reviewing them, not for prompting them.

### Rule 5 — The board lives in git

A named team needs one place where the flow of work is visible and permanent. Put it in the repo
the coordinator owns:

```
docs/board/
├── README.md              # how the board works
├── BOARD.md               # kanban: the task table is GENERATED from card frontmatter
├── sync.sh                # regenerates the table, validates the board; --check before commit
├── PRIORITIES.md          # groups and a queue per agent (Rule 7)
└── cards/<id>-<slug>.md   # one card per task: description, assignee, discussion, outcome
```

History is `git log docs/board/`. The card is the history of the work — decisions written down as
they are made, so nobody re-litigates them next month.

**The card's frontmatter is the single source of truth; the table in `BOARD.md` is generated.**
Edit a card, run `sync.sh`. A coordinator who edits the table by hand gets it overwritten on the
next run — and the validator refusing to commit until the table matches is the correct behaviour.

Fields that earn their place: `status` (`queued | doing | blocked | review | done`); `assignee`
as a **list**; `evidence: command | artefact` — how acceptance will be shown; `source` — where the
task came from (a plan, the owner's word with its date, a neighbour's measurement); `blocked_by`
— **what exactly is awaited**: a card, an agent, a decision of the owner. A `review` queue in
which 22 of 23 cards say `blocked_by: —` is not a queue waiting for work; it is a queue of owner
decisions nobody has grouped for him (Rule 6).

Sections of a card: *Task · Done when · Boundaries · Questions to the owner · Work log · Outcome*
(`templates/card.md`). **`review → done` is the coordinator's or the owner's move**, never the
author's. A pre-commit hook runs `sync.sh --check`.

Why not Trello / GitHub Projects / Jira: an external board splits across repositories, lives
outside git, needs credentials, and costs an API round-trip per read. A git board is one carrier
for all components, readable instantly, and diffable. If the owner wants an external board, it is
*their* view: **mirror git → board** at the day's closing, never the reverse, and do not make agents
poll it.

### Rule 6 — Task flow, review, evidence, and who commits

1. **Card.** Coordinator creates `cards/<id>-<slug>.md`, puts it on the board and gives it a group
   (Rule 7).
2. **Assignment.** The card lands in the executor's queue, and the agent takes the next card of its
   own queue itself. `SendMessage` is for what is out of order — a critical card, a question.
3. **Work in the open.** The agent keeps the card in `Doing` and writes decisions and traps into
   it as it goes. The owner watches and can interrupt.
4. **Review — before the commit, and the author starts it.** Each named agent invokes a
   **subagent with a code-review skill itself**. Do **not** route review through the coordinator:
   that turns him into a bottleneck and everyone queues at one desk.
5. **Fixes.** The author addresses findings or refutes them with evidence — a finding is a claim,
   not a verdict.
6. **Commit — the agent's own decision after review**, in its own repository, **by path** (never
   `git add -A`: other sessions write in the same repositories). Documents — the card, the day's
   state, the diary — the agent commits itself whenever it goes idle. Not the owner's word: a commit
   is local and revertible, and the charter grants rights over reversible things.
   Price of getting this wrong: a coordinator extended "the owner's word" to ordinary commits and
   held finished work uncommitted for a day; the owner: *"where is that norm written? nobody else
   has it."* Compaction destroys uncommitted work; a written-down deferred review destroys nothing.
7. **Report.** Card to `Review` with an **Outcome** section, one line by `SendMessage`.
8. **Push and tag — outward, by the owner's recorded word** (Rule 12). A team that ships releases
   does better to centralise the push in the release role: it pushes every repository that has to
   ship, in one pass, right before the release is cut. Release images are built from the tag on
   origin, so the push is part of cutting the release, not of finishing a card.
9. **Close.** Card to `Done`; the coordinator records the slice in the day's `STATE.md`.

**"It works" is not accepted without command output.** The card's Outcome carries the command
and its output in a fenced block (or names the artefact — a filed application, a published page,
a tag in `origin` — when no command exists). Let the validator refuse `review` without it. And
know its blind spot: a validator that checks for *a fenced block anywhere in the card* passes a
long card whose finding section has code and whose Outcome is empty — three such cards sat in
`review` for a week. The check must look at the Outcome section, not at the file.

**How to brief a review so it is worth its tokens.** The author hands over **an entry point, not
"look at the diff"**: what changed, what to check, what the author did **not** check, what not to
touch. **One pass per task**, not three as the author keeps finding new things in his own work. A
finding is `file:line` plus "breaks under these conditions". The subagent **fixes nothing itself**
and never touches a database, a stand or production. **"No objections" counts only with a list of
what was looked at.** Review the diff *after* the remarks were addressed, not the one before them.

**A neighbouring named agent is not a replacement but a layer above, when needed.** A subagent
reads code; **it does not check the premise under the code, because it does not know the domain.**
Contested reasoning, a seam between two layers, an acceptance number — those go to the neighbour.

> Measured price of that difference, from a live incident: a QR charging session never started on
> production. The SQL read perfectly — the payload was assembled cleanly, with a comment promising
> the transport would reshape it per station version. A code-reading subagent would have had no
> objections. **The defect was in the premise, not the code:** the OCPP 1.6 schema does not know
> the field being sent, and the transport's promise was not kept. Seeing it required knowing the
> protocol and reading two layers at once.

If the platform's interactive review command is billed, say so in the charter: that one belongs to
the **owner**; agents use a subagent.

**The review queue is a decision queue.** On a visible team most cards in `review` wait for the
owner, not for work: a push, a rollout, a live acceptance in the browser, a ruling on substance.
The coordinator's job with that queue is to **group it by what each card waits for** and put the
grouping in front of the owner — not to count it.

Cross-agent traffic is allowed and expected — the front-end agent asks the db agent for the
endpoint contract rather than inventing it. State the axes explicitly in the charter, and require
that any decision born in a two-agent conversation lands on a card, or the coordinator never sees
it.

### Rule 7 — Limit work in flight by people, not by cards

The failure this prevents looks like success on day one: every agent picks up a card and all four
work at once. The owner then discovers two things at the same time — he can no longer see *what
stage the work is at*, which was the whole reason for a visible team rather than a fleet, and he is
paying for four parallel context streams. Both goals defeated by the same move.

**The limit is on people.** A card names as many assignees as it has work for, and they take it
**together**; an agent the current card does not name may take the next one, but only a card where
it is **alone**. What is forbidden is two cards in flight that share an assignee — that overlap is
exactly the unfollowable parallelism. Make `assignee` a list, and let the board's validator enforce
it: parse the list, and fail if any agent appears in two cards that are in flight. **It will catch
the coordinator too** — twice on a live project, both times correctly.

Corollaries worth writing into the charter:

- **Review of the active card is part of that card.** It opens no second slot and the reviewer is
  not added to `assignee`.
- **The coordinator consumes no slot** — it writes no code, and its cards (research, regulation,
  the board itself) block nobody.
- **Idle is the correct state, not a failure.** An agent with nothing to do costs nothing — **as
  long as nobody writes to it** (Rule 10). Say so explicitly, or agents invent work: "just
  preparing" the next card is work, it burns context, and it presumes an order that the next
  conversation may change.
- **Whether `review` occupies the slot is the owner's call**, because it sets the team's
  throughput: `doing` only lets work pile up in `review`; `doing review` keeps the author bound to
  his card until it is accepted. Write down which one you chose.

**Chat discipline belongs to the same rule.** The chat is for business — a question, a hand-off,
working out a failure together. It is not where results are published. A finished piece is
announced in one or two lines: *"T067 done, detail in the card."* The substance goes **into the
card**, which is where the next reader looks anyway. A long report in chat is paid for twice —
once by the sender's context, once by every recipient's — and it is unfindable a day later. The
same holds upward, to the coordinator: the short form plus the card, not the essay. The same holds
for the reply to "the day is open": **one line**, not a report.

The card is therefore **the source of knowledge about its task** — not memory, not the chronicle.
An agent whose card is thin has not finished the task; it has finished the code.

**Priorities are groups and queues, not a sorted list.** Once the board passes a few dozen open
cards, give it `docs/board/PRIORITIES.md` (`templates/PRIORITIES.md`): five groups — **Critical**
(a hole open *now* from outside or between tenants; money obtainable by deceit), **Urgent** (a
deadline, work in flight, finished work awaiting acceptance), **Important** (a real defect),
**Ordinary**, **Unimportant** — and a queue per executor. The rules that keep a day from turning
into chaos:

- the agent **takes the next card of its own queue itself**; nothing out of queue except
  Critical, whoever sends it;
- **one `doing` per agent**, interrupted only by Critical;
- **every day starts with acceptance of `review`** — cheaper than new work, and it frees the
  release;
- a new finding **gets its group when it is filed**, by the coordinator in the same move;
- **the release train** carries closed Critical + Urgent + Important at the cut; Ordinary rides
  only if already merged; outside the train — only a critical patch;
- **questions to the owner are one list** in `STATE.md`, in group order, not scattered across
  terminals.

### Rule 8 — Sharding: an agent may hire, but still answers

A named agent starts a background sub-agent for a specific task — for the review of Rule 6, or
when it is overloaded — and supervises it.

**Write the permission into every layer's `CLAUDE.md`, not only into the charter.** The
environment's default is *do not start a sub-agent unless the **user** asks*, and it is lifted by
a record in `CLAUDE.md` — not by the charter, and **not by the coordinator asking**, because a
colleague is not the user. Skip this and the rule silently does not apply: an agent, correctly
following its own instructions, refuses a review its coordinator requested. That happened on a
real team before the record was added.

Once the record exists, say plainly that **no per-launch request is needed** — otherwise the ban
is reinstated out of caution by the next agent that reads the environment default and not the
`CLAUDE.md`.

- **The named agent answers for the result, not the sub-agent.** The coordinator asks the named
  agent; that agent accepts, verifies and absorbs the work as its own.
- Briefing is mandatory — skill, the relevant reference pages, working examples, and the rule
  *"unverifiable" beats a guess: a verdict without a coordinate in the code is not accepted*. An
  unbriefed sub-agent is confidently wrong on anything non-standard.
- **Pick the sub-agent's model for the job.** Checking claims against code, filtering a log,
  running a test set — a smaller model; designing or reviewing a state machine — the large one.
- Sub-agents are one-off. A role that keeps recurring is the signal to promote it to a permanent
  named agent (devops, qa), not to breed background ones.
- **Sub-agents spend the same limit.** Near the end of a weekly allowance the rule is: finish,
  release, stop — no new cards and **no sub-agents** (Rule 10).

### Rule 9 — One write barrier per component

Roles in prose are not enforcement. A `PreToolUse` hook per component is.

Copy `templates/guard-write.sh` and `templates/guard-write.test.sh` into each component's
`.claude/hooks/`, edit the CONFIG block, `chmod +x`, register the barrier in that launch
directory's `.claude/settings.json`, and run the test (`hooks.md`). What it enforces:

- **a positive allow in one place** — a write passes only if it lands in the role's own paths (plus
  the agent's own memory store and, for an auditor, its scratchpad); everything else in the
  workspace is refused. An enumeration of what to block always misses a name;
- **the role is decided by the launch directory**, and an unknown role is refused. The direction of
  error is a **false refusal — visible at once and lifted in one line — never a silent pass**;
- **secrets are read-only**, while `.example` templates stay editable;
- **narrowing for the roles that write no code** — the coordinator and the auditor get an
  allow-list of what they may write inside the root;
- **the Bash branch** refuses destructive verbs, in-place edit flags in any form, `cd` followed by
  a write, `git apply`/`patch`, and writes into other projects of the workspace — best effort
  (below).

**Check that it is called, not only that it works.** A barrier that passes its test but is not
registered in the `settings.json` of the directory an agent starts from is never invoked: two launch
points of a live team ran for weeks with no `PreToolUse` at all, and the session logs showed zero
calls. The acceptance includes a registration check for every launch directory.

**A temporary exception carries its removal condition** — in the barrier's comment and in the
card: *"open for `<path>` during stage 1; remove at step 1.9"*. Without it the exception becomes
the rule.

State the framework model explicitly, because it drives the barrier: **framework code consumed as
a submodule is patched in place, inside the project** — the closed environment where the fix is
tested together with the project's own code — **and only then pushed upstream and pinned**. Commit
and push before `git submodule update`, or the work is lost. Copies of the framework elsewhere on
the machine are mirrors, not the source of truth.

**Say what the barrier does not do.** It stops the file tools (`Write`, `Edit`), and it cannot
stop a shell redirect to a relative path — the Bash branch is a deny-list of verbs against known
mirrors, and there is no positive allow for a target hidden behind `../`. Write that into the
barrier's header and into the regulation: *mechanism plus agreement*, never "the barrier prevents
it". A mechanism recorded as stronger than it is teaches the next reader to stop checking.

**The rest of the harness lives once, with the coordinator,** and layers find it by walking up:
the `SessionStart`/`PostCompact` briefing (identity by launch directory, boundaries, reading order,
the open working day, the context rule), the context guard (Rule 10), the output filter, and an
optional desktop notification. Keep hook text in files, not in quoted JSON strings — an apostrophe
inside a quoted hook string killed a `PostCompact` for a day while the JSON looked fine. **Run
each hook** to test it; reading it proves nothing. Templates and wiring: `hooks.md`.

### Rule 10 — What is always read is always paid for

Every carrier has a price, and the price is *frequency of loading × its size × the number of
agents*. Nothing else about a document matters as much, and it is invisible paragraph by
paragraph: each one looks like it belongs.

**Measure before you cut.** File sizes are an estimate; the platform's own usage report is the
instrument (`/usage`, weekly view: behaviour flags such as *long context* and *cache misses*,
attribution by skill, subagent and MCP server). On a real team the estimate said 12.5k tokens of
startup load and the report said 14.6k — and, more usefully, it showed the startup load was *not*
the main consumer, while still being multiplied by every session ever started.

```bash
wc -c <root>/CLAUDE.md <layer>/CLAUDE.md <memory>/MEMORY.md   # what loads at startup
wc -c docs/TEAM.md docs/STATE.md docs/history/DAY             # what the charter orders read next, and what the hooks print
grep -cE '[0-9]{2}\.[0-9]{2}|20[0-9]{2}-[0-9]{2}' docs/TEAM.md   # dated lines = chronicle in a charter
grep -oE '\b[A-Z][0-9]{2,3}\b' docs/STATE.md | wc -l            # card refs = the board copied inside
grep -n '^## День\|^## Day' docs/STATE.md                        # day summaries in the root state = the chronicle again
```

Four findings that recur, in order of how much they cost:

- **The root `CLAUDE.md` is loaded by every agent**, because `CLAUDE.md` is collected up the
  **directory** tree, not the git tree — a component being a separate repository changes nothing.
  It is therefore the single most expensive document in the project, and the first to diet. Keep
  each `CLAUDE.md` under ~200 lines: rules, boundaries, verification commands, traps that bite in
  every session. A procedure needed in *some* sessions (how to cut a release, how to apply a
  migration, how a module is built) is a **skill**, loaded on demand. Measured on a live project:
  layer files of 528, 357, 353 and 270 lines, on top of a root and a workspace file — a db agent
  read ~1,500 lines before its first action.
- **The mandatory reading a charter orders can outweigh the prompt itself.** On the same team
  `TEAM.md` + `STATE.md` came to ~29k tokens against ~14k of loaded context.
- **A charter accumulates its own history.** Every norm arrives with the story of the mistake that
  bought it — right to write down, wrong to re-read in every session. Move the stories to
  `wiki/common/norms-earned.md` and leave the rule plus a link. The story is needed exactly once:
  when someone is about to weaken, bypass or reinstate the rule. Mind that cards and
  `DECISIONS.md` cite the charter by line (`TEAM.md:165`) — moving text moves the citations.
- **What the hooks print is read at every start and every compaction by every agent.** A `DAY`
  file with 26 lines of explanatory comments was printed seven times per restart; the comments
  belong in the regulation, the file keeps four fields and the rule of behaviour.

**Language is money here.** The same thought in a language that tokenises poorly can cost twice as
much. Write **the charter, the `CLAUDE.md` files and the hooks in English**; keep cards, wiki,
history and chat in the team's working language — those are read on demand, not at startup. This
is not a style preference and should be stated as such in the charter, or someone will "restore"
the original language out of respect for it.

**Move text, never re-summarise it.** Cutting by rewriting loses the sentence somebody needed;
cutting by relocation loses nothing. Every excision leaves one line and a link behind.

Measured outcome on a live project, one afternoon, no code touched:

```
TEAM.md            58 448 → 18 517 chars   English + norm histories moved to the wiki
root CLAUDE.md     29 217 →  5 794         reference material moved to wiki/common/system-map.md
STATE.md           27 914 → 19 839         four finished storylines moved to DECISIONS.md
STATE.md (later)   57 503 → 35 539         four day summaries moved to history/<day>/STATE.md
DAY                32 → 16 lines           comments moved to the regulation
startup per agent  −40% to −60%; ~26–29k tokens saved in every session of every agent
```

**The long-lived session is the other half of the bill — and on a subscription it is the larger
half.** Seven foreground sessions open for days cost in ways that no file diet touches:

- **Every turn sends the whole conversation.** Cached history is cheaper per token but **counts
  against a plan's limit**; a one-line question in a session open since morning costs that
  session's entire context.
- **A cross-session message is a new turn with the receiver's full context** — and after an idle
  gap longer than the cache lifetime (an hour on a subscription) it lands in a **cold cache** and
  re-processes everything at full price. Idle agents are free only until somebody writes to them.
  Do not message an agent for something that is on disk — the coordinator can read every tree.
  Batch what you must send. Reply in one line.
- **Launch an agent when there is a card for it, not because it is on the roster.** Five agents
  launched "just in case" on a day the owner had said *no work today* each received the opening,
  answered with a ten-line report, and received the closing — three full-context turns each for
  nothing.
- **Compaction is itself a large request** (it reads everything it summarises); **`/clear` costs
  nothing**. The closing protocol (Rule 11) ends with every agent stating that nothing remains in
  its context that is not on disk — so the correct next step is `/clear` in that terminal, and
  the `SessionStart` hook restores identity and day. Do not carry a finished day into tomorrow
  through compaction.
- **Verbose tool output is context you keep paying for.** A full test run, a migration log, an
  image build — hundreds or thousands of lines land in the agent's context and stay there.
  `templates/filter-output.sh` is the `PreToolUse` hook for it: it trims test runs, migrations and
  builds to the failures **and the summary line** (the card needs it), keeps the exit code, marks
  the trimmed output `[filter]`, and lets a command ending in `# nofilter` through untouched. Or
  delegate the run to a sub-agent and keep only the summary (Rule 8).
- **Add compaction instructions to the root `CLAUDE.md`**: what to keep verbatim (the owner's
  words, card ids and their status, commit hashes and what is pushed, cited decision lines, open
  decisions) and what to drop because a carrier already holds it. A summary that paraphrases the
  owner's ruling is how a norm gets weakened between two halves of one day.

**An agent's context lives one working day — and a hook enforces its size.**

- **Enter once a day.** At the day's opening the agent starts in a clean context (the hook
  delivers role and day), loads its skill **once** and works cards back to back until closing; the
  owner's corrections stay in context. After a compaction — the skill again: the summary does not
  keep it. Measured reason: `/usage` across seven terminals showed 98.7 % of tokens were context
  re-read on every tool call, with sessions living 6–8 days at 300–350k and no boundary. A
  sub-agent per card was rejected by the same arithmetic: three or four entries of 150–230k a day
  against one.
- **Three rules with numbers.** Past **300k** — no new card unrelated to the current one, whoever
  sends it. Past **450k** — even the current card only to a point of continuation; compaction sits
  on a card boundary, never mid-card. **Idle** — fix the state yourself (card, the day's
  `STATE.md`, diary, commit of docs by path), without a reminder. The numbers are the owner's
  setting; they started at 200k/350k.
- **Enforced, not advised.** Written as text, the rule was broken by every agent, because "I have
  no exact context counter" was a true answer. `templates/context-guard.sh` (`UserPromptSubmit`,
  `PostToolUse`, `Stop`) reads the size from the last `usage` record of the transcript, resets after
  a `compact_boundary`, puts the rules with the measured number into the agent's context past the
  soft threshold and every +25k while it works, and holds the turn if readiness is declared
  anywhere but in the last line (Rule 11).
- **Weekly limits get rules too.** At ~80 % of the weekly allowance only what the next release
  needs is worked on; at ~92 % — finish, release, stop: no new cards, no sub-agents. Write the
  thresholds into the charter; the owner moves them.

### Rule 11 — The working day is opened and closed by the owner's word, not by the calendar

A working day is the unit of the team's memory: a folder per agent, a `STATE.md`, a diary. It
begins when the owner says *"open the day"* and ends when he says *"close it"* — relayed by the
coordinator. Midnight does nothing: a `current` symlink that points at yesterday's date on today's
clock is **an unclosed day, not a discrepancy**.

- **One file says which day is open** — `docs/history/DAY`, written only by the coordinator,
  printed by every agent's `SessionStart` and `PostCompact` hooks.
- **Three prohibitions:** no new day by the calendar; no moving `current` without the word; no
  closing the day yourself.
- **Opening means handing the opening to each running agent**, checked by command, not by memory.
- **Closing is a seven-step protocol**, sent to each agent and answered by each; the coordinator
  starts nothing of its own until all have answered.
- **Readiness to lose context has one form.** The agent tells the coordinator by `SendMessage` —
  *"ready for compaction or clear, context N, commit <sha>"* — and **the last line in its terminal
  is exactly `Ready for compaction or clear`**. The phrase is the owner's choice; the context guard
  checks it. It is said at a threshold or at the end of a line of work, **not as a signature under
  every answer** — a phrase that appears everywhere stops meaning anything.
- **Watch for clears and brief after them.** A `SessionStart` hook is not guaranteed: once it did
  not fire, and a cleared agent stood silent for forty minutes. The briefing hook appends
  `HH:MM <agent> <clear|compact>` to a lifecycle log; the coordinator keeps a monitor on it
  (`tail -n0 -F`, re-armed every 30 minutes and after its own clear) and on each event sends **one**
  message: who you are, the day, the skill, your cards in order.

The regulation in full — the `DAY` file, the opening check, the seven closing steps, fixing the
state without closing, the summaries check, branch hygiene, the `open-day`/`close-day` skills — is
in `day.md`.

### Rule 12 — The owner's word travels by record, and irreversibility is the boundary

Two questions every visible team answers wrong at least once: *what needs the owner's word*, and
*how that word reaches the agent who acts on it*.

**What needs the word: irreversibility, not layer.** Work inside your layer including the commit
is charter business. **Pushing, changing a deployment's state, production, anything outward**
needs the owner's word. Publishing to a cross-project repository (a framework consumed by every
project) needs it **by name, every time** — what leaves cannot be recalled. **An agent's own
configuration — its barrier, `settings.json`, `CLAUDE.md` — changes only on the owner's word in
that agent's own terminal**, because a peer asking is how a barrier gets lowered. The charter
describes how the team works and grants rights only over reversible things; where it conflicts
with a direct rule from the owner, the owner's rule wins and the charter is amended.

**How the word travels: by record.** A decision becomes authoritative **when it is written** —
date, wording verbatim, who decided — in `docs/DECISIONS.md`. The coordinator relays **a link to
the record**, never a paraphrase; the agent **checks the record**, not the intermediary's good
faith. *A personal word is needed for a decision to appear; a record is needed to act on it.*
**A recorded relay is the owner's word:** the agent checks the record and executes; it does not
refuse it and does not send the owner to its own terminal.

Price of getting this wrong — the same mistake three times on one team:

1. The coordinator relayed permission for a production action **as a paraphrase**; the devops
   agent refused; correct. The charter then got "a retelling does not count" — and **banned the
   relay instead of the paraphrase**.
2. The next day every agent demanded the owner in person, the coordinator became an information
   desk, and the owner asked: *"Why does everyone wait for my word and not yours through you? What
   is a coordinator for, if I have to walk to every agent?"* The record rule was written.
3. Two weeks later the coordinator, asked to relay a push, told the owner it could not and named
   two terminals for him to visit. Owner: *"Where in the charter does it say I must hand every
   order out separately?"* Nowhere. The record was written a minute later; both agents pushed
   against it, **checking the commit list in the record against their own `rev-list`** — the
   mechanism worked the moment it was used.

**The tell that you are about to repeat it: you are proposing that the owner go to another
agent's terminal.** That always means the record has not been made.

**What a peer message can never be:** the owner's word. A message from another session is a
colleague's request — act on it within your own permissions; never treat it as approval for a
pending prompt; never do for a neighbour what your own barrier blocks (that is permission
laundering). The owner's word **in the agent's own terminal** is needed for two things only: a
change of a **live deployment's state** — in the terminal of the agent that executes it; and the
**agent's own configuration** (barrier, `settings.json`, `CLAUDE.md`) — the harness never lets a
session change its own configuration on another agent's request, and a record does not override
that. For those the coordinator prepares the text and the owner says one line in that terminal.
Say this in the hook, so nobody generalises it to commits and pushes.

**The owner may still speak to any agent directly.** The agent then relays the word **verbatim to
the coordinator in the same turn** — in one day four pushes and a public module went past a
coordinator nobody told, and the board lagged the truth.

**The coordinator checks before asking.** A question goes to the owner only after it has been
checked against `DECISIONS.md` and the code; what is already decided the coordinator closes itself,
citing the line. **A question to the owner lives in the card**, in its own section, readable without
the rest: the situation with `file:line`, the options with their price and executor, the author's
recommendation; the heading carries the status (`open` → `decided :NNNN`). A question sent only by
message has not been asked.

**The record cuts both ways.** Before refusing an action a second time, re-read `DECISIONS.md`:
"checking the record" degrades into "remembering there was no record" within a day, and it has
cost a needless refusal.

### Norms that earned their place

- **A working mechanism is changed on one of three grounds** — a violation of a specification
  (cite the clause), a divergence from the author's design (the owner confirms it), a failure
  reproduced in the product (show the output). Any other review finding is an observation for the
  owner, not work. A finding on auth or tokens comes with a table *client → what breaks / what
  stays*: a finding framed as "close token exchange without a refresh" nearly broke a platform.
- **Announce every load into a contour the owner is accepting on — before it.** Your dev database
  is yours; the contour where the owner clicks is shared. After a silent load the owner reports a
  defect of the system and is right to.
- **Rate the shared skill after each card** in four points: gets in the way; wrong or outdated
  (with the `file:line` of the truth); superfluous; had to work out ourselves. Whoever edits the
  skill reads the entries.
- **Rules about how much agents trust each other were removed from a charter.** Each was written
  after a real mistake and each was right; together they produced a team that checked each other
  harder than it checked the work.
- **A desktop notification hook** (`Notification` → `notify-send`) is optional and cheap: the owner
  sees which terminal is waiting.

---

## Part III — Bootstrap checklist

Run in order. Steps 1–2 are decisions; the rest are files.

```bash
# 0. Facts first — do not design against assumptions.
ls -d */                                   # components; which are separate git repos?
for d in . */; do git -C "$d" rev-parse --show-toplevel 2>/dev/null; done | sort -u
ls ~/.claude/projects/ | grep <project>    # existing memory stores
find . -maxdepth 2 -name CLAUDE.md         # what already documents each layer
```

1. **Decide the model** — visible team or fleet (Part I). Ask; do not infer.
2. **Decide the roster and the root.** One role per language plus a coordinator; the root is the
   directory development actually happens in. Ask the owner whether `review` occupies a slot.
3. **Write the charter** — `docs/TEAM.md`: roster with launch directories and memory stores, who
   assigns what, task flow with evidence, memory rule, board layout, sharding, team norms, **what
   needs the owner's word and how it travels** (Rule 12). Rules only; stories go to
   `wiki/common/norms-earned.md`.
4. **Add a "You are …" block to each layer's `CLAUDE.md`**: name, what it owns, who assigns its
   work, who to ask for a neighbouring contract, that the commit is its own decision after review,
   **its explicit permission to start subagents** (Rule 8 — the charter cannot grant it, only this
   file can), and **that it runs its own review before committing** (Rule 6). English (Rule 10),
   under ~200 lines.
5. **Point the entry document at the charter** — the coordinator's `CLAUDE.md` and `STATE.md`
   should name it, or nobody reads it. Add the compaction instructions section to the root
   `CLAUDE.md` (Rule 10).
6. **Create `docs/DECISIONS.md`** — the owner's decisions, dated, verbatim, with the decider; the
   carrier every relayed word points at (Rule 12).
7. **Create the board** — `docs/board/` with README, `BOARD.md`, `sync.sh` and the card template
   (`templates/card.md`) carrying `assignee` as a list, `evidence`, `source`, `blocked_by` and a
   *Questions to the owner* section. Have the validator enforce the in-flight limit by people
   (Rule 7) and refuse `review` without an Outcome (Rule 6) — retrofitting either means editing
   every existing card. Add `PRIORITIES.md` once the board passes a few dozen cards.
8. **Create a history tree per agent** — `<root>/docs/history/` with `INDEX.md`, today's folder,
   the `current` symlink, that day's `STATE.md`, **the `DAY` file** and one regulation file saying
   what a day is for, who opens and closes it, the seven closing steps, and how the two `STATE.md`
   files differ (Rules 3, 11). Cheapest on day one; by week two there is a chronicle to relocate.
9. **Create the wiki** — `docs/wiki/` with `Home.md`, a regulation naming the carriers, a `common/`
   owned by the coordinator (start `silent-failures.md` and `norms-earned.md` empty) and an empty
   section per agent (each with a one-line README saying who owns it and what belongs). Then ask
   each agent to write its section; do not write it for them.
10. **Install the harness** (`hooks.md`): the barrier and its test in every component; the
    briefing, the context guard and the output filter once, with the coordinator; a `settings.json`
    in **every** launch directory. The briefing says who the agent is by launch directory, what it
    may write, its verification command, that review is its own to start, which day is open, the
    context rule, and that live servers and own configuration change only on the owner's word in
    *this* terminal. Then test: run the barrier's test, feed each hook its JSON, **check that every
    launch directory's `settings.json` registers the barrier**, and start the coordinator's
    lifecycle monitor (Rule 11). **Run each hook** rather than reading it.
11. **Write the two day skills** for the coordinator — `open-day`, `close-day` — as checklists over
    the regulation (`day.md`).
12. **Split the memory** — move layer facts into the per-agent stores, leave a pointer to
    `history/current` in each, rewrite every `MEMORY.md`.
13. **Record the decision** — a dated design doc in `docs/plans/` listing what was chosen, what was
    rejected and why, so the next session does not re-open settled forks.
14. **Measure the startup cost once the harness exists** (Rule 10) — file sizes first, then
    `/usage` in each terminal after a week. The numbers only get worse, and a charter written in
    week one is exactly the thing nobody re-reads with a `wc -c` in hand.

