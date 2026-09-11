#!/bin/bash
# One-command install: skills symlinks + SessionStart/UserPromptSubmit hooks + smoke test.
# Idempotent — re-running updates paths in place and never duplicates the hook.
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)

command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "error: git is required" >&2; exit 1; }

mkdir -p ~/.claude/skills
for s in epic-new epic-start epic-handoff; do
  ln -sfn "$repo/skills/$s" ~/.claude/skills/"$s"
done
echo "✓ skills linked into ~/.claude/skills: epic-new, epic-start, epic-handoff"

python3 - "$repo" <<'EOF'
import json, sys, pathlib
repo = sys.argv[1]
hooks = {"SessionStart": "session-start.sh", "UserPromptSubmit": "user-prompt-submit.sh"}
p = pathlib.Path.home() / ".claude" / "settings.json"
s = json.loads(p.read_text()) if p.exists() else {}
for event, script in hooks.items():
    entry = {"type": "command", "command": f"bash {repo}/hooks/{script}",
             "timeout": 15, "statusMessage": "epic-tree"}
    groups = s.setdefault("hooks", {}).setdefault(event, [])
    ours = [h for g in groups for h in g.get("hooks", [])
            if h.get("statusMessage") == "epic-tree" or "epic-tree" in h.get("command", "")]
    if ours:
        ours[0].update(entry)
        print(f"✓ {event} hook already present — path refreshed in {p}")
    else:
        groups.append({"hooks": [entry]})
        print(f"✓ {event} hook registered in {p}")
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(s, indent=2) + "\n")
EOF

bash "$repo/tests/smoke.sh"

echo
echo "Done. Restart Claude Code sessions to pick up the hook and skills."
