// S25d's done-when (docs/PLAN.md): Playwright resolves a paste and adds what resolved, then a tag's documents, by
// keyboard on Chromium with no axe violations. Add Documents' Citations: a link and a citation by page resolve and
// are chosen at once, and a citation of a volume the server's index does not hold finds only the volume, in the
// kit's words, with nothing to choose; Add puts the two at the end of the collection. Its Tags: a tag a note and an
// assignment carry is listed with its count, opens on its documents, the note's first, all chosen, with the focus
// on Tags, and Add puts them at the end. Against the image, which the test leaves as it found it.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, removeNotesAndSummaries, send } from './notes';

const tagName = 'Paste and gather';

interface Detail {
  id: string;
  entries: { kind: string; volumeId: string; documentId: string }[];
}

/** The collection's documents, in its order, as `volumeId/documentId`. */
async function documents(page: Page, id: string): Promise<string[]> {
  const detail = await getJSON<Detail>(page, `api/v1/me/collections/${id}`);
  return detail.entries.filter((entry) => entry.kind === 'document').map((entry) => `${entry.volumeId}/${entry.documentId}`);
}

let made: string | null = null;
test.afterEach(async ({ page }) => {
  // From the Collections list, not the editor, whose preview would ask for the collection deleted under it.
  await page.goto('collections');
  if (made) await send(page, 'DELETE', `api/v1/me/collections/${made}`);
  made = null;
  await removeNotesAndSummaries(page);
});

/** The editor's Add Documents… under Contents, over the footer that names the sheet's four tabs. */
const opener = (page: Page) => page.getByRole('button', { name: 'Add Documents…', exact: true });

/** Opens Add Documents by keyboard, from its button where the focus is or a Tab reaches it: its Search tab takes the focus. */
async function openAddDocuments(page: Page) {
  const open = opener(page);
  if (!(await open.evaluate((element) => element === element.ownerDocument.activeElement))) await tabTo(page, open);
  await page.keyboard.press('Enter');
  const sheet = page.getByRole('dialog', { name: 'Add Documents' });
  await expect(sheet.getByRole('button', { name: 'Search', exact: true })).toBeFocused();
  return sheet;
}

test("resolves a paste and adds what resolved, then a tag's documents, by keyboard alone", async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('collections');
  const detail = (await send(page, 'POST', 'api/v1/me/collections', { name: 'Add Documents by citation and tag' })) as Detail;
  made = detail.id;
  // The tag on a note on frus1969-76v01's d2, and assigned to frus1894Nicaragua's d1.
  const tag = (await send(page, 'POST', 'api/v1/me/tags', { name: tagName })) as { id: string };
  await send(page, 'POST', 'api/v1/me/volumes/frus1969-76v01/documents/d2/notes', {
    bodyText: 'Gathered by its tag.',
    runs: null,
    userTagIds: [tag.id],
    projectIds: [],
    selectedSummaryIds: [],
  });
  await send(page, 'PUT', 'api/v1/me/volumes/frus1894Nicaragua/documents/d1/tags', { tagIds: [tag.id] });
  await page.goto(`collections/${detail.id}`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Add Documents by citation and tag');
  await expect(
    page.getByText('Search the index, browse volumes, paste citations or history.state.gov links, or gather a tag. New documents are added to the end of the list.'),
  ).toBeVisible();

  // Citations: a link, a citation by page, and one of a volume the index does not hold.
  let sheet = await openAddDocuments(page);
  const citationsTab = sheet.getByRole('button', { name: 'Citations', exact: true });
  await tabTo(page, citationsTab);
  await page.keyboard.press('Enter');
  await expect(citationsTab).toHaveAttribute('aria-pressed', 'true');
  await expect(sheet.getByText('Each line is resolved against the FRUS manifest and this server’s index', { exact: false })).toBeVisible();
  await axeCheck(page);
  const paste = sheet.getByRole('textbox', { name: 'Paste citations or history.state.gov links, one per line…' });
  await tabTo(page, paste);
  await page.keyboard.type(
    ['https://history.state.gov/historicaldocuments/frus1961-63v06/d1', 'FRUS, 1961–1963, vol. VI, p. 2', 'FRUS, 1961–1963, vol. V, doc. 84'].join('\n'),
  );
  const resolve = sheet.getByRole('button', { name: 'Resolve', exact: true });
  await tabTo(page, resolve);
  await page.keyboard.press('Enter');
  await expect(sheet.getByRole('status')).toHaveText('2 of 3 resolved');
  await expect(resolve).toBeFocused();
  const lines = sheet.getByRole('list', { name: 'Citations' }).locator('xpath=./li');
  await expect(lines).toHaveCount(3);
  const telegram = sheet.getByRole('checkbox', { name: '1. Telegram From the Embassy in the Soviet Union', exact: true });
  const memorandum = sheet.getByRole('checkbox', { name: '2. Memorandum of Conversation', exact: true });
  await expect(telegram).toBeChecked();
  await expect(memorandum).toBeChecked();
  await expect(lines.nth(1)).toContainText('FRUS, 1961–1963, vol. VI, p. 2');
  await expect(lines.nth(2)).toHaveText(/FRUS, 1961–1963, vol. V, doc. 84\s*No match — Volume identified — download to find the specific document/);
  await expect(lines.nth(2).getByRole('checkbox')).toHaveCount(0);
  await axeCheck(page);
  await tabTo(page, sheet.getByRole('button', { name: 'Add 2 Document(s)' }));
  await page.keyboard.press('Enter');
  await expect(sheet).toHaveCount(0);
  await expect(opener(page)).toBeFocused();
  await expect.poll(() => documents(page, detail.id)).toEqual(['frus1961-63v06/d1', 'frus1961-63v06/d2']);

  // Tags: the tag's documents, the note's then the assignment's, chosen as the tag opens.
  sheet = await openAddDocuments(page);
  const tagsTab = sheet.getByRole('button', { name: 'Tags', exact: true });
  await tabTo(page, tagsTab);
  await page.keyboard.press('Enter');
  await expect(tagsTab).toHaveAttribute('aria-pressed', 'true');
  const opener = sheet.getByRole('list', { name: 'Tags' }).getByRole('button', { name: `${tagName} 2`, exact: true });
  await tabTo(page, opener);
  await axeCheck(page);
  await page.keyboard.press('Enter');
  const gathered = sheet.getByRole('list', { name: tagName });
  await expect(gathered.getByRole('checkbox')).toHaveCount(2);
  await expect(sheet.getByRole('button', { name: 'Tags', exact: true }).last()).toBeFocused();
  await expect(gathered.locator('.pick-title')).toHaveText(['2. Memorandum', 'No. 1. Mr. Baker to Mr. Gresham']);
  for (const box of await gathered.getByRole('checkbox').all()) await expect(box).toBeChecked();
  await axeCheck(page);
  await tabTo(page, sheet.getByRole('button', { name: 'Add 2 Document(s)' }));
  await page.keyboard.press('Enter');
  await expect(sheet).toHaveCount(0);
  await expect(opener(page)).toBeFocused();
  await expect
    .poll(() => documents(page, detail.id))
    .toEqual(['frus1961-63v06/d1', 'frus1961-63v06/d2', 'frus1969-76v01/d2', 'frus1894Nicaragua/d1']);
});
