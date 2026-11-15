// S24g's done-when (docs/PLAN.md): Playwright changes a control by keyboard and reads the table, on Chromium, with no axe
// violations. Against the image with the synthetic export imported, whose one person of the rollup, Khrushchev, is
// mentioned in frus1961-63v06's d1 and d2 of November 1960: Person Analytics opens from the header's Analytics menu, he
// is added to the comparison from his row of the ranking, and Values and By decade are changed, by keyboard, each read
// back from the table beside the chart; the ranking's CSV carries the kit's method block; and Cross-Reference Analytics,
// which the export's three documents give no reference to chart, says so. With FRUS_E2E_GRAPH, on the smoke test's
// Standalone server, whose index holds the three fixture volumes, the out-degree overlay is turned on by keyboard and
// read from the distribution's table, and the co-mention network is walked by keyboard: a partner shown in the dock,
// closed, and explored. The file's name ends as the graph spec's does, so the smoke test's graph step, which runs that
// spec on that server, runs this one's second test beside it.
import { readFile } from 'node:fs/promises';
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

const standalone = !!process.env.FRUS_E2E_GRAPH;

/** Leaves Values as this browser kept them. */
async function forget(page: Page): Promise<void> {
  await page.evaluate(() => localStorage.removeItem('frus.personAnalytics.normalizationMode'));
}

/** A table's header and rows, as text. */
async function rows(table: Locator): Promise<string[][]> {
  await expect(table.locator('tr').first()).toBeVisible();
  return table
    .locator('tr')
    .evaluateAll((elements) => elements.map((row) => [...row.querySelectorAll('th, td')].map((cell) => (cell.textContent ?? '').trim())));
}

async function openFromMenu(page: Page, item: string, steps: number): Promise<void> {
  const menu = page.getByRole('navigation', { name: 'Main' }).getByRole('button', { name: 'Analytics' });
  await tabTo(page, menu);
  await page.keyboard.press('Enter');
  for (let step = 0; step < steps; step += 1) await page.keyboard.press('ArrowDown');
  await expect(page.getByRole('menuitem', { name: item })).toBeFocused();
  await page.keyboard.press('Enter');
}

test('compares a person by keyboard, changes the values and the decades, and reads the tables', async ({ page }) => {
  test.skip(standalone, 'runs on the synthetic export');
  test.setTimeout(90_000);
  await page.goto('search');
  await forget(page);
  try {
    await openFromMenu(page, 'Person Analytics', 1);
    await expect(page).toHaveURL(/analytics\/people$/);
    await expect(page.getByRole('heading', { level: 1, name: 'Person Analytics' })).toBeFocused();
    await expect(page.getByRole('heading', { level: 2, name: 'Most-Mentioned People' })).toBeVisible();
    const ranking = page.getByRole('table', { name: 'Most-Mentioned People' });
    expect(await rows(ranking)).toEqual([
      ['Rank', 'Person', 'Chart label', 'Person id', 'Mentions in dated documents'],
      ['1', 'Khrushchev, Nikita Sergeyevich', 'Khrushchev, Nikita Sergeyevich', '1', '2'],
    ]);
    await expect(page.getByText('Add up to 5 people — from the ranking above or the search field — to compare how often each is tagged over time.')).toBeVisible();
    await expect(page.getByRole('img', { name: 'Most-Mentioned People. The table beside the chart lists its numbers.' }).locator('svg')).toBeVisible();
    await axeCheck(page);

    // He joins the comparison from his row, by keyboard.
    const compare = ranking.getByRole('button', { name: 'Khrushchev, Nikita Sergeyevich', exact: true });
    await tabTo(page, compare);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/people=1/);
    await expect(compare).toHaveAttribute('aria-pressed', 'true');
    const trajectories = page.getByRole('table', { name: 'Mention Trajectories' });
    await expect.poll(async () => (await rows(trajectories)).length).toBe(2);
    expect(await rows(trajectories)).toEqual([
      ['Person', 'Person id', 'Year', 'Mentions in dated documents', 'Documents mentioning this person', 'Dated documents in period', 'Plotted value'],
      ['Khrushchev, Nikita Sergeyevich', '1', '1960', '2', '2', '2', '2'],
    ]);
    await expect(page.getByRole('button', { name: 'Remove Khrushchev, Nikita Sergeyevich from comparison' })).toBeVisible();
    await axeCheck(page);

    // Values, by keyboard: the arrow keys move from Raw count to % of documents, a share of 1960's two dated documents.
    const raw = page.getByRole('radio', { name: 'Raw count', exact: true });
    await tabTo(page, raw);
    await expect(raw).toBeChecked();
    await page.keyboard.press('ArrowRight');
    await expect(page.getByRole('radio', { name: '% of documents', exact: true })).toBeChecked();
    await expect(page).toHaveURL(/values=percentOfDocuments/);
    await expect.poll(async () => (await rows(trajectories))[1]?.[6]).toBe('100');

    // By decade, by keyboard: the period is the decade's.
    const decade = page.getByRole('checkbox', { name: 'By decade' });
    await tabTo(page, decade);
    await page.keyboard.press('Space');
    await expect(page).toHaveURL(/decade=on/);
    await expect.poll(async () => (await rows(trajectories))[0]?.[2]).toBe('Decade');
    expect((await rows(trajectories))[1]).toEqual(['Khrushchev, Nikita Sergeyevich', '1', '1960', '2', '2', '2', '100']);
    await axeCheck(page);

    // The ranking's CSV, its method block the kit's.
    const exportMenu = page.getByRole('button', { name: 'Export' }).first();
    await tabTo(page, exportMenu);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Chart data (CSV)…' })).toBeFocused();
    const saving = page.waitForEvent('download');
    await page.keyboard.press('Enter');
    const csv = await saving;
    expect(csv.suggestedFilename()).toMatch(/^FRUS-Analytics-Most-Mentioned-People-\d{4}-\d{2}-\d{2}\.csv$/);
    const text = await readFile(await csv.path(), 'utf8');
    expect(text).toContain('# Figure: Most-Mentioned People\n');
    expect(text).toContain('Population: person mentions are counted in dated documents only.');
    expect(text).toContain('\nRank,Person,Chart label,Person id,Mentions in dated documents\n1,"Khrushchev, Nikita Sergeyevich","Khrushchev, Nikita Sergeyevich",1,2\n');
    await expect(page.getByRole('alert')).toHaveCount(0);

    // Cross-Reference Analytics: the export's documents cite nothing, and each section says so.
    await openFromMenu(page, 'Cross-Reference Analytics', 2);
    await expect(page).toHaveURL(/analytics\/cross-references$/);
    await expect(page.getByRole('heading', { level: 1, name: 'Cross-Reference Analytics' })).toBeFocused();
    await expect(page.getByText(/^The most-referenced, degree, and PageRank charts count same-volume references/)).toBeVisible();
    await expect(page.getByRole('heading', { level: 2, name: 'No Data' })).toHaveCount(4);
    await axeCheck(page);
  } finally {
    await forget(page);
  }
});

test('turns on the out-degree overlay and walks the co-mention network by keyboard, over the fixture index', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_GRAPH');
  test.setTimeout(120_000);
  await page.goto('analytics/cross-references');
  await expect(page.getByRole('heading', { level: 1, name: 'Cross-Reference Analytics' })).toBeVisible();
  const ranked = page.getByRole('table', { name: 'Most-Referenced Documents' });
  await expect.poll(async () => (await rows(ranked)).length).toBeGreaterThan(2);
  await expect(page.getByRole('table', { name: 'Landmark Documents (Influence)' })).toBeVisible();
  const distribution = page.getByRole('table', { name: 'Citation Degree Distribution' });
  expect((await rows(distribution))[0]).toEqual(['References received', 'Documents (inbound)']);
  await axeCheck(page);

  // The out-degree overlay, by keyboard: the table gains its outbound column.
  const outDegree = page.getByRole('checkbox', { name: 'Out-degree' });
  await tabTo(page, outDegree);
  await page.keyboard.press('Space');
  await expect(page).toHaveURL(/outDegree=on/);
  await expect.poll(async () => (await rows(distribution))[0]).toEqual(['References received', 'Documents (inbound)', 'Documents (outbound)']);
  await expect(outDegree).toBeFocused();
  await axeCheck(page);

  // The co-mention network around the ranking's first person, its partners walked by keyboard.
  await page.goto('analytics/people?mode=network');
  await expect(page.getByRole('heading', { level: 1, name: 'Person Analytics' })).toBeVisible();
  const network = page.getByRole('listbox', { name: /^Co-mention network of / });
  await expect(network).toBeAttached();
  await tabTo(page, network);
  const first = network.getByRole('option').first();
  await expect(network).toHaveAttribute('aria-activedescendant', (await first.getAttribute('id')) ?? '');
  await page.keyboard.press('ArrowDown');
  const second = network.getByRole('option').nth(1);
  await expect(network).toHaveAttribute('aria-activedescendant', (await second.getAttribute('id')) ?? '');
  await page.keyboard.press('Enter');
  await expect(second).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator('.person-dock').getByText(/^[\d,]+ shared documents? with /)).toBeVisible();
  await expect(page.getByRole('table', { name: 'Co-mentioned people' })).toBeVisible();
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(page.getByText('Select a person to see their shared documents and connections.')).toBeVisible();

  // Explore connections re-centres the network on the partner shown, and Back returns.
  await page.keyboard.press('Enter');
  const before = page.url();
  await tabTo(page, page.getByRole('button', { name: 'Explore connections' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/focus=\d+/);
  await expect(page.getByRole('button', { name: 'Back', exact: true })).toBeVisible();
  await expect(page.getByRole('listbox', { name: /^Co-mention network of / })).toBeAttached();
  await axeCheck(page);
  expect(page.url()).not.toBe(before);
});
