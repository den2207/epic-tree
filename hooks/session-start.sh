#!/bin/bash
# epic-tree SessionStart hook. One live epic under the cwd → inject its charter +
# state + ledger index. Several → inject a roster; the epic is then selected by the
# user's message (see user-prompt-submit.sh). Silent (exit 0, no output) otherwise.
set -u
command -v python3 >/dev/null 2>&1 || exit 0
. "$(dirname "$0")/lib.sh"

input=$(cat)
cwd=$(printf '%s' "$input" | json_field cwd)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
start=$(map_worktree "$cwd")

if [ -n "${EPIC_TREE_ROOT:-}" ] && [ -z "$(epics_base "$EPIC_TREE_ROOT")" ]; then
  emit SessionStart "epic-tree: EPIC_TREE_ROOT=$EPIC_TREE_ROOT has no epics/ dir (nor legacy .claude/epics/) — unset or fix it."
  exit 0
fi

bases=()
while IFS= read -r b; do [ -n "$b" ] && bases+=("$b"); done < <(find_bases "$start")
[ ${#bases[@]} -gt 0 ] || exit 0

dirs=()
while IFS= read -r d; do [ -n "$d" ] && dirs+=("$d"); done < <(all_live_dirs "${bases[@]}")
note=$(stale_active_note "${bases[@]}")

if [ ${#dirs[@]} -eq 1 ]; then
  d=${dirs[0]}
  header="[epic-tree] active epic: $(basename "$d") @ $d (the only live epic under $(dirname "${bases[0]}"), resolved from cwd $cwd).$note Follow the charter Non-negotiables; run the epic-start skill before working."
  emit SessionStart "$(epic_context "$d" "$header")"
else
  emit SessionStart "$(roster "${bases[@]}")$note"
fi
exit 0
