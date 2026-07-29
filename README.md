# epic-harness

Context-persistent execution of large, multi-session tasks in Claude Code.

## The problem

A big epic spans many chat sessions. Task trackers remember *what's left*, but every
new session still loses the **operational context**: which model runs which role,
permission boundaries, agreed approaches, known traps, and where the work actually
stands. The usual workaround — an ever-growing plan file plus a hand-written handoff
prompt per session — degrades fast: stale kickoffs, re-discovered blockers,
re-argued rules.

## The idea

Split epic context into two physically separate classes:

| class | files | lifecycle |
|---|---|---|
| stable operational layer | `charter.md`, `ledger.md` | written once / append-only; auto-injected every session |
| live state | `state.md` (overwrite-only), `journal/` (append-only per session) | rewritten at each handoff by a single writer |

A `SessionStart` hook injects the active epic's charter, state, and ledger index into
every new session automatically — the handoff prompt as a genre disappears.

## Anatomy of an epic

```
<root>/.claude/epics/
  ACTIVE                    # first line: slug; then one repo name per line
  <slug>/
    charter.md              # non-negotiables, roles (agent/model/effort), repo topology
    plan.md                 # slice table: S-NN | slice | verify | status | evidence
    state.md                # where we are; coordinator-only, max 40 lines
    ledger.md               # L-NN stable facts: known blockers, non-regressions, gotchas
    gated-actions.md        # G-NN queue of human-only actions
    journal/                # <date>-<HHMM>-<role>.md, one per session
```

`<root>` is the directory spanning every repo the epic touches — typically a group
dir containing several repos. The hook resolves it from any cwd: linked git worktrees
map back to their main checkout, then a walk-up finds the nearest `ACTIVE`
(never considering `$HOME` itself). Sessions in repos the epic doesn't list are left
untouched.

## Skills

- **epic-new** — scaffold an epic from an approved plan; refuses to finish without a
  verify command per slice and a roles/model table.
- **epic-start** — session kickoff: reconcile injected state against `git` reality
  across ALL topology repos, detect dead sessions (commits without journal entries),
  confirm role and nearest stop-gate.
- **epic-handoff** — session close: journal first, ledger/gates/statuses next
  (coordinator only), `state.md` rewritten LAST as the crash-safe commit marker.

## Design rules that earn their keep

- **Single writer**: only the coordinator rewrites `state.md`; executors write their
  own journal file and propose changes there.
- **Evidence discipline**: a slice status flips to `done` only with a verify-command
  output or commit hash in the `evidence` column.
- **Ledger over re-proving**: known blockers and non-regressions get an `L-NN` ID once
  and are referenced, not re-derived, by later sessions.
- **Tool-agnostic files**: fixed sections, stable IDs, one fact per line, a
  `contract:` line in every file — any AI executor (not just Claude) can consume them;
  the charter's Non-negotiables block is designed to be embedded verbatim in any
  executor prompt.

## Install

See [install.md](install.md). Rationale and the review that shaped the design:
[docs/design.md](docs/design.md).

## License

MIT
