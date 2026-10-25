// S19a's done-when (docs/PLAN.md), by keyboard alone: Citation Lookup's three modes on Chromium, the
// mode picker by its arrows, Return in a field to look up, a result's View Document, Batch's Needs
// work first and a note's document, with no axe violations. No text in the reader is selected, so no
// caret browsing is needed. Against the image, with the synthetic export imported.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

const link = 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1';

test('looks up a pasted link, a structured page and a block of notes, by keyboard alone', async ({ page }) => {
  await page.goto('lookup');
  await expect(page.getByRole('heading', { level: 1, name: 'Citation Lookup' })).toBeVisible();

  // Paste Citation: Tab to the mode picker and on to the text, and Return looks it up.
  const paste = page.getByRole('radio', { name: 'Paste Citation' });
  await tabTo(page, paste);
  await expect(paste).toBeChecked();
  const text = page.getByRole('textbox', { name: 'Citation Text' });
  await tabTo(page, text);
  await page.keyboard.type(link);
  await expect(page.getByRole('textbox', { name: 'Document no.' })).toHaveValue('1');
  await expect(page.getByRole('button', { name: 'Look Up' })).toHaveAttribute('aria-disabled', 'false');
  await page.keyboard.press('Enter');
  const found = page.getByRole('list', { name: 'Results (1 found)' }).getByRole('listitem');
  await expect(found.locator('.confidence')).toHaveText('Exact match');
  // Return looked it up; it began no line.
  await expect(text).toHaveValue(link);
  await expect(text).toBeFocused();
  await axeCheck(page);

  // The result's View Document opens the document; Back returns to the lookup as it was.
  const view = found.getByRole('link', { name: /^View Document/ });
  await tabTo(page, view);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d1$/);
  await page.goBack();
  await expect(page.getByRole('list', { name: 'Results (1 found)' })).toBeVisible();

  // Structured Entry, by the picker's arrows: focus stays on the picker as the mode changes.
  await tabTo(page, page.getByRole('radio', { name: 'Paste Citation' }));
  await page.keyboard.press('ArrowRight');
  const structured = page.getByRole('radio', { name: 'Structured Entry' });
  await expect(structured).toBeChecked();
  await expect(structured).toBeFocused();
  await expect(text).toHaveCount(0);
  // The fields the link filled stay, as the app's form keeps them; the page replaces the number.
  const documentNumber = page.getByRole('textbox', { name: 'Document no.' });
  await tabTo(page, documentNumber);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.press('Tab');
  await expect(page.getByRole('textbox', { name: 'Page' })).toBeFocused();
  await page.keyboard.type('2');
  await expect(page.getByRole('button', { name: 'Look Up' })).toHaveAttribute('aria-disabled', 'false');
  await page.keyboard.press('Enter');
  const byPage = page.getByRole('list', { name: 'Results (1 found)' }).getByRole('listitem');
  await expect(byPage.getByRole('heading', { level: 3 })).toHaveText('d2');
  await expect(byPage.locator('.confidence')).toHaveText('Matched by page number — this document begins on page 2 and ends on it');
  await axeCheck(page);

  // Batch: the picker's last mode; in its footnotes Return begins a line, and Look Up runs it.
  await backTabTo(page, structured);
  await page.keyboard.press('ArrowRight');
  const batch = page.getByRole('radio', { name: 'Batch' });
  await expect(batch).toBeChecked();
  const footnotes = page.getByRole('textbox', { name: 'Footnotes' });
  await tabTo(page, footnotes);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(`1. ${link}`);
  await page.keyboard.press('Enter');
  await page.keyboard.type('2. Memorandum, no citation at all.');
  await expect(footnotes).toHaveValue(`1. ${link}\n2. Memorandum, no citation at all.`);
  const lookUp = page.getByRole('button', { name: 'Look Up' });
  await tabTo(page, lookUp);
  await expect(lookUp).toHaveAttribute('aria-disabled', 'false');
  await page.keyboard.press('Enter');
  const summary = '2 citations · 1 resolved · 0 ambiguous · 0 best guesses · 1 unresolved';
  const table = page.getByRole('list', { name: summary });
  await expect(table.getByRole('listitem').locator('.batch-marker')).toHaveText(['2', '1']);
  await axeCheck(page);

  // Needs work first, by Space; then the resolved note's document, by Return.
  const toggle = page.getByRole('button', { name: 'Needs work first' });
  await tabTo(page, toggle);
  await page.keyboard.press('Space');
  await expect(toggle).toHaveAttribute('aria-pressed', 'false');
  await expect(table.getByRole('listitem').locator('.batch-marker')).toHaveText(['1', '2']);
  const note = table.getByRole('link', { name: link });
  await tabTo(page, note);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d1$/);
});
