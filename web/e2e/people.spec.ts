// S21g's done-when (docs/PLAN.md): Playwright merges two people by keyboard on Chromium with no axe violations. In
// the main suite, over the synthetic export, People is reached from Browse by keyboard and a person's sheet opened,
// a subject chip's pivot opened and closed, and the sheet closed, axe at each step. With FRUS_E2E_PEOPLE, on the
// smoke test's Standalone server, whose index holds the three fixture volumes and corrects at once: S21g's
// follow-up's done-when, a sheet's Career and Subjects read and a subject chip followed to a volume covering it, by
// keyboard; and the owner, a curator, merges Adenauer and Adzhubei by keyboard: the sheet's Merge with another
// person…, the picker searched by name, the question, Merge; the screen says what was done and lists one identity of
// the two; and Corrections undoes it by keyboard, the list as it was again.
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
  // Subjects, from his volume's profile: the first chip's pivot by keyboard, and Escape back to the chip.
  const chip = sheet.getByRole('region', { name: 'Subjects' }).getByRole('button').first();
  await expect(chip).toBeVisible();
  await axeCheck(page);
  await tabTo(page, chip, 20);
  const subject = (await chip.textContent()) ?? '';
  await page.keyboard.press('Enter');
  const pivot = page.getByRole('dialog', { name: subject, exact: true });
  await expect(pivot.getByRole('heading', { level: 3, name: /^\d+ volumes? covers? this subject$/ })).toBeVisible();
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(pivot).toBeHidden();
  await expect(chip).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(sheet).toBeHidden();
  await expect(row).toBeFocused();
  // Administration ▸ Corrections, the log, empty on the synthetic export's server.
  await page.goto('admin/corrections');
  await expect(page.getByRole('heading', { level: 1, name: 'Corrections' })).toBeVisible();
  await expect(page.getByText('No curator has corrected the index on this server.')).toBeVisible();
  await axeCheck(page);
});

test('reads a person’s Career and Subjects, and follows a subject chip to a volume, by keyboard', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_PEOPLE');
  test.setTimeout(120_000);
  await page.goto('people');
  await expect(page.getByRole('heading', { level: 1, name: 'People' })).toBeVisible();
  await tabTo(page, page.getByRole('searchbox', { name: 'Search people' }));
  await page.keyboard.type('Bohlen');
  const row = page.getByRole('button', { name: /^Bohlen, Charles Eustis/ });
  await expect(row).toHaveCount(1);
  await tabTo(page, row, 60);
  await page.keyboard.press('Enter');
  const sheet = page.getByRole('dialog', { name: /^Bohlen, Charles Eustis/ });

  // The lifespan line, and Career: the register's posts in its order, each its title, its dates and its note.
  await expect(sheet.getByText('1904–1974', { exact: true })).toBeVisible();
  const career = sheet.getByRole('region', { name: 'Career' });
  const posts = career.getByRole('listitem');
  await expect(posts).toHaveCount(8);
  await expect(posts.nth(0)).toHaveText('Counselor 1947-08-01 – 1949-08-03');
  await expect(posts.nth(4)).toHaveText('Career Ambassador from 1960-06-24');
  await expect(posts.nth(5)).toHaveText('Ambassador Extraordinary and Plenipotentiary — France 1962-10-27 – 1968-02-09 Left post on');
  await expect(career).toContainText('From the Department’s Principal Officers and Chiefs of Mission register.');

  // Subjects: the chips of the kit's ranking, each said with its category and how many of his volumes carry it.
  const chip = sheet.getByRole('region', { name: 'Subjects' }).getByRole('button').first();
  await expect(chip).toHaveAccessibleDescription(/^.+, in \d+ volumes? mentioning this person Shows other volumes covering this subject$/);
  await axeCheck(page);

  // The first chip, followed: its pivot lists the volumes covering its subject, and the first opens its page.
  await tabTo(page, chip, 30);
  const subject = (await chip.textContent()) ?? '';
  await page.keyboard.press('Enter');
  const pivot = page.getByRole('dialog', { name: subject, exact: true });
  await expect(pivot.getByRole('heading', { level: 3, name: /^\d+ volumes? covers? this subject$/ })).toBeVisible();
  const volume = pivot.getByRole('link').first();
  await expect(volume).toBeVisible();
  await axeCheck(page);
  const href = (await volume.getAttribute('href')) ?? '';
  expect(href).toMatch(/\/browse\/frus[^/]+$/);
  await tabTo(page, volume, 10);
  await page.keyboard.press('Enter');
  await page.waitForURL((url) => url.pathname === href);
  await expect(pivot).toBeHidden();
  await expect(page.getByRole('heading', { level: 1 })).toBeFocused();
  await axeCheck(page);
});

test('merges two people by keyboard, and undoes it from Corrections', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_PEOPLE');
  test.setTimeout(120_000);
  // A page just loaded starts at its top, as the shell has it: the field is reached from there.
  await page.goto('people');
  await expect(page.getByRole('heading', { level: 1, name: 'People' })).toBeVisible();
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

  // The log names both, newest first, each applied, above the smoke test's own correction of d1.
  await page.goto('admin/corrections');
  const log = page.getByRole('table', { name: 'The corrections, newest first' });
  await expect(log.getByRole('row').nth(1)).toContainText(/The merge of Adenauer, .+ and Adzhubei, .+ undone.*Applied$/);
  await expect(log.getByRole('row').nth(2)).toContainText(/Adenauer, .+ and Adzhubei, .+ merged.*Applied$/);
  await axeCheck(page);
});
