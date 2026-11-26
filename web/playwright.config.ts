// The browser suite (SPEC check 11's start): Chromium against a running server with the synthetic
// export imported and fixtures/tei mounted, as scripts/compose-smoke --e2e sets it up.
import { defineConfig, devices } from '@playwright/test';

// The suite's paths are relative, so it runs under FRUS_E2E_BASE_URL's path as it does at the root
// (PLAN's S14f). The URL ends in a slash, or a relative path would replace its last name.
const baseURL = (process.env.FRUS_E2E_BASE_URL ?? 'http://localhost:8080/').replace(/\/?$/, '/');

// Behind a proxy that signs people in (PLAN's S14e), the sign-in spec runs alone, signing in as it
// goes; on a server with accounts of its own (S20b), the accounts spec runs alone; on the smoke test's
// Standalone server (S21c), the library spec runs alone, downloading; everywhere else, the rest run
// without the first two, the library spec's Import server's test among them.
const signIn = /sign-in\.spec\.ts$/;
const signingIn = !!process.env.FRUS_E2E_SIGN_IN;
const accounts = /accounts\.spec\.ts$/;
const withAccounts = !!process.env.FRUS_E2E_ACCOUNTS;
const library = /library\.spec\.ts$/;
const standalone = !!process.env.FRUS_E2E_LIBRARY;
// The update review (PLAN's S21f): on the smoke test's Standalone server, before and after its update.
const updateReview = /update-review\.spec\.ts$/;
const reviewing = !!process.env.FRUS_E2E_UPDATE_REVIEW;
// The cross-reference graph (PLAN's S23e): its spec's second test, on the smoke test's Standalone server,
// over its index of the three fixture volumes.
const graph = /graph\.spec\.ts$/;
const graphing = !!process.env.FRUS_E2E_GRAPH;
// Source Explorer (PLAN's S22d): its spec's second test, on the smoke test's Standalone server, over its index of
// the three fixture volumes.
const sources = /sources\.spec\.ts$/;
const sourcing = !!process.env.FRUS_E2E_SOURCES;
// Look Up and Send to Zotero Library (PLAN's S22e): its spec, on the smoke test's Standalone server, whose stand-ins
// of NARA and Zotero FRUS_SERVICES_MIRROR names.
const lookUp = /look-up\.spec\.ts$/;
const lookingUp = !!process.env.FRUS_E2E_LOOK_UP;
// The People screen (PLAN's S21g): its spec's Standalone tests, a sheet's Career and Subjects with a chip followed (its
// follow-up) and a merge by keyboard, on the smoke test's Standalone server, which applies a correction at once.
const people = /people\.spec\.ts$/;
const correcting = !!process.env.FRUS_E2E_PEOPLE;
// Distinctive and Collocates (PLAN's S29f): its spec's Standalone tests, a fixture volume's ranking and a search's
// collocates, on the smoke test's Standalone server, whose index holds the three fixture volumes' text.
const language = /distinctive-collocates\.spec\.ts$/;
const ranking = !!process.env.FRUS_E2E_LANGUAGE;
// Archives Visits (PLAN's S30c): its spec's Standalone tests, a plan seeded from a project's notes over the smoke test's
// Standalone server's index of the three fixture volumes, whose source notes derive its targets, and (S30d) a document added
// from its sources and the plan's packet opened and saved.
const visits = /visits\.spec\.ts$/;
const planning = !!process.env.FRUS_E2E_VISITS;

export default defineConfig({
  testDir: './e2e',
  ...(signingIn
    ? { testMatch: signIn }
    : withAccounts
      ? { testMatch: accounts }
      : standalone
        ? { testMatch: library }
        : reviewing
          ? { testMatch: updateReview }
          : graphing
            ? { testMatch: graph }
            : sourcing
              ? { testMatch: sources }
              : lookingUp
                ? { testMatch: lookUp }
                : correcting
                  ? { testMatch: people }
                  : ranking
                    ? { testMatch: language }
                    : planning
                      ? { testMatch: visits }
                      : { testIgnore: [signIn, accounts, updateReview] }),
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
