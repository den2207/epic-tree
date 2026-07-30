---
name: epic-handoff
description: Close an epic session — finalize the journal entry, promote stable facts to the ledger, update slice statuses with evidence, and (coordinator only) rewrite state.md last as the commit marker. Use at context thresholds, session end, when the user says to hand off / continue in a new chat, or when an epic slice batch is done.
---

# epic-handoff

Fixed write order — state.md is written LAST so a crash mid-handoff leaves state
pointing at the previous consistent snapshot; the next epic-start reconciles the rest.

## Steps (all roles)

1. **Finalize your journal file** (`journal/<date>-<HHMM>-<role>.md`): Done (with
   commit hashes), Discovered, Decisions, Proposals, Next. A handoff without a
   finalized journal entry did not happen.
2. If you are an **executor**: stop here. You do not touch state/ledger/gated/plan —
   your Proposals section carries anything the coordinator must apply.

## Steps (coordinator only)

3. **Merge executor journals** written since the last state update: apply their
   Proposals (or record why rejected — in your own journal, one line each).
4. **Ledger**: append new stable facts as `L-NN | fact | evidence | date`. Facts that
   outlive the epic also get a one-line pointer in the orchestrator's global memory.
5. **Gated actions**: add new G-NN blocks (copy-paste-ready command, cwd, account,
   expected output); mark executed ones done.
6. **plan.md statuses**: flip `status` to done ONLY with evidence (verify-command
   output or commit hash) recorded in the `evidence` column. No evidence — stays todo.
7. **Rewrite state.md** (the commit marker, LAST write): active slice, per-repo git
   state verified against `git log`/`status` (never from memory), next step,
   blocked-on, relevant L-IDs, `updated: <ISO ts> by coordinator`. Max 40 lines.
8. **Epic finished?** All slices done with evidence → delete `ACTIVE`, remove the
   epic-tree marked block from `<root>/AGENTS.md` (only the block — text outside
   the markers stays; delete the file if the block was its entire content), write a
   final journal entry, and tell the user the epic is closed and archivable.

## Guardrails

- Coordinator handoff without a rewritten state.md = handoff not performed.
- state.md is rewritten from verified reality, never from conversation memory.
- Nothing valuable may live only in chat: if it matters, it is now in a file.
