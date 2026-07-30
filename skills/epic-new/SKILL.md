---
name: epic-new
description: Scaffold a new epic directory (epics/<slug>/) from an approved plan — charter, plan with slice table, state, ledger, gated-actions — and activate it. Use when the user approves a plan for a large multi-session task and says to set it up as an epic, start an epic, or convert a plan into an epic.
---

# epic-new

Turn an APPROVED plan into an epic directory the SessionStart hook and the
epic-start/epic-handoff skills operate on. Templates live in this repo's `templates/`.

## Steps

1. **Resolve the epic root**: the directory that spans every repo the epic touches —
   usually the group dir (e.g. `~/Work/<group>/`), or the repo itself for single-repo
   epics. If ambiguous, ask the user (one question, concrete options).
2. **Guard (self-check, not a mechanism):** if `<root>/epics/ACTIVE` already
   exists, STOP and ask — switching epics must be an explicit user decision. Never
   silently overwrite ACTIVE.
3. Create `<root>/epics/<slug>/` and fill from templates:
   - `charter.md` — Non-negotiables, roles table (agent/model/effort per role —
     MANDATORY, do not finish without it), repo topology (repo/path/branch/worktree),
     autonomy contract. Only epic deltas; global rules stay global.
   - `plan.md` — the approved plan restructured as a slice table:
     `| S-NN | slice (files/symbols + what) | verify (exact command) | status | evidence |`.
     Every slice needs a verify command. Statuses start at `todo`.
   - `state.md` — initial state: active slice S-01, per-repo git state (verify against
     `git log`/`git status`, do not guess), next step.
   - `ledger.md`, `gated-actions.md` — seed with known facts/gates from the plan.
4. **Non-Claude adapter**: copy `templates/AGENTS.md` to `<root>/AGENTS.md` (adjust
   the slug) so Codex/Cursor-family agents self-discover the epic and its write rules.
   If `<root>/AGENTS.md` already exists: replace the content between the
   `BEGIN/END epic-tree adapter` markers if present, otherwise append the whole
   marked block at the end. Never modify text outside the markers.
5. **Activate**: write `<root>/epics/ACTIVE` — first line the slug, then one
   repo name per line (must match charter topology). For migrations of already-running
   work, let the user review the directory and write ACTIVE themselves.
6. Confirm: print the tree, the active slice, and the roles table.

## Guardrails

- A plan without a verify command per slice is not ready — fix the plan first.
- A charter without the roles/model table is not ready.
- Do not invent file:line references — verify they exist.
- New stable facts discovered while scaffolding go to ledger.md, not chat only.
