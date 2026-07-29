# journal — <YYYY-MM-DD> <HHMM> <role>

contract: one file per session, named journal/<YYYY-MM-DD>-<HHMM>-<role>.md (HHMM = session start) / written append-only by that session ONLY / merged into state.md by the coordinator at handoff

## Done

<!-- One line per completed slice, with the commit that proves it. -->
S-NN: <what> (commit <short-hash>, repo <name>)

## Discovered

<!-- Stable facts worth outliving this session. Coordinator promotes to ledger.md as L-NN. -->
- <fact + evidence (file:line / command output / MR link)>

## Decisions

- <decision taken this session + why, one line each>

## Proposals

<!-- Executors cannot write ledger/gated-actions/state. Propose here instead. -->
- <proposed L-entry / G-action / state correction>

## Next

<what this session would have done next>
