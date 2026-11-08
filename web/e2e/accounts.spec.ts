// S20b's done-when (docs/PLAN.md): Playwright signs in and out by keyboard on Chromium with no axe
// violations. scripts/compose-smoke --e2e runs this spec alone, with FRUS_E2E_ACCOUNTS set, against a
// server with FRUS_AUTH=local under a path, where the smoke test has made two accounts with
// frus-light user add, erin and frank, whose password it gives in FRUS_E2E_PASSWORD; the rest of the
// suite runs without sign-in. Any page asks for a sign-in first, and opens once erin has signed in by
// keyboard; the reader's frame, whose scripts and figures come with no cookie, works for her; she
// signs out by keyboard, back at the sign-in page; and frank, signing in at the same tab, finds none
// of her research there. The console stays clean throughout: the app asks whether it is signed in
// before it asks anything of a user, so nothing is refused.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { d1Text } from './expected';
import { expect, test } from './fixtures';
import { documentPath, dragOver, drawn, listed } from './highlights';
import { tabTo } from './keyboard';

const password = process.env.FRUS_E2E_PASSWORD ?? '';
const phrase = 'no insurmountable obstacles';

test.skip(!password, 'needs FRUS_E2E_PASSWORD, as scripts/compose-smoke gives it');

/** Signs in as `name` on the sign-in page, by keyboard alone, and waits for the header to name them. */
async function signInByKeyboard(page: Page, name: string) {
  await expect(page.getByRole('heading', { level: 1, name: 'Sign In' })).toBeVisible();
  await tabTo(page, page.getByLabel('Name'));
  await page.keyboard.type(name);
  await page.keyboard.press('Tab');
  await expect(page.getByLabel('Password')).toBeFocused();
  await page.keyboard.type(password);
  await page.keyboard.press('Enter');
  await expect(page.getByRole('banner').getByText(`Signed in as ${name}`)).toBeVisible();
}

/** Signs out from the top of a page just opened, by keyboard alone. */
async function signOutByKeyboard(page: Page) {
  await tabTo(page, page.getByRole('button', { name: 'Sign Out' }));
  await page.keyboard.press('Enter');
  await expect(page.getByRole('heading', { level: 1, name: 'Sign In' })).toBeFocused();
}

test('signs in and out by keyboard, and the next person finds none of the last one’s research', async ({ page }) => {
  await page.goto('research/notes');
  await expect(page.getByRole('heading', { level: 1, name: 'Sign In' })).toBeVisible();
  await expect(page.getByRole('navigation', { name: 'Main' })).toBeHidden();
  await expect(page.getByRole('contentinfo')).toContainText('Whoever runs this instance can read everything it keeps for you');
  await axeCheck(page);

  await signInByKeyboard(page, 'erin');
  await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeFocused();
  await expect(page).toHaveURL(/\/research\/notes$/);
  await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
  await axeCheck(page);

  // The frame's scripts come with no session: the selection bar comes, and the highlight is drawn
  // and kept as erin's.
  await page.goto(documentPath);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  expect(await listed(page)).toEqual([]);
  await dragOver(page, phrase);
  await page.getByRole('toolbar', { name: 'Selection' }).getByRole('button', { name: 'Highlight Yellow' }).click();
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1 });
  expect((await listed(page)).map((highlight) => highlight.selectedText)).toEqual([phrase]);
  await axeCheck(page);

  await page.goto('research/notes');
  await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeVisible();
  await signOutByKeyboard(page);
  await expect(page.getByRole('banner').getByText(/^Signed in as/)).toHaveCount(0);
  await axeCheck(page);

  // Frank, at the same tab, finds none of hers: not in the browser, which forgot her, nor the server.
  await signInByKeyboard(page, 'frank');
  await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeVisible();
  await page.goto(documentPath);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  expect(await listed(page)).toEqual([]);
  await expect.poll(() => drawn(page)).toEqual({});
  await axeCheck(page);
  await page.goto('research/notes');
  await signOutByKeyboard(page);
});
