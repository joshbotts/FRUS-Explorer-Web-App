// S16d's done-when (docs/PLAN.md) for the export: with the kit's export of every type imported,
// Settings ▸ Data counts what an export carries as the app's Contents does, and Export as JSON saves
// the server's frus-research-export.json, the kit's envelope at version 7 with the web's one key more,
// holding what Contents counts; with the app's switch on, every summary too. By pointer and by
// keyboard, on Chromium with no axe violations. The notes, tags and highlights the import brings are
// removed after each test, as the import's spec removes them; what the API cannot remove stays for
// the run, and Contents counts it with the rest.
import { readFileSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import type { Download, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { removeNotesAndSummaries, send } from './notes';

const exported = readFileSync(new URL('../../fixtures/import/research-export.json', import.meta.url), 'utf8');

/** The file's arrays, as the kit's envelope names them, and the web's key. */
interface ExportFile {
  formatVersion: number;
  frusExplorerLight: { formatVersion: number; includesGeneratedSummaries: boolean; includesCorrections: boolean };
  [key: string]: unknown;
}

/** The envelope's keys, as the kit's `CodingKeys` spell them, but the two of a header's project. */
const envelopeKeys = [
  'formatVersion',
  'exportedAt',
  'notes',
  'tags',
  'tagAssignments',
  'highlights',
  'collections',
  'prompts',
  'projects',
  'summaries',
  'readingHistory',
  'searchHistory',
  'exportHistory',
  'archiveVisits',
  'savedSearches',
  'workingCorpora',
  'customVolumeScopes',
  'classificationOverrides',
  'personClusterOverrides',
  'annotationReviews',
  'projectLeads',
  'syncedPreferences',
];

test.afterEach(async ({ page }) => {
  await removeNotesAndSummaries(page);
  const highlights = (await (await page.request.get('api/v1/me/highlights')).json()) as { items: { id: string }[] };
  for (const highlight of highlights.items) await send(page, 'DELETE', `api/v1/me/highlights/${highlight.id}`);
});

/** The kit's export of every type, imported through the API as the browser app sends it, once its job is done. */
async function importEveryType(page: Page) {
  await page.goto('settings/data');
  const begun = (await send(page, 'POST', 'api/v1/me/import', JSON.parse(exported))) as { id: string };
  await expect
    .poll(async () => ((await (await page.request.get(`api/v1/me/import/${begun.id}`)).json()) as { state: string }).state, { timeout: 30_000 })
    .toBe('succeeded');
}

/** Contents' rows, each its name and count, as the page shows them. */
async function contentsRows(page: Page): Promise<string[][]> {
  const table = page.getByRole('table', { name: 'Contents' });
  await expect(table).toBeVisible();
  return table.locator('tr').evaluateAll((rows) => rows.map((row) => [...row.querySelectorAll('th, td')].map((cell) => cell.textContent ?? '')));
}

/** Contents' rows, the app's sheet's, each with the arrays of a file whose records it counts. */
const contents: [string, string[]][] = [
  ['Research Notes', ['notes']],
  ['Tags & Assignments', ['tags', 'tagAssignments']],
  ['Highlights', ['highlights']],
  ['Collections', ['collections']],
  ['Custom Prompts', ['prompts']],
  ['Projects', ['projects']],
  ['Archives Visits', ['archiveVisits']],
  ['Saved Searches', ['savedSearches']],
  ['Working Corpora', ['workingCorpora']],
  ['Volume Scopes', ['customVolumeScopes']],
  ['Classification Corrections', ['classificationOverrides']],
  ['Person Corrections', ['personClusterOverrides']],
  ['Reviewed Changes', ['annotationReviews']],
  ['Suggested Next Leads', ['projectLeads']],
  ['Synced Settings', ['syncedPreferences']],
  ['Documents Visited', ['readingHistory']],
  ['Searches Executed', ['searchHistory']],
  ['Collections Exported', ['exportHistory']],
];

/** What each of Contents' rows counts in a file, its arrays' lengths, as the app's sheet counts its store. */
function counted(file: ExportFile): string[][] {
  // As the app's sheet writes each count, an interpolated number, which groups no digits.
  return contents.map(([name, keys]) => [name, String(keys.reduce((sum, key) => sum + (file[key] as unknown[]).length, 0))]);
}

/** The saved file, read as JSON. */
async function saved(download: Download): Promise<ExportFile> {
  expect(download.suggestedFilename()).toBe('frus-research-export.json');
  return JSON.parse(await readFile(await download.path(), 'utf8')) as ExportFile;
}

/** The ids of the records under `key`. */
function ids(file: Record<string, unknown>, key: string): string[] {
  return (file[key] as { id: string }[]).map((record) => record.id);
}

test('counts what an export carries as the app’s Contents does, and saves the kit’s envelope with the web’s key, by pointer', async ({ page }) => {
  await importEveryType(page);
  await page.goto('settings/data');
  const rows = await contentsRows(page);
  expect(rows.map((row) => row[0])).toEqual(contents.map(([name]) => name));
  await axeCheck(page);

  const file = JSON.parse(exported) as Record<string, unknown>;
  const plain = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export as JSON' }).click();
  const first = await saved(await plain);
  expect(first.formatVersion).toBe(7);
  expect(Object.keys(first).sort()).toEqual([...envelopeKeys, 'frusExplorerLight'].sort());
  expect(first.frusExplorerLight).toEqual({ formatVersion: 1, includesGeneratedSummaries: false, includesCorrections: true });
  expect(first.summaries).toEqual([]);
  expect(counted(first)).toEqual(rows);
  for (const key of ['notes', 'tags', 'highlights', 'collections', 'projects', 'savedSearches', 'readingHistory']) {
    expect(ids(first, key), key).toEqual(expect.arrayContaining(ids(file, key)));
  }

  // The app's switch: every summary, which its footer counts.
  await page.getByRole('checkbox', { name: 'Include AI-Generated Summaries' }).check();
  const footer = await page.getByText(/^Adds all [\d,]+ generated summaries to the JSON export\./).textContent();
  const summaries = Number(/^Adds all ([\d,]+)/.exec(footer ?? '')![1]!.replaceAll(',', ''));
  expect(summaries).toBeGreaterThanOrEqual((file.summaries as unknown[]).length);
  await axeCheck(page);
  const all = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export as JSON' }).click();
  const second = await saved(await all);
  expect(second.frusExplorerLight.includesGeneratedSummaries).toBe(true);
  expect((second.summaries as unknown[]).length).toBe(summaries);
  expect(ids(second, 'summaries')).toEqual(expect.arrayContaining(ids(file, 'summaries')));
  expect(counted(second)).toEqual(rows);
  await expect(page).toHaveURL(/\/settings\/data$/);
});

test('turns the switch on and exports, by keyboard', async ({ page }) => {
  await importEveryType(page);
  await page.goto('settings/data');
  await contentsRows(page);
  const toggle = page.getByRole('checkbox', { name: 'Include AI-Generated Summaries' });
  await tabTo(page, toggle);
  await page.keyboard.press('Space');
  await expect(toggle).toBeChecked();
  await tabTo(page, page.getByRole('button', { name: 'Export as JSON' }));
  const saving = page.waitForEvent('download');
  await page.keyboard.press('Enter');
  const file = await saved(await saving);
  expect(file.frusExplorerLight.includesGeneratedSummaries).toBe(true);
  expect((file.summaries as unknown[]).length).toBeGreaterThan(0);
  await axeCheck(page);
});
