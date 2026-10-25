// S19a's done-when (docs/PLAN.md), by pointer: Citation Lookup's three modes on Chromium, from
// Search's Find by Citation, with no axe violations. Against the image, with the synthetic export
// imported: frus1961-63v06's d1 and d2, beginning on pages 1 and 2, with no printed numbers, so these
// citations find them by link and by page. Every label is the kit's, as the server answers it.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';

const link = 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1';
const d1Header = '1. Telegram From the Embassy in the Soviet Union';
const v05Title = 'Foreign Relations of the United States, 1961–1963, Volume V, Soviet Union';

test('pastes a link and a page, opens the document a result names and comes back to the lookup as it was', async ({ page }) => {
  await page.goto('search');
  await page.getByRole('link', { name: 'Find by Citation' }).click();
  await expect(page).toHaveURL(/\/lookup$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Citation Lookup' })).toBeFocused();
  await expect(page.getByRole('radio', { name: 'Paste Citation' })).toBeChecked();
  const lookUp = page.getByRole('button', { name: 'Look Up' });
  await expect(lookUp).toHaveAttribute('aria-disabled', 'true');
  await axeCheck(page);

  // A history.state.gov link: the kit fills the Parsed Fields from it, and finds the document it names.
  await page.getByRole('textbox', { name: 'Citation Text' }).fill(link);
  const fields = page.getByRole('group', { name: 'Parsed Fields' });
  await expect(fields.getByRole('textbox', { name: 'Volume' })).toHaveValue('VI');
  await expect(fields.getByRole('textbox', { name: 'Subseries' })).toHaveValue('1961-63');
  await expect(lookUp).toHaveAttribute('aria-disabled', 'false');
  await lookUp.click();
  const results = page.getByRole('list', { name: 'Results (1 found)' });
  const exact = results.getByRole('listitem');
  await expect(exact.locator('.confidence')).toHaveText('Exact match');
  await expect(exact.getByRole('heading', { level: 3 })).toHaveText('d1');
  await expect(exact.locator('.meta')).toHaveText('frus1961-63v06');
  await expect(page.getByRole('status').filter({ hasText: 'found' })).toHaveText('1 matches found');
  await axeCheck(page);

  await exact.getByRole('link', { name: /^View Document/ }).click();
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d1$/);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(d1Header);
  await page.goBack();
  await expect(page).toHaveURL(/\/lookup$/);
  await expect(page.getByRole('textbox', { name: 'Citation Text' })).toHaveValue(link);
  await expect(page.getByRole('list', { name: 'Results (1 found)' })).toBeVisible();

  // A page: the document that begins on it, matched by page number.
  await page.getByRole('textbox', { name: 'Citation Text' }).fill('FRUS, 1961–1963, vol. VI, p. 2');
  await expect(fields.getByRole('textbox', { name: 'Page' })).toHaveValue('2');
  await lookUp.click();
  const byPage = page.getByRole('list', { name: 'Results (1 found)' }).getByRole('listitem');
  await expect(byPage.locator('.confidence')).toHaveText('Matched by page number — this document begins on page 2 and ends on it');
  await expect(byPage.getByRole('heading', { level: 3 })).toHaveText('d2');

  // A volume this server does not hold, which its page in Browse describes.
  await page.getByRole('textbox', { name: 'Citation Text' }).fill('FRUS, 1961–1963, vol. V, doc. 84');
  await lookUp.click();
  const elsewhere = page.getByRole('list', { name: 'Results (1 found)' }).getByRole('listitem');
  await expect(elsewhere.locator('.confidence')).toHaveText('Volume identified — download to find the specific document');
  await expect(elsewhere.getByRole('heading', { level: 3 })).toHaveText(v05Title);
  await axeCheck(page);
  await elsewhere.getByRole('link', { name: /^View Volume/ }).click();
  await expect(page).toHaveURL(/\/browse\/frus1961-63v05$/);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(v05Title);
});

test('looks a page up in Structured Entry, and a cited part the volume lacks is the kit’s best guess', async ({ page }) => {
  await page.goto('lookup');
  await page.getByRole('radio', { name: 'Structured Entry' }).check();
  await expect(page.getByRole('textbox', { name: 'Citation Text' })).toHaveCount(0);
  const fields = page.getByRole('group', { name: 'Parsed Fields' });
  await fields.getByRole('textbox', { name: 'Subseries' }).fill('1961-63');
  await fields.getByRole('textbox', { name: 'Volume' }).fill('VI');
  await fields.getByRole('textbox', { name: 'Page' }).fill('1');
  const lookUp = page.getByRole('button', { name: 'Look Up' });
  await expect(lookUp).toHaveAttribute('aria-disabled', 'false');
  await lookUp.click();
  const found = page.getByRole('list', { name: 'Results (1 found)' }).getByRole('listitem');
  await expect(found.locator('.confidence')).toHaveText('Matched by page number — this document begins on page 1 and ends on it');
  await expect(found.getByRole('heading', { level: 3 })).toHaveText('d1');
  await axeCheck(page);

  await fields.getByRole('textbox', { name: 'Part' }).fill('2');
  await lookUp.click();
  const guess = page.getByRole('list', { name: 'Results (1 found)' }).getByRole('listitem');
  await expect(guess.locator('.confidence')).toHaveText('Best guess — this volume does not match the cited part 2');
  await expect(guess.locator('.match-note')).toContainText('This result comes from a volume the citation does not name');
  await expect(guess.locator('.confidence svg')).toHaveAttribute('data-symbol', 'lightbulb');
  await axeCheck(page);
});

test('triages a chapter’s notes in Batch, worst first or as pasted, and opens a resolved note’s document', async ({ page }) => {
  await page.goto('lookup');
  await page.getByRole('radio', { name: 'Batch' }).check();
  await expect(page.getByRole('group', { name: 'Parsed Fields' })).toHaveCount(0);
  await page
    .getByRole('textbox', { name: 'Footnotes' })
    .fill(
      [
        `1. ${link}`,
        '2. FRUS, 1961–1963, vol. VI,',
        'p. 2.',
        '3. FRUS, 1961–1963, vol. V, doc. 84.',
        '4. Memorandum, no citation at all.',
        '5. FRUS, 1961–1963, vol. VI, pt. 2, p. 1.',
      ].join('\n'),
    );
  const lookUp = page.getByRole('button', { name: 'Look Up' });
  await expect(lookUp).toHaveAttribute('aria-disabled', 'false');
  await lookUp.click();

  const summary = '5 citations · 2 resolved · 1 ambiguous · 1 best guess · 1 unresolved';
  const table = page.getByRole('list', { name: summary });
  await expect(page.getByRole('heading', { level: 2, name: summary })).toBeVisible();
  await expect(page.getByRole('status').filter({ hasText: 'citations' })).toHaveText(summary);
  const rows = table.getByRole('listitem');
  await expect(rows.locator('.batch-marker')).toHaveText(['4', '5', '3', '1', '2']);
  await expect(rows.locator('.batch-outcome')).toHaveText([
    'No match',
    'Best guess — this volume does not match the cited part 2',
    'Volume identified — download to find the specific document',
    'Resolved — frus1961-63v06 d1',
    'Resolved — frus1961-63v06 d2',
  ]);
  // The note wrapped across two lines is one citation.
  await expect(rows.filter({ hasText: 'Resolved — frus1961-63v06 d2' }).locator('.batch-text')).toHaveText('FRUS, 1961–1963, vol. VI, p. 2.');
  await axeCheck(page);

  const toggle = page.getByRole('button', { name: 'Needs work first' });
  await expect(toggle).toHaveAttribute('aria-pressed', 'true');
  await toggle.click();
  await expect(toggle).toHaveAttribute('aria-pressed', 'false');
  await expect(rows.locator('.batch-marker')).toHaveText(['1', '2', '3', '4', '5']);
  await axeCheck(page);

  await table.getByRole('link', { name: 'FRUS, 1961–1963, vol. VI, p. 2.' }).click();
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d2$/);
  await page.goBack();
  await expect(page.getByRole('radio', { name: 'Batch' })).toBeChecked();
  await expect(page.getByRole('heading', { level: 2, name: summary })).toBeVisible();
});

test('answers each mode in the dark appearance with no axe violations', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('lookup');
  await page.getByRole('textbox', { name: 'Citation Text' }).fill('FRUS, 1961–1963, vol. VI, pt. 2, p. 1');
  await expect(page.getByRole('button', { name: 'Look Up' })).toHaveAttribute('aria-disabled', 'false');
  await page.getByRole('button', { name: 'Look Up' }).click();
  await expect(page.getByRole('list', { name: 'Results (1 found)' })).toBeVisible();
  await axeCheck(page);
  await page.getByRole('radio', { name: 'Batch' }).check();
  await page.getByRole('textbox', { name: 'Footnotes' }).fill(`1. ${link}\n2. FRUS, 1961–1963, vol. V, doc. 84.\n3. Memorandum.`);
  await page.getByRole('button', { name: 'Look Up' }).click();
  await expect(page.getByRole('button', { name: 'Needs work first' })).toBeVisible();
  await axeCheck(page);
});
