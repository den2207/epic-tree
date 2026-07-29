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
| role | provider/surface | model | effort | writes |
|---|---|---|---|---|
| coordinator | <e.g. Claude Code> | <e.g. Opus> | <e.g. high> | state.md, ledger.md, gated-actions.md, plan.md statuses, own journal file |
| executor | <e.g. Claude Code agent / Codex MCP / Cursor> | <e.g. Sonnet / gpt-5.x> | <e.g. medium> | own journal file ONLY |

## Executor bootstrap (any tool)

An executor that does not run the Claude Code hook/skills must, before working:
read this charter (Non-negotiables are binding verbatim) → read state.md and the
active slice row in plan.md → create its own journal file (see AGENTS.md at the epic
root) → write nothing else. The orchestrator embeds Non-negotiables in every
executor prompt regardless of tool.

## Repo topology

<!-- Every repo this epic touches. ACTIVE must list the same repo names. -->
| repo | path | work branch | worktree |
|---|---|---|---|
| <name> | <absolute path> | <branch> | <absolute worktree path or —> |

## Autonomy contract

- <when to proceed without asking, e.g.: execute plan.md slices back-to-back>
- <when to stop, e.g.: stop only at gated actions (G-NN) and context thresholds>

## Global rules (coordinator-only pointer)

Context thresholds, git conventions, language policy live in the coordinator's own
rule files (e.g. CLAUDE.md) and are NOT visible to other tools. Any rule an EXECUTOR
must obey belongs in Non-negotiables above — portable and self-contained.
