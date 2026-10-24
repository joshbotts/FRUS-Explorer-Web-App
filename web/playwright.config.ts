// The browser suite (SPEC check 11's start): Chromium against a running server with the synthetic
// export imported and fixtures/tei mounted, as scripts/compose-smoke --e2e sets it up.
import { defineConfig, devices } from '@playwright/test';

// The suite's paths are relative, so it runs under FRUS_E2E_BASE_URL's path as it does at the root
// (PLAN's S14f). The URL ends in a slash, or a relative path would replace its last name.
const baseURL = (process.env.FRUS_E2E_BASE_URL ?? 'http://localhost:8080/').replace(/\/?$/, '/');

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI
    ? [['list'], ['github'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    // localhost is a secure context, which the clipboard needs.
    baseURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    locale: 'en-US',
    timezoneId: 'UTC',
    colorScheme: 'light',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 900 },
        permissions: ['clipboard-read', 'clipboard-write'],
      },
    },
  ],
});
