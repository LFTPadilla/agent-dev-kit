---
name: stagehand
description: Write self-healing browser automation with Stagehand (act/extract/observe) — natural-language steps on top of Playwright that survive UI changes without rewriting selectors. Use for the parts of a flow that change often, or when scripted Playwright selectors keep breaking. Pilot it against one volatile flow before adopting widely.
---

# stagehand — self-healing NL automation on Playwright

Stagehand (Browserbase) is a TypeScript SDK over Playwright with three
primitives. Natural-language steps resolve at runtime, so they survive markup
changes that would break a hardcoded selector — the "self-healing" the volatile
parts of a suite need.

- `page.act("click the Connect GitHub button")` — perform an action.
- `page.observe("the primary CTA")` — find an element / preview an action.
- `page.extract({ schema })` — pull structured data from the page.

You still drop to raw Playwright for the deterministic 80%; Stagehand is for the
20% that keeps shifting. It's the same `page`, so they mix in one test.

## When to use vs not

- **Use** on flows whose DOM/labels churn, or where specs break every release on selectors.
- **Don't** use for stable, hot-path regression — plain Playwright (`getByRole` + web-first assertions) is faster, free, and fully deterministic. NL steps cost an LLM call each.

## Pilot (recommended first step)

```bash
npm i @browserbasehq/stagehand
```

```ts
import { Stagehand } from '@browserbasehq/stagehand'

const sh = new Stagehand({ env: 'LOCAL' })   // LOCAL = your machine; BROWSERBASE = cloud
await sh.init()
const page = sh.page                          // a Playwright Page, augmented
await page.goto(process.env.APP_URL!)
await page.act('open the onboarding wizard')
const { steps } = await page.extract({
  instruction: 'list the visible wizard step titles',
  schema: { type: 'object', properties: { steps: { type: 'array', items: { type: 'string' } } } },
})
await sh.close()
```

Run it against ONE flaky flow, compare maintenance cost vs the plain-Playwright
version over a few releases, then decide whether to expand. Needs an LLM API
key (set per its docs) — keep it in env, never commit.
