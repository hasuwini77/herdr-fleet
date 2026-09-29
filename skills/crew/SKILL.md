---
name: crew
description: The default fan-out rung — ≤ 3 in-process subagents (Claude Agent / Codex spawn_agent), each owning disjoint paths in ONE worktree on ONE branch, gated by fleet-gate.sh, landed by the main pane as one PR; at most one Herdr pane for a cross-model worker. Triggers on /crew <task>, "crew this", or whenever ≥ 2 write-capable subagents are about to spawn. Below /fleet (sessions), above the main pane (one file).
---

# /crew — subagent crew, one worktree, one branch

Beside this file: `INNER.md` (every stream's contract; each prompt points at it), `tests/`. Shared with `/fleet`, resolved by path, never copied: `fleet-gate.sh` (the diff gate), `fleet-watch.sh` (only for a pane stream), `references/runtimes.md` (Codex rows). Crew is one `/fleet` bucket with `inner: split`, run from the main pane, Herdr optional.

## 0 · Preflight
- Inside a git repo, clean enough to branch from. `HERDR_ENV` is NOT required — only a `kind: codex` pane stream needs it.
- Resolve once, PATH-free: `g=$(ls ~/.claude/skills/fleet/fleet-gate.sh ~/.codex/skills/fleet/fleet-gate.sh ~/.agents/skills/fleet/fleet-gate.sh 2>/dev/null | head -1); h=$(dirname "$g"); c=$(dirname "$(ls ~/.claude/skills/crew/SKILL.md ~/.codex/skills/crew/SKILL.md ~/.agents/skills/crew/SKILL.md 2>/dev/null | head -1)")`.
- Claude Code row inlined below (Sonnet `general-purpose` streams, Haiku `Explore` scouts, `TaskStop`). A Codex orchestrator or a `kind: codex` stream reads `$h/references/runtimes.md`: inner worker type `fleet-worker` (`spawn_agent` → `wait` → `close_agent`; it may end `WORKER-DONE` — accept that marker from a Codex inner stream), scout `fleet-scout`.
- **Never nested:** inside a `/fleet` worker you already are a crew — `WORKER.md` rules, not this file.

## 1 · Fit gate (do NOT skip)
| Shape | Rung |
|---|---|
| One file, one concern | Main pane. No agents. |
| 2–3 genuinely file-disjoint streams, each ~5–30 min | **`/crew`** — this file |
| Any stream ≥ ~30 min · > 3 streams · a stream needs its own dev server, simulator or browser session | `/fleet` — say so and stop; never degrade a session-sized stream into a subagent |
| Investigation only | An inner scout (§3), no crew |

`/agt` is a different axis: planner → executor → reviewer ceremony on a single stream. **Risk gate first, always:** auth, billing/payments, schema migrations, deploy/env config, permissions, global config never become a stream — main pane, serial, its irreversible step confirms with the user.

## 2 · Roster (the contract)
Prove disjointness before printing — for every pair check shared surface beyond owned files: `package.json`/lockfile, schema + migrations, shared types/API contracts, route registries, generated artifacts, global CSS/config, root layout, test fixtures. Shared surface is **the main pane's, before spawn** — that commit *is* the contract freeze; dependency additions are never a stream's. Two streams that would touch one file are one stream. Ambiguous → one stream, doubt stated.

One row per stream:
- **name** `[a-z][a-z0-9_-]*` · **role** one plain word · **goal** one sentence
- **owned** — exclusive paths, printed **absolute under the worktree** (`$d/src/foo`)
- **verification** — exact commands (vitest + tsc shapes; builds and Playwright are the main pane's)
- **tier** — `sonnet` (writes) · `haiku` (scout, read-only) · **kind** — `—` or `codex` (a pane; needs `HERDR_ENV=1` — without it print "runs as inner sonnet — no Herdr" and proceed) · **tags** — `ui` or `—`
- **bound** — tool calls or minutes (default 60 calls / 25 min)

**Dry run:** `/crew --dry-run <task>` prints the roster + every rendered prompt, creates nothing (`fixtures/crew-expected.md` is the reference).

**Print and go.** Typing `/crew` — or the moment ≥ 2 write-capable subagents would spawn — is the approval. ≤ 3 intake questions, one message, only on a real fork; else zero. Print the roster (weakest split named + the serial alternative), then spawn. Never idle after: review landed hunks, draft the commit split and PR body, run preflights — but **no edits in `$d` and no browser-driving until the gate** (HMR on half-edited files yields false failures).

## 3 · Spawn
1. **Issue** (GitHub remote): `gh issue create --title "<goal>" --body "<roster: owned + verification>"`, keep the number.
2. **Worktree — never the live directory:** `b=feat/<name>; d=$(cd .. && pwd)/<repo>-<name>; git show-ref -q --verify "refs/heads/$b" && git worktree add "$d" "$b" || git worktree add "$d" -b "$b"`; assert `git -C "$d" symbolic-ref --short -q HEAD` = `$b`; copy `.env*` in; worktree dirs gitignored.
3. **Groundwork** — shared-surface edits in `$d`, committed and pushed (`git -C "$d" push -u origin "$b"`).
4. **Snapshot + baseline:** `git status --porcelain > /tmp/crew-<crew>-live.txt` (the live checkout, for the leak check) · `(cd "$d" && bash "$g" baseline)` must exit 0.
5. **Streams** — max 3 concurrent; **every prompt is the template below**; `test -r <contract path>` first (fallback `$c/INNER.md`; a prompt pointing at an absent file is a silent contract loss):
   - Claude: `Agent` — subagent_type `general-purpose`, `model: sonnet`; scout: `Explore`, `haiku`, read-only prompt (question · paths · ≤ 25 calls · ANSWER / EVIDENCE / OPEN). Returns arrive as notifications.
   - Codex: `spawn_agent(agent_type="fleet-worker")` (scout `fleet-scout`) → `wait` → `close_agent`.
   - **Pane stream** (`kind: codex`, at most ONE): `herdr pane split --pane "$HERDR_PANE_ID" --direction right --ratio 0.4 --cwd "$d" --no-focus` → pane id `.result.pane.pane_id` · `herdr agent start <name> --kind codex --pane <id> -- -m gpt-5.5 -a never -s danger-full-access` · `herdr agent prompt <name> "<prompt>" --wait --until working --timeout 20000` (stalled / blocked handling verbatim from `/fleet` §3.4 — never resend blind) · watch: `Monitor({command: 'w=$(ls ~/.claude/skills/fleet/fleet-watch.sh ~/.codex/skills/fleet/fleet-watch.sh ~/.agents/skills/fleet/fleet-watch.sh 2>/dev/null | head -1); bash "$w" --follow --timeout 3300 <name>:<pane>', description: 'crew: <name>', timeout_ms: 3600000, persistent: false})`; `HEARTBEAT` = no action; `EVENT … marker=FLEET-DONE` → `herdr agent read <name> --source recent-unwrapped --lines 40` for the report. A second pane → that is `/fleet`.

```
Stream <name> of crew <crew> — issue #<n>. First read <contract path> and obey it; it is your contract.
Worktree: <$d> — work only there. Goal: <one sentence>.
Owned paths (hard boundary — touch nothing outside): <absolute paths>.
Verification (run, capture exit=, quote): <commands>.
Bound: <n> tool calls / <m> min. Tags: <ui | —>.
Finish with the report (FILES / VERIFY exit= / OPEN / UNVERIFIED, ≤ 20 lines), then `FLEET-DONE <name>` as the very last line. Never commit, never ask.
```

## 4 · Collect
Returns arrive as notifications (Claude: the Agent task; Codex: `wait`; pane: the Monitor `EVENT`) — never poll, never read a running stream's files. **On each return:** save its work before a sibling can touch the tree — `git -C "$d" diff > /tmp/crew-<crew>-<name>.patch` — then read the report; a missing `FLEET-DONE <name>`, a non-zero `exit=`, or an `OPEN:` naming a change outside the wall = not done (below).

**After the LAST return, in order:**
1. **Union gate** — once, never per stream: `(cd "$d" && bash "$g" check --bucket crew-<crew> -- <union of all owned paths>)`. exit 0 clean · exit 1 out-of-bounds preserved under `~/fleet-oob/crew-<crew>-<ts>/` and reverted — quote the path · exit 2 fail-closed (something ran `git add`) — stop, inspect by hand.
2. **Attribution** — `git -C "$d" status --porcelain` vs the union of every report's `FILES:`; a changed file no stream claimed is a trespass: read it, decide keep / revert by hand.
3. **Leak check** — `git status --porcelain | diff - /tmp/crew-<crew>-live.txt` is empty; a diff means a stream edited the live checkout: `git diff` it, move the hunk into `$d` or drop it.
4. Main pane runs formatters / generators / `next build` **once**, then **reruns every stream's verification itself** — a report is never evidence. `ui` → Playwright screenshot ≥ 1440 px + axe to `~/screenshots`, `/ui-test` where installed.
5. **Review on a diet** (`/fleet` §5.2 law): `git -C "$d" diff --stat` + reports first; full diff ≤ ~400 changed lines, else every hand-written file one at a time; lockfiles / generated stat-only. Fresh eyes, optional: an inner read-only reviewer (≤ 15 calls) or cross-model with no pane — `git -C "$d" diff | codex exec -m gpt-5.5 -s read-only -a never "review for bugs and ownership violations; severity-classified findings only"`.
6. **`TaskStop` every inner agent and the Monitor, `herdr pane close <id>` the pane — before the first commit.**

**Not done / `OPEN:` outside the wall** → `TaskStop` it if still running, let the rest return, run 1–3, main pane makes the shared change, commits, reruns `baseline`, respawns that stream with the delta (once; a second failure → do it yourself or promote to `/fleet`). **Interrupt (Ctrl-C mid-run)** → streams die with partial edits mixed in `$d`: run 1–3, `git -C "$d" diff > /tmp/crew-<crew>-interrupt.patch`, print per-stream status, **never commit the mixture** — the user decides.

## 5 · Land
Main pane only, in `$d`: one logical change per commit across streams (types · A · B · styles · test · docs · cleanup — **6–9 commits**), `git push` after each, never squash / amend / batch. Then per the project's merge mode (default `direct-PR`): `gh pr create` with `Closes #<n>`, merge on green without pausing (`--merge`, never squash), tag (feat → minor, fix → patch) · `no-mistakes` → PR then STOP · `local-only` → merge to main. **Cleanup after merge:** kill the dev server by PID → `git worktree remove --force "$d"`, verify gone else `rm -rf` → delete the branch → verification line: `git ls-remote --heads origin <b>` empty · `git worktree list` no longer lists `$d` · `herdr pane list` no longer lists the pane · no inner agent still listed.

## 6 · Report
Stream table: name · tier/kind · `FILES:` count · `VERIFY:` (rerun by you, exit=) · OOB path or none — plus merge commit, tag, and the skill SHA (`git -C "$c" rev-parse --short HEAD`). No "done" without evidence.
