# Design rationale

## Where this comes from

Observed across ~13 handoffs of one real epic (and a second epic with the same
pattern): a master plan file grew to ~1700 lines, alternating "session N outcome" /
"kickoff for session N+1" sections, each tagged "priority over everything above".
Concrete, repeated losses:

- model-per-role routing retyped into nearly every kickoff prompt;
- account-safety boundaries re-argued verbatim across consecutive sessions;
- known infra blockers re-discovered as "new findings" despite being documented;
- two sessions independently recording the same WRONG conclusion the ledger now
  prevents (a tooling-visibility gotcha);
- a dead kickoff section grabbed by a fresh session reading top-down;
- baseline test failures re-proven "not a regression" per session.

Root cause: stable rules and live state lived in the same append-only document, so
stable facts kept getting re-derived and the "current truth" pointer was a manually
maintained convention.

## Landscape (July 2026)

No existing tool carries the operational half. Task/state trackers (Beads,
claude-task-master) are excellent at "what's left" but have no notion of model
routing, permissions, or agreed approaches. Spec-phase tools (GitHub Spec Kit,
OpenSpec) structure *what* to build, not *how to operate*. claude-handoff captures
session state but explicitly not operational rules. Anthropic's guidance for
long-running agents (initializer agent + progress file + pass/fail feature list)
is the closest reference architecture and shaped the evidence discipline here.

Ideas deliberately borrowed:
- pass/fail-only status flips with evidence (Anthropic's feature-list pattern) —
  folded into plan.md's slice table instead of a separate JSON to keep ONE id space;
- "failed approaches / decisions" journal fields (claude-handoff);
- conventions-as-skills (Agent OS);
- phase separation of plan → slices (Spec Kit).

## Decisions worth explaining

**Two context classes (charter/ledger vs state/journal).** The stable layer is
auto-injected every session and almost never written; the live layer is rewritten at
every handoff by a single writer. Mixing them is what made the old plan files rot.

**Group-level epic root + membership gate.** Epics span several repos, so the epic
dir lives in the directory that spans them. The ACTIVE file lists the epic's repos;
sessions inside a sibling repo that is NOT listed get nothing injected — one group
can host unrelated projects safely. Nested ACTIVEs resolve nearest-first.

**Worktree mapping via `git rev-parse --path-format=absolute --git-common-dir`.**
Linked worktrees live outside the group tree; a naive cwd walk-up never finds the
epic. The common-dir (always absolute via `--path-format`) points into the main
checkout's `.git`; its dirname is the main checkout. Empirically verified — the
common-dir output is otherwise relative and inconsistent with plain `rev-parse`.
Note the remap runs for ANY git cwd, not only worktrees: it collapses the start
point to the repo's top level before the walk-up, which is what makes sessions in
repo subdirectories resolve to the repo's own epic. Known blind spot, accepted:
inside a git submodule the common-dir points into `<super>/.git/modules/`, so the
membership gate misfires — none of the target repos use submodules.

**state.md written LAST at handoff.** The handoff order is journal → ledger/gates →
statuses → state. A crash mid-handoff leaves state pointing at the previous
consistent snapshot, and the next epic-start reconciles against git (commits with no
journal entry = red flag for a dead session).

**9k-char injection budget.** `additionalContext` is hard-capped at 10k characters;
the hook drops the ledger index first, then truncates the charter tail with an
explicit warning — state is never truncated.

**Prose discipline, honestly labeled.** Single-writer and evidence rules are
guardrails the skills self-check, not OS-level enforcement; epic-start detects
foreign `updated:` writers after the fact. This is stated plainly rather than
dressed up as a mechanism.

**Migration protocol for live epics.** Old plan files are renamed `*.ARCHIVED.md`
with a banner pointing to the epic dir; uncertain statuses default to `todo`; the
human reviews the migrated epic and writes ACTIVE themselves.

## Prompting-guide alignment (2026-07)

Audited against Anthropic's model-specific guides —
[prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)
and [prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5).
The evidence-grounding, short imperative guardrails, explicit do/don't boundaries, and
the ledger's "one lesson per entry, reference don't re-derive" pattern match the
guides directly; the autonomy-contract template reuses their pause-only-for
(irreversible / scope change / user-only input) phrasing. Deliberately absent, per the
guides: narrative self-verification instructions ("double-check") and prescriptive
behavior enumerations — verification here is tool evidence, not prose. If a skill ever
wraps in-session subagents, add delegation-scope caps then (Opus 5 guide).

## Ecosystem sweep (2026-07) and v2 backlog

A second, broader landscape pass after v1 shipped checked whether any cross-agent
convention already covers this niche. None does — but three findings shaped changes:

- [AGENTS.md](https://agents.md) is the real cross-brand standard (Linux Foundation
  governance since late 2025; native readers include Codex, Cursor, Copilot,
  Gemini CLI, Aider, Zed, Windsurf/Devin). It is static-rules-only by design — no
  live state, permissions, or model routing — exactly the half this repo carries.
  Claude Code does NOT read AGENTS.md natively (official workaround: an `@AGENTS.md`
  import or a symlink); irrelevant here, since Claude Code gets the richer hook
  injection instead.
- Config unifiers ([ruler](https://github.com/intellectronica/ruler),
  [rulesync](https://github.com/dyoshikawa/rulesync)) solve the N-native-filenames
  problem with generated files inside managed-block markers. That marker convention
  is borrowed: the AGENTS.md adapter is delimited by `BEGIN/END epic-tree adapter`
  comments, so regeneration replaces its own block and never touches hand-written
  content around it.
- No cross-tool convention exists for per-role model routing in a repo file — every
  tool pins models in its own config (Codex `config.toml`, Claude Code
  `settings.json`). The charter roles table stays the single declaration; the launch
  command of each surface remains the enforcement point.
- **Epic dir renamed `.claude/epics/` → `epics/`** (2026-07, follow-up sweep on
  directory conventions). A vendor dot-dir contradicted the cross-agent story. No
  neutral standard exists to join: `.agents/` is five mutually incompatible drafts
  fighting over one name ([agents.md issue #9](https://github.com/agentsmd/agents.md/issues/9),
  [dotagents](https://github.com/bgreenwell/dotagents),
  [agentsfolder/spec](https://github.com/agentsfolder/spec), …) — nothing ratified by
  the AAIF, which governs only the root file. The closest analogues split hidden
  tool-internals from visible content ([Spec Kit `.specify/` + `specs/`, settled in
  issue #38](https://github.com/github/spec-kit/issues/38);
  [Cline's visible `memory-bank/`](https://docs.cline.bot/best-practices/memory-bank)).
  Epic files are content read every session by humans and agents — and some agents'
  file-globbing skips dotfiles — so the visible, content-named `epics/` wins over
  `.epics/` and over a tool-named dot-dir. The hook keeps a legacy fallback to
  `.claude/epics/`.
- **Project renamed epic-harness → epic-tree** (2026-07-30). The working name
  clashed with the unrelated, active
  [epicsagas/epic-harness](https://github.com/epicsagas/epic-harness) (multi-tool
  agent harness — same pitch), and a naming sweep showed the niche's plain-English
  vocabulary is already claimed by same-space tools (kungfu "Continuity for Agent
  Work", Trellis "the best agent harness", carryover, passdown, throughline, edict).
  `epic-tree` has clean GitHub and npm namespaces and reads natively in dev
  vocabulary: git tree, worktree (the hook is worktree-aware), and the `epics/`
  file tree itself.

Independent validation, no changes needed:
[Cline Memory Bank](https://docs.cline.bot/best-practices/memory-bank) converged on
the same stable/live file split (its documented weaknesses — token cost and staleness
— are what the 9k budget and git reconciliation address), and
[Anthropic's long-running-agent harness](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
converged on evidence-gated progress files.

v2 backlog, deliberately not built yet:

1. **Local MCP server over state/ledger/plan** (`get_active_slice`,
   `record_evidence`, `next_gate`) — turns the single-writer and evidence rules from
   prose guardrails into code-enforced tools any MCP-capable agent can call
   (pattern: [claude-task-master](https://github.com/eyaltoledano/claude-task-master),
   [Beads](https://github.com/steveyegge/beads)). Closes the biggest honest gap
   named under "Prose discipline" above.
2. **Git-mergeable ledger/journal encoding** (Beads-style ID-per-line) — only if
   concurrent executors across worktrees ever append to the same file.
3. **Watch the AGENTS.md spec** for state/permission extensions; `gated-actions.md`
   is a candidate pattern to propose upstream rather than keep proprietary.
4. **Honest multi-active resolution** — today `ACTIVE` names exactly one epic and
   `nearest ACTIVE wins`, so two concurrently active epics can only be expressed by
   planting a repo-level `epics/ACTIVE` plus a symlink to the shared epic dir inside
   each member repo (and excluding `epics/` in `.git/info/exclude`). That pattern
   works — a session in the repo gets the nested epic, the group epic stays intact
   for every other repo, and both `session-start.sh` and `epic-list.sh` report the
   shadowing — but it has four honest gaps: the scaffold is manual (`epic-new` does
   not plant it); a repo can belong to only one active epic; lines 2+ of a
   repo-level `ACTIVE` are inert, because the membership gate only fires when
   `start != root` and the worktree mapping makes those equal inside any git repo,
   so the repo list reads like a promise the hook never checks; and the shadowed
   epic is named in the banner but its gates and non-negotiables are never injected,
   so a session can be inside two live epics while seeing one. A real fix accepts a
   set of slugs (multi-line `ACTIVE` or `ACTIVE.d/`), resolves membership per repo
   across all of them, and splits the 9k budget over the epics that actually match.

## Review provenance

The v1 design went through a 3-reviewer adversarial pass (two independent lenses +
one external model): 27 findings raised, 18 survived judging, all folded in — among
them the worktree resolution bug, the sibling-repo leak, the nested-ACTIVE
precedence, journal filename collisions, the 10k additionalContext cap, and
dropping a separate features.json in favor of one id space in plan.md.
