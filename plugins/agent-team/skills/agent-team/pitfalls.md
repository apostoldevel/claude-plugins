<!-- Reference of the /agent-team skill, read on demand via the table in SKILL.md. Moved verbatim from SKILL.md (Part IV) on 30.09.2026; later edits are listed in CHANGELOG.md. -->
# Verified pitfalls

Each of these was found by testing, not by reasoning. Test the barrier the same way: feed the hook
a tool-call JSON on stdin and check the exit code (`0` allow, `2` block).

```bash
t() { echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$2\"}}" \
      | env CLAUDE_PROJECT_DIR="$3" "$1" >/dev/null 2>&1; echo "exit=$? $2"; }
t <guard> /abs/path/inside/root/file.sql   <component-dir>   # want 0
t <guard> /abs/path/to/mirror/file.sql     <component-dir>   # want 2
t <guard> ../../other-generation/file.sql  <component-dir>   # want 2
```

The template ships its own acceptance, `templates/guard-write.test.sh`: a throwaway workspace, a
config pointing at it, every case fed as JSON.

**Barrier and hooks**

- **`*/.env.*` blocks `.env.example`.** The deny message usually tells the agent to edit that very
  file. Let `*.example|*.sample|*.template` fall through first.
- **A barrier that is not registered is not a barrier.** Two launch points inside an umbrella repo
  had their own `settings.json` without `PreToolUse`; their agents ran for weeks with no barrier,
  and the session logs showed zero calls. Check registration for every launch directory, not only
  the script.
- **`NotebookEdit` carries its path in `notebook_path`, not `file_path`.** A barrier reading
  `file_path` gets an empty string and exits 0 — the one tool nobody tested.
- **A `cd` defeats a check that looks for the path next to the verb.** `cd <mirror> && echo x > f`
  writes into the mirror with no mirror path after `>`. Treat a `cd` followed by a write as a write
  into the `cd` target, and normalise quotes and line continuations before matching.
- **In-place edit flags come in many spellings** — `sed -i`, `sed -i.bak`, `sed --in-place=…`,
  `perl -pi`: match the family, not one form. `git apply` and `patch` write too.
- **Relative paths defeat the barrier.** `root/../sibling/x` still contains the root string. Run
  `realpath -m` (works on non-existent paths) after making the path absolute.
- **The allow-scope must be the real root.** Allowing the whole workspace makes sibling
  generations — including a customer's live one — writable. Scope to the development root.
- **Hooks do not cross repository boundaries.** A barrier in the parent repo protects nobody in a
  component repo. This is the single most common way a barrier is silently absent for exactly the
  agents that write the code.
- **Bash cannot be guarded reliably.** A relative path inside a shell string is unresolvable; catch
  the obvious verbs and redirects, and rely on `git -C <submodule> status --short` at boundaries.
  Write this limitation into the barrier's header and the regulation, or the next reader will
  record "the barrier prevents it" and stop checking.
- **The Bash branch matches the mirror path anywhere in the command string — including inside
  text being written.** A heredoc that *mentioned* the mirror paths in prose was refused as a write
  to the mirror. Expected for a deny-list; know it before writing documentation through the shell,
  and phrase the mention so it does not match (`<workspace>/<mirror>`).
- **A mirrors regex without a trailing separator matches your own project.** A pattern for
  `<workspace>/apostol` also matches `<workspace>/apostol-crm`, so the barrier forbids writing
  into the very repo it protects. Anchor every alternative — `(a|b|c)/` — and, where the paths
  allow it, prefer a **positive allow** over enumerating what to block: an allow-list cannot be
  defeated by a name you did not foresee. Test against paths you did *not* think of; a first pass
  over the paths already in your head proves nothing — it checks the intent, not the behaviour.
- **Hooks are shell strings: an apostrophe in the text breaks them, and JSON looks fine.** A hook
  body wrapped in single quotes dies on `owner's` with a syntax error the file never shows. Keep
  the text in a file, and test every hook **by executing it**, not by reading the JSON:
  `bash -c "$(python3 -c "import json;print(json.load(open('.claude/settings.json'))['hooks']['PostCompact'][0]['hooks'][0]['command'])")"`
- **A `PostCompact` hook is where a day silently ends.** After a compaction the agent has the date
  and no memory of the evening, and it will create tomorrow's folder mid-day unless the hook says
  otherwise. Whatever the charter says about days, repeat it in the hook — that is the moment it
  is needed. And `PostCompact` fires only on compaction: a **restarted** session gets nothing
  unless `SessionStart` prints the same briefing.
- **A briefing identical for every layer delivers no layer.** `grep <agent>` over its output → 0.
  Branch on the launch directory.
- **Auto-loaded rule files may not reach component agents.** If `.claude/rules/*.md` lives in the
  parent repo, verify each component agent actually loads them; copy per component if not.
- **The history tree and the barrier can be silently `.gitignore`d in the component repos.** A
  component's `.gitignore` that excludes `/docs` or `.claude` wholesale eats `docs/history/` and
  `.claude/hooks/` — so "the days accumulate in git" quietly does not happen, and the barrier does
  not survive a clone. **Git does not descend into an excluded directory**, so a single
  `!docs/history/` will not rescue it: re-include the directory, re-exclude its contents, then open
  what you need. Verify with `git add -n <path>` and `git ls-files`, **not** with
  `git check-ignore` — the latter exits 0 both when a path is ignored and when a negation rule
  matched it.

**Roles, memory, trees**

- **A role that disappears leaves live instructions behind.** After merging or dropping a role,
  grep the whole harness for its name — a stale "ask X for framework fixes" norm outlives the
  agent X and quietly misroutes work.
- **A charter edit changes the context of its neighbours, not only its own place.** A rule moved
  from one agent to another was corrected in the roster table and left standing in two adjacent
  sentences; the contradiction lived three days, then reappeared in a layer `CLAUDE.md`, then in
  the root one — three passes, each finding one more site. After any change of ownership, grep the
  whole harness for the old assignment before calling it done.
- **Two agents launched from one directory share one memory store — and one history tree.** The
  store is bound to the launch directory, not to the agent name, so a framework specialist started
  from `backend/` writes into the backend agent's memory. Nothing warns you. Either give each its
  own directory, or make the sharing explicit: one state file and one diary per agent inside the
  day folder, and authorship recorded in each memory. **Record authorship in the frontmatter, not
  in the filename** — prefixing files with the agent's name breaks every `[[wikilink]]` silently;
  an `agent:` field and a per-agent section in the store's index keep the filenames valid.
- **The day-tree bootstraps twice.** Two agents sharing a tree both create `INDEX.md` and the
  `current` symlink. Say in the hand-off who creates the skeleton (the first one in), and let the
  second add only its own files.
- **The root `STATE.md` grows a tail of closed days.** Each closing appended a "day X closed"
  section; in a week 240 lines of chronicle sat in the file every agent reads first. Day summaries
  go into the day's folder; the root file carries only the current sections.

**Board and cards**

- **A WIP validator that counts cards instead of people** either blocks a legitimate two-agent card
  or lets three single-agent cards through. Test it on three cases before trusting it: overlapping
  assignees (must fail), disjoint assignees (must pass), and a multi-assignee card overlapping a
  single-assignee one (must fail).
- **An evidence validator that looks for a fenced block *anywhere* in the card** passes a long card
  with code in its findings and an empty Outcome. Three such cards sat in `review` for a week. Check
  the Outcome section.
- **A hand-edited generated table.** The coordinator added a row to `BOARD.md` by hand; `sync.sh
  --check` refused the commit. Right behaviour — edit the card, regenerate.
- **A card that reaches `review` without the card's own text moving.** Acceptance got written in
  the coordinator's diary and never into the card; for a day the coordinator counted done work as
  undone and gave a neighbouring project an understated assessment. The card is the carrier of the
  task's status; the diary is not.
- **`blocked_by: —` on a review queue.** Every card in `review` waits for *something*; if the field
  does not name it, the owner cannot see what he owes and the coordinator cannot group it.

**Instruments and claims**

- **An instruction that names a tool nobody verified is worse than none.** A coordinator wrote a
  plan around `git add -p`; the environment's interactive git flags are unusable, and the executor
  found out only after accepting the task. The reverse then also proved false — the flag *does*
  run with answers piped in, but without a TTY git does not split the diff into hunks at all, so
  one answer decides the whole file at exit code 0. Four claims, three wrong, none survived a
  measurement on material where the hypotheses actually differ.
- **A counting check where a naming check was needed** (Rule 11) raises false alarms and gets
  ignored; a pattern that covers one of three formats reports 28 gaps that are not there.
- **A number that is correct and answers a different question.** A count of access rows measured
  visibility that a runtime flag had switched off; a group membership count was read as rights; a
  measurement window from the 5th missed two rows from the 24th and the 5th of the month before.
  Before reporting a number, state the question it answers and check that it is the one asked.
- **A prediction about production is a claim about code until measured on production.** "Three of
  five volumes are bounded by the library's own rotation" — a 120 MB file at a 100 MB threshold
  with no rotated copies refuted it on the first look. Check predictions at closing, not the next
  morning.
- **Moving a wiki page breaks links in its neighbours, not in itself.** Relative links from a page
  written in the wrong directory and then relocated come out one segment short — and they do not
  fail, they point somewhere else. After any move, resolve links across **the whole wiki**.
- **A wiki page can be documented better than it is verified.** Writing a section forces agents to
  describe things they had assumed; some of those assumptions have never met the wire. Require the
  unverified marker in the page *and* at the source, because the people who touch the thing are not
  the people who read the page.
- **A layer's `CLAUDE.md` can describe fields that do not exist** — and a coordinator will build a
  card on them, because the file is read every session and reads as knowledge. Audit the always-read
  files against the code periodically; the audit itself is a card with a subagent per file.

**The owner's word**

- **"In your terminal" generalised from live servers to everything outward** sends the owner from
  terminal to terminal; it happened three times on one team (Rule 12). The hook text must scope it:
  live servers and own configuration only.
- **The coordinator advising a neighbouring project "do not start"** on the basis of its own
  understated assessment — decided for their owner. Send the measurement and the trap; the decision
  is theirs.
