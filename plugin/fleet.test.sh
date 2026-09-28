#!/usr/bin/env bash
# fleet.sh against a stub herdr: lists only herd/* worktrees. Run: bash plugin/fleet.test.sh
set -euo pipefail
d="$(cd "$(dirname "$0")" && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
git init -q -b main "$t/w" && git -C "$t/w" commit -q --allow-empty -m init
git -C "$t/w" switch -q -c herd/demo && git -C "$t/w" commit -q --allow-empty -m "feat: demo commit"
printf '#!/usr/bin/env bash\necho %s\n' "'{\"result\":{\"agents\":[{\"pane_id\":\"w9:p2\",\"agent_status\":\"working\",\"cwd\":\"$t/w\"},{\"pane_id\":\"w9:p1\",\"agent_status\":\"idle\",\"cwd\":\"/\"}]}}'" > "$t/herdr"
chmod +x "$t/herdr"
out=$(HERDR_BIN_PATH="$t/herdr" bash "$d/fleet.sh" --once)
grep -qE '^demo +w9:p2 +working +1 +feat: demo commit$' <<< "$out" || { echo "FAIL herd worker row"; echo "$out"; exit 1; }
! grep -q 'w9:p1' <<< "$out" || { echo "FAIL non-herd pane listed"; exit 1; }
printf '#!/usr/bin/env bash\necho %s\n' "'{\"result\":{\"agents\":[]}}'" > "$t/herdr"
HERDR_BIN_PATH="$t/herdr" bash "$d/fleet.sh" --once | grep -q 'No herd workers running' || { echo "FAIL empty state"; exit 1; }
echo "passed 3, failed 0"
