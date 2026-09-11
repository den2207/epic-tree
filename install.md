# Install

One command (clone anywhere you like, then run the installer):

```bash
git clone https://github.com/den2207/epic-tree.git ~/epic-tree && ~/epic-tree/install.sh
```

`install.sh` is idempotent: it symlinks the three skills into `~/.claude/skills`,
registers the SessionStart hook in `~/.claude/settings.json` (updates the path on
re-run, never duplicates), and runs the full smoke suite. Restart Claude Code
sessions afterwards. Requirements: `bash`, `git` ≥ 2.31, `python3`.

Everything below is the manual equivalent — for reference or unusual setups.

## 1. Skills

```bash
mkdir -p ~/.claude/skills
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

Or merge it automatically (run from the clone root; appends without touching your
other settings):

```bash
python3 -c "
import json, os, pathlib
p = pathlib.Path.home()/'.claude'/'settings.json'
s = json.loads(p.read_text()) if p.exists() else {}
for ev, sh in (('SessionStart','session-start.sh'),('UserPromptSubmit','user-prompt-submit.sh')):
    h = {'type':'command','command':'bash '+os.getcwd()+'/hooks/'+sh,'timeout':15,'statusMessage':'epic-tree'}
    s.setdefault('hooks',{}).setdefault(ev,[]).append({'hooks':[h]})
p.write_text(json.dumps(s, indent=2))
"
```

Both hooks are silent (no output, exit 0) unless a session starts under an epic root
or a misconfiguration needs surfacing (bad `EPIC_TREE_ROOT`, stale v1 `ACTIVE`,
incomplete scaffold) — safe to keep enabled globally.

Requirements: `bash`, `git` ≥ 2.31, `python3` (used for JSON in/out; the hook exits
silently if missing).

## 3. Smoke test

```bash
printf '{"cwd":"%s"}' "$HOME" | bash hooks/session-start.sh
```

Expected: empty output (no `epics/` dir with a live epic above `$HOME`). Then create a throwaway epic
dir with `epic-new` in a project and start a new session there — the epic banner,
charter, and state should appear in the session context.

## 4. Quick demo (no real epic needed)

Fake a minimal epic and run the hook against it — takes under a minute:

```bash
demo=$(mktemp -d)/group
mkdir -p "$demo/epics/demo"
printf '# charter — demo\n\n## Non-negotiables\n- demo rule\n' > "$demo/epics/demo/charter.md"
printf '# state — demo\n\n## Active slice\nS-01 hello\n' > "$demo/epics/demo/state.md"
printf '{"cwd":"%s"}' "$demo" | bash hooks/session-start.sh
```

Expected: one JSON line whose `additionalContext` starts with
`[epic-tree] active epic: demo @ …` followed by the charter and state. Starting a
real Claude Code session with that dir as cwd injects the same context automatically.
For the full lifecycle (scaffold → work → handoff), use the three skills on a real
plan; templates live in `templates/`. The full scenario matrix: `bash tests/smoke.sh`.

## Override

`EPIC_TREE_ROOT=<dir>` forces the epic root (must contain `epics/`, or the legacy
`.claude/epics/`), bypassing worktree mapping and the walk-up. With one live epic
there its full context is injected; with several, the roster — and the user's message
selects the epic exactly as without the override.
