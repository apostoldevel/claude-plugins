#!/usr/bin/env bash
#
# guard-write.sh -- per-role write barrier. PreToolUse hook for Edit|Write|NotebookEdit|Bash.
# Exit 0 = allow, exit 2 = block (the reason goes to the agent on stderr). All project facts
# live in team.conf (found next to this file or by walking up); there is no CONFIG block here.
#
# WHERE IT LIVES. The coordinator's copy: <root>/.claude/hooks/. Every layer that is its own
# repository or has its own .claude/settings.json gets the SAME file in <layer>/.claude/hooks/
# and registers it in its own settings.json: hooks do not cross repository boundaries, and a
# barrier that is not registered is never called. Test the registration, not only the script.
#
# MODEL. The agent writes inside PROJECT_ROOT and nowhere else. Mirrors and other projects of
# the workspace are read-only ("git pull" only). The framework is patched INSIDE the project
# (a submodule), tested with the project's own code, and only then pushed upstream and pinned.
# Inside the root the role decides: ALLOW_<role> (positive allow-list), DENY_<role> (read-only
# subtrees), or neither (open). The role comes from the launch directory (ROLE_MAP).
#
# DESIGN RULES (each one cost a false pass or a false refusal once):
#  * Positive allow, decided in ONE place (check_path). A deny-list is bypassed by a name nobody
#    foresaw; an allow-list that misses a name refuses too much, which is visible.
#  * Fail closed. An unknown role, an unreadable team.conf, missing jq, malformed input or any
#    internal error ends in exit 2. (A hook that dies with exit 1 is a PASS for the harness;
#    the EXIT trap below turns every such death into a block.)
#  * The mirror regex is anchored by a trailing separator class, never by a literal "/":
#    `cd <mirror> && ...` has no slash after the name, and a bare prefix would also swallow
#    the project `kit-app` when the mirror is `kit`.
#  * Edit/Write carry file_path, NotebookEdit carries notebook_path. EVERY input field named
#    *path is checked; taking the first non-empty one lets a request with two paths slip by.
#  * Secrets are checked before anything can allow; .example/.sample/.template pass that one
#    check first, or the refusal would forbid editing the very template it tells you to edit.
#  * Bash: no verb/path adjacency (`cd <mirror> && sed -i x` is the normal idiom), in-place
#    flags in any form (-i, -ni, -i.bak, -n -i, --in-place, --i, perl -0777pi), `cd` + relative
#    redirect, `git apply`/`patch`, line continuations and quoted text are normalised.
#
# WHAT IT DOES NOT DO (mechanism plus agreement, never "the barrier prevents it"):
#  * Bash carries only a command string; a relative path or a path built at run time hides the
#    target (`python -c`, `$VAR/x`, `../other-app`, `awk -i inplace`, `cp` from a script).
#    Bash role narrowing is NOT applied: only mirrors and other projects are watched there.
#  * A tool that writes under another name never reaches this hook (the settings matcher is a
#    list of four names). Add the name to the matcher and to the `case` below if one appears.
#  * Heredoc prose is scanned like a command: a mirror path plus a word from VERBS (install,
#    patch, cp ...) in the same command is refused. Split the command or rephrase.
#
# Requires: bash, jq, sed, grep. Uses GNU `realpath -m` when present, else a lexical fallback.

set -euo pipefail
set -f   # never glob-expand the lists from team.conf

AGENT=""
deny() { echo "BLOCKED${AGENT:+ ($AGENT)}: $1" >&2; exit 2; }

# Any abnormal death (set -e, set -u, a failed command) is a block, never a silent pass.
trap '_rc=$?; if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then echo "BLOCKED: write barrier internal error (rc=$_rc); fail-closed." >&2; exit 2; fi' EXIT

command -v jq >/dev/null 2>&1 || deny "jq is not installed; the barrier cannot read the request."

# ---- helpers ----------------------------------------------------------------------------------
lexnorm() {  # lexical normalisation: collapse . and .. (no symlink resolution)
  local -a parts stack=()
  local seg
  IFS=/ read -r -a parts <<<"$1"
  for seg in "${parts[@]}"; do
    case "$seg" in
      ''|.) ;;
      ..) if [ "${#stack[@]}" -gt 0 ]; then unset "stack[${#stack[@]}-1]"; fi ;;
      *) stack+=("$seg") ;;
    esac
  done
  local IFS=/
  printf '/%s' "${stack[*]:-}"
}
norm() { realpath -m -- "$1" 2>/dev/null || lexnorm "$1"; }
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}; printf '%s' "$s"; }
ere()  { printf '%s' "$1" | sed -E 's/[].[(){}*+?^$|\\]/\\&/g'; }  # escape ERE specials
glob_any() {  # glob_any <string> "<space-separated globs>" -> 0 if any glob matches
  local s=$1 g
  for g in $2; do
    if [[ $s == $g ]]; then return 0; fi
  done
  return 1
}

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
  deny "team.conf not found (looked next to $here and up the tree); every write is refused until it exists."
fi
# shellcheck disable=SC1090
. "$conf"
for v in TEAM WORKSPACE_DIR PROJECT_ROOT; do
  if [ -z "${!v:-}" ]; then deny "team.conf: $v is not set."; fi
done
: "${ROLE_MAP:=}" "${MIRRORS:=}" "${SECRET_GLOBS:=}" "${SECRET_TEMPLATE_GLOBS:=}" "${EXTRA_DENY:=}"
: "${TEMP_ALLOW:=}" "${SCRATCHPAD_ROLES:=}" "${SCRATCHPAD_BASE:=/tmp/claude-$(id -u)}" "${WORKSPACE_ALIASES:=}"

WORKSPACE_DIR=$(norm "$WORKSPACE_DIR")
PROJECT_ROOT=$(norm "$PROJECT_ROOT")
PROJECT_NAME=${PROJECT_ROOT##*/}
# How the workspace may be SPELLED in a shell command: its real path; `~/x`, `$HOME/x`, `${HOME}/x`
# when it is under $HOME; plus WORKSPACE_ALIASES (other spellings, e.g. through a symlink). The
# spellings are anchored on purpose: a bare tail such as `work` or `src` would also match
# `build/work` or `frontend/src` and refuse innocent commands.
ws_alt=$(ere "$WORKSPACE_DIR")
home_real=$(norm "${HOME:-/nonexistent}")
case "$WORKSPACE_DIR" in
  "$home_real"/*)
    ws_tail=$(ere "${WORKSPACE_DIR#"$home_real"/}")
    ws_alt="$ws_alt|~/$ws_tail|$(ere '$HOME')/$ws_tail|$(ere '${HOME}')/$ws_tail" ;;
esac
for a in $WORKSPACE_ALIASES; do ws_alt="$ws_alt|$(ere "${a%/}")"; done
WS_ALT="($ws_alt)"
WS_RE="(^|[^A-Za-z0-9_.-])$WS_ALT"   # the left boundary keeps `xx/path/to/work` out
mir_alt=""
for m in ${MIRRORS//|/ }; do mir_alt="${mir_alt:+$mir_alt|}$(ere "$m")"; done
[ -n "$mir_alt" ] || mir_alt='__no_mirror_configured__'
MIRRORS_RE="$WS_RE/($mir_alt)([^A-Za-z0-9_.-]|\$)"

# ---- who are we -------------------------------------------------------------------------------
input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null) || deny "request is not valid JSON."

launch=$(norm "${CLAUDE_PROJECT_DIR:-$PWD}")
rel=""
case "$launch" in
  "$PROJECT_ROOT")   rel=. ;;
  "$PROJECT_ROOT"/*) rel=${launch#"$PROJECT_ROOT"/} ;;
esac
role=unknown
if [ -n "$rel" ]; then
  while IFS= read -r line; do
    line=${line%%#*}
    case "$line" in *=*) ;; *) continue ;; esac
    k=$(trim "${line%%=*}"); v=$(trim "${line#*=}")
    k=${k#./}; k=${k%/}; [ -n "$k" ] || k=.
    if [ "$k" = "$rel" ]; then role=${v%%|*}; break; fi
  done <<<"$ROLE_MAP"
  case "$role" in ''|*[!A-Za-z0-9_]*) role=unknown ;; esac
fi
if [ "$role" = unknown ]; then AGENT="$TEAM-?"; else AGENT="$TEAM-$role"; fi
allow_var="ALLOW_$role"; deny_var="DENY_$role"; hint_var="HINT_$role"
allow_list=${!allow_var:-}; deny_list=${!deny_var:-}; hint=${!hint_var:-}

# ---- one path ---------------------------------------------------------------------------------
# `return 0` = this path is fine; `deny` = exit 2. Never `exit 0` here: a request may carry
# several paths and one good path must not end the check of the others.
check_path() {
  local path=$1 allowed=0 r g slug relp
  case "$path" in /*) : ;; *) path="$launch/$path" ;; esac
  path=$(norm "$path")   # collapses `..` and follows symlinks; works on paths that do not exist

  # 1. Secrets. Templates pass THIS rule first, then face the rest like any other file.
  if ! glob_any "$path" "$SECRET_TEMPLATE_GLOBS"; then
    if glob_any "$path" "$SECRET_GLOBS"; then
      deny "secret or credential file, read-only for agents. Edit the .example/.template instead, or ask the owner."
    fi
  fi
  if glob_any "$path" "$EXTRA_DENY"; then
    deny "this path is closed to every role by EXTRA_DENY in team.conf."
  fi

  # 2. Explicit allows outside the root.
  case "$path" in
    */.claude/projects/*/memory/*) return 0 ;;   # the agent's own memory lives outside the tree
  esac
  if [ -n "$SCRATCHPAD_ROLES" ] && { [ "$SCRATCHPAD_ROLES" = '*' ] || glob_any "$role" "$SCRATCHPAD_ROLES"; }; then
    # Only the scratchpad derived from THIS session's launch directory; a neighbour's slug,
    # other /tmp and any `..`/symlink escape (already collapsed above) stay refused.
    slug=$(printf '%s' "$launch" | sed 's#[/._]#-#g')
    case "$path" in
      "$SCRATCHPAD_BASE/$slug/"*/scratchpad/*) return 0 ;;
    esac
  fi
  while read -r r g; do   # TEMP_ALLOW: "<role|*> <absolute glob>", see team.conf
    case "$r" in ''|'#'*) continue ;; esac
    if [ "$r" = '*' ] || [ "$r" = "$role" ]; then
      if [[ $path == $g ]]; then return 0; fi
    fi
  done <<<"$TEMP_ALLOW"

  # 3. Fail closed on an unknown role.
  if [ "$role" = unknown ]; then
    deny "launch directory '$launch' is not in ROLE_MAP (team.conf), so the role is unknown and file writes are refused. Start the agent from its own directory or fix ROLE_MAP."
  fi

  # 4. THE POSITIVE ALLOW. Everything decided here; below is only the wording of a refusal.
  case "$path" in
    "$PROJECT_ROOT"/*) allowed=1 ;;
  esac
  if [ "$allowed" = 1 ]; then
    relp=${path#"$PROJECT_ROOT"/}
    if [ -n "$allow_list" ]; then
      if glob_any "$relp" "$allow_list"; then return 0; fi
      deny "$AGENT writes only in: $allow_list. '$relp' is another agent's. $hint"
    fi
    if [ -n "$deny_list" ] && glob_any "$relp" "$deny_list"; then
      deny "$AGENT does not write in: $deny_list. '$relp' belongs to another agent. $hint"
    fi
    return 0
  fi

  # 5. Refused; pick the wording.
  if [[ $path =~ $MIRRORS_RE ]]; then
    deny "framework mirror. The source of truth is upstream; here only \`git pull\`. Patch the framework inside the project (submodule), test it with the project's code, then push upstream and move the pin."
  fi
  case "$path" in
    "$WORKSPACE_DIR"/*) deny "another project of the workspace. It is read as a reference and is not edited from here." ;;
    *)                  deny "path outside the project root ($PROJECT_ROOT)." ;;
  esac
}

# ---- Edit / Write / NotebookEdit --------------------------------------------------------------
# (A temporary project-specific exception belongs in TEMP_ALLOW with its removal condition,
#  not as a special case in this code.)
case "$tool" in
  Edit|Write|NotebookEdit)
    paths=$(jq -r '(.tool_input // {}) | to_entries[] | select(.key | test("(^|_)path$"))
                   | .value | select(type == "string") | select(length > 0)' <<<"$input") \
      || deny "cannot read the tool input."
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      check_path "$p"
    done <<<"$paths"
    ;;

  # ---- Bash ------------------------------------------------------------------------------------
  Bash)
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input") || deny "cannot read the tool input."
    [ -n "$cmd" ] || exit 0

    # Word boundary on the left is mandatory, or `docker run --rm` reads as `rm`.
    VERBS='(patch|cp|mv|rm|tee|truncate|dd|touch|ln|chmod|chown|install|rsync|mkdir)'
    # In-place editing is a FLAG, not a name, and the flag need not come first: `sed -n -i`,
    # `sed -E -i`, `perl -p -i -e`, `sed 's/a/b/' -i f`, `sed --in-place`, `sed --i` (getopt takes
    # a unique prefix), `perl -0777pi`. The mandatory space before the dash keeps `vue-i18n.ts`
    # out; the tail `([^A-Za-z0-9]|$)` keeps `perl -MTime::HiRes` out.
    INPLACE='(^|[^a-zA-Z0-9_.-])(sed|perl|ruby)([[:space:]][^|;&]*)?[[:space:]](--i|-[A-Za-z0-9]*i([^A-Za-z0-9]|$))'

    # (A) a writing verb and a mirror path in ONE command, adjacency not required
    if grep -Eq "$MIRRORS_RE" <<<"$cmd" \
       && { grep -Eq "(^|[^a-zA-Z0-9_.-])$VERBS([[:space:]]|\$)" <<<"$cmd" \
            || grep -Eq "$INPLACE" <<<"$cmd"; }; then
      deny "write to a framework mirror. Read and \`git pull\` only; patch the framework inside the project."
    fi
    # (B) redirect straight into a mirror
    if grep -Eq ">>?[[:space:]]*[^|;& ]*($MIRRORS_RE)" <<<"$cmd"; then
      deny "redirect into a framework mirror. Read and \`git pull\` only."
    fi
    # (C) `cd` into a mirror, then a redirect to a relative path. /dev/* does not count, or
    #     `git -C <mirror> status 2>/dev/null` would be refused.
    if grep -Eq "(^|[;&|[:space:]])cd[[:space:]]+[^;&|]*($MIRRORS_RE)" <<<"$cmd"; then
      for tgt in $(grep -oE '>>?[[:space:]]*[^|;&[:space:]]+' <<<"$cmd" | sed -E 's/^>>?[[:space:]]*//' || true); do
        case "$tgt" in /dev/*) : ;; *) deny "redirect after \`cd\` into a framework mirror." ;; esac
      done
    fi
    # (D) `git apply` / `patch`: the target is inside the diff and the barrier cannot see it.
    if grep -Eq "(^|[;&|[:space:]])(git[[:space:]]+apply|patch)([[:space:]]|\$)" <<<"$cmd" \
       && grep -Eq "$MIRRORS_RE" <<<"$cmd"; then
      deny "\`git apply\`/\`patch\` with a mirror path: the write target is inside the diff, which the barrier cannot see."
    fi

    # ---- other projects of the workspace -----------------------------------------------------
    # The set is any DIRECTORY <workspace>/<name> except this project. Files in the workspace
    # root (`deploy.sh`, `*.tgz`) are not projects. Not caught: a relative path without the
    # workspace in it (`../other-app`) and a path held in a variable.
    # Price of (E): reading a foreign project and writing to your own in ONE command
    # (`cp <other>/x docs/`, `... | tee out`) is refused; make it two commands.
    #
    # Normalisation: line continuations are joined; verbs are looked for outside quoted text
    # (`grep 'rm -rf'` is a read); redirect targets are taken without single-quoted text
    # (`grep '=> {'`) and without double-quote marks.
    c1=${cmd//$'\\\n'/ }
    bare=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$c1")
    rsrc=$(sed -E "s/'[^']*'//g; s/\"//g" <<<"$c1")
    plain=${c1//\"/}
    WRITE_RE="(^|[[:space:];&|(])$VERBS([[:space:]]|\$)"
    fp() {  # is the directory name $1 another project of the workspace?
      if [ "$1" = "$PROJECT_NAME" ]; then return 1; fi
      [ -d "$WORKSPACE_DIR/$1" ]
    }
    has_foreign() {  # does the string $1 contain a path into another project?
      local n
      for n in $(grep -oE "$WS_RE/[A-Za-z0-9_.-]+" <<<"$1" | sed -E 's#.*/##' | sort -u || true); do
        if fp "$n"; then return 0; fi
      done
      grep -Eq "$WS_RE/[^[:space:]]*/\\.\\.(/|[[:space:]]|\$)" <<<"$1"
    }
    writes=0
    if grep -Eq "$WRITE_RE" <<<"$bare" || grep -Eq "$INPLACE" <<<"$bare"; then writes=1; fi
    targets=$(grep -oE '>[>|]?[[:space:]]*[^|;&[:space:]]+' <<<"$rsrc" | sed -E 's/^>[>|]?[[:space:]]*//' || true)
    # `cd`/`pushd`, also inside a subshell `( cd ... )`, into another project or into the
    # workspace root itself. Only in command position and outside quotes: the word "cd" in a
    # heredoc or a commit message is not a move.
    # The workspace must be spelled in one of the anchored forms above and end at `/` or the end
    # of the word, so `cd build/work` or `cd ~/workshop` are not moves into a workspace `work`.
    cdforeign=0
    CD_RE="(^|[;&|(])[[:space:]]*(cd|pushd)[[:space:]]+$WS_ALT(/[A-Za-z0-9_.-]*|[[:space:];&|)]|\$)"
    STRIP_RE="^[;&|(]?[[:space:]]*(cd|pushd)[[:space:]]+$WS_ALT/?(.*)\$"
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      n=""
      if [[ $m =~ $STRIP_RE ]]; then n=${BASH_REMATCH[$(( ${#BASH_REMATCH[@]} - 1 ))]}; fi
      n=${n%%[!A-Za-z0-9_.-]*}
      if [ -z "$n" ] || fp "$n"; then cdforeign=1; fi   # empty name = the workspace root itself
    done < <(grep -oE "$CD_RE" <<<"${bare//\"/}" || true)

    # (E) a writing verb or in-place flag in the same command as a foreign path, or after `cd` there
    if [ "$writes" = 1 ] && { has_foreign "$plain" || [ "$cdforeign" = 1 ]; }; then
      deny "write to another project of the workspace. It is read as a reference and is not edited from here. If this reads there and writes here, split it into two commands."
    fi
    for tgt in $targets; do
      # (F) redirect straight into a foreign project
      if has_foreign "$tgt"; then deny "redirect into another project of the workspace."; fi
      # (G) after `cd` into a foreign project, a redirect to a relative path
      if [ "$cdforeign" = 1 ]; then
        case "$tgt" in
          /*|~*|'$HOME'*|'${HOME}'*|'$TMPDIR'*|'${TMPDIR}'*|'&'[0-9]*|[0-9]) : ;;
          *) deny "redirect after \`cd\` into another project of the workspace." ;;
        esac
      fi
    done
    # (H) git that changes a foreign tree or history. Parsed per git call: global options
    # (-C, -c, --no-pager ...) are skipped; the target is `-C` or a `cd` earlier in the command.
    # Reading (log, status, diff, tag --list, stash list, branch -a) and pull/fetch pass.
    while IFS= read -r seg; do
      [ -n "$seg" ] || continue
      read -r -a w <<<"$seg"
      i=1; tgtC=""; sub=""
      while [ "$i" -lt "${#w[@]}" ]; do
        case "${w[$i]}" in
          -C) tgtC=${w[$((i+1))]:-}; i=$((i+2)) ;;
          -c) i=$((i+2)) ;;
          -*) i=$((i+1)) ;;
          *) sub=${w[$i]}; i=$((i+1)); break ;;
        esac
      done
      first=${w[$i]:-}
      mut=0
      case "$sub" in
        add|commit|reset|checkout|restore|switch|rm|mv|apply|am|merge|rebase|cherry-pick|revert|clean|push|submodule|update-ref|worktree|filter-repo|filter-branch|gc|prune|replace|notes) mut=1 ;;
        stash) case "$first" in ''|push|pop|apply|drop|clear|save|store) mut=1 ;; esac ;;
        tag) case "$first" in ''|-l|--list|--contains|--no-contains|--points-at|-n*|--merged|--no-merged|--sort*|--format*|--column*) : ;; *) mut=1 ;; esac ;;
        branch) case "$first" in -d|-D|-m|-M|-c|-C|-f|--delete|--move|--copy|--force|-u|--set-upstream-to*|--unset-upstream) mut=1 ;; -*|'') : ;; *) mut=1 ;; esac ;;
      esac
      [ "$mut" = 1 ] || continue
      if [ -n "$tgtC" ]; then
        case "$tgtC" in
          /*|~*|'$HOME'*|'${HOME}'*)
            if has_foreign "$tgtC"; then deny "git that changes another project of the workspace ($sub). From here: read and \`git pull\` only."; fi ;;
          *)
            if [ "$cdforeign" = 1 ]; then deny "git that changes another project of the workspace ($sub), after \`cd\` there."; fi ;;
        esac
      elif [ "$cdforeign" = 1 ]; then
        deny "git that changes another project of the workspace ($sub), after \`cd\` there. From here: read and \`git pull\` only."
      fi
    done < <(grep -oE "(^|[;&|(\`[:space:]])git([[:space:]]+[^;&|)]*)?" <<<"$plain" | sed -E 's/^[;&|(`[:space:]]+//' || true)
    ;;
esac

exit 0
