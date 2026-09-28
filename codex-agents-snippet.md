# AGENTS.md snippet — paste into `~/.codex/AGENTS.md`

Codex reads `~/.codex/AGENTS.md`, not `CLAUDE.md`. Without this section it will
squash-merge and batch commits, flattening the contribution graph Claude Code is
carefully building. Keep it in sync with `claude-md-snippet.md`'s GitHub section.

Two sections: **Models & delegation** (Herdr as the spawn layer, the two-tier
rule, Codex's `spawn_agent` limits) and the **Git law**. How Codex *reviews*
plans stays in the `/codex-reviewer` skill on the Claude side, not here.

---

## Models & delegation
gpt-5.5 (reasoning high) = main pane (plan, review, debug, merge) — never switch it mid-run. gpt-5.5 = ship workers. gpt-5.4-mini = scouts/grunt (search, investigation) — never for code that ships.
- **Two tiers.** Sessions (a real agent in its own Herdr tab/pane + worktree + branch) are the unit of ownership and git — `HERDR_ENV=1` means you're in one; if it isn't 1, say so and ask before any fallback; the `herdr` skill is the CLI syntax authority. Inside a session, **inner agents** (`spawn_agent` → `wait` → `close_agent`, types `herd-scout` / `herd-worker` / `herd-reviewer`) are allowed for bounded labor: max 3 concurrent, read-only by default (map / scout / self-review), `herd-worker` only when a `/herd` graph declared `inner: split` or a `/crew` roster owns the paths, never commit/branch/push/open tabs, confined to the session's owned paths by `herd-gate.sh`.
- **Three rungs.** One file, one concern → main pane. **≥2 write-capable `spawn_agent` workers about to spawn → `/crew`** — the default, it triggers itself: ≤3 `herd-worker` agents on disjoint paths, one worktree, one branch, one PR, `herd-gate.sh` around them, at most one Herdr pane for a cross-model worker. Any stream ≥ ~30 min, >3 streams, or a stream that needs its own dev server/sim/browser → `/herd` — typed only, never triggered by a bundled prompt. Never nest one in the other. A single quick delegation: one sibling pane.
- Freeze the shared contract in the main pane before fanning out; max 3 parallel sessions unless I ask for more. A bucket must be worth ≥ ~30 min of agent work — smaller is a `/crew` stream, the main pane, or an inner scout.
- **Typing it is the go.** `/herd` or `/crew` is the approval: print the graph/roster, spawn, don't ask "go?". Pauses: a high-risk irreversible step, or ≤3 batched intake questions when a real fork exists. Outside those, nothing spawns unless I ask.

# Git & GitHub — the contribution graph is the product

The graph is a business asset. Every event — issue opened, commit on the default branch, PR opened, merge commit — is one contribution. Ceremony you skip is activity thrown away.

**Every task on a repo with a GitHub remote runs this loop, start to finish, without pausing for approval:**
1. `gh issue create` — one issue per task, **before** any code.
2. Branch `feat/<name>` → **6–9 atomic commits**, one per logical change (types · schema · component · styles · test · docs · cleanup). Push after every commit; unpushed commits count for nothing.
3. `gh pr create` with `Closes #N` in the body.
4. Merge on green without asking: `gh pr merge --merge --delete-branch`. Then tag (feat → minor, fix → patch).

## Hard rules
- **Never squash-merge, never rebase-merge, never `--amend` a pushed commit, never batch unrelated files into one commit.** Squash collapses 9 contributions into 1. Merge commits only.
- Fewer than 6 commits on a feature = committed too coarsely. Say so and split before merging.
- The git author email must be the one verified on the GitHub account — a different email scores zero.
- Per-project override, one line in its `AGENTS.md`/`CLAUDE.md`: `no-mistakes` → stop after step 3 for review · `local-only` → no remote, skip steps 1 and 3.
- Never claim "done" without evidence: test output, build exit code, or a real screenshot.
