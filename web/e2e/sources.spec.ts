// S22d's done-when (docs/PLAN.md): Playwright opens a document's sources and a collection's record by keyboard
// on Chromium with no axe violations. In the main suite, over the synthetic export, the reader's Sources opens
// a document's Source Explorer by keyboard. With FRUS_E2E_SOURCES, on the smoke test's Standalone server, whose
// index holds the three fixture volumes, frus1961-63v06's d3, a lot file the bundled index resolves, is opened
// from the reader by keyboard, its collection's record followed from it, the record's neighbours, and the
// document's neighbours in their three scopes, axe at each step; and the volume's Sources outline is opened from
// Browse and its branches closed and opened by keyboard.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

const standalone = !!process.env.FRUS_E2E_SOURCES;

test('opens a document’s Source Explorer from the reader by keyboard', async ({ page }) => {
  test.skip(standalone, 'the Standalone server’s sources are the test below');
  await page.goto('doc/frus1961-63v06/d2');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  const tile = page.getByRole('group', { name: 'Document' }).getByRole('link', { name: 'Sources', exact: true });
  await tabTo(page, tile);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/sources\/frus1961-63v06\/d2/);
  await expect(page.getByRole('heading', { level: 1, name: 'Source Explorer' })).toBeFocused();
  await expect(page.getByRole('heading', { level: 2, name: 'Archival Neighbors' })).toBeVisible();
  await axeCheck(page);
  // The way back, by keyboard.
  await tabTo(page, page.getByRole('link', { name: /^Back to / }), 60, 'Shift+Tab');
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/doc\/frus1961-63v06\/d2/);
});

test('follows a lot file’s note to its collection’s record and their neighbours by keyboard', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_SOURCES');
  // Five pages, each with an axe pass.
  test.setTimeout(90_000);
  await page.goto('doc/frus1961-63v06/d3');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  const tile = page.getByRole('group', { name: 'Document' }).getByRole('link', { name: 'Sources', exact: true });
  await tabTo(page, tile);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/sources\/frus1961-63v06\/d3/);
  await expect(page.getByRole('heading', { level: 1, name: 'Source Explorer' })).toBeFocused();
  // The note's sections, in the app's order: its lot, the bundled series, the catalogue's line, the neighbours.
  const provenance = page.getByRole('region', { name: 'Provenance' });
  await expect(provenance.getByText('State Dept. Lot File')).toBeVisible();
  await expect(page.getByRole('region', { name: 'NARA Catalog Record', exact: true })).toBeVisible();
  await expect(
    page.getByRole('region', { name: 'NARA Catalog', exact: true }).getByText('This server does not search the NARA Catalog yet.'),
  ).toBeVisible();
  const neighbours = page.getByRole('region', { name: 'Archival Neighbors', exact: true });
  await expect(neighbours.getByRole('listitem').first()).toBeVisible();
  await axeCheck(page);

  // The collection's record, by keyboard.
  const collection = page.getByRole('region', { name: 'Archival Collection', exact: true }).getByRole('link').first();
  const name = (await collection.textContent()) ?? '';
  await tabTo(page, collection, 120);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/archival-collection\?id=/);
  await expect(page.getByRole('heading', { level: 1, name: 'Collection', exact: true })).toBeFocused();
  await expect(page.getByRole('region', { name: 'Archival Collection', exact: true }).getByText(name, { exact: true })).toBeVisible();
  await expect(
    page.getByRole('region', { name: 'In Your Library', exact: true }).getByText(/of your indexed volumes cite this collection\.$/),
  ).toBeVisible();
  await expect(page.getByRole('region', { name: /^Cited Across the Series/ }).getByRole('link').first()).toBeVisible();
  await axeCheck(page);

  // The record's neighbours, by keyboard: all volumes', with no picker.
  await tabTo(page, page.getByRole('link', { name: 'Show Archival Neighbors' }), 60);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/archival-neighbors\?collection=/);
  await expect(page.getByRole('heading', { level: 1, name: 'Archival Neighbors', exact: true })).toBeFocused();
  await expect(page.getByRole('main').getByRole('listitem').first()).toBeVisible();
  await expect(page.getByRole('radio')).toHaveCount(0);
  await axeCheck(page);

  // The document's own neighbours, in their three scopes: the picker on All volumes, then This volume. A page
  // just loaded starts at its top, where Skip to content is the first stop, so the heading is not focused.
  await page.goto('sources/frus1961-63v06/d3');
  await expect(page.getByRole('heading', { level: 1, name: 'Source Explorer' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Archival Neighbors', exact: true }).getByRole('listitem').first()).toBeVisible();
  await tabTo(page, page.getByRole('link', { name: 'Archival Neighbors…' }), 120);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/archival-neighbors\?.*documentId=d3/);
  const all = page.getByRole('radio', { name: 'All volumes' });
  await expect(all).toBeChecked();
  await expect(page.getByRole('radio', { name: 'This subseries' })).toBeVisible();
  await tabTo(page, all, 20);
  // The radios are one group, which the arrow keys move through: back past This subseries to This volume. The
  // list on show stays while the next is fetched, so the check waits for This volume's answer and its rows.
  const thisVolume = page.waitForResponse((response) => response.url().includes('scope=volume'));
  await page.keyboard.press('ArrowLeft');
  await expect(page.getByRole('radio', { name: 'This subseries' })).toBeChecked();
  await page.keyboard.press('ArrowLeft');
  await expect(page.getByRole('radio', { name: 'This volume' })).toBeChecked();
  await expect(page).toHaveURL(/scope=volume/);
  await thisVolume;
  await expect(page.locator('[aria-busy="true"]')).toHaveCount(0);
  await expect(page.getByRole('main').getByRole('listitem').first()).toBeVisible();
  await axeCheck(page);
});

test('opens a volume’s Sources outline from Browse and closes and opens its branches by keyboard', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_SOURCES');
  await page.goto('browse/frus1961-63v06');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await tabTo(page, page.getByRole('link', { name: 'List of Sources', exact: true }), 120);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/browse\/frus1961-63v06\/sources/);
  await expect(page.getByRole('heading', { level: 1, name: 'List of Sources' })).toBeFocused();
  const collections = page.getByRole('region', { name: 'Archival Collections', exact: true });
  await expect(collections.getByRole('link', { name: 'View in National Archives Catalog' }).first()).toBeVisible();
  await expect(page.getByRole('region', { name: 'Published Sources', exact: true }).getByRole('listitem').first()).toBeVisible();
  await axeCheck(page);
  // A branch, by its disclosure, named by its row: closed, its rows hidden, then open again.
  const kennedy = collections.getByRole('button', { name: 'John F. Kennedy Library, Boston, Massachusetts' });
  await expect(kennedy).toHaveAttribute('aria-expanded', 'true');
  await tabTo(page, kennedy, 60);
  await page.keyboard.press('Enter');
  await expect(kennedy).toHaveAttribute('aria-expanded', 'false');
  await expect(collections.getByText('National Security Files', { exact: true })).toBeHidden();
  await page.keyboard.press('Space');
  await expect(kennedy).toHaveAttribute('aria-expanded', 'true');
  await expect(collections.getByText('National Security Files', { exact: true })).toBeVisible();
  // Collapse All closes every branch; Expand All opens them.
  await tabTo(page, collections.getByRole('button', { name: 'Collapse All' }), 60, 'Shift+Tab');
  await page.keyboard.press('Enter');
  await expect(collections.getByRole('button', { expanded: true })).toHaveCount(0);
  await expect(collections.getByRole('button', { name: 'Expand All' })).toBeFocused();
  await axeCheck(page);
});
