# Runtimes — read the row for the runtime you are in, and for each worker's `kind`

The core `SKILL.md` inlines the Claude Code row. Read this file when you are a **Codex orchestrator**, or when a bucket declares `kind: codex` / another Herdr kind.

| | Claude Code | Codex | other Herdr kinds |
|---|---|---|---|
| orchestrator model | Fable — never switched | gpt-5.5, reasoning high | — (sessions only) |
| ship worker start | `herdr agent start <name> --kind claude --pane <pane> -- --model sonnet --dangerously-skip-permissions` | `herdr agent start <name> --kind codex --pane <pane> -- -m gpt-5.5 -a never -s danger-full-access` | `--kind <k>` + that agent's own model + unattended flags |
| cheap tier (scout / grunt) | `--model haiku --dangerously-skip-permissions` · inner: `Explore` | `-m gpt-5.4-mini -a never -s read-only` · inner: `herd-scout` | — |
| unattended flags — why | the orchestrator runs `claude --dangerously-skip-permissions`; a worker without it sits `blocked` at its first Bash call, unwatched | `~/.codex/config.toml` sets `approval_policy = "never"` on the user's machines; the flags make the worker independent of that file | that agent's own auto-approve flag, or the kind is sessions-off |
| inner-agent API line (goes in the worker prompt) | "the `Agent` tool: `Explore` for read-only, `general-purpose` for writes; close with `TaskStop`" | "`spawn_agent(agent_type=\"herd-scout\"\|\"herd-worker\"\|\"herd-reviewer\")`, then `wait`, then `close_agent`" (types registered by `install.sh --codex-config`) | none — inner patterns disabled, sessions only |
| inner scout (main pane) | `Agent` subagent_type `Explore`, model haiku | `spawn_agent(agent_type="herd-scout")` → `wait` → `close_agent` | a `scout (tab)` on the cheap tier |
| fleet watch | `Monitor` tool + `herd-watch.sh --follow` (§4) | one background shell call, one-shot: `bash "$w" --timeout 900 <name>:<pane> …` — exits on the first settle (exit 0) or `TIMEOUT` (exit 3); re-arm for the buckets still working after every wake | same as Codex |
| worker contract path | `~/.claude/skills/herd/WORKER.md` | `~/.codex/skills/herd/WORKER.md` | `~/.agents/skills/herd/WORKER.md` |
| plan review | `/codex-reviewer` | the same 3-lens `codex exec -m gpt-5.5` panel (a shell command) | same panel |
| UI evidence | `lean-ui` + `frontend-design` + `ui-ux-pro-max`, `/ui-test` at merge | the same skills if present under `~/.codex/skills`, else Playwright screenshot ≥ 1440 px + axe | Playwright screenshot + axe |
| merge conflicts | `resolving-merge-conflicts` skill | plain git | plain git |
| close inner agents | `TaskStop` | `close_agent` | — |
| global rules file | `~/.claude/CLAUDE.md` (`claude-md-snippet.md`) | `~/.codex/AGENTS.md` (`codex-agents-snippet.md`) | that agent's own |

Mixed fleets are normal: a Claude orchestrator may run a `kind: codex` worker and vice versa. The worker prompt names commands, paths, its contract path and the inner-agent API line for its own kind, so nothing else needs translating. The watcher and the merge queue don't care which kind built the branch.

## Codex role files
`codex/agents/herd-{scout,worker,reviewer}.toml` — read-only scout (≤ 25 tool calls, `SCOUT-DONE`), write-capable split worker (`workspace-write`, never commits, `WORKER-DONE`), fresh-context reviewer (`read-only`, severity-classified findings, `REVIEW-DONE`). `install.sh --codex-config` registers them in `$CODEX_HOME/config.toml` with a parse check, backup and marker guard.
