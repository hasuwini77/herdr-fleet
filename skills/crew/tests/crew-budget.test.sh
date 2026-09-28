#!/usr/bin/env bash
# Token-budget + structure lint for the crew skill. Run: bash skills/crew/tests/crew-budget.test.sh
# The orchestrator loads SKILL.md on every /crew run and every session on the machine loads the
# frontmatter description, so size is a cost, not a style choice. Every stream reads INNER.md once.
# Caps are bytes (≈ tokens × 4). Raise one only with a reason in PROGRESS.md.
set -euo pipefail
d="$(cd "$(dirname "$0")/.." && pwd)"
herd="$d/../herd"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "  ok   $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL $1" >&2; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
size() { wc -c < "$1" | tr -d ' '; }
desc_len() { awk '/^description:/{print length($0)-13; exit}' "$1"; }

echo "budget"
check "SKILL.md ≤ 11000 bytes ($(size "$d/SKILL.md"))"              "[[ $(size "$d/SKILL.md") -le 11000 ]]"
check "INNER.md ≤ 4500 bytes ($(size "$d/INNER.md"))"               "[[ $(size "$d/INNER.md") -le 4500 ]]"
check "crew description ≤ 450 chars ($(desc_len "$d/SKILL.md"))"    "[[ $(desc_len "$d/SKILL.md") -le 450 ]]"

echo "shared with herd (resolved by path, never copied)"
check "herd-gate.sh exists beside crew"                              "[[ -x '$herd/herd-gate.sh' ]]"
check "herd-watch.sh exists beside crew"                             "[[ -x '$herd/herd-watch.sh' ]]"
check "references/runtimes.md exists beside crew"                    "[[ -r '$herd/references/runtimes.md' ]]"
check "crew ships no gate or watcher copy"                           "! ls '$d'/*.sh >/dev/null 2>&1"

echo "structure"
check "SKILL.md points streams at INNER.md"                          "grep -q 'INNER.md' '$d/SKILL.md'"
check "SKILL.md resolves herd-gate.sh by path"                        "grep -q 'herd-gate.sh' '$d/SKILL.md'"
check "SKILL.md points at references/runtimes.md"                    "grep -q 'references/runtimes.md' '$d/SKILL.md'"
check "SKILL.md: Herdr not required"                                 "grep -q 'HERDR_ENV\` is NOT required' '$d/SKILL.md'"
check "SKILL.md: never nested inside a herd worker"                  "grep -q 'Never nested' '$d/SKILL.md'"
check "SKILL.md: fit gate hands ≥ 30 min streams to /herd"            "grep -q '≥ ~30 min' '$d/SKILL.md' && grep -q 'never degrade' '$d/SKILL.md'"
check "SKILL.md: risk gate keeps auth/billing/migrations home"        "grep -q 'Risk gate first' '$d/SKILL.md'"
check "SKILL.md: worktree, never the live directory"                 "grep -q 'never the live directory' '$d/SKILL.md'"
check "SKILL.md: owned paths absolute under the worktree"            "grep -q 'absolute under the worktree' '$d/SKILL.md'"
check "SKILL.md: contract path is test -r'd before dispatch"         "grep -q 'test -r <contract path>' '$d/SKILL.md'"
check "SKILL.md: prompt template names contract, HERD-DONE, never commit" "grep -q 'obey it; it is your contract' '$d/SKILL.md' && grep -q 'HERD-DONE <name>' '$d/SKILL.md' && grep -q 'Never commit, never ask' '$d/SKILL.md'"
check "SKILL.md: at most ONE pane stream"                            "grep -q 'at most ONE' '$d/SKILL.md' && grep -q 'A second pane → that is \`/herd\`' '$d/SKILL.md'"
check "SKILL.md: patch saved on each return"                         "grep -q 'crew-<crew>-<name>.patch' '$d/SKILL.md'"
check "SKILL.md: union gate once, never per stream"                  "grep -q 'once, never per stream' '$d/SKILL.md' && grep -q -- '--bucket crew-<crew>' '$d/SKILL.md'"
check "SKILL.md: attribution + leak check"                           "grep -q 'Attribution' '$d/SKILL.md' && grep -q 'Leak check' '$d/SKILL.md'"
check "SKILL.md: parent reruns verification, report is never evidence" "grep -q 'a report is never evidence' '$d/SKILL.md'"
check "SKILL.md: review diet (stat first, ≤ ~400 lines)"             "grep -q -- 'diff --stat' '$d/SKILL.md' && grep -q '400 changed lines' '$d/SKILL.md'"
check "SKILL.md: close agents + pane before the first commit"        "grep -q 'before the first commit' '$d/SKILL.md'"
check "SKILL.md: interrupt path never commits the mixture"           "grep -q 'never commit the mixture' '$d/SKILL.md'"
check "SKILL.md: 6–9 commits, never squash"                          "grep -q '6–9 commits' '$d/SKILL.md' && grep -q 'never squash' '$d/SKILL.md'"
check "SKILL.md: --dry-run"                                          "grep -q -- '--dry-run' '$d/SKILL.md'"

echo "inner contract"
for m in 'HERD-DONE <name>' 'No git that writes' '`stash`' 'Playwright' '/tmp/crew-<name>-vitest.log' 'Never install packages' 'never a pipe' '≤ 20 lines' '1440'; do
  check "INNER.md carries '$m'" "grep -qF -- '$m' '$d/INNER.md'"
done
check "INNER.md: exit= captured from a file"                          "grep -q 'echo \"vitest exit=\$?\"' '$d/INNER.md'"
check "INNER.md: labeled report fields"                               "for f in FILES VERIFY OPEN UNVERIFIED; do grep -q \"\\\`\$f:\" '$d/INNER.md' || exit 1; done"
check "INNER.md: HERD-DONE is the very last line"                     "grep -q 'as the very last line' '$d/INNER.md'"
check "INNER.md: no npx downloads, no .env writes"                    "grep -q 'never let \`npx\` download' '$d/INNER.md' && grep -q 'Never write \`.env' '$d/INNER.md'"
for tag in ui high-risk; do
  check "INNER.md has the '$tag' addendum" "grep -q \"^\*\*$tag\*\*\" '$d/INNER.md'"
done

echo
echo "passed $pass, failed $fail"
[[ $fail -eq 0 ]]
