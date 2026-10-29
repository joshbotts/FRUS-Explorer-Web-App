// S18e's done-when (docs/PLAN.md), S11c's: Playwright uses a collection's live preview and its exports
// on Chromium with no axe violations. By pointer: the preview beside Contents, the HTML export's page in
// its frame, the first 20 documents until Render All, a change shown a second later, and a volume the
// server's folder lacks as its citation card. By keyboard: Export…, the sheet's quotation check, which
// warns without blocking, Word chosen by the arrow keys and saved; then HTML, BibTeX and RIS by pointer,
// each the file its exporter names; and each export in History's Collections Exported. Narrow, the
// iPhone's Outline | Preview. Each test deletes the collections it made and the exports it recorded.
import { readFile } from 'node:fs/promises';
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, send } from './notes';

interface Detail {
  id: string;
  name: string;
}

interface HistoryPage {
  exports: { id: string; title: string; format: string; formatName: string; documentCount: number }[];
}

const volume = 'frus1961-63v06';
const listed = async (page: Page) => (await getJSON<{ items: { id: string }[] }>(page, 'api/v1/me/collections')).items;
const recorded = async (page: Page) => (await getJSON<HistoryPage>(page, 'api/v1/me/history')).exports;

// The collections and the exports there before each test, which it leaves.
let collectionsBefore = new Set<string>();
let exportsBefore = new Set<string>();
test.beforeEach(async ({ page }) => {
  await page.goto('collections');
  collectionsBefore = new Set((await listed(page)).map((item) => item.id));
  exportsBefore = new Set((await recorded(page)).map((row) => row.id));
});
test.afterEach(async ({ page }) => {
  if (page.url() === 'about:blank') await page.goto('collections');
  for (const item of await listed(page)) if (!collectionsBefore.has(item.id)) await send(page, 'DELETE', `api/v1/me/collections/${item.id}`);
  for (const row of await recorded(page)) if (!exportsBefore.has(row.id)) await send(page, 'DELETE', `api/v1/me/history/exports/${row.id}`);
});

/** A collection made through the API, holding `documents`, from a page of the app. */
async function made(page: Page, name: string, documents: { volumeId: string; documentId: string }[]): Promise<string> {
  const detail = (await send(page, 'POST', 'api/v1/me/collections', { name })) as Detail;
  await send(page, 'POST', `api/v1/me/collections/${detail.id}/documents`, { documents });
  return detail.id;
}

const letters = (count: number) => Array.from({ length: count }, (_, at) => ({ volumeId: volume, documentId: `d${at + 1}` }));

test('previews a collection beside its contents, the first 20 documents until Render All', async ({ page }) => {
  const id = await made(page, 'Twenty-two letters', letters(22));
  await page.goto('collections');
  await page.getByRole('link', { name: 'Twenty-two letters' }).click();
  await expect(page).toHaveURL(new RegExp(`/collections/${id}$`, 'i'));
  const frame = page.frameLocator('iframe.preview-frame');
  await expect(frame.locator('header h1')).toHaveText('Twenty-two letters');
  await expect(frame.locator('section[id^="doc-"]')).toHaveCount(20);
  await expect(frame.locator('#doc-frus1961-63v06-d1')).toContainText('Allow me to congratulate you');
  await expect(page.getByText('Showing first 20 of 22 documents')).toBeVisible();
  await expect(page.getByText('Preview of the HTML export — PDF and Word pagination will differ')).toBeVisible();
  await axeCheck(page);

  await page.getByRole('button', { name: 'Render All' }).click();
  await expect(frame.locator('section[id^="doc-"]')).toHaveCount(22);
  await expect(page.getByText('Showing first 20 of 22 documents')).toBeHidden();
  // Its bar gone, focus is on the preview, which says what it shows.
  await expect(page.getByRole('region', { name: 'Preview' })).toBeFocused();
  await expect(page.getByText('Showing all 22 documents')).toBeAttached();

  // A change shows in the page once it settles: a new name.
  await page.getByRole('button', { name: 'Collection settings' }).click();
  const settings = page.getByRole('dialog', { name: 'Collection settings' });
  await settings.getByRole('textbox', { name: 'Collection name' }).fill('Twenty-two letters, renamed');
  await settings.getByRole('button', { name: 'Done' }).click();
  await expect(frame.locator('header h1')).toHaveText('Twenty-two letters, renamed');
  await expect(frame.locator('section[id^="doc-"]')).toHaveCount(22, { timeout: 1_000 });
  // Each page took the frame's own place in the history: Back leaves the editor.
  await page.goBack();
  await expect(page).toHaveURL(/\/collections$/);

  // A volume the server's folder lacks: its document as the citation card, and the bar names it.
  const away = await made(page, 'A volume away', [{ volumeId: 'frus1961-63v05', documentId: 'd1' }]);
  await page.goto(`collections/${away}`);
  await expect(page.getByText('1 volume not downloaded')).toBeVisible();
  await expect(page.frameLocator('iframe.preview-frame').locator('.citation-card-note')).toHaveText('Volume not downloaded — citation only');
  await axeCheck(page);
});

test('exports each format by keyboard and pointer, after the quotation check, and keeps each in the history', async ({ page }) => {
  const id = await made(page, 'Café letters', letters(2));
  // An excerpt frozen from d1's page, whose text the synthetic index stores in other words: not found.
  const page1 = await page.request.get(`api/v1/volumes/${volume}/documents/d1/html`);
  const version = page1.headers()['x-frus-rendering-version'];
  await send(page, 'POST', `api/v1/me/collections/${id}/excerpts`, {
    volumeId: volume,
    documentId: 'd1',
    startOffset: 0,
    endOffset: 60,
    renderingVersion: version,
  });
  await page.goto(`collections/${id}`);
  const open = page.getByRole('button', { name: 'Export…' });
  await tabTo(page, open);
  await page.keyboard.press('Enter');
  const sheet = page.getByRole('dialog', { name: 'Export collection' });
  await expect(sheet.getByText('Exports the full text of each document, with your notes and footnotes.')).toBeVisible();
  await expect(sheet.getByText('One quotation was not found in the document it cites.')).toBeVisible();
  await expect(sheet.getByRole('radio', { name: 'HTML, Web page' })).toBeChecked();
  await axeCheck(page);

  await tabTo(page, sheet.getByRole('radio', { name: 'HTML, Web page' }));
  await page.keyboard.press('ArrowRight');
  await expect(sheet.getByRole('radio', { name: 'Word, Editable .docx' })).toBeChecked();
  await tabTo(page, sheet.getByRole('button', { name: 'Export Word' }));
  const word = page.waitForEvent('download');
  await page.keyboard.press('Enter');
  const docx = await word;
  expect(docx.suggestedFilename()).toBe('Café letters.docx');
  expect([...(await readFile(await docx.path())).subarray(0, 4)]).toEqual([0x50, 0x4b, 0x03, 0x04]);
  await expect(sheet.getByText('Export Complete: Café letters.docx')).toBeVisible();
  await expect(sheet.getByRole('button', { name: 'Export Word' })).toBeFocused();

  for (const [radio, button, name, holds] of [
    ['HTML, Web page', 'Export HTML', 'Café letters.html', '<title>Café letters</title>'],
    ['BibTeX, Reference manager', 'Export BibTeX', 'Café letters.bib', '@incollection{frus1961-63v06_d1,'],
    ['RIS, Zotero / EndNote', 'Export RIS', 'Café letters-zotero.ris', 'TY  - CHAP'],
  ] as const) {
    await sheet.getByText(radio.split(',')[0]!, { exact: true }).click();
    await expect(sheet.getByRole('radio', { name: radio })).toBeChecked();
    const saving = page.waitForEvent('download');
    await sheet.getByRole('button', { name: button }).click();
    const file = await saving;
    expect(file.suggestedFilename()).toBe(name);
    expect(await readFile(await file.path(), 'utf8')).toContain(holds);
  }
  await page.keyboard.press('Escape');
  await expect(sheet).toBeHidden();
  await expect(open).toBeFocused();

  await page.goto('research/history');
  const exported = page.getByRole('region', { name: 'Collections Exported' });
  for (const format of ['Zotero RIS (desktop)', 'BibTeX', 'HTML', 'DOCX']) {
    await expect(exported.getByText(`${format} · 2 documents`, { exact: false }).first()).toBeVisible();
  }
  expect((await recorded(page)).filter((row) => !exportsBefore.has(row.id)).map((row) => row.format)).toEqual([
    'zoteroJSON',
    'bibtex',
    'html',
    'docx',
  ]);
});

test('shows Outline or Preview, one at a time, in a narrow window', async ({ page }) => {
  const id = await made(page, 'Narrow letters', letters(2));
  await page.setViewportSize({ width: 600, height: 900 });
  await page.goto(`collections/${id}`);
  const view = page.getByRole('group', { name: 'View' });
  await expect(view.getByRole('radio', { name: 'Outline' })).toBeChecked();
  await expect(page.getByRole('heading', { name: 'Contents' })).toBeVisible();
  await expect(page.locator('iframe.preview-frame')).toHaveCount(0);
  // The radio lies over its whole label, as Citation Lookup's, so a pointer presses it.
  await view.getByRole('radio', { name: 'Preview' }).click();
  await expect(page.frameLocator('iframe.preview-frame').locator('header h1')).toHaveText('Narrow letters');
  await expect(page.getByRole('heading', { name: 'Contents' })).toHaveCount(0);
  await axeCheck(page);
  await view.getByRole('radio', { name: 'Outline' }).click();
  await expect(page.getByRole('heading', { name: 'Contents' })).toBeVisible();
});
