---
name: agent-team
description: Organise phased product development across specialised agent roles in Claude Code, Codex or any execution-capable agent CLI — the owner talks to one coordinator, which runs each card as a background executor session that ends with an outcome in the card. Use for responsibilities, launching and relaunching executors, authority tiers, evidence-gated acceptance and recovery across sessions; when a team process has outgrown its product (more records than delivered increments); when moving a team set up on one CLI to another; select the matching CLI profile for runtime setup.
---

# Agent team — product delivery with specialised roles

The goal is working, verified product increments. Team tooling serves that goal. Preserve the
existing specification, board, decisions and release process before adding infrastructure.
Measure success by accepted product outcomes, resolved blockers and the owner's coordination
effort, rather than agent count, message traffic or session longevity.

**The portable unit of a team is the card, not the session.** A card that carries its goal,
criteria, scope and continuation lets any fresh session of any CLI take the role and continue.
So the owner keeps one window — the coordinator — and the coordinator runs each card as a
background session of the right role, which ends with an outcome written into the card (§§ 1, 5).
Peer messaging, monitors and context guards are accelerators of one client — useful where they
exist, never what the process stands on (§ 8). Section 9 says how to tell when the team's
mechanics have started to cost more than the product receives.

After loading, announce: **"Agent team context loaded."**

## Read only what the task needs

| Need | Read |
|---|---|
| Claude Code: background launch, watching, hooks, messaging | [references/claude-code.md](references/claude-code.md) |
| Codex: detached runs, discovery, hooks, messaging | [references/codex.md](references/codex.md) |
| Any other CLI: a detached non-interactive run, the card as the channel | [references/other-clients.md](references/other-clients.md) |
| The working day: calendar default, owner-word option | [day.md](day.md) |
| Claude hook templates; telling background from interactive | [hooks.md](hooks.md), then the Claude profile |
| A known failure: write barrier, worktrees, background sessions | [pitfalls.md](pitfalls.md) |
| Apostol project/framework ownership | [apostol.md](apostol.md), subject to the actual project roster |
| Rationale, knowledge layout and detailed review examples | Relevant section of [references/field-guide.md](references/field-guide.md) |

The field guide preserves experience; it is not mandatory startup reading. Templates include
shared card/day examples and Claude-specific runtime examples. Do not install either CLI's
configuration into the other. Project instructions and owner decisions determine permissions;
this skill grants no new authority.

## 1. The shape: one window, executors in the background

Use the owner's stated preference. Ask only if unknown: does the owner work alongside a visible
team, delegate bounded stages, or want unattended execution? These are levels of autonomy, not
rankings of CLI quality. The shape below serves all three; what changes is how often the owner
looks in.

- **Two interactive sessions at most.** The **coordinator** is the owner's one window; a
  **technical lead** is optional. The owner talks to them only.
- **Executors are background sessions, one per card.** The coordinator launches each from the
  role's own directory, so the role's instructions, memory, write barrier and start-up brief
  apply exactly as in an interactive start. The launch line's core is «Continue as `<role>` on
  `<card>`». The session ends when the card reaches an outcome (§ 5); the next card gets a fresh
  session.
- **Model and effort per role come from one table the owner controls**, kept with the
  coordinator's instructions. A card may raise effort in its head; the card wins.

A **role** is a stable responsibility with allowed scope and accountable output. A **session**
is a replaceable context. A **card** is an authorised unit of work. A **transport address**
identifies a current recipient. Neither a session id nor a display name is task state.

The coordinator is the team's **control bus**: it launches, watches, relaunches and stops
executors, and turns their outcomes into one status line each for the owner. A subagent inside
the coordinator's own session is not an executor — it inherits the coordinator's barrier, not the
role's. Background does not mean hidden: the owner can attach to any executor, read its log and
interrupt it, and does so through the coordinator. Do not launch idle roles to fill a roster.

## 2. Keep knowledge in the existing project

- Specification/requirements define intended behaviour; source and checks establish facts.
- The card holds scope, acceptance criteria, decisions, evidence and continuation.
- Wiki explains durable mechanisms and traps with source coordinates; link existing documents.
- Project/day state describes current position; history records events. Task detail stays in cards.
- Private memory is an optional pointer, never the only carrier of a team obligation.
- Record consequential owner decisions verbatim with their scope; peer messages are not approval.

Reuse the existing board and wiki. Do not add a parallel task database to adopt a framework.
For a new project, shared templates can seed these carriers. In an existing project, a schema,
language, storage or commit-policy migration is separate work.

## 3. Assign roles at real seams

The coordinator holds priorities, dependencies, owner decisions and acceptance routing; it writes
no product code. CTO, where needed, owns technical design and release planning. Developers own
defined layers/toolchains; preserve the project's framework ownership exceptions.
QA independently checks behaviour; audit independently checks requirements, assumptions and
evidence. They route defects to developers rather than silently changing their implementation.
DevOps owns authorised infrastructure operations.

Use only roles needed for the stage. An interface seam is settled in the card: the executor
writes the question and may ask the neighbouring executor directly or through the coordinator; the
answer lands in the same card or the decision record. Do not invent new roles, product tasks or
permissions.

## 4. Deliver bounded stages

Typical flow, adjusted to task risk:

`goal and acceptance -> technical decision -> implementation -> independent verification -> acceptance`

**A transition needs evidence, not a status edit.** `review` carries the evidence command output
or the named artefact; `done` carries an acceptance matrix written by someone other than the author:
every criterion `pass`, `fail` or `not verified` with its evidence, and `not verified` is not
`pass`. Each role leaves a minimal output in the card — the author: what changed, checks run,
checks not run and why, known limits; the reviewer: the matrix, findings, an unrelated-changes
check and the decision. Rejected work returns with an actionable finding and reproduction/evidence.

Approval gates are explicit. By default a role stops where the owner decides (product meaning,
an architecture/API/schema/payment/security change, anything irreversible). An "auto" permission
covers a named transition or a bounded segment, never the whole workflow, and still stops on a
blocking question, a second rejection, secrets, destructive or live-system actions. Update affected
documentation when needed. Follow the existing release plan and gates. QA passing does not
replace an owner ruling on product meaning.

A local correction need not visit every role. Cross-layer contracts involve their affected
owners; permission, security and regulatory changes need corresponding checks. Group related
changes into coherent passes to avoid repeated builds/reviews without hiding risk.
Record relevant checks and limitations. Do not require full suites after every small edit or
skip a required gate because a patch is small. Follow project-specific review requirements.

**Authority.** Three tiers, written once in the project's instructions:

- **The executor itself:** edits in its own scope, a local commit after its own review, tests on
  throwaway stands.
- **The coordinator, by a standing owner decision recorded with its bounds:** start, order and
  relaunch of cards inside an accepted scope, a "by recommendation" answer to a technical
  question, and regulated actions the team has performed before — a push after review and the
  quality gate, reading servers, a rollout by the release procedure. A coordinator's message that
  cites a recorded owner decision **is** the owner's word: the executor checks the record and
  proceeds without asking again. Each such decision is one line in the card citing the record.
- **The owner only:** product meaning, scope and freeze of a release, and anything destructive,
  irreversible or not covered by a procedure. These stop whoever asks — think, not only follow
  the charter. An agent's **own configuration** (instructions, barrier, settings) changes only on
  the owner's word in that agent's own terminal; this is a harness rule, and no record or relay
  substitutes for it.

An unattended executor that meets an owner-only decision stops with outcome `blocked` and the
question in the card; it never waits at a prompt nobody will see.

**Concurrency: one executor per repository** unless the project has prepared worktrees. A
background worktree isolates the session and allows parallel work in one repository, but a fresh
worktree has no initialised submodules, no ignored files (secrets, `.env`), no build cache — and a
test stack that mounts the main checkout tests the old code and reports a false green. Either
prepare worktrees (the code root as a compose parameter, a worktree-creation hook that initialises
submodules and copies the environment, a shared build cache) or switch isolation off and keep
the queue. Different repositories run in parallel. Check trees before edits; preserve others'
dirty work; stage explicit paths; account for every repository and dependency pin.

## 5. The outcome closes every executor run

Before ending, the executor persists these fields in the card (prefer references over copies):

1. Goal, current stage and checkable acceptance criteria.
2. Allowed paths, relevant contracts and consequential owner decisions.
3. Changes and `repository + commit`, including local/pushed state.
4. Relevant dirty files and their owners.
5. Checks run with results; checks not run and why.
6. Open findings, dependencies, blockers and questions needing a decision.
7. Next responsible role and exact continuation point.

Then the **last line of the card's work log** is the outcome, and the session ends:

`Outcome: review|blocked|checkpoint|failed — <one line>`

| Outcome | Meaning | The coordinator |
|---|---|---|
| `review` | the work meets its criteria with evidence | launches an independent check (QA, audit, or the neighbouring role at a seam) as its own run |
| `blocked` | a decision or dependency is missing; the question is in the card | decides within the standing authority, or puts one question to the owner |
| `checkpoint` | the context threshold was reached; the state is recorded | stops the session and relaunches the same line — a fresh context replaces a clear |
| `failed` | the run crashed or broke a rule | reads the log and the card; relaunches only with a corrected brief |

**Relaunch guard:** at most two relaunches of one card without a new work-log entry; then stop and
ask the owner. **One status line to the owner per outcome:** card, outcome, evidence locator, next
step. The owner stops asking for status because status arrives by itself.

Independent review needs a separate session and enough raw evidence to check the result;
relabelling the author's own answer is not independent review. The author's own pre-commit review
(a review subagent inside the executor's run) is a different, earlier check and does not replace it.

**Messages are an accelerator.** The content is always in the card, so nothing is lost on a client
without messaging. Executors may message each other on a seam; the question and the answer still
land in the card. An executor notifies the coordinator on `blocked`/`failed` and on finishing,
unless the launch already delivers an exit notice. Across teams, coordinator talks to coordinator.
Avoid ACK loops, roster pings and repeated reports without new state.

## 6. Context and recovery

A fresh session per card is the recovery strategy: the card, not the chat, carries the state.
Thresholds and the context guard stay. For an executor, "record the state and stop" **is** the
`checkpoint` outcome — no readiness line, no wait for a human to clear. For the interactive
coordinator and technical lead, the project's readiness rule applies and the owner resets them.
Hooks fire in background sessions as well; a guard that checks the readiness line in an
interactive session checks the outcome line in a background one ([hooks.md](hooks.md)).

After any fresh start the session binds the explicitly assigned role, loads its instructions and
the card, checks commits and dirty trees, and continues from the stated point. Never clear,
compact or stop a peer except as the coordinator acting on an outcome or the owner's word.

**The working day is the calendar day by default.** The first session of a date opens it and
closes the previous one; daily history slices stay. A day opened and closed by the owner's word is
an option for teams that work across midnight ([day.md](day.md)).

Load the needed role/skill, exact card sections and relevant source only. Bound tool output while
preserving failures, summaries and exit status. Distinguish capacity, current context occupancy,
lifetime token usage and account limits; unknown is not zero. Thresholds and cost claims depend
on the actual model, client and plan, not historical fixed numbers.

## 7. Adopt the smallest useful runtime

Reuse available CLI capabilities before adding a launcher, queue, database, daemon or orchestrator.
A background mode the client already has is enough; a supervisor of your own is not needed. Keep
common process separate from client adapters. Preserve the other CLI's configuration and ongoing
work unless the owner explicitly authorises changing it.

Tool-managed workflow frameworks contribute useful stage contracts, evidence-driven transitions,
independent quality and durable handoffs (§ 4). Apply these principles to existing cards without
automatically adopting their managed storage, role names or approval system. Full adoption requires an explicit migration
and one agreed source of truth. An external orchestrator is an option, not a prerequisite.

Accept setup through a bounded, authorised product stage: can the coordinator launch an executor,
receive its outcome, launch an independent check and report to the owner — without the owner
carrying a message or resetting a session? Config parsing, hook fixtures, a background start, an
outcome read back, a relaunch after `checkpoint` are different evidence levels; state which passed.
Return to product work once the required capability is established. A connectivity check alone
does not authorise starting new product work.

## 8. Keep the core portable; adapters stay thin

Split the team's instructions into two layers and keep them apart:

| Core — every client reads it | Adapter — one per client |
|---|---|
| roles and their write scope; the card contract (§ 5 fields, outcome line, acceptance matrix) | how to launch a background session and pass the role |
| the board, wiki, decisions and history carriers | how to list, read, attach to and stop sessions |
| authority tiers: standing decisions, owner-only actions, own configuration | peer messaging, if the client has it |
| commit policy by path; production and migration rules | context counters, hooks, reset rituals |

The core is short enough to be read on every start (a few pages, not a charter). An adapter may
be deleted without losing a single obligation; if deleting it loses one, that obligation belongs
in the core or in the card.

**The minimum that works on any CLI:** an `AGENTS.md`/`CLAUDE.md` with the core, the card, and one
launch line — «Continue as `<role>` on `<card>`» — started detached in the client's non-interactive
mode from the role's directory, with its output in a log outside git. The session reads the core
and the card, checks commits and dirty trees, works the card and writes the outcome. The coordinator
reads the outcome from the card; no live transport is required.

**Do not rebuild one client's runtime inside another.** Reproducing named sessions, peer delivery,
id-to-role registries and monitors on a client that lacks them is a separate infrastructure
project with its own failure modes. Signs it has started: a registry or daemon to rebind roles after
a reset, transport documents longer than the role files, setup cards outnumbering product cards.
Stop rule: when setup has consumed a product card's worth of effort without a delivered increment,
freeze it and run one real card through the minimum above; add an adapter only for a failure that
card actually hit.

## 9. Product before mechanics — measure it

A team process grows by accretion: every incident adds a rule, a ritual or a record, and each is
right on its own. Check the balance against the product on a schedule, from git, not by feel:

- **Records versus product.** Commits and changed lines in board/history/state/decision files
  against commits in product repositories over the same window. When the team's records outgrow
  the product code, the next improvement is removing process, not adding it.
- **Increments versus self-found defects.** Per release, how many items change something a user or
  operator can see, against defects and hardening the team found in its own code. Hardening is
  real work; a run of releases with no user-visible increment is a roadmap gap, and the technical
  lead owns proposing one.
- **Owner as message bus.** How often the owner relays, repeats or re-briefs. Each instance is a
  missing card field or decision record.
- **Always-read size.** The bytes every session loads before work (instructions, charter, skill
  core). Growth here is paid by every role on every start.

Each release plan names its product goal in user terms beside the defect queue. The team's own
mechanics are changed by a card like any other, with a measured reason, and the change that
removes a ritual is reviewed as carefully as the one that adds it.

