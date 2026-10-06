// S9's done-when (docs/PLAN.md): Playwright on Chromium searches, opens a document and copies a
// citation. Against the image, with the synthetic export imported and fixtures/tei mounted.
import { expect, test } from '@playwright/test';
import { d1Chicago, d1Text, treatiesResults } from './expected';

test.beforeEach(async ({ page }) => {
  // Any console error or policy violation in the app or the reader's frame fails the test.
  const problems: string[] = [];
  page.on('pageerror', (error) => problems.push(`page error: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() === 'error') problems.push(`console: ${message.text()}`);
  });
  (page as unknown as { problems: string[] }).problems = problems;
});

test.afterEach(async ({ page }) => {
  expect((page as unknown as { problems: string[] }).problems).toEqual([]);
});

test('the app is served with its policy, and every client route answers with it', async ({ request }) => {
  const app = await request.get('/');
  expect(app.status()).toBe(200);
  expect(app.headers()['content-security-policy']).toMatch(/^default-src 'self'/);
  const html = await app.text();
  for (const route of ['/search?keywords=treaties', '/doc/frus1961-63v06/d1']) {
    expect(await (await request.get(route)).text()).toBe(html);
  }
  const unknown = await request.get('/api/v1/no-such-endpoint');
  expect(unknown.status()).toBe(404);
  expect(unknown.headers()['content-type']).toBe('application/problem+json');
});

test('searches, opens a document and copies a citation', async ({ page }) => {
  await page.goto('/search');
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await box.fill('treaties');
  await box.press('Enter');
  await expect(page).toHaveURL(/\/search\?keywords=treaties$/);

  const results = page.getByRole('list', { name: 'Results' });
  await expect(results.getByRole('listitem')).toHaveCount(2);
  await expect(page.getByRole('status').filter({ hasText: 'documents match' })).toContainText('2 documents match');
  await expect(results.locator('mark')).toHaveText(['treaties', 'treaties']);
  await expect(results).not.toContainText('<b>');
  for (const header of treatiesResults) await expect(results.getByRole('link', { name: header })).toBeVisible();

  // Chosen by name: bm25 orders the two.
  await results.getByRole('link', { name: treatiesResults[0] }).click();
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d1$/);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(treatiesResults[0]);
  // A new screen takes focus at its heading.
  await expect(page.getByRole('heading', { level: 1 })).toBeFocused();

  const frame = page.frameLocator('iframe.reader-frame');
  await expect(frame.getByText(d1Text)).toBeVisible();
  // The host script ran under the frame's sandbox and the page's policy.
  const reader = page.frames().find((candidate) => candidate.url().includes('/documents/d1/html'));
  expect(reader).toBeDefined();
  expect(await reader!.evaluate(() => typeof (window as { webkit?: { messageHandlers?: { selectionChanged?: unknown } } }).webkit?.messageHandlers?.selectionChanged)).toBe('object');

  await page.getByRole('button', { name: 'Cite' }).click();
  const cite = page.getByRole('complementary', { name: 'Cite' });
  await expect(cite.getByRole('heading', { name: 'Cite' })).toBeFocused();
  await expect(page.getByRole('button', { name: 'Cite' })).toHaveAttribute('aria-expanded', 'true');
  await cite.getByRole('radio', { name: 'Chicago' }).check();
  await expect(cite.locator('.citation')).toHaveAttribute('data-style', 'chicago');

  // A sentinel first, so a stale clipboard cannot pass.
  await page.evaluate(() => navigator.clipboard.writeText('sentinel'));
  await cite.getByRole('button', { name: 'Copy Citation' }).click();
  await expect(cite.getByRole('status')).toHaveText('Copied');
  const copied = await page.evaluate(() => navigator.clipboard.readText());

  const api = await page.request.get('/api/v1/volumes/frus1961-63v06/documents/d1/citation?style=chicago');
  const citation = (await api.json()) as { plainText: string };
  expect(copied).toBe(citation.plainText);
  expect(copied).toBe(d1Chicago);

  // Close hands focus back to the toggle; Back returns to the results, focused at their heading.
  await cite.getByRole('button', { name: 'Close' }).click();
  await expect(page.getByRole('button', { name: 'Cite' })).toBeFocused();
  await page.goBack();
  await expect(page).toHaveURL(/\/search\?keywords=treaties$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Search' })).toBeFocused();
});
