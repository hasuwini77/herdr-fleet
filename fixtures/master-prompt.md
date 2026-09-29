# Fixture — sample master prompt

Reference input for `/fleet --dry-run`. Re-render after editing `skills/fleet/SKILL.md`
and diff against `expected.md` — the graph shape, the `inner:` lines and the
rendered prompts are the regression surface. Assumes a Next.js app with a
GitHub remote, `direct-PR` merge mode, Playwright + vitest present.

---

Add a pricing page with three tiers that goes to Stripe checkout — we already
have a Stripe account, keys are in the env. And then also we should finally add
a dark mode toggle in the header that remembers the choice. Oh and can you
check why /api/search feels slow lately, I think it's the Postgres query but
not sure.
