#!/bin/bash
# epic-tree: list every live epic under the given roots (default: cwd), newest
# first, with kickoff phrase and active step. Live = a dir under some epics/ with
# state.md or charter.md, not under _archive/. Nested epics/ dirs are reported
# separately so strays can be consolidated into the group root.
set -u
. "$(dirname "$0")/../hooks/lib.sh"

roots=("$@")
[ ${#roots[@]} -eq 0 ] && roots=("$PWD")

found=""
for r in "${roots[@]}"; do
  r=${r%/}
  [ -d "$r" ] || { echo "epic-list: no such directory: $r" >&2; continue; }
  while IFS= read -r base; do
    root=$(dirname "$base")
    case $base in */.claude/epics) root=$(dirname "$root");; esac
    n=$(live_epics "$base" | grep -c .)
    printf '%s  (%s live)\n' "$root" "$n"
    [ -f "$base/ACTIVE" ] && printf '    STALE: %s/ACTIVE is a v1 pointer, no longer read — delete it\n' "$base"
    while IFS=$'\t' read -r ts slug dir; do
      [ -n "$slug" ] || continue
      printf '  %-28s updated %s\n' "$slug" "${ts:-—}"
      k=$(epic_kickoff "$dir"); s=$(epic_step "$dir")
      printf '      kickoff: %s\n' "${k:-(none)}"
      [ -n "$s" ] && printf '      step:    %s\n' "$s"
    done < <(while IFS= read -r s; do [ -n "$s" ] && printf '%s\t%s\t%s\n' "$(epic_updated "$base/$s")" "$s" "$base/$s"; done < <(live_epics "$base") | sort -r)
    found=1
  done < <(find "$r" -maxdepth 5 \( -name node_modules -o -name .git -o -name DerivedData -o -name _archive \) -prune -o -type d \( -path '*/epics' -o -path '*/.claude/epics' \) -print 2>/dev/null | sort)
done

[ -n "$found" ] || echo "no epics/ dirs found up to 5 levels below: ${roots[*]}"
