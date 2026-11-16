# Profile for any other execution-capable CLI

Use this profile for a client that reads project instructions and runs commands but offers no
peer messaging, no session registry or no hooks you can rely on — or when you do not yet know
what it offers. It is the core of SKILL.md § 8 with nothing added; the Claude Code and Codex
profiles are this plus their own accelerators.

## What the session needs

1. **Instructions.** The client's own discovery file (`AGENTS.md`, `CLAUDE.md`, or the file the
   client documents) holding the core: roles and write scope, the card contract, the gates, the
   commit policy, production rules. If the client does not discover it, the launch line names it.
2. **A role by explicit assignment.** «Continue as `<role>` on `T<nnn>`» — said by the owner or
   given by the coordinator. Never infer the role from a shared directory or from the most recent
   session; two roles may share one directory.
3. **The card.** Goal, numbered criteria, allowed paths, the handoff fields of SKILL.md § 5. The
   session reads it, checks the commits and dirty trees it names, and continues from the stated
   point. If the card does not say where to continue, that is the first finding — fix the card.

## Transport

None is required. The coordinator routes by cards and card ids; a finished card is reported by its
status, Outcome and acceptance matrix, which anyone can read from git. Where a reply is genuinely
needed between sessions, a file mailbox works on every client:

- an ignored directory (one per project), one file per message: sender role, card, text;
- the recipient reads it at a checkpoint (start, before handing off, before review) and moves the
  file to a read folder;
- a message is a request, never the owner's approval, and never the only carrier of a task fact.

Do not build a daemon, a queue or a role registry for such a client before one real card has run
without it and hit a failure that the file mailbox could not handle.

## Context and reset

Use what the client itself reports about context occupancy; unknown is unknown, not zero. Persist
the handoff in the card before any reset, then start a fresh session with the launch line. A reset
or compaction ritual from another client (its wording, its hook, its thresholds) is not carried
over; the project's own readiness rule applies only where the project has stated it for this client.

## Write scope

Use the client's sandbox and approval modes as the primary barrier. Where hooks exist, adapt the
write barrier to that client's event schema (see `hooks.md` only as an example). Where they do not,
compare trees at every handoff — `git status` in each repository the card names — and stage by path.

## Acceptance of the setup

The setup is accepted when one real card has gone through implementation, independent review and
acceptance on this client without the owner carrying messages by hand. State which levels were
actually observed: instructions discovered, role taken from the launch line, card resumed after a
reset, review by a separate session. A profile that was only written, not run, says so.
