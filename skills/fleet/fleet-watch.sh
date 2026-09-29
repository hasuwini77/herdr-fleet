#!/usr/bin/env bash
# fleet-watch.sh — zero-token fleet watcher for /fleet.
# Blocks in bash (no model tokens) until a watched agent settles, then reports.
#
# Usage: fleet-watch.sh [options] <label>:<pane_id> ...
#   e.g. fleet-watch.sh --timeout 900 b1:w3:p2 b2:wR:p3        (label = bucket name)
#
#   --interval N    poll `herdr agent list` every N s (default 5)
#   --timeout N     give up after N s with nothing settled (default 900; exit 3)
#   --grace N       wait N s before the first poll (default 15; use 0 for agents already running)
#   --follow        keep watching after a settle: one EVENT per settle, a HEARTBEAT every
#                   --heartbeat s, then ALL-SETTLED + exit 0 once every label is settled.
#                   Claude Code: run this mode under the Monitor tool — every line is a notification.
#   --heartbeat N   seconds between HEARTBEAT lines in --follow (default 900). Under the Monitor
#                   tool every line wakes the orchestrator for a full turn, so keep these rare —
#                   the Herdr sidebar already shows liveness; TIMEOUT covers a dead fleet.
#   --no-marker     skip the FLEET-DONE check when an agent settles
#
# Output, one line per event (stdout):
#   EVENT <label> <pane_id> <old> -> <new> marker=FLEET-DONE|none (<n> still working: …)
#   HEARTBEAT <n> working: <labels>          --follow only, periodic
#   ALL-SETTLED <n> label(s)                 --follow only, then exit 0
#   TIMEOUT no-settle after <N>s — still working: <labels>     then exit 3
# `marker=FLEET-DONE` means the worker's own `FLEET-DONE <label>` line is in its recent output —
# a hint that it finished; `marker=none` means read the pane before judging (stopped early?).
#
# Exit 0 = settled (one-shot: at least one; --follow: all). Exit 3 = timeout, nothing settled
# (one-shot) or labels still working (--follow) — re-arm. Exit 2 = usage error.
set -u

interval=5
timeout=900
grace=15
follow=0
heartbeat=900
marker=1
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --interval)  interval="$2";  shift 2 ;;
    --timeout)   timeout="$2";   shift 2 ;;
    --grace)     grace="$2";     shift 2 ;;
    --heartbeat) heartbeat="$2"; shift 2 ;;
    --follow)    follow=1;       shift ;;
    --no-marker) marker=0;       shift ;;
    -h|--help)   sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
if [[ $# -lt 1 ]]; then
  echo "usage: fleet-watch.sh [--interval N] [--timeout N] [--grace N] [--follow] [--heartbeat N] [--no-marker] <label>:<pane_id> ..." >&2
  exit 2
fi

# Parallel indexed arrays, not associative — macOS ships bash 3.2, which has no `declare -A`,
# and SKILL.md invokes this as `bash fleet-watch.sh`, so the shebang can't rescue us.
labels=()
panes=()
states=()
classes=()
for arg in "$@"; do
  label="${arg%%:*}"
  pane="${arg#*:}"
  # pane IDs look like w3:p2 or wR:p3 — a bare pane id without a label must not parse as one
  if [[ -z "$label" || ! "$pane" =~ ^w[A-Za-z0-9]+:p[A-Za-z0-9]+$ ]]; then
    echo "bad target '$arg' — need <label>:<pane_id> (e.g. b1:w3:p2, b2:wR:p3)" >&2
    exit 2
  fi
  labels+=("$label")
  panes+=("$pane")
  states+=("__init__")
  classes+=("busy")
done

# Settle classes: idle and done are the same underlying state (done = unseen in the UI), so a
# focus that flips done -> idle must not fire a second EVENT. Only class changes count.
cls() { case "$1" in idle|done) echo ok ;; blocked) echo blocked ;; gone) echo gone ;; *) echo busy ;; esac; }

# The worker prints `FLEET-DONE <label>` on its own line when it finishes. The prompt that asked
# for it is echoed in the same pane mid-sentence, so anchor at line start (a glyph prefix such as
# "⏺ " is allowed) to avoid reading the instruction as the marker.
has_marker() { # $1 = pane, $2 = label
  herdr agent read "$1" --source recent-unwrapped --lines 80 2>/dev/null \
    | grep -Eq "^[^[:alnum:]]{0,8}FLEET-DONE[[:space:]]+$2([[:space:]]|$)"
}

busy_labels() { # prints the labels whose class is busy, space-separated
  local i out=""
  for i in "${!labels[@]}"; do [[ "${classes[$i]}" == busy ]] && out+="${labels[$i]} "; done
  printf '%s' "${out% }"
}
busy_count() { local n=0 i; for i in "${!labels[@]}"; do [[ "${classes[$i]}" == busy ]] && n=$((n+1)); done; echo "$n"; }

deadline=$(( SECONDS + timeout ))
next_heartbeat=$(( SECONDS + heartbeat ))

# Herdr's status lags a just-submitted prompt by a few seconds, so an agent that is about to
# start working still reads as idle/done. Polling immediately would fire a false EVENT on the
# first pass and the caller would "collect" results that don't exist yet. Wait it out.
# --grace 0 disables this, for watching agents that were already running.
(( grace > 0 )) && sleep "$grace"

while :; do
  # A failed `herdr agent list` (server restarting, socket busy) must not read as "every agent
  # is gone" — skip the poll and try again.
  if raw="$(herdr agent list 2>/dev/null)" && snapshot="$(jq -r '.result.agents[] | "\(.pane_id) \(.agent_status)"' <<<"$raw" 2>/dev/null)"; then
    events=0
    for i in "${!labels[@]}"; do
      label="${labels[$i]}"
      pane="${panes[$i]}"
      new="$(awk -v p="$pane" '$1 == p { print $2 }' <<<"$snapshot")"
      [[ -z "$new" ]] && new="gone"   # pane closed or agent released
      old="${states[$i]}"
      oldcls="${classes[$i]}"
      newcls="$(cls "$new")"
      states[$i]="$new"
      classes[$i]="$newcls"
      if [[ "$newcls" != busy && "$newcls" != "$oldcls" ]]; then
        m=""
        if [[ $marker -eq 1 && "$newcls" == ok ]]; then
          if has_marker "$pane" "$label"; then m=" marker=FLEET-DONE"; else m=" marker=none"; fi
        fi
        n="$(busy_count)"; rest="($n still working)"
        (( n > 0 )) && rest="($n still working: $(busy_labels))"
        echo "EVENT $label $pane ${old/__init__/(start)} -> $new$m $rest"
        events=$(( events + 1 ))
      fi
    done
    if [[ $follow -eq 0 ]]; then
      (( events > 0 )) && exit 0
    elif [[ "$(busy_count)" -eq 0 ]]; then
      echo "ALL-SETTLED ${#labels[@]} label(s)"; exit 0
    fi
  else
    echo "WARN herdr agent list failed — retrying in ${interval}s" >&2
  fi
  if (( SECONDS >= deadline )); then
    echo "TIMEOUT no-settle after ${timeout}s — still working: $(busy_labels)"; exit 3
  fi
  if [[ $follow -eq 1 ]] && (( SECONDS >= next_heartbeat )); then
    echo "HEARTBEAT $(busy_count) working: $(busy_labels)"
    next_heartbeat=$(( SECONDS + heartbeat ))
  fi
  sleep "$interval"
done
