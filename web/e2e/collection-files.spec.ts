// S18f's done-when (docs/PLAN.md), S11c's: Playwright uses a collection's `.fruscollection` file both
// ways, a smart collection and its snapshot, Summary only's reason and the headnote card on Chromium with
// no axe violations. By keyboard: the export sheet's .fruscollection with the reader's notes, saved; by
// pointer, Import Collection… with that file, which opens the collection it makes. A collection linked to
// a saved search from Collection settings, its earlier entries listed apart and removed, previewed and
// exported as its search's results, then snapshotted from its row. Summary only listed but not offered,
// with the app's reason; and the
// inspector's headnote card and New Note…. Each test deletes what it made: collections, exports, notes
// and saved searches.
import { readFile } from 'node:fs/promises';
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, notes, send } from './notes';

interface Detail {
  id: string;
  name: string;
  entries: { id: string }[];
}

const volume = 'frus1961-63v06';
const listed = async (page: Page) => (await getJSON<{ items: { id: string }[] }>(page, 'api/v1/me/collections')).items;
const recorded = async (page: Page) => (await getJSON<{ exports: { id: string }[] }>(page, 'api/v1/me/history')).exports;
const searches = async (page: Page) => (await getJSON<{ items: { id: string }[] }>(page, 'api/v1/me/saved-searches')).items;

// What was there before each test, which it leaves.
let collectionsBefore = new Set<string>();
let exportsBefore = new Set<string>();
let notesBefore = new Set<string>();
let searchesBefore = new Set<string>();
test.beforeEach(async ({ page }) => {
  await page.goto('collections');
  collectionsBefore = new Set((await listed(page)).map((item) => item.id));
  exportsBefore = new Set((await recorded(page)).map((row) => row.id));
  notesBefore = new Set((await notes(page)).map((note) => note.id));
  searchesBefore = new Set((await searches(page)).map((search) => search.id));
});
test.afterEach(async ({ page }) => {
  if (page.url() === 'about:blank') await page.goto('collections');
  for (const item of await listed(page)) if (!collectionsBefore.has(item.id)) await send(page, 'DELETE', `api/v1/me/collections/${item.id}`);
  for (const row of await recorded(page)) if (!exportsBefore.has(row.id)) await send(page, 'DELETE', `api/v1/me/history/exports/${row.id}`);
  for (const note of await notes(page)) if (!notesBefore.has(note.id)) await send(page, 'DELETE', `api/v1/me/notes/${note.id}`);
  for (const search of await searches(page)) if (!searchesBefore.has(search.id)) await send(page, 'DELETE', `api/v1/me/saved-searches/${search.id}`);
});

/** A collection made through the API, holding `documents`, from a page of the app. */
async function made(page: Page, name: string, documentIds: string[]): Promise<Detail> {
  const detail = (await send(page, 'POST', 'api/v1/me/collections', { name })) as Detail;
  const documents = documentIds.map((documentId) => ({ volumeId: volume, documentId }));
  return ((await send(page, 'POST', `api/v1/me/collections/${detail.id}/documents`, { documents })) as { collection: Detail }).collection;
}

test('writes a collection’s file with its notes by keyboard, and imports it as a new collection', async ({ page }) => {
  const letters = await made(page, 'Shared letters', ['d1', 'd2']);
  await send(page, 'POST', `api/v1/me/volumes/${volume}/documents/d1/notes`, {
    bodyText: 'Read beside the second letter.',
    runs: null,
    userTagIds: [],
    projectIds: [],
    selectedSummaryIds: [],
  });
  await page.goto(`collections/${letters.id}`);
  const open = page.getByRole('button', { name: 'Export…' });
  await tabTo(page, open);
  await page.keyboard.press('Enter');
  const sheet = page.getByRole('dialog', { name: 'Export collection' });
  await expect(sheet.getByRole('radio', { name: 'HTML, Web page' })).toBeChecked();
  await tabTo(page, sheet.getByRole('radio', { name: 'HTML, Web page' }));
  for (let step = 0; step < 4; step += 1) await page.keyboard.press('ArrowRight');
  await expect(sheet.getByRole('radio', { name: '.fruscollection, Editable copy for a colleague' })).toBeChecked();
  const notesSwitch = sheet.getByRole('switch', { name: 'Include my research notes' });
  await expect(notesSwitch).not.toBeChecked();
  await expect(sheet.getByText(/Shares an editable copy of this collection/)).toBeVisible();
  await axeCheck(page);
  await tabTo(page, notesSwitch);
  await page.keyboard.press('Space');
  await expect(notesSwitch).toBeChecked();
  await tabTo(page, sheet.getByRole('button', { name: 'Export .fruscollection' }));
  const saving = page.waitForEvent('download');
  await page.keyboard.press('Enter');
  const download = await saving;
  expect(download.suggestedFilename()).toBe('Shared letters.fruscollection');
  const path = await download.path();
  const file = JSON.parse(await readFile(path, 'utf8')) as {
    format: string;
    formatVersion: number;
    name: string;
    entries: { kind: string; documentId?: string; notes?: string[] }[];
  };
  expect(file.format).toBe('fruscollection');
  expect(file.name).toBe('Shared letters');
  expect(file.entries.map((entry) => [entry.kind, entry.documentId, entry.notes])).toEqual([
    ['document', 'd1', ['Read beside the second letter.']],
    ['document', 'd2', undefined],
  ]);
  await expect(sheet.getByText('Export Complete: Shared letters.fruscollection')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(open).toBeFocused();

  // Import Collection…, with the file just written: a new collection, which its editor opens.
  await page.goto('collections');
  const choosing = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Import Collection…' }).click();
  await (await choosing).setFiles(path);
  await expect(page.getByRole('heading', { level: 1, name: 'Shared letters' })).toBeVisible();
  await expect(page).not.toHaveURL(new RegExp(`/collections/${letters.id}$`, 'i'));
  await expect(page.getByRole('group', { name: /^Document / })).toHaveCount(2);
  await expect(page.frameLocator('iframe.preview-frame').locator('section[id^="doc-"]')).toHaveCount(2);
  await axeCheck(page);
  expect((await notes(page)).filter((note) => note.bodyText === 'Read beside the second letter.')).toHaveLength(2);
});

test('links a collection to a saved search, previews and exports its results, and snapshots it', async ({ page }) => {
  const saved = (await send(page, 'POST', 'api/v1/me/saved-searches', { name: 'Treaties', search: 'keywords=treaties' })) as { id: string };
  expect(saved.id).toBeTruthy();
  const treaties = await made(page, 'Treaty letters', ['d3']);
  await page.goto(`collections/${treaties.id}`);
  await page.getByRole('button', { name: 'Collection settings' }).click();
  const settings = page.getByRole('dialog', { name: 'Collection settings' });
  const smart = settings.getByRole('region', { name: 'Smart Collection' });
  await smart.getByRole('button', { name: 'Link to Saved Search…' }).click();
  const picker = page.getByRole('dialog', { name: 'Link to Saved Search' });
  await axeCheck(page);
  await picker.getByRole('button', { name: /Treaties/ }).click();
  await expect(smart.getByText('Documents are resolved from this saved search at export time. Static entries are ignored.')).toBeVisible();
  await expect(smart.getByRole('button', { name: 'Unlink' })).toBeFocused();
  await axeCheck(page);
  await settings.getByRole('button', { name: 'Done' }).click();

  // The document added before the link is apart, dimmed, until Remove These Entries takes it.
  const earlier = page.getByRole('region', { name: 'Not part of the smart collection: added before it was linked to its saved search.' });
  await expect(earlier.getByRole('listitem')).toHaveCount(1);
  await axeCheck(page);
  await earlier.getByRole('button', { name: 'Remove These Entries' }).click();
  const question = page.getByRole('alertdialog', { name: 'Remove These Entries?' });
  await expect(question.getByText('Removes the entry added before this collection was linked to its saved search.')).toBeVisible();
  await question.getByRole('button', { name: 'Remove These Entries' }).click();
  await expect(earlier).toHaveCount(0);
  await expect(page.getByRole('heading', { name: 'Contents' })).toBeFocused();

  // The preview and the HTML export are its search's results.
  const frame = page.frameLocator('iframe.preview-frame');
  await expect(frame.locator('section[id^="doc-"]')).toHaveCount(2);
  await page.getByRole('button', { name: 'Export…' }).click();
  const sheet = page.getByRole('dialog', { name: 'Export collection' });
  await expect(sheet.getByRole('radio')).toHaveCount(4);
  const saving = page.waitForEvent('download');
  await sheet.getByRole('button', { name: 'Export HTML' }).click();
  const html = await readFile(await (await saving).path(), 'utf8');
  expect(html.split('<section id="doc-').length - 1).toBe(2);
  await page.keyboard.press('Escape');

  // Create Static Snapshot, from its row: a collection of its results' documents, which opens.
  await page.goto('collections');
  await expect(page.getByRole('listitem').filter({ hasText: 'Treaty letters' }).getByText('Smart collection')).toBeVisible();
  await page.getByRole('button', { name: 'Create Static Snapshot: Treaty letters' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Treaty letters (Snapshot)' })).toBeVisible();
  await expect(page.getByRole('group', { name: /^Document / })).toHaveCount(2);
  await axeCheck(page);
});

test('lists Summary only with the app’s reason, and writes a headnote and a note from the inspector', async ({ page }) => {
  const letters = await made(page, 'Headnoted letters', ['d1']);
  await page.goto(`collections/${letters.id}`);
  await page.getByRole('button', { name: 'Collection settings' }).click();
  const settings = page.getByRole('dialog', { name: 'Collection settings' });
  const depth = settings.getByRole('combobox', { name: 'Body depth' });
  await expect(depth.getByRole('option', { name: 'Summary only' })).toBeDisabled();
  await expect(settings.getByText(/none of this collection’s documents has a summary stored\. Summaries are generated on demand/)).toBeVisible();
  await settings.getByRole('button', { name: 'Done' }).click();

  const configure = page.getByRole('button', { name: /^Configure: / });
  await configure.click();
  const inspector = page.getByRole('dialog', { name: 'Headnoted letters' });
  await inspector.getByRole('combobox', { name: 'Show a summary above the document' }).selectOption('on');
  await expect(inspector.getByText('Key takeaway · headnote')).toBeVisible();
  await expect(inspector.getByText('No headnote yet. Edit to write a key takeaway, or generate a document summary to seed one.')).toBeVisible();
  await inspector.getByRole('button', { name: 'Edit' }).click();
  await inspector.getByRole('textbox', { name: 'Headnote text' }).fill('Khrushchev answers the President at once.');
  await inspector.getByRole('button', { name: 'Save' }).click();
  await expect(inspector.getByText('Yours')).toBeVisible();
  await expect(inspector.getByRole('button', { name: 'Edit' })).toBeFocused();
  await axeCheck(page);

  await inspector.getByRole('button', { name: 'New Note…' }).click();
  const sheet = page.getByRole('dialog', { name: 'New Research Note' });
  await sheet.getByRole('textbox', { name: 'Note text' }).fill('Read with the President’s reply.');
  await axeCheck(page);
  await sheet.getByRole('button', { name: 'Save Note' }).click();
  await expect(sheet).toBeHidden();
  await expect(inspector.getByRole('checkbox', { name: /Read with the President’s reply\./ })).toBeChecked();
  await inspector.getByRole('button', { name: 'Done' }).click();
  await expect(page.frameLocator('iframe.preview-frame').getByText('Khrushchev answers the President at once.')).toBeVisible();
});
