# state — <epic-slug>

contract: rewritten (never appended) by the COORDINATOR only, as the LAST step of epic-handoff / read by every session at start (auto-injected) / max 40 lines; history lives in journal/, not here

updated: <ISO-8601 timestamp> by <role>
kickoff: <slug>: <concrete next step, a few words — pasted as the next session's first message; it becomes that chat's title>

## Map

<!-- Cheap ASCII map of the WHOLE epic, rebuilt from plan.md statuses at every handoff.
     One line per slice, <= 80 chars; fold runs of done slices (S-01..S-04).
     Legend: [x] done (evidence in plan.md) · [~] in progress · [ ] todo ·
     [!] blocked (name the G-NN) · [-] deferred / out of scope (say why).
     Exactly one "<- NEXT" marker; one "After:" line — what follows once the epic closes. -->
[x] S-01..S-02 <phase or slice titles>
[~] S-03 <slice title>                              <- NEXT: <first concrete action>
[!] S-04 <slice title>  (G-NN: <who/what unblocks it>)
[ ] S-05 <slice title>
[-] S-06 <slice title>  (deferred: <why>)
After: <next phase / follow-up epic / debts that outlive this epic>

## Active slice

S-NN <title> — <one line: what is in flight right now>

## Repos

<!-- One line per repo from the charter topology. -->
| repo | branch | last commit | dirty |
|---|---|---|---|
| <name> | <branch> | <short-hash subject> | yes/no |

## Next step

<one concrete action the next session takes first>

## Blocked on

<G-NN refs or "nothing">

## Relevant ledger

<L-NN, L-NN — only entries the active slice needs; full registry in ledger.md>
