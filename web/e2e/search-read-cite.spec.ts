// S9's done-when (docs/PLAN.md): Playwright on Chromium searches, opens a document and copies a
// citation; and S11c's Cite, which copies the BibTeX and RIS records and saves the BibTeX. Against
// the image, with the synthetic export imported and fixtures/tei mounted.
import { readFile } from 'node:fs/promises';
import { axeCheck } from './axe';
import { d1BibTeX, d1Chicago, d1RIS, d1Text, treatiesResults } from './expected';
import { expect, test } from './fixtures';

test('the app is served with its policy, and every client route answers with it', async ({ request }) => {
  const app = await request.get('./');
  expect(app.status()).toBe(200);
  expect(app.headers()['content-security-policy']).toMatch(/^default-src 'self'/);
  const html = await app.text();
  for (const route of ['search?keywords=treaties', 'doc/frus1961-63v06/d1']) {
    expect(await (await request.get(route)).text()).toBe(html);
  }
  const unknown = await request.get('api/v1/no-such-endpoint');
  expect(unknown.status()).toBe(404);
  expect(unknown.headers()['content-type']).toBe('application/problem+json');
});

test('searches, opens a document and copies a citation', async ({ page }) => {
  await page.goto('search');
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
  // Each row names its document beside its volume, as the Mac's search window labels a row: the
  // synthetic export's rows have no number, so the label is the one each id spells.
  for (const [index, label] of ['Doc 1', 'Doc 2'].entries()) {
    await expect(results.getByRole('listitem').filter({ hasText: treatiesResults[index] }).locator('.meta')).toContainText(label);
  }

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

  const api = await page.request.get('api/v1/volumes/frus1961-63v06/documents/d1/citation?style=chicago');
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

test('Cite copies the BibTeX and RIS records, and saves the BibTeX as the Mac names the file', async ({ page }) => {
  await page.goto('doc/frus1961-63v06/d1?rail=cite');
  const cite = page.getByRole('complementary', { name: 'Cite' });
  await expect(cite.locator('.citation')).toBeVisible();
  const api = await page.request.get('api/v1/volumes/frus1961-63v06/documents/d1/citation');
  const records = (await api.json()) as { bibtex: string; ris: string; publicationYear: string; publicationYearSource: string };
  // The TEI is mounted, so the year is the one its header states.
  expect(records.publicationYear).toBe('1996');
  expect(records.publicationYearSource).toBe('tei');

  for (const [button, record, expected] of [
    ['Copy BibTeX', records.bibtex, d1BibTeX],
    ['Copy RIS', records.ris, d1RIS],
  ] as const) {
    await page.evaluate(() => navigator.clipboard.writeText('sentinel'));
    await cite.getByRole('button', { name: button }).click();
    // Each copy's own text, however soon after the last: the status says "Copied" either way.
    await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toBe(record);
    await expect(cite.getByRole('status')).toHaveText('Copied');
    expect(record).toBe(expected);
  }

  const saving = page.waitForEvent('download');
  await cite.getByRole('link', { name: 'Save as .bib' }).click();
  const download = await saving;
  expect(download.suggestedFilename()).toBe('frus1961-63v06-d1.bib');
  expect(await readFile(await download.path(), 'utf8')).toBe(d1BibTeX);
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d1\?rail=cite$/);
  await axeCheck(page);
});
