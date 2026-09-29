# herdr-fleet

Parallel builds for Claude Code and Codex on [Herdr](https://herdr.dev).

`/fleet <task>` splits a task into **file-disjoint buckets**, starts one agent per bucket
in its own Herdr tab and git worktree, watches them with a zero-token bash watcher, then
reviews, merges and tags them one by one from your main pane. `/crew` is the smaller
rung: up to 3 in-process subagents in one worktree, one branch, one PR.

The Herdr plugin adds two things to the action menu:

- **Fleet: install skills** — links `/fleet` and `/crew` into `~/.claude/skills`,
  `~/.codex/skills` and `~/.agents/skills` (symlinks only, never overwrites a real directory).
- **Fleet: show board** — a popup with every agent whose worktree is on a `fleet/*` branch:
  status, commits ahead, last commit. Refreshes every 3 s; `q` closes.

```text
Fleet board  16:16:56                                   (demo data)

BUCKET         PANE     STATUS   AHEAD  LAST COMMIT
darkmode       w3:p2    working  4      feat(theme): persist choice in localStorage
pricing        w3:p3    done     6      test(pricing): rounding cases
search         w3:p4    blocked  1      feat(search): debounce query input
```

## Install

```sh
herdr plugin install hasuwini77/herdr-fleet
herdr plugin action invoke hasuwini77.fleet.install
```

Or clone it and run `./install.sh` (`--dry-run` shows every action first).

Requirements: herdr ≥ 0.7.4 on PATH, `jq`, git, Claude Code and/or Codex CLI.
Plugin tested with herdr 0.8.2 on Linux (WSL2); the skills also run on macOS.

## How a run flows

1. **Gate.** Small or risky tasks (auth, billing, migrations, deploy config) stay in the
   main pane. Only genuinely file-disjoint work fans out, max 3 parallel sessions.
2. **Plan.** Each bucket gets a goal, owned paths (a hard wall), a verification command
   and a time budget.
3. **Ship.** One worker per bucket, started with a short prompt that points at
   `skills/fleet/WORKER.md`, its contract: push after every commit, stay inside owned
   paths, end with an evidence block and `FLEET-DONE <name>` — or `FLEET-BLOCKED`.
4. **Watch.** `fleet-watch.sh` reports each worker settling; no model tokens are spent
   while waiting.
5. **Merge.** The main pane reviews each branch, re-runs its verification, merges in
   order and tags once everything is on main.

`claude-md-snippet.md` and `codex-agents-snippet.md` hold the rules to paste into your
agent's global instructions.

## Tests

```sh
bash skills/fleet/tests/fleet-budget.test.sh   # size budget + contract lint
bash skills/fleet/tests/fleet-gate.test.sh
bash skills/fleet/tests/fleet-watch.test.sh
bash plugin/board.test.sh
```

## License

MIT
