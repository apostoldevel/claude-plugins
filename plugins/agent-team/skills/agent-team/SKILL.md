---
name: agent-team
description: Organise phased product development across specialised agent roles in Claude Code, Codex or any execution-capable agent CLI. Use for responsibilities, task handoffs, evidence-gated acceptance and recovery across sessions; when a team process has outgrown its product (more records than delivered increments); when moving a team set up on one CLI to another; select the matching CLI profile for runtime setup.
---

# Agent team — product delivery with specialised roles

The goal is working, verified product increments. Team tooling serves that goal. Preserve the
existing specification, board, decisions and release process before adding infrastructure.
Measure success by accepted product outcomes, resolved blockers and the owner's coordination
effort, rather than agent count, message traffic or session longevity.

**The portable unit of a team is the card, not the session.** A card that carries its goal,
criteria, scope and continuation lets any fresh session of any CLI take the role and continue.
Long-lived named sessions, peer messaging, monitors and context guards are accelerators of one
client — useful where they exist, never what the process stands on (§ 8). Section 9 says how to
tell when the team's mechanics have started to cost more than the product receives.

After loading, announce: **"Agent team context loaded."**

## Read only what the task needs

| Need | Read |
|---|---|
| Claude Code discovery, hooks, messaging and recovery | [references/claude-code.md](references/claude-code.md) |
| Codex discovery, hooks, messaging and recovery | [references/codex.md](references/codex.md) |
| Any other CLI, or a client without peer messaging | [references/other-clients.md](references/other-clients.md) |
| Owner-controlled working day | [day.md](day.md), with the selected CLI profile |
| Original Claude hook installation and shell templates | [hooks.md](hooks.md), then the Claude profile |
| A known failure or write-barrier trap | [pitfalls.md](pitfalls.md) |
| Apostol project/framework ownership | [apostol.md](apostol.md), subject to the actual project roster |
| Rationale, knowledge layout and detailed review examples | Relevant section of [references/field-guide.md](references/field-guide.md) |

The field guide preserves experience; it is not mandatory startup reading. Templates include
shared card/day examples and Claude-specific runtime examples. Do not install either CLI's
configuration into the other. Project instructions and owner decisions determine permissions;
this skill grants no new authority.

## 1. Choose the working relationship, then the runtime

Use the owner's stated preference. Ask only if unknown: does the owner work alongside a visible
team, delegate bounded stages, or want unattended execution? These are levels of autonomy, not
rankings of CLI quality. Do not turn a request for colleagues into an autonomous fleet.

A **role** is a stable responsibility with allowed scope and accountable output. A **session**
is a replaceable context. A **task/stage** is an authorised unit of work. A **transport address**
identifies a current recipient. Neither a UUID nor a display name is task state.

Long-lived foreground experts help when the owner interacts directly or a related series
benefits from accumulated context. Fresh bounded sessions/subagents help with isolated work
and independent review. Choose by dependencies, startup cost, context load and owner preference.
Neither session-per-day nor session-per-card is universal. Preserve requested visibility and
interruption; fresh sessions need not be headless. Do not launch idle roles to fill a roster.

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

Use only roles needed for the stage. Peers can discuss interface seams directly, recording the
result in the card/decision record. The coordinator holds the common course without relaying
every sentence. Do not invent new roles, product tasks or permissions.

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

Limit work in progress by shared executors and overlapping writes. Check trees before edits;
preserve others' dirty work. Stage explicit paths under the project's commit policy. Use separate
branches/worktrees when concurrent writes justify them, not one per role by default. Account for
all repositories and dependency pins in multi-repository projects.

## 5. Make handoffs sufficient to resume

Persist these fields in the existing card or linked stage record before handing off or replacing
a context. Prefer references over copying the whole project:

1. Goal, current stage and checkable acceptance criteria.
2. Allowed paths, relevant contracts and consequential owner decisions.
3. Changes and `repository + commit`, including local/pushed state.
4. Relevant dirty files and their owners.
5. Checks run with results; checks not run and why.
6. Open findings, dependencies, blockers and questions needing a decision.
7. Next responsible role and exact continuation point.

Completion messages are short: card, result, evidence locator and next action. Avoid duplicate
ACK loops, roster pings and repeated reports without new state.
Independent review needs a separate reviewer/context and enough raw evidence to check the result;
relabelling the author's own answer is not independent review.

## 6. Recover work rather than preserve every chat

Before context replacement, persist the handoff. Afterwards bind the explicitly assigned role to
the actual new session, reload relevant instructions and the handoff, check commits/dirty trees,
and continue the authorised step. Notify the coordinator when routing or blockers change.
The CLI profile defines what is automatic and what needs explicit bootstrap.

Do not make repeated compaction the only recovery strategy or promise identical clear behaviour.
Never clear/compact a peer automatically. Respect owner-controlled day boundaries where used;
a new chat or midnight does not open a day.

Load the needed role/skill, exact card sections and relevant source only. Bound tool output while
preserving failures, summaries and exit status. Distinguish capacity, current context occupancy,
lifetime token usage and account limits; unknown is not zero. Thresholds and cost claims depend
on the actual model, client and plan, not historical fixed numbers.

## 7. Adopt the smallest useful runtime

Reuse available CLI capabilities before adding a launcher, queue, database, daemon or orchestrator.
Keep common process separate from client adapters. Preserve the other CLI's configuration and
ongoing work unless the owner explicitly authorises changing it.

Tool-managed workflow frameworks contribute useful stage contracts, evidence-driven transitions,
independent quality and durable handoffs (§ 4). Apply these principles to existing cards without
automatically adopting their managed storage, role names or approval system. Full adoption requires an explicit migration
and one agreed source of truth. An external orchestrator is an option, not a prerequisite.

Accept setup through a bounded, authorised product stage: can assigned roles deliver, verify and
hand off a real increment without losing decisions or making the owner carry messages?
Config parsing, hook fixtures, native startup, message replies and recovery are different evidence
levels; state which passed. Return to product work once the required capability is established.
Keep convenience improvements as explicit limitations instead of an endless setup programme.
A connectivity check alone does not authorise starting new product work.

## 8. Keep the core portable; adapters stay thin

Split the team's instructions into two layers and keep them apart:

| Core — every client reads it | Adapter — one per client |
|---|---|
| roles and their write scope; the card contract (§ 5 fields, criteria, acceptance matrix) | how a session learns its role (launcher variable, explicit line, hook) |
| the board, wiki, decisions and history carriers | peer messaging, if the client has it |
| gates: owner decisions, review independence, irreversible actions, push/tag/deploy | monitors, lifecycle events, context counters |
| commit policy by path; production and migration rules | reset/compaction rituals and their wording |

The core is short enough to be read on every start (a few pages, not a charter). An adapter may
be deleted without losing a single obligation; if deleting it loses one, that obligation belongs
in the core or in the card.

**The minimum that works on any CLI:** an `AGENTS.md`/`CLAUDE.md` with the core, the card, and one
launch line — «Continue as `<role>` on `T<nnn>`». The session reads the core and the card, checks
commits and dirty trees, and works the card. The coordinator (or the owner) hands over the card id;
no live transport is required. A file mailbox in an ignored directory, read at checkpoints, is an
optional adapter for clients without messaging.

**Do not rebuild one client's runtime inside another.** Reproducing named sessions, peer delivery,
UUID-to-role registries and monitors on a client that lacks them is a separate infrastructure
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

