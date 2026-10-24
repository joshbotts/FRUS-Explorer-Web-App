// S15d's done-when (docs/PLAN.md) for the Markdown export: Settings ▸ Data says there is nothing to
// export with no notes, and with one offers the app's Export Notes as Markdown (1), which saves
// the server's FRUSResearchNotes.zip: one stored entry, named as the kit's exporter names the file,
// holding its front matter and the note's text; on Chromium with no axe violations. Against the
// image, whose user store starts with no notes, and which the test leaves with none.
import { readFile } from 'node:fs/promises';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { removeNotesAndSummaries, send } from './notes';

test.afterEach(async ({ page }) => {
  await removeNotesAndSummaries(page);
});

test('exports every note as the app’s Markdown files, in one ZIP, from Settings ▸ Data', async ({ page }) => {
  await page.goto('settings/data');
  await expect(page.getByRole('heading', { level: 1, name: 'Data' })).toBeVisible();
  await expect(page.getByRole('navigation', { name: 'Settings' }).getByRole('link', { name: 'Data' })).toHaveAttribute('aria-current', 'page');
  await expect(page.getByText('No research notes to export.')).toBeVisible();
  await expect(page.getByText(/^One Markdown file per research note/)).toBeVisible();
  await axeCheck(page);

  const made = (await send(page, 'POST', 'api/v1/me/volumes/frus1961-63v06/documents/d1/notes', {
    bodyText: 'A note to export.',
    runs: null,
    userTagIds: [],
    projectIds: [],
    selectedSummaryIds: [],
  })) as { id: string };
  await page.reload();
  const action = page.getByRole('link', { name: 'Export Notes as Markdown (1)' });
  await expect(action).toBeVisible();
  await axeCheck(page);

  const saving = page.waitForEvent('download');
  await action.click();
  const download = await saving;
  expect(download.suggestedFilename()).toBe('FRUSResearchNotes.zip');
  const zip = await readFile(await download.path());
  // A ZIP's local file header, its entry stored (method 0), and the kit's file name for the note.
  expect(zip.readUInt32LE(0)).toBe(0x04034b50);
  expect(zip.readUInt16LE(8)).toBe(0);
  const name = `frus1961-63v06-d1-${made.id.slice(0, 8).toUpperCase()}.md`;
  const nameLength = zip.readUInt16LE(26);
  expect(zip.subarray(30, 30 + nameLength).toString('utf8')).toBe(name);
  const text = zip.toString('utf8');
  expect(text).toContain('---\ndocumentId: d1\nvolumeId: frus1961-63v06\nurl: https://history.state.gov/historicaldocuments/frus1961-63v06/d1\n');
  expect(text).toContain('---\n\nA note to export.\n');
  await expect(page).toHaveURL(/\/settings\/data$/);
});
