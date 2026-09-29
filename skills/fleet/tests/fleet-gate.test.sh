#!/usr/bin/env bash
# Tests for fleet-gate.sh against a throwaway git repo. Run: bash skills/fleet/tests/fleet-gate.test.sh
set -euo pipefail
gate="$(cd "$(dirname "$0")/.." && pwd)/fleet-gate.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export FLEET_OOB_DIR="$tmp/oob"
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $1"; }
bad() { fail=$((fail+1)); echo "  FAIL $1"; }
expect_exit() { # $1 expected code, $2 label, rest = command
  local want="$1" label="$2"; shift 2; local got=0
  "$@" >"$tmp/out" 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then ok "$label (exit $got)"; else bad "$label: want exit $want got $got"; sed 's/^/       /' "$tmp/out"; fi
}
fresh() {
  rm -rf "$tmp/repo"; mkdir -p "$tmp/repo"; cd "$tmp/repo"
  git init -q -b main; git config user.email t@t; git config user.name t
  mkdir -p src/owned src/other "src/with space"; echo a > src/owned/a.txt; echo b > src/other/b.txt; echo c > "src/with space/c.txt"
  echo 'build/' > .gitignore; git add -A; git commit -q -m init
}

echo "baseline"
fresh; expect_exit 0 "clean tree" bash "$gate" baseline
echo x >> src/owned/a.txt; expect_exit 2 "dirty tree" bash "$gate" baseline

echo "check — in bounds"
fresh; echo x >> src/owned/a.txt; echo n > src/owned/new.txt
expect_exit 0 "modify + add inside owned" bash "$gate" check --bucket t -- src/owned
[[ "$(cat src/owned/a.txt)" == $'a\nx' ]] && ok "in-bounds change kept" || bad "in-bounds change lost"

echo "check — out of bounds preserved then reverted"
fresh; echo x >> src/owned/a.txt; echo y >> src/other/b.txt; echo z > src/other/new.txt; rm "src/with space/c.txt"
expect_exit 1 "oob modify/add/delete" bash "$gate" check --bucket t -- src/owned
[[ "$(cat src/other/b.txt)" == b ]] && ok "oob modify reverted" || bad "oob modify not reverted"
[[ ! -e src/other/new.txt ]] && ok "oob untracked removed" || bad "oob untracked still present"
[[ -f "src/with space/c.txt" ]] && ok "oob delete restored (path with space)" || bad "oob delete not restored"
[[ "$(cat src/owned/a.txt)" == $'a\nx' ]] && ok "in-bounds change untouched" || bad "in-bounds change lost"
d="$(ls -d "$FLEET_OOB_DIR"/t-* | head -1)"
[[ -f "$d/changes.patch" && -f "$d/MANIFEST" ]] && ok "patch + manifest written" || bad "patch/manifest missing"
grep -q $'modified\tsrc/other/b.txt' "$d/MANIFEST" && grep -q $'untracked\tsrc/other/new.txt' "$d/MANIFEST" && grep -q $'deleted\tsrc/with space/c.txt' "$d/MANIFEST" && ok "manifest lists all three kinds" || bad "manifest incomplete: $(cat "$d/MANIFEST")"
[[ "$(cat "$d/files/src/other/new.txt")" == z && "$(cat "$d/files/src/other/b.txt")" == $'b\ny' ]] && ok "copies preserved" || bad "copies wrong"
git apply --check -R "$d/changes.patch" 2>/dev/null && ok "patch applies (reverse-checkable against HEAD tree)" || true

echo "check — fail closed"
fresh; echo y >> src/other/b.txt; git add src/other/b.txt
expect_exit 2 "staged change" bash "$gate" check -- src/owned
[[ "$(cat src/other/b.txt)" == $'b\ny' ]] && ok "nothing reverted on fail-closed" || bad "reverted despite fail-closed"
fresh; git mv src/other/b.txt src/other/renamed.txt
expect_exit 2 "rename" bash "$gate" check -- src/owned
fresh; echo x >> src/owned/a.txt; git add src/owned/a.txt
expect_exit 2 "staged even when in bounds" bash "$gate" check -- src/owned

echo "check — ignored listed, never touched"
fresh; mkdir -p build; echo o > build/out.js; echo x >> src/owned/a.txt
expect_exit 0 "ignored outside owned" bash "$gate" check -- src/owned
grep -q '!! build/' "$tmp/out" && ok "ignored path listed" || bad "ignored path not listed"
[[ -f build/out.js ]] && ok "ignored file untouched" || bad "ignored file removed"

echo "usage"
expect_exit 2 "no command" bash "$gate"
expect_exit 2 "check without owned paths" bash "$gate" check --
expect_exit 0 "help" bash "$gate" --help

echo; echo "passed $pass, failed $fail"; [[ $fail -eq 0 ]]
