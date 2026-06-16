---
name: playwright-stability
description: Make a Playwright E2E suite stable and realistic — kill flaky tests and authenticate like a real user via storageState (login once, reuse). Use when E2E tests are flaky, slow, re-login in every test, mock auth instead of using it, or when hardening a suite before relying on it.
---

# Playwright stability & real-user auth

Two jobs: (1) stop flakes, (2) authenticate like a real user without paying the
login cost per test. Both raise realism and reliability at once.

## Anti-flaky checklist

1. **Locators by role first.** `getByRole(name)` → `getByLabel` → `getByText` → `getByTestId`. CSS/XPath last. Role locators double as an accessibility check.
2. **Web-first assertions only.** `await expect(locator).toBeVisible()` auto-waits. Never `waitForTimeout`, never assert on a snapshot you grabbed manually.
3. **No manual sleeps.** Replace every fixed wait with an assertion on the state you actually need (`toHaveURL`, `toBeEnabled`, `toHaveText`).
4. **Trace on first retry + screenshot on failure.** Open the Trace Viewer before editing flaky code — DOM/network/console at each step finds the cause in minutes.
5. **`retries: 2` in CI**, 0 locally (a local flake is a bug to fix, not retry).
6. **Isolate.** Each test sets up its own data; no shared mutable state, no order dependency.
7. **One clean server.** Kill stray dev servers and confirm the port is free before a full run — a stale server serves old assets and fakes failures.

## Real-user auth via storageState (stop mocking the session)

Mocking auth is the least realistic part of a suite. Instead log in **once**,
save the browser state, and every test starts already authenticated — real
tokens, real session, near-zero per-test cost.

See [`templates/playwright/auth.setup.ts`](../../../../templates/playwright/auth.setup.ts)
and the config snippet beside it.

- Run the provider's real login (WorkOS / Cognito / Auth0 / your own form) in a
  `setup` project, then `context.storageState({ path })`.
- Other projects depend on that setup and load `storageState`.
- **Keep the state file out of git** (it holds live tokens) and regenerate it at
  the start of each CI run — never commit and reuse across days.
- MFA / bot-protected SSO: do the login interactively once, persist the state,
  refresh when it expires. Credentials come from env vars, never hardcoded.

## Config (the bits that matter)

```ts
export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  use: { trace: 'on-first-retry', screenshot: 'only-on-failure' },
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    { name: 'chromium', dependencies: ['setup'],
      use: { storageState: 'playwright/.auth/user.json' } },
  ],
})
```
