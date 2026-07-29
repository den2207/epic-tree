---
name: epic-start
description: Session kickoff for an active epic — reconcile injected charter/state with reality (git across all topology repos), confirm role, model split, and nearest stop-gate, then continue the active slice. Use at the start of any session working on an epic, when the user says to continue the epic, or when SessionStart context shows an active epic.
---

# epic-start

The SessionStart hook already injected `charter.md`, `state.md`, and the ledger index.
Do NOT re-read them unless the hook reported truncation. Do NOT read plan.md fully —
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
3. **Read the last 1–2 files in `journal/`** (by name, newest first) for decisions
   and proposals that postdate state.md.
4. **Open your journal file**: `journal/<YYYY-MM-DD>-<HHMM>-<role>.md` from
   `templates/journal-entry.md` (HHMM = now; never reuse an existing file).
5. **Confirm in your first reply**: active slice, your role, the roles/model table
   (one line), the nearest stop-gate (G-NN or threshold), and any red flags from step 2.
   Then start the active slice — no permission-asking beyond the charter's autonomy contract.

## Guardrails

- Starting work with a state/reality mismatch left unexplained = broken kickoff.
- Never edit charter.md; propose changes via journal + user decision.
- Respect the injected Non-negotiables verbatim; when delegating to any executor
  (including non-Claude), embed the charter's Non-negotiables block in its prompt.
