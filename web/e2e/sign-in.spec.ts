// S14e's done-when (docs/PLAN.md): Playwright signs in through a proxy that sets the header, on
// Chromium with no axe violations. scripts/compose-smoke --e2e runs this spec alone, with
// FRUS_E2E_SIGN_IN set, behind docs/INSTALL.md's recipe for signing in, whose session check is a
// stand-in with a sign-in page that takes a name, against a server that trusts that proxy alone;
// the rest of the suite runs without sign-in. Two people sign in, each in a browser of their own:
// the app names each and says that whoever runs the instance can read what it keeps for them; the
// reader's frame, whose scripts and figures come with no session, works for both; and neither finds
// the other's research, nor the notes imported earlier for the server's one user.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { d1Text } from './expected';
import { expect, test } from './fixtures';
import { documentPath, dragOver, drawn, listed, removeAll } from './highlights';

const phrase = 'no insurmountable obstacles';

test.afterEach(async ({ page }) => {
  await removeAll(page);
});

/** Asks for `path`, signs in as `user` on the page the proxy shows instead, and arrives at `path`. */
async function signIn(page: Page, user: string, path: string) {
  await page.goto(path);
  await expect(page.getByRole('heading', { level: 1, name: 'Sign in' })).toBeVisible();
  await page.getByLabel('User name').fill(user);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(new RegExp(`/${path}$`));
  await expect(page.getByRole('banner').getByText(`Signed in as ${user}`)).toBeVisible();
  await expect(page.getByRole('contentinfo')).toContainText('Whoever runs this instance can read everything it keeps for you');
}

test('two people sign in through the proxy, are named, and keep their research apart', async ({ page, browser, baseURL }) => {
  await signIn(page, 'carol', 'research/notes');
  await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeVisible();
  await expect(page.getByText('No notes yet. Notes you write from a document appear here.')).toBeVisible();
  await axeCheck(page);

  // The frame's scripts come through the proxy with no session: the selection bar comes, and the
  // highlight is drawn and kept as Carol's.
  await page.goto(documentPath);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  expect(await listed(page)).toEqual([]);
  await dragOver(page, phrase);
  await page.getByRole('toolbar', { name: 'Selection' }).getByRole('button', { name: 'Highlight Yellow' }).click();
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1 });
  expect((await listed(page)).map((highlight) => highlight.selectedText)).toEqual([phrase]);
  await axeCheck(page);

  // Dave, in a browser of his own, is asked to sign in too, and finds none of it.
  const other = await browser.newContext({ baseURL, locale: 'en-US', timezoneId: 'UTC', colorScheme: 'light' });
  try {
    const dave = await other.newPage();
    const problems: string[] = [];
    dave.on('pageerror', (error) => problems.push(`page error: ${error.message}`));
    dave.on('console', (message) => {
      if (message.type() === 'error') problems.push(`console: ${message.text()}`);
    });
    await signIn(dave, 'dave', documentPath);
    await expect(dave.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
    expect(await listed(dave)).toEqual([]);
    await expect.poll(() => drawn(dave)).toEqual({});
    await axeCheck(dave);
    expect(problems).toEqual([]);
  } finally {
    await other.close();
  }
  expect(await listed(page)).toHaveLength(1);
});
