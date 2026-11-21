<!-- Reference of the /agent-team skill, read on demand via the table in SKILL.md. Later edits are listed in CHANGELOG.md. -->
# The working day — regulation

A working day is the unit of the team's history: a folder per date with the day's `STATE.md` and a
diary per role, a `current` link, a line per day in `INDEX.md`. The day slices history; it does not
bound a session. Executors live one card each (SKILL.md § 1) and ignore the day except to write
into the right folder. Client events and reset behaviour come from the selected
[Claude](references/claude-code.md) or [Codex](references/codex.md) profile. References below to
old numbered rules refer to [the field guide](references/field-guide.md).

## Default: the calendar day

**The day is the system date.** The first session of a new date — normally the coordinator —
opens it and closes the previous one in the same step; nobody waits for a word:

1. Create `docs/history/<YYYY-MM-DD>/`, move `current` to it, start the day's `STATE.md`.
2. Close the previous date: its `STATE.md` final, its line in `INDEX.md`, durable facts moved out
   to the wiki or `docs/` (a day `STATE.md` is a shredder, not a store), root `STATE.md` sections
   updated.
3. Commit the history by path.

Any other session that finds no folder for today writes into today's folder only if the coordinator
has created it; otherwise it writes into `current` and says so in its card. Two sessions must not
both create the skeleton.

Work that crosses midnight stays in the card; the diary entry lands in the date it was written.
Nothing is closed, cleared or relaunched because the date changed.

## Option: the day opened and closed by the owner's word

For a team whose working day regularly crosses midnight and whose owner wants the day's history to
match the working session, the day can begin when the owner says *"open the day"* and end when
the owner says *"close it"* — relayed by the coordinator. Then midnight does nothing: a `current`
symlink that points at yesterday's date on today's clock is **an unclosed day, not a discrepancy**
— keep writing there. Choose this deliberately and write it into the project instructions; the
rest of this file describes it.

**One file says which day is open.** `docs/history/DAY`, written only by the coordinator, twice a
day:

```
day: 2026-09-11
status: open            # open | closed
opened: 2026-09-11, on the owner's word — with his caveat, verbatim, if he gave one
previous: 2026-09-09, closed 10.09 on the owner's word
# open, no folder of that name in your tree → create it, move current, write the day's STATE.md
# open, folder exists → keep writing there
# closed → do not open a new day; wait for the word
```

Deliver the open DAY through the client's supported startup/recovery briefing, with explicit
reading as fallback. Verify delivery rather than assuming identical hook events or automatic
identity recovery. Keep it short because it is read repeatedly.

**Three prohibitions:** no new day by the calendar; no moving `current` without the word (the one
exception: no tree at all — first launch); no closing the day yourself.

**`DAY` carries the date of the word**, not of the clock, and a day the owner did not open gets no
folder — a gap between two dates is not a missing day.

**Opening the day means handing the opening to each agent.** A note in `DAY` is not an opening.
Check by command, not by memory:

```bash
for d in . backend db frontend ocpp brands; do
  echo "$d -> $(readlink $d/docs/history/current 2>/dev/null || echo 'no tree')"
done
```

The first time this ran on a live team, three of six trees were on the previous day. **A lagging
`current` is not the agent's violation; it is the sign that no hand-off happened** — the agents
were right not to create a folder themselves. Who gets the message: **whoever is running and
continues work in the same context**. An executor launched later gets `DAY` from its briefing hook
at launch; an interactive session that was cleared gets it the same way **and** a brief from the
coordinator — the hook is not guaranteed. The coordinator records in the day's `STATE.md` who
received the opening live and who will get it from the hook. Messaging an idle agent for anything
else costs a full-context turn and buys nothing (Rule 10 of the field guide).

**Closing the day — the seven-step protocol, sent to each agent, answered by each.** *Closing is
not "drop everything now"; it is a planned stop without loss, so that tomorrow continues from a
compacted or cleared context without re-deriving anything.*

1. Bring the work to a point somebody can continue from — not "the whole card", **a state**.
2. Commit what is done. Review should have happened earlier, right after the work.
3. **Do not start a code review at closing** — it becomes a background process everybody must
   wait for, and the closing stretches for work nobody planned.
4. If review is deferred, record that obligation and preserve the work using the project's
   permitted checkpoint procedure. Do not bypass a mandatory pre-commit review. Context reset
   does not itself delete files, but unrecorded intent and unowned dirty work are hard to recover.
5. Write the day's `STATE.md`, then the diary. In that order.
6. A background process running (build, tests, a long query) — tell the coordinator, wait for it,
   then close. Never report ready over a running process, never kill it to report sooner.
7. Answer in the readiness form — an interactive session: one line to the coordinator — *"ready for compaction or
   clear, context N, commit <sha>"* — and **`Ready for compaction or clear`** as the last line in
   the terminal; a background executor: the outcome line in its card (`checkpoint` if the card is
   not finished), then it ends. It means: tree clean, work committed, state written, nothing in this context that
   is not on disk. Use the project's exact readiness phrase; identify any explicitly deferred
   review or preserved dirty work instead of claiming a clean tree. Before it, check the branches
   of your layer — `git branch`, `git worktree list`,
   `git submodule status`: nothing is left that no card names, and nobody tidies up after another
   agent.

The coordinator starts nothing of its own until all have answered, then: day `STATE.md` → diary →
history `INDEX.md` → root `STATE.md` (sections into sections) → the mirror of the board to the
owner's external board, if there is one (git → board) → `DAY: closed` → commit of its own layer by
path. Then it tells the owner what closed, what each agent's closing caught, and what
waits for the owner's decision — and names the terminals where `/clear` is now safe (all that
answered).

**Check the summaries by naming, not by counting.** Each tree's `INDEX.md` needs a line per day;
the check must *name* the missing day, not shout a number:

```bash
for r in . backend db frontend ocpp brands; do
  for d in $r/docs/history/2026-*; do n=$(basename "$d")
    grep -qE "^(## |- )\[?$n" "$r/docs/history/INDEX.md" 2>/dev/null || echo "$r: no line for $n"
  done
done
```

A counting form (`ls | wc -l` against `grep -c`) cannot tell "forgot the line" from "the day is
still open" and raises a false alarm at every opening; an instrument that cries without cause
stops being heard. And the pattern must cover every summary format the agents actually use
(`## <date>`, `- [<date>](…)`, `## [<date>](…)`): the first version matched one of three and
reported 28 false gaps an hour after the same trap had been written into the wiki. Run this
**last**, after every agent has answered — one tree still lacked its line after the coordinator
had declared the day closed.

**Each closing catches something.** On the first full run: a prediction an agent had made about
production was checked before closing rather than the next morning, and it was wrong; an unpushed
commit that a card called "done"; a pin three layers out of step. That is the protocol's return,
and it is why the seven steps are not shortened when everyone "already compacted".

**Fixing the state without closing** — before a compaction in the middle of a day, on the owner's
*"fix the state"* — is the same protocol in the same order, without the root `STATE.md` and without
touching `DAY`.

Make both halves executable: a `close-day` and an `open-day` skill for the coordinator, each a
checklist over the regulation, each stating in its first line that **the trigger is the owner's
word in the coordinator's terminal** — the skill opens nothing by itself.
