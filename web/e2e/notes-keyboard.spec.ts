// S15d's done-when (docs/PLAN.md), by keyboard: Playwright selects text in the reader's frame with
// caret browsing, as highlights-keyboard.spec.ts does, reaches the selection bar's Note by Alt+F10
// and End, writes a note, bolds a word with ⌘B, or Ctrl+B here, reaches the formatting bar by
// Shift+Tab and its Link by the arrow keys, links the word from the link dialog, has ⌘K refuse an
// address the page cannot follow, saves, discards an edit with Escape from the rail, and deletes the
// note in All Notes; on Chromium with no axe violations. Against the image, whose user store starts
// with no notes, and which the test leaves with none.
import { axeCheck } from './axe';
import { d1Text } from './expected';
import { expect, test } from './fixtures';
import { documentPath, removeAll } from './highlights';
import { backTabTo, tabTo } from './keyboard';
import { notes, noteWithRuns, removeNotesAndSummaries, run, settle } from './notes';

// Caret browsing, in a worker of its own, as the highlights' keyboard spec has it.
test.use({
  launchOptions: {
    args: ['--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4,caretBrowsingEnabled=true'],
  },
});

test.afterEach(async ({ page }) => {
  await removeNotesAndSummaries(page);
  await removeAll(page);
});

test('writes, formats, links and saves a note from the bar’s Note, discards an edit, and deletes it in All Notes, by keyboard alone', async ({ page }) => {
  await page.goto(documentPath);
  const frame = page.frameLocator('iframe.reader-frame');
  await expect(frame.getByText(d1Text)).toBeVisible();
  const selection = () => frame.locator('body').evaluate(() => getSelection()?.toString() ?? '');

  // A selection in the text by caret, then Alt+F10 to the bar and End to its last verb, Note.
  await tabTo(page, frame.locator('p.body').getByRole('link', { name: 'Kennedy' }));
  await page.keyboard.press('ArrowRight');
  for (let word = 0; word < 3; word++) await page.keyboard.press('Control+Shift+ArrowRight');
  await expect.poll(selection).not.toBe('');
  await page.keyboard.press('Alt+F10');
  const bar = page.getByRole('toolbar', { name: 'Selection' });
  await expect(bar.getByRole('button', { name: 'Highlight Yellow' })).toBeFocused();
  await page.keyboard.press('End');
  await expect(bar.getByRole('button', { name: 'Note' })).toBeFocused();
  await page.keyboard.press('Enter');

  // The editor: its heading first, then the text, for a new note.
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  const body = editor.getByRole('textbox', { name: 'Research note body' });
  await expect(body).toBeFocused();
  await expect.poll(selection).toBe('');
  await page.keyboard.type('Keyboard note');
  // The last word, bold by the app's ⌘B.
  await page.keyboard.press('Control+Shift+ArrowLeft');
  await settle(page);
  await page.keyboard.press('ControlOrMeta+b');
  const formatting = editor.getByRole('toolbar', { name: 'Text formatting' });
  await expect(formatting.getByRole('button', { name: 'Bold' })).toHaveAttribute('aria-pressed', 'true');
  await axeCheck(page);

  // The formatting bar, one stop before the text: its Link, by End, over the selection still held.
  await page.keyboard.press('Shift+Tab');
  await expect(formatting.getByRole('button', { name: 'Bold' })).toBeFocused();
  await page.keyboard.press('ArrowRight');
  await expect(formatting.getByRole('button', { name: 'Italic' })).toBeFocused();
  await page.keyboard.press('End');
  const linkButton = formatting.getByRole('button', { name: 'Link selected text to a URL' });
  await expect(linkButton).toBeFocused();
  await page.keyboard.press('Enter');
  const link = page.getByRole('dialog', { name: 'Link selection to URL' });
  await expect(link.getByRole('textbox')).toBeFocused();
  await page.keyboard.type('mailto:researcher@example.com');
  await axeCheck(page);
  await page.keyboard.press('Enter');
  await expect(link).toHaveCount(0);
  // Back in the text, with its selection, which now has the link.
  await expect(body).toBeFocused();
  await expect(linkButton).toHaveAttribute('aria-pressed', 'true');

  // ⌘K over the first word opens the dialog; an address the page cannot follow is refused there,
  // and Escape cancels it.
  await settle(page);
  await page.keyboard.press('Home');
  await page.keyboard.press('Control+Shift+ArrowRight');
  await settle(page);
  await page.keyboard.press('ControlOrMeta+k');
  await expect(link.getByRole('textbox')).toBeFocused();
  await page.keyboard.type('history.state.gov');
  await page.keyboard.press('Enter');
  await expect(link.getByRole('alert')).toHaveText('A link here starts with http://, https:// or mailto:.');
  await expect(link).toBeVisible();
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(link).toHaveCount(0);
  await expect(body).toBeFocused();
  await expect(editor).toBeVisible();

  // Save, by Tab: focus goes back to the text it was opened from.
  await tabTo(page, editor.getByRole('button', { name: 'Save' }));
  await page.keyboard.press('Enter');
  await expect(editor).toHaveCount(0);
  await expect(page.locator('iframe.reader-frame')).toBeFocused();
  const [made] = await notes(page);
  expect(made.bodyText).toBe('Keyboard note');
  expect((await noteWithRuns(page, made.id)).runs).toEqual([run('Keyboard '), run('note', { bold: true, linkURL: 'mailto:researcher@example.com' })]);

  // The rail, from the toolbar: the note's row opens it, and Escape in its text discards the edit
  // and leaves the rail open.
  const toggle = page.getByRole('button', { name: 'Research' });
  await backTabTo(page, toggle);
  await page.keyboard.press('Enter');
  const rail = page.getByRole('complementary', { name: 'Research' });
  await expect(rail.getByRole('heading', { name: 'Research' })).toBeFocused();
  const row = rail.locator('#research-notes').getByRole('button', { name: /^Keyboard note/ });
  await expect(row).toBeVisible();
  await axeCheck(page);
  await tabTo(page, row);
  await page.keyboard.press('Enter');
  const edit = page.getByRole('dialog', { name: 'Edit Note' });
  await expect(edit.getByRole('heading', { name: 'Edit Note' })).toBeFocused();
  const editBody = edit.getByRole('textbox', { name: 'Research note body' });
  await tabTo(page, editBody);
  await settle(page);
  await page.keyboard.press('ControlOrMeta+End');
  await settle(page);
  await page.keyboard.type(' discarded');
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(edit).toHaveCount(0);
  await expect(rail).toBeVisible();
  await expect(row).toBeFocused();
  expect((await notes(page))[0].bodyText).toBe('Keyboard note');

  // All Notes, from the header: Delete… asks, Cancel first, and Delete deletes.
  await page.keyboard.press('Escape');
  await expect(rail).toHaveCount(0);
  await backTabTo(page, page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Research' }));
  await page.keyboard.press('Enter');
  await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeVisible();
  const remove = page.getByRole('list', { name: 'All Notes' }).getByRole('button', { name: 'Delete…' });
  await expect(remove).toBeVisible();
  await axeCheck(page);
  await tabTo(page, remove);
  await page.keyboard.press('Enter');
  const question = page.getByRole('alertdialog', { name: 'Delete Note?' });
  await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('Tab');
  await expect(question.getByRole('button', { name: 'Delete', exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(question).toHaveCount(0);
  await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeFocused();
  await expect(page.getByText('No notes yet. Notes you write from a document appear here.')).toBeVisible();
  expect(await notes(page)).toEqual([]);
});
