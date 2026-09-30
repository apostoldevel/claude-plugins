# Priorities and the execution plan of the board

Written by the coordinator on the owner's word, re-cut when the owner asks. Every open card stands in
exactly one group. The classification is by the card's title and finding — **not** a re-measurement:
the executor confirms each Critical card against the code.

## 1. Groups

| Group | Sign | What we do with it |
|---|---|---|
| **Critical** | a hole open **now** from outside or between tenants; money obtainable by deceit | into the next release; displaces any work but critical |
| **Urgent** | a deadline (contract, date); work in flight; finished work awaiting acceptance | closed before new Important |
| **Important** | a real defect: money, access, law, sessions, protocol conformance, rollout safety, disk | the executor's queue, by the release train |
| **Ordinary** | small damage, UX, debt, test hygiene | when the executor's first three groups are empty |
| **Unimportant** | cosmetics, notes, documentation, distant plans | on the way, or closed by a decision "we don't" |

## 2. Rules — so the day does not turn into chaos

1. **The executor's queue — § 4, top down.** The agent takes the next card of its own queue itself,
   without asking; it does not take a card out of queue, whoever sends it, except Critical.
2. **One card in `doing` per agent.** Only Critical interrupts it.
3. **Every day starts with acceptance** of `review`: acceptance is cheaper than new work and frees the
   release.
4. **A new finding gets its group when it is filed** — the coordinator sets it in the same move.
   Critical goes to the owner at once; the rest to the queue, not into work.
5. **The release train.** A release = the Critical + Urgent + Important closed at the cut; Ordinary
   rides only if already merged. Outside the train — only a critical patch.
6. **Questions to the owner — one list in § 6 of `STATE.md`, in group order**, not scattered across
   terminals.
7. **Economy mode** (near the end of a weekly allowance): until the reset — only Critical and Urgent.

## 3. Plan — waves

_Wave 0 — today; wave 1 — the next release; further waves by group._

## 4. Queues per executor

### <team>-db
1. T0xx — …

### <team>-backend
1. T0xx — …
