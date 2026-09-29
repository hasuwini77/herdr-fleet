---
name: fleet
description: Parallel bucket build on Herdr — split a task into file-disjoint buckets, build each in a role-labeled Herdr worker tab + git worktree, then serially review/merge/tag. Explicit invocation only — /fleet <task> or "fleet this"; a prompt that merely bundles several features does NOT trigger it (that is `/crew`). Typing it is the go; its complexity gate keeps small tasks in the main pane.
---

# /fleet — parallel bucket build on Herdr

Beside this file: `WORKER.md` (the worker's contract; every ship prompt points at it), `references/runtimes.md` (Codex / other-kind rows; read only as a Codex orchestrator or for a `kind:` bucket), `fleet-watch.sh`, `fleet-gate.sh`, `tests/`. Do not load the `herdr` skill for a run — every command is inlined; on a CLI error `herdr <group>` prints the syntax.

## 0 · Preflight
- `test "${HERDR_ENV:-}" = 1` — if it fails, say so and stop. Never fall back to in-process agents as sessions: inner agents are labor inside a session.
- Inside a git repo, clean enough to branch from. Parse every ID from JSON responses, never predict one.
- Resolve the scripts once, PATH-free: `g=$(ls ~/.claude/skills/fleet/fleet-gate.sh ~/.codex/skills/fleet/fleet-gate.sh ~/.agents/skills/fleet/fleet-gate.sh 2>/dev/null | head -1); h=$(dirname "$g"); w="$h/fleet-watch.sh"`.

## T · Two tiers
| Tier | What | Owns | Never |
|---|---|---|---|
| **Session** — Herdr tab + worktree + branch + issue | one bucket | files, git, evidence, `FLEET-DONE` | shares a file with another session |
| **Inner agent** — in-process subagent (Claude `Agent` / Codex `spawn_agent`) | bounded labor inside its parent | nothing | commits, branches, pushes, opens tabs/worktrees, edits outside the parent's owned paths |

Main-pane rules (workers get theirs from `WORKER.md`): max 3 concurrent, read-only (scouts, map, pre-read); a write-capable inner agent in the main pane follows WORKER.md's gate lines (`bash "$g" baseline` / `check`) verbatim. Inner output is never evidence. `TaskStop` / `close_agent` every inner agent this run started before reporting.

## 1 · Complexity gate (do NOT skip)
| Task shape | Action |
|---|---|
| Trivial — one file, one concern | Main pane. No agents. |
| Single stream — real but coherent | ONE session, one worktree. |
| Multi-stream — ≥ 2 genuinely file-disjoint parts | Fan out, max **3** parallel sessions (more only if the user asks). |
| Investigation only | An inner scout from the main pane (§3); a session only if promoted. |

A **master prompt** (one message, ≥ 2 unrelated ideas) is multi-stream by default — don't serialize independent features out of laziness. The default yields when requirements are ambiguous, shared contracts are still moving, or b0 is unstable: then serialize deliberately and say why.

**Gate precedence, per idea, in order:**
1. **Risk.** High-blast-radius work (auth, billing/payments, schema migrations, deploy/env config, permissions, global config) never folds into a neighbor. Small → main pane, serial. Large → its own bucket, merged serially at a dependency-compatible point; its **irreversible step** (migration apply, billing/config write, env mutation, deploy) confirms with the user even mid-run — everything before it runs without pausing.
2. **Size.** A session costs ~30–80k tokens of load before its first useful edit. A bucket must be worth ≥ ~30 min of agent work; smaller folds into the most-related bucket, `/crew`, or (pure investigation) an inner scout. **`b0` below this bar is built by the main pane itself** — it *is* the contract freeze — in its own worktree on `fleet/b0` (never the live directory), same loop, merged first, then fan out on top of it.
3. **Parallelize** what survives. In doubt, fewer sessions.

## 2 · Decompose (goal-backward)
**Master-prompt intake first.** Split at idea boundaries — connective pivots ("and then also…", "another thing…", "oh and…") and topic shifts to an unrelated part of the app. The linguistic split is a HYPOTHESIS; the dependency scan is the proof. Ideas below the size bar fold into the nearest bucket or the main pane, never a session of their own. Restate the split as the bucket graph so the user sees one prompt become N streams.

**Dependency scan.** For every pair of candidate buckets check shared surface beyond owned files: `package.json`/lockfile, DB schema + migrations, shared types/API contracts, route registries, generated artifacts, global CSS/config, test fixtures. Read-only inner scouts may scan in parallel. Classify each overlap: **sequencing-only** (B needs A's output, different surface) → keep both, add an edge · **shared-contract** (both would edit the same file/schema/type/lockfile) → collapse into one bucket, or extract the shared surface into `b0` and depend on it (`b0` stays minimal; **dependency additions are `b0`-only**, workers never add packages) · **ambiguous** → ONE bucket (or main pane), doubt stated on the graph. Never guess toward more parallelism.

**Bucket graph** — one row per bucket:
- **name** `[a-z][a-z0-9_-]*` → agent name and branch `fleet/<name>`
- **shape** — `ship` (worktree, merges) · `scout (inner)` (read-only inner agent in the main pane, no tab; default for investigation) · `scout (tab)` (cheap-tier session, only when promoted)
- **role** — one plain word for the tab label (`designer`, `analyst`, `api`, `docs`…) so the sidebar reads like a crew roster
- **goal** (one sentence) · **owned** (exclusive paths — no overlap) · **verification** (exact command) · **depends on**
- **inner** — `—` (map + self-review only) or `split: <sub-path A> | <sub-path B> [| C]`; no `split` for buckets owning generated artifacts or a lockfile
- **tags** — `ui` · `migration` · `ios` · `high-risk: <irreversible step>` (WORKER.md addenda) · **kind** — omit for your runtime; `codex`/`claude` otherwise (`references/runtimes.md`)

**Dry run.** `/fleet --dry-run <task>` runs §1–§2, renders every ship prompt, stops — creates nothing. `fixtures/` holds the reference rendering.

**Print and go.** Typing `/fleet` is the approval (a master prompt inside it is split at idea boundaries). Order: dependency scan → **intake questions** only if the ambiguity fallback fired or a fork would materially change the graph (≤ 3, one message, wait, fold in) → print the graph, challenge-first (weakest split + the serial alternative; risk-gated rows MARKED `⚠ HIGH-RISK — main pane, serial` or `own bucket, merges at <point>`; `inner:`, `tags:`, `kind:` visible) → spawn. After that only a high-risk irreversible step, genuine drift, an undecidable point, unrecoverable failure or fan-out beyond 3 pauses; an interrupt → §5's failed-bucket teardown per bucket.

**Never idle the orchestrator.** While workers build, the main pane opens PRs, reviews landed diffs, runs preflights and drives the user's browser for portal chores (Vercel env, Stripe, Discord) — never hands him a checklist. A human hand only for what is impossible from here (a password, a device).

## 3 · Spawn (per bucket)
Workers live in **tabs**, not panes. A single quick delegation outside `/fleet` stays a sibling pane per the `herdr` skill.

**Inner scout (default for investigation):** `Agent` subagent_type `Explore`, model haiku (Codex: `references/runtimes.md`). Prompt = the question, the paths, a bound (≤ 25 tool calls, one report), exit = ANSWER / EVIDENCE (file:line) / OPEN. **Promotion** — no answer within the bound, or it needs a long-lived interactive tool (browser, running app) → `scout (tab)`: cwd = repo root, cheap tier, read-only prompt, finish with `FLEET-DONE <name>` + findings; amend the graph.

**Ship bucket** (GitHub remote → first `gh issue create --title "<goal>" --body "<owned + verification>"`, keep the number):
1. **Worktree**, idempotent and never detached: `b=fleet/<name>; d=../<repo>-<name>; git show-ref -q --verify "refs/heads/$b" && git worktree add "$d" "$b" || git worktree add "$d" -b "$b"`; assert `git -C "$d" symbolic-ref --short -q HEAD` = `fleet/<name>`. Worktree dirs gitignored; copy `.env*` in.
2. **Tab:** `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$d" --label "<role>" --no-focus` → tab ID `.result.tab.tab_id`, pane ID `.result.root_pane.pane_id` (objects, never strings). Label = the **role word**, never the slug; if herdr overwrites it, `herdr tab rename <tab-id> "<role>"`.
3. **Agent:** `herdr agent start <name> --kind claude --pane <pane> -- --model sonnet --dangerously-skip-permissions` (pure grunt: `--model haiku`). The unattended flag is mandatory — an unwatched worker must never sit at a permission dialog. `agent_not_ready` (or `blocked` right after start) = a startup dialog: `herdr agent read <name>`; the workspace-trust prompt on a worktree this run created is safe (`herdr agent send-keys <name> enter`, then `herdr agent wait <name> --until idle --timeout 60000`); anything else, surface it.
4. **Prompt — dispatch, don't babysit:** `herdr agent prompt <name> "<prompt>" --wait --until working --timeout 20000` returns when Herdr sees the worker start, never at its finish. `agent_prompt_stalled` or still `idle|done` = text landed, Enter didn't: `agent read` to confirm the prompt sits in the input box, `send-keys <name> enter` once, re-check — **never resend blind** (a doubled prompt runs the bucket twice). `agent_blocked` = a dialog is up, read it first.

**The ship prompt** — bucket-specific lines only; the contract is in the file (path for the worker's kind: Claude `$h/WORKER.md`, Codex `~/.codex/skills/fleet/WORKER.md`). **Before dispatch `test -r <that path>`** — if it is missing, hand the worker `$h/WORKER.md` instead; a prompt pointing at an absent file is a silent contract loss.
```
Bucket <name> — issue #<n>. First read <contract path> and obey it; it is your contract.
Goal: <one sentence>.
Owned paths (hard boundary — touch nothing outside): <paths>.
Verification (run and quote): <commands>.
Inner: <— | split: A | B> · API: <inner-agent API line for its kind>.
Tags: <ui | migration | ios | high-risk: <step> | —>.
Time: started <HH:MM>, budget <N> min.
Non-negotiable: push after every commit (6–9 per bucket); never stop to ask — undecidable → commit, push, `FLEET-BLOCKED <name>: <question>`; finish with the labeled evidence block (≤ 20 lines, every check with its exit code), then `FLEET-DONE <name>` as the very last line.
```
Inner-agent API line, Claude: "the `Agent` tool: `Explore` read-only, `general-purpose` writes; close with `TaskStop`". A bucket without `inner: split` gets `Inner: —` and thereby no write-capable inner permission.

## 4 · Monitor — zero-token watch, never model-side polling
Targets are `<bucket-name>:<pane-id>` (the **name**, not the role — the watcher greps the pane for `FLEET-DONE <name>`); the pane is the tab's root pane, e.g. `darkmode:wR:p3`. The watcher polls `herdr agent list` and sleeps in bash.

**Claude Code:** the **`Monitor` tool**, never a background Bash call (they get killed mid-build). Inline the resolve line (own shell): `Monitor({command: 'w=$(ls ~/.claude/skills/fleet/fleet-watch.sh ~/.codex/skills/fleet/fleet-watch.sh ~/.agents/skills/fleet/fleet-watch.sh 2>/dev/null | head -1); bash "$w" --follow --timeout 3300 <name>:<pane> …', description: 'fleet: <names>', timeout_ms: 3600000, persistent: false})`. Lines: `EVENT` per settle · `HEARTBEAT` every 15 min · `ALL-SETTLED` (monitor exits) · `TIMEOUT` (exit 3, Monitor exited — only then re-arm, **one Monitor per fleet**) → re-arm for the names it lists, **at most twice** (~3 h); after that read each still-working pane and decide: wedged → failed-bucket path (§5). A Monitor that exits any other way (no `ALL-SETTLED`, no `TIMEOUT`) → `herdr agent list`, then re-arm once for the still-working names — it counts toward the two.

- `--grace` (default 15 s) delays the first poll because Herdr's status lags a fresh prompt; `--grace 0` only for agents already running.
- **`HEARTBEAT` = no action.** No pane reads, no status calls, no message. It proves the watcher loop is alive, nothing about the workers — worker progress is judged on `EVENT`s and `TIMEOUT`. Every line is a full orchestrator turn.
- On an `EVENT`: `herdr agent get <name>` + `herdr agent read <name> --source recent-unwrapped --lines 60` for the named agents only. Then judge by the marker:
  - `idle`/`done` + `marker=FLEET-DONE` → collect the evidence block — and **accept it only if** there is one `VERIFY:` line per command in the bucket's verification list, each with `exit=0`, plus `PUSHED: yes` and the tag's field (`EVIDENCE:` for `ui`); fewer lines, a non-zero exit or a missing field = `marker=none` below. Accepted → `herdr tab close <tab-id>`; worktree + branch stay for §5.
  - `idle`/`done` + `marker=none` → stopped early (API drop, context boundary, an unanswered question). A `FLEET-BLOCKED` line → decide it from the spec or surface it. Otherwise check the branch first — `git -C ../<repo>-<name> status --short | head` and `git -C ../<repo>-<name> log --oneline main..` — then **resume, once per bucket** (re-`test -r` the contract path first), with one prompt dispatched per §3.4: "your <n> pushed commits survived; re-read your contract at <path> and the spec — <goal, owned, verification>; continue from `fleet/<name>`, don't redo landed work or stop to ask; finish with the evidence block, then `FLEET-DONE <name>` last" — then re-arm. A second early stop on the same bucket → failed-bucket path (§5), never a resume loop.
  - `blocked` → read the dialog; answer it yourself if the spec already decides it (permission/trust prompt inside a worktree this run created: yes), else surface to the user.
  - `gone` → `git -C <worktree> log --oneline main..` shows what landed; failed-bucket path (§5) unless the branch already carries the evidence.
  - `unknown` proves nothing — read the pane.

**Queue interrupts:** a scout finding that invalidates a ship bucket's premise → stop that worker, re-prompt or cancel (§5 failed-bucket path). Urgent work (prod bug) preempts the merge queue; the run resumes after. A dependency discovered mid-flight → add the edge, pause the affected worker until it merges — never merge on a stale premise.

## 5 · Integrate — serial merge queue
Ship buckets only, in dependency order, one at a time, from the main pane:
1. **Ownership gate:** pin what you review — `sha=$(git rev-parse fleet/<name>)` — then `git diff --name-only main...$sha`: every file inside the owned list, or the merge blocks: revert or renegotiate consciously, never wave through.
2. **Review the diff yourself — on a diet.** The decision is never delegated, the reading is targeted: `git diff --stat main...fleet/<name>` + the worker's evidence block + its self-review findings first. Read the full diff when it is ≤ ~400 changed lines; above that read **every hand-written changed file**, one at a time (`git diff main...fleet/<name> -- <file>`), source before tests — the diet is the order and the exclusions, never a skipped file. **Never dump lockfiles, generated files, snapshots, minified or vendored assets into context**: `--stat` them; for a lockfile read the `package.json` hunk in full and confirm the lockfile's added names are exactly those (grep the lockfile diff per name; nothing unexplained in `--stat`). Chain `/codex-reviewer` when the diff is large, cross-cutting or security-touching.
3. **Re-run the bucket's verification**; `ui` → `test -f` every `EVIDENCE:` path, then `/ui-test` where installed, else Playwright screenshot + axe; `migration` → apply + rollback on a local DB, regenerate types/clients. **A bucket that merged main (step 4) voids its earlier green run** — verify the merged result.
4. **Integrate per the project's merge mode** — first assert `git rev-parse fleet/<name>` still equals `$sha`; a moved head means unreviewed commits: review the delta, re-verify, re-pin (one line in its CLAUDE.md/AGENTS.md; default `direct-PR` with a GitHub remote, else `local-only`): `direct-PR` → push, `gh pr create` with `Closes #<issue>`, merge on green **without pausing**, merge commit, **never squash** · `no-mistakes` → push + PR, STOP for the user · `local-only` → merge to main, no remote. A later bucket that trails main → prompt its worker to merge main into its branch first (then step 3 again). An earlier merge changed a contract a pending bucket depends on → re-check that spec, re-prompt with the delta. Conflicts → resolve (`resolving-merge-conflicts` where installed); `git merge --abort` is fine, abandoning the bucket is not — have the worker merge main, retry.
5. **Cleanup — only after the branch is merged:** kill the bucket's dev server by PID (`pkill -P $PID` then `kill $PID`, never broad matching) → `ios`: `xcrun simctl shutdown <udid>` → `git worktree remove --force`, verify gone, else `rm -rf` → delete the merged branch → `herdr tab close <tab-id>` (only tabs this run created) → `TaskStop` the Monitor task if still armed. **Failed/abandoned bucket:** capture `git status` + unpushed commits, push the branch (or save a patch) BEFORE removal, close its issue with a comment linking the preserved branch. Every teardown ends with its **verification line**: `git ls-remote --heads origin fleet/<name>` (or the patch path) · `gh issue view <n> --json state` · `git worktree list` no longer lists the dir · `herdr tab list` no longer lists the tab.
6. After the last merge: run the union of all merged verification commands once on main, THEN tag (feat → minor, fix → patch), then PROGRESS.md — **append via heredoc under a new `## YYYY-MM-DD` heading; read only its first 30 lines, never the whole file**.

## 6 · Report
Bucket table: name · status · evidence (test/build/screenshot) · merge commit · inner agents used (count, patterns) · any `~/fleet-oob` path — plus the skill version the run used (`git -C "$h" rev-parse --short HEAD`). No "done" without evidence.

## 7 · Runtime
This file inlines the **Claude Code** row: Fable orchestrator (never switched), Sonnet ship workers, Haiku scouts/grunt, `Agent` inner API, `Monitor` watch, `/codex-reviewer`, `/ui-test`, `resolving-merge-conflicts`. Codex orchestrators, `kind: codex` workers and other kinds: `references/runtimes.md`. Mixed fleets are normal — each prompt carries its own kind's contract path and API line.
