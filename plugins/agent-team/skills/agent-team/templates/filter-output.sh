#!/usr/bin/env bash
#
# filter-output.sh -- PreToolUse(Bash): cuts the noise out of long commands BEFORE it reaches the
# agent's context. Usage data of one team showed ~99% of tokens were re-reading context on every
# turn; a full test run (hundreds of lines), a build log or a migration log kept in context is
# re-read until the session ends. The command is rewritten so that only the FAILURES and the
# SUMMARY LINE remain -- the summary is needed ("it works" is not accepted without output).
#
# Rewritten (and only these; everything else passes unchanged):
#   pytest ...                      -> FAILED/ERROR, `E ` blocks, tracebacks, the passed/failed line
#   go test|build|vet ...           -> FAIL/panic/compile errors, `ok <pkg>` / `FAIL <pkg>` lines
#   cmake --build, ./configure, docker [compose] build
#                                   -> error/warning/Built target/Successfully, tail 40
#   anything matching FILTER_SCRIPT_RE (team.conf; empty by default), e.g. a migration script
#                                   -> ERROR/FATAL/passed/failed/applied/done lines, tail 60
# The exit code of the original command is kept (pipefail; `|| true` only on the greps). The
# agent is told: the first output line is "[filter] ..." -- the rewrite is never hidden.
#
# Off for one call: append ` # nofilter` to the command. A command that already contains a
# pipe (` | `) is left alone.
#
# NOTE: the rewritten call is returned with permissionDecision "allow", i.e. the harness will not
# ask about it. Acceptable for test/build runs; if you also filter commands you want to be asked
# about, drop that field from the last line and accept the prompt.
#
# One file for the team, found by walking up the tree like session-start.sh. Needs jq.

set -u
input=$(cat)

# FILTER_SCRIPT_RE may come from team.conf (optional).
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
conf=${TEAM_CONF:-}
if [ -z "$conf" ]; then
  d=$here
  while :; do
    if [ -f "$d/team.conf" ]; then conf=$d/team.conf; break; fi
    if [ -f "$d/.claude/hooks/team.conf" ]; then conf=$d/.claude/hooks/team.conf; break; fi
    [ "$d" = "/" ] && break
    d=$(dirname "$d")
  done
fi
# shellcheck disable=SC1090
[ -n "$conf" ] && [ -f "$conf" ] && . "$conf"
FILTER_SCRIPT_RE=${FILTER_SCRIPT_RE:-}

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || { echo '{}'; exit 0; }
[ -z "$cmd" ] && { echo '{}'; exit 0; }
case "$cmd" in *'# nofilter'*|*' | '*) echo '{}'; exit 0 ;; esac   # opted out, or already piped

# The closing brace goes on its OWN line: a trailing `# comment` in the command would otherwise
# swallow `; }` and leave the group unterminated.
wrap() {  # wrap <grep -E pattern> <grep options> <tail lines>
  printf 'set -o pipefail; { %s\n} 2>&1 | { grep -E %s %s || true; } | tail -n %s' "$cmd" "$2" "'$1'" "$3"
}

filtered=""
# pytest counts only as the START of the command or of a segment (after ; & | or a newline), not
# as a word in prose: a heredoc mentioning "12 pytest" once got rewritten into a filter.
if   [[ "$cmd" =~ (^|[;\&|]|$'\n')[[:space:]]*([^[:space:]]*/)?pytest([[:space:]]|$) ]]; then
  filtered=$(wrap '(FAILED|ERROR|^E |Error|Traceback|passed|failed|error in|no tests ran|deselected)' '-A 6' 150)
elif [[ "$cmd" =~ (^|[[:space:];&])go[[:space:]]+(test|build|vet)([[:space:]]|$) ]]; then
  # `go test` prints `ok <pkg>` / `FAIL <pkg>` per package and `--- FAIL: Test...` per test; -v
  # adds two lines per test, and those are what gets cut. Compile errors look like file.go:1:2: ...
  filtered=$(wrap '(^(ok|FAIL|\?)[[:space:]]|--- FAIL|^FAIL$|^panic:|\.go:[0-9]+:|build failed|cannot |undefined:|vet:|^# )' '-A 8' 80)
elif [[ "$cmd" =~ (cmake[[:space:]]+--build|(^|[[:space:];&])\./configure|docker[[:space:]]+(compose[[:space:]]+)?build) ]]; then
  filtered=$(wrap '(error|Error|ERROR|warning:|Warning|Built target|Successfully|exporting|naming to|rc=|FAILED)' '' 40)
elif [ -n "$FILTER_SCRIPT_RE" ] && [[ "$cmd" =~ $FILTER_SCRIPT_RE ]]; then
  filtered=$(wrap '(ERROR|FATAL|error|passed|failed|ok |not ok|applied|no-op|Done|done)' '' 60)
fi

[ -z "$filtered" ] && { echo '{}'; exit 0; }
filtered="echo '[filter] output trimmed by .claude/hooks/filter-output.sh -- failures and the summary only; for the full output append  # nofilter  to the command'
$filtered"
printf '%s' "$input" | jq --arg f "$filtered" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:(.tool_input + {command:$f})}}'
