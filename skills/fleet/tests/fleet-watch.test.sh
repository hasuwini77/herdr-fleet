#!/usr/bin/env bash
# Tests for fleet-watch.sh against a stub `herdr` on PATH. Run: bash skills/fleet/tests/fleet-watch.test.sh
# The stub renders $FLEET_STUB_STATE (lines: "<pane_id> <status>") as `herdr agent list` JSON and
# serves $FLEET_STUB_READ_DIR/<pane_id> as `herdr agent read` output; FLEET_STUB_FAIL=1 makes it fail.
set -euo pipefail
watch="$(cd "$(dirname "$0")/.." && pwd)/fleet-watch.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/state/read"
cat > "$tmp/bin/herdr" <<'STUB'
#!/usr/bin/env bash
[[ "${FLEET_STUB_FAIL:-0}" == 1 ]] && exit 1
case "${1:-} ${2:-}" in
  "agent list")
    printf '{"id":"cli:agent:list","result":{"agents":['
    first=1
    while read -r pane status; do
      [[ -z "$pane" ]] && continue
      [[ $first -eq 0 ]] && printf ','
      printf '{"pane_id":"%s","agent_status":"%s"}' "$pane" "$status"; first=0
    done < "$FLEET_STUB_STATE"
    printf '],"type":"agent_list"}}\n' ;;
  "agent read")
    f="$FLEET_STUB_READ_DIR/$3"; [[ -f "$f" ]] && cat "$f"; exit 0 ;;
  *) echo "stub herdr: unsupported: $*" >&2; exit 2 ;;
esac
STUB
chmod +x "$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH" FLEET_STUB_STATE="$tmp/state/agents" FLEET_STUB_READ_DIR="$tmp/state/read"
: > "$FLEET_STUB_STATE"

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $1"; }
bad() { fail=$((fail+1)); echo "  FAIL $1"; }
expect_exit() { # $1 expected code, $2 label, rest = command; stdout+stderr land in $tmp/out
  local want="$1" label="$2"; shift 2; local got=0
  "$@" >"$tmp/out" 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then ok "$label (exit $got)"; else bad "$label: want exit $want got $got"; sed 's/^/       /' "$tmp/out"; fi
}
out_has() { if grep -Eq "$1" "$tmp/out"; then ok "$2"; else bad "$2 — output was:"; sed 's/^/       /' "$tmp/out"; fi; }
out_lacks() { if grep -Eq "$1" "$tmp/out"; then bad "$2 — output was:"; sed 's/^/       /' "$tmp/out"; else ok "$2"; fi; }
set_state() { printf '%s\n' "$@" > "$FLEET_STUB_STATE"; }
fast=(--grace 0 --interval 1)

echo "usage"
expect_exit 2 "no targets" bash "$watch"
expect_exit 2 "bare pane id without label" bash "$watch" wX:p3
expect_exit 2 "numeric-only pane regex rejects junk" bash "$watch" b1:p3
expect_exit 2 "unknown flag" bash "$watch" --bogus b1:wX:p3
expect_exit 0 "help" bash "$watch" --help
rm -f "$FLEET_STUB_READ_DIR"/*

echo "one-shot — already settled"
set_state "wX:p3 idle" "wX:p4 working"
expect_exit 0 "idle agent fires at once" bash "$watch" "${fast[@]}" b1:wX:p3 b2:wX:p4
out_has '^EVENT b1 wX:p3 \(start\) -> idle marker=none \(1 still working: b2\)$' "EVENT line: start -> idle, no marker, names the busy label"
out_lacks '^EVENT b2' "working agent produces no EVENT"

echo "one-shot — FLEET-DONE marker"
set_state "wX:p3 done"
printf '⏺ Verification quoted above.\n\n  FLEET-DONE b1\n' > "$FLEET_STUB_READ_DIR/wX:p3"
expect_exit 0 "done agent with marker" bash "$watch" "${fast[@]}" b1:wX:p3
out_has 'EVENT b1 wX:p3 \(start\) -> done marker=FLEET-DONE \(0 still working\)' "marker=FLEET-DONE when the line is in recent output"
printf 'Finish by printing FLEET-DONE b1 plus its evidence.\n' > "$FLEET_STUB_READ_DIR/wX:p3"
expect_exit 0 "done agent, marker only inside the echoed prompt" bash "$watch" "${fast[@]}" b1:wX:p3
out_has 'marker=none' "mid-sentence FLEET-DONE (the prompt echo) is not a marker"
printf 'FLEET-DONE b10\n' > "$FLEET_STUB_READ_DIR/wX:p3"
expect_exit 0 "done agent, marker for a different label" bash "$watch" "${fast[@]}" b1:wX:p3
out_has 'marker=none' "FLEET-DONE b10 is not the marker for b1"
expect_exit 0 "--no-marker" bash "$watch" "${fast[@]}" --no-marker b1:wX:p3
out_lacks 'marker=' "--no-marker skips the read"
rm -f "$FLEET_STUB_READ_DIR"/*

echo "one-shot — timeout, gone, herdr failure"
set_state "wX:p3 working"
expect_exit 3 "working agent times out" bash "$watch" "${fast[@]}" --timeout 2 b1:wX:p3
out_has '^TIMEOUT no-settle after 2s — still working: b1$' "TIMEOUT line names the busy label"
set_state "wX:p9 working"
expect_exit 0 "pane missing from agent list" bash "$watch" "${fast[@]}" b1:wX:p3
out_has 'EVENT b1 wX:p3 \(start\) -> gone' "missing pane reads as gone"
set_state "wX:p3 blocked"
expect_exit 0 "blocked agent" bash "$watch" "${fast[@]}" b1:wX:p3
out_has 'EVENT b1 wX:p3 \(start\) -> blocked \(0 still working\)$' "blocked fires without a marker read"
set_state "wX:p3 working"
FLEET_STUB_FAIL=1 expect_exit 3 "herdr unreachable" bash "$watch" "${fast[@]}" --timeout 2 b1:wX:p3
out_lacks 'gone' "herdr failure never reads as gone"
out_has 'WARN herdr agent list failed' "herdr failure is warned about"

echo "follow — stream every settle, then ALL-SETTLED"
set_state "wX:p3 working" "wX:p4 working"
bash "$watch" "${fast[@]}" --follow --timeout 30 --heartbeat 2 b1:wX:p3 b2:wX:p4 > "$tmp/follow" 2>&1 &
wpid=$!
sleep 2.5
set_state "wX:p3 done" "wX:p4 working"; printf 'FLEET-DONE b1\n' > "$FLEET_STUB_READ_DIR/wX:p3"
sleep 2.5
set_state "wX:p3 idle" "wX:p4 working"        # the user focused the tab: done -> idle, same class
sleep 2.5
set_state "wX:p3 idle" "wX:p4 blocked"
if wait "$wpid"; then ok "follow exits 0 once every label settled"; else bad "follow exit $? — output:"; sed 's/^/       /' "$tmp/follow"; fi
cp "$tmp/follow" "$tmp/out"
out_has '^EVENT b1 wX:p3 working -> done marker=FLEET-DONE \(1 still working: b2\)$' "b1 settle streamed with marker + remaining label"
[[ "$(grep -c '^EVENT b1' "$tmp/follow")" == 1 ]] && ok "done -> idle does not re-fire" || { bad "b1 fired $(grep -c '^EVENT b1' "$tmp/follow") times:"; sed 's/^/       /' "$tmp/follow"; }
out_has '^EVENT b2 wX:p4 working -> blocked \(0 still working\)$' "b2 blocked streamed"
out_has '^HEARTBEAT [12] working: ' "periodic HEARTBEAT while labels are busy"
[[ "$(tail -1 "$tmp/follow")" == "ALL-SETTLED 2 label(s)" ]] && ok "ALL-SETTLED is the last line" || { bad "last line: $(tail -1 "$tmp/follow")"; }

echo "follow — a re-prompted agent settles again while a sibling still works"
rm -f "$FLEET_STUB_READ_DIR"/*
set_state "wX:p3 working" "wX:p4 working"
bash "$watch" "${fast[@]}" --follow --timeout 30 --heartbeat 60 b1:wX:p3 b2:wX:p4 > "$tmp/follow" 2>&1 &
wpid=$!
sleep 2.5; set_state "wX:p3 done" "wX:p4 working"
sleep 2.5; set_state "wX:p3 working" "wX:p4 working"   # orchestrator re-prompted b1 — busy again
sleep 2.5; set_state "wX:p3 idle" "wX:p4 working"
sleep 2.5; set_state "wX:p3 idle" "wX:p4 done"
wait "$wpid" && ok "follow exits 0 after every label settled" || bad "follow exit $?"
[[ "$(grep -c '^EVENT b1' "$tmp/follow")" == 2 ]] && ok "b1: two settles, two EVENTs" || { bad "b1 EVENT count $(grep -c '^EVENT b1' "$tmp/follow"):"; sed 's/^/       /' "$tmp/follow"; }
grep -q '^EVENT b1 wX:p3 working -> idle marker=none (1 still working: b2)$' "$tmp/follow" && ok "second b1 EVENT shows working -> idle" || { bad "second b1 EVENT missing:"; sed 's/^/       /' "$tmp/follow"; }
grep -q '^EVENT b2 wX:p4 working -> done marker=none (0 still working)$' "$tmp/follow" && ok "b2 settle closes the run" || bad "b2 EVENT missing"

echo "follow — timeout while still working"
set_state "wX:p3 working"
expect_exit 3 "follow times out" bash "$watch" "${fast[@]}" --follow --timeout 2 --heartbeat 60 b1:wX:p3
out_has '^TIMEOUT no-settle after 2s — still working: b1$' "follow TIMEOUT names the busy label"
out_lacks 'ALL-SETTLED' "no ALL-SETTLED on timeout"

echo; echo "passed $pass, failed $fail"; [[ $fail -eq 0 ]]
