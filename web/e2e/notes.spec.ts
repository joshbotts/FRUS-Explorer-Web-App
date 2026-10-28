// S15d's done-when (docs/PLAN.md), by pointer: Playwright writes a note from the selection bar's
// Note with bold, a colour and a link, saves it, finds it in the Research rail's Notes and edits it
// there, then filters for it and deletes it in All Notes; writes one with italic, underline and a
// link, removes the link, edits it plain with the Formatting switch off, which drops its formatting,
// and deletes it from the editor's own Delete; makes a highlight and a note for it from the rail's
// Add Note to Highlight, which the highlight takes as its note; opens Note from a footnote's bar,
// which offers it alone; puts a new note's text in focus when the editor's code comes late; and
// pastes styled HTML into the editor, with the formatting its styles give and its line breaks, with
// no policy violation; on Chromium with no axe violations. By keyboard, it is notes-keyboard.spec.ts.
// Against the image, whose user store starts with no notes, and which each test leaves with none.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { d1Text } from './expected';
import { expect, test } from './fixtures';
import { documentPath, dragOver, drawn, removeAll } from './highlights';
import { abbreviatedDate, notes, noteWithRuns, removeNotesAndSummaries, run, settle } from './notes';

const phrase = 'no insurmountable obstacles';

test.afterEach(async ({ page }) => {
  await removeNotesAndSummaries(page);
  await removeAll(page);
});

/** Selects `length` characters of the editor's line, from `start`, with the arrow keys. */
async function selectInLine(body: Locator, start: number, length: number) {
  const page = body.page();
  await body.focus();
  await settle(page);
  await page.keyboard.press('Home');
  for (let step = 0; step < start; step++) await page.keyboard.press('ArrowRight');
  for (let step = 0; step < length; step++) await page.keyboard.press('Shift+ArrowRight');
  await settle(page);
}

async function openDocument(page: Page) {
  await page.goto(documentPath);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
}

test('writes a formatted note from the bar’s Note, edits it in the rail, and finds and deletes it in All Notes, by pointer', async ({ page }) => {
  await openDocument(page);
  expect(await notes(page)).toEqual([]);

  // The bar's verbs: the four colours, then Note, as the app's bar orders them.
  await dragOver(page, phrase);
  const bar = page.getByRole('toolbar', { name: 'Selection' });
  await expect(bar.getByRole('button')).toHaveCount(5);
  await expect(bar.getByRole('button').nth(4)).toHaveAccessibleName('Note');
  await axeCheck(page);
  await bar.getByRole('button', { name: 'Note' }).click();

  // A note on the document, its text empty: the selection is not quoted, as the app's is not.
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  await expect(editor).toBeVisible();
  await expect(bar).toBeHidden();
  const body = editor.getByRole('textbox', { name: 'Research note body' });
  await expect(body).toBeFocused();
  await expect(body).toHaveText('');
  await expect(editor.getByRole('switch', { name: 'Formatting' })).toBeChecked();
  await expect(page.locator('style[data-tiptap-style]')).toHaveCount(0);
  await page.keyboard.type('Kennedy writes warmly.');
  const formatting = editor.getByRole('toolbar', { name: 'Text formatting' });

  await selectInLine(body, 8, 6);
  await formatting.getByRole('button', { name: 'Bold' }).click();
  await expect(formatting.getByRole('button', { name: 'Bold' })).toHaveAttribute('aria-pressed', 'true');
  await selectInLine(body, 15, 6);
  // A colour at 4.5:1 or more on the page, so the note's own text passes axe.
  await formatting.getByLabel('Text Color').fill('#0000ff');
  await selectInLine(body, 0, 7);
  await formatting.getByRole('button', { name: 'Link selected text to a URL' }).click();
  const link = page.getByRole('dialog', { name: 'Link selection to URL' });
  await expect(link.getByRole('textbox')).toBeFocused();
  await link.getByRole('textbox').fill('https://history.state.gov/');
  await axeCheck(page);
  await link.getByRole('button', { name: 'Apply' }).click();
  await expect(link).toHaveCount(0);
  await expect(body.locator('strong')).toHaveText('writes');
  await expect(body.locator('span[data-color="0000FF"]')).toHaveText('warmly');
  await expect(body.locator('a[href="https://history.state.gov/"]')).toHaveText('Kennedy');
  await axeCheck(page);
  await editor.getByRole('button', { name: 'Save' }).click();
  await expect(editor).toHaveCount(0);

  const [made] = await notes(page);
  expect(made.bodyText).toBe('Kennedy writes warmly.');
  expect(made.linkedHighlightIds).toEqual([]);
  expect(made.projectIds).toEqual([]);
  expect((await noteWithRuns(page, made.id)).runs).toEqual([
    run('Kennedy', { linkURL: 'https://history.state.gov/' }),
    run(' '),
    run('writes', { bold: true }),
    run(' '),
    run('warmly', { colorHex: '0000FF' }),
    run('.'),
  ]);

  // The rail's Notes, open from the first, list it; its row opens it with its formatting.
  await page.getByRole('button', { name: 'Research' }).click();
  const rail = page.getByRole('complementary', { name: 'Research' });
  await expect(rail.getByRole('button', { name: 'Notes, 1 note' })).toHaveAttribute('aria-expanded', 'true');
  const row = rail.locator('#research-notes').getByRole('button', { name: /^Kennedy writes warmly\./ });
  await expect(row).toBeVisible();
  await axeCheck(page);
  await row.click();
  const edit = page.getByRole('dialog', { name: 'Edit Note' });
  const editBody = edit.getByRole('textbox', { name: 'Research note body' });
  await expect(editBody.locator('strong')).toHaveText('writes');
  await expect(editBody.locator('span[data-color="0000FF"]')).toHaveText('warmly');
  await editBody.click();
  await settle(page);
  await page.keyboard.press('ControlOrMeta+End');
  await settle(page);
  await page.keyboard.press('Enter');
  await page.keyboard.type('Second line.');
  // A tag made in the editor is made at once, and ticked.
  await edit.getByRole('textbox', { name: 'New tag name' }).fill('Primary source');
  await edit.getByRole('button', { name: 'Add' }).click();
  await expect(edit.getByRole('checkbox', { name: 'Primary source' })).toBeChecked();
  await axeCheck(page);
  await edit.getByRole('button', { name: 'Save' }).click();
  await expect(edit).toHaveCount(0);
  const [edited] = await notes(page);
  expect(edited.bodyText).toBe('Kennedy writes warmly.\nSecond line.');
  expect(edited.userTagIds).toHaveLength(1);
  // The line break takes the formatting of the text before it, as the codec writes it.
  expect((await noteWithRuns(page, edited.id)).runs?.at(-1)).toEqual(run('.\nSecond line.'));
  await expect(rail.locator('#research-notes').getByRole('button', { name: /^Kennedy writes warmly\.\s+Second line\./ })).toBeVisible();

  // All Notes, from the header's Research.
  await page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Research' }).click();
  await expect(page).toHaveURL(/\/research\/notes$/);
  await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeVisible();
  const list = page.getByRole('list', { name: 'All Notes' });
  const item = list.getByRole('listitem');
  await expect(item).toHaveCount(1);
  await expect(item.locator('.all-notes-title')).toHaveText('Kennedy writes warmly.');
  await expect(item.locator('.all-notes-detail')).toHaveText('frus1961-63v06 / d1 · Primary source');
  await expect(item.locator('.all-notes-date')).toHaveText(abbreviatedDate(edited.lastModified!));
  await expect(page.getByRole('status')).toHaveText('1 note');
  await axeCheck(page);

  // The filters: the project picker's own two, then the user's projects by name, which only an
  // import brings (import.spec.ts leaves its own); the tag; the text.
  const project = page.getByRole('combobox', { name: 'Project', exact: true });
  const projects = ((await (await page.request.get('api/v1/me/projects')).json()) as { items: { name: string }[] }).items;
  await expect(project.locator('option')).toHaveText(['All projects', 'Not in a project', ...projects.map((each) => each.name)]);
  await project.selectOption({ label: 'Not in a project' });
  await expect(item).toHaveCount(1);
  const tag = page.getByRole('combobox', { name: 'Tag' });
  await expect(tag.locator('option')).toHaveText(['All tags', 'Primary source']);
  await tag.selectOption({ label: 'Primary source' });
  await expect(item).toHaveCount(1);
  const search = page.getByRole('searchbox', { name: 'Search notes…' });
  await search.fill('Khrushchev');
  await expect(page.getByText('No notes match the selected filters.')).toBeVisible();
  await expect(page.getByRole('status')).toHaveText('Showing 0 of 1 note');
  await axeCheck(page);
  await search.fill('  second LINE ');
  await expect(item).toHaveCount(1);
  await search.fill('');

  // Delete… asks the app's question, Cancel first.
  await item.getByRole('button', { name: 'Delete…' }).click();
  const question = page.getByRole('alertdialog', { name: 'Delete Note?' });
  await expect(question).toContainText('This note will be permanently deleted.');
  await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  await question.getByRole('button', { name: 'Delete', exact: true }).click();
  await expect(question).toHaveCount(0);
  await expect(page.getByText('No notes yet. Notes you write from a document appear here.')).toBeVisible();
  await axeCheck(page);
  expect(await notes(page)).toEqual([]);
});

test('writes italic, underline and a link, removes the link, edits plain with Formatting off, and deletes from the editor, by pointer', async ({ page }) => {
  await openDocument(page);
  await page.getByRole('button', { name: 'Research' }).click();
  const rail = page.getByRole('complementary', { name: 'Research' });
  await rail.getByRole('button', { name: 'Add Note', exact: true }).click();
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  const body = editor.getByRole('textbox', { name: 'Research note body' });
  await expect(body).toBeFocused();
  await settle(page);
  await page.keyboard.type('Italic, underlined and linked.');
  const formatting = editor.getByRole('toolbar', { name: 'Text formatting' });

  await selectInLine(body, 0, 6);
  await formatting.getByRole('button', { name: 'Italic' }).click();
  await expect(formatting.getByRole('button', { name: 'Italic' })).toHaveAttribute('aria-pressed', 'true');
  await selectInLine(body, 8, 10);
  await formatting.getByRole('button', { name: 'Underline' }).click();
  await expect(formatting.getByRole('button', { name: 'Underline' })).toHaveAttribute('aria-pressed', 'true');
  await selectInLine(body, 23, 6);
  await formatting.getByRole('button', { name: 'Link selected text to a URL' }).click();
  const link = page.getByRole('dialog', { name: 'Link selection to URL' });
  await link.getByRole('textbox').fill('https://history.state.gov/');
  await link.getByRole('button', { name: 'Apply' }).click();
  await expect(link).toHaveCount(0);
  await expect(body.locator('em')).toHaveText('Italic');
  await expect(body.locator('u')).toHaveText('underlined');
  await axeCheck(page);
  await editor.getByRole('button', { name: 'Save' }).click();
  await expect(editor).toHaveCount(0);
  const [made] = await notes(page);
  expect((await noteWithRuns(page, made.id)).runs).toEqual([
    run('Italic', { italic: true }),
    run(', '),
    run('underlined', { underline: true }),
    run(' and '),
    run('linked', { linkURL: 'https://history.state.gov/' }),
    run('.'),
  ]);

  // Remove Link, from the dialog over the link, which starts with its address.
  const row = rail.locator('#research-notes').getByRole('button', { name: /^Italic, underlined and linked\./ });
  await row.click();
  const edit = page.getByRole('dialog', { name: 'Edit Note' });
  const editBody = edit.getByRole('textbox', { name: 'Research note body' });
  await expect(editBody.locator('a[href="https://history.state.gov/"]')).toHaveText('linked');
  await selectInLine(editBody, 23, 6);
  await edit.getByRole('toolbar', { name: 'Text formatting' }).getByRole('button', { name: 'Link selected text to a URL' }).click();
  await expect(link.getByRole('textbox')).toHaveValue('https://history.state.gov/');
  await axeCheck(page);
  await link.getByRole('button', { name: 'Remove Link' }).click();
  await expect(link).toHaveCount(0);
  await expect(editBody.locator('a')).toHaveCount(0);
  await edit.getByRole('button', { name: 'Save' }).click();
  await expect(edit).toHaveCount(0);
  expect((await noteWithRuns(page, made.id)).runs).toEqual([
    run('Italic', { italic: true }),
    run(', '),
    run('underlined', { underline: true }),
    run(' and linked.'),
  ]);

  // With Formatting off, the note is plain text, and an edit to it drops the formatting, as the
  // app's plain editor does.
  await row.click();
  const switchControl = edit.getByRole('switch', { name: 'Formatting' });
  await expect(switchControl).toBeChecked();
  await switchControl.click();
  await expect(switchControl).not.toBeChecked();
  const plain = edit.locator('textarea');
  await expect(plain).toHaveAccessibleName('Research note body');
  await expect(plain).toHaveValue('Italic, underlined and linked.');
  await expect(edit.getByRole('toolbar', { name: 'Text formatting' })).toHaveCount(0);
  await plain.click();
  await page.keyboard.press('ControlOrMeta+End');
  await page.keyboard.type(' Plain now.');
  await axeCheck(page);
  await edit.getByRole('button', { name: 'Save' }).click();
  await expect(edit).toHaveCount(0);
  const plainNote = await noteWithRuns(page, made.id);
  expect([plainNote.bodyText, plainNote.runs, plainNote.formattingKept]).toEqual(['Italic, underlined and linked. Plain now.', null, false]);

  // The switch on again, the note opens formatted, with nothing to format; the editor's Delete
  // deletes it at once, as the app's editor does.
  await row.click();
  await expect(plain).toBeVisible();
  await switchControl.click();
  await expect(switchControl).toBeChecked();
  await expect(editBody).toHaveText('Italic, underlined and linked. Plain now.');
  await expect(editBody.locator('em, u, strong, a')).toHaveCount(0);
  await axeCheck(page);
  await edit.getByRole('button', { name: 'Delete', exact: true }).click();
  await expect(edit).toHaveCount(0);
  expect(await notes(page)).toEqual([]);
  await expect(rail.locator('#research-notes').getByRole('button', { name: /^Italic, underlined/ })).toHaveCount(0);
});

test('makes a note for a highlight from the rail’s Add Note to Highlight, which the highlight takes as its note', async ({ page }) => {
  await openDocument(page);
  await page.getByRole('button', { name: 'Research' }).click();
  const rail = page.getByRole('complementary', { name: 'Research' });
  await expect(rail.getByRole('button', { name: 'Add Note', exact: true })).toBeVisible();
  await expect(rail.getByRole('button', { name: 'Add Note to Highlight' })).toHaveCount(0);

  await dragOver(page, phrase);
  await page.getByRole('toolbar', { name: 'Selection' }).getByRole('button', { name: 'Highlight Yellow' }).click();
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1 });
  const toHighlight = rail.getByRole('button', { name: 'Add Note to Highlight' });
  await expect(toHighlight).toBeVisible();
  await expect(rail.locator('.note-actions').getByRole('button')).toHaveText(['Add Note to Highlight', /Add Note$/]);
  await axeCheck(page);
  await toHighlight.click();
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  // Chosen, it is no longer offered, as the app's is not, whether the note is saved or not.
  await expect(toHighlight).toHaveCount(0);
  await editor.getByRole('textbox', { name: 'Research note body' }).click();
  await page.keyboard.type('On this passage.');
  await editor.getByRole('button', { name: 'Save' }).click();
  await expect(editor).toHaveCount(0);

  const [made] = await notes(page);
  const highlights = (await (await page.request.get('api/v1/me/volumes/frus1961-63v06/documents/d1/highlights')).json()) as {
    items: { id: string; noteId?: string }[];
  };
  expect(highlights.items).toHaveLength(1);
  expect(highlights.items[0].noteId).toBe(made.id);
  expect(made.linkedHighlightIds).toEqual([highlights.items[0].id]);
  await expect(rail.locator('#research-notes').getByRole('button', { name: /^On this passage\./ })).toBeVisible();
});

test('a footnote’s selection offers Note alone, which opens a new note on the document', async ({ page }) => {
  await openDocument(page);
  const frame = page.frameLocator('iframe.reader-frame');
  await frame.locator('.footnotes-section').scrollIntoViewIfNeeded();
  await dragOver(page, 'American Foreign Policy', { within: '.footnotes-section' });
  const bar = page.getByRole('toolbar', { name: 'Selection' });
  await expect(bar).toBeVisible();
  await expect(bar.getByRole('button')).toHaveCount(1);
  await expect(bar.getByRole('button')).toHaveAccessibleName('Note');
  await axeCheck(page);
  await bar.getByRole('button', { name: 'Note' }).click();
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  await expect(editor).toBeVisible();
  await editor.getByRole('button', { name: 'Discard' }).click();
  await expect(editor).toHaveCount(0);
  expect(await notes(page)).toEqual([]);
});

test('puts a new note’s text in focus once the editor’s code has come, however late, after the dialog has focused its heading', async ({ page }) => {
  // Half a second, as a slow machine or network brings it: React then shows the editor in a render it
  // may pause after making the editor and before placing it in the dialog, and CI's 260 ms did the same.
  await page.route(/\/assets\/RichTextEditor-[^/]+\.js$/, async (route) => {
    await new Promise((done) => setTimeout(done, 500));
    await route.continue();
  });
  await openDocument(page);
  await dragOver(page, phrase);
  await page.getByRole('toolbar', { name: 'Selection' }).getByRole('button', { name: 'Note' }).click();
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  await expect(editor.getByText('Loading the editor…')).toBeVisible();
  await expect(editor.getByRole('heading', { name: 'New Research Note' })).toBeFocused();
  await expect(editor.getByRole('textbox', { name: 'Research note body' })).toBeFocused();
  await editor.getByRole('button', { name: 'Discard' }).click();
  await expect(editor).toHaveCount(0);
  expect(await notes(page)).toEqual([]);
});

test('pastes HTML from elsewhere with its bold, italic, underline, links and lines, and none of its styles, which the page’s policy refuses', async ({ page }) => {
  await openDocument(page);
  await page.getByRole('button', { name: 'Research' }).click();
  await page.getByRole('complementary', { name: 'Research' }).getByRole('button', { name: 'Add Note', exact: true }).click();
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  const body = editor.getByRole('textbox', { name: 'Research note body' });
  await expect(body).toBeFocused();
  // Google Docs' copy: its wrapper, a <b> that is not bold, and the formatting in its spans' styles;
  // a line broken by a <br>, as the reader's own lines are; and the <br> Chrome adds where a copy ends
  // at a paragraph's end, which makes no line.
  const html =
    '<style>b { color: red }</style><b style="font-weight:normal;" id="docs-internal-guid-1"><p><span style="color:#ff0000;font-size:20pt">Red</span> <strong style="color:blue">bold</strong> <a href="https://history.state.gov/" style="color:green">link</a><br>\n<span style="font-size:11pt;font-weight:700">Key</span> <span style="font-style:italic;text-decoration:underline">point</span></p></b><br class="Apple-interchange-newline">';
  await body.evaluate((element, pasted) => {
    const data = new DataTransfer();
    data.setData('text/html', pasted);
    data.setData('text/plain', 'Red bold link\nKey point');
    element.dispatchEvent(new ClipboardEvent('paste', { clipboardData: data, bubbles: true, cancelable: true }));
  }, html);
  await expect(body.locator('p')).toHaveText(['Red bold link', 'Key point']);
  await expect(body.locator('strong')).toHaveText(['bold', 'Key']);
  await expect(body.locator('em')).toHaveText('point');
  await expect(body.locator('u')).toHaveText('point');
  await expect(body.locator('a[href="https://history.state.gov/"]')).toHaveText('link');
  await expect(body.locator('[data-color], [data-pasted-style], [style]:not(span[data-color])')).toHaveCount(0);
  await axeCheck(page);
  // Escape in the text is the editor's Discard, as the app's sheet takes it.
  await body.press('Escape');
  await expect(editor).toHaveCount(0);
  await expect(page.getByRole('complementary', { name: 'Research' })).toBeVisible();
  expect(await notes(page)).toEqual([]);
});
