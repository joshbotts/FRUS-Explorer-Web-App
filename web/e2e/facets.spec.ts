// S11d's done-when (docs/PLAN.md): Playwright uses the facets on Chromium with no axe violations.
// Against the image, with the synthetic export imported: three documents, two of 1960 in
// frus1961-63v06, both mentioning Khrushchev, and one of 1894 in frus1894Nicaragua.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';

test('the facets stage years to include or exclude, then Apply, and narrow to a person and a type, each a filter that clears', async ({ page }) => {
  await page.goto('/search?keywords=negotiating+OR+canal');
  const results = page.getByRole('list', { name: 'Results' });
  const count = page.getByRole('status').filter({ hasText: 'match' });
  await expect(results.getByRole('listitem')).toHaveCount(3);

  const toggle = page.getByRole('button', { name: 'Facets' });
  await toggle.click();
  await expect(toggle).toHaveAttribute('aria-expanded', 'true');
  await expect(page).toHaveURL(/[?&]panel=facets(&|$)/);
  const panel = page.getByRole('complementary', { name: 'Result-set facets' });
  await expect(panel).toContainText('Describing all 3 matches');

  // Years, newest first: include 1894, Apply.
  await panel.getByRole('button', { name: 'Years' }).click();
  const year1960 = panel.getByRole('button', { name: /^1960 2, / });
  const year1894 = panel.getByRole('button', { name: /^1894 1, / });
  await expect(panel.getByRole('button', { name: /^\d{4} \d, Not selected$/ })).toHaveCount(2);
  await expect(panel.locator('.facet-row').first()).toContainText('1960');
  await year1894.click();
  await expect(year1894).toHaveAccessibleName('1894 1, Included');
  await expect(panel).toContainText('1 included');
  await axeCheck(page);
  await panel.getByRole('button', { name: 'Apply' }).click();
  await expect(page).toHaveURL(/[?&]yearKeys=1894(&|$)/);
  await expect(results.getByRole('listitem')).toHaveCount(1);
  await expect(count).toContainText('1 document matches · narrowed from 3');
  const years = page.getByRole('button', { name: 'Years 1894, clear this filter' });
  await expect(years).toBeVisible();
  await years.click();
  await expect(results.getByRole('listitem')).toHaveCount(3);
  await expect(page).not.toHaveURL(/yearKeys/);

  // An exclusion alone means every year but that one.
  await year1960.click();
  await year1960.click();
  await expect(year1960).toHaveAccessibleName('1960 2, Excluded');
  await expect(panel).toContainText('1 excluded');
  await panel.getByRole('button', { name: 'Apply' }).click();
  await expect(page).toHaveURL(/[?&]yearKeys=1894(&|$)/);
  await expect(results.getByRole('listitem')).toHaveCount(1);
  await page.getByRole('button', { name: 'Years 1894, clear this filter' }).click();
  await expect(results.getByRole('listitem')).toHaveCount(3);

  // People narrows on a click, by the person's rollup, and focus returns to the section.
  await panel.getByRole('button', { name: 'People' }).click();
  await panel.getByRole('button', { name: 'Khrushchev, Nikita Sergeyevich 2' }).click();
  await expect(page).toHaveURL(/[?&]personRollupId=1(&|$)/);
  await expect(results.getByRole('listitem')).toHaveCount(2);
  await expect(panel.getByRole('button', { name: 'People' })).toBeFocused();
  await expect(page.getByRole('button', { name: 'Person Khrushchev, Nikita Sergeyevich, clear this filter' })).toBeVisible();

  // Document type narrows the type filter, which the filters show.
  await panel.getByRole('button', { name: 'Document type' }).click();
  await panel.getByRole('button', { name: 'Documents 2' }).click();
  await expect(page).toHaveURL(/[?&]documentType=documentsOnly(&|$)/);
  await expect(page.getByRole('combobox', { name: 'Document type' })).toHaveValue('documentsOnly');

  // Every section open, over the narrowed match: nothing on the page fails axe.
  for (const name of ['Volumes', 'Archival provenance', 'Subjects']) await panel.getByRole('button', { name }).click();
  await expect(panel.getByText('Counting…')).toHaveCount(0);
  await axeCheck(page);

  await page.getByRole('button', { name: 'Person Khrushchev, Nikita Sergeyevich, clear this filter' }).click();
  await expect(page).not.toHaveURL(/personRollupId/);
  // Closing the panel hands the toggle back.
  await toggle.click();
  await expect(panel).toHaveCount(0);
  await expect(page).not.toHaveURL(/panel=facets/);
});
