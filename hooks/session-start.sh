#!/bin/bash
# epic-tree SessionStart hook: injects the active epic's charter + state + ledger
# index as additionalContext. Silent (exit 0, no output) when no epic applies.
set -u
LC_ALL=C
export LC_ALL

command -v python3 >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("cwd",""))
except Exception: pass' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD

emit() {
  printf '%s' "$1" | python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))'
}

# Canonical epics dir is <root>/epics/; <root>/.claude/epics/ is the pre-rename
# legacy location, still honored so existing epics keep working.
epics_base() {
  if [ -f "$1/epics/ACTIVE" ]; then printf '%s/epics' "$1"
  elif [ -f "$1/.claude/epics/ACTIVE" ]; then printf '%s/.claude/epics' "$1"
  fi
}

# Worktree-aware start point: map a linked worktree back to its main checkout.
start=$cwd
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
[ -n "$common" ] && start=$(dirname "$common")

# Nearest ACTIVE wins; never consider $HOME itself or /.
root=""
base=""
forced=""
if [ -n "${EPIC_TREE_ROOT:-}" ]; then
  base=$(epics_base "$EPIC_TREE_ROOT")
  if [ -n "$base" ]; then
    root=$EPIC_TREE_ROOT
    forced=1
  else
    emit "epic-tree: EPIC_TREE_ROOT=$EPIC_TREE_ROOT has no epics/ACTIVE (nor legacy .claude/epics/ACTIVE) — unset or fix it."
    exit 0
  fi
else
  d=$start
  while [ "$d" != "$HOME" ] && [ "$d" != "/" ]; do
    base=$(epics_base "$d")
    if [ -n "$base" ]; then root=$d; break; fi
    d=$(dirname "$d")
  done
fi
[ -n "$root" ] || exit 0

active="$base/ACTIVE"
slug=$(head -n1 "$active" | tr -d '[:space:]')
if [ -z "$slug" ] || [ ! -d "$base/$slug" ]; then
  emit "epic-tree: broken ACTIVE at $active (epic dir for '$slug' not found) — fix or remove it."
  exit 0
fi

# Membership gate: a session inside a repo the epic does not list stays untouched.
# Skipped when the root was forced via EPIC_TREE_ROOT.
if [ -z "$forced" ] && [ "$start" != "$root" ]; then
  rel=${start#"$root"/}
  repo=${rel%%/*}
  repos=$(tail -n +2 "$active" | tr -d ' ')
  if [ -n "$repos" ] && ! printf '%s\n' "$repos" | grep -qx "$repo"; then
    exit 0
  fi
fi

epic_dir="$base/$slug"
charter=""; state=""; lindex=""
[ -f "$epic_dir/charter.md" ] && charter=$(cat "$epic_dir/charter.md")
[ -f "$epic_dir/state.md" ] && state=$(cat "$epic_dir/state.md")
[ -f "$epic_dir/ledger.md" ] && lindex=$(grep -E '^\| L-[0-9]+' "$epic_dir/ledger.md" | cut -c1-160 || true)
if [ -z "$charter$state" ]; then
  emit "epic-tree: epic '$slug' at $epic_dir has no charter.md/state.md — scaffold incomplete."
  exit 0
fi

header="[epic-tree] active epic: $slug @ $epic_dir (resolved from cwd $cwd). Follow the charter Non-negotiables; run the epic-start skill before working."
budget=9000

assemble() {
  printf '%s\n\n===== charter.md =====\n%s\n\n===== state.md =====\n%s' "$header" "$charter" "$state"
  [ -n "$lindex" ] && printf '\n\n===== ledger index (full file: %s/ledger.md) =====\n%s' "$epic_dir" "$lindex"
  return 0
}

ctx=$(assemble)
if [ ${#ctx} -gt $budget ]; then
  lindex=""
  ctx=$(assemble)
fi
if [ ${#ctx} -gt $budget ]; then
  header="$header [TRUNCATED to fit the 9k additionalContext budget — read $epic_dir/charter.md fully before relying on it]"
  keep=$(( budget - ${#header} - ${#state} - 200 ))
  [ "$keep" -lt 0 ] && keep=0
  charter=$(printf '%s' "$charter" | head -c "$keep")
  ctx=$(assemble)
fi
emit "$ctx"
exit 0
