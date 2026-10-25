// S15d's done-when (docs/PLAN.md) for summaries: Playwright writes two summaries of its own in the
// Research rail's Summary section, the web's own, moves between them with the Mac's history control,
// edits one, previews the one shown in the closed section's header, inserts one into a note from the
// note editor's Generated Summaries and, with the note opened again, takes it out with Remove from
// note, which leaves its text, and deletes both, each after its question; on Chromium with no axe
// violations. An imported or AI summary, its labels and its prompt's name, are the server's and
// Vitest's to test until S16c imports them. Against the image, whose user store starts with none,
// and which the test leaves with none.
import { axeCheck } from './axe';
import { d1Text } from './expected';
import { expect, test } from './fixtures';
import { documentPath } from './highlights';
import { notes, removeNotesAndSummaries, summaries } from './notes';

test.afterEach(async ({ page }) => {
  await removeNotesAndSummaries(page);
});

test('writes, moves between, edits, inserts into a note and deletes the researcher’s own summaries, by pointer', async ({ page }) => {
  await page.goto(`${documentPath}?rail=research`);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  expect(await summaries(page)).toEqual([]);
  const rail = page.getByRole('complementary', { name: 'Research' });
  const section = rail.locator('#research-summary');
  await expect(rail.getByRole('button', { name: 'Summary', exact: true })).toHaveAttribute('aria-expanded', 'true');

  // Two of one's own, the newest shown, labelled as the headnote chip names what is one's own.
  for (const text of ['The first reading: a cordial opening.', 'The second reading: an offer of talks.']) {
    await section.getByRole('button', { name: 'Write a Summary' }).click();
    const dialog = page.getByRole('dialog', { name: 'Write a Summary' });
    await expect(dialog.getByRole('textbox')).toBeFocused();
    await page.keyboard.type(text);
    await axeCheck(page);
    await dialog.getByRole('button', { name: 'Save' }).click();
    await expect(dialog).toHaveCount(0);
    await expect(section.locator('.summary-text')).toHaveText(text);
  }
  await expect(section.locator('.summary-label')).toHaveText('Yours');
  const [newest, oldest] = await summaries(page);
  expect([newest.responseText, oldest.responseText, newest.authorship, newest.editable, newest.isHeadnoteDraft]).toEqual([
    'The second reading: an offer of talks.',
    'The first reading: a cordial opening.',
    'userWritten',
    true,
    false,
  ]);

  // The Mac's history control: older first, the position, newer last.
  const older = section.getByRole('button', { name: 'Older summary' });
  const newer = section.getByRole('button', { name: 'Newer summary' });
  await expect(section.locator('.summary-history')).toContainText('1/2');
  await expect(newer).toHaveAttribute('aria-disabled', 'true');
  await axeCheck(page);
  await older.click();
  await expect(section.locator('.summary-text')).toHaveText('The first reading: a cordial opening.');
  await expect(section.locator('.summary-history')).toContainText('2/2');
  await expect(older).toHaveAttribute('aria-disabled', 'true');

  // Edit… the older; after a write the newest is shown again.
  await section.getByRole('button', { name: 'Edit…' }).click();
  const editing = page.getByRole('dialog', { name: 'Edit Summary' });
  await expect(editing.getByRole('textbox')).toHaveValue('The first reading: a cordial opening.');
  await axeCheck(page);
  await editing.getByRole('textbox').fill('The first reading, revised: a cordial opening.');
  await editing.getByRole('button', { name: 'Save' }).click();
  await expect(editing).toHaveCount(0);
  await expect(section.locator('.summary-text')).toHaveText('The second reading: an offer of talks.');
  await older.click();
  await expect(section.locator('.summary-text')).toHaveText('The first reading, revised: a cordial opening.');

  // Closed, the header previews the summary shown.
  await rail.getByRole('button', { name: 'Summary', exact: true }).click();
  await expect(rail.getByRole('button', { name: 'Summary, The first reading, revised: a cordial opening.…' })).toHaveAttribute('aria-expanded', 'false');
  await axeCheck(page);
  await rail.getByRole('button', { name: /^Summary, / }).click();

  // The note editor's Generated Summaries: Insert into note puts the text in an empty note.
  await rail.getByRole('button', { name: 'Add Note', exact: true }).click();
  const editor = page.getByRole('dialog', { name: 'New Research Note' });
  const generated = editor.getByRole('region', { name: 'Generated Summaries' });
  await expect(generated.getByRole('listitem')).toHaveCount(2);
  await generated.getByRole('listitem').filter({ hasText: 'offer of talks' }).getByRole('button', { name: 'Insert into note' }).click();
  await expect(editor.getByRole('textbox', { name: 'Research note body' })).toHaveText('The second reading: an offer of talks.');
  await expect(generated.getByRole('button', { name: 'Remove from note' })).toHaveCount(1);
  await axeCheck(page);
  await editor.getByRole('button', { name: 'Save' }).click();
  await expect(editor).toHaveCount(0);
  const [made] = await notes(page);
  expect([made.bodyText, made.selectedSummaryIds]).toEqual(['The second reading: an offer of talks.', [newest.id]]);

  // Opened again from the rail, Remove from note unticks the summary and leaves its text, as the
  // app's does; Insert into note then adds it again after a blank line.
  const row = rail.locator('#research-notes').getByRole('button', { name: /^The second reading/ });
  await row.click();
  const edit = page.getByRole('dialog', { name: 'Edit Note' });
  const inserted = edit.getByRole('region', { name: 'Generated Summaries' }).getByRole('listitem').filter({ hasText: 'offer of talks' });
  await inserted.getByRole('button', { name: 'Remove from note' }).click();
  await expect(inserted.getByRole('button', { name: 'Insert into note' })).toBeVisible();
  await expect(edit.getByRole('button', { name: 'Remove from note' })).toHaveCount(0);
  await expect(edit.getByRole('textbox', { name: 'Research note body' })).toHaveText('The second reading: an offer of talks.');
  await axeCheck(page);
  await edit.getByRole('button', { name: 'Save' }).click();
  await expect(edit).toHaveCount(0);
  const [removed] = await notes(page);
  expect([removed.bodyText, removed.selectedSummaryIds]).toEqual(['The second reading: an offer of talks.', []]);
  await row.click();
  await inserted.getByRole('button', { name: 'Insert into note' }).click();
  await expect(inserted.getByRole('button', { name: 'Remove from note' })).toBeVisible();
  await edit.getByRole('button', { name: 'Save' }).click();
  await expect(edit).toHaveCount(0);
  const [again] = await notes(page);
  expect([again.bodyText, again.selectedSummaryIds]).toEqual(['The second reading: an offer of talks.\n\nThe second reading: an offer of talks.', [newest.id]]);

  // Delete… each, after its question, Cancel first.
  for (let left = 2; left > 0; left--) {
    await section.getByRole('button', { name: 'Delete…' }).click();
    const question = page.getByRole('alertdialog', { name: 'Delete Summary?' });
    await expect(question).toContainText('This summary will be permanently deleted.');
    await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
    if (left === 2) await axeCheck(page);
    await question.getByRole('button', { name: 'Delete', exact: true }).click();
    await expect(question).toHaveCount(0);
    await expect.poll(async () => (await summaries(page)).length).toBe(left - 1);
  }
  await expect(section.locator('.summary-block')).toHaveCount(0);
  await expect(section.getByRole('button', { name: 'Write a Summary' })).toBeFocused();
  await axeCheck(page);
  // The note keeps the id of the summary it named, as the app's does.
  expect((await notes(page))[0].selectedSummaryIds).toEqual([newest.id]);
});
