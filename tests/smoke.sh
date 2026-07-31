#!/bin/bash
# Hermetic smoke set for hooks/session-start.sh. Run after ANY hook change.
set -u
HOOK=$(cd "$(dirname "$0")/.." && pwd)/hooks/session-start.sh
FX=$(mktemp -d)
trap 'rm -rf "$FX"' EXIT
pass=0; fail=0
run() { printf '{"cwd":"%s"}' "$1" | env -u EPIC_TREE_ROOT bash "$HOOK"; }
ctx() { python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }
check() {
  if [ "$2" = "0" ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi
}

g="$FX/group"; mkdir -p "$g/epics/demo" "$g/repoA" "$g/repoZ"
printf 'demo\nrepoA\n' > "$g/epics/ACTIVE"
printf '# charter — demo\n\n## Non-negotiables\n- demo rule\n' > "$g/epics/demo/charter.md"
printf '# state — demo\n\n## Active slice\nS-01 hello\n' > "$g/epics/demo/state.md"

# 1. full context at the epic root
out=$(run "$g" | ctx)
echo "$out" | grep -q '===== charter.md =====' && echo "$out" | grep -q 'active epic: demo'
check "root-full-context" $?

# 2. member repo -> one-line banner, no full context
out=$(run "$g/repoA" | ctx)
echo "$out" | grep -q 'banner only' && ! echo "$out" | grep -q '===== charter.md ====='
check "member-banner-only" $?

# 3. non-member repo -> silent
out=$(run "$g/repoZ")
[ -z "$out" ]; check "non-member-silent" $?

# 4. no epic anywhere -> silent
n="$FX/plain/dir"; mkdir -p "$n"
out=$(run "$n")
[ -z "$out" ]; check "no-epic-silent" $?

# 5. CRLF ACTIVE: membership gate still matches
c="$FX/crlf"; mkdir -p "$c/epics/demo" "$c/repoA"
printf 'demo\r\nrepoA\r\n' > "$c/epics/ACTIVE"
cp "$g/epics/demo/charter.md" "$g/epics/demo/state.md" "$c/epics/demo/"
out=$(run "$c/repoA" | ctx)
echo "$out" | grep -q 'banner only'
check "crlf-member-gate" $?

# 6. slug traversal guard
s="$FX/slug"; mkdir -p "$s/epics"
printf '../x\n' > "$s/epics/ACTIVE"
out=$(run "$s" | ctx)
echo "$out" | grep -q 'invalid slug'
check "slug-guard" $?

# 7. UTF-8-safe truncation: multi-byte charter over the 9k budget stays valid JSON
u="$FX/utf8"; mkdir -p "$u/epics/big"
printf 'big\n' > "$u/epics/ACTIVE"
python3 -c 'open("'"$u"'/epics/big/charter.md","w").write("# чартер\n" + "методологія перевірки цілісності юнікоду "*700)'
printf '# state — big\nActive: S-01\n' > "$u/epics/big/state.md"
run "$u" > "$FX/utf8.json"
python3 -c 'import json; c=json.load(open("'"$FX"'/utf8.json"))["hookSpecificOutput"]["additionalContext"]; c.encode("utf-8"); assert "TRUNCATED" in c and len(c)<=9000, len(c)'
check "utf8-truncate" $?

# 8. nested repo epic shadows the group epic, with a banner note
mkdir -p "$g/repoB/epics/inner"
printf 'inner\n' > "$g/repoB/epics/ACTIVE"
cp "$g/epics/demo/charter.md" "$g/epics/demo/state.md" "$g/repoB/epics/inner/"
out=$(run "$g/repoB" | ctx)
echo "$out" | grep -q "shadows epic 'demo'" && echo "$out" | grep -q '===== charter.md ====='
check "nested-shadow" $?

# 9. EPIC_TREE_ROOT override forces full context from an unrelated cwd
out=$(printf '{"cwd":"%s"}' "$n" | EPIC_TREE_ROOT=$g bash "$HOOK" | ctx)
echo "$out" | grep -q '===== charter.md =====' && ! echo "$out" | grep -q 'banner only'
check "override-full" $?

echo "----- $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ]
