#!/bin/bash
# epic-tree: list every epic under the given roots (default: cwd) with its
# active step. The third ingredient of the ambient-pointer pattern: ACTIVE is
# the pointer, EPIC_TREE_ROOT the override, this is the `list/status` view.
set -u
LC_ALL=C
export LC_ALL

roots=("$@")
[ ${#roots[@]} -eq 0 ] && roots=("$PWD")

found=""
for r in "${roots[@]}"; do
  r=${r%/}
  [ -d "$r" ] || { echo "epic-list: no such directory: $r" >&2; continue; }
  while IFS= read -r active; do
    base=$(dirname "$active")
    root=$(dirname "$base")
    case $base in */.claude/epics) root=$(dirname "$root");; esac
    slug=$(head -n1 "$active" | tr -d '[:space:]')
    epic_dir="$base/$slug"
    if [ -z "$slug" ] || [ ! -d "$epic_dir" ]; then
      printf '%s  @ %s\n    BROKEN ACTIVE (epic dir missing)\n' "${slug:-<empty>}" "$root"
      continue
    fi
    updated=""
    step=""
    if [ -f "$epic_dir/state.md" ]; then
      updated=$(grep -m1 '^updated:' "$epic_dir/state.md" | cut -c1-100)
      step=$(awk '/^## Active slice/{f=1;next} f&&NF{print;exit}' "$epic_dir/state.md" | cut -c1-160)
    fi
    printf '%s  @ %s\n' "$slug" "$root"
    [ -n "$step" ] && printf '    %s\n' "$step"
    [ -n "$updated" ] && printf '    %s\n' "$updated"
    # Shadow check: another ACTIVE strictly above this root wins nothing —
    # this nested one shadows it for every session under $root.
    d=$(dirname "$root")
    while [ "$d" != "$HOME" ] && [ "$d" != "/" ] && [ -n "$d" ]; do
      for cand in "$d/epics/ACTIVE" "$d/.claude/epics/ACTIVE"; do
        if [ -f "$cand" ]; then
          printf '    SHADOWS: epic %s @ %s (nearest ACTIVE wins under %s)\n' \
            "$(head -n1 "$cand" | tr -d '[:space:]')" "$d" "$root"
          d=/
          break
        fi
      done
      [ "$d" = "/" ] || d=$(dirname "$d")
    done
    found=1
  done < <(find "$r" -maxdepth 5 \( -name node_modules -o -name .git -o -name DerivedData \) -prune -o -type f -path '*/epics/ACTIVE' -print 2>/dev/null | sort)
done

[ -n "$found" ] || echo "no epics found (looked for epics/ACTIVE up to 5 levels below: ${roots[*]})"
