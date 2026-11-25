// S29f's done-when (docs/PLAN.md): Playwright sizes a cloud by Distinctive and reads a search's collocates by keyboard
// on Chromium with no axe violations. In the main suite, over the synthetic export, a volume the export holds four rows
// of is counted live under Distinctive, whose ranking the server gives, the kit's against the language family's
// reference: the cloud drawn by it, each word with its keyness, its multiple and its counts, and the app's caveat, by
// keyboard, Frequency bringing the family's list back. With FRUS_E2E_LANGUAGE, on the smoke test's Standalone server,
// whose index holds the three fixture volumes: a real volume's ranking read the same way, and a search's collocates
// chosen from the Reading picker by keyboard, its window widened and its order changed, and a neighbour's search opened,
// each list the server's, axe at each state. Each test sets back the reader's word cloud settings and this browser's
// measure, window and order.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { send } from './notes';

const standalone = !!process.env.FRUS_E2E_LANGUAGE;

/** Sets back the word cloud's criteria a reader who has set nothing has, every word the reader's lists hide, and what this browser keeps. */
async function reset(page: Page): Promise<void> {
  const held = (await page.evaluate(async () => {
    const response = await fetch(new URL('api/v1/me/preferences', document.baseURI), { headers: { Accept: 'application/json' } });
    return response.ok ? ((await response.json()) as { wordCloud: { globalStopwords: string[]; lensStopwords: Record<string, string[]> } }).wordCloud : undefined;
  })) ?? { globalStopwords: [], lensStopwords: {} };
  const words: { word: string; lens?: string }[] = [
    ...held.globalStopwords.map((word) => ({ word })),
    ...Object.entries(held.lensStopwords).flatMap(([lens, list]) => list.map((word) => ({ word, lens }))),
  ];
  for (const each of words) {
    const query = new URLSearchParams(each.lens ? { word: each.word, lens: each.lens } : { word: each.word });
    await send(page, 'DELETE', `api/v1/me/preferences/hidden-words?${query.toString()}`);
  }
  await send(page, 'PATCH', 'api/v1/me/preferences', {
    wordCloud: { minLength: 3, minCount: 1, foldPlurals: true, filterMarkings: true, excludeBoilerplate: true },
  });
  await page.evaluate(() => {
    for (const key of ['frus.wordcloud.measure', 'frus.search.collocation.window', 'frus.search.collocation.order']) localStorage.removeItem(key);
  });
}

/** What the server answers at `path`, as the page asks it. */
async function asked<T>(page: Page, path: string): Promise<T> {
  return page.evaluate(async (path) => {
    const response = await fetch(new URL(path, document.baseURI), { headers: { Accept: 'application/json' } });
    if (!response.ok) throw new Error(`${path}: ${response.status} ${await response.text()}`);
    return (await response.json()) as T;
  }, path);
}

/** Presses an arrow key on the focused radio of a group and waits for `next` to be the one chosen. */
async function arrowTo(page: Page, key: 'ArrowRight' | 'ArrowLeft', next: Locator): Promise<void> {
  await page.keyboard.press(key);
  await expect(next).toBeChecked();
  await expect(next).toBeFocused();
}

/** The words of the list a table names, rank by rank. */
async function listed(page: Page, name: string): Promise<string[]> {
  const table = page.getByRole('table', { name });
  await expect(table.locator('tbody tr').first()).toBeVisible();
  return table.locator('tbody tr .link-button').allTextContents();
}

/**
 * A cloud sized by Distinctive, by keyboard from Frequency: the server's ranking of the scope's count, drawn and listed,
 * with the app's caveat; then Frequency again.
 */
async function sizeByDistinctive(page: Page, scope: string): Promise<{ caveat?: string }> {
  await page.goto(`cloud?scope=${encodeURIComponent(scope)}`);
  await expect(page.getByRole('table', { name: 'Terms by count' })).toBeVisible();
  const frequency = page.getByRole('radio', { name: 'Frequency', exact: true });
  const distinctive = page.getByRole('radio', { name: 'Distinctive', exact: true });
  await tabTo(page, frequency, 60);
  await arrowTo(page, 'ArrowRight', distinctive);
  // The server's ranking, the kit's, word for word.
  const ranking = await asked<{ distinctive?: { state: string; scores: { term: string }[]; caveat?: string; countLine?: string } }>(
    page,
    `api/v1/cloud?scope=${encodeURIComponent(scope)}&lens=allTerms&measure=keyness`,
  );
  expect(ranking.distinctive?.state).toBe('ranked');
  const words = ranking.distinctive!.scores.map((score) => score.term);
  await expect.poll(() => listed(page, 'Terms by distinctiveness')).toEqual(words);
  await expect(page.getByRole('columnheader', { name: 'Keyness' })).toBeVisible();
  await expect(page.getByText(ranking.distinctive!.caveat!, { exact: true })).toBeVisible();
  await expect(page.getByText(ranking.distinctive!.countLine!, { exact: true })).toBeVisible();
  // The cloud is sized by the ranking, each word's title its word alone, never a count.
  const canvas = page.getByRole('img', { name: /each sized by how distinctive it is of this scope/ });
  await expect(canvas.locator('text').first()).toBeVisible();
  // A word's numbers are read with it: its keyness, its multiple and its counts, the app's reading.
  const first = page.getByRole('table', { name: 'Terms by distinctiveness' }).getByRole('button', { name: words[0], exact: true });
  await expect(first).toHaveAccessibleDescription(/^keyness [\d,.]+; [\d,.]+× more often here; [\d,]+ here · /);
  await expect(page.getByRole('heading', { level: 2, name: 'No Distinctiveness Ranking' })).toHaveCount(0);
  await axeCheck(page);
  // Kept in this browser, as the app's measure is.
  expect(await page.evaluate(() => localStorage.getItem('frus.wordcloud.measure'))).toBe('keyness');
  await arrowTo(page, 'ArrowLeft', frequency);
  await expect(page.getByRole('table', { name: 'Terms by count' })).toBeVisible();
  return ranking.distinctive!;
}

test('sizes a volume’s cloud by Distinctive by keyboard, the server’s ranking of its count', async ({ page }) => {
  test.skip(standalone, 'the Standalone server’s tests are below');
  test.setTimeout(90_000);
  await page.goto('search');
  await reset(page);
  try {
    // Four rows of the own-text volume, its minutes and its conference each three times: a ranking of two words.
    await sizeByDistinctive(page, 'vol:frus1969-76v01');
    await expect(page.getByRole('heading', { level: 2, name: /Volume I/ })).toBeVisible();
  } finally {
    await reset(page);
  }
});

test('sizes a fixture volume’s cloud by Distinctive by keyboard', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_LANGUAGE');
  test.setTimeout(120_000);
  await page.goto('search');
  await reset(page);
  try {
    const ranking = await sizeByDistinctive(page, 'vol:frus1961-63v06');
    // A volume's thousand words are a pool the limit cut, as the caveat says.
    expect(ranking.caveat).toMatch(/^Ranked among this scope’s 1000 most frequent words\. Words occurring fewer than \d+ times corpus-wide are unpriced/);
  } finally {
    await reset(page);
  }
});

interface Collocates {
  state: string;
  caveat?: string;
  items: { term: string }[];
  orders: Record<string, number[]>;
}

/** The neighbours the reading lists, in its order. */
async function neighbours(page: Page): Promise<string[]> {
  const list = page.getByRole('list', { name: 'Words near your matches' });
  await expect(list.getByRole('link').first()).toBeVisible();
  return list.getByRole('link').allTextContents();
}

test('reads a search’s collocates by keyboard, widens the window, ranks by Concentration and opens a neighbour’s search', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_LANGUAGE');
  test.setTimeout(120_000);
  await page.goto('search');
  await reset(page);
  try {
    await page.goto('search?keywords=Berlin');
    await expect(page.getByRole('list', { name: 'Results' }).getByRole('link').first()).toBeVisible();
    // The Reading picker's fourth, past the header, Search by, the box, the filters and the readings before it.
    const collocates = page.getByRole('group', { name: 'Reading' }).getByRole('button', { name: 'Collocates' });
    await tabTo(page, collocates, 100);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/reading=collocates/);
    const ten = await asked<Collocates>(page, 'api/v1/search/collocates?keywords=Berlin&window=10');
    expect(ten.state).toBe('ranked');
    await expect.poll(() => neighbours(page)).toEqual(ten.items.map((item) => item.term));
    await expect(page.getByText(ten.caveat!, { exact: true })).toBeVisible();
    // A neighbour is read with its numbers: its multiple and its two counts.
    const first = page.getByRole('list', { name: 'Words near your matches' }).getByRole('link').first();
    await expect(first).toHaveAccessibleDescription(/^[\d,.]+× more often here · [\d,]+ nearby · /);
    // The whole retained set, so no page to turn.
    await expect(page.getByRole('navigation', { name: 'Pages' })).toHaveCount(0);
    await axeCheck(page);

    // Within ±20 words, by keyboard: asked again.
    const twenty = page.getByRole('group', { name: 'Within' }).getByRole('button', { name: '±20 words' });
    await tabTo(page, twenty, 30);
    await page.keyboard.press('Enter');
    await expect(twenty).toHaveAttribute('aria-pressed', 'true');
    const wider = await asked<Collocates>(page, 'api/v1/search/collocates?keywords=Berlin&window=20');
    await expect.poll(() => neighbours(page)).toEqual(wider.items.map((item) => item.term));
    await axeCheck(page);

    // Rank by Concentration, by keyboard: the order the server gave for it, asking nothing again.
    const concentration = page.getByRole('group', { name: 'Rank by' }).getByRole('button', { name: 'Concentration' });
    await tabTo(page, concentration, 10);
    await page.keyboard.press('Enter');
    await expect(concentration).toHaveAttribute('aria-pressed', 'true');
    const effect = wider.orders.effect!.map((position) => wider.items[position]!.term);
    await expect.poll(() => neighbours(page)).toEqual(effect);
    expect(await page.evaluate(() => [localStorage.getItem('frus.search.collocation.window'), localStorage.getItem('frus.search.collocation.order')])).toEqual([
      '20',
      'effect',
    ]);
    await axeCheck(page);

    // A neighbour opens its own search.
    const neighbour = page.getByRole('list', { name: 'Words near your matches' }).getByRole('link').first();
    const term = (await neighbour.textContent()) ?? '';
    await tabTo(page, neighbour, 20);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(new RegExp(`search\\?keywords=${encodeURIComponent(term)}$`));
    await expect(page.getByRole('list', { name: 'Results' }).getByRole('link').first()).toBeVisible();
    await axeCheck(page);
  } finally {
    await reset(page);
  }
});
