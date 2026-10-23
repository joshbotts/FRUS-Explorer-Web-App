// S12c's done-when (docs/PLAN.md): Playwright uses on Chromium, with no axe violations, what
// FRUS Explorer 1.0 changed that the web edition serves: a result's date where its row prints no
// dateline, the reader's Reading Width, and a search the reader replaces, which is abandoned. Against
// the image, with the synthetic export imported and fixtures/tei mounted.
import { axeCheck } from './axe';
import { treatiesDates, treatiesResults } from './expected';
import { expect, test } from './fixtures';

test('a row that prints no dateline draws the day the index dates it by, as the Mac’s window does', async ({ page }) => {
  await page.goto('/search?keywords=treaties');
  const results = page.getByRole('list', { name: 'Results' });
  await expect(results.getByRole('listitem')).toHaveCount(2);
  for (const [index, title] of treatiesResults.entries()) {
    await expect(results.getByRole('listitem').filter({ hasText: title }).locator('.meta')).toHaveText(
      `Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges · Doc ${index + 1} · ${treatiesDates[index]}`,
    );
  }
  await axeCheck(page);
});

test('the Reading Width loads the page at the app’s measure, beside Text Size, keeping focus on its control', async ({ page }) => {
  await page.goto('/doc/frus1961-63v06/d1');
  const toolbar = page.getByRole('group', { name: 'Document' });
  await expect(toolbar.getByRole('combobox')).toHaveCount(2);
  const width = toolbar.getByRole('combobox', { name: 'Reading Width' });
  await expect(width).toHaveValue('standard');
  await expect(width.locator('option')).toHaveText(['Narrow', 'Standard', 'Wide']);
  const frame = page.locator('iframe.reader-frame');
  await expect(frame).toHaveAttribute('src', /readingWidth=standard/);

  /** The page's measure, and the width its column may grow to, in pixels: read in the frame shown, once its column is there. */
  const column = () =>
    page
      .frameLocator('iframe.reader-frame')
      .locator('.frus-document')
      .evaluate((element) => ({
        measure: getComputedStyle(element.ownerDocument.documentElement).getPropertyValue('--reader-measure').trim(),
        maxWidth: parseFloat(getComputedStyle(element).maxWidth),
      }));
  await expect.poll(async () => (await column()).measure).toBe('87ch');
  const standard = await column();

  // From the keyboard, as Text Size is chosen: the page loads again, and focus stays on the control.
  await width.focus();
  await page.keyboard.press('ArrowDown');
  await expect(width).toHaveValue('wide');
  await expect(frame).toHaveAttribute('src', /readingWidth=wide/);
  await expect.poll(async () => (await column()).measure).toBe('120ch');
  await expect(width).toBeFocused();
  const wide = await column();
  expect(wide.maxWidth / standard.maxWidth).toBeCloseTo(120 / 87, 2);
  await axeCheck(page);

  // The choice outlasts the page.
  await page.reload();
  await expect(page.getByRole('group', { name: 'Document' }).getByRole('combobox', { name: 'Reading Width' })).toHaveValue('wide');
  await expect(page.locator('iframe.reader-frame')).toHaveAttribute('src', /readingWidth=wide/);
});

test('a search the reader replaces is abandoned, so the server can stop it', async ({ page }) => {
  // The first search is held on its way until the page has abandoned it, so the second replaces it
  // while it is under way.
  let release = () => {};
  const held = new Promise<void>((resolve) => (release = resolve));
  await page.route(/\/api\/v1\/search\?keywords=negotiating&/, async (route) => {
    await held;
    await route.continue().catch(() => {});
  });
  const abandoned = page.waitForEvent('requestfailed', (request) => request.url().includes('/api/v1/search?keywords=negotiating&'));
  await page.goto('/search?keywords=negotiating');
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await box.fill('treaties');
  await box.press('Enter');
  expect((await abandoned).failure()?.errorText).toBe('net::ERR_ABORTED');
  release();
  const results = page.getByRole('list', { name: 'Results' });
  await expect(results.getByRole('listitem')).toHaveCount(2);
  for (const title of treatiesResults) await expect(results.getByRole('link', { name: title })).toBeVisible();
  await axeCheck(page);
});
