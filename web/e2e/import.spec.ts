// S16c's import of a Mac JSON export (docs/PLAN.md), through Settings ▸ Data: the kit's envelope with
// a record of every type, fixtures/import/research-export.json, chosen and imported, its report shown
// as the server gives it; imported again, every record kept; and once more with a note changed later,
// that note replaced. Then what S15d's tests could only seed in Swift: All Notes filtered by a real
// project, and a document's imported summaries in the Research rail with the app's authorship words
// and their prompt's name, one of a standard prompt the file does not name; and from S18d, the
// collections it brought, in the Collections tab and the editor as the Mac left them. By pointer and
// by keyboard, on Chromium with no axe violations. The file's notes, tags and highlights are removed
// after each test; what the API cannot remove, its projects, prompts and summaries on documents no
// other spec opens, stays for the run under the path, which finds them kept.
import { readFileSync } from 'node:fs';
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { drawn } from './highlights';
import { getJSON, removeNotesAndSummaries, run, type Run, send } from './notes';

const exported = readFileSync(new URL('../../fixtures/import/research-export.json', import.meta.url), 'utf8');
const fileName = 'research-export.json';

interface TypeCount {
  type: string;
  inFile: number;
  added: number;
  replaced: number;
  kept: number;
  setAside: number;
  repeated: number;
}

/** The kinds of record the test removes after each run, so each run's first import brings them anew. */
const removed = new Set(['ResearchNote', 'UserTag', 'DocumentTagAssignment', 'DocumentHighlight']);

test.afterEach(async ({ page }) => {
  await removeNotesAndSummaries(page);
  const highlights = (await (await page.request.get('api/v1/me/highlights')).json()) as { items: { id: string }[] };
  for (const highlight of highlights.items) await send(page, 'DELETE', `api/v1/me/highlights/${highlight.id}`);
});

/** Chooses `text` as the export file and imports it, by pointer; answers the import's report as the server gives it. */
async function importByPointer(page: Page, text: string): Promise<TypeCount[]> {
  const section = page.getByRole('region', { name: 'Import a JSON Export' });
  await section.getByLabel('Export file').setInputFiles({ name: fileName, mimeType: 'application/json', buffer: Buffer.from(text) });
  const posted = page.waitForResponse((response) => response.url().endsWith('/api/v1/me/import') && response.request().method() === 'POST');
  await section.getByRole('button', { name: 'Import' }).click();
  return finished(page, (await (await posted).json()) as { id: string });
}

/** The report, once the page says the import is done. */
async function finished(page: Page, begun: { id: string }): Promise<TypeCount[]> {
  const section = page.getByRole('region', { name: 'Import a JSON Export' });
  await expect(section.getByRole('status')).toHaveText(`Imported ${fileName}`);
  const status = (await (await page.request.get(`api/v1/me/import/${begun.id}`)).json()) as { report: { types: TypeCount[] } };
  return status.report.types;
}

/** The report's table, each row's name and counts, as the page shows it. */
async function tableRows(page: Page): Promise<string[][]> {
  const table = page.getByRole('table', { name: 'What the export held, and what became of it' });
  return table.locator('tbody tr').evaluateAll((rows) => rows.map((row) => [...row.querySelectorAll('th, td')].map((cell) => cell.textContent ?? '')));
}

const names: Record<string, string> = {
  ResearchNote: 'Research Notes',
  UserTag: 'Tags',
  DocumentTagAssignment: 'Tag Assignments',
  DocumentHighlight: 'Highlights',
  Collection: 'Collections',
  CollectionEntry: 'Collection Entries',
  SummarizationPrompt: 'Custom Prompts',
  Project: 'Projects',
  ArchiveVisitPlan: 'Archives Visits',
  ArchiveVisitDocument: 'Archives Visit Documents',
  ArchiveVisitTarget: 'Archives Visit Targets',
  SavedSearch: 'Saved Searches',
  WorkingCorpus: 'Working Corpora',
  CustomVolumeScope: 'Volume Scopes',
  DocumentClassificationOverride: 'Classification Corrections',
  PersonClusterOverride: 'Person Corrections',
  AnnotationReview: 'Reviewed Changes',
  ProjectLeadEntry: 'Suggested Next Leads',
  SyncedPreferences: 'Synced Settings',
  ReadingHistoryEntry: 'Documents Visited',
  SearchHistoryEntry: 'Searches Executed',
  ExportHistoryEntry: 'Collections Exported',
  GeneratedSummary: 'Generated Summaries',
};

/** The table holds the report's counts, each type under its name, in the export sheet's order. */
function expectTable(rows: string[][], types: TypeCount[]) {
  const byName = new Map(types.map((type) => [names[type.type], type]));
  expect(rows.map((row) => row[0])).toEqual(Object.values(names));
  for (const [name, inFile, added, replaced, kept] of rows) {
    const type = byName.get(name)!;
    expect([inFile, added, replaced, kept], name).toEqual([type.inFile, type.added, type.replaced, type.kept].map((count) => count.toLocaleString('en-US')));
  }
}

test('imports the kit’s export of every type, imports it again and keeps it, then takes a newer copy, by pointer', async ({ page }) => {
  await page.goto('settings/data');
  await expect(page.getByRole('heading', { level: 2, name: 'Import a JSON Export' })).toBeVisible();
  await axeCheck(page);

  // First: every record in the file, each new to the store or, in the run under the path, the
  // records the API cannot remove kept from the run before; none replaced.
  const first = await importByPointer(page, exported);
  for (const type of first) {
    expect(type.added + type.replaced + type.kept + type.setAside + type.repeated, type.type).toBe(type.inFile);
    expect(type.replaced, type.type).toBe(0);
    if (removed.has(type.type)) expect(type.added, type.type).toBe(type.inFile);
  }
  expect(first.find((type) => type.type === 'SyncedPreferences')).toMatchObject({ inFile: 2, setAside: 1 });
  expectTable(await tableRows(page), first);
  const section = page.getByRole('region', { name: 'Import a JSON Export' });
  await expect(section.getByText('A version-7 export, written on October 24, 2026.')).toBeVisible();
  await expect(section.getByText(/^The file held a second set of synced settings/)).toBeVisible();
  await expect(section.getByText('One note keeps formatting this server cannot show: it opens as plain text until you edit it here.')).toBeVisible();
  await expect(section.getByText("A deleted search's: The linked saved search could not be found. It may have been deleted.")).toBeVisible();
  await axeCheck(page);

  // Again: every record kept, as the store's copy is as new.
  const again = await importByPointer(page, exported);
  for (const type of again) expect(type.kept + type.setAside, type.type).toBe(type.inFile);

  // A note changed on the Mac after the first: that note replaced, the others kept.
  const newer = await importByPointer(page, exported.replace('"2026-03-04T12:34:56Z"', '"2026-09-01T00:00:00Z"'));
  expect(newer.find((type) => type.type === 'ResearchNote')).toMatchObject({ inFile: 3, replaced: 1, kept: 2 });
  expect((await tableRows(page))[0]).toEqual(['Research Notes', '3', '0', '1', '2']);

  // All Notes, filtered by the projects the file brought.
  await page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Research' }).click();
  const titles = page.getByRole('list', { name: 'All Notes' }).locator('.all-notes-title');
  await expect(titles).toHaveText(['In no project.', 'The OAS meeting.', 'Planners on Zapata.']);
  const project = page.getByRole('combobox', { name: 'Project', exact: true });
  await expect(project.locator('option')).toContainText(['All projects', 'Not in a project', 'Bay of Pigs review', 'Cuba and the OAS']);
  await project.selectOption({ label: 'Bay of Pigs review' });
  await expect(titles).toHaveText(['The OAS meeting.', 'Planners on Zapata.']);
  await expect(page.getByRole('status')).toHaveText('Showing 2 of 3 notes');
  await project.selectOption({ label: 'Cuba and the OAS' });
  await expect(titles).toHaveText(['The OAS meeting.']);
  await project.selectOption({ label: 'Not in a project' });
  await expect(titles).toHaveText(['In no project.']);
  await axeCheck(page);

  // d3's imported summaries, newest first: an AI summary of the researcher's own prompt, one edited
  // by hand of a standard prompt the file does not name, and one the researcher wrote on the Mac,
  // read-only here; the collection's headnote draft is no summary of the document's.
  await page.goto('doc/frus1961-63v06/d3?rail=research');
  // The imported highlight, in d3's version of its text, drawn by the kit's renderer, and not stale.
  await expect.poll(() => drawn(page)).toEqual({ 'frus-blue': 1 });
  const rail = page.getByRole('complementary', { name: 'Research' });
  const summary = rail.locator('#research-summary');
  const older = summary.getByRole('button', { name: 'Older summary' });
  const shown = async () =>
    [await summary.locator('.summary-text').textContent(), await summary.locator('.summary-label').textContent(),
     (await summary.locator('.summary-prompt').count()) ? await summary.locator('.summary-prompt').textContent() : null,
     await summary.locator('.summary-history').textContent()];
  await expect(summary.locator('.summary-text')).toHaveText('The planners expected an uprising.');
  expect(await shown()).toEqual(['The planners expected an uprising.', 'AI summary', '· Cold War brief', expect.stringContaining('1/3')]);
  await axeCheck(page);
  await older.click();
  await expect(summary.locator('.summary-text')).toHaveText('An earlier summary, edited by hand.');
  expect(await shown()).toEqual(['An earlier summary, edited by hand.', 'AI · edited', null, expect.stringContaining('2/3')]);
  await older.click();
  await expect(summary.locator('.summary-text')).toHaveText("The researcher's own summary, from the Mac.");
  expect((await shown()).slice(1, 3)).toEqual(['Yours', '· Cold War brief']);
  await expect(summary.getByRole('button', { name: 'Edit…' })).toHaveCount(0);
  await expect(summary.getByRole('button', { name: 'Delete…' })).toHaveCount(0);
  await axeCheck(page);
  // The note the highlight is linked to.
  await expect(rail.locator('#research-notes')).toContainText('Planners on Zapata.');

  // The collections it brought (S18d): a smart one says so, and the Briefing book keeps its
  // document, heading, note block, excerpt and bibliography, its note block's RTF read as the Mac
  // wrote it.
  await page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Collections', exact: true }).click();
  const collections = page.getByRole('list', { name: 'Collections', exact: true });
  await expect(collections.getByRole('listitem').filter({ hasText: 'Every covert action' })).toContainText('Smart collection');
  await collections.getByRole('link', { name: 'Briefing book', exact: true }).click();
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Briefing book');
  const contents = page.getByRole('list', { name: 'Contents' });
  await expect(contents.getByRole('group', { name: 'Document d3' })).toBeVisible();
  await expect(contents.getByRole('textbox', { name: 'Section heading' })).toHaveValue('Planning');
  await expect(contents.locator('.prose-text')).toHaveText('A bold note.');
  await expect(contents.getByRole('group', { name: 'Excerpt from d3: Kept verbatim' })).toBeVisible();
  await expect(contents.getByRole('group', { name: 'Generated block: Bibliography' })).toBeVisible();
  await axeCheck(page);
  const briefing = await getJSON<{ entries: { kind: string; runs?: Run[] | null }[] }>(
    page,
    'api/v1/me/collections/5E16C000-0000-4000-8000-000000000032',
  );
  expect(briefing.entries.find((entry) => entry.kind === 'prose')?.runs).toEqual([run('A '), run('bold', { bold: true }), run(' note.')]);
});

test('chooses the export and imports it by keyboard alone', async ({ page }) => {
  await page.goto('settings/data');
  const section = page.getByRole('region', { name: 'Import a JSON Export' });
  const input = section.getByLabel('Export file');
  await input.focus();
  const chooser = page.waitForEvent('filechooser');
  await page.keyboard.press('Space');
  await (await chooser).setFiles({ name: fileName, mimeType: 'application/json', buffer: Buffer.from(exported) });
  await page.keyboard.press('Tab');
  await expect(section.getByRole('button', { name: 'Import' })).toBeFocused();
  const posted = page.waitForResponse((response) => response.url().endsWith('/api/v1/me/import') && response.request().method() === 'POST');
  await page.keyboard.press('Enter');
  const types = await finished(page, (await (await posted).json()) as { id: string });
  expect(types.find((type) => type.type === 'ResearchNote')).toMatchObject({ inFile: 3, added: 3 });
  expectTable(await tableRows(page), types);
  await axeCheck(page);
});
