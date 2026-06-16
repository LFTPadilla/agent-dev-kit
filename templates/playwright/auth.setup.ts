// auth.setup.ts — log in once as a real user, save the session for reuse.
// Generic: works for any SSO/provider (WorkOS, Cognito, Auth0) or a plain form.
// Credentials come from env vars (E2E_USER / E2E_PASS) — never hardcode.
//
// Wire it up in playwright.config.ts:
//   projects: [
//     { name: 'setup', testMatch: /auth\.setup\.ts/ },
//     { name: 'chromium', dependencies: ['setup'],
//       use: { storageState: 'playwright/.auth/user.json' } },
//   ]
// And gitignore: playwright/.auth/

import { test as setup, expect } from '@playwright/test'

const authFile = 'playwright/.auth/user.json'

setup('authenticate', async ({ page }) => {
  await page.goto('/login')

  // Adjust the three lines below to your login UI / provider.
  await page.getByLabel(/email/i).fill(process.env.E2E_USER!)
  await page.getByLabel(/password/i).fill(process.env.E2E_PASS!)
  await page.getByRole('button', { name: /sign in|log in/i }).click()

  // Wait for a real post-login signal — not a fixed sleep.
  await expect(page.getByRole('button', { name: /sign out|account|profile/i })).toBeVisible()

  await page.context().storageState({ path: authFile })
})

// MFA / bot-protected SSO: replace the fill/click block with a one-time
// interactive login (`await page.pause()`), complete it by hand, then let the
// storageState line persist it. Refresh when the session expires.
