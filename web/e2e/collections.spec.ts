// S18d's done-when (docs/PLAN.md), S11c's: Playwright uses collections and their editor on Chromium
// with no axe violations. By keyboard: the Collections tab and New Collection; three section headings,
// three deep by Indent, the third offering no more; Add Documents' search, its documents in the order
// chosen; Sort by Date within each section; a note block with bold; an apparatus block, which goes
// where the kit puts it; and Delete…'s question. The presets, Briefing packet offered once a document
// of the collection has a summary. By pointer: Excerpt from the selection bar into a collection the
// picker makes; the Research rail's Collections section and its Add to Collection; Add Documents'
// Browse; Move Up; Sort by Date across the whole collection; the document inspector's overrides, each
// with what Default resolves to, and a section's defaults, which its documents resolve to; and
// Duplicate. Against the image, whose user store holds none of these collections, and which each test
// leaves as it found it, keeping the collections an import brought in the run before.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { d1Text, d2Header, v06Title } from './expected';
import { expect, test } from './fixtures';
import { documentPath, dragOver } from './highlights';
import { backTabTo, tabTo } from './keyboard';
import { getJSON, removeNotesAndSummaries, type Run, run, send, settle, summariesPath } from './notes';

const d1Header = '1. Telegram From the Embassy in the Soviet Union';
const phrase = 'no insurmountable obstacles';
const addLabel = 'Add documents, a section heading, a note block, highlighted passages, or an apparatus block';

interface Entry {
  id: string;
  kind: string;
  depth: number;
  documentId: string;
  text?: string;
  runs?: Run[] | null;
  generatedBlockType?: string;
  includeFootnotesOverride?: boolean;
}

interface Detail {
  id: string;
  name: string;
  entries: Entry[];
  presets: { id: string; active: boolean }[];
  defaultBodyDepth: string;
  defaultIncludeHeadnote: boolean;
}

const collection = (page: Page, id: string) => getJSON<Detail>(page, `api/v1/me/collections/${id}`);
const listed = async (page: Page) => (await getJSON<{ items: { id: string; name: string }[] }>(page, 'api/v1/me/collections')).items;

/** The collection's outline: each entry's kind, its document, text or block, and its depth. */
async function outline(page: Page, id: string) {
  return (await collection(page, id)).entries.map((entry) => [
    entry.kind,
    entry.kind === 'document' ? entry.documentId : entry.kind === 'generated' ? entry.generatedBlockType : entry.text,
    entry.depth,
  ]);
}

/** The names of the rows `rows` finds, in order. */
const names = (rows: Locator) => rows.evaluateAll((elements) => elements.map((element) => element.getAttribute('aria-label')));

// The collections there before each test, which it leaves; it deletes any it made.
let before = new Set<string>();
test.beforeEach(async ({ page }) => {
  before = new Set((await listed(page)).map((item) => item.id));
});
test.afterEach(async ({ page }) => {
  if (page.url() === 'about:blank') await page.goto('collections');
  for (const item of await listed(page)) if (!before.has(item.id)) await send(page, 'DELETE', `api/v1/me/collections/${item.id}`);
  await removeNotesAndSummaries(page);
});

/** A collection made through the API, holding d1 and d2, from a page of the app. */
async function made(page: Page, name: string): Promise<string> {
  const detail = (await send(page, 'POST', 'api/v1/me/collections', { name })) as Detail;
  await send(page, 'POST', `api/v1/me/collections/${detail.id}/documents`, {
    documents: [
      { volumeId: 'frus1961-63v06', documentId: 'd1' },
      { volumeId: 'frus1961-63v06', documentId: 'd2' },
    ],
  });
  return detail.id;
}

test('makes a collection three sections deep, with documents, a note block and an apparatus block, orders it and deletes it, by keyboard alone', async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('');
  const heading = page.getByRole('heading', { level: 1 });
  const tab = page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Collections', exact: true });
  await tabTo(page, tab);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/collections$/);
  await expect(heading).toHaveText('Collections');
  await axeCheck(page);

  // New Collection, the Mac's sheet: Create waits for a name, then opens the editor.
  await tabTo(page, page.getByRole('button', { name: 'New Collection', exact: true }).first());
  await page.keyboard.press('Enter');
  const sheet = page.getByRole('dialog', { name: 'New Collection' });
  await expect(sheet.getByRole('textbox', { name: 'Name' })).toBeFocused();
  const create = sheet.getByRole('button', { name: 'Create' });
  await expect(create).toHaveAttribute('aria-disabled', 'true');
  await axeCheck(page);
  await page.keyboard.type('Kennedy–Khrushchev letters');
  await expect(create).toHaveAttribute('aria-disabled', 'false');
  await page.keyboard.press('Enter');
  await expect(sheet).toHaveCount(0);
  await expect(page).toHaveURL(/\/collections\/[0-9A-F-]{36}$/i);
  await expect(heading).toHaveText('Kennedy–Khrushchev letters');
  await expect(heading).toBeFocused();
  await expect(page.getByText('No content yet. Add documents, headings, notes, and apparatus from the toolbar above.')).toBeVisible();
  const id = new URL(page.url()).pathname.split('/').pop()!;
  await axeCheck(page);

  const add = page.getByRole('button', { name: addLabel });
  const menu = page.getByRole('menu', { name: addLabel });
  const contents = page.getByRole('list', { name: 'Contents' });
  const rows = contents.locator('xpath=./li');
  const titles = contents.getByRole('textbox', { name: 'Section heading' });

  /** Opens Add, above focus or, with `below`, after it, and chooses the item `steps` down from the first. */
  async function addItem(steps: number, name: string, { below = false } = {}) {
    await (below ? tabTo(page, add) : backTabTo(page, add));
    await page.keyboard.press('Enter');
    await expect(menu.getByRole('menuitem', { name: 'Add Documents…' })).toBeFocused();
    for (let step = 0; step < steps; step++) await page.keyboard.press('ArrowDown');
    await expect(menu.getByRole('menuitem', { name, exact: true })).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(menu).toHaveCount(0);
  }

  /** Indents the heading titled `title` from its row's menu, the web's way to the app's context menu. */
  async function indent(title: string) {
    const actions = contents.getByRole('button', { name: `Actions: ${title}` });
    await tabTo(page, actions);
    await page.keyboard.press('Enter');
    const rowMenu = page.getByRole('menu', { name: `Actions: ${title}` });
    await expect(rowMenu.getByRole('menuitem', { name: 'Rename' })).toBeFocused();
    // A letter goes to the next item it starts.
    await page.keyboard.press('i');
    await expect(rowMenu.getByRole('menuitem', { name: 'Indent' })).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(rowMenu).toHaveCount(0);
    await expect(actions).toBeFocused();
  }

  // Three sections, each heading added at the end with its title focused, the second indented under
  // the first and the third under the second.
  await addItem(1, 'Add Section Heading', { below: true });
  await expect(titles.nth(0)).toBeFocused();
  await page.keyboard.type('Europe');
  await addItem(1, 'Add Section Heading');
  await expect(titles.nth(1)).toBeFocused();
  await page.keyboard.type('Soviet Union');
  await indent('Soviet Union');
  await addItem(1, 'Add Section Heading');
  await expect(titles.nth(2)).toBeFocused();
  await page.keyboard.type('Moscow embassy');
  await indent('Moscow embassy');
  await expect.poll(() => outline(page, id)).toEqual([
    ['heading', 'Europe', 1],
    ['heading', 'Soviet Union', 2],
    ['heading', 'Moscow embassy', 2],
  ]);
  await indent('Moscow embassy');
  await expect.poll(() => outline(page, id)).toEqual([
    ['heading', 'Europe', 1],
    ['heading', 'Soviet Union', 2],
    ['heading', 'Moscow embassy', 3],
  ]);
  // Three deep is the most: the third offers no Indent, only Outdent.
  await page.keyboard.press('Enter');
  const third = page.getByRole('menu', { name: 'Actions: Moscow embassy' });
  await expect(third.getByRole('menuitem', { name: 'Indent' })).toHaveAttribute('aria-disabled', 'true');
  await expect(third.getByRole('menuitem', { name: 'Outdent' })).not.toHaveAttribute('aria-disabled');
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(third).toHaveCount(0);
  await expect(contents.getByRole('button', { name: 'Actions: Moscow embassy' })).toBeFocused();
  await expect(rows).toHaveClass([/indent-0/, /indent-1/, /indent-2/]);

  // Add Documents: a search, and two of its results, the second first, which Add puts at the end in
  // the order chosen, inside the last section.
  await addItem(0, 'Add Documents…');
  const picker = page.getByRole('dialog', { name: 'Add Documents' });
  await expect(picker.getByRole('button', { name: 'Search', exact: true, pressed: true })).toBeFocused();
  const search = picker.getByRole('searchbox', { name: 'Search indexed documents' });
  await tabTo(page, search);
  await page.keyboard.type('treaties');
  await page.keyboard.press('Enter');
  const d1Box = picker.getByRole('checkbox', { name: d1Header });
  const d2Box = picker.getByRole('checkbox', { name: d2Header });
  await expect(d2Box).toBeVisible();
  await axeCheck(page);
  await tabTo(page, d2Box);
  await page.keyboard.press('Space');
  await backTabTo(page, d1Box);
  await page.keyboard.press('Space');
  await expect(d1Box).toBeChecked();
  await expect(d2Box).toBeChecked();
  await tabTo(page, picker.getByRole('button', { name: 'Add 2 Document(s)' }));
  await page.keyboard.press('Enter');
  await expect(picker).toHaveCount(0);
  await expect(page.getByRole('status').filter({ hasText: 'Added 2 documents' })).toBeAttached();
  const documents = contents.getByRole('group', { name: /^Document / });
  await expect.poll(() => names(documents)).toEqual([`Document ${d2Header}`, `Document ${d1Header}`]);
  await axeCheck(page);

  // Sort by Date, within each section: the documents in the order of their dates, under their heading.
  const sort = page.getByRole('button', { name: 'Sort by Date', exact: true });
  await tabTo(page, sort);
  await page.keyboard.press('Enter');
  const sortMenu = page.getByRole('menu', { name: 'Sort by Date' });
  await expect(sortMenu.getByRole('menuitem', { name: 'Across the Whole Collection' })).toBeFocused();
  await page.keyboard.press('ArrowDown');
  await expect(sortMenu.getByRole('menuitem', { name: 'Within Each Section' })).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('Enter');
  await expect(sort).toBeFocused();
  await expect.poll(() => names(documents)).toEqual([`Document ${d1Header}`, `Document ${d2Header}`]);

  // A note block, its editor open in place, with a word made bold by the app's ⌘B.
  await addItem(2, 'Add Note Block');
  const body = contents.getByRole('textbox', { name: 'Note block' });
  await expect(body).toBeFocused();
  await settle(page);
  await page.keyboard.type('Read these two together');
  await page.keyboard.press('Control+Shift+ArrowLeft');
  await settle(page);
  await page.keyboard.press('ControlOrMeta+b');
  await expect(contents.getByRole('toolbar', { name: 'Text formatting' }).getByRole('button', { name: 'Bold' })).toHaveAttribute('aria-pressed', 'true');
  await axeCheck(page);
  await tabTo(page, contents.getByRole('button', { name: 'Done', exact: true }));
  await page.keyboard.press('Enter');
  await expect(body).toHaveCount(0);
  await expect(contents.getByRole('button', { name: 'Edit: Note block' })).toBeFocused();
  await expect
    .poll(async () => (await collection(page, id)).entries.find((entry) => entry.kind === 'prose')?.runs)
    .toEqual([run('Read these two '), run('together', { bold: true })]);

  // An apparatus block: the chronology, which the kit puts at the front.
  await addItem(5, 'Chronology');
  await expect(contents.getByRole('button', { name: 'Actions: Chronology' })).toBeFocused();
  await expect(contents.getByRole('group', { name: 'Generated block: Chronology' })).toContainText(
    'Lists 2 documents. Generated from this collection’s documents at export and in the preview.',
  );
  await expect.poll(() => outline(page, id)).toEqual([
    ['generated', 'chronology', 0],
    ['heading', 'Europe', 1],
    ['heading', 'Soviet Union', 2],
    ['heading', 'Moscow embassy', 3],
    ['document', 'd1', 3],
    ['document', 'd2', 3],
    ['prose', 'Read these two together', 3],
  ]);
  await expect(rows).toHaveClass([/indent-0/, /indent-0/, /indent-1/, /indent-2/, /indent-3/, /indent-3/, /indent-3/]);
  await axeCheck(page);

  // Delete…, from the list, asks first.
  await backTabTo(page, tab, 80);
  await page.keyboard.press('Enter');
  await expect(heading).toHaveText('Collections');
  const remove = page.getByRole('button', { name: 'Delete… Kennedy–Khrushchev letters', exact: true });
  await tabTo(page, remove);
  await page.keyboard.press('Enter');
  const confirm = page.getByRole('alertdialog', { name: 'Delete Collection?' });
  await expect(confirm.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('Tab');
  await expect(confirm.getByRole('button', { name: 'Delete', exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(confirm).toHaveCount(0);
  await expect(remove).toHaveCount(0);
  // Focus goes to the next row's Delete…, else New Collection, never to the page's body.
  await expect.poll(() => page.evaluate(() => document.activeElement?.textContent)).toMatch(/^(Delete…|New Collection)$/);
  expect((await listed(page)).some((item) => item.id === id)).toBe(false);
});

test('offers the app’s presets, Briefing packet once a document of the collection has a summary, by pointer', async ({ page }) => {
  await page.goto('collections');
  const id = await made(page, 'Berlin briefing');
  await page.goto(`collections/${id}`);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Berlin briefing');
  const contents = page.getByRole('list', { name: 'Contents' });
  await expect(contents.getByRole('group', { name: /^Document / })).toHaveCount(2);

  async function openSettings() {
    await page.getByRole('button', { name: 'Collection settings', exact: true }).click();
    const settings = page.getByRole('dialog', { name: 'Collection settings' });
    await expect(settings.getByRole('button', { name: 'Done' })).toBeFocused();
    return { settings, presets: settings.getByRole('region', { name: 'Start from a template — optional' }).getByRole('button') };
  }

  // No document has a summary: no Briefing packet.
  let { settings, presets } = await openSettings();
  await expect(presets).toHaveText([/^Teaching reader/, /^Source dossier/, /^Scholarly edition/]);
  await axeCheck(page);
  // Teaching reader: its composition, and the chronology it brings.
  await presets.filter({ hasText: 'Teaching reader' }).click();
  await expect(presets.filter({ hasText: 'Teaching reader' })).toHaveAttribute('aria-pressed', 'true');
  await expect(settings.getByRole('combobox', { name: 'Body depth' })).toHaveValue('full');
  await settings.getByRole('button', { name: 'Done' }).click();
  await expect(settings).toHaveCount(0);
  await expect(contents.getByRole('group', { name: 'Generated block: Chronology' })).toBeVisible();
  expect((await collection(page, id)).presets.filter((preset) => preset.active).map((preset) => preset.id)).toEqual(['teachingReader']);

  // A summary of d1's, and the editor read again: Briefing packet is offered, and makes the documents
  // summaries with headnotes.
  await send(page, 'POST', summariesPath, { responseText: 'A cordial opening, and an offer of talks.' });
  await page.reload();
  await expect(contents.getByRole('group', { name: /^Document / })).toHaveCount(2);
  ({ settings, presets } = await openSettings());
  await expect(presets).toHaveText([/^Teaching reader/, /^Briefing packet/, /^Source dossier/, /^Scholarly edition/]);
  await presets.filter({ hasText: 'Briefing packet' }).click();
  await expect(presets.filter({ hasText: 'Briefing packet' })).toHaveAttribute('aria-pressed', 'true');
  await expect(presets.filter({ hasText: 'Teaching reader' })).toHaveAttribute('aria-pressed', 'false');
  await expect(settings.getByRole('combobox', { name: 'Body depth' })).toHaveValue('summaryOnly');
  await expect(settings.getByRole('switch', { name: 'Headnotes' })).toBeChecked();
  await expect(settings.getByRole('switch', { name: 'Word-cloud overview' })).toBeChecked();
  await axeCheck(page);
  await settings.getByRole('button', { name: 'Done' }).click();
  await expect(contents.getByRole('group', { name: `Document ${d1Header}` }).getByRole('listitem')).toHaveText(['Headnote']);
  const briefing = await collection(page, id);
  expect([briefing.defaultBodyDepth, briefing.defaultIncludeHeadnote]).toEqual(['summaryOnly', true]);
  expect(briefing.presets.filter((preset) => preset.active).map((preset) => preset.id)).toEqual(['briefingPacket']);
});

test('freezes an excerpt from the selection bar, adds the document from the rail, and configures it and its section, by pointer', async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto(documentPath);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();

  // Excerpt, after the colours, opens the picker for an excerpt.
  await dragOver(page, phrase);
  const bar = page.getByRole('toolbar', { name: 'Selection' });
  await bar.getByRole('button', { name: 'Excerpt', exact: true }).click();
  const picker = page.getByRole('dialog', { name: 'Add Excerpt to Collection' });
  await expect(picker.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await expect(bar).toBeHidden();
  await axeCheck(page);

  // New Collection, from the picker, which lists it first, then takes the excerpt into it.
  await picker.getByRole('button', { name: 'New Collection', exact: true }).click();
  const sheet = page.getByRole('dialog', { name: 'New Collection' });
  await sheet.getByRole('textbox', { name: 'Name' }).fill('Excerpts for teaching');
  await sheet.getByRole('button', { name: 'Create' }).click();
  await expect(sheet).toHaveCount(0);
  const choices = picker.getByRole('list', { name: 'Collections' }).getByRole('button');
  await expect(choices.first()).toContainText('Excerpts for teaching0 documents');
  await axeCheck(page);
  await choices.first().click();
  await expect(choices.first()).toContainText('Added');
  await expect(picker).toHaveCount(0);
  const [mine] = (await listed(page)).filter((item) => !before.has(item.id));
  expect((await collection(page, mine.id)).entries.map((entry) => [entry.kind, entry.documentId, entry.text])).toEqual([['excerpt', 'd1', phrase]]);

  // The rail's Collections: an excerpt makes the document no member; Add to Collection does.
  await page.getByRole('button', { name: 'Research', exact: true }).click();
  const rail = page.getByRole('complementary', { name: 'Research' });
  const section = rail.getByRole('button', { name: 'Collections', exact: true });
  await section.click();
  await expect(section).toHaveAttribute('aria-expanded', 'true');
  await expect(rail.getByText('Not in any collection yet.')).toBeVisible();
  await rail.getByRole('button', { name: 'Add to Collection' }).click();
  const adding = page.getByRole('dialog', { name: 'Add to Collection', exact: true });
  await adding.getByRole('list', { name: 'Collections' }).getByRole('button', { name: /^Excerpts for teaching/ }).click();
  await expect(adding).toHaveCount(0);
  const link = rail.getByRole('link', { name: 'Excerpts for teaching', exact: true });
  await expect(link).toBeVisible();
  await expect(rail.getByRole('button', { name: 'Collections, 1 collection' })).toHaveAttribute('aria-expanded', 'true');
  await axeCheck(page);

  // Its name opens the editor: the excerpt, then the document.
  await link.click();
  await expect(page).toHaveURL(new RegExp(`/collections/${mine.id}$`));
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Excerpts for teaching');
  const contents = page.getByRole('list', { name: 'Contents' });
  await expect(contents.getByRole('group', { name: `Excerpt from d1: ${phrase}` })).toBeVisible();
  const documents = contents.getByRole('group', { name: /^Document / });
  await expect.poll(() => names(documents)).toEqual([`Document ${d1Header}`]);
  await axeCheck(page);

  // Add Documents' Browse: the volume's documents, the one held saying so.
  await page.getByRole('button', { name: 'Add Documents…', exact: true }).click();
  const browse = page.getByRole('dialog', { name: 'Add Documents' });
  await browse.getByRole('button', { name: 'Browse', exact: true }).click();
  await browse.getByRole('searchbox', { name: 'Filter volumes by title or ID' }).fill('frus1961-63v06');
  await browse.getByRole('button', { name: v06Title }).click();
  await expect(browse.getByRole('heading', { name: v06Title })).toBeVisible();
  await expect(browse.getByRole('listitem').filter({ hasText: d1Header })).toContainText('In collection');
  await browse.getByRole('checkbox', { name: d2Header }).check();
  await axeCheck(page);
  await browse.getByRole('button', { name: 'Add 1 Document(s)' }).click();
  await expect(browse).toHaveCount(0);
  await expect.poll(() => names(documents)).toEqual([`Document ${d1Header}`, `Document ${d2Header}`]);

  // Move Up, from d2's menu, then Sort by Date across the whole collection, which puts it back.
  await contents.getByRole('button', { name: `Actions: ${d2Header}` }).click();
  await page.getByRole('menu', { name: `Actions: ${d2Header}` }).getByRole('menuitem', { name: 'Move Up' }).click();
  await expect.poll(() => names(documents)).toEqual([`Document ${d2Header}`, `Document ${d1Header}`]);
  await page.getByRole('button', { name: 'Sort by Date', exact: true }).click();
  await page.getByRole('menu', { name: 'Sort by Date' }).getByRole('menuitem', { name: 'Across the Whole Collection' }).click();
  await expect.poll(() => names(documents)).toEqual([`Document ${d1Header}`, `Document ${d2Header}`]);
  await expect(contents.getByRole('group').first()).toHaveAccessibleName(`Excerpt from d1: ${phrase}`);

  // d1's inspector: Default says what it resolves to, an override shows on the row, and the excerpt
  // the collection holds from it is listed.
  const configure = contents.getByRole('button', { name: `Configure: ${d1Header}` });
  await configure.click();
  let inspector = page.getByRole('dialog', { name: 'Excerpts for teaching' });
  await expect(inspector.getByRole('button', { name: 'Done' })).toBeFocused();
  await expect(inspector.getByText('No research notes')).toBeVisible();
  const depth = inspector.getByRole('combobox', { name: 'Body depth' });
  await expect(depth).toHaveValue('');
  await expect(depth).toHaveAccessibleDescription('Default → Full document');
  await expect(inspector.getByRole('region', { name: 'Excerpts in This Collection' })).toContainText(phrase);
  await axeCheck(page);
  await depth.selectOption({ label: 'Index / outline' });
  await expect(depth).toHaveAccessibleDescription('');
  await inspector.getByRole('button', { name: 'Done' }).click();
  await expect(inspector).toHaveCount(0);
  await expect(configure).toBeFocused();
  await expect(contents.getByRole('group', { name: `Document ${d1Header}` }).getByRole('listitem')).toHaveText(['Index']);

  // A section heading, moved up over d2, which it then holds; its defaults are d2's Default.
  await page.getByRole('button', { name: addLabel }).click();
  await page.getByRole('menu', { name: addLabel }).getByRole('menuitem', { name: 'Add Section Heading' }).click();
  await expect(contents.getByRole('textbox', { name: 'Section heading' })).toBeFocused();
  await page.keyboard.type('Memoranda');
  await contents.getByRole('button', { name: 'Actions: Memoranda' }).click();
  await page.getByRole('menu', { name: 'Actions: Memoranda' }).getByRole('menuitem', { name: 'Move Up' }).click();
  await expect.poll(() => outline(page, mine.id)).toEqual([
    ['excerpt', phrase, 0],
    ['document', 'd1', 0],
    ['heading', 'Memoranda', 1],
    ['document', 'd2', 1],
  ]);
  await contents.getByRole('button', { name: 'Section defaults', exact: true }).click();
  inspector = page.getByRole('dialog', { name: 'Excerpts for teaching' });
  await expect(inspector.getByRole('region', { name: 'Section', exact: true })).toContainText('Memoranda');
  const defaults = inspector.getByRole('region', { name: 'Section Defaults' });
  await defaults.getByRole('combobox', { name: 'Footnotes' }).selectOption({ label: 'Off' });
  await axeCheck(page);
  await expect
    .poll(async () => (await collection(page, mine.id)).entries.find((entry) => entry.kind === 'heading')?.includeFootnotesOverride)
    .toBe(false);
  await inspector.getByRole('button', { name: 'Done' }).click();
  await expect(inspector).toHaveCount(0);
  await contents.getByRole('button', { name: `Configure: ${d2Header}` }).click();
  inspector = page.getByRole('dialog', { name: 'Excerpts for teaching' });
  const footnotes = inspector.getByRole('region', { name: 'Export Overrides' }).getByRole('combobox', { name: 'Footnotes' });
  await expect(footnotes).toHaveValue('');
  await expect(footnotes).toHaveAccessibleDescription('Default → Off');
  await axeCheck(page);
  await inspector.getByRole('button', { name: 'Done' }).click();
});

test('duplicates a collection and deletes the copy from the list, by pointer', async ({ page }) => {
  await page.goto('collections');
  const id = await made(page, 'Moscow telegrams');
  await page.reload();
  const list = page.getByRole('list', { name: 'Collections', exact: true });
  const row = (name: string) => list.getByRole('listitem').filter({ has: page.getByRole('link', { name, exact: true }) });
  await expect(row('Moscow telegrams')).toContainText('2 documents');
  await axeCheck(page);

  // Duplicate: a copy, the most recently changed, so first, with the same entries under new ids.
  await list.getByRole('button', { name: 'Duplicate Moscow telegrams', exact: true }).click();
  await expect(list.getByRole('link').first()).toHaveText('Moscow telegrams copy');
  await expect(row('Moscow telegrams copy')).toContainText('2 documents');
  const copyId = (await listed(page)).find((item) => item.name === 'Moscow telegrams copy')!.id;
  const [original, copied] = [await collection(page, id), await collection(page, copyId)];
  expect(copied.entries.map((entry) => [entry.kind, entry.documentId])).toEqual(original.entries.map((entry) => [entry.kind, entry.documentId]));
  expect(copied.entries.filter((entry) => original.entries.some((held) => held.id === entry.id))).toEqual([]);

  // Delete…: the question names the collection, and focus goes on to the next row's Delete….
  await list.getByRole('button', { name: 'Delete… Moscow telegrams copy', exact: true }).click();
  const confirm = page.getByRole('alertdialog', { name: 'Delete Collection?' });
  await expect(confirm.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await expect(confirm).toContainText('Moscow telegrams copy — This collection and everything in it will be permanently deleted.');
  await axeCheck(page);
  await confirm.getByRole('button', { name: 'Delete', exact: true }).click();
  await expect(confirm).toHaveCount(0);
  await expect(row('Moscow telegrams copy')).toHaveCount(0);
  await expect(list.getByRole('button', { name: 'Delete… Moscow telegrams', exact: true })).toBeFocused();
  expect((await listed(page)).map((item) => item.id)).not.toContain(copyId);
});
