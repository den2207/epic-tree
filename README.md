# epic-tree

Long-running AI work, rooted: charter, state, and evidence that survive every
session, agent, and compaction. Built for Claude Code (hook + skills), readable
by any agent via [AGENTS.md](https://agents.md).

## The problem

A big epic spans many chat sessions. Task trackers remember *what's left*, but every
new session still loses the **operational context**: which model runs which role,
permission boundaries, agreed approaches, known traps, and where the work actually
stands.

### Before

Every handoff is hand-written, and every session re-learns the epic from scratch:

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 30, "rankSpacing": 36}}}%%
flowchart LR
    S1["session 1"] -- "hand-written<br/>handoff prompt" --> S2["session 2"]
    S2 -- "stale kickoff" --> S3["session 3"]
    S3 -- "…" --> SN["session N"]
    P["ever-growing plan file"] -.-> S1 & S2 & S3
    S2 -.- X1(["rules re-argued"])
    S3 -.- X2(["blocker re-discovered"])
    SN -.- X3(["evidence lost"])
    style X1 fill:none,stroke:#d66,stroke-dasharray:3
    style X2 fill:none,stroke:#d66,stroke-dasharray:3
    style X3 fill:none,stroke:#d66,stroke-dasharray:3
```

### After

The epic lives in files with fixed roles; hooks inject them into every new session
automatically — the handoff prompt as a genre disappears:

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 30, "rankSpacing": 36}}}%%
flowchart TD
    subgraph epic ["epics/&lt;slug&gt;/"]
        C["charter.md — rules, roles"] ~~~ ST["state.md — where we are"]
        ST ~~~ L["ledger.md — known facts"] ~~~ J["journal/ — session log"]
    end
    epic -- "auto-injected at session start" --> S(["new session"])
    S -- "epic-handoff: journal + state.md rewrite" --> epic
```

Two physically separate context classes make this safe:

| class | files | lifecycle |
|---|---|---|
| stable operational layer | `charter.md`, `ledger.md` | written once / append-only; auto-injected every session |
| live state | `state.md` (overwrite-only), `journal/` (append-only per session) | rewritten at each handoff by a single writer |

With one live epic under the cwd, every session gets its full context at start. With
several, the session gets a roster (slug, last update, kickoff phrase — ~300 tokens),
and the user's first message selects the epic by naming its slug: a `UserPromptSubmit`
hook then injects that epic's full context. Selection is a mechanism, not a rule the
model has to remember.

## Anatomy of an epic

```
<root>/epics/
  _archive/<slug>/          # closed epics — moved here, no longer live
  <slug>/                   # live epic: any dir here with a state.md
    charter.md              # non-negotiables, roles (agent/model/effort), repo topology
    plan.md                 # slice table: S-NN | slice | verify | status | evidence
    state.md                # where we are; coordinator-only, max 40 lines
    ledger.md               # L-NN stable facts: known blockers, non-regressions, gotchas
    gated-actions.md        # G-NN queue of human-only actions (open + this session's)
    gated-actions.ARCHIVE.md# closed G-NN blocks, moved here at handoff
    journal/                # <date>-<HHMM>-<role>.md, one per session
```

`<root>` is the directory spanning every repo the epic touches — typically a group
dir containing several repos. The hooks resolve it from any cwd: linked git worktrees
map back to their main checkout, then a walk-up collects every `epics/` dir above
(never considering `$HOME` itself). There is no pointer file: a directory with a
`state.md` is live, a directory under `_archive/` is closed.

`epics/` is deliberately visible and vendor-neutral — not a `.claude/` or tool-named
dot-dir. These files are project content that humans and every agent read each
session, so they follow the visible-content convention of Spec Kit's `specs/` and
Cline's `memory-bank/` rather than the hidden tool-internals pattern. Epics created
under the legacy `.claude/epics/` path keep working — the hook falls back to it.

## Session lifecycle

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 30, "rankSpacing": 36}}}%%
flowchart TD
    A["epic-new<br/>scaffold from an approved plan"] --> B["state.md exists — epic is live"]
    B --> C["session starts anywhere under &lt;root&gt;"]
    C --> D["one live epic: hook injects charter + state<br/>several: roster, then the first message<br/>names the slug and the prompt hook injects it"]
    D --> E["epic-start<br/>reconcile state vs git reality"]
    E --> F["work the active slice<br/>evidence into journal"]
    F --> G["epic-handoff<br/>journal → ledger → gates → statuses → state.md LAST"]
    G --> C
    G -- "all slices done<br/>with evidence" --> H["epic closed:<br/>dir moved to _archive/"]
```

- **epic-new** — scaffold an epic from an approved plan; refuses to finish without a
  verify command per slice and a roles/model table.
- **epic-start** — session kickoff: reconcile injected state against `git` reality
  across ALL topology repos, detect dead sessions (commits without journal entries),
  confirm role and nearest stop-gate.
- **epic-handoff** — session close: journal first, ledger/gates/statuses next
  (coordinator only), `state.md` rewritten LAST as the crash-safe commit marker,
  including a `## Map` — a cheap ASCII picture of every slice (done / in progress /
  blocked / todo) with one `<- NEXT` marker and an `After:` line — and a concrete
  `kickoff:` phrase. The closing chat message repeats the map and ends with one
  sentence: which directory to open the next chat in and what to paste as its first
  message — it names the slug and next step, so chat titles stop being generic.

## Multiple epics

Any number of epics can be live under one root — a group-wide one, a repo-scoped one
and a third for a sub-group repo all sit in the same `epics/` dir and differ only in
their charter topology. Nothing is shared between them, so parallel sessions on
different epics never race. Per session the selection goes:

```
epics/                          new chat, cwd anywhere under <root>
  payments/   state.md            │ SessionStart: 3 live → roster (slug · updated · kickoff)
  icons/      state.md            │ user pastes:  "epic icons: S-3 export pipeline"
  onboarding/ state.md            │ UserPromptSubmit: names `icons` → inject icons' charter + state
  _archive/legacy-cleanup/        ▼ epic-start, work, epic-handoff → state.md + kickoff for next time
```

A message naming two slugs injects nothing and asks for one; a message naming none
means the session is not epic work. Nested `<repo>/epics/` dirs are merged into the
roster of sessions below them, but one `epics/` at the group root keeps the roster in
one place. `EPIC_TREE_ROOT=<dir>` forces a specific root from any cwd.

Visibility: `bin/epic-list.sh [root…]` prints every live epic below a root with its
last update, kickoff phrase and active step, and flags stray v1 `ACTIVE` files.

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
  survives. Because those tools stop AGENTS.md discovery at a repo's own git root
  (and a group root is usually not a git repo), `epic-new` also drops an untracked
  stub `AGENTS.md` into each member repo that has none (kept out of git via
  `.git/info/exclude`), pointing one level up. Orchestrators additionally embed
  the Non-negotiables block in every executor prompt regardless of tool.

## Testing

```bash
bash tests/smoke.sh
```

Sixteen hermetic scenarios (temp-dir fixtures, no setup): single-epic injection from
the root and from a repo below it, `_archive/` exclusion, roster order and kickoff
lines, prompt selection (one slug, none, several, whole-word matching), UTF-8-safe
truncation of an oversized charter, nested `epics/` merging, stale v1 `ACTIVE`
flagging, the `EPIC_TREE_ROOT` override, and `epic-list`. Run it after any change
under `hooks/`.

## Install

```bash
git clone https://github.com/den2207/epic-tree.git ~/epic-tree && ~/epic-tree/install.sh
```

Idempotent: links the skills, registers both hooks, runs the smoke suite. Details and
the manual path: [install.md](install.md). Rationale and the review that shaped the
design: [docs/design.md](docs/design.md).

## Roadmap

A local MCP server exposing `get_active_slice` / `record_evidence` / `next_gate`
would turn the write discipline from prose rules into code-enforced tools for any
MCP-capable agent — see the ecosystem sweep in [docs/design.md](docs/design.md).

## License

MIT
