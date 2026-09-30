#!/usr/bin/env bash
#
# session-start.sh -- the session briefing. Printed by the SessionStart hook of EVERY layer; the
# file itself lives only in the coordinator's .claude/hooks/ and the layers find it by walking up
# the tree (settings.layer.json), so there is one copy and no drift.
#
#   session-start.sh                SessionStart: who you are, yours / not yours, reading order,
#                                   the rules that must survive a clear, the open working day.
#   session-start.sh --postcompact  PostCompact: briefing.txt (placeholders filled in) + the day.
#
# WHY A SCRIPT AND NOT A TEXT FILE. The first version was a .txt that printed the same thing to
# everyone. `grep <agent-name>` over its output found NOTHING: after a /clear the agent got the
# day and the reading order but not its own layer and boundaries -- "recoverable by reading the
# charter", not "delivered". That difference cost a day once (a PostCompact hook was declared and
# never ran, and looked as if it had). So the identity is decided here, by launch directory,
# from the same ROLE_MAP the write barrier uses.
#
# Two roles in one directory (`backend=backend|framework` in ROLE_MAP) cannot be told apart by
# the directory: start the second with `${AGENT_ENV}=framework` (team.conf), or the agent is told
# to establish its name first.
#
# Lifecycle log: on source=clear|compact an entry "HH:MM <agent> <source>" is appended to
# LIFECYCLE_LOG (not for the coordinator). The coordinator watches it (Monitor on
# `tail -n0 -F <file>`) and re-briefs an agent that has just lost its context; an agent after
# /clear otherwise stands silent until somebody writes to it.

set -u

# ---- team.conf --------------------------------------------------------------------------------
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
if [ -z "$conf" ] || [ ! -f "$conf" ]; then
  echo "WARNING: team.conf not found (looked up the tree from $here) -- no briefing; ask the coordinator."
  exit 0
fi
# shellcheck disable=SC1090
. "$conf"
TEAM=${TEAM:-team}
COORDINATOR_ROLE=${COORDINATOR_ROLE:-owner}
COORD="$TEAM-$COORDINATOR_ROLE"
READY=${READY_PHRASE:-Ready for compaction or clear}
SOFT=${CONTEXT_SOFT:-300000}
HARD=${CONTEXT_HARD:-450000}
LOG=${LIFECYCLE_LOG:-${XDG_RUNTIME_DIR:-/tmp}/$TEAM-lifecycle.log}
AGENT_ENV=${AGENT_ENV:-TEAM_AGENT}

trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}; printf '%s' "$s"; }
norm() { realpath -m -- "$1" 2>/dev/null || printf '%s' "$1"; }

# ---- the working day: the nearest docs/history/DAY above the launch directory -----------------
start="${CLAUDE_PROJECT_DIR:-$PWD}"
root=$start
while [ "$root" != "/" ] && [ ! -f "$root/docs/history/DAY" ]; do root=$(dirname "$root"); done
day() {
  cat "$root/docs/history/DAY" 2>/dev/null ||
    echo "WARNING: docs/history/DAY not found -- ask $COORD which day is open."
}

# ---- PostCompact: the static note with placeholders filled in ---------------------------------
if [ "${1:-}" = "--postcompact" ]; then
  esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
  if [ -f "$here/briefing.txt" ]; then
    sed -e "s|{{TEAM}}|$(esc "$TEAM")|g" -e "s|{{COORDINATOR}}|$(esc "$COORD")|g" \
        -e "s|{{READY_PHRASE}}|$(esc "$READY")|g" -e "s|{{CONTEXT_SOFT}}|$((SOFT / 1000))k|g" \
        -e "s|{{CONTEXT_HARD}}|$((HARD / 1000))k|g" "$here/briefing.txt"
  else
    echo "WARNING: briefing.txt not found next to session-start.sh."
  fi
  echo
  echo "=== WORKING DAY ==="
  day
  exit 0
fi

# ---- who are we: ROLE_MAP by launch directory -------------------------------------------------
launch=$(norm "$start")
proot=$(norm "${PROJECT_ROOT:-}")
rel=""
case "$launch" in
  "$proot")   rel=. ;;
  "$proot"/*) rel=${launch#"$proot"/} ;;
esac
roles=""
if [ -n "$rel" ]; then
  while IFS= read -r line; do
    line=${line%%#*}
    case "$line" in *=*) ;; *) continue ;; esac
    k=$(trim "${line%%=*}"); v=$(trim "${line#*=}")
    k=${k#./}; k=${k%/}; [ -n "$k" ] || k=.
    if [ "$k" = "$rel" ]; then roles=$v; break; fi
  done <<<"${ROLE_MAP:-}"
fi

role=""; dual=""
if [ -z "$roles" ]; then
  who="<layer not determined>"
  mine="-"; notmine="find out who you are from the launch directory and tell the owner"
else
  role=${roles%%|*}
  if [ "$roles" != "$role" ]; then   # several roles share this directory
    want=${!AGENT_ENV:-}; want=${want#"$TEAM-"}
    for r in ${roles//|/ }; do [ "$r" = "$want" ] && role=$r; done
    if [ "$want" != "$role" ]; then
      dual="
This directory hosts several roles ($roles) and the directory cannot tell them apart. FIRST
establish your name (the launch variable $AGENT_ENV, or the name your session was given); if you
are not $TEAM-$role, you are the other one and the lines above are not yours. A shared checkout:
your diary is only your own file under docs/history/<day>/; commit by paths, never --amend or
git add -A."
    fi
  fi
  who="$TEAM-$role"
  m="MINE_$role"; n="NOTMINE_$role"
  mine=${!m:-"(not described in team.conf)"}; notmine=${!n:-"(not described in team.conf)"}
fi

# ---- lifecycle log ----------------------------------------------------------------------------
input=$(cat 2>/dev/null || true)
src=$(printf '%s' "$input" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' | head -n 1)
case "$src" in
  clear|compact)
    if [ "$role" != "$COORDINATOR_ROLE" ]; then
      tag=$who
      [ -z "$roles" ] && tag="$TEAM-?(${rel:-outside-project})"
      [ -n "$dual" ] && tag="$TEAM-${roles//|/|$TEAM-}"
      printf '%s %s %s\n' "$(date '+%H:%M')" "$tag" "$src" >> "$LOG" 2>/dev/null || true
    fi ;;
esac

cat <<EOF
SESSION START. There is no context from the previous session -- state is read from disk, not recalled.

YOU ARE $who.
  yours:     $mine
  NOT yours: $notmine$dual

Reading order: (1) docs/STATE.md -- where the project is; (2) docs/TEAM.md -- the charter, whole;
(3) your open cards:
    grep -l 'assignee:.*$who' docs/board/cards/*.md | xargs grep -L 'status: done'
(4) docs/history/current/ -- the state of the current day and the diary.

Live systems (production, staging) and your own configuration (barrier, settings.json, CLAUDE.md)
change only on the owner's word said in YOUR terminal. Push and tag: on the owner's word recorded
in docs/DECISIONS.md and relayed by $COORD with the line -- check the record and act, do not send
the owner to your terminal. Code: commit it yourself after your own review; docs: commit them
yourself when idle. If the owner tells you something directly, pass it to $COORD verbatim in
the same turn: the coordinator must know.

CONTEXT AND STATE -- a hard rule:
  (1) above $((SOFT / 1000))k take NO new card unrelated to the current one, whoever sends it;
  (2) when idle, record your state yourself, without a reminder: card, day STATE, diary, docs commit;
  (3) ready to lose context (compaction or clear): you MUST notify $COORD (SendMessage: "ready for
      compaction or clear, context N, commit <sha>"), and the LAST line in your terminal is exactly:
      $READY
  The context-guard hook reports the size above $((SOFT / 1000))k -- "I have no counter" is no longer an answer.

A working day opens and closes by the OWNER'S WORD, not by the date. The open day is below.

=== WORKING DAY ===
EOF
day
