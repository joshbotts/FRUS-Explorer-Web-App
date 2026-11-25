// S27d's done-when (docs/PLAN.md): Playwright asks a question by keyboard, opens a hit and saves the results as a
// corpus, on Chromium with no axe violations. Against the image, its encoder and every semantic vector in it, with the
// synthetic export imported (frus1961-63v06's d1 and d2, and frus1894Nicaragua's d1): a question of the whole series
// finds its nearest documents mostly in volumes this server does not serve, which are listed apart under the rows; a
// question inside a working corpus of the two documents that mention treaties ranks both. Each test removes the corpora
// it made, and nothing else, since the suite runs twice on one store.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { treatiesResults } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, send } from './notes';

interface Corpus {
  id: string;
  name: string;
  documentCount: number;
  isMeaningCapture: boolean;
  truncationLine?: string;
}

/** Removes the user's working corpora named `name`, those a test made. */
async function removeCorpora(page: Page, name: string): Promise<void> {
  const list = await getJSON<{ items: Corpus[] }>(page, 'api/v1/me/working-corpora');
  for (const corpus of list.items) if (corpus.name === name) await send(page, 'DELETE', `api/v1/me/working-corpora/${corpus.id}`);
}

test('a question of the whole series lists the hits this server does not serve apart, with no download to offer', async ({ page }) => {
  await page.goto('search?keywords=the%20Soviet%20note%20on%20Berlin&by=meaning');
  const strip = page.getByRole('region', { name: 'About this Meaning search' });
  // The first search by meaning starts the encoder.
  await expect(strip).toContainText('Meaning search (experimental): ranked by what your question means, across the whole series', {
    timeout: 60_000,
  });
  const beyond = page.getByRole('region', { name: /^In volumes this server does not serve \(\d+\)$/ });
  await expect(beyond).toBeVisible();
  await expect(beyond.getByRole('link').first()).toHaveText(/^Document \S+ in .+/);
  await expect(beyond.getByText('Volume not on this server — its documents are shown without titles.').first()).toBeVisible();
  await expect(page.getByRole('button', { name: /Download/ })).toHaveCount(0);
  // The keyword surfaces wait for Keywords.
  await expect(page.locator('.query-inspector')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Facets' })).toHaveCount(0);
  await axeCheck(page);
});

test('asks a question by keyboard inside a corpus, opens a hit, and saves the closest matches as a corpus', async ({ page }) => {
  await page.goto('search');
  const treaties = (await send(page, 'POST', 'api/v1/me/working-corpora', { name: 'S27d treaties', search: 'keywords=treaties' })) as Corpus;
  try {
    await page.goto(`search?workingCorpusId=${treaties.id}`);
    // Search by, Keywords then Meaning, by an arrow key, as a group of radio buttons is chosen.
    const searchBy = page.getByRole('group', { name: 'Search by' });
    const keywords = searchBy.getByRole('radio', { name: 'Keywords' });
    await expect(keywords).toBeChecked();
    await tabTo(page, keywords);
    await page.keyboard.press('ArrowRight');
    await expect(searchBy.getByRole('radio', { name: 'Meaning' })).toBeChecked();
    await expect(page).toHaveURL(/[?&]by=meaning(&|$)/);
    const box = page.getByRole('searchbox', { name: 'Search the documents' });
    await expect(box).toHaveAttribute('placeholder', 'A question in your own words…');
    await tabTo(page, box);
    await page.keyboard.type('the Soviet note on Berlin');
    await page.keyboard.press('Enter');

    // Every member of the corpus ranked, each with the kit's chip, under the strip that says where it ranked.
    const results = page.getByRole('list', { name: 'Results' });
    await expect(results.getByRole('heading')).toHaveCount(2, { timeout: 60_000 });
    await expect(page.getByRole('status').filter({ hasText: 'closest matches' })).toContainText('2 closest matches');
    for (const title of treatiesResults) await expect(results.getByRole('link', { name: title })).toBeVisible();
    await expect(results.locator('.semantic-chip')).toHaveText([/^Semantic match · \d+%$/, /^Semantic match · \d+%$/]);
    await expect(page.getByRole('region', { name: 'About this Meaning search' })).toContainText(
      'inside the 2 documents you are searching within',
    );
    await axeCheck(page);

    // A hit opened by keyboard, and the list back.
    const first = results.getByRole('link').first();
    const title = (await first.textContent()) ?? '';
    await tabTo(page, first, 80);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d[12]$/);
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(title);
    await page.goBack();
    await expect(results.getByRole('heading')).toHaveCount(2);

    // The closest matches saved as a working corpus, as the app captures a Meaning search's list.
    const save = page.getByRole('button', { name: 'Save as Working Corpus…' });
    await tabTo(page, save, 80);
    await page.keyboard.press('Enter');
    const sheet = page.getByRole('dialog', { name: 'Save Working Corpus' });
    const name = sheet.getByRole('textbox', { name: 'Name' });
    await expect(name).toBeFocused();
    await expect(
      sheet.getByText(
        'These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.',
      ),
    ).toBeVisible();
    await axeCheck(page);
    await page.keyboard.type('S27d closest');
    await page.keyboard.press('Enter');
    await expect(sheet).toHaveCount(0);
    const saved = (await getJSON<{ items: Corpus[] }>(page, 'api/v1/me/working-corpora')).items.find((corpus) => corpus.name === 'S27d closest');
    expect(saved).toMatchObject({ documentCount: 2, isMeaningCapture: true, truncationLine: 'The 2 closest matches of a Meaning search' });
  } finally {
    await removeCorpora(page, 'S27d closest');
    await removeCorpora(page, 'S27d treaties');
  }
});
