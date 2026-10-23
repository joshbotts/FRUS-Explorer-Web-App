// S11e's done-when (docs/PLAN.md): Playwright uses the Query Inspector and the date order on
// Chromium with no axe violations. Against the image, with the synthetic export imported: three
// documents, d1 and d2 of November 1960 in frus1961-63v06, both negotiating, and d1 of January 1894
// in frus1894Nicaragua, of the canal; and four rows of frus1969-76v01, which neither word finds.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';

test('the Query Inspector follows the text as it is typed, counts each term in scope, and names the term a search found nothing for', async ({
  page,
}) => {
  await page.goto('/search');
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await box.fill('negotiating -canal');
  // The strip reads the box as it is typed; nothing is searched until the search is made.
  const strip = page.getByRole('region', { name: 'Query Inspector' });
  await expect(strip).toContainText('MATCH');
  await expect(strip.locator('code')).toContainText('negotiating');
  await expect(strip.locator('code')).toContainText('canal');
  await expect(page.getByRole('list', { name: 'Results' })).toHaveCount(0);

  await strip.getByRole('button', { name: 'Show term detail' }).click();
  const terms = strip.getByRole('listitem');
  await expect(terms).toHaveCount(2);
  await expect(terms.nth(0)).toContainText('negotiating 2 across everything this server has indexed');
  await expect(terms.nth(0)).toContainText('negotiating is searched as negoti — other words with that root match too');
  await expect(terms.nth(1)).toContainText('canal EXCLUDED excluded');
  await expect(strip).toContainText('Counts are over the 3 volumes indexed on this server — not the whole published series.');
  await strip.getByRole('button', { name: 'Count each term in scope…' }).click();
  await expect(terms.nth(0)).toContainText('2 in your current scope · 2 across everything this server has indexed');
  await expect(strip.getByRole('button', { name: 'Count each term in scope…' })).toHaveCount(0);
  await expect(strip.getByRole('button', { name: 'Hide term detail' })).toBeFocused();
  await axeCheck(page);

  // A search that finds nothing names the term responsible, and the strip keeps its detail open.
  await box.fill('negotiating formosa');
  await box.press('Enter');
  await expect(page.getByRole('heading', { name: 'No Results' })).toBeVisible();
  await expect(page.getByText('formosa matches no document in your current scope. The rest of your query is not the problem.')).toBeVisible();
  await expect(page.getByText('0 here means 0 in what this server has indexed — 3 volumes.')).toBeVisible();
  await expect(strip.getByRole('button', { name: 'Hide term detail' })).toHaveAttribute('aria-expanded', 'true');
  await expect(strip.getByRole('listitem')).toHaveCount(2);
  await axeCheck(page);
});

test('the results read in either order of the date from their first page, and by relevance again', async ({ page }) => {
  await page.goto('/search?keywords=negotiating+OR+canal');
  const titles = page.getByRole('list', { name: 'Results' }).getByRole('link');
  await expect(titles).toHaveCount(3);
  const orders = page.getByRole('group', { name: 'Sort' });
  await expect(orders.getByRole('button', { name: 'Relevance' })).toHaveAttribute('aria-pressed', 'true');

  await orders.getByRole('button', { name: 'Date ↑' }).click();
  await expect(page).toHaveURL(/[?&]sort=dateAscending(&|$)/);
  await expect(titles).toHaveText([
    'No. 1. Mr. Baker to Mr. Gresham',
    '1. Telegram From the Embassy in the Soviet Union',
    '2. Memorandum of Conversation',
  ]);
  await expect(orders.getByRole('button', { name: 'Date ↑' })).toHaveAttribute('aria-pressed', 'true');

  await orders.getByRole('button', { name: 'Date ↓' }).click();
  await expect(page).toHaveURL(/[?&]sort=dateDescending(&|$)/);
  await expect(titles).toHaveText([
    '2. Memorandum of Conversation',
    '1. Telegram From the Embassy in the Soviet Union',
    'No. 1. Mr. Baker to Mr. Gresham',
  ]);
  await axeCheck(page);

  // The order outlasts a new search, as the Mac's window keeps it.
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await box.fill('negotiating');
  await box.press('Enter');
  await expect(titles).toHaveText(['2. Memorandum of Conversation', '1. Telegram From the Embassy in the Soviet Union']);
  await expect(page).toHaveURL(/[?&]sort=dateDescending(&|$)/);

  await orders.getByRole('button', { name: 'Relevance' }).click();
  await expect(page).not.toHaveURL(/sort=/);
  await expect(orders.getByRole('button', { name: 'Relevance' })).toHaveAttribute('aria-pressed', 'true');
});
