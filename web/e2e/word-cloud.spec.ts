// S24i's done-when (docs/PLAN.md): Playwright changes the lens by keyboard on Chromium, with no axe violations. Against
// the image with the synthetic export imported; the Word Cloud reads the clouds bundled with the app, which need nothing
// indexed. It opens from the header's Analytics menu, after Chronology, on the corpus: the lens is changed by the lens
// bar's arrow keys and the list read back after each, the scope changed to a volume, and Distinctive refused with its
// reason; a word hidden in this lens by its menu leaves the cloud and is shown again from Settings ▸ Word Cloud; the
// reader's rail opens its document's volume's cloud, saying why; and Search offers Collocates refused, axe at each state.
// Each test sets back the reader's word cloud settings and this browser's measure.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';
import { send } from './notes';

/** Sets back the word cloud's criteria a reader who has set nothing has, the words `hidden` names, and the measure. */
async function reset(page: Page, hidden: { word: string; lens?: string }[] = []): Promise<void> {
  for (const each of hidden) {
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
    expect((await terms(page)).slice(0, 5)).toEqual(['united', 'president', 'country', 'time', 'agreement']);
    await expect(page.getByRole('img', { name: /^Word cloud of \d+ of 50 terms/ }).locator('text').first()).toBeVisible();
    await axeCheck(page);

    // The lens, by keyboard: the lens bar's arrow keys move from Topics to Actions, and on to Sentiment by Concepts.
    const topics = page.getByRole('radio', { name: 'Topics (nouns)', exact: true });
    await tabTo(page, topics);
    await expect(topics).toBeChecked();
    await arrowTo(page, 'ArrowRight', page.getByRole('radio', { name: 'Actions (verbs)', exact: true }));
    await expect(page).toHaveURL(/lens=actions/);
    await expect.poll(async () => (await terms(page)).slice(0, 3)).toEqual(['say', 'take', 'give']);
    await expect(page.locator('.cloud-chip')).toHaveText('Actions');
    await axeCheck(page);
    await arrowTo(page, 'ArrowRight', page.getByRole('radio', { name: 'Concepts', exact: true }));
    await arrowTo(page, 'ArrowRight', page.getByRole('radio', { name: 'Sentiment', exact: true }));
    await expect(page).toHaveURL(/lens=sentiment/);
    await expect.poll(async () => (await terms(page)).slice(0, 3)).toEqual(['agreement', 'war', 'agree']);
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
    await expect(page.getByText(/This server cannot count a scope’s words itself yet/)).toBeVisible();
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
  await page.goto('cloud?lens=concepts');
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
    await expect(page.getByRole('button', { name: 'war', exact: true })).toBeFocused();
    await expect(page.getByText('Your settings took one word out of this list of 50.')).toBeVisible();
    await expect.poll(async () => (await terms(page))[0]).toBe('war');
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
    await page.goto('cloud?lens=concepts');
    await expect.poll(async () => (await terms(page))[0]).toBe('policy');
  } finally {
    await reset(page, [{ word: 'policy', lens: 'concepts' }]);
  }
});

test('opens its document’s volume’s cloud from the reader’s rail, saying why, and Search offers Collocates refused', async ({ page }) => {
  test.setTimeout(60_000);
  await page.goto('doc/frus1961-63v06/d1');
  await reset(page);
  try {
    const tile = page.getByRole('link', { name: 'Word Cloud', exact: true });
    await tabTo(page, tile);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/cloud\?scope=doc(%3A|:)frus1961-63v06(%2F|\/)d1$/);
    await expect(page.getByText(/A document’s own word cloud is counted from its text/)).toBeVisible();
    await expect(page.getByRole('heading', { level: 2, name: /Volume VI, Kennedy-Khrushchev Exchanges/ })).toBeVisible();
    expect((await terms(page)).slice(0, 3)).toEqual(['president', 'country', 'soviet']);
    await axeCheck(page);
    await page.getByRole('link', { name: 'Back to the document' }).click();
    await expect(page).toHaveURL(/doc\/frus1961-63v06\/d1$/);

    // Search's Reading picker: Collocates, the Mac's fourth, in reach of the keyboard with its reason, choosing nothing.
    await page.goto('search?keywords=negotiating+OR+canal');
    await expect(page.getByRole('list', { name: 'Results' }).getByRole('link')).toHaveCount(3);
    const collocates = page.getByRole('group', { name: 'Reading' }).getByRole('button', { name: 'Collocates' });
    await tabTo(page, collocates, 60);
    await expect(collocates).toHaveAttribute('aria-disabled', 'true');
    await expect(collocates).toHaveAccessibleDescription(/this server’s language analysis cannot do yet/);
    await page.keyboard.press('Enter');
    await expect(page).not.toHaveURL(/reading=/);
    await axeCheck(page);
  } finally {
    await reset(page);
  }
});
