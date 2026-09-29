# Fixture — expected rendering of a `/crew` run

Rendered by hand from `skills/crew/SKILL.md` v0.10.0. Task, as typed in the
devdwin repo (a Next.js + R3F portfolio) from a Claude Code main pane inside
Herdr (`HERDR_ENV=1`):

> /crew give the floor labels a hover lift and a HUD counter that reads the
> commit-count API; and check whether the ripple shader is why the floor
> drops frames on hover

Three ideas at two pivots. Dependency scan: labels and HUD share no file
(`components/space/floor/**` vs `components/hud/**`); the HUD needs a `useCommitCount`
hook that both could want later → the hook is shared surface, so the main pane
writes it first (groundwork commit). The shader question is investigation.

## Fit gate
Two write streams of ~15–25 min each + one scout → `/crew`. Nothing high-risk,
nothing that needs its own dev server (headless vitest + tsc only; the Playwright
screenshot is the main pane's after the gate). Not `/fleet`: no stream is worth a
session.

## Intake questions
None — no fork changes the roster.

## Roster (printed, then spawned — no pause)

Worktree `d=/Users/you/Documents/Frontend/app-floor-hud` on `feat/floor-hud`.
Groundwork (main pane, committed first): `lib/commit-count/useCommitCount.ts` + its
type.

| name | role | goal | owned (absolute under `$d`) | verification | tier | kind | tags | bound |
|---|---|---|---|---|---|---|---|---|
| labels | designer | floor labels lift 0.15 wu on hover with a 200 ms ease | `$d/components/space/floor/FloorLabel.tsx`, `$d/components/space/floor/__tests__/**` | `./node_modules/.bin/vitest run components/space/floor` · `tsc --noEmit` | sonnet | — | ui | 60 calls / 25 min |
| hud | analyst | HUD counter reading `useCommitCount` for three repos | `$d/components/hud/**` | `./node_modules/.bin/vitest run components/hud` · `tsc --noEmit` | sonnet | codex (pane) | ui | 60 calls / 25 min |
| ripple-perf | scout | is the cursor ripple shader the hover frame drop? | read: `$d/components/space/floor/Floor.tsx`, `$d/components/space/shaders/**` | findings: ANSWER / EVIDENCE (file:line) / OPEN | haiku | — | — | 25 calls |

Challenge line: weakest split is `labels` vs `hud` both being `ui` — resolved
because the screenshot + axe evidence is the main pane's, so neither stream runs
Playwright; serial alternative is labels → hud in the main pane (~45 min vs ~25 min
wall). `hud` runs on Codex only because Herdr is up — outside Herdr the roster
would print "runs as inner sonnet — no Herdr" and proceed.

## Rendered — inner scout prompt (main pane, Claude: `Agent` subagent_type Explore, model haiku)

> Question: is the cursor ripple shader the reason the floor drops frames on hover?
> Look ONLY at `/Users/you/Documents/Frontend/app-floor-hud/components/space/floor/Floor.tsx`
> and `…/components/space/shaders/**`. Read-only — no edits, no git. Bound: 25 tool
> calls. Exit: ANSWER / EVIDENCE (file:line) / OPEN. If the answer needs a live
> profiler run, say so under OPEN; the parent decides.

## Rendered — inner stream prompt, `labels` (Claude: `Agent` general-purpose, model sonnet)

> Stream labels of crew floor-hud — issue #41. First read /Users/you/.claude/skills/crew/INNER.md and obey it; it is your contract.
> Worktree: /Users/you/Documents/Frontend/app-floor-hud — work only there. Goal: floor labels lift 0.15 world units on hover with a 200 ms ease-out, and settle back.
> Owned paths (hard boundary — touch nothing outside): /Users/you/Documents/Frontend/app-floor-hud/components/space/floor/FloorLabel.tsx, /Users/you/Documents/Frontend/app-floor-hud/components/space/floor/__tests__/**.
> Verification (run, capture exit=, quote): `./node_modules/.bin/vitest run --reporter=dot components/space/floor > /tmp/crew-labels-vitest.log 2>&1; echo "vitest exit=$?"; tail -40 /tmp/crew-labels-vitest.log`; `./node_modules/.bin/tsc --noEmit > /tmp/crew-labels-tsc.log 2>&1; echo "tsc exit=$?"; tail -20 /tmp/crew-labels-tsc.log`.
> Bound: 60 tool calls / 25 min. Tags: ui.
> Finish with the report (FILES / VERIFY exit= / OPEN / UNVERIFIED, ≤ 20 lines), then `FLEET-DONE labels` as the very last line. Never commit, never ask.

## Rendered — pane stream prompt, `hud` (kind: codex, via `herdr agent prompt hud "…" --wait --until working --timeout 20000`)

Pane: `herdr pane split --pane "$HERDR_PANE_ID" --direction right --ratio 0.4 --cwd "$d" --no-focus` → `.result.pane.pane_id` = `wR:p7`.
Agent: `herdr agent start hud --kind codex --pane wR:p7 -- -m gpt-5.5 -a never -s danger-full-access`.
Contract path `test -r`'d: `~/.codex/skills/crew/INNER.md`.

> Stream hud of crew floor-hud — issue #41. First read /Users/you/.codex/skills/crew/INNER.md and obey it; it is your contract.
> Worktree: /Users/you/Documents/Frontend/app-floor-hud — work only there. Goal: a HUD counter component that renders `useCommitCount` for web2audio, widen-island-next and hat-dropship, ink/signal palette, no bold.
> Owned paths (hard boundary — touch nothing outside): /Users/you/Documents/Frontend/app-floor-hud/components/hud/**.
> Verification (run, capture exit=, quote): `./node_modules/.bin/vitest run --reporter=dot components/hud > /tmp/crew-hud-vitest.log 2>&1; echo "vitest exit=$?"; tail -40 /tmp/crew-hud-vitest.log`; `./node_modules/.bin/tsc --noEmit > /tmp/crew-hud-tsc.log 2>&1; echo "tsc exit=$?"; tail -20 /tmp/crew-hud-tsc.log`.
> Bound: 60 tool calls / 25 min. Tags: ui.
> Finish with the report (FILES / VERIFY exit= / OPEN / UNVERIFIED, ≤ 20 lines), then `FLEET-DONE hud` as the very last line. Never commit, never ask.

Watch: `Monitor({command: 'w=$(ls ~/.claude/skills/fleet/fleet-watch.sh ~/.codex/skills/fleet/fleet-watch.sh ~/.agents/skills/fleet/fleet-watch.sh 2>/dev/null | head -1); bash "$w" --follow --timeout 3300 hud:wR:p7', description: 'crew: hud', timeout_ms: 3600000, persistent: false})`.

## Codex orchestrator variant
Same roster. `labels` → `spawn_agent(agent_type="fleet-worker")` with the prompt
above (contract path `~/.codex/skills/crew/INNER.md`; a `WORKER-DONE` last line is
accepted as the marker) → `wait` → `close_agent`. `ripple-perf` → `fleet-scout`.
The pane stream is unchanged — it is a Herdr session, not an inner agent.

## Collect, expected shape
`labels` returns first → `git -C "$d" diff > /tmp/crew-floor-hud-labels.patch`,
report read. Scout returns: ANSWER "yes — `uRipple` uniform is updated every
frame even when the cursor is still" with file:line. Monitor `EVENT hud … marker=FLEET-DONE`
→ `herdr agent read hud --source recent-unwrapped --lines 40`. Then, in order:
union gate `bash "$g" check --bucket crew-floor-hud -- <both owned lists>` (exit 0)
· attribution (every changed file claimed by a `FILES:` line) · leak check (live
`git status` unchanged) · main pane runs `next build` once, reruns both vitest +
tsc, takes the ≥ 1440 px screenshot + axe to `~/screenshots` · review on a diet ·
`TaskStop` the scout task + the Monitor, `herdr pane close wR:p7`.

## Land, expected shape
7 commits on `feat/floor-hud`, pushed each: hook (groundwork) · label lift ·
label test · hud component · hud test · ripple uniform fix (from the scout, main
pane) · docs. PR `Closes #41`, merge commit, tag v1.4.0. Cleanup verification
line printed. The scout's finding becomes its own commit, not a stream — it was
a one-line fix inside the main pane's reach.
