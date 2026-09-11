# charter — <epic-slug>

contract: written once by `epic-new` (later edits only by explicit human decision, logged in a journal entry) / read by every session at start (auto-injected by the SessionStart hook) / never edited during handoff

## Non-negotiables

<!-- Self-contained. Embed this section VERBATIM in the prompt of ANY executor,
     including non-Claude agents that do not read CLAUDE.md. One rule per line. -->
- <account-safety boundary, one line, e.g.: no writes on <account>; read-only allowed>
- <push/merge policy, e.g.: never push, never merge; commits allowed per slice>
- <hard stop-gates, e.g.: cloud actions and manual IDE steps go to gated-actions.md, never executed by an agent>

## Roles

<!-- Single-writer rule lives here. Exactly one coordinator.
     Solo use is valid: keep a single coordinator row and delete the executor row. -->
| role | surface (provider) | model id | reasoning effort | writes (inside epics/) |
|---|---|---|---|---|
| coordinator | <e.g. Claude Code> | <exact id, e.g. claude-opus-5> | <e.g. high> | state.md, ledger.md, gated-actions.md, plan.md statuses, own journal file |
| executor | <e.g. Codex MCP / Claude Code agent / Cursor> | <exact id, e.g. gpt-5.6-luna / claude-sonnet-5> | <e.g. xhigh / medium> | own journal file ONLY |

Filled-in charters record exact pinned model identifiers, not tier nicknames.
Editing the active slice's source files in member repos is every role's normal work —
the "writes" column scopes only the epic-control files.

## Executor bootstrap (any tool)

An executor that does not run the Claude Code hook/skills must, before working:
read this charter (Non-negotiables are binding verbatim) → read state.md and the
active slice row in plan.md → create its own journal file (see AGENTS.md at the epic
root) → inside `epics/` write nothing else; keep working until the slice's
verify command passes or a named gate/blocker stops you. The process launching an
executor embeds Non-negotiables in its prompt regardless of tool.

## Repo topology

<!-- Every repo this epic touches — the only source of truth for membership. -->
| repo | path | work branch | worktree |
|---|---|---|---|
| <name> | <absolute path> | <branch> | <absolute worktree path or —> |

## Autonomy contract

- <when to proceed without asking, e.g.: reversible actions that follow from plan.md
  slices — execute back-to-back, no confirmation pauses>
- <when to stop, e.g.: only at gated actions (G-NN), destructive/irreversible steps,
  real scope changes, the runtime limits of your own surface (for Claude Code — the
  global context thresholds), or input only the user can provide>

## Global rules (coordinator-only pointer)

Context thresholds, git conventions, language policy live in the coordinator's own
rule files (e.g. CLAUDE.md) and are NOT visible to other tools. Any rule an EXECUTOR
must obey belongs in Non-negotiables above — portable and self-contained.
