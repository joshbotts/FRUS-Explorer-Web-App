// S28d's done-when (docs/PLAN.md): Playwright browses to a region, opens a document and the map, by keyboard on Chromium
// with no axe violations. Against the image with the synthetic export imported, which serves frus1961-63v06's d1 and d2,
// both in the region the bundled map names "edc nato nuclear" (id 115, 10,914 documents), whose members come in volume
// order, so that the volume's 79 come from the 7,931st on: Browse ▸ Clusters lists the regions largest first under the
// kit's caption; the region opens with its facts and its first 500 documents; fifteen presses of Show more list the first
// 8,000, frus1961-63v06's among them, each of a volume this server holds opening in the reader; d1 opens, and back in the
// list See on the semantic map opens the map on the region's card. Save as Working Corpus keeps the app's 7,500 of the
// region's 10,914, named by the map's rule, which Working Corpora lists. A link from another layout, which the server
// answers 409, is the unit suite's and the route tests': the browser logs any answer of an error status as a console
// error, which fails a test here.
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

const telegram = '1. Telegram From the Embassy in the Soviet Union';

test('browses to a region by keyboard, opens one of its documents, and opens the map on it', async ({ page }) => {
  test.setTimeout(300_000);
  await page.goto('browse');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await tabTo(page, page.getByRole('navigation', { name: 'Browse by' }).getByRole('link', { name: 'Clusters', exact: true }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/clusters$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Clusters' })).toBeFocused();
  await expect(
    page.getByText(
      "140 clusters computed from document text. Labels are the most distinctive sampled terms, not subject headings. 88,059 documents (28.0%) belong to no cluster and cannot be reached from this list. Era bars reflect each volume's coverage era, not document dates.",
    ),
  ).toBeVisible();
  const list = page.getByRole('list', { name: 'Clusters' });
  await expect(list.getByRole('listitem')).toHaveCount(140);
  await expect(list.getByRole('link').first()).toHaveAccessibleName('nanking · shanghai · chinese · tientsin, 37,899 documents');
  await axeCheck(page);

  // The region, fourth largest, by keyboard.
  const region = list.getByRole('link', { name: 'edc · nato · nuclear · soviet, 10,914 documents' });
  await tabTo(page, region);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/browse\/clusters\/115\?layout=/);
  const title = page.getByRole('heading', { level: 1, name: 'edc · nato · nuclear · soviet' });
  await expect(title).toBeFocused();
  await expect(page.getByText('Documents in the series')).toBeVisible();
  await expect(page.getByText('10,878', { exact: true })).toBeVisible();
  // By volume, as the kit's resolver counts: frus1961-63v06's 79 members, and those of any other volume the export serves.
  await expect(page.getByText(/^\d+ of 10,914 documents indexed on this server$/)).toHaveClass('count warning');
  await expect(page.getByText(/^A cluster is a grouping detected by an AI model/)).toBeVisible();
  await expect(page.getByText('Showing the first 500 of 10,914 documents, in volume order.')).toBeVisible();
  await expect(page.getByRole('link', { name: telegram })).toHaveCount(0);
  await axeCheck(page);

  // Show more, by keyboard, the button keeping the keyboard, till the first 8,000 hold frus1961-63v06's documents.
  const more = page.getByRole('button', { name: 'Show more' });
  await tabTo(page, more);
  for (let shown = 1_000; shown <= 8_000; shown += 500) {
    await page.keyboard.press('Enter');
    await expect(page.getByText(`Showing the first ${shown.toLocaleString('en-US')} of 10,914 documents, in volume order.`)).toBeVisible();
    await expect(more).toBeFocused();
  }
  const opened = page.getByRole('link', { name: telegram });
  await expect(opened).toHaveAttribute('href', /\/doc\/frus1961-63v06\/d1$/);
  await backTabTo(page, opened, 100);
  await axeCheck(page);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/doc\/frus1961-63v06\/d1(\?|$)/);
  await expect(page.getByRole('heading', { level: 1, name: /1\. Telegram From the Embassy in the Soviet Union/ })).toBeVisible();

  // Back in the list as it was; See on the semantic map opens the map on the region's card, in its layout.
  await page.goBack();
  await expect(title).toBeFocused();
  await expect(page.getByText('Showing the first 8,000 of 10,914 documents, in volume order.')).toBeVisible();
  const map = page.getByRole('link', { name: 'See on the semantic map' });
  await tabTo(page, map);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/analytics\/semantic\?region=115&layout=/);
  const frame = page.locator('.semantic-map-frame');
  await expect(frame).toHaveAttribute('data-view', /^8\.333 /, { timeout: 60_000 });
  await expect(frame).toHaveAttribute('data-names', 'laid-out');
  await expect(page.getByRole('region', { name: 'Region', exact: true }).getByText('edc nato nuclear', { exact: true })).toBeVisible();
  await expect(page.getByRole('listbox', { name: 'Semantic map' }).getByRole('option', { selected: true })).toHaveText(/^edc nato nuclear, region/);
  await axeCheck(page);
});

test('saves a region as a working corpus, the app’s 7,500 of its documents, by keyboard', async ({ page }) => {
  await page.goto('browse/clusters/115');
  await expect(page.getByRole('heading', { level: 1, name: 'edc · nato · nuclear · soviet' })).toBeVisible();
  const save = page.getByRole('button', { name: 'Save as Working Corpus' });
  await tabTo(page, save);
  await page.keyboard.press('Enter');
  const saved = page.getByText(/^Saved “edc nato nuclear — .+” with the first 7,500 of 10,914 documents\.$/);
  await expect(saved).toBeVisible();
  await expect(saved).toHaveAttribute('role', 'status');
  await expect(save).toBeFocused();
  await axeCheck(page);
  const name = /^Saved “(.+)” with/.exec((await saved.textContent()) ?? '')?.[1] ?? '';

  // Working Corpora lists it: its name, its count, the browse it came from, and the kit's line for a capture cut short.
  await page.goto('browse/corpora');
  const row = page.getByRole('listitem').filter({ has: page.getByRole('link', { name: `${name}, 7,500 documents` }) });
  await expect(row.locator('.meta').first()).toHaveText(/^7,500 documents · Semantic cluster, browsed · /);
  await expect(row.locator('.meta.warning')).toBeVisible();
  await axeCheck(page);
  // Deleted, so that the suite's other specs find the corpora they make alone.
  await row.getByRole('link').click();
  await page.getByRole('button', { name: 'Delete Corpus' }).click();
  await page.getByRole('alertdialog', { name: 'Delete Working Corpus?' }).getByRole('button', { name: 'Delete' }).click();
  await expect(page).toHaveURL(/\/browse\/corpora$/);
  await expect(page.getByRole('link', { name: `${name}, 7,500 documents` })).toHaveCount(0);
});
