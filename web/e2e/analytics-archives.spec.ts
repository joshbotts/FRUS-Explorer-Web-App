// S24h's done-when (docs/PLAN.md): Playwright changes a control by keyboard and reads the table, on Chromium, with no axe
// violations. Against the image with the synthetic export imported; every surface here but Your Library reads the bundled
// data, which needs nothing indexed. Archival Analytics opens from the header's Analytics menu: the Collections ranking's
// era and unit are changed by keyboard, each read back from the table beside the chart, and its CSV carries the kit's
// method block; the Network's list box is walked by keyboard, a partner shown in the dock and closed; the Flows and Your
// Library modes are opened by keyboard. About the Series opens from the same menu: its pages are reached by keyboard,
// Geographic Emphasis's table read, and Administration Profiles' editorial notes turned on by keyboard and read back.
import { readFile } from 'node:fs/promises';
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

/** Leaves the unit, the weight and the link strength as this browser kept them. */
async function forget(page: Page): Promise<void> {
  await page.evaluate(() => {
    for (const key of ['frus.archivalAnalytics.unitLens', 'frus.archivalAnalytics.weight', 'frus.archivalAnalytics.edgeMeasure']) localStorage.removeItem(key);
  });
}

/** A table's header and rows, as text. */
async function rows(table: Locator): Promise<string[][]> {
  await expect(table.locator('tr').first()).toBeVisible();
  return table
    .locator('tr')
    .evaluateAll((elements) => elements.map((row) => [...row.querySelectorAll('th, td')].map((cell) => (cell.textContent ?? '').trim())));
}

/** Opens an item of the header's Analytics menu by keyboard: `steps` presses of ArrowDown, or End for the last. */
async function openFromMenu(page: Page, item: string, steps: number | 'end'): Promise<void> {
  const menu = page.getByRole('navigation', { name: 'Main' }).getByRole('button', { name: 'Analytics' });
  await tabTo(page, menu);
  await page.keyboard.press('Enter');
  if (steps === 'end') await page.keyboard.press('End');
  else for (let step = 0; step < steps; step += 1) await page.keyboard.press('ArrowDown');
  await expect(page.getByRole('menuitem', { name: item })).toBeFocused();
  await page.keyboard.press('Enter');
}

test('changes the era and the unit by keyboard and reads the ranking, then walks the network and opens the other modes', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('search');
  await forget(page);
  try {
    await openFromMenu(page, 'Archival Analytics', 3);
    await expect(page).toHaveURL(/analytics\/archives$/);
    await expect(page.getByRole('heading', { level: 1, name: 'Archival Analytics' })).toBeFocused();
    await expect(page.getByRole('heading', { level: 2, name: 'Top collections by era' })).toBeVisible();
    const ranking = page.getByRole('table', { name: 'Top collections by era' });
    const before = await rows(ranking);
    expect(before[0]).toEqual(['Archival unit', 'Custodian', 'Documents']);
    expect(before).toHaveLength(13);
    await expect(page.getByText(/ in 1948–1960\. The 12 rows below account for /)).toBeVisible();
    await expect(page.getByRole('img', { name: 'Top collections by era. The table beside the chart lists its numbers.' }).locator('svg')).toBeVisible();
    await axeCheck(page);

    // The era, by keyboard: ArrowDown moves from 1948–1960 to 1961–1968, and the ranking is the new era's.
    const era = page.getByLabel('Era', { exact: true });
    await tabTo(page, era);
    await page.keyboard.press('ArrowDown');
    await expect(page).toHaveURL(/band=2/);
    await expect(page.getByText(/ in 1961–1968\. The \d+ rows? below accounts? for /)).toBeVisible();
    await expect.poll(async () => (await rows(ranking))[1]).not.toEqual(before[1]);
    await expect(era).toBeFocused();

    // The unit, by keyboard: the central-file classes, ranked under their own title.
    const unit = page.getByLabel('Show', { exact: true });
    await tabTo(page, unit);
    await page.keyboard.press('ArrowDown');
    await expect(page).toHaveURL(/lens=centralFileClasses/);
    const classes = page.getByRole('table', { name: 'Top central-file classes by era' });
    await expect.poll(async () => (await rows(classes)).length).toBeGreaterThan(1);
    expect((await rows(classes))[0]).toEqual(['Archival unit', 'Custodian', 'Documents']);
    await axeCheck(page);

    // The ranking's CSV, its method block the kit's.
    const exportMenu = page.getByRole('button', { name: 'Export' }).first();
    await tabTo(page, exportMenu);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Chart data (CSV)…' })).toBeFocused();
    const saving = page.waitForEvent('download');
    await page.keyboard.press('Enter');
    const csv = await saving;
    // Named by the kit's title for the export, the lens and the era.
    expect(csv.suggestedFilename()).toMatch(/^FRUS-Analytics-Central-file-classes-by-era-1961-1968-\d{4}-\d{2}-\d{2}\.csv$/);
    const text = await readFile(await csv.path(), 'utf8');
    expect(text).toContain('# Figure: Central-file classes by era — 1961–1968\n');
    expect(text).toContain('\nArchival unit,Custodian,Documents\n');
    await expect(page.getByRole('alert')).toHaveCount(0);

    // The Network, by keyboard: back from the Export menu to the mode's radio, then the canvas's list box, a partner shown
    // in the dock and closed.
    const collections = page.getByRole('radio', { name: 'Collections', exact: true });
    await backTabTo(page, collections);
    await page.keyboard.press('ArrowRight');
    await expect(page.getByRole('radio', { name: 'Network', exact: true })).toBeChecked();
    await expect(page).toHaveURL(/mode=network/);
    const network = page.getByRole('listbox', { name: /^Collections co-cited with / });
    await expect(network).toBeAttached();
    await expect(page.getByText('Select a node to see the link')).toBeVisible();
    await tabTo(page, network);
    const first = network.getByRole('option').first();
    await expect(network).toHaveAttribute('aria-activedescendant', (await first.getAttribute('id')) ?? '');
    await page.keyboard.press('ArrowDown');
    const second = network.getByRole('option').nth(1);
    await expect(network).toHaveAttribute('aria-activedescendant', (await second.getAttribute('id')) ?? '');
    await page.keyboard.press('Enter');
    await expect(second).toHaveAttribute('aria-selected', 'true');
    await expect(page.locator('.archival-dock').getByText(/cite both /)).toBeVisible();
    const neighbourhood = page.getByRole('table', { name: /^Co-cited with / });
    expect((await rows(neighbourhood))[0]).toEqual(['Archival unit', 'Kind', 'Custodian', 'Shared volumes', 'Jointly supplied documents', 'Share of strongest link']);
    await axeCheck(page);
    await page.keyboard.press('Escape');
    await expect(page.getByText('Select a node to see the link')).toBeVisible();

    // The Flows: the heaviest hand-offs of the series, and their table.
    await tabTo(page, page.getByRole('radio', { name: 'Network', exact: true }));
    await page.keyboard.press('ArrowRight');
    await expect(page).toHaveURL(/mode=flows/);
    await expect(page.getByRole('heading', { level: 2, name: 'The heaviest hand-offs in the series' })).toBeVisible();
    const pairs = page.getByRole('table', { name: 'The heaviest hand-offs in the series' });
    expect((await rows(pairs))[0]).toEqual(['From', 'To', 'References']);
    await axeCheck(page);

    // Your Library, over the served index: its cards, or its empty state.
    await tabTo(page, page.getByRole('radio', { name: 'Flows', exact: true }));
    await page.keyboard.press('ArrowRight');
    await expect(page).toHaveURL(/mode=yourLibrary/);
    await expect(
      page.getByRole('heading', { level: 2, name: 'Where your documents come from' }).or(page.getByRole('heading', { level: 2, name: 'No Source Notes Yet' })),
    ).toBeVisible();
    await axeCheck(page);
  } finally {
    await forget(page);
  }
});

test('reaches About the Series by keyboard, reads its tables, and turns on the editorial notes', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('search');
  await openFromMenu(page, 'About the Series', 'end');
  await expect(page).toHaveURL(/\/about$/);
  await expect(page.getByRole('heading', { level: 1, name: 'About the Series' })).toBeFocused();
  await expect(page.getByRole('heading', { level: 2, name: 'Production & Timeliness' })).toBeVisible();
  const lag = page.getByRole('table', { name: 'Publication lag over time' });
  await expect.poll(async () => (await rows(lag)).length).toBeGreaterThan(100);
  await expect(page.getByRole('img', { name: 'Publication lag over time. The table beside the chart lists its numbers.' }).locator('svg')).toBeVisible();
  await axeCheck(page);

  // Geographic Emphasis, by keyboard: its overall regional table.
  const pages = page.getByRole('navigation', { name: 'About the Series pages' });
  await tabTo(page, pages.getByRole('link', { name: 'Geographic Emphasis' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/page=geography/);
  const totals = page.getByRole('table', { name: 'Overall regional emphasis' });
  await expect.poll(async () => (await rows(totals)).length).toBeGreaterThan(5);
  expect((await rows(totals))[0]).toEqual(['Region', 'Volumes']);
  expect((await rows(totals))[1]?.[0]).toBe('Europe');
  await axeCheck(page);

  // Administration Profiles, by keyboard: the editorial notes counted, and the documents' table counting them.
  await tabTo(page, pages.getByRole('link', { name: 'Administration Profiles' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/page=administrations/);
  const documents = page.getByRole('table', { name: 'Documents per administration' });
  await expect.poll(async () => (await rows(documents)).length).toBeGreaterThan(20);
  const counted = await rows(documents);
  const notes = page.getByRole('checkbox', { name: 'Include editorial notes (date ranges)' });
  await tabTo(page, notes);
  await page.keyboard.press('Space');
  await expect(page).toHaveURL(/notes=on/);
  await expect.poll(async () => (await rows(documents)).slice(1)).not.toEqual(counted.slice(1));
  await expect(notes).toBeChecked();
  await expect(page.getByRole('heading', { level: 3, name: 'Administration detail' })).toBeVisible();
  await axeCheck(page);
});
