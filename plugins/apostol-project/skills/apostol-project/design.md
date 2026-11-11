<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## The design, and this implementation of it

This skill describes **one implementation** of the Apostol platform — the PostgreSQL one (db-platform
1.2.x + libapostol). The design itself is older than PostgreSQL here (its first execution environment
was Oracle, 2010–2019) and is written down separately, environment-free, in three design notes (not published; the
list and the table below are their summary):

- `platform-concept.md` — the design: objects in a class
  tree, lifecycle as data, one universal executor, context “who / as whom / where / which workplace /
  which operating date”, three-dimensional access, a trace of every action with delivery, atomic action.
- `design-vs-implementation.md` — what stayed identical across Oracle and PostgreSQL (= the design) and
  what each environment dictated (= implementation).
- `kernel-notes.md` — the 17 places where this implementation strains against the design.

**Three boundaries fixed by the platform's author — do not re-argue them in project work:**

| First-generation slogan | Design (keep) | Implementation (this skill) |
|---|---|---|
| “One request — one transaction” | the **action** is atomic: object, state, history, trace, money in one commit | the unit of atomicity is the whole HTTP request, batch arrays included, session check included |
| “The database is an active participant” | the **system** initiates outbound work from its own data | the initiator is PostgreSQL itself: triggers → `pg_notify` → a C++ process with a polling fallback |
| “Behaviour as data, changed at runtime” | **the automaton and the rights are data** (states, methods, transitions, ACU/AMU, routes, registry) | reaction code is `EXECUTE`d text in `db.event.text`; in the design reaction code may be code bound to (class, action) by reference |

Why this matters for configuration work: when a platform construct fights you (a right you cannot
express, a state that does not change, a filter that silently disappears), check the design first.
If the design requires it and the implementation lacks it, that is framework work (`/apostol`), not
a reason to bend the configuration. If the design does not require it, you are free.
