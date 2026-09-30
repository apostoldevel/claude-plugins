---
id: T000
title: Short name of the task
status: queued          # queued | doing | blocked | review | done
assignee: —             # a list: <team>-db, <team>-backend
evidence: command       # command | artefact — how acceptance will be shown
source: —               # where the task came from: docs/plans/…, STATE.md §…, the owner's word with its date
blocked_by: —           # what exactly is awaited: T0xx, an agent, a decision of the owner
opened: YYYY-MM-DD
# owner_word: DECISIONS.md:NNNN   # optional: the record this card executes
---

# T000 · Short name of the task

## Task

What to do and why. If it came from a plan, one line with the link — not a retelling.

## Done when

A checkable criterion.

- `evidence: command` — a concrete command from the layer's `CLAUDE.md` test table. Not "looks done".
- `evidence: artefact` — a named artefact: a filed application, a published page, a signed document,
  a tag in `origin` — for lines of work where no command exists.

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

## Outcome

What was done, commits (`repository sha`) and **the output of the evidence command** in a fenced
block — or the named artefact for `evidence: artefact`. Without it the validator refuses `review`.
