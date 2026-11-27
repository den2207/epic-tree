#!/bin/bash
# epic-tree Stop / SessionEnd hook: keep the session marker EpicBar reads in step with
# the session. usage: session-mark.sh idle|end  (hook JSON on stdin)
set -u
command -v python3 >/dev/null 2>&1 || exit 0
. "$(dirname "$0")/lib.sh"

sid=$(json_field session_id)
dir=$(session_epic "$sid")
[ -n "$dir" ] || exit 0
marker=$SESSIONS_DIR/$sid

# A state.md newer than the marker means this turn ran epic-handoff: the session let go of the epic.
if [ "${1:-}" = end ] || [ "$dir/state.md" -nt "$marker" ]; then
  rm -f "$marker"
else
  session_mark "$sid" "$dir" idle
fi
exit 0
