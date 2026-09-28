#!/usr/bin/env bash
# Herd fleet — every agent whose worktree sits on a herd/* branch: status, commits ahead, last commit.
# Refreshes every 3 s; q or Esc closes. --once prints one frame and exits (for tests and scripts).
set -uo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"

frame() {
  local rows
  rows=$("$herdr" agent list 2>/dev/null | jq -r '.result.agents[]? | [.pane_id, .agent_status, .cwd] | @tsv')
  printf 'Herd fleet  %s\n\n' "$(date +%H:%M:%S)"
  printf '%-14s %-8s %-8s %-6s %s\n' BUCKET PANE STATUS AHEAD "LAST COMMIT"
  local n=0 pane status cwd branch base ahead last
  while IFS=$'\t' read -r pane status cwd; do
    [[ -n "$cwd" ]] || continue
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null) || continue
    [[ "$branch" == herd/* ]] || continue
    base=$(git -C "$cwd" rev-parse --verify -q main >/dev/null && echo main || echo master)
    ahead=$(git -C "$cwd" rev-list --count "$base"..HEAD 2>/dev/null || echo "?")
    last=$(git -C "$cwd" log -1 --format='%s' 2>/dev/null | cut -c1-50)
    printf '%-14s %-8s %-8s %-6s %s\n' "${branch#herd/}" "$pane" "$status" "$ahead" "$last"
    n=$((n+1))
  done <<< "$rows"
  (( n )) || printf '\nNo herd workers running. Start one with /herd <task>.\n'
}

if [[ "${1:-}" == "--once" ]]; then frame; exit 0; fi
while true; do
  clear; frame; printf '\nq to close\n'
  read -rsn1 -t 3 key && [[ "$key" == q || "$key" == $'\e' ]] && exit 0
done
