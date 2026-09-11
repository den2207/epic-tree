---
name: epic-new
description: Scaffold and activate a new epic dir (epics/<slug>/ — charter, plan, state, ledger, gated-actions) from an approved plan. Use when the user says to set up / start an epic or convert a plan into one.
---

# epic-new

Turn an APPROVED plan into an epic directory the SessionStart hook and the
epic-start/epic-handoff skills operate on. Templates live in this repo's `templates/`.

## Steps

1. **Resolve the epic root**: the directory that spans every repo the epic touches —
   usually the group dir (e.g. `~/Work/<group>/`), or the repo itself for single-repo
   epics. If ambiguous, ask the user (one question, concrete options).
2. **Guard:** if `<root>/epics/<slug>/` already exists, STOP and ask. Several live
   epics under one root are normal — each is its own directory, selected per session
   by the user's message (see step 5). Prefer ONE `epics/` dir at the group root for
   every epic of the group (repo-scoped ones included); nested `<repo>/epics/` dirs
   work but scatter the roster.
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
4. **Non-Claude adapter**: copy `templates/AGENTS.md` to `<root>/AGENTS.md` (it is
   slug-agnostic) so Codex/Cursor-family agents self-discover the epics and the write rules.
   If `<root>/AGENTS.md` already exists: replace the content between the
   `BEGIN/END epic-tree adapter` markers if present, otherwise append the whole
   marked block at the end. Never modify text outside the markers.
   Then bridge the discovery gap (Codex/Copilot never read AGENTS.md above a repo's
   own git root, and a group root is usually not a git repo) — for EACH member repo:
   - no tracked `AGENTS.md` there → write `templates/AGENTS-stub.md` as
     `<repo>/AGENTS.md` and append `AGENTS.md` to `<repo>/.git/info/exclude`
     so the work repo stays clean for git;
   - a tracked `AGENTS.md` already exists → do NOT touch it; report to the user that
     this repo's own file governs and committing the epic block there is their
     explicit, team-visible decision.
5. **Live from now on**: the epic is live as soon as `epics/<slug>/state.md` exists —
   there is no pointer file to write. The SessionStart hook lists every live epic under
   the root; the user selects one by naming its slug in the first message (the
   `kickoff:` phrase from state.md), and the UserPromptSubmit hook injects its charter
   and state. Closing an epic later = moving its dir to `epics/_archive/`.
6. Confirm: print the tree, the active slice, the roles table, and the exact kickoff
   phrase the user pastes to start the first working session.

## Guardrails

- A plan without a verify command per slice is not ready — fix the plan first.
- A charter without the roles/model table is not ready.
- Do not invent file:line references — verify they exist.
- New stable facts discovered while scaffolding go to ledger.md, not chat only.
