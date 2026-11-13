// The update review (PLAN's S21f), on the smoke test's Standalone server, by keyboard on Chromium with no axe
// violations. With FRUS_E2E_UPDATE_REVIEW=before, before the smoke test fetches frus1894Nicaragua corrected
// upstream: a highlight on d2, over a passage after the correction's place, made through the API at the offsets
// the page's own engine gives, as a selection's are. With FRUS_E2E_UPDATE_REVIEW=after, once the corrected volume
// is indexed again: Research's Changed by an update lists d2 in the kit's words, the reader's banner says what
// changed in the app's, and the review sheet finds the passage two characters on, moves the highlight there by
// keyboard, which the server's search confirms, and marks the document reviewed, the banner gone after it.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

const phase = process.env.FRUS_E2E_UPDATE_REVIEW;
const documentPath = 'doc/frus1894Nicaragua/d2';
const highlightsPath = 'api/v1/me/volumes/frus1894Nicaragua/documents/d2/highlights';
const passage = 'touching an invasion of the troops of Honduras at Cape Gracias';

interface Highlight {
  id: string;
  startOffset: number;
  endOffset: number;
  selectedText: string;
  isStale?: boolean;
}

/** Where the passage starts in the page's flat text, as the kit's offset engine built it. */
function offsetOf(page: import('@playwright/test').Page, text: string): Promise<number> {
  return page
    .frameLocator('iframe.reader-frame')
    .locator('.frus-document')
    .evaluate((_, wanted) => (window as unknown as { FRUSOffsets: { flatText: string } }).FRUSOffsets.flatText.indexOf(wanted), text);
}

async function highlights(page: import('@playwright/test').Page): Promise<{ renderingVersion: string; items: Highlight[] }> {
  const response = await page.request.get(highlightsPath);
  expect(response.ok()).toBe(true);
  return (await response.json()) as { renderingVersion: string; items: Highlight[] };
}

test('before the update: a highlight over a passage of d2', async ({ page }) => {
  test.skip(phase !== 'before', 'runs on the smoke test’s Standalone server, before the corrected volume is fetched');
  await page.goto(documentPath);
  const frame = page.frameLocator('iframe.reader-frame');
  await expect(frame.getByText(/touching an invasion of the troops/)).toBeVisible();
  const start = await offsetOf(page, passage);
  expect(start).toBeGreaterThan(0);
  const { renderingVersion, items } = await highlights(page);
  expect(items).toEqual([]);
  const status = await page.evaluate(
    async ({ path, startOffset, endOffset, version }) => {
      const me = (await (await fetch(new URL('api/v1/me', document.baseURI))).json()) as { csrfToken: string };
      const response = await fetch(new URL(path, document.baseURI), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': me.csrfToken },
        body: JSON.stringify({ startOffset, endOffset, colorTag: 'yellow', renderingVersion: version }),
      });
      return response.status;
    },
    { path: highlightsPath, startOffset: start, endOffset: start + passage.length, version: renderingVersion },
  );
  expect(status).toBe(201);
  const [made] = (await highlights(page)).items;
  expect(made.selectedText).toBe(passage);
});

test('after the update: Changed by an update, the banner, and the highlight moved and reviewed by keyboard', async ({ page }) => {
  test.skip(phase !== 'after', 'runs on the smoke test’s Standalone server, once the corrected volume is indexed again');
  test.setTimeout(60_000);
  const before = (await highlights(page)).items;
  expect(before).toHaveLength(1);
  expect(before[0].isStale).toBe(true);

  // Research: Changed by an update, by keyboard, listing d2 in the kit's words.
  await page.goto('research');
  // Its name, as the accessibility tree joins the row's parts: "Changed by an update , 1".
  const category = page.getByRole('link', { name: /^Changed by an update\b/ });
  await expect(category).toContainText('1');
  await tabTo(page, category, 60);
  await page.keyboard.press('Enter');
  const list = page.getByRole('region', { name: 'Changed by an update' });
  await expect(list.getByText('Text changed in an update — highlight positions may have moved')).toBeVisible();
  await axeCheck(page);
  const title = list.getByRole('link', { name: /Gresham/ });
  await tabTo(page, title, 20);
  await page.keyboard.press('Enter');

  // The reader's banner, in the app's words, and Review….
  const banner = page.getByRole('region', { name: 'A change to this document' });
  await expect(banner).toContainText('The text of this document changed in a volume update. Some highlights may be misaligned.');
  await expect(page.frameLocator('iframe.reader-frame').getByText(/touching an invasion of the troops/)).toBeVisible();
  await axeCheck(page);
  const review = banner.getByRole('button', { name: 'Review…' });
  await tabTo(page, review, 40);
  await page.keyboard.press('Enter');

  // The sheet: the highlight stale, its passage found once, two characters on, with what surrounds it.
  const sheet = page.getByRole('dialog', { name: /Gresham/ });
  await expect(sheet.getByRole('heading', { level: 3, name: 'What Changed' })).toBeVisible();
  await expect(sheet.getByText('Made against an earlier version of the text — its position may have moved.')).toBeVisible();
  await expect(sheet.getByText('Found once, at a new position in the corrected text.')).toBeVisible();
  await expect(sheet.locator('strong', { hasText: passage })).toBeVisible();
  await axeCheck(page);

  // Move Here, by keyboard: the highlight moves where the kit's search found it, and is no longer stale.
  const move = sheet.getByRole('button', { name: `Move Here: ${passage.slice(0, 60)}…` });
  await tabTo(page, move, 20);
  await page.keyboard.press('Enter');
  await expect(sheet.getByText('The highlight is moved to the corrected text.')).toBeVisible();
  await expect(sheet.getByText('Matches the current text.')).toBeVisible();
  const after = (await highlights(page)).items;
  expect(after).toHaveLength(1);
  expect(after[0].startOffset).toBe(before[0].startOffset + 2);
  expect(after[0].isStale).toBe(false);
  expect(await offsetOf(page, passage)).toBe(after[0].startOffset);
  await axeCheck(page);

  // Mark Reviewed, by keyboard: the user's review, and the banner has nothing more to say.
  const mark = sheet.getByRole('button', { name: 'Mark Reviewed' });
  await tabTo(page, mark, 20);
  await page.keyboard.press('Enter');
  await expect(sheet.getByText('The document is marked reviewed.')).toBeVisible();
  await expect(mark).toHaveCount(0);
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(sheet).toHaveCount(0);
  await expect(banner).toHaveCount(0);
  const research = await page.request.get('api/v1/me/research');
  expect(((await research.json()) as { updated: number }).updated).toBe(0);
});
