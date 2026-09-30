#!/usr/bin/env bash
#
# context-guard.sh -- the context-size rule and the "ready for compaction or clear" announcement.
# One file for the whole team: it lives only in the coordinator's .claude/hooks/ and the layers
# find it by walking up the tree (see settings.layer.json). Thresholds and the ready phrase come
# from team.conf (CONTEXT_SOFT / CONTEXT_STEP / CONTEXT_HARD / READY_PHRASE).
#
# WHY A HOOK AND NOT A SENTENCE IN THE CHARTER. The rule stood in the charter and every busy
# agent broke it, each answering "I have no exact context counter". Text cannot see the context
# size; a hook can: it reads the last `usage` record of the session transcript
# (input + cache_creation + cache_read + output tokens).
#
# Registered on three events:
#   UserPromptSubmit, PostToolUse -- above CONTEXT_SOFT the rule with the current number is put
#       into the agent's context (every incoming turn; while it works with tools, once per
#       CONTEXT_STEP so it is not repeated on every call).
#   Stop -- if the reply contains a line that STARTS with the ready phrase, the LAST line of the
#       reply must be exactly that phrase, otherwise the turn is not closed (one retry:
#       stop_hook_active). A mention inside a sentence is not an announcement.
#
# This hook never blocks a tool call and never exits non-zero; if it cannot read something it
# stays silent. It needs python3.

set -u
input=$(cat)

# ---- team.conf (optional here: the defaults below apply without it) ---------------------------
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

export CG_TEAM="${TEAM:-team}"
export CG_SOFT="${CONTEXT_SOFT:-300000}"
export CG_STEP="${CONTEXT_STEP:-25000}"
export CG_HARD="${CONTEXT_HARD:-450000}"
export CG_READY="${READY_PHRASE:-Ready for compaction or clear}"   # the owner's choice; must match the charter
export CG_COORD="${TEAM:-team}-${COORDINATOR_ROLE:-owner}"

HOOK_INPUT="$input" python3 - <<'PY'
import json, os, re, sys

SOFT = int(os.environ["CG_SOFT"])
STEP = int(os.environ["CG_STEP"])
HARD = int(os.environ["CG_HARD"])
READY = os.environ["CG_READY"]
TEAM = os.environ["CG_TEAM"]
COORD = os.environ["CG_COORD"]

try:
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except Exception:
    sys.exit(0)

event = data.get("hook_event_name", "")
path = data.get("transcript_path") or ""
sid = re.sub(r"[^A-Za-z0-9_-]", "", data.get("session_id") or "x")


def tail_lines(p, size=4_000_000):
    try:
        with open(p, "rb") as f:
            f.seek(0, 2)
            n = f.tell()
            f.seek(max(0, n - size))
            return f.read().decode("utf-8", "replace").splitlines()
    except Exception:
        return []


lines = tail_lines(path)


def context_size():
    # A compaction boundary ends the search: until the first reply after /compact the last
    # `usage` in the transcript is still the pre-compaction one and would report a stale size.
    for ln in reversed(lines):
        if '"compact_boundary"' in ln:
            return 0
        if '"usage"' not in ln:
            continue
        try:
            d = json.loads(ln)
            if d.get("isSidechain"):
                continue
            u = d["message"]["usage"]
        except Exception:
            continue
        return sum(int(u.get(k) or 0) for k in (
            "input_tokens", "cache_creation_input_tokens",
            "cache_read_input_tokens", "output_tokens"))
    return 0


def last_assistant_text():
    # Prefer the text given in the hook input; else the transcript, but only the CURRENT turn:
    # the last reply may not be on disk yet, and the previous turn's text must not be taken.
    given = data.get("last_assistant_message")
    if isinstance(given, str):
        return given
    for ln in reversed(lines):
        try:
            d = json.loads(ln)
        except Exception:
            continue
        if d.get("type") == "user" and not d.get("isSidechain"):
            c = (d.get("message") or {}).get("content")
            if isinstance(c, str) or not any(
                    isinstance(x, dict) and x.get("type") == "tool_result" for x in c or []):
                return ""
        if d.get("type") != "assistant":
            continue
        content = (d.get("message") or {}).get("content") or []
        texts = [c.get("text", "") for c in content
                 if isinstance(c, dict) and c.get("type") == "text"]
        if texts:
            return "\n".join(texts)
    return ""


if event == "Stop":
    if data.get("stop_hook_active"):
        sys.exit(0)
    # An announcement is a separate line that starts with the phrase; a quoted mention inside a
    # sentence ("the agent wrote 'ready for compaction or clear'") is not one.
    text = last_assistant_text()
    body = [l.strip().strip("*_`>- ").strip() for l in text.strip().splitlines() if l.strip()]
    pattern = re.compile(r"\s+".join(re.escape(w) for w in READY.split()), re.I)
    if not any(pattern.match(l) for l in body):
        sys.exit(0)
    if body and body[-1] == READY:
        sys.exit(0)
    print(json.dumps({
        "decision": "block",
        "reason": (
            "You announced readiness for compaction or clear. The owner's rule (charter): the state "
            "is recorded (the card, the day's docs/history/current/STATE.md, the diary, a docs "
            f"commit by paths), {COORD} is notified through SendMessage, and the LAST line of the "
            "reply is exactly: " + READY + ". Complete the reply so that this phrase is the last "
            "line and nothing follows it."),
    }))
    sys.exit(0)

if event not in ("UserPromptSubmit", "PostToolUse"):
    sys.exit(0)

ctx = context_size()
if ctx < SOFT:
    sys.exit(0)

bucket = (ctx - SOFT) // STEP
state = os.path.join(os.environ.get("TMPDIR") or "/tmp", f"{TEAM}-context-guard-{sid}")
if event == "PostToolUse":
    try:
        last = int(open(state).read().strip() or -1)
    except Exception:
        last = -1
    if bucket <= last:
        sys.exit(0)
try:
    with open(state, "w") as f:
        f.write(str(bucket))
except Exception:
    pass

hard = ctx >= HARD
msg = (
    f"CONTEXT ~ {ctx // 1000}k -- ABOVE {SOFT // 1000}k. The owner's context rule (charter), "
    "not cancelled by anyone's request:\n"
    "1) Take NO new card unrelated to the current one -- even if the coordinator sent it.\n"
    + (f"2) Above {HARD // 1000}k is the hard limit: bring the current card to a point of "
       "continuation, no further.\n"
       if hard else
       "2) The current card of the same line may be finished.\n")
    + "3) Record the state: the card (progress / result), the day's docs/history/current/STATE.md, "
    "the diary, a docs commit by paths.\n"
    f"4) NOTIFY {COORD} with SendMessage: \"{READY.lower()}, context N, commit <sha>\" "
    "(the coordinator tells the owner).\n"
    f"5) The very last line of your terminal reply, exactly: {READY}"
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": event, "additionalContext": msg}}))
PY
exit 0
