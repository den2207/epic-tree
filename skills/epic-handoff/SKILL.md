---
name: epic-handoff
description: Close an epic session — finalize the journal, promote facts to the ledger, update slice statuses with evidence, rewrite state.md last (coordinator). Use at context thresholds, session end, "hand off / continue in a new chat", or a finished slice batch.
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
   expected output); mark executed ones done. Then archive: append every done block
   from BEFORE this session to `gated-actions.ARCHIVE.md` in the same epic dir
   (keep the `## G-NN` headings verbatim so grep still finds them) and delete it
   from the main file — it keeps only open blocks plus blocks closed this session.
6. **plan.md statuses**: flip `status` to done ONLY with evidence (verify-command
   output or commit hash) recorded in the `evidence` column. No evidence — stays todo.
7. **Rewrite state.md** (the commit marker, LAST write): active slice, per-repo git
   state verified against `git log`/`status` (never from memory), next step,
   blocked-on, relevant L-IDs, `updated: <ISO ts> by coordinator`. Max 40 lines.
   Two parts are mandatory, in this order, right after `updated:`:
   - `kickoff:` — the exact phrase the human pastes as the FIRST message of the next
     session. It must name the slug and the concrete next step
     (`epic payments: G3 R2 — deploy after key rotation`), never a generic "continue
     the epic": chat titles are auto-generated from the first message, and a generic
     kickoff makes every session in the list look identical.
   - `## Map` — the cheap ASCII map of the whole epic, rebuilt from plan.md statuses
     (format and legend in `templates/state.md`): one line per slice (fold runs of
     done slices into `S-01..S-04`), exactly one `<- NEXT` marker, every blocked slice
     names its G-NN, and one `After:` line saying what follows the epic. It is the
     first thing the next session and the human read: done / not done / what next.
8. **Epic finished?** All slices done with evidence → delete `ACTIVE`, remove the
   epic-tree marked block from `<root>/AGENTS.md` (only the block — text outside
   the markers stays; delete the file if the block was its entire content), delete
   the untracked AGENTS.md stubs from member repos (only files that carry the
   epic-tree stub marker) and their `.git/info/exclude` lines, write a
   final journal entry, and tell the user the epic is closed and archivable. The
   final journal entry and the closing message carry the final `## Map` — every
   slice `[x]`, or `[-]` with its reason — and an `After:` line naming the
   follow-up epics and the debts that outlive this one.
9. **Close the chat** (coordinator): your LAST message repeats the `## Map` block
   verbatim and ends with exactly ONE sentence telling the human how to open the
   next session — the cwd to start it in and the kickoff phrase to paste, copied
   from state.md (`Next session: open a chat in ~/Work/<group> and paste
   "epic payments: G3 R2 — deploy after key rotation".`). Nothing after it.

## Guardrails

- Coordinator handoff without a rewritten state.md = handoff not performed.
- A closing message without the Map and the single next-session sentence = handoff
  not performed: the human must know what is done, what is not, and what to paste.
- state.md is rewritten from verified reality, never from conversation memory.
- Nothing valuable may live only in chat: if it matters, it is now in a file.
