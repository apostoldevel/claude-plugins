<!-- Reference of the /agent-team skill, read on demand via the table in SKILL.md; numbered rules are those of the field guide. -->
# The harness — hooks, their config, their tests

**Claude Code examples only.** Read [the Claude profile](references/claude-code.md) before
installing these templates. They preserve the original working setup, not a universal schema
or current-version guarantee. For Codex use [its separate profile](references/codex.md) and
the project's `.codex` runtime. Do not install these `.claude` settings into Codex. Existing
working hooks need no rewrite merely because the shared skill now supports both clients.
References to numbered rules below refer to [the historical field guide](references/field-guide.md).
Review output rewriting and approval effects before adopting `filter-output.sh`; it is optional.

The templates in `templates/` are what a live team runs, stripped of that team's names. They are
**not** installed as plugin hooks: a barrier differs per component and per role, so the project
copies them and configures them.

## Files and where they go

| Template | Event | Lives in | What it does |
|---|---|---|---|
| `team.conf` | — | coordinator's `.claude/hooks/` | **the one place for the team's facts**: team prefix, workspace, project root, launch directory → role, per-role allow/deny, mirrors, secrets, temporary exceptions, lifecycle log, context thresholds, the ready phrase, what the briefing says per role |
| `guard-write.sh` | `PreToolUse` `Edit\|Write\|NotebookEdit\|Bash` | coordinator **and every component** | per-role write barrier (Rule 9) |
| `guard-write.test.sh` | — | next to each barrier | its acceptance: a throwaway workspace, every case as JSON, exit codes checked; with `settings.json` paths as arguments it also checks registration |
| `session-start.sh` + `briefing.txt` | `SessionStart`, `PostCompact` | coordinator | the briefing by launch directory — who you are, what is yours and what is not, the reading order, the context rule, the open `DAY`; appends `HH:MM <agent> clear\|compact` to the lifecycle log |
| `context-guard.sh` | `UserPromptSubmit`, `PostToolUse`, `Stop` | coordinator | reads the context size from the transcript's last `usage` record (reset after `compact_boundary`); above `CONTEXT_SOFT` puts the rules and the number into the context, every `CONTEXT_STEP` while working; on `Stop` holds the turn if `READY_PHRASE` is declared but is not the last line — in a background session, adapt it to check the outcome line instead (below) |
| `filter-output.sh` | `PreToolUse` `Bash` | coordinator | rewrites test runs, builds and listed scripts to failures + the summary line; keeps the exit code; first line `[filter] …`; `# nofilter` switches it off for one call |
| `settings.coordinator.json` | — | `<root>/.claude/settings.json` | registers everything from the root's own `.claude/hooks/` |
| `settings.layer.json` | — | `<component>/.claude/settings.json` | registers the layer's own barrier and finds the shared hooks by walking **up** the tree |
| `card.md`, `PRIORITIES.md`, `DAY` | — | `docs/board/cards/_TEMPLATE.md`, `docs/board/`, `docs/history/` | the board and the day (Rules 5, 7, 11) |

Each script looks for `team.conf` in `$TEAM_CONF`, then next to itself, then walking up from its
own directory — so a layer's barrier copy finds the coordinator's file. **A barrier that cannot find
its config refuses every write.**

## Installing, in order

1. Copy the templates into `<root>/.claude/hooks/`, `chmod +x *.sh`, fill `team.conf` —
   `ROLE_MAP` first: every directory an agent starts from, and nothing else.
2. For every component that is its own repository: copy `guard-write.sh` and
   `guard-write.test.sh` into `<component>/.claude/hooks/`, and `settings.layer.json` into
   `<component>/.claude/settings.json`.
3. For every launch point **inside** the umbrella repo (`tests/`, `audit/`, `brands/`…): give it its
   own `.claude/settings.json` from `settings.layer.json` — without it that agent runs with no
   barrier at all.
4. Root: `settings.coordinator.json` → `<root>/.claude/settings.json`.
5. Test, and keep the output in the card:

```bash
bash .claude/hooks/guard-write.test.sh $(ls -d */.claude/settings.json .claude/settings.json)
echo '{"hook_event_name":"SessionStart","source":"startup"}' \
  | CLAUDE_PROJECT_DIR="$PWD/db" bash .claude/hooks/session-start.sh | grep -c "<team>-db"
```

   The first line runs every case and checks that each listed `settings.json` registers the
   barrier. The second must print a non-zero count from every launch directory: a briefing that
   does not name its agent delivers nothing (`pitfalls.md`).
6. Launch one executor in the background from each role directory and check that its briefing
   named the role and that the guard fired (`claude logs <role>`). A lifecycle-log monitor is
   optional: it watches clears of the interactive sessions; executors are watched with
   `claude agents`.

## Background sessions: the outcome check

Hooks registered for a launch directory fire in background sessions too (observed), so the same
files serve both kinds of session. Two things differ for an executor:

- **The context rule's last step.** "Record the state and stop" is the outcome `checkpoint`
  written into the card, then the end of the reply — not the readiness line and not a message
  asking to be cleared. The guard's text must say so for a background session.
- **The `Stop` check.** Instead of "the readiness phrase, if declared, is the last line", check
  "the card named in the launch line ends its work log with `Outcome: review|blocked|checkpoint|failed`
  before the session ends". Hold the turn once (`stop_hook_active` guards the retry) with a reason
  that names the card and the four outcomes.

**Telling the two apart.** Do not guess from the transcript. Pass a marker at launch and read it in
the hook:

```bash
# launch (Claude Code): a variable from the launching shell does NOT reach a --bg session;
# pass it through settings
claude --bg -n <role> --settings '{"env":{"TEAM_RUN":"background","TEAM_CARD":"<card>"}}' \
  "Continue as <role> on <card>"
```

```python
# in context-guard.sh, Stop branch
if os.environ.get("TEAM_RUN") == "background":
    card = os.environ.get("TEAM_CARD", "")
    # find the card file, take the last non-empty line of its work-log section,
    # allow if it matches r"^Outcome: (review|blocked|checkpoint|failed) — ", else block once
```

Measured on Claude Code 2.1.330 (check again after an upgrade): a variable set in the launching
shell is absent in a `--bg` session, one passed through `--settings '{"env":{…}}'` is present.
`ROLE=… claude --bg …` therefore silently starts the directory's default role, and without the
marker the guard demands the interactive readiness line. The client itself sets
`CLAUDE_CODE_SESSION_ATTENDED=0` in a `--bg` session, while `CLAUDE_CODE_ENTRYPOINT` is `cli` in
both kinds — a transcript's `entrypoint` does not tell them apart. Client markers are
version-specific; prefer the team's own variable. Test both branches: feed the hook a `Stop`
payload with and without the marker, against a card with and without the outcome line, and check
the decision.

## Changing the harness

- The barrier, `settings.json` and `CLAUDE.md` are **the agent's own configuration**: changed only
  on the owner's word in that agent's terminal (Rule 12). The coordinator prepares the text.
- Every change to `guard-write.sh` goes with a new case in `guard-write.test.sh` — first red on the
  old barrier, then green on the new one. A case you did not see fail proves nothing.
- A temporary exception goes into `TEMP_ALLOW` with its removal condition on the line above, and
  into the card that needs it.
- Hook text lives in files. A hook written as a quoted JSON string dies on the first apostrophe,
  and the JSON still looks fine.

## What the barrier does not do

- **Bash is best effort.** A relative path inside a shell string (`../other-app/x`) cannot be
  resolved. The Bash branch refuses the known forms: destructive verbs, in-place flags, `cd` and
  then a write, redirects, `git apply`/`patch`, writes into other projects of the workspace.
  Mechanism plus agreement, never "the barrier prevents it".
- **Outside the workspace it checks nothing** except the scratchpad and memory allowances.
- **It is not a guard against a determined agent**, only a router for an honest one. The real
  check at boundaries is `git -C <component> status --short`.
