#!/usr/bin/env bash
#
# guard-write.test.sh -- acceptance test for guard-write.sh. Self-contained: builds a throwaway
# workspace under mktemp -d, writes its own team.conf, feeds tool-call JSON to the barrier on
# stdin and checks the exit code (0 = allow, 2 = block). Touches nothing outside the temp dir.
#
#   bash guard-write.test.sh                        # tests the guard.sh next to this file
#   GUARD=/path/to/guard-write.sh bash guard-write.test.sh
#   bash guard-write.test.sh <.claude/settings.json>...   # also checks that the file REGISTERS
#                                                         # the barrier (a barrier nobody calls
#                                                         # protects nobody -- found the hard way)
#
# Case line: t <launch dir under the project | - = the root | absolute> <tool> <expected rc> <arg>
# The whole list runs twice: once with the workspace under $HOME and commands written `~/work/x`,
# once with the workspace OUTSIDE $HOME and commands written with absolute paths.

set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
GUARD=${GUARD:-$HERE/guard-write.sh}
[ -f "$GUARD" ] || { echo "guard not found: $GUARD"; exit 1; }
command -v jq >/dev/null || { echo "jq is required"; exit 1; }

T=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$T"' EXIT
WS=$T/work            # the workspace: the project, its neighbours, the framework mirrors
PR=$WS/kit-app        # the project root ("kit" below is a mirror whose name prefixes the project's)
pass=0; fail=0

# ---- the throwaway workspace ---------------------------------------------------------------
mkdir -p "$PR"/{.claude/hooks,docs/wiki/audit,docs/wiki/db,docs/board/cards,docs/history,audit,ops/x/.secrets,tests,db/.claude/hooks,db/sql,backend/src,frontend,misc}
mkdir -p "$WS"/{kit,kit.v2,shared/platform,other-app/docs,other-app/src,third-app,tools} "$T/elsewhere" "$T/home" "$T/scratch"
: > "$WS/release.tgz.note"
ln -s ../backend "$PR/db/link-out"     # a symlink out of the layer
ln -s sql "$PR/db/link-in"             # a symlink inside it
cp "$GUARD" "$PR/.claude/hooks/guard-write.sh"
cp "$GUARD" "$PR/db/.claude/hooks/guard-write.sh"     # a layer keeps only its own barrier copy

cat > "$PR/.claude/hooks/team.conf" <<EOF
TEAM="acme"
WORKSPACE_DIR="$WS"
PROJECT_ROOT="$PR"
WORKSPACE_ALIASES=""
ROLE_MAP='
.=owner
ops=devops
tests=qa
audit=audit
db=db
backend=backend|framework
'
DENY_owner="backend/* db/* frontend/* tests/*"
ALLOW_audit="audit/* docs/wiki/audit/* docs/board/cards/*"
ALLOW_db="db/* docs/wiki/db/* docs/board/cards/*"
ALLOW_backend="backend/* docs/board/cards/*"
MIRRORS="kit kit.v2 shared/platform"
SECRET_GLOBS="*/.secrets/* */.pgpass */passwords.psql */license.json */.env.production"
SECRET_TEMPLATE_GLOBS="*.example *.sample *.template"
TEMP_ALLOW='
# REMOVE WHEN: this test ends
owner $WS/other-app/docs/*
* $T/shared-notes/*
'
SCRATCHPAD_ROLES="audit"
SCRATCHPAD_BASE="$T/scratch"
EOF

# ---- runner --------------------------------------------------------------------------------
HOME_MODE=inside
run() {  # run <launch dir> <hook> <json>  -> sets rc, out
  local h=$T/home
  [ "$HOME_MODE" = inside ] && h=$T
  out=$(env -u TEAM_CONF -u CLAUDE_PROJECT_DIR CLAUDE_PROJECT_DIR="$1" HOME="$h" bash "$2" <<<"$3" 2>&1 >/dev/null); rc=$?
}
hook_for() {  # the layer's own copy if the launch dir has one, else the coordinator's
  if [ -f "$1/.claude/hooks/guard-write.sh" ]; then echo "$1/.claude/hooks/guard-write.sh"; else echo "$PR/.claude/hooks/guard-write.sh"; fi
}
ok() {  # ok <expected> <label>
  if [ "$rc" = "$1" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL rc=$rc exp=$1 [$HOME_MODE] $2"; echo "     $out" | head -2; fi
}
t() {  # t <launch> <tool> <expected rc> <arg>
  local l=$1 tool=$2 exp=$3 arg=$4 d j
  case "$l" in -) d=$PR ;; /*) d=$l ;; *) d=$PR/$l ;; esac
  case "$tool" in
    Bash)         j=$(jq -nc --arg c "$arg" '{tool_name:"Bash",tool_input:{command:$c}}') ;;
    NotebookEdit) j=$(jq -nc --arg p "$arg" '{tool_name:"NotebookEdit",tool_input:{notebook_path:$p,new_source:"x"}}') ;;
    *)            j=$(jq -nc --arg t "$tool" --arg p "$arg" '{tool_name:$t,tool_input:{file_path:$p}}') ;;
  esac
  run "$d" "$(hook_for "$d")" "$j"
  ok "$exp" "[$l] $tool ${arg//$'\n'/\\n}"
}
tj() {  # tj <launch> <expected rc> <raw json>
  local d=$PR; [ "$1" != - ] && d=$PR/$1
  run "$d" "$(hook_for "$d")" "$3"
  ok "$2" "[$1] raw $3"
}

suite() {
  local P=$1   # how the workspace is spelled inside commands
  local slug_a slug_o
  slug_a=$(printf '%s' "$PR/audit" | sed 's#[/._]#-#g')
  slug_o=$(printf '%s' "$PR" | sed 's#[/._]#-#g')

  # -- Edit/Write inside the project: the role decides
  t -      Write 0 "$PR/docs/x.md"
  t -      Edit  0 "$PR/docs/x.md"
  t -      Write 2 "$PR/backend/x.cpp"                 # the coordinator writes no code
  t -      Write 2 "$PR/db/sql/x.sql"
  t -      Write 2 "$PR/tests/test_x.py"
  t audit  Write 0 "$PR/audit/x.md"
  t audit  Write 0 "$PR/docs/wiki/audit/c.md"
  t audit  Write 0 "$PR/docs/board/cards/C1-x.md"
  t audit  Write 2 "$PR/docs/STATE.md"                # the auditor is narrowed to an allow-list
  t audit  Write 2 "$PR/backend/x.cpp"
  t ops    Write 0 "$PR/ops/deploy.sh"
  t ops    Write 0 "$PR/docs/x.md"                    # a role with no ALLOW/DENY is open in the root
  t tests  Write 0 "$PR/tests/test_x.py"
  t tests  Write 0 "$PR/docs/x.md"
  t db     Write 0 "$PR/db/sql/x.sql"                 # layer copy of the barrier (walks up to team.conf)
  t db     Write 0 "$PR/docs/wiki/db/x.md"
  t db     Write 0 "$PR/docs/board/cards/C1-x.md"
  t db     Write 2 "$PR/backend/x.cpp"
  t db     Write 2 "$PR/docs/STATE.md"
  t db     Write 2 "$PR/ops/deploy.sh"
  t backend Write 0 "$PR/backend/src/x.cpp"
  t backend Write 2 "$PR/db/sql/x.sql"

  # -- relative paths resolve against the launch directory
  t -      Write 0 "docs/x.md"
  t -      Write 2 "backend/x.cpp"
  t -      Write 2 "../other-app/x"
  t tests  Write 0 "x.py"
  t tests  Write 2 "../../other-app/x"
  t db     Write 0 "sql/x.sql"
  t db     Write 2 "../backend/x.cpp"

  # -- secrets: read-only for every role; templates stay editable; the dev .env is open
  t ops    Write 2 "$PR/ops/x/.secrets/k"
  t ops    Write 0 "$PR/ops/x/.secrets/k.example"
  t ops    Write 2 "$PR/ops/x/.pgpass"
  t ops    Write 2 "$PR/ops/x/conf/license.json"
  t ops    Write 0 "$PR/ops/x/conf/license.json.template"
  t ops    Edit  2 "$PR/ops/.env.production"
  t ops    Write 0 "$PR/ops/.env"
  t -      Write 2 "$PR/docs/.secrets/k"
  t db     Write 2 "$PR/db/.secrets/k"
  t db     Write 0 "$PR/db/.secrets/k.sample"
  t ops    NotebookEdit 2 "$PR/ops/x/.secrets/n.ipynb"

  # -- mirrors and other projects (Edit/Write)
  t -      Write 2 "$WS/other-app/x"
  t -      Write 2 "$WS/kit/x"
  t -      Write 2 "$WS/kit.v2/x"
  t -      Write 2 "$WS/shared/platform/x.sql"
  t -      Write 2 "$WS/kit-evil/x"                   # a name nobody foresaw is still refused
  t -      Write 2 "$WS/third-app/../other-app/x"
  t -      Write 2 "$PR/../other-app/x"               # `..` out of the project
  t -      Write 2 "$WS/release.tgz.note"             # a file of the workspace root is outside the project
  t ops    Write 2 "$T/elsewhere/work/x"
  t ops    Write 2 "$WS/kit/nested/work/third-app/x"
  t audit  Write 2 "$WS/other-app/x.md"
  t db     Write 2 "$WS/other-app/x"
  t db     Write 2 "$WS/kit/x"
  t -      Write 2 "/tmp/not-in-the-project"
  t -      Write 0 "$PR/kit-app-notes.md"             # the project's name starts with a mirror's name

  # -- NotebookEdit reads notebook_path
  t -      NotebookEdit 0 "$PR/docs/n.ipynb"
  t -      NotebookEdit 2 "$T/elsewhere/n.ipynb"
  t -      NotebookEdit 2 "$WS/other-app/n.ipynb"
  t -      NotebookEdit 2 "$PR/backend/n.ipynb"
  # a request with two path fields is judged on BOTH
  tj -     2 "$(jq -nc --arg a "$PR/docs/a.md" --arg b "$T/elsewhere/b" '{tool_name:"Write",tool_input:{file_path:$a,notebook_path:$b}}')"
  tj -     2 "$(jq -nc --arg a "$T/elsewhere/a" --arg b "$PR/docs/b.md" '{tool_name:"Write",tool_input:{file_path:$a,notebook_path:$b}}')"
  tj -     0 "$(jq -nc --arg a "$PR/docs/a.md" --arg b "$PR/docs/b.md" '{tool_name:"Write",tool_input:{file_path:$a,notebook_path:$b}}')"
  tj -     0 '{"tool_name":"Write","tool_input":{"content":"no path at all"}}'   # nothing to write

  # -- memory of the agent and the auditor's scratchpad are explicit allows
  t -      Write 0 "$T/home/.claude/projects/-some-slug/memory/MEMORY.md"
  t db     Write 0 "$T/home/.claude/projects/-some-slug/memory/note.md"
  t audit  Write 0 "$T/scratch/$slug_a/sess-1/scratchpad/probe.sh"
  t audit  Write 2 "$T/scratch/other-slug/sess-1/scratchpad/probe.sh"      # a neighbour's session
  t audit  Write 2 "$T/scratch/$slug_a/sess-1/scratchpad/../../../x"       # `..` escape
  t audit  Write 2 "$T/scratch/$slug_a/sess-1/elsewhere/x"
  t audit  Write 2 "$T/other-tmp/x"
  t -      Write 2 "$T/scratch/$slug_o/sess-1/scratchpad/x"               # the coordinator is not in SCRATCHPAD_ROLES
  t db     Write 2 "$T/scratch/$(printf '%s' "$PR/db" | sed 's#[/._]#-#g')/s/scratchpad/x"

  # -- symlinks are followed before the decision
  t db     Write 2 "$PR/db/link-out/x.cpp"
  t db     Write 0 "$PR/db/link-in/x.sql"

  # -- unknown role: fail closed (a false refusal is visible, a silent pass is not)
  t misc   Write 2 "$PR/docs/x.md"                    # directory not in ROLE_MAP
  t misc   Write 2 "$PR/misc/x"
  t misc   NotebookEdit 2 "$PR/misc/n.ipynb"
  t "$T/elsewhere" Write 2 "$PR/docs/x.md"            # launched outside the project
  t misc   Write 0 "$T/home/.claude/projects/-x/memory/m.md"    # memory stays the agent's own
  t misc   Bash 2 "sed -i s/a/b/ $P/kit/x"            # the path-independent Bash checks still apply
  t misc   Bash 0 "echo hi"

  # -- TEMP_ALLOW (file tools only) and its limits
  t -      Write 0 "$WS/other-app/docs/n.md"
  t -      Write 2 "$WS/other-app/src/n.c"
  t ops    Write 2 "$WS/other-app/docs/n.md"          # the exception names one role
  t audit  Write 0 "$T/shared-notes/n.md"             # `*` = every role
  t db     Write 0 "$T/shared-notes/n.md"
  t -      Write 2 "$WS/other-app/docs/.secrets/k"    # secrets beat any exception
  t -      Bash 2 "echo x > $P/other-app/docs/n.md"   # Bash keeps refusing foreign projects

  # -- Bash: a mirror is never written --------------------------------------------------------
  t - Bash 2 "sed -i s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "sed -i.bak s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "sed --in-place=.bak s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "sed --in-place s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "sed --i s/a/b/ $P/kit/x.cpp"            # getopt accepts a unique prefix
  t - Bash 2 "sed -ni s/a/b/p $P/kit/x.cpp"
  t - Bash 2 "sed -n -i s/a/b/p $P/kit/x.cpp"         # the flag need not come first
  t - Bash 2 "sed -E -i s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "sed s/a/b/ -i $P/kit/x.cpp"             # flag after the operand
  t - Bash 2 "perl -pi -e s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "perl -p -i -e s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "perl -0777pi -e s/a/b/ $P/kit/x.cpp"
  t - Bash 2 "echo a|sed -i s/a/b/ $P/kit/x.cpp"      # one separator char before the verb
  t - Bash 2 "cd $P/kit;sed -i s/a/b/ x.cpp"
  t - Bash 2 "cd $P/kit && sed -i s/a/b/ x.cpp"       # the everyday idiom: no verb/path adjacency
  t - Bash 2 "cd $P/kit && echo x > f"
  t - Bash 2 "cd $P/kit && echo x >> f"
  t - Bash 2 "cd $P/kit.v2 && echo x > f"
  t - Bash 2 "cd '$P/kit' && echo x > f"
  t - Bash 2 "echo x > $P/kit/f"
  t - Bash 2 "echo x >> $P/shared/platform/f"
  t - Bash 2 "echo x | tee $P/kit/f"
  t - Bash 2 "rm -rf $P/kit/build"
  t - Bash 2 "mv $P/kit/a $P/kit/b"
  t - Bash 2 "touch $P/kit/f"
  t - Bash 2 "mkdir $P/kit/new"
  t - Bash 2 "chmod +x $P/kit/run.sh"
  t - Bash 2 "ln -s x $P/kit/y"
  t - Bash 2 "dd if=/dev/zero of=$P/kit/f count=1"
  t - Bash 2 "rsync -a src/ $P/kit/src/"
  t - Bash 2 "git apply fix.diff # for $P/kit"
  t - Bash 2 "patch -p1 < fix.diff # $P/kit"
  t - Bash 2 "cd $P/kit && git apply fix.diff"
  t - Bash 2 $'sed -i \\\n  s/a/b/ '"$P"'/kit/x.cpp'                    # line continuation
  t - Bash 2 "git -C $P/kit commit -am x"
  t - Bash 2 "git -C $P/kit push"
  t - Bash 2 "git -C $P/kit reset --hard"
  t ops Bash 2 "sed -i s/a/b/ $P/kit/x.cpp"
  t db  Bash 2 "sed -i s/a/b/ $P/kit/x.cpp"            # the layer copy
  t db  Bash 2 "cd $P/kit && echo x > f"

  # -- Bash: reading a mirror is fine -----------------------------------------------------------
  t - Bash 0 "grep -rn foo $P/kit/src | head"
  t - Bash 0 "cat $P/kit/README.md"
  t - Bash 0 "git -C $P/kit log --oneline -3"
  t - Bash 0 "git -C $P/kit pull"                     # the one allowed mutation
  t - Bash 0 "git -C $P/kit status 2>/dev/null"
  t - Bash 0 "git -C $P/kit tag --list 'v*'"
  t - Bash 0 "git -C $P/kit stash list"
  t - Bash 0 "git -C $P/kit branch -a"
  t - Bash 0 "cd $P/kit && git log -1 && grep -rn x ."
  t - Bash 0 "cd $P/kit && git diff > /dev/null"
  t - Bash 0 "ls $P/kit $P/kit.v2 $P/shared/platform"
  t - Bash 0 "ls $P/"
  t - Bash 0 "diff -r $P/kit/src backend/src/kit"
  t - Bash 0 "find $P/kit -name '*.cpp' | wc -l"
  t - Bash 0 "sed -n 1,20p $P/kit/x.cpp"
  t - Bash 0 "sed -n p $P/kit/vue-i18n.ts"            # `-i` inside a file name is not a flag
  t - Bash 0 "perl -MTime::HiRes -e 'print 1' $P/kit/x"
  t - Bash 0 "docker run --rm -v $P/kit:/s alpine ls" # `--rm` is not `rm`
  t - Bash 0 "git -C $P/kit log -1 --format=%H && git add docs/STATE.md && git commit -m pin"
  t - Bash 0 "echo x > $P/kit-app-notes.txt"          # the project's own name prefixes a mirror's
  t - Bash 0 "rm -f $P/kit-app/tmp.txt"
  t - Bash 0 "cp -r $P/kit-app/docs $P/kit-app/docs.bak"
  # documented behaviour, not endorsed: copying FROM a mirror with a verb is refused (split it:
  # `cat <mirror>/x > file` or `git show`), and so is heredoc prose that names a mirror path next
  # to a word from VERBS ("install", "patch", "cp", "rm" ...). Prose without such a word passes.
  t - Bash 2 "cp $P/kit/x.cpp docs/"
  t - Bash 2 "grep -rn 'rm -rf' $P/kit/run.sh"        # mirrors: verbs are scanned in RAW text, quotes included,
  t - Bash 2 "sh -c 'rm -rf $P/kit/build'"            #   which is what catches `sh -c '...'` (other projects are lenient)
  t - Bash 0 "cat $P/kit/x.cpp > docs/x.cpp"
  t - Bash 2 $'cat <<\'EOF\'\nfirst install the tool, then read '"$P"$'/kit/README\nEOF'
  t - Bash 0 $'cat <<\'EOF\'\nsee '"$P"$'/kit/README for details\nEOF'

  # -- Bash: other projects of the workspace ----------------------------------------------------
  t - Bash 2 "sed -i s/a/b/ $P/other-app/x"
  t - Bash 2 "echo hi > $P/other-app/x"
  t - Bash 2 "echo hi >> $P/third-app/x"
  t - Bash 2 "cd $P/third-app && echo x > a.txt"
  t - Bash 2 "rm -rf $P/third-app/tmp"
  t - Bash 2 "git -C $P/other-app commit -am x"
  t - Bash 2 "cd $P/other-app && git reset --hard"
  t - Bash 2 "cp docs/x $P/kit-app/../other-app/x"
  t - Bash 2 "perl -pi -e s/a/b/ $P/shared/platform/x.sql"
  t - Bash 2 "grep x $P/third-app/y | tee out.txt"
  t - Bash 2 "(cd $P/other-app && echo x > f)"
  t - Bash 2 "pushd $P/other-app && echo x > f"
  t - Bash 2 "cd $P && sed -i 's/a/b/' other-app/x"
  t - Bash 2 "cd $P && echo x > other-app/x"
  t - Bash 2 $'git -C '"$P"$'/other-app \\\n  commit -am x'
  t - Bash 2 "git -C $P/other-app -c user.name=x commit -am x"
  t - Bash 2 "git -C $P/other-app branch -D feat"
  t - Bash 2 "git -C $P/other-app submodule update --init"
  t - Bash 2 "git -C $P/other-app tag v9"
  t - Bash 2 "git -C $P/other-app stash"
  t - Bash 2 "echo x >| $P/other-app/x"
  t audit Bash 2 "echo x > $P/other-app/x.md"
  t audit Bash 2 "cp /tmp/x $P/other-app/x.md"
  t ops   Bash 2 "echo x > $P/tools/x"
  t - Bash 0 "echo x > $P/release.tgz.note"           # a file of the workspace root is not a project
  t - Bash 0 "cat $P/third-app/CLAUDE.md"
  t - Bash 0 "grep -rn foo $P/third-app $P/other-app | head"
  t - Bash 0 "git -C $P/other-app log --oneline -3"
  t - Bash 0 "git -C $P/third-app status 2>/dev/null"
  t - Bash 0 "cd $P/third-app && git diff > /dev/null"
  t - Bash 0 "ls $P/"
  t - Bash 0 "sed -n 1,20p $P/other-app/x"
  t - Bash 0 "docker run --rm -v $P/third-app:/s alpine ls"
  t - Bash 0 "sed -i s/a/b/ docs/x.md"
  t - Bash 0 "git commit -m x -- docs/x.md"
  t - Bash 0 "cd $P/kit-app && echo x > docs/y"
  t - Bash 0 "cd $P/third-app && git log > /tmp/third.log"
  t - Bash 0 "cd $P/other-app && grep -rn '=> {' frontend/src | head"
  t - Bash 0 "cd $P/other-app && grep -rn '<template>' ."
  t - Bash 0 "cd $P/other-app && git log 2>\"/dev/null\""
  t - Bash 0 "git add docs/x.md && git commit -m 'T1: the truth is in $P/other-app/docs'"
  t - Bash 0 "git commit -m 'after cd $P/other-app' -- docs/x.md"
  t - Bash 0 "git -C $P/other-app stash list"
  t - Bash 0 "git -C $P/other-app branch -a"
  t - Bash 0 "grep -rn 'rm -rf' $P/other-app/docker-up.sh"
  t - Bash 0 "grep -rn \"npm install \" $P/other-app/frontend"
  t ops Bash 0 "bash $P/deploy.sh --dry 2>&1 | tee /tmp/deploy.log"
  t ops Bash 0 "ls -la $P/kit-app.tgz && rm -f /tmp/x"
  t - Bash 0 $'python3 - <<\'EOF\'\nx = "escapes `(cd ...)`, `cd '"$P"$' && ... other-app/x`"\nEOF\ngit add docs/x.md && git commit -m x -- docs/x.md'
  t - Bash 0 "cd build/work && echo x > out.txt"      # a dir that merely ends like the workspace
  t - Bash 0 "cd /srv/mywork && echo x > out.txt"
  # heredoc prose naming a foreign project next to a VERBS word is refused, without it passes
  t - Bash 2 $'cat <<\'EOF\'\nread '"$P"$'/other-app/docs, then rm the copy\nEOF'
  t - Bash 0 $'cat <<\'EOF\'\nread '"$P"$'/other-app/docs for the plan\nEOF'
}

# ---- run the suite twice -------------------------------------------------------------------
HOME_MODE=inside;  echo "== workspace under HOME, commands written ~/work/..."; suite '~/work'
HOME_MODE=outside; echo "== workspace outside HOME, commands written with absolute paths"; suite "$WS"

# ---- cases that need their own environment --------------------------------------------------
HOME_MODE=inside
echo "== fail-closed cases"
# no CLAUDE_PROJECT_DIR: falls back to $PWD (the project root = the coordinator)
out=$(cd "$PR" && env -u TEAM_CONF -u CLAUDE_PROJECT_DIR HOME="$T" bash "$PR/.claude/hooks/guard-write.sh" \
      <<<"$(jq -nc --arg p "$PR/docs/x.md" '{tool_name:"Write",tool_input:{file_path:$p}}')" 2>&1 >/dev/null); rc=$?
ok 0 "no CLAUDE_PROJECT_DIR, cwd = root, Write docs/x.md"
out=$(cd "$PR" && env -u TEAM_CONF -u CLAUDE_PROJECT_DIR HOME="$T" bash "$PR/.claude/hooks/guard-write.sh" \
      <<<"$(jq -nc --arg p "$PR/backend/x.cpp" '{tool_name:"Write",tool_input:{file_path:$p}}')" 2>&1 >/dev/null); rc=$?
ok 2 "no CLAUDE_PROJECT_DIR, cwd = root, Write backend/x.cpp"

# malformed input
run "$PR" "$PR/.claude/hooks/guard-write.sh" 'this is not json';                     ok 2 "malformed JSON"
run "$PR" "$PR/.claude/hooks/guard-write.sh" '';                                     ok 0 "empty input (no tool_name)"
run "$PR" "$PR/.claude/hooks/guard-write.sh" '{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"}}'; ok 0 "a tool the barrier does not judge"

# a guard copy with no team.conf anywhere above it refuses everything
mkdir -p "$T/orphan/.claude/hooks"; cp "$GUARD" "$T/orphan/.claude/hooks/guard-write.sh"
run "$T/orphan" "$T/orphan/.claude/hooks/guard-write.sh" "$(jq -nc --arg p "$PR/docs/x.md" '{tool_name:"Write",tool_input:{file_path:$p}}')"
ok 2 "no team.conf above the script: Write refused"
run "$T/orphan" "$T/orphan/.claude/hooks/guard-write.sh" '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
ok 2 "no team.conf above the script: Bash refused"

# a broken team.conf (syntax error) is a block, not a pass
printf 'if then\n' > "$T/bad.conf"
out=$(env TEAM_CONF="$T/bad.conf" CLAUDE_PROJECT_DIR="$PR" bash "$PR/.claude/hooks/guard-write.sh" \
      <<<"$(jq -nc --arg p "$PR/docs/x.md" '{tool_name:"Write",tool_input:{file_path:$p}}')" 2>&1 >/dev/null); rc=$?
ok 2 "team.conf with a syntax error"
# team.conf that forgets a required variable
printf 'TEAM=acme\n' > "$T/short.conf"
out=$(env TEAM_CONF="$T/short.conf" CLAUDE_PROJECT_DIR="$PR" bash "$PR/.claude/hooks/guard-write.sh" \
      <<<"$(jq -nc --arg p "$PR/docs/x.md" '{tool_name:"Write",tool_input:{file_path:$p}}')" 2>&1 >/dev/null); rc=$?
ok 2 "team.conf without PROJECT_ROOT"
# TEAM_CONF points at the real config: works (this is how a test or a one-off run overrides)
out=$(env TEAM_CONF="$PR/.claude/hooks/team.conf" CLAUDE_PROJECT_DIR="$PR" HOME="$T" bash "$T/orphan/.claude/hooks/guard-write.sh" \
      <<<"$(jq -nc --arg p "$PR/docs/x.md" '{tool_name:"Write",tool_input:{file_path:$p}}')" 2>&1 >/dev/null); rc=$?
ok 0 "TEAM_CONF override"

# missing jq: block, not pass
mkdir -p "$T/emptybin"
out=$(env PATH="$T/emptybin" CLAUDE_PROJECT_DIR="$PR" "$BASH" "$PR/.claude/hooks/guard-write.sh" <<<'{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' 2>&1 >/dev/null); rc=$?
ok 2 "jq missing"

# no GNU realpath: the lexical fallback must still collapse `..`
mkdir -p "$T/bin-norealpath"
for c in jq sed grep sort dirname cat id tr head date; do
  p=$(command -v "$c") && ln -sf "$p" "$T/bin-norealpath/$c"
done
nr() {  # nr <expected> <tool> <path or command>
  local j
  if [ "$2" = Bash ]; then j=$(jq -nc --arg c "$3" '{tool_name:"Bash",tool_input:{command:$c}}')
  else j=$(jq -nc --arg p "$3" --arg t "$2" '{tool_name:$t,tool_input:{file_path:$p}}'); fi
  out=$(env PATH="$T/bin-norealpath" CLAUDE_PROJECT_DIR="$PR" HOME="$T" "$BASH" "$PR/.claude/hooks/guard-write.sh" <<<"$j" 2>&1 >/dev/null); rc=$?
  ok "$1" "no realpath: $2 $3"
}
nr 0 Write "$PR/docs/x.md"
nr 2 Write "$PR/backend/x.cpp"
nr 2 Write "$PR/docs/../../other-app/x"
nr 2 Write "$WS/kit/x"
nr 0 Write "$PR/db/../docs/x.md"
nr 2 Bash "sed -i s/a/b/ ~/work/kit/x"

# ---- registration: a barrier nobody calls protects nobody -----------------------------------
echo "== registration"
reg_static() {  # reg_static <settings.json>: PreToolUse carries the guard for all four tools
  python3 - "$1" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
for e in d.get("hooks", {}).get("PreToolUse", []):
    m = e.get("matcher", "")
    if any("guard-write.sh" in h.get("command", "") for h in e.get("hooks", [])) \
       and all(re.search(t, m) for t in ("Edit", "Write", "NotebookEdit", "Bash")):
        sys.exit(0)
sys.exit(1)
PY
}
reg_run() {  # reg_run <settings.json> <CLAUDE_PROJECT_DIR>: EXECUTE the registered command
  local cmd
  cmd=$(python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for e in d["hooks"]["PreToolUse"]:
    for h in e["hooks"]:
        if "guard-write.sh" in h["command"]:
            print(h["command"]); sys.exit(0)
PY
)
  local bad ok_j
  bad=$(jq -nc --arg p "$WS/other-app/x" '{tool_name:"Write",tool_input:{file_path:$p}}')
  ok_j=$(jq -nc --arg p "$2/docs/x.md" '{tool_name:"Write",tool_input:{file_path:$p}}')
  out=$(env -u TEAM_CONF CLAUDE_PROJECT_DIR="$2" HOME="$T" bash -c "$cmd" <<<"$bad" 2>&1 >/dev/null); rc=$?
  ok 2 "registered command blocks a foreign write ($1)"
  # blocking alone proves little (a command that cannot find the barrier also exits 2): an allowed
  # write must pass, so the command really located and ran the barrier
  out=$(env -u TEAM_CONF CLAUDE_PROJECT_DIR="$2" HOME="$T" bash -c "$cmd" <<<"$ok_j" 2>&1 >/dev/null); rc=$?
  ok 0 "registered command lets an allowed write through ($1)"
}
# the check itself must be able to fail
echo '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"guard-write.sh"}]}]}}' > "$T/not-registered.json"
if reg_static "$T/not-registered.json"; then fail=$((fail+1)); echo "FAIL registration check accepts a matcher without Edit/Write/NotebookEdit"; else pass=$((pass+1)); fi
echo '{"hooks":{"SessionStart":[]}}' > "$T/no-pretooluse.json"
if reg_static "$T/no-pretooluse.json"; then fail=$((fail+1)); echo "FAIL registration check accepts a file without PreToolUse"; else pass=$((pass+1)); fi
n=0
for s in "$HERE"/settings.coordinator.json "$HERE"/settings.layer.json "$@"; do
  [ -f "$s" ] || continue
  n=$((n+1))
  if reg_static "$s"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL registration: $s does not register guard-write.sh for Edit|Write|NotebookEdit|Bash"; fi
done
# executed registration (only for the template files next to this test; the layer file runs from a layer)
[ -f "$HERE/settings.coordinator.json" ] && reg_run "$HERE/settings.coordinator.json" "$PR"
[ -f "$HERE/settings.layer.json" ]       && reg_run "$HERE/settings.layer.json" "$PR/db"
[ "$n" -gt 0 ] || echo "(no settings files to check)"

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
