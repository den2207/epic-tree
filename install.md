# Install

Manual install (symlinks), until this ships as a Claude Code plugin.

## 1. Skills

```bash
for s in epic-new epic-start epic-handoff; do
  ln -sfn "$(pwd)/skills/$s" ~/.claude/skills/$s
done
```

New sessions list the three skills immediately (user-level skills are visible from
session start, unlike repo-scoped ones).

## 2. SessionStart hook

Add to the `hooks` object in `~/.claude/settings.json` (path adjusted to your clone):

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash ~/Personal/epic-tree/hooks/session-start.sh",
        "timeout": 15,
        "statusMessage": "epic-tree"
      }
    ]
  }
]
```

The hook is silent (no output, exit 0) unless a session starts inside an epic root —
so it is safe to keep enabled globally.

Requirements: `bash`, `git` ≥ 2.31, `python3` (used for JSON in/out; the hook exits
silently if missing).

## 3. Smoke test

```bash
printf '{"cwd":"%s"}' "$HOME" | bash hooks/session-start.sh
```

Expected: empty output (no ACTIVE epic above `$HOME`). Then create a throwaway epic
dir with `epic-new` in a project and start a new session there — the epic banner,
charter, and state should appear in the session context.

## Override

`EPIC_TREE_ROOT=<dir>` forces the epic root (must contain `epics/ACTIVE`, or the
legacy `.claude/epics/ACTIVE`), bypassing worktree mapping and the walk-up.
