# Fixture — expected rendering of `master-prompt.md`

Rendered by hand from SKILL.md v0.9.1 (Claude Code orchestrator). Three ideas
at two connective pivots ("And then also…", "Oh and…"). Dependency scan:
pricing needs the `stripe` package (lockfile → `b0`), dark mode touches the
header + a theme provider, search is investigation only.

## Intake questions
None — no fork changes the graph. (The Stripe *product/price IDs* are read
from env at runtime; if they were missing that would be one batched question.)

## Bucket graph (printed, then spawned — no pause)

| name | shape | role | goal | owned | verification | depends | inner | tags | kind |
|---|---|---|---|---|---|---|---|---|---|
| b0 | ship — **main pane** (below the size bar: one dep + one type, ~10 min) | foundation | add `stripe` dep + shared `Tier` type | `package.json`, lockfile, `lib/billing/types.ts` | `tsc --noEmit` | — | — | — | — |
| pricing | ship ⚠ HIGH-RISK — own bucket, merges LAST | billing | pricing page → Stripe Checkout session | `app/(marketing)/pricing/**`, `app/api/checkout/**`, `lib/billing/**` (except types.ts) | `npx vitest run lib/billing app/api/checkout` + headless Playwright: click tier → Checkout URL 303 | b0 | — | high-risk: any Stripe dashboard/config write | codex |
| darkmode | ship | designer | header toggle, persisted theme | `components/theme/**`, `components/header/**`, `app/globals.css` (theme tokens only) | `npx vitest run components/theme` + Playwright screenshot ≥1440px light/dark + axe | — | split: `components/theme` \| `components/header` | ui | — |
| search-perf | scout (inner) | analyst | why is `/api/search` slow — query plan, indexes, N+1? | read: `app/api/search/**`, `lib/db/**`, `prisma/schema.prisma` | findings report with `EXPLAIN ANALYZE` evidence | — | — | — | — |

Challenge line: weakest split is `darkmode` vs `pricing` both touching
`app/globals.css` — resolved by scoping darkmode to theme tokens only and
forbidding pricing from touching globals; serial alternative is
b0 → darkmode → pricing in one session (~2.5 h vs ~1 h wall).

Sessions: 2 (pricing + darkmode in parallel, after the main pane lands b0 on
`fleet/b0`). Inner: 1 scout in the main pane, up to 2 split workers inside
darkmode. v0.8.0 spent a third session on b0; the size gate now keeps it home.

## Rendered — inner scout prompt (main pane, Claude: `Agent` subagent_type Explore, model haiku)

> Question: why does `/api/search` feel slow? Look ONLY at `app/api/search/**`,
> `lib/db/**`, `prisma/schema.prisma`. Read-only — no edits, no commits. Bound:
> 25 tool calls. Exit: a findings report — ANSWER / EVIDENCE (file:line) / OPEN.
> If the answer needs a live `EXPLAIN ANALYZE`, say so; the parent decides on
> promotion to a `scout (tab)`.

Promotion trigger: the scout returns "needs a live query plan" → `scout (tab)`
on haiku with DB access, graph amended.

## Rendered — ship prompt, `darkmode` (kind: claude)

> Bucket darkmode — issue #N. First read ~/.claude/skills/fleet/WORKER.md and obey it; it is your contract.
> Goal: header toggle that switches light/dark and persists the choice.
> Owned paths (hard boundary — touch nothing outside): `components/theme/**`, `components/header/**`, `app/globals.css` (theme tokens only).
> Verification (run and quote): `npx vitest run components/theme`; `tsc --noEmit`; headless Playwright screenshot at ≥1440px light + dark, axe scan, to `~/screenshots`.
> Inner: split: `components/theme` | `components/header` · API: the `Agent` tool: `Explore` read-only, `general-purpose` writes; close with `TaskStop`.
> Tags: ui.
> Time: started 14:05, budget 45 min.
> Non-negotiable: push after every commit (6–9 per bucket); never stop to ask — undecidable → commit, push, `FLEET-BLOCKED darkmode: <question>`; finish with the labeled evidence block (≤ 20 lines, every check with its exit code), then `FLEET-DONE darkmode` as the very last line.

Everything v0.8.0 rendered inline — git law, inner-agent patterns and bounds,
the `fleet-gate.sh` baseline/check lines, the UI budget and evidence rule, the
resume semantics — the worker now reads from `WORKER.md` (Sonnet input, once)
instead of the orchestrator writing it (Fable output, per bucket).

Expected tail of the worker's pane when it finishes (marker LAST — the watcher
reads it as "evidence complete, push confirmed"):

```
COMMITS: 7 on fleet/darkmode
PUSHED: yes — ## fleet/darkmode...origin/fleet/darkmode
VERIFY: ./node_modules/.bin/vitest run components/theme exit=0 — Tests 14 passed (14)
VERIFY: tsc --noEmit exit=0 —
EVIDENCE: ~/screenshots/darkmode-1440-light.png, ~/screenshots/darkmode-1440-dark.png, axe 0 violations
INNER: 3 · split ×2 (theme, header) · self-review ×1
OOB: none
UNVERIFIED: keyboard focus ring on the toggle in Safari
FLEET-DONE darkmode
```

Spawn lines for this bucket (Claude Code orchestrator): worktree
`b=fleet/darkmode; d=../app-darkmode; git show-ref -q --verify "refs/heads/$b"
&& git worktree add "$d" "$b" || git worktree add "$d" -b "$b"` + the
`symbolic-ref` assert; `herdr agent start darkmode --kind claude --pane <pane>
-- --model sonnet --dangerously-skip-permissions`; dispatch `herdr agent prompt
darkmode "<prompt>" --wait --until working --timeout 20000`.

## Rendered — ship prompt, `pricing` (kind: codex) — NEGATIVE CASE: no `inner:` declared

> Bucket pricing — issue #N. First read ~/.codex/skills/fleet/WORKER.md and obey it; it is your contract.
> Goal: pricing page with three tiers → Stripe Checkout session.
> Owned paths (hard boundary — touch nothing outside): `app/(marketing)/pricing/**`, `app/api/checkout/**`, `lib/billing/**` except `lib/billing/types.ts`.
> Verification (run and quote): `npx vitest run lib/billing app/api/checkout`; `tsc --noEmit`; headless Playwright against the local fixture: click a tier → 303 to a Checkout URL.
> Inner: — · API: `spawn_agent(agent_type="fleet-scout"|"fleet-reviewer")`, then `wait`, then `close_agent` (no `fleet-worker`: no split declared).
> Tags: high-risk: any write to the Stripe account or dashboard config stops for the main pane's confirm; everything else runs without pausing.
> Time: started 14:05, budget 60 min.
> Non-negotiable: push after every commit (6–9 per bucket); never stop to ask — undecidable → commit, push, `FLEET-BLOCKED pricing: <question>`; finish with the labeled evidence block (≤ 20 lines, every check with its exit code), then `FLEET-DONE pricing` as the very last line.

Spawn line (kind: codex, from `references/runtimes.md`): `herdr agent start
pricing --kind codex --pane <pane> -- -m gpt-5.5 -a never -s danger-full-access`.

## Watch (Claude Code orchestrator)

`Monitor({command: 'w=$(ls ~/.claude/skills/fleet/fleet-watch.sh
~/.codex/skills/fleet/fleet-watch.sh ~/.agents/skills/fleet/fleet-watch.sh 2>/dev/null | head -1);
bash "$w" --follow --timeout 3300 pricing:<pane> darkmode:<pane>', description: 'fleet:
pricing darkmode', timeout_ms: 3600000, persistent: false})` — after `b0` merged.
Expected stream: `HEARTBEAT 2 working: pricing darkmode` (every 15 min — **no action**)
… `EVENT darkmode <pane> working -> done marker=FLEET-DONE (1 still working: pricing)`
… `EVENT pricing … marker=FLEET-DONE (0 still working)` … `ALL-SETTLED 2 label(s)`.
On each EVENT: `agent get` + `agent read --lines 60` for that agent only. A
`marker=none` settle is the resume path in §4, not a result.

## Merge (review on a diet)

Per bucket: `sha=$(git rev-parse fleet/darkmode)`, `git diff --name-only main...$sha` (ownership gate, pinned) →
`git diff --stat main...fleet/darkmode` + the worker's ≤ 20-line evidence block
+ its self-review findings → full diff only if ≤ ~400 changed lines, else per
file, source before tests; `app/globals.css` read in full (it is the risky
one), the lockfile from `b0` checked by `--stat` only → re-run verification →
assert `git rev-parse fleet/darkmode` still equals `$sha` → `gh pr create` (`Closes #N`)
→ merge commit → teardown + verification line.

Checks (all hold in this rendering):
- Both ship prompts are ≤ 8 lines, name the contract path for their own kind (`~/.claude/…` vs `~/.codex/…`, `test -r` before dispatch), and require the labeled evidence block then `FLEET-DONE <name>` as the last line + the `FLEET-BLOCKED` rule.
- Every `VERIFY:` line carries an `exit=` code captured from the command, not from a `tail`/`head` pipe; the orchestrator accepts the block only with all `exit=0` + `PUSHED: yes` (+ `EVIDENCE:` for `ui`).
- Both start lines carry their kind's unattended flags; dispatch uses `--wait --until working`.
- Watch targets use bucket names (`pricing`, `darkmode`), not roles (`billing`, `designer`).
- Claude prompt names `Agent`/`Explore`/`general-purpose`/`TaskStop`, never `spawn_agent`.
- Codex prompt names `spawn_agent`/`wait`/`close_agent`, never `Agent` tool, `/ui-test`, `TaskStop`.
- Bucket without `inner:` → `Inner: —` and `fleet-worker` absent from its API line.
- `b0` owns the lockfile → no `split` offered, and being below the size bar it builds in the main pane, not a session.
- `darkmode` split sub-paths are disjoint and both inside its owned list; `Tags: ui` selects the WORKER.md addendum.
- Scout is `(inner)` with a bound and a promotion trigger; it never gets a tab up front.
- Nothing paused between the printed graph and spawn; only the pricing bucket's Stripe write confirms.
- HEARTBEAT lines produce no orchestrator action; EVENT reads are 60 lines, named agents only; a `marker=none` bucket is resumed at most once, after `git status`/`log` on its worktree.
