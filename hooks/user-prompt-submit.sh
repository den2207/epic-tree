#!/bin/bash
# epic-tree UserPromptSubmit hook: when the user's message names exactly one live
# epic's slug (as a whole word), inject that epic's charter + state + ledger index.
# This is the selection mechanism — the epic is chosen by the message, not by the
# cwd or a pointer file. Silent (exit 0, no output) when no slug is named.
set -u
command -v python3 >/dev/null 2>&1 || exit 0
. "$(dirname "$0")/lib.sh"

input=$(cat)
prompt=$(printf '%s' "$input" | json_field prompt)
[ -n "$prompt" ] || exit 0
cwd=$(printf '%s' "$input" | json_field cwd)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
start=$(map_worktree "$cwd")

bases=()
while IFS= read -r b; do [ -n "$b" ] && bases+=("$b"); done < <(find_bases "$start")
[ ${#bases[@]} -gt 0 ] || exit 0

# Nearest base wins for a slug present in several bases (all_live_dirs is nearest-first).
matches=()
seen=" "
while IFS= read -r d; do
  [ -n "$d" ] || continue
  slug=$(basename "$d")
  case $seen in *" $slug "*) continue;; esac
  seen="$seen$slug "
  if printf '%s' "$prompt" | grep -qiE "(^|[^A-Za-z0-9_-])${slug}([^A-Za-z0-9_-]|\$)"; then
    matches+=("$d")
  fi
done < <(all_live_dirs "${bases[@]}")

case ${#matches[@]} in
  0) exit 0;;
  1)
    d=${matches[0]}
    header="[epic-tree] epic selected by this message: $(basename "$d") @ $d. Follow the charter Non-negotiables; run the epic-start skill before working. If this epic is already the one in progress in this session, treat this as a state resync (state.md may have been rewritten by another session's handoff)."
    emit UserPromptSubmit "$(epic_context "$d" "$header")";;
  *)
    names=""
    for d in "${matches[@]}"; do names="$names $(basename "$d")"; done
    emit UserPromptSubmit "[epic-tree] this message names several live epics:$names — nothing injected. Ask the user to name exactly one; do not pick.";;
esac
exit 0
