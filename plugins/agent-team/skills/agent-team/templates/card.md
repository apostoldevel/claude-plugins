---
id: T000
title: Short name of the task
status: queued          # queued | doing | blocked | review | done
assignee: —             # a list: <team>-db, <team>-backend
evidence: command       # command | artefact — how acceptance will be shown
# effort: high          # optional: raises the executor's effort above the role's default in the launch table
source: —               # where the task came from: docs/plans/…, STATE.md §…, the owner's word with its date
blocked_by: —           # what exactly is awaited: T0xx, an agent, a decision of the owner
opened: YYYY-MM-DD
# owner_word: DECISIONS.md:NNNN   # optional: the record this card executes
---

# T000 · Short name of the task

## Task

What to do and why. If it came from a plan, one line with the link — not a retelling.

**Who gains what.** The user, operator or contract that is better off when this is done — one line.
An internal card names the product outcome it protects; "the team's process" is not an outcome.

## Done when

Numbered, checkable criteria — each one verified on its own at review (C1, C2, …).

- `evidence: command` — a concrete command from the layer's verification instructions (`CLAUDE.md`
  or `AGENTS.md`, as applicable). Not "looks done".
- `evidence: artefact` — a named artefact: a filed application, a published page, a signed document,
  a tag in `origin` — for lines of work where no command exists.

## Stage and handoff

Use this section at a stage boundary or context replacement; keep the existing project's card
schema when adopting this template into an established board.

- Current stage and responsible role:
- Allowed paths and relevant contracts/owner decisions:
- Completed changes: repository + commit; local/pushed:
- Dirty files and their owners:
- Checks and results; omitted checks and reasons:
- Open findings, dependencies, blockers and decisions needed:
- Next role and exact continuation point:

## Boundaries

What this card does **not** include, and why. Half of all scope creep is caught here.

## Questions to the owner

_Only if there is a question. Each one reads without the rest of the card._

### Q1 · <the question in one line> — open

**Situation.** What happens and why the owner's answer is needed; `file:line`.

**Options.**
- **A (recommended)** — what follows, its price, who executes.
- **B** — what follows, its price, who executes.

**Recommendation.** A, because …

_Once answered: heading → "— decided :NNNN", and one line "Answer: …" below. Answered questions stay._

## Work log

_Decisions and traps as the work goes — the history of the process, the reason the card lives in git._

- YYYY-MM-DD (agent): what was decided and why. Links: `T0xx`, `docs/plans/…`.
- YYYY-MM-DD (agent): continuation point — where the next session starts, in one line.

Outcome: review — C1–C3 pass locally, evidence in Outcome

_A background executor ends every run with that line as the **last line of the work log**, after
the continuation point, then ends its reply. One of four: `review` (criteria met, evidence below),
`blocked` (a decision or dependency is missing; the question is in "Questions to the owner"),
`checkpoint` (context threshold reached; the state is recorded, relaunch the same line), `failed`
(the run broke; the log locator follows). The coordinator acts on it and reports one status line
to the owner. An interactive session may use the same line._

## Outcome

What was done, commits (`repository sha`) and **the output of the evidence command** in a fenced
block — or the named artefact for `evidence: artefact`. Without it the validator refuses `review`.

**Acceptance** — filled by the reviewer, not the author:

| Criterion | Result | Evidence |
|---|---|---|
| C1 | pass / fail / not verified | command output, `file:line`, artefact |

`not verified` is not `pass`. The card moves to `done` only when every criterion is `pass`; a check
that could not run is listed with its reason and risk, never folded into a general "looks good".
