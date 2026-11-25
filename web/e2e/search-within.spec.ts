// S27e's done-when (docs/PLAN.md): Playwright runs both layers of Search Within These Results and the fallback by
// keyboard, on Chromium with no axe violations. Against the image, its encoder and every semantic vector in it, with the
// synthetic export imported (frus1961-63v06's d1 and d2, both on treaties, and frus1894Nicaragua's d1): a keyword list of
// the two held and ranked by a question, the two searches swapped, so that the question's closest matches are held and
// the words found in them, and the list left; and a Meaning list held, words found nowhere in it, searched across the
// whole library instead, where the keyword search finds nothing and the nearest by meaning are listed under it, one
// followed. Nothing is saved, so the suite's second pass on the same store starts as the first.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

/** A question whose nearest documents across the series include the two of November 1960 the export holds. */
const question = 'Khrushchev congratulates Kennedy on his election';

test('ranks a keyword list by a question by keyboard, swaps the two searches, and leaves the list', async ({ page }) => {
  await page.goto('search?keywords=treaties');
  const results = page.getByRole('list', { name: 'Results' });
  await expect(results.getByRole('heading')).toHaveCount(2);

  // The list held: its row in Search by's place, the field emptied and asking for a question, the rows still shown.
  const hold = page.getByRole('button', { name: 'Rank These Results by a Question' });
  await tabTo(page, hold, 80);
  await page.keyboard.press('Enter');
  const row = page.getByRole('region', { name: 'Searching within 2 results for “treaties”' });
  await expect(row).toContainText('Within 2 results for “treaties”');
  await expect(page.getByRole('group', { name: 'Search by' })).toHaveCount(0);
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await expect(box).toBeFocused();
  await expect(box).toHaveAttribute('placeholder', 'A question to rank these results by…');
  await expect(results.getByRole('heading')).toHaveCount(2);
  await axeCheck(page);

  // A question ranks every row of it, each with its chip, under the strip that says where it ranked.
  await page.keyboard.type(question);
  await page.keyboard.press('Enter');
  const header = page.getByRole('status').filter({ hasText: 'closest first' });
  // The first search by meaning starts the encoder.
  await expect(header).toContainText('2 results, closest first', { timeout: 60_000 });
  await expect(results.locator('.semantic-chip')).toHaveText([/^Semantic match · \d+%$/, /^Semantic match · \d+%$/]);
  await expect(page.getByRole('region', { name: 'About this Meaning search' })).toContainText(
    'inside the 2 documents you are searching within',
  );
  await axeCheck(page);

  // Swap: the question's closest matches across the series become the list, and the words are found in them.
  const swap = row.getByRole('button', { name: 'Swap the two searches' });
  await expect(swap).toHaveAttribute('title', `Ask “${question}” first, then find “treaties” among its closest matches`);
  await backTabTo(page, swap, 20);
  await page.keyboard.press('Enter');
  const swapped = page.getByRole('region', { name: new RegExp(`^Searching within (\\d+ closest matches|the closest match) to “${question}”$`) });
  await expect(swapped).toBeVisible();
  await expect(box).toHaveValue('treaties');
  await expect(page.getByRole('status').filter({ hasText: 'these words' })).toContainText(
    /(\d+ of your \d+ closest matches contain|1 of your \d+ closest matches contains|Your closest match contains) these words/,
    { timeout: 60_000 },
  );
  await expect(results.locator('.semantic-chip').first()).toHaveText(/^Semantic match · \d+%$/);
  await axeCheck(page);

  // Left, the list it held comes back: the question's own closest matches.
  const leave = swapped.getByRole('button', { name: 'Stop searching within these results' });
  await backTabTo(page, leave, 20);
  await page.keyboard.press('Enter');
  await expect(page.getByRole('group', { name: 'Search by' })).toBeVisible();
  await expect(page.getByRole('searchbox', { name: 'Search the documents' })).toHaveValue(question);
  await expect(page).toHaveURL(/[?&]by=meaning(&|$)/);
  await expect(page).not.toHaveURL(/[?&]within=/);
  await expect(page.getByRole('status').filter({ hasText: 'closest match' })).toContainText(/\d+ closest match/);
  await axeCheck(page);
});

test('finds words in a Meaning list by keyboard, then searches the whole library and opens the nearest by meaning', async ({ page }) => {
  await page.goto(`search?keywords=${encodeURIComponent(question)}&by=meaning`);
  const results = page.getByRole('list', { name: 'Results' });
  await expect(results.getByRole('heading').first()).toBeVisible({ timeout: 60_000 });

  const hold = page.getByRole('button', { name: 'Find Words in These Matches' });
  await tabTo(page, hold, 80);
  await page.keyboard.press('Enter');
  const row = page.getByRole('region', { name: new RegExp(`^Searching within (\\d+ closest matches|the closest match) to “${question}”$`) });
  await expect(row).toBeVisible();
  // The hits in volumes this server does not serve have no rows to search, which the row says.
  await expect(row).toContainText(/in (volumes|a volume) this server does not serve (are|is) not included/);
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await expect(box).toBeFocused();
  await expect(box).toHaveAttribute('placeholder', 'Words to find in these matches…');
  await axeCheck(page);

  // Words found nowhere in the list: what it looked in, and the ways on.
  await page.keyboard.type('zeppelin');
  await page.keyboard.press('Enter');
  await expect(
    page.getByRole('heading', { name: /^(None of your \d+ closest matches contains these words|Your closest match does not contain these words)$/ }),
  ).toBeVisible();
  await expect(page.getByRole('button', { name: /^Back to the (\d+ Matches|Closest Match)$/ })).toBeVisible();
  await axeCheck(page);

  // The words searched across the whole library: the keyword search finds nothing, and the nearest by meaning follow.
  const everywhere = page.getByRole('button', { name: 'Search the Whole Library for These Words' });
  await tabTo(page, everywhere, 80);
  await page.keyboard.press('Enter');
  await expect(page).not.toHaveURL(/[?&]within=/);
  await expect(page.getByRole('heading', { name: 'No Results' })).toBeVisible();
  const fallback = page.getByRole('region', { name: 'Semantic matches (experimental)' });
  await expect(fallback).toContainText('Ranked by meaning, not keywords, across the whole series — your exact words may not appear.', {
    timeout: 60_000,
  });
  await expect(fallback.locator('.semantic-chip').first()).toHaveText(/^Semantic match · \d+%$/);
  await expect(page.getByRole('button', { name: /Download/ })).toHaveCount(0);
  await axeCheck(page);

  // A hit followed by keyboard: a document the server holds opens in the reader, another's volume in Browse.
  const first = fallback.getByRole('link').first();
  await tabTo(page, first, 80);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/(doc\/[^/]+\/[^/]+|browse\/[^/?]+)$/);
  await page.goBack();
  await expect(fallback).toBeVisible();
});
