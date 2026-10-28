// S17e's done-when (docs/PLAN.md, the same as S11c's): Playwright uses saved searches, working corpora,
// volume scopes and Checklist Mode, by keyboard, on Chromium with no axe violations. Against the image,
// with the synthetic export imported (frus1961-63v06's d1 and d2, and frus1894Nicaragua's d1), and the
// single user's store, which starts with none of the three. Each test leaves the store as it found it,
// since the suite runs twice on one store.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { treatiesResults } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';
import { getJSON, removeNotesAndSummaries, send } from './notes';

const nicaraguaNotes = 'api/v1/me/volumes/frus1894Nicaragua/documents/d1/notes';

async function removeAll(page: Page, path: string): Promise<void> {
  const list = await getJSON<{ items: { id: string }[] }>(page, path);
  for (const item of list.items) await send(page, 'DELETE', `${path}/${item.id}`);
}

test('saves a search, recalls it, and says what it has gained since, by keyboard alone', async ({ page }) => {
  await page.goto('search?keywords=treaties');
  const titles = page.getByRole('list', { name: 'Results' }).getByRole('heading');
  await expect(titles).toHaveText(treatiesResults);
  try {
    // Save this search: the sheet offers the words as the name, and Return saves it.
    const save = page.getByRole('button', { name: 'Save this search' });
    await tabTo(page, save);
    await page.keyboard.press('Enter');
    const sheet = page.getByRole('dialog', { name: 'Save Search' });
    const name = sheet.getByRole('textbox', { name: 'Name' });
    await expect(name).toBeFocused();
    await expect(name).toHaveValue('treaties');
    await axeCheck(page);
    await page.keyboard.type(' talks');
    await page.keyboard.press('Enter');
    await expect(sheet).toHaveCount(0);
    await expect(save).toBeFocused();

    // Recalled from another search: the search is the saved one's, and its run is stamped from its count.
    await page.goto('search?keywords=canal');
    await expect(titles).toHaveCount(1);
    const open = page.getByRole('button', { name: 'Saved searches' });
    await tabTo(page, open);
    await page.keyboard.press('Enter');
    const list = page.getByRole('dialog', { name: 'Saved Searches' });
    await expect(list.getByRole('heading', { name: 'Saved Searches' })).toBeFocused();
    const row = list.getByRole('button', { name: /^treaties talks/ });
    await expect(row).toBeVisible();
    await axeCheck(page);
    await tabTo(page, row);
    await page.keyboard.press('Enter');
    await expect(list).toHaveCount(0);
    await expect(page).toHaveURL(/[?&]keywords=treaties(&|$)/);
    await expect(titles).toHaveText(treatiesResults);
    await expect
      .poll(async () => (await getJSON<{ items: { matchCountAtLastRun?: number }[] }>(page, 'api/v1/me/saved-searches')).items[0]?.matchCountAtLastRun)
      .toBe(2);

    // A note with the word on another document: the saved search matches one more than at its run.
    await send(page, 'POST', nicaraguaNotes, { bodyText: 'Treaties with the canal company', runs: null, userTagIds: [], projectIds: [], selectedSummaryIds: [] });
    await tabTo(page, open);
    await page.keyboard.press('Enter');
    await expect(list.getByText('+1 since last run')).toBeVisible();
    await expect(list.getByText('NEW', { exact: true })).toBeVisible();
    await axeCheck(page);

    // Rename, as given, and Delete, from the row.
    await tabTo(page, list.getByRole('button', { name: 'Rename treaties talks' }));
    await page.keyboard.press('Enter');
    const field = list.getByRole('textbox', { name: 'Rename' });
    await expect(field).toBeFocused();
    await page.keyboard.press('ControlOrMeta+a');
    await page.keyboard.type('Treaties');
    await page.keyboard.press('Enter');
    const rename = list.getByRole('button', { name: 'Rename Treaties' });
    await expect(rename).toBeFocused();
    await tabTo(page, list.getByRole('button', { name: 'Delete Treaties' }));
    await page.keyboard.press('Enter');
    await expect(list.getByText('No Saved Searches')).toBeVisible();
    await expect(list.getByRole('heading', { name: 'Saved Searches' })).toBeFocused();
    await page.keyboard.press('Escape');
    await expect(list).toHaveCount(0);
    await expect(open).toBeFocused();
  } finally {
    await removeAll(page, 'api/v1/me/saved-searches');
    await removeNotesAndSummaries(page);
  }
});

test('saves the rows a search shows as a working corpus, opens it in Browse, and searches inside it, by keyboard alone', async ({ page }) => {
  await page.goto('search?keywords=treaties');
  const titles = page.getByRole('list', { name: 'Results' }).getByRole('heading');
  await expect(titles).toHaveText(treatiesResults);
  try {
    const save = page.getByRole('button', { name: 'Save as Working Corpus…' });
    await tabTo(page, save, 60);
    await page.keyboard.press('Enter');
    const sheet = page.getByRole('dialog', { name: 'Save Working Corpus' });
    await expect(sheet.getByRole('textbox', { name: 'Name' })).toBeFocused();
    await expect(sheet.locator('dt', { hasText: 'Documents' }).locator('+ dd')).toHaveText('2');
    await expect(sheet.locator('dt', { hasText: 'From' }).locator('+ dd')).toHaveText('treaties');
    await axeCheck(page);
    await page.keyboard.type('Treaty talks');
    await page.keyboard.press('Enter');
    await expect(sheet).toHaveCount(0);
    await expect(save).toBeFocused();

    // Browse's Working Corpora lists it, and opens it by volume.
    await page.goto('browse/corpora');
    const corpus = page.getByRole('link', { name: 'Treaty talks, 2 documents' });
    await expect(corpus).toBeVisible();
    await axeCheck(page);
    await tabTo(page, corpus);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('heading', { level: 1, name: 'Treaty talks' })).toBeVisible();
    await expect(page.getByText('2 of 2 documents indexed on this server')).toBeVisible();
    const documents = page.getByRole('region', { name: 'Kennedy-Khrushchev Exchanges' }).getByRole('link');
    await expect(documents).toHaveText(treatiesResults);
    await axeCheck(page);

    // In Search, applied from My Working Corpora: a search inside it finds only its documents.
    await page.goto('search?keywords=treaties+OR+canal');
    await expect(titles).toHaveCount(3);
    const corpora = page.locator('details.corpus-filter > summary');
    await tabTo(page, corpora, 60);
    await page.keyboard.press('Enter');
    const apply = page.getByRole('button', { name: /^Treaty talks/ });
    await tabTo(page, apply);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/[?&]workingCorpusId=[0-9A-F-]{36}(&|$)/);
    await expect(titles).toHaveText(treatiesResults);
    const banner = page.getByRole('group', { name: 'My Working Corpora' });
    await expect(banner).toContainText('Inside “Treaty talks”');
    await axeCheck(page);
    const leave = banner.getByRole('button', { name: 'Leave this working corpus' });
    await tabTo(page, leave);
    await page.keyboard.press('Enter');
    await expect(page).not.toHaveURL(/workingCorpusId=/);
    await expect(titles).toHaveCount(3);
  } finally {
    await removeAll(page, 'api/v1/me/working-corpora');
  }
});

test('makes a scope in My Scopes, gives it a volume, and fills a search’s volume filter with it, by keyboard alone', async ({ page }) => {
  await page.goto('browse/scopes');
  try {
    await expect(page.getByText('No Scopes Yet')).toBeVisible();
    await axeCheck(page);
    const create = page.getByRole('button', { name: 'New Scope' });
    await tabTo(page, create);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('heading', { level: 1, name: 'Edit Scope' })).toBeVisible();
    const name = page.getByRole('textbox', { name: 'Name' });
    await tabTo(page, name);
    await page.keyboard.type('Isthmus');
    await page.keyboard.press('Enter');
    const add = page.getByRole('button', { name: 'Add Volumes…' });
    await tabTo(page, add);
    await page.keyboard.press('Enter');
    const picker = page.getByRole('dialog', { name: 'Add Volumes' });
    await expect(picker.getByRole('searchbox')).toBeFocused();
    await page.keyboard.type('frus1894Nicaragua');
    const nicaragua = picker.getByRole('checkbox');
    await expect(nicaragua).toHaveCount(1);
    await axeCheck(page);
    await tabTo(page, nicaragua);
    await page.keyboard.press('Space');
    await tabTo(page, picker.getByRole('button', { name: 'Done' }));
    await page.keyboard.press('Enter');
    await expect(picker).toHaveCount(0);
    await expect(add).toBeFocused();
    await expect(page.getByRole('heading', { name: 'Volumes (1)' })).toBeVisible();
    await axeCheck(page);

    // In Search, My Volume Scopes fills the volume filter with the scope's indexed volume.
    await page.goto('search?keywords=treaties+OR+canal');
    const titles = page.getByRole('list', { name: 'Results' }).getByRole('heading');
    await expect(titles).toHaveCount(3);
    const scopes = page.locator('details.scope-filter > summary');
    await tabTo(page, scopes, 60);
    await page.keyboard.press('Enter');
    const isthmus = page.getByRole('button', { name: /^Isthmus/ });
    await expect(isthmus).toContainText('1 of 1 volumes indexed');
    await tabTo(page, isthmus);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/[?&]volumeIds=frus1894Nicaragua(&|$)/);
    await expect(titles).toHaveText(['No. 1. Mr. Baker to Mr. Gresham']);
    await axeCheck(page);
  } finally {
    await removeAll(page, 'api/v1/me/volume-scopes');
  }
});

test('hides results reviewed in Checklist Mode, marked or opened, and brings a page back with Undo, by keyboard alone', async ({ page }) => {
  await page.goto('search?keywords=treaties');
  const titles = page.getByRole('list', { name: 'Results' }).getByRole('heading');
  await expect(titles).toHaveText(treatiesResults);
  const toggle = page.getByRole('button', { name: 'Checklist Mode' });
  await tabTo(page, toggle, 60);
  await page.keyboard.press('Enter');
  await expect(toggle).toHaveAttribute('aria-pressed', 'true');
  const strip = page.getByRole('group', { name: 'Checklist Mode' });
  await expect(strip).toContainText('Nothing hidden');
  await axeCheck(page);

  // One marked by its row: it leaves the list, and the strip counts it.
  await tabTo(page, page.getByRole('button', { name: `Mark Reviewed: ${treatiesResults[0]}` }));
  await page.keyboard.press('Enter');
  await expect(strip).toContainText('1 reviewed hidden');
  await expect(titles).toHaveText([treatiesResults[1]!]);

  // The page at a stroke, then Undo, which brings back that stroke's alone.
  await tabTo(page, strip.getByRole('button', { name: 'Mark Page Reviewed' }), 60, 'Shift+Tab');
  await page.keyboard.press('Enter');
  await expect(strip).toContainText('2 reviewed hidden');
  await expect(page.getByText('All Results Reviewed')).toBeVisible();
  await expect(strip.getByRole('status')).toHaveText('1 result marked reviewed');
  await axeCheck(page);
  await page.keyboard.press('Shift+Tab');
  await expect(strip.getByRole('button', { name: 'Undo' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(strip.getByRole('status')).toHaveText('1 result is back in the list');
  await expect(titles).toHaveText([treatiesResults[1]!]);

  // A document opened while the mode is on leaves the list too, once the reader is back.
  await tabTo(page, titles.getByRole('link', { name: treatiesResults[1] }));
  await page.keyboard.press('Enter');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(treatiesResults[1]!);
  await page.goBack();
  await expect(page.getByText('All Results Reviewed')).toBeVisible();
  await expect(strip).toContainText('2 reviewed hidden');

  // Off, every result again.
  await tabTo(page, toggle, 60);
  await page.keyboard.press('Enter');
  await expect(strip).toHaveCount(0);
  await expect(titles).toHaveText(treatiesResults);
});
