#!/usr/bin/env bash
# Token-budget lint for the herd skill. Run: bash skills/herd/tests/herd-budget.test.sh
# The orchestrator loads SKILL.md into its context on every /herd run and every session on the
# machine loads both frontmatter descriptions, so their size is a cost, not a style choice.
# Caps are bytes (≈ tokens × 4). Raise one only with a reason in PROGRESS.md.
set -euo pipefail
d="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "  ok   $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL $1" >&2; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
size() { wc -c < "$1" | tr -d ' '; }
desc_len() { awk '/^description:/{print length($0)-13; exit}' "$1"; }

echo "budget"
check "SKILL.md ≤ 18500 bytes ($(size "$d/SKILL.md"))"             "[[ $(size "$d/SKILL.md") -le 18500 ]]"
check "WORKER.md ≤ 7800 bytes ($(size "$d/WORKER.md"))"             "[[ $(size "$d/WORKER.md") -le 7800 ]]"
check "references/runtimes.md ≤ 5000 bytes"                          "[[ $(size "$d/references/runtimes.md") -le 5000 ]]"
check "herd description ≤ 450 chars ($(desc_len "$d/SKILL.md"))"    "[[ $(desc_len "$d/SKILL.md") -le 450 ]]"

echo "structure"
check "SKILL.md points workers at WORKER.md"                         "grep -q 'WORKER.md' '$d/SKILL.md'"
check "SKILL.md points at references/runtimes.md"                    "grep -q 'references/runtimes.md' '$d/SKILL.md'"
check "SKILL.md does not load the herdr skill"                       "! grep -q 'Load the \`herdr\` skill' '$d/SKILL.md'"
check "SKILL.md: HEARTBEAT is a no-op"                               "grep -q 'HEARTBEAT.*= no action' '$d/SKILL.md'"
check "SKILL.md: review diet (stat first, ≤ ~400 lines)"             "grep -q -- '--stat main' '$d/SKILL.md' && grep -q '400 changed lines' '$d/SKILL.md'"
check "SKILL.md: pane reads capped at 60 lines"                      "grep -q -- '--lines 60' '$d/SKILL.md'"
check "ship prompt template names the contract, HERD-DONE, HERD-BLOCKED" "grep -q 'contract path' '$d/SKILL.md' && grep -q 'HERD-DONE <name>' '$d/SKILL.md' && grep -q 'HERD-BLOCKED <name>' '$d/SKILL.md'"
check "SKILL.md: contract path is test -r'd before dispatch"          "grep -q 'test -r <that path>' '$d/SKILL.md'"
check "SKILL.md: resume once per bucket, re-arm at most twice"        "grep -q 'once per bucket' '$d/SKILL.md' && grep -q 'at most twice' '$d/SKILL.md'"
check "SKILL.md: review reads every hand-written changed file"        "grep -q 'every hand-written changed file' '$d/SKILL.md'"
check "SKILL.md: b0 in the main pane still gets a worktree"           "grep -q 'own worktree on \`herd/b0\`' '$d/SKILL.md'"
check "SKILL.md: one VERIFY per required check, exit=0, PUSHED: yes"   "grep -q 'one \`VERIFY:\` line per command' '$d/SKILL.md' && grep -q 'PUSHED: yes' '$d/SKILL.md'"
check "SKILL.md: abnormal Monitor exit re-arms once, counts toward two" "grep -q 'exits any other way' '$d/SKILL.md'"
check "SKILL.md: ui EVIDENCE paths test -f'd at merge"                "grep -q 'test -f\` every \`EVIDENCE:\` path' '$d/SKILL.md'"
check "SKILL.md: reviewed SHA pinned and re-asserted before merge"     "grep -q 'sha=\$(git rev-parse herd/<name>)' '$d/SKILL.md' && grep -q 'still equals \`\$sha\`' '$d/SKILL.md'"

echo "worker contract"
for m in 'HERD-DONE <name>' 'HERD-BLOCKED <name>' 'herd-gate.sh' 'push -u origin herd/<name>' '--reporter=dot' 'inner: split' '≤ 20 lines' '1440'; do
  check "WORKER.md carries '$m'" "grep -qF -- '$m' '$d/WORKER.md'"
done
check "WORKER.md: verification captures exit= from a file, not a pipe" "grep -q 'echo \"vitest exit=\$?\"' '$d/WORKER.md' && grep -q 'never pipe a check into' '$d/WORKER.md'"
check "WORKER.md: HERD-DONE is the very last line, after evidence"     "grep -q 'as the very last line' '$d/WORKER.md'"
check "WORKER.md: log paths carry the bucket name"                     "grep -q '/tmp/herd-<name>-vitest.log' '$d/WORKER.md'"
check "WORKER.md: tools from node_modules/.bin, content secret scan"   "grep -q './node_modules/.bin/vitest' '$d/WORKER.md' && grep -q 'PRIVATE KEY' '$d/WORKER.md'"
check "WORKER.md: labeled evidence fields"                             "for f in COMMITS PUSHED VERIFY EVIDENCE INNER OOB UNVERIFIED; do grep -q \"\\\`\$f:\" '$d/WORKER.md' || exit 1; done"
check "WORKER.md: no npx downloads, push failure, secrets rules"       "grep -q 'never let \`npx\` download' '$d/WORKER.md' && grep -q 'push failed' '$d/WORKER.md' && grep -q 'Never commit \`.env' '$d/WORKER.md'"
for tag in ui migration ios high-risk; do
  check "WORKER.md has the '$tag' addendum" "grep -q \"^\*\*$tag\*\*\" '$d/WORKER.md'"
done

check "WORKER.md: named early-stop patterns, only HERD-DONE/BLOCKED end a run" "grep -q 'A message with no tool call ends your run' '$d/WORKER.md'"
check "SKILL.md: ship prompt carries a time budget line"              "grep -q 'Time: started <HH:MM>, budget <N> min' '$d/SKILL.md'"

echo "watcher"
check "herd-watch.sh heartbeat default is 900 s"                     "grep -q '^heartbeat=900$' '$d/herd-watch.sh'"
check "herd-watch.sh --help prints its exit-code line"               "bash '$d/herd-watch.sh' --help | grep -q 'Exit 2 = usage error'"

echo
echo "passed $pass, failed $fail"
[[ $fail -eq 0 ]]
