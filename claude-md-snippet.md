# CLAUDE.md snippet — paste into `~/.claude/CLAUDE.md`

Two sections. **Models & delegation** makes Claude route every fan-out through
`/crew` (subagents) or Herdr (`/herd`) correctly. **GitHub activity** is the contribution-graph
law — it decides how work lands (issue → atomic commits → PR → merge commit).
The supporting lines at the bottom belong in your Verify/Housekeeping sections.

Codex reads a different file: mirror both sections into `~/.codex/AGENTS.md`
(see `codex-agents-snippet.md`), or Codex will happily squash your graph flat
and won't know the two-tier rule.

---

## Models & delegation
Fable 5 = main pane (plan, review, debug) — **never switch the main pane's model**. Sonnet = every implementation agent. Haiku = scouts/grunt (search, investigation, scaffolding) — never for code that ships. Opus = fallback/fast mode.
- **Two tiers.** Sessions (a real agent in its own Herdr tab/pane + worktree + branch) are the unit of ownership and git — `HERDR_ENV=1` means you're in one; if it isn't 1, say so and ask before any fallback; the `herdr` skill is the CLI syntax authority. Inside a session, **inner agents** (in-process subagents) are allowed for bounded labor: max 3 concurrent, read-only by default (map / scout / self-review), write-capable only when a `/herd` graph declared `inner: split` or a `/crew` roster owns the paths, never commit/branch/push/open tabs, confined to the session's owned paths by `herd-gate.sh`. No Claude Code teammates, no `Workflow` fan-outs, no raw tmux.
- **Three rungs.** One file, one concern → main pane. **≥2 write-capable subagents about to spawn → `/crew`** — the default, it triggers itself: ≤3 in-process subagents on disjoint paths, one worktree, one branch, one PR, `herd-gate.sh` around them, at most one Herdr pane for a cross-model worker. Any stream ≥ ~30 min, >3 streams, or a stream that needs its own dev server/sim/browser → `/herd` — typed only, never triggered by a bundled prompt. Never nest one in the other. A single quick delegation: one sibling pane.
- Freeze the shared contract in the main pane before fanning out; max 3 parallel agents unless I ask for more (each burns the 5h/7d quota). A bucket must be worth ≥ ~30 min of agent work — smaller is a `/crew` stream or the main pane; a session's load overhead never outweighs its work.
- **Typing it is the go.** `/herd` or `/crew` is the approval: print the graph/roster, spawn, don't ask "go?". Pauses: a high-risk irreversible step, or ≤3 batched intake questions when a real fork exists. Outside those, nothing spawns unless I ask. Claude Code agent teams stay OFF everywhere — `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="0"`, no `teammateMode`: Herdr is the session layer, subagents the labor.

## GitHub activity — the graph is the product
**Every task on a repo with a GitHub remote runs this exact loop, start to finish, without pausing:**
1. `gh issue create` — one issue per task (per bucket in `/herd`), **before** any code.
2. Branch (`feat/<name>`, or `herd/<name>` under `/herd`) → **6–9 atomic commits**, one per logical change (types · schema · component · styles · test · docs · cleanup). **Push after every commit** — unpushed commits count for nothing.
3. `gh pr create` with `Closes #N` in the body.
4. Merge on green **without asking me**: `gh pr merge --merge --delete-branch`. Then tag (feat → minor, fix → patch).

- **Never squash-merge, never rebase-merge, never `--amend` a pushed commit, never batch unrelated files.** If a repo still offers squash, it was missed: `gh repo edit --enable-squash-merge=false --enable-merge-commit`.
- **Fewer than 6 commits on a feature = committed too coarsely.** Say so and split before merging.
- Per-project exceptions, one line in its CLAUDE.md: `no-mistakes` → stop after step 3 for my review · `local-only` → no remote, skip steps 1 and 3.
- The graph counts **per day** — steps 1–4 all darken *today's* square. Breadth comes from days I don't build → keep daily `/schedule` routines on active repos, each opening its own PR.
- Author email must be the one verified on the GitHub account, or the commits score zero.

## Supporting lines (Verify / Housekeeping)
- UI work: `/ui-ux-pro-max` + `/impeccable` + `/frontend-design` + `/lean-ui` (hard design budget: 2 fonts · 3 sizes · 3 weights, no bold — github.com/hasuwini77/lean-ui) · `/ui-test` before merge.
- Never claim "done" without evidence — test result, build exit code, or a real screenshot (drive UI in Playwright, don't assert from the diff).
- **Dev-server/worktree cleanup** — `pkill -P $PID` then `kill $PID` (Next.js SWC workers survive a naive kill) → `git worktree remove --force` → verify the dir is gone, else `rm -rf`.
- **`.gitignore` on first appearance** — worktree dirs, `.env` copies, `.ui-test/`, `.ui-audit/`, `.playwright-mcp/`, `.dev-server.*`, `/*.png`.
- Nothing idle survives a run: close each `/herd` tab and `/crew` pane the run created; `TaskStop` every inner agent it started.

---

## One-time machine setup

Disable squash-merge everywhere so a stray UI click can't collapse a 9-commit PR
into one contribution (scoped to repos pushed in the last ~6 weeks):

```sh
gh repo list <user> --limit 200 --json name,pushedAt,isArchived,isFork \
  --jq 'map(select(.isArchived==false and .isFork==false and .pushedAt>="YYYY-MM-DD")) | .[].name' |
while read -r r; do gh repo edit "<user>/$r" --enable-squash-merge=false --enable-merge-commit=true; done
```

Also confirm on github.com: **Settings → Emails** (git author email verified) and
**Settings → Profile → include private contributions**, or private work stays grey.

Machine-specific lines deliberately left out: add your own per machine.
