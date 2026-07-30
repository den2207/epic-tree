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

## 4. Quick demo (no real epic needed)

Fake a minimal epic and run the hook against it — takes under a minute:

```bash
demo=$(mktemp -d)/group
mkdir -p "$demo/epics/demo"
printf 'demo\n' > "$demo/epics/ACTIVE"
printf '# charter — demo\n\n## Non-negotiables\n- demo rule\n' > "$demo/epics/demo/charter.md"
printf '# state — demo\n\n## Active slice\nS-01 hello\n' > "$demo/epics/demo/state.md"
printf '{"cwd":"%s"}' "$demo" | bash hooks/session-start.sh
```

Expected: one JSON line whose `additionalContext` starts with
`[epic-tree] active epic: demo @ …` followed by the charter and state. Starting a
real Claude Code session with that dir as cwd injects the same context automatically.
For the full lifecycle (scaffold → work → handoff), use the three skills on a real
plan; templates live in `templates/`.

## Override

`EPIC_TREE_ROOT=<dir>` forces the epic root (must contain `epics/ACTIVE`, or the
legacy `.claude/epics/ACTIVE`), bypassing worktree mapping and the walk-up.
