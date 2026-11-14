// S21g's done-when (docs/PLAN.md): Playwright merges two people by keyboard on Chromium with no axe violations. In
// the main suite, over the synthetic export, People is reached from Browse by keyboard and a person's sheet opened
// and closed, axe at each step. With FRUS_E2E_PEOPLE, on the smoke test's Standalone server, whose index holds the
// three fixture volumes and corrects at once, the owner, a curator, merges Adenauer and Adzhubei by keyboard: the
// sheet's Merge with another person…, the picker searched by name, the question, Merge; the screen says what was
// done and lists one identity of the two; and Corrections undoes it by keyboard, the list as it was again.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

const standalone = !!process.env.FRUS_E2E_PEOPLE;

test('reaches People from Browse and opens a person’s sheet by keyboard', async ({ page }) => {
  test.skip(standalone, 'the Standalone server’s merge is the test below');
  await page.goto('browse');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await tabTo(page, page.getByRole('navigation', { name: 'Browse by' }).getByRole('link', { name: 'People', exact: true }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/people$/);
  await expect(page.getByRole('heading', { level: 1, name: 'People' })).toBeFocused();
  const row = page.getByRole('button', { name: /^Khrushchev, Nikita Sergeyevich/ });
  await expect(row).toBeVisible();
  await axeCheck(page);
  await tabTo(page, row, 60);
  await page.keyboard.press('Enter');
  const sheet = page.getByRole('dialog', { name: 'Khrushchev, Nikita Sergeyevich' });
  await expect(sheet.getByRole('link', { name: 'Find all mentions' })).toBeVisible();
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(sheet).toBeHidden();
  await expect(row).toBeFocused();
});

test('merges two people by keyboard, and undoes it from Corrections', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_PEOPLE');
  test.setTimeout(120_000);
  await page.goto('people');
  await expect(page.getByRole('heading', { level: 1, name: 'People' })).toBeFocused();
  const search = page.getByRole('searchbox', { name: 'Search people' });
  await tabTo(page, search);
  await page.keyboard.type('Ad');
  const adenauer = page.getByRole('button', { name: /^Adenauer, / });
  const adzhubei = page.getByRole('button', { name: /^Adzhubei, / });
  await expect(adenauer).toHaveCount(1);
  await expect(adzhubei).toHaveCount(1);
  await axeCheck(page);

  // Adenauer's sheet, its Merge with another person…, the picker searched for Adzhubei.
  await tabTo(page, adenauer, 60);
  await page.keyboard.press('Enter');
  const sheet = page.getByRole('dialog', { name: /^Adenauer, / });
  const mergeButton = sheet.getByRole('button', { name: 'Merge with another person…' });
  await expect(mergeButton).toBeVisible();
  await axeCheck(page);
  await tabTo(page, mergeButton, 60);
  await page.keyboard.press('Enter');
  const picker = page.getByRole('dialog', { name: 'Merge With…' });
  await expect(picker.getByRole('searchbox', { name: 'Search people' })).toBeFocused();
  await page.keyboard.type('Adzhubei');
  const choice = picker.getByRole('button', { name: /^Adzhubei, / });
  await expect(choice).toHaveCount(1);
  await axeCheck(page);
  await tabTo(page, choice, 10);
  await page.keyboard.press('Enter');

  // The app's question, Cancel first, then Merge.
  const question = page.getByRole('alertdialog', { name: 'Merge these identities?' });
  await expect(question).toContainText('will become a single identity');
  await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('Tab');
  await expect(question.getByRole('button', { name: 'Merge' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('status').filter({ hasText: /^Merged Adzhubei, .+ into Adenauer, / })).toHaveCount(1, { timeout: 60_000 });
  await expect(page.getByRole('heading', { level: 1, name: 'People' })).toBeFocused();
  // One identity of the two now, under the name the rollup gives it.
  await expect(page.getByRole('button', { name: /^(Adenauer|Adzhubei), / })).toHaveCount(1);
  await axeCheck(page);

  // Corrections: the merge, undone by keyboard.
  await tabTo(page, page.getByRole('button', { name: 'Corrections' }), 20);
  await page.keyboard.press('Enter');
  const corrections = page.getByRole('dialog', { name: 'Corrections' });
  const undo = corrections.getByRole('button', { name: /^Undo: Adenauer, .+ and Adzhubei, .+ — merged$/ });
  await expect(undo).toBeVisible();
  await axeCheck(page);
  await tabTo(page, undo, 10);
  await page.keyboard.press('Enter');
  await expect(corrections.getByRole('heading', { name: 'No Corrections' })).toBeVisible({ timeout: 60_000 });
  await tabTo(page, corrections.getByRole('button', { name: 'Done' }), 10);
  await page.keyboard.press('Enter');
  await expect(corrections).toBeHidden();
  await expect(page.getByRole('button', { name: 'Corrections' })).toBeFocused();
  await expect(adenauer).toHaveCount(1);
  await expect(adzhubei).toHaveCount(1);
});
