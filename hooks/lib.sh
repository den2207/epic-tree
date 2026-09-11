#!/bin/bash
# epic-tree shared hook logic: root discovery, live-epic enumeration, context
# assembly. Sourced by session-start.sh and user-prompt-submit.sh.
LC_ALL=C
export LC_ALL
BUDGET=9000
ROSTER_CAP=10

json_field() {
  python3 -c 'import json,sys
try: print(json.load(sys.stdin).get(sys.argv[1],"") or "")
except Exception: pass' "$1" 2>/dev/null
}

emit() {
  printf '%s' "$2" | python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":sys.argv[1],"additionalContext":sys.stdin.read()}}))' "$1"
}

# Canonical epics dir is <root>/epics/; <root>/.claude/epics/ is the pre-rename
# legacy location, still honored so existing epics keep working.
epics_base() {
  if [ -d "$1/epics" ]; then printf '%s/epics' "$1"
  elif [ -d "$1/.claude/epics" ]; then printf '%s/.claude/epics' "$1"
  fi
}

# A live epic is a directory (or symlink to one) under the base whose name does not
# start with `_` or `.` and which carries state.md or charter.md. Closed epics are
# moved to `_archive/` and thereby stop being live — there is no ACTIVE pointer.
live_epics() {
  local d n
  for d in "$1"/*/; do
    d=${d%/}
    n=$(basename "$d")
    case $n in _*|.*|*[!A-Za-z0-9._-]*) continue;; esac
    [ -f "$d/state.md" ] || [ -f "$d/charter.md" ] || continue
    printf '%s\n' "$n"
  done
}

# Worktree-aware start point: map a linked worktree back to its main checkout.
map_worktree() {
  local common
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  if [ -n "$common" ]; then dirname "$common"; else printf '%s' "$1"; fi
}

# Every epics base on the walk-up from $1 that holds at least one live epic,
# nearest first. Never considers $HOME itself or /. EPIC_TREE_ROOT forces one root.
find_bases() {
  local d b
  if [ -n "${EPIC_TREE_ROOT:-}" ]; then
    b=$(epics_base "$EPIC_TREE_ROOT")
    [ -n "$b" ] && printf '%s\n' "$b"
    return
  fi
  d=$1
  while [ "$d" != "$HOME" ] && [ "$d" != "/" ] && [ -n "$d" ]; do
    b=$(epics_base "$d")
    if [ -n "$b" ] && [ -n "$(live_epics "$b")" ]; then printf '%s\n' "$b"; fi
    d=$(dirname "$d")
  done
}

# All live epics across the given bases (one per line): "<base>/<slug>".
all_live_dirs() {
  local b s
  for b in "$@"; do
    while IFS= read -r s; do [ -n "$s" ] && printf '%s/%s\n' "$b" "$s"; done < <(live_epics "$b")
  done
}

epic_updated() { grep -m1 '^updated:' "$1/state.md" 2>/dev/null | sed 's/^updated:[[:space:]]*//' | cut -c1-16; }
epic_kickoff() { grep -m1 '^kickoff:' "$1/state.md" 2>/dev/null | sed 's/^kickoff:[[:space:]]*//' | cut -c1-120; }
epic_step()    { awk '/^## Active slice/{f=1;next} f&&NF{print;exit}' "$1/state.md" 2>/dev/null | cut -c1-120; }

# Full context for one epic: charter + state + ledger index, within BUDGET.
# $1 = epic dir, $2 = header line. Prints the assembled text.
epic_context() {
  local epic_dir=$1 header=$2 charter="" state="" lindex="" ctx keep
  [ -f "$epic_dir/charter.md" ] && charter=$(cat "$epic_dir/charter.md")
  [ -f "$epic_dir/state.md" ] && state=$(cat "$epic_dir/state.md")
  [ -f "$epic_dir/ledger.md" ] && lindex=$(grep -E '^\| L-[0-9]+' "$epic_dir/ledger.md" | cut -c1-160 || true)
  if [ -z "$charter$state" ]; then
    printf 'epic-tree: epic at %s has no charter.md/state.md — scaffold incomplete.' "$epic_dir"
    return
  fi
  assemble() {
    printf '%s\n\n===== charter.md =====\n%s\n\n===== state.md =====\n%s' "$header" "$charter" "$state"
    [ -n "$lindex" ] && printf '\n\n===== ledger index (full file: %s/ledger.md) =====\n%s' "$epic_dir" "$lindex"
    return 0
  }
  ctx=$(assemble)
  if [ ${#ctx} -gt $BUDGET ]; then lindex=""; ctx=$(assemble); fi
  if [ ${#ctx} -gt $BUDGET ]; then
    header="$header [TRUNCATED to fit the 9k additionalContext budget — read $epic_dir/charter.md fully before relying on it]"
    keep=$(( BUDGET - ${#header} - ${#state} - 200 ))
    [ "$keep" -lt 0 ] && keep=0
    # Cut on a UTF-8 character boundary: a raw byte cut mid-sequence leaks lone
    # surrogates into the emitted JSON and crashes downstream re-encoders.
    charter=$(printf '%s' "$charter" | python3 -c 'import sys
n = int(sys.argv[1])
sys.stdout.write(sys.stdin.buffer.read()[:n].decode("utf-8", "ignore"))' "$keep")
    ctx=$(assemble)
  fi
  printf '%s' "$ctx"
}

# Roster of every live epic across the bases, newest `updated:` first.
roster() {
  local lines n shown
  lines=$(while IFS= read -r d; do
    [ -n "$d" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$(epic_updated "$d")" "$(basename "$d")" "$(dirname "$d")" "${d}"
  done < <(all_live_dirs "$@") | sort -r)
  n=$(printf '%s\n' "$lines" | grep -c .)
  printf '[epic-tree] %s live epics, none selected yet. Selection is by the user'\''s message: the FIRST message names the epic slug — normally its kickoff phrase, `epic <slug>: <next step>` — and the UserPromptSubmit hook injects that epic'\''s charter + state; then run the epic-start skill. A message naming no slug means this session is not epic work. Never pick an epic from this list yourself; if the work is clearly epic work but no slug was named, ask which one.\n' "$n"
  shown=0
  while IFS=$'\t' read -r ts slug base dir; do
    [ -n "$slug" ] || continue
    if [ "$shown" -ge "$ROSTER_CAP" ]; then
      printf '  +%s older — bash <epic-tree>/bin/epic-list.sh %s\n' "$((n - shown))" "$(dirname "$base")"
      break
    fi
    k=$(epic_kickoff "$dir")
    printf '  %s  updated %s  kickoff: %s\n' "$slug" "${ts:-—}" "${k:-(none — the coordinator adds one at handoff)}"
    shown=$((shown + 1))
  done <<< "$lines"
}

# Stale single-epic pointer from v1: it is no longer read anywhere.
stale_active_note() {
  local b
  for b in "$@"; do
    [ -f "$b/ACTIVE" ] && printf ' NOTE: %s/ACTIVE is a v1 pointer and is no longer read — delete it (live = dir with state.md, closed = moved to _archive/).' "$b"
  done
}
