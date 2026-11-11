// Administration ▸ Library (PLAN's S21c), by keyboard on Chromium with no axe violations. In the main suite,
// on the smoke test's Import server, the Library lists the TEI folder and the index and downloads nothing,
// saying why. With FRUS_E2E_LIBRARY, on the smoke test's Standalone server, whose library has downloaded
// the three fixture volumes from a folder served as GitHub serves them, a volume is removed after a question
// and downloaded again, its state followed until it is indexed, which follows its download (PLAN's S21d).
// frus1969-76ve09p1 is in both servers' folders and in neither's index: the synthetic export that seeds the
// Standalone server's indexes frus1961-63v06 and frus1894Nicaragua.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

const standalone = !!process.env.FRUS_E2E_LIBRARY;
const caption = 'The catalogue’s volumes, with what this server holds of each';

test('an Import server’s Library lists its TEI folder and the index, and downloads nothing', async ({ page }) => {
  test.skip(standalone, 'the Standalone server downloads, in the test below');
  await page.goto('admin/library');
  await expect(page.getByRole('heading', { level: 1, name: 'Library', exact: true })).toBeVisible();
  await expect(page.getByText('This server serves an index exported from the Mac', { exact: false })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Download All' })).toHaveCount(0);
  await axeCheck(page);
  const find = page.getByRole('searchbox', { name: 'Find a volume' });
  await tabTo(page, find, 60);
  await page.keyboard.type('frus1969-76ve09p1');
  const table = page.getByRole('table', { name: caption });
  await expect(table.getByRole('rowheader')).toHaveCount(1);
  const row = table.getByRole('row').filter({ has: page.getByRole('rowheader', { name: /^frus1969-76ve09p1/ }) });
  await expect(row.getByText('In the TEI folder', { exact: true })).toBeVisible();
  await expect(row.getByRole('button')).toHaveCount(0);
  await axeCheck(page);
});

test('a Standalone server’s Library removes a volume after a question and downloads it again, by keyboard', async ({ page, problems }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_LIBRARY');
  // Three axe passes over the catalogue's table, and a download the mirror serves slowly.
  test.setTimeout(90_000);
  await page.goto('admin/library');
  await expect(page.getByRole('heading', { level: 1, name: 'Library', exact: true })).toBeVisible();
  await expect(page.getByText('Volumes and their figure images come from the mirror', { exact: false })).toBeVisible();
  await axeCheck(page);
  const find = page.getByRole('searchbox', { name: 'Find a volume' });
  await tabTo(page, find, 60);
  await page.keyboard.type('frus1969-76ve09p1');
  const table = page.getByRole('table', { name: caption });
  // A filter's inner locator is read within the row: `page`'s, not the table's.
  const header = page.getByRole('rowheader', { name: /^frus1969-76ve09p1/ });
  const row = table.getByRole('row').filter({ has: header });
  await expect(row.getByText('Downloaded', { exact: true })).toBeVisible();

  const remove = row.getByRole('button', { name: 'Remove frus1969-76ve09p1', exact: true });
  await tabTo(page, remove, 20);
  await page.keyboard.press('Enter');
  const question = page.getByRole('alertdialog', { name: 'Remove frus1969-76ve09p1?' });
  await expect(question.getByRole('button', { name: 'Keep It', exact: true })).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('Tab');
  await expect(question.getByRole('button', { name: 'Remove', exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(question).toHaveCount(0);
  await expect(row.getByText('Not downloaded', { exact: true })).toBeVisible();
  await expect(header).toBeFocused();
  await expect(page.getByRole('status').filter({ hasText: 'Removed frus1969-76ve09p1.' })).toHaveCount(1);

  const download = row.getByRole('button', { name: 'Download frus1969-76ve09p1', exact: true });
  await tabTo(page, download, 20);
  await page.keyboard.press('Enter');
  await expect(page.getByRole('status').filter({ hasText: 'The download of frus1969-76ve09p1 is queued as a job: Jobs follows it.' })).toHaveCount(1);
  // The Library is read again every two seconds while the download waits or runs, and the indexing after it.
  await expect(row.getByText('Indexed', { exact: true })).toBeVisible({ timeout: 60_000 });
  await axeCheck(page);
  // While the indexing job writes the index, /readyz answers 503, naming the indexing, which the shell's banner
  // shows (PLAN's S21d): a reading of it then is the one console error this test expects.
  const expected = problems.filter((problem) => problem.includes('the server responded with a status of 503'));
  problems.splice(0, problems.length, ...problems.filter((problem) => !expected.includes(problem)));
});
