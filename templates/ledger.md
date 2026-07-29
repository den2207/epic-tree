# ledger — <epic-slug>

contract: append-only registry of STABLE facts, written by the COORDINATOR only (executors propose via journal) / referenced by ID from state/journal/plan instead of re-proving / facts that outlive the epic also get a one-line pointer in the orchestrator's global memory

<!-- One fact = one line. Never delete; supersede with a new entry referencing the old ID. -->
| id | fact | evidence | date |
|---|---|---|---|
| L-01 | <known non-regression / infra blocker / gotcha, one line> | <file:line / MR / command> | <YYYY-MM-DD> |
