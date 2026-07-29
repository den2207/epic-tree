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

## Review provenance

The v1 design went through a 3-reviewer adversarial pass (two independent lenses +
one external model): 27 findings raised, 18 survived judging, all folded in — among
them the worktree resolution bug, the sibling-repo leak, the nested-ACTIVE
precedence, journal filename collisions, the 10k additionalContext cap, and
dropping a separate features.json in favor of one id space in plan.md.
