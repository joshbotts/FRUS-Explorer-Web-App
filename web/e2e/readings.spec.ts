// S11f's done-when (docs/PLAN.md): Playwright uses the timeline and the concordance on Chromium with
// no axe violations, each by keyboard alone. Against the image, with the synthetic export imported:
// three documents, d1 and d2 of November 1960 in frus1961-63v06, both negotiating, and d1 of January
// 1894 in frus1894Nicaragua, of the canal.
import { axeCheck } from './axe';
import { d2Header } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

test('the timeline counts the results the search keeps by year, in a chart with its table and in a list under each year', async ({ page }) => {
  await page.goto('/search?keywords=negotiating+OR+canal');
  await expect(page.getByRole('list', { name: 'Results' }).getByRole('link')).toHaveCount(3);
  const picker = page.getByRole('group', { name: 'Reading' });
  await expect(picker.getByRole('button', { name: 'List' })).toHaveAttribute('aria-pressed', 'true');

  await tabTo(page, picker.getByRole('button', { name: 'Timeline' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/[?&]reading=timeline(&|$)/);
  const chart = page.getByRole('img', { name: 'Documents per year, 1894 to 1960: 3 in 2 years' });
  await expect(chart).toBeVisible();
  await expect(chart.locator('.chart-column')).toHaveCount(2);
  await expect(page.getByRole('list', { name: 'Results' })).toHaveCount(0);
  // The timeline covers every result the search keeps, so it has no pages; every match is kept,
  // so no caption says the shape is a ranking's.
  await expect(page.getByRole('navigation', { name: 'Pages' })).toHaveCount(0);
  await expect(page.getByText(/not a sample across time/)).toHaveCount(0);

  // Its figures are all in its table, which the keyboard opens.
  await tabTo(page, page.getByText('Table of the counts'));
  await page.keyboard.press('Enter');
  const rows = page.getByRole('table').getByRole('row');
  await expect(rows).toHaveText(['YearDocuments', '18941', '19602']);
  await axeCheck(page);

  // The list, under each year, in the order the results are in: here the most recent first.
  await tabTo(page, page.getByRole('group', { name: 'Sort' }).getByRole('button', { name: 'Date ↓' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/[?&]sort=dateDescending(&|$)/);
  await tabTo(page, page.getByRole('group', { name: 'View mode' }).getByRole('button', { name: 'List' }));
  await page.keyboard.press('Enter');
  await expect(page.getByRole('heading', { name: '1894' })).toBeVisible();
  const year1960 = page.locator('.timeline-year').filter({ has: page.getByRole('heading', { name: '1960' }) });
  await expect(year1960.getByRole('link')).toHaveText([d2Header, '1. Telegram From the Embassy in the Soviet Union']);
  await expect(chart).toHaveCount(0);
  await axeCheck(page);

  // A document opens from its year, as a row of the list opens it.
  await tabTo(page, year1960.getByRole('link', { name: d2Header }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d2(\?|$)/);
  await expect(page.getByRole('heading', { level: 1, name: d2Header })).toBeVisible();
  // Back shows the timeline as it was, in its List mode, as the Mac's window stays as it was.
  await page.goBack();
  await expect(page).toHaveURL(/[?&]reading=timeline(&|$)/);
  await expect(page).toHaveURL(/[?&]timelineMode=list(&|$)/);
  await expect(year1960.getByRole('link')).toHaveCount(2);
  await expect(page.getByRole('group', { name: 'View mode' }).getByRole('button', { name: 'List' })).toHaveAttribute('aria-pressed', 'true');
});

test('the concordance lines up each occurrence on the page between its contexts, in each of the kit’s orders', async ({ page }) => {
  await page.goto('/search?keywords=negotiating');
  await expect(page.getByRole('list', { name: 'Results' }).getByRole('link')).toHaveCount(2);
  await tabTo(page, page.getByRole('group', { name: 'Reading' }).getByRole('button', { name: 'Concordance' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/[?&]reading=concordance(&|$)/);
  const lines = page.getByRole('list', { name: 'Occurrences' }).getByRole('link');
  const keywords = page.getByRole('list', { name: 'Occurrences' }).locator('.kwic-keyword');
  await expect(lines).toHaveCount(2);
  // By the word before the term, the Mac's first order: d2's has none, so it comes first.
  await expect(keywords).toHaveText(['Negotiating', 'negotiating']);
  await expect(lines.nth(1)).toHaveAccessibleName(
    'The ambassador was negotiating treaties with the minister.. 1. Telegram From the Embassy in the Soviet Union · 1960-11-09',
  );
  await expect(page.getByText('2 occurrences', { exact: true })).toBeVisible();
  // The concordance shows one page, so the pages stay.
  await expect(page.getByRole('navigation', { name: 'Pages' })).toBeVisible();
  await axeCheck(page);

  const align = page.getByRole('group', { name: 'Align by' });
  await expect(align.getByRole('button')).toHaveText(['Left context', 'Right context', 'Date', 'Volume']);
  await tabTo(page, align.getByRole('button', { name: 'Date' }));
  await page.keyboard.press('Enter');
  await expect(align.getByRole('button', { name: 'Date' })).toHaveAttribute('aria-pressed', 'true');
  await expect(keywords).toHaveText(['negotiating', 'Negotiating']);

  // A line opens its document, and Back returns to the lines in the order chosen.
  await tabTo(page, lines.first());
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d1(\?|$)/);
  await page.goBack();
  await expect(page).toHaveURL(/[?&]align=date(&|$)/);
  await expect(keywords).toHaveText(['negotiating', 'Negotiating']);

  // An exact word is matched as typed, which no stem centers a line on: the Mac's view says so.
  const box = page.getByRole('searchbox', { name: 'Search the documents' });
  await box.fill('=negotiating');
  await box.press('Enter');
  await expect(page.getByRole('heading', { name: 'No Aligned Occurrences' })).toBeVisible();
  await expect(page.getByText(/contributed no line — /)).toBeVisible();
  await expect(page).toHaveURL(/[?&]reading=concordance(&|$)/);
  await axeCheck(page);
});
