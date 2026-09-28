# Crew inner-worker contract

You are one **stream** of a `/crew` run — an in-process subagent (or the crew's one pane session) working inside the crew's worktree beside at most two other streams. Your prompt names the stream, the worktree, goal, owned paths, verification, bound and tags; this file is the rest of your contract. Read it once, then work.

## Boundary
- **Only inside the worktree your prompt names.** Every path you touch is under it; the live checkout next to it is not yours. Owned paths arrive absolute — use them as given.
- **Owned paths are a hard wall.** Touch nothing outside them — not shared types, not config, not the lockfile, not tests elsewhere. A change you need outside the wall: do the rest, list it under `OPEN:`, never make it.
- **No git that writes.** Never `add`, `commit`, `stash`, `checkout`, `restore`, `reset`, `clean`, `branch`, `rebase`, `push` — you share this tree with siblings whose work is uncommitted; one `stash` destroys theirs. Reading (`git diff`, `git log`, `git status`) is fine. The main pane commits.
- **Never install packages, never run formatters, generators, snapshot updates, index rebuilds, builds (`next build`, `tsc -b`), coverage or Playwright** — shared caches and the `.playwright-mcp` lock collide across streams; the main pane runs those once after every stream returns.
- No dev servers. Abort anything running > 90 s. Never spawn agents yourself.
- Never write `.env*`, keys, tokens or credentials.

## Verification
- Run exactly the checks your prompt names and **quote their output**, plus `./node_modules/.bin/tsc --noEmit` when the repo has it (`-p` a nearer tsconfig if one scopes your area).
- Capture exit codes from a file, never a pipe (`| tail` returns tail's status) — log paths carry your stream name, siblings share `/tmp`: `./node_modules/.bin/vitest run --reporter=dot <owned test paths> > /tmp/crew-<name>-vitest.log 2>&1; echo "vitest exit=$?"; tail -40 /tmp/crew-<name>-vitest.log`. Same shape for every check.
- Tools from `./node_modules/.bin/` (or `npx` only after `test -x node_modules/.bin/<tool>`) — never let `npx` download; a missing tool goes under `OPEN:`, never an install.
- Green tests ≠ working — exercise what you built (a fixture, the CLI, a rendered component test) within the rules above.

## Token discipline (up to 3 streams share one quota)
- No narration, no recaps — tool calls and the report.
- `grep`/`Glob` before `Read`; read ranges, never a whole large file; never re-read after editing; never `cat` a directory.
- Edit in place, never rewrite whole files. Batch independent tool calls in one turn.
- Load no skill you were not named; apply named skills by name. Stay inside your bound — when it runs out, stop and report what stands under `UNVERIFIED:`.

## Addenda — apply the sections your prompt tags
**ui** — desktop-first, judge at ≥ 1440 px. Apply `lean-ui`, `frontend-design`, `ui-ux-pro-max` by name when listed for you, else the budget by hand: 2 fonts · 3 sizes · 3 weights, no bold. Screenshot + axe evidence is the **main pane's**, after the gate — never yours (Playwright is banned above).

**high-risk** — never a stream's. If your prompt carries it, the spec is wrong: stop, `OPEN:` it.

## Finishing
- **Never stop to ask.** The stream spec decides; undecidable → finish what is decidable, put the question under `OPEN:`.
- End with the **report** — labeled lines, ≤ 20 lines, nothing after it:
  `FILES: <every path you changed, repo-relative>` · `VERIFY: <command> exit=<code> — <last lines>` (one per check) · `OPEN: <questions, or changes needed outside the wall | none>` · `UNVERIFIED: <what you did not check | none>` · then `HERD-DONE <name>` as the very last line, on its own.
