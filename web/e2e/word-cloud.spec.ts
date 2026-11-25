// S24i's and S29e's done-when (docs/PLAN.md): Playwright changes the lens by keyboard on Chromium, with no axe violations,
// and since S29e opens a document's cloud from the reader's rail and changes the lens and a setting by keyboard. Against
// the image with the synthetic export imported; the corpus, a subseries and a volume are the language family's clouds
// (S29d) at the family's settings, and every other scope, or any of them under other settings, is counted live from the
// served index. The Word Cloud opens from the header's Analytics menu, after Chronology, on the corpus: the lens is
// changed by the lens bar's arrow keys, an entity lens saying why the server draws none, the list read back after each,
// the scope changed to a volume, and Distinctive refused with its reason; a word hidden in this lens by its menu leaves a
// volume's cloud the index holds none of and is shown again from Settings ▸ Word Cloud; the reader's rail opens its
// document's own cloud, counted live, whose lens and diplomatic layer are changed by keyboard, and the corpus is then
// counted as a job the page follows; Chronology opens its range's cloud; and Search offers Collocates refused, axe at each
// state. Each test sets back the reader's word cloud settings and this browser's measure.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';
import { send } from './notes';

/**
 * Sets back the word cloud's criteria a reader who has set nothing has, the words `hidden` names and every other word the
 * reader's lists hold, and the measure. Since S29e any hidden word makes a cloud of the corpus a count of the index, where
 * the family's list answers at the family's settings, and the smoke test's research import leaves the owner one
 * ("telegram"), which S24i's filtered lists never showed, the diplomatic layer having left it out of them.
 */
async function reset(page: Page, hidden: { word: string; lens?: string }[] = []): Promise<void> {
  const held = (await page.evaluate(async () => {
    const response = await fetch(new URL('api/v1/me/preferences', document.baseURI), { headers: { Accept: 'application/json' } });
    return (await response.json()) as { wordCloud: { globalStopwords: string[]; lensStopwords: Record<string, string[]> } };
  })).wordCloud;
  const words: { word: string; lens?: string }[] = [
    ...hidden,
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
  await page.evaluate(() => localStorage.removeItem('frus.wordcloud.measure'));
}

/** The list's words, rank by rank. */
async function terms(page: Page): Promise<string[]> {
  const table = page.getByRole('table', { name: 'Terms by count' });
  await expect(table.locator('tbody tr').first()).toBeVisible();
  return table.locator('tbody tr td:nth-child(2)').allTextContents();
}

/** Presses an arrow key on the focused radio of a group and waits for `next` to be the one chosen. */
async function arrowTo(page: Page, key: 'ArrowRight' | 'ArrowLeft', next: Locator): Promise<void> {
  await page.keyboard.press(key);
  await expect(next).toBeChecked();
  await expect(next).toBeFocused();
}

/** The lens bar's radio of a lens, by its label. */
function lens(page: Page, label: string): Locator {
  return page.getByRole('group', { name: 'Show' }).getByRole('radio', { name: label, exact: true });
}

const unavailable = 'This server’s tagger does not recognize names, so the “People” lens can’t be drawn. All terms, Topics (nouns), Actions (verbs), Descriptors (adjectives), Concepts, and Sentiment still work.';

test('changes the lens by keyboard and reads the list, then the scope, and refuses Distinctive with its reason', async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('search');
  await reset(page);
  try {
    // The header's Analytics menu, by keyboard: End reaches About the Series, and the item before it is the Word Cloud.
    const menu = page.getByRole('navigation', { name: 'Main' }).getByRole('button', { name: 'Analytics' });
    await tabTo(page, menu);
    await page.keyboard.press('Enter');
    await page.keyboard.press('End');
    await page.keyboard.press('ArrowUp');
    await expect(page.getByRole('menuitem', { name: 'Word Cloud' })).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/cloud$/);
    await expect(page.getByRole('heading', { level: 1, name: 'Word Cloud' })).toBeFocused();
    await expect(page.getByRole('heading', { level: 2, name: 'Entire Corpus' })).toBeVisible();
    await expect(page.getByText('50 terms', { exact: true })).toBeVisible();
    expect((await terms(page)).slice(0, 5)).toEqual(['united', 'say', 'president', 'soviet', 'take']);
    await expect(page.locator('.cloud-chip')).toHaveText('All terms');
    await expect(page.getByRole('img', { name: /^Word cloud of \d+ of 50 terms/ }).locator('text').first()).toBeVisible();
    await axeCheck(page);

    // The lens, by keyboard: All terms first, then People, which the server's tagger cannot draw, then on to Actions.
    await tabTo(page, lens(page, 'All terms'));
    await expect(lens(page, 'All terms')).toBeChecked();
    await arrowTo(page, 'ArrowRight', lens(page, 'People'));
    await expect(page).toHaveURL(/lens=people/);
    await expect(page.getByRole('heading', { level: 2, name: 'Lens Unavailable on This Server' })).toBeVisible();
    await expect(page.getByText(unavailable)).toBeVisible();
    await expect(page.getByRole('table', { name: 'Terms by count' })).toHaveCount(0);
    await axeCheck(page);
    for (const next of ['Places', 'Organizations', 'Topics (nouns)']) await arrowTo(page, 'ArrowRight', lens(page, next));
    await arrowTo(page, 'ArrowRight', lens(page, 'Actions (verbs)'));
    await expect(page).toHaveURL(/lens=actions/);
    await expect.poll(async () => (await terms(page)).slice(0, 3)).toEqual(['say', 'take', 'give']);
    await expect(page.locator('.cloud-chip')).toHaveText('Actions');
    await axeCheck(page);
    for (const next of ['Descriptors (adjectives)', 'Concepts']) await arrowTo(page, 'ArrowRight', lens(page, next));
    await arrowTo(page, 'ArrowRight', lens(page, 'Sentiment'));
    await expect(page).toHaveURL(/lens=sentiment/);
    await expect.poll(async () => (await terms(page)).slice(0, 3)).toEqual(['agreement', 'war', 'problem']);
    await expect(page.getByRole('columnheader', { name: 'Polarity' })).toBeVisible();
    await expect(page.locator('.cloud-legend')).toContainText('Positive');
    await axeCheck(page);

    // The scope, by keyboard: a volume's own cloud, under the lens chosen. The scope bar comes before the lens bar.
    const scope = page.getByRole('combobox', { name: 'Scope' });
    await backTabTo(page, scope);
    await scope.selectOption('vol:frus1961-63v06');
    await expect(page).toHaveURL(/scope=vol(%3A|:)frus1961-63v06/);
    await expect(page.getByRole('heading', { level: 2, name: /Volume VI, Kennedy-Khrushchev Exchanges/ })).toBeVisible();
    await expect.poll(async () => (await terms(page)).slice(0, 3)).toEqual(['agreement', 'peace', 'agree']);
    await axeCheck(page);

    // Distinctive, by keyboard: refused with its reason, the cloud and its list set aside, Frequency bringing them back.
    const frequency = page.getByRole('radio', { name: 'Frequency', exact: true });
    await tabTo(page, frequency);
    await arrowTo(page, 'ArrowRight', page.getByRole('radio', { name: 'Distinctive', exact: true }));
    await expect(page.getByRole('heading', { level: 2, name: 'No Distinctiveness Ranking' })).toBeVisible();
    await expect(page.getByText(/which this server does not rank them against yet/)).toBeVisible();
    await expect(page.getByRole('table', { name: 'Terms by count' })).toHaveCount(0);
    await axeCheck(page);
    await arrowTo(page, 'ArrowLeft', frequency);
    await expect(page.getByRole('table', { name: 'Terms by count' })).toBeVisible();
  } finally {
    await reset(page);
  }
});

test('hides a word in this lens from its menu, and shows it again from Settings ▸ Word Cloud', async ({ page }) => {
  test.setTimeout(90_000);
  // A volume the synthetic export holds no document of, whose family's list a hidden word is taken out of.
  const address = 'cloud?scope=vol%3Afrus1969-76ve09p1&lens=concepts';
  await page.goto(address);
  await reset(page, [{ word: 'policy', lens: 'concepts' }]);
  try {
    await page.reload();
    await expect.poll(async () => (await terms(page))[0]).toBe('policy');
    const more = page.getByRole('button', { name: 'More for policy' });
    await tabTo(page, more);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Analyze in Corpus Analytics' })).toBeFocused();
    await page.keyboard.press('End');
    await page.keyboard.press('ArrowUp');
    await expect(page.getByRole('menuitem', { name: 'Hide this word in this lens' })).toBeFocused();
    await page.keyboard.press('Enter');
    // The word leaves the cloud, and the keyboard goes to the word in its place.
    await expect(page.getByRole('button', { name: 'policy', exact: true })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'interest', exact: true })).toBeFocused();
    await expect(page.getByText('Your settings took one word out of this list of 50.')).toBeVisible();
    await expect.poll(async () => (await terms(page))[0]).toBe('interest');
    await axeCheck(page);

    // Settings ▸ Word Cloud: the lens's list holds it, and Remove shows it again.
    await page.goto('settings/word-cloud');
    await expect(page.getByRole('heading', { level: 1, name: 'Word Cloud' })).toBeVisible();
    await expect(page.getByText(/^Keeps \d+ of 23 terms in this sample$/)).toBeVisible();
    const appliesTo = page.getByRole('combobox', { name: 'Applies to' });
    await tabTo(page, appliesTo);
    await appliesTo.selectOption('concepts');
    const remove = page.getByRole('button', { name: 'Remove policy' });
    await expect(remove).toBeVisible();
    await axeCheck(page);
    await tabTo(page, remove);
    await page.keyboard.press('Enter');
    await expect(remove).toHaveCount(0);
    await expect(page.getByText('No custom words yet.')).toBeVisible();
    await page.goto(address);
    await expect.poll(async () => (await terms(page))[0]).toBe('policy');
  } finally {
    await reset(page, [{ word: 'policy', lens: 'concepts' }]);
  }
});

test('opens its document’s own cloud from the reader’s rail, and changes the lens and a setting by keyboard', async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('doc/frus1961-63v06/d1');
  await reset(page);
  try {
    const tile = page.getByRole('link', { name: 'Word Cloud', exact: true });
    await tabTo(page, tile);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/cloud\?scope=doc(%3A|:)frus1961-63v06(%2F|\/)d1$/);
    await expect(page.getByRole('heading', { level: 2, name: /Volume VI, Kennedy-Khrushchev Exchanges/ })).toBeVisible();
    // "The ambassador was negotiating treaties with the minister.": the diplomatic layer leaves the ambassador and the
    // minister out, as it does at the app's own settings.
    await expect.poll(async () => terms(page)).toEqual(['negotiate', 'treaty']);
    await expect(page.getByText('2 terms from 1 document', { exact: true })).toBeVisible();
    await expect(page.getByText(/This cloud was counted from its scope’s 1 document by this server’s own tagger, FRUSLanguage /)).toBeVisible();
    await expect(page.getByRole('link', { name: 'Back to the document' })).toBeVisible();
    await axeCheck(page);

    // The lens, by keyboard: People unavailable, then Topics, the document's nouns.
    await tabTo(page, lens(page, 'All terms'));
    await arrowTo(page, 'ArrowRight', lens(page, 'People'));
    await expect(page.getByText(unavailable)).toBeVisible();
    await axeCheck(page);
    for (const next of ['Places', 'Organizations']) await arrowTo(page, 'ArrowRight', lens(page, next));
    await arrowTo(page, 'ArrowRight', lens(page, 'Topics (nouns)'));
    await expect.poll(async () => terms(page)).toEqual(['treaty']);
    await axeCheck(page);

    // A setting, by keyboard: Hide common diplomatic words off counts the document again with the ambassador and the minister.
    const boilerplate = page.getByRole('checkbox', { name: 'Hide common diplomatic words' });
    await tabTo(page, boilerplate);
    await expect(boilerplate).toBeChecked();
    await page.keyboard.press('Space');
    await expect(boilerplate).not.toBeChecked();
    await expect.poll(async () => terms(page)).toEqual(['ambassador', 'minister', 'treaty']);
    await expect(page.getByText(/This cloud was counted from its scope’s 1 document by this server’s own tagger, .* under your settings\./)).toBeVisible();
    await axeCheck(page);

    // Under these settings the corpus is counted, as a job the page follows until it ends.
    const scope = page.getByRole('combobox', { name: 'Scope' });
    await backTabTo(page, scope);
    await scope.selectOption('corpus');
    await expect(page.getByRole('heading', { level: 2, name: 'Entire Corpus' })).toBeVisible();
    // The synthetic export the smoke test imports holds seven documents: the fixtures' three and the own-text volume's four.
    await expect(page.getByText(/^\d+ terms? from 7 documents$/)).toBeVisible({ timeout: 20_000 });
    await expect.poll(async () => terms(page)).toContain('ambassador');
    await axeCheck(page);
  } finally {
    await reset(page);
  }
});

test('Chronology opens its range’s cloud, and Search offers Collocates refused', async ({ page }) => {
  test.setTimeout(60_000);
  await page.goto('chronology?from=1960-11-01&to=1960-11-30');
  await reset(page);
  try {
    const link = page.getByRole('link', { name: 'Word Cloud for this range' });
    await tabTo(page, link, 60);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/cloud\?scope=daterange(%3A|:)1960-11-\d\d\.\.1960-11-\d\d/);
    await expect(page.getByText(/^\d+ terms? from 2 documents$/)).toBeVisible();
    await expect(page.getByLabel('Range start')).toHaveValue(/^1960-11-\d\d$/);
    await expect(page.getByRole('link', { name: 'View in Chronology' })).toBeVisible();
    await axeCheck(page);

    // Search's Reading picker: Collocates, the Mac's fourth, in reach of the keyboard with its reason, choosing nothing.
    await page.goto('search?keywords=negotiating+OR+canal');
    await expect(page.getByRole('list', { name: 'Results' }).getByRole('link')).toHaveCount(3);
    const collocates = page.getByRole('group', { name: 'Reading' }).getByRole('button', { name: 'Collocates' });
    // Past the header, Search by (S27d), the box, the filters and the readings before it: more than sixty stops.
    await tabTo(page, collocates, 80);
    await expect(collocates).toHaveAttribute('aria-disabled', 'true');
    await expect(collocates).toHaveAccessibleDescription(/this server’s language analysis cannot do yet/);
    await page.keyboard.press('Enter');
    await expect(page).not.toHaveURL(/reading=/);
    await axeCheck(page);
  } finally {
    await reset(page);
  }
});
