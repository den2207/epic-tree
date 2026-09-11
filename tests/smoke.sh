#!/bin/bash
# Hermetic smoke set for hooks/session-start.sh + hooks/user-prompt-submit.sh.
# Run after ANY hook change.
set -u
HOOKS=$(cd "$(dirname "$0")/.." && pwd)/hooks
FX=$(mktemp -d)
trap 'rm -rf "$FX"' EXIT
pass=0; fail=0
start()  { printf '{"cwd":"%s"}' "$1" | env -u EPIC_TREE_ROOT bash "$HOOKS/session-start.sh"; }
prompt() { python3 -c 'import json,sys; print(json.dumps({"cwd":sys.argv[1],"prompt":sys.argv[2]}))' "$1" "$2" | env -u EPIC_TREE_ROOT bash "$HOOKS/user-prompt-submit.sh"; }
ctx() { python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }
check() {
  if [ "$2" = "0" ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi
}
mkepic() { # base slug updated-ts
  mkdir -p "$1/$2"
  printf '# charter — %s\n\n## Non-negotiables\n- %s rule\n' "$2" "$2" > "$1/$2/charter.md"
  printf '# state — %s\n\nupdated: %s by coordinator\nkickoff: epic %s: next thing\n\n## Active slice\nS-01 hello %s\n' "$2" "$3" "$2" "$2" > "$1/$2/state.md"
}

g="$FX/group"; mkdir -p "$g/repoA"
mkepic "$g/epics" demo 2026-01-01T10:00

# 1. single live epic at the root -> full context
out=$(start "$g" | ctx)
echo "$out" | grep -q '===== charter.md =====' && echo "$out" | grep -q 'active epic: demo'
check "single-full-context" $?

# 2. cwd inside any repo below the root -> same full context (no membership gate)
out=$(start "$g/repoA" | ctx)
echo "$out" | grep -q 'active epic: demo'
check "any-cwd-full-context" $?

# 3. no epics anywhere -> silent
n="$FX/plain/dir"; mkdir -p "$n"
out=$(start "$n"); [ -z "$out" ]; check "no-epic-silent" $?

# 4. archived epic is not live: root with 1 live + 1 archived -> still full context
mkepic "$g/epics/_archive" old 2025-01-01T10:00
out=$(start "$g" | ctx)
echo "$out" | grep -q 'active epic: demo' && ! echo "$out" | grep -q 'epic: old'
check "archive-excluded" $?

# 5. two live epics -> roster (no charter), newest updated first
mkepic "$g/epics" payments 2026-03-01T10:00
out=$(start "$g" | ctx)
echo "$out" | grep -q '2 live epics' && ! echo "$out" | grep -q '===== charter' \
  && [ "$(echo "$out" | grep -E '^  (demo|payments) ' | head -1 | awk '{print $1}')" = "payments" ]
check "roster-newest-first" $?

# 6. roster carries the kickoff phrase of each epic
echo "$out" | grep -q 'kickoff: epic payments: next thing'
check "roster-kickoff" $?

# 7. prompt names one slug -> that epic's full context
out=$(prompt "$g/repoA" "epic payments: next thing" | ctx)
echo "$out" | grep -q 'epic selected by this message: payments' && echo "$out" | grep -q 'payments rule'
check "prompt-selects" $?

# 8. prompt names no slug -> silent
out=$(prompt "$g" "how do I sort a list in python"); [ -z "$out" ]; check "prompt-none-silent" $?

# 9. prompt names two slugs -> refuse to pick
out=$(prompt "$g" "compare demo with payments" | ctx)
echo "$out" | grep -q 'several live epics' && ! echo "$out" | grep -q '===== charter'
check "prompt-ambiguous" $?

# 10. whole-word match: "pay" epic must not fire on "payments"
mkepic "$g/epics" pay 2026-02-01T10:00
out=$(prompt "$g" "epic payments: go" | ctx)
echo "$out" | grep -q 'epic selected by this message: payments'
check "prompt-whole-word" $?

# 11. UTF-8-safe truncation: multi-byte charter over the 9k budget stays valid JSON
u="$FX/utf8"; mkepic "$u/epics" big 2026-01-01T10:00
python3 -c 'open("'"$u"'/epics/big/charter.md","w").write("# чартер\n" + "методологія перевірки цілісності юнікоду "*700)'
start "$u" > "$FX/utf8.json"
python3 -c 'import json; c=json.load(open("'"$FX"'/utf8.json"))["hookSpecificOutput"]["additionalContext"]; c.encode("utf-8"); assert "TRUNCATED" in c and len(c)<=9000, len(c)'
check "utf8-truncate" $?

# 12. nested epics/ inside a repo merges with the group roster
mkepic "$g/repoB/epics" inner 2026-04-01T10:00
out=$(start "$g/repoB" | ctx)
echo "$out" | grep -q '4 live epics' && echo "$out" | grep -q '^  inner '
check "nested-merged" $?
out=$(prompt "$g/repoB" "epic inner: go" | ctx)
echo "$out" | grep -q 'epic selected by this message: inner'
check "nested-prompt-selects" $?

# 13. stale v1 ACTIVE pointer -> flagged, hook still works
printf 'demo\nrepoA\n' > "$g/epics/ACTIVE"
out=$(start "$g" | ctx)
echo "$out" | grep -q 'v1 pointer' && echo "$out" | grep -q 'live epics'
check "stale-active-flagged" $?
rm "$g/epics/ACTIVE"

# 14. EPIC_TREE_ROOT override from an unrelated cwd
out=$(printf '{"cwd":"%s"}' "$n" | EPIC_TREE_ROOT=$u bash "$HOOKS/session-start.sh" | ctx)
echo "$out" | grep -q 'active epic: big'
check "override" $?

# 15. epic-list shows live epics and skips _archive
out=$(bash "$HOOKS/../bin/epic-list.sh" "$g")
echo "$out" | grep -q 'payments' && ! echo "$out" | grep -q '^  old '
check "epic-list" $?

echo "----- $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ]
