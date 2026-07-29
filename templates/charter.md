# charter — <epic-slug>

contract: written once by `epic-new` (later edits only by explicit human decision, logged in a journal entry) / read by every session at start (auto-injected by the SessionStart hook) / never edited during handoff

## Non-negotiables

<!-- Self-contained. Embed this section VERBATIM in the prompt of ANY executor,
     including non-Claude agents that do not read CLAUDE.md. One rule per line. -->
- <account-safety boundary, one line, e.g.: no writes on <account>; read-only allowed>
- <push/merge policy, e.g.: never push, never merge; commits allowed per slice>
- <hard stop-gates, e.g.: cloud actions and manual IDE steps go to gated-actions.md, never executed by an agent>

## Roles

<!-- Single-writer rule lives here. Exactly one coordinator. -->
| role | agent/model | effort | writes |
|---|---|---|---|
| coordinator | <e.g. Claude Opus> | <e.g. high> | state.md, ledger.md, gated-actions.md, plan.md statuses, own journal file |
| executor | <e.g. Claude Sonnet / Codex> | <e.g. medium> | own journal file ONLY |

## Repo topology

<!-- Every repo this epic touches. ACTIVE must list the same repo names. -->
| repo | path | work branch | worktree |
|---|---|---|---|
| <name> | <absolute path> | <branch> | <absolute worktree path or —> |

## Autonomy contract

- <when to proceed without asking, e.g.: execute plan.md slices back-to-back>
- <when to stop, e.g.: stop only at gated actions (G-NN) and context thresholds>

## Global rules

Context thresholds, git conventions, language policy: see the user-level rules of the
orchestrating agent (e.g. CLAUDE.md). Do not duplicate them here — only epic deltas above.
