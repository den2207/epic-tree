---
name: epic-start
description: Epic session kickoff — reconcile charter/state with git reality across topology repos, confirm role and nearest stop-gate, continue the active slice. Use at the start of any session on an epic, or when SessionStart context shows an active epic.
---

# epic-start

The SessionStart hook already injected `charter.md`, `state.md`, and the ledger index —
unless it reported "banner only" (member-repo session): then read charter.md, state.md,
and the `| L-NN` ledger index lines from the epic dir yourself FIRST. Do NOT re-read
injected files unless the hook reported truncation. Do NOT read plan.md fully —
only the active slice's row and section. Do NOT read all journal files.

## Steps

1. **Identify your role** from the charter roles table (coordinator or executor).
   It defines what you may write: executors write ONLY their own journal file.
2. **Reconcile state vs reality** — for EVERY repo in the charter topology
   (including worktrees): `git -C <path> log --oneline -3` + `git -C <path> status -sb`.
   - Mismatch with state.md → reality wins; coordinator fixes state.md BEFORE working;
     executor records the mismatch in its journal and proceeds from reality.
   - Commits present that no journal entry mentions → red flag: a session died before
     handoff. Reconstruct what they did from the diffs before continuing.
   - `updated: ... by <role>` shows a writer other than the coordinator → flag it to
     the user; single-writer discipline was violated.
3. When looking up a G-NN, check `gated-actions.md` first, then
   `gated-actions.ARCHIVE.md` (closed blocks are moved there at handoff).
4. **Read the last 1–2 files in `journal/`** (by name, newest first) for decisions
   and proposals that postdate state.md.
5. **Open your journal file**: `journal/<YYYY-MM-DD>-<HHMM>-<role>.md` from
   `templates/journal-entry.md` (HHMM = now; never reuse an existing file).
6. **Confirm in your first reply**: active slice, your role, the roles/model table
   (one line), the nearest stop-gate (G-NN or threshold), and any red flags from step 2.
   Then start the active slice — no permission-asking beyond the charter's autonomy contract.

## Guardrails

- Starting work with a state/reality mismatch left unexplained = broken kickoff.
- Never edit charter.md; propose changes via journal + user decision.
- Respect the injected Non-negotiables verbatim; when delegating to any executor
  (including non-Claude), embed the charter's Non-negotiables block in its prompt.
