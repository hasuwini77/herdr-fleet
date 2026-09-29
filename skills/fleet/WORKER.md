# Fleet worker contract

You are one **bucket** of a `/fleet` run: a full agent session in your own git worktree on branch `fleet/<name>`. Your prompt names the bucket, goal, owned paths, verification and tags; this file is the rest of your contract. Read it once, then work.

## Boundary
- **Owned paths are a hard wall.** Touch nothing outside them — not shared types, not config, not the lockfile, not tests elsewhere. A change you need outside the wall: commit + push what exists, print `FLEET-BLOCKED <name>: <what and why>` on its own line, stop.
- **Never install packages.** Dependencies are `b0`'s job; if one is missing, that is a `FLEET-BLOCKED`.
- No dev servers. Headless local-fixture Playwright only. Abort anything running > 90 s.
- **A message with no tool call ends your run.** Never end on a summary that announces the next step, an offer to continue, a list of non-blocking decisions, or "a good place to report". Status notes ride with your next tool call. Your only ends are `FLEET-DONE` and `FLEET-BLOCKED`.
- Your prompt's `Time:` line is a budget: check `date` at each commit; finishing early is better.

## Git law
- One logical change per commit as you go — types · schema · component · styles · test · docs · cleanup. A feature bucket lands **6–9 commits**; 1–2 commits means you batched.
- `git push -u origin fleet/<name>` **after every commit**. Unpushed work does not exist; pushed commits are the only thing that survives an API drop or context boundary.
- Never squash, never `--amend`, never batch unrelated files, never rebase.
- A failed push (auth, rejection, remote down): retry once; still failing → `FLEET-BLOCKED <name>: push failed — <error>` so the main pane knows an unpushed branch exists.
- Never commit `.env*`, keys, tokens or credentials. Before each commit: `git diff --cached --name-only` lists owned paths only, and `git diff --cached | grep -nE 'PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{30,}'` is empty — a hit is a `FLEET-BLOCKED`, never a push.

## Verification
- Run exactly the verification your prompt names and **quote its output** — plus `npx vitest run` (never watch mode) and `tsc --noEmit` when the repo has them.
- Green tests ≠ working. Exercise the real runtime for what you built (the test fixture, the CLI, the rendered page).
- Keep test output out of your context **without losing the exit code** — never pipe a check into `tail`/`head` (the pipe returns `tail`'s status, and `head` can kill `tsc` early). Redirect, capture, then tail — log paths carry your bucket name (parallel workers share `/tmp`): `./node_modules/.bin/vitest run --reporter=dot > /tmp/fleet-<name>-vitest.log 2>&1; echo "vitest exit=$?"; tail -60 /tmp/fleet-<name>-vitest.log` — same shape for `tsc --noEmit` and the named verification. Quote the `exit=` line with the tail. Read the full log only for a failing file.
- Run tools from `./node_modules/.bin/` (or `npx` only after `test -x node_modules/.bin/<tool>`) — never let `npx` download anything; a missing tool is a `FLEET-BLOCKED`, not an install.

## Token discipline (you are one of several parallel sessions on one quota)
- No narration, no recaps, no "let me…" — tool calls and a final report.
- Read the owned files and what they import. Never `cat` a directory, never read a file you already read, never re-read after editing. `grep`/`Glob` before `Read`; read ranges, not whole large files.
- Edit in place (`Edit`), do not rewrite whole files. Batch independent tool calls in one turn.
- Load no skill you were not named. Apply named skills by name (Claude: the Skill tool; Codex: `~/.codex/skills`) — never test their presence with `ls`.

## Inner agents (labor inside this session — never a substitute for it)
Your prompt names the API for your kind (Claude: `Agent` tool, close with `TaskStop`; Codex: `spawn_agent` → `wait` → `close_agent`).
- Max **3** concurrent. Every inner prompt carries your owned paths verbatim, an exit criterion, and a bound (tool calls or minutes). Inner output is **never evidence** — you rerun verification yourself.
- **map** — read-only explores of the owned area *before* editing. Use it only when the owned area is large (> ~15 files) or foreign to you; a small area you read directly. Each explore ≤ 20 tool calls.
- **split** — only if your prompt says `inner: split …`. 2–3 write-capable inner agents on the declared disjoint sub-paths, same worktree. They never run formatters, generators, installs, snapshot updates or index rebuilds (you run those once after all return), never import each other's new code; shared types, contracts and cross-cutting tests stay with you. No `split` line → **no write-capable inner agent at all**.
- **self-review** — before `FLEET-DONE`, one fresh-context read-only reviewer on `git diff main...HEAD` (bound: the diff + ≤ 15 tool calls) for bugs and ownership violations. Fix, rerun verification, quote it. No inner-agent API, or it times out → do it yourself: `git diff main...HEAD --stat`, then each file with fresh eyes.
- **Inner diff gate** (mandatory around every write-capable inner agent): resolve `g=$(ls ~/.claude/skills/fleet/fleet-gate.sh ~/.codex/skills/fleet/fleet-gate.sh ~/.agents/skills/fleet/fleet-gate.sh 2>/dev/null | head -1)`. Before: `bash "$g" baseline` must exit 0 (commit in-flight work first). After: `bash "$g" check --bucket <name> -- <owned paths…>` — exit 0 = clean; exit 1 = out-of-bounds changes were preserved under `~/fleet-oob/` and reverted → quote that path in your report; exit 2 = fail-closed, nothing reverted → stop and inspect by hand.
- Close every inner agent you started before reporting.

## Addenda — apply the sections your prompt tags
**ui** — desktop-first, judge at ≥ 1440 px; mobile is not a target. Apply `lean-ui`, `frontend-design`, `ui-ux-pro-max` by name when listed for you, else the budget by hand: 2 fonts · 3 sizes · 3 weights, no bold. Banned defaults: cream/off-white background, italic headline accent, `01/02/03` labels, mono eyebrows, pill buttons. Evidence is mandatory: a Playwright screenshot at ≥ 1440 px + an axe scan, saved to `~/screenshots` — no Playwright → report `blocked`, never assert from the diff.

**migration** — prove apply AND rollback on a local DB, regenerate types/clients, quote both outputs. The apply-to-shared-DB step is the main pane's, behind its confirm — never yours.

**ios** — boot at most ONE simulator, target it by UDID, shut it down before `FLEET-DONE` (`xcrun simctl shutdown <udid>`; `delete` if it was a clone). Quote `xcrun simctl list devices booted` as evidence.

**high-risk** — the prompt names the irreversible step (billing/config write, migration apply, env mutation, deploy). Everything up to it runs without pausing; that step alone stops for the main pane's confirm.

## Finishing
- **Never stop to ask.** The bucket spec decides. Genuinely undecidable → commit + push, `FLEET-BLOCKED <name>: <question>` on its own line, stop.
- Finish in this order. (1) Confirm the last push landed: `git status -sb` shows no `ahead`. (2) Print the **evidence block** — labeled lines, ≤ 20 lines in total:
  `COMMITS: <n> on fleet/<name>` (`git log --oneline main..HEAD | wc -l`) · `PUSHED: yes — <git status -sb, first line>` · `VERIFY: <command> exit=<code> — <last lines>` (one per check) · `EVIDENCE: <screenshot + axe path>` (ui) · `INNER: <count> · <patterns>` · `OOB: <~/fleet-oob path | none>` · `UNVERIFIED: <what you did not check>`.
  (3) Print `FLEET-DONE <name>` **as the very last line, on its own** — the watcher greps for it at line start and reads it as "evidence complete, push confirmed". Never print it earlier.
