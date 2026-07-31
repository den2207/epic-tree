# epic-tree

Long-running AI work, rooted: charter, state, and evidence that survive every
session, agent, and compaction. Built for Claude Code (hook + skills), readable
by any agent via AGENTS.md.

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
<root>/epics/
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

`epics/` is deliberately visible and vendor-neutral — not a `.claude/` or tool-named
dot-dir. These files are project content that humans and every agent read each
session, so they follow the visible-content convention of Spec Kit's `specs/` and
Cline's `memory-bank/` rather than the hidden tool-internals pattern. Epics created
under the legacy `.claude/epics/` path keep working — the hook falls back to it.

## Multiple epics

One `ACTIVE` — one active epic per root; the hook injects exactly one context per
session. Ways to run several epics concurrently:

- **Different groups** — fully independent; each root has its own `epics/ACTIVE`.
- **Group + repo** — the nearest `ACTIVE` wins on the walk-up, so a repo-scoped epic
  (`<repo>/epics/ACTIVE`) can run inside a group that has its own group-level epic:
  sessions in that repo get the repo epic, the rest of the group gets the group epic.
- **Per-terminal override** — `EPIC_TREE_ROOT=<dir>` forces a specific root.

Two epics sharing the same repo at the same level are deliberately unsupported: one
session gets one charter (the 9k injection budget) and one single-writer state.

## Skills

- **epic-new** — scaffold an epic from an approved plan; refuses to finish without a
  verify command per slice and a roles/model table.
- **epic-start** — session kickoff: reconcile injected state against `git` reality
  across ALL topology repos, detect dead sessions (commits without journal entries),
  confirm role and nearest stop-gate.
- **epic-handoff** — session close: journal first, ledger/gates/statuses next
  (coordinator only), `state.md` rewritten LAST as the crash-safe commit marker,
  including a concrete `kickoff:` line the human pastes to open the next session —
  it names the slug and next step, so chat titles stop being generic.

## Design rules that earn their keep

- **Single writer**: only the coordinator rewrites `state.md`; executors write their
  own journal file and propose changes there.
- **Evidence discipline**: a slice status flips to `done` only with a verify-command
  output or commit hash in the `evidence` column.
- **Ledger over re-proving**: known blockers and non-regressions get an `L-NN` ID once
  and are referenced, not re-derived, by later sessions.
- **Tool-agnostic files, Claude Code adapters**: the epic files are plain
  markdown with fixed sections, stable IDs, and a `contract:` line each — any AI agent
  can consume them. The hook and the three skills are the *Claude Code adapter*;
  non-Claude agents (Codex, Cursor, Copilot CLI, …) self-discover the epic via the
  generated `AGENTS.md` at the epic root ([the cross-tool standard](https://agents.md)),
  which carries the bootstrap: read charter Non-negotiables verbatim, read state +
  active slice, create your own journal file, respect the write discipline of your
  role. The generated content sits inside `BEGIN/END epic-tree adapter` markers,
  so regeneration replaces only its own block and hand-written AGENTS.md content
  survives. Orchestrators additionally embed the Non-negotiables block in every
  executor prompt regardless of tool.

## Roadmap

A local MCP server exposing `get_active_slice` / `record_evidence` / `next_gate`
would turn the write discipline from prose rules into code-enforced tools for any
MCP-capable agent — see the ecosystem sweep in [docs/design.md](docs/design.md).

## Install

See [install.md](install.md). Rationale and the review that shaped the design:
[docs/design.md](docs/design.md).

## License

MIT
