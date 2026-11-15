// S24f's done-when (docs/PLAN.md): Playwright changes the axis and the unit by keyboard and reads the table, on
// Chromium, with no axe violations. Against the image, with the synthetic export imported: frus1961-63v06's d1 and
// d2, dated 9 and 10 November 1960, say "treaties", and frus1894Nicaragua's d1, of 25 January 1894, says "canal".
// Corpus Analytics opens from the header's Analytics menu; a term is charted by keyboard; Group by changes the
// axis and Measure the unit, by keyboard, each read back from the table beside the chart; the CSV with the method
// block and the figure, PNG and SVG, are saved. Then Chronology shows a range, its legend filters the list by
// keyboard, and its table and sections are read. Vega draws under the app's policy: the suite fails on any console
// error, a policy violation among them. The test leaves the measure, values and colours this browser keeps as it
// found them.
import { readFile } from 'node:fs/promises';
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

async function forget(page: Page): Promise<void> {
  await page.evaluate(() => {
    for (const key of ['frus.analytics.valueUnit', 'frus.analytics.normalizationMode', 'frus.display.chartSeriesCount']) {
      localStorage.removeItem(key);
    }
  });
}

/** The chart's table, its header and its rows, as text. */
async function table(page: Page): Promise<string[][]> {
  const rows = page.locator('.analytics-table table tr');
  await expect(rows.first()).toBeVisible();
  return rows.evaluateAll((elements) =>
    elements.map((row) => [...row.querySelectorAll('th, td')].map((cell) => (cell.textContent ?? '').trim())),
  );
}

test('charts a term, changes its axis and unit by keyboard, reads the table and exports it', async ({ page }) => {
  // Six charts, four scans and three exports, with Vega's chunk loaded once.
  test.setTimeout(90_000);
  await page.goto('search');
  await forget(page);
  try {
    // The header's Analytics menu, by keyboard.
    const menu = page.getByRole('navigation', { name: 'Main' }).getByRole('button', { name: 'Analytics' });
    await tabTo(page, menu);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Corpus Analytics' })).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/analytics\/corpus$/);
    await expect(page.getByRole('heading', { level: 1, name: 'Corpus Analytics' })).toBeFocused();
    await expect(page.getByRole('heading', { level: 2, name: 'Enter a Term' })).toBeVisible();
    await axeCheck(page);

    // A term, typed and searched by keyboard.
    await tabTo(page, page.getByRole('searchbox', { name: 'Term' }));
    await page.keyboard.type('treaties');
    await page.keyboard.press('Enter');
    await expect(page.getByRole('heading', { level: 2, name: '"treaties" — by Year' })).toBeVisible();
    expect(await table(page)).toEqual([
      ['Term', 'Year', 'Matching documents', 'Indexed documents in period', 'Share of indexed documents (%)', 'Plotted value'],
      ['treaties', '1960', '2', '2', '100', '2'],
    ]);
    await expect(page.getByText('2 documents matched', { exact: true })).toBeVisible();
    // Search's count of the documents the link opens.
    await expect(page.getByRole('link', { name: /View 2 documents/ })).toBeVisible();
    await expect(page.getByRole('img', { name: '"treaties" — by Year. The table beside the chart lists its numbers.' }).locator('svg')).toBeVisible();
    await axeCheck(page);

    // The axis, by keyboard: Group by's arrow keys move along its options, By Year to By Volume.
    const groupBy = page.getByRole('combobox', { name: 'Group by' });
    await tabTo(page, groupBy);
    for (const [step, heading] of [
      [1, '"treaties" — by Month'],
      [2, '"treaties" — by Day'],
      [3, '“treaties” — by Subseries'],
      [4, '“treaties” — by Volume'],
    ] as const) {
      await page.keyboard.press('ArrowDown');
      await expect(page.getByRole('heading', { level: 2, name: heading }), `step ${step}`).toBeVisible();
    }
    await expect(groupBy).toBeFocused();
    const byVolume = await table(page);
    expect(byVolume[0]?.slice(0, 3)).toEqual(['Term', 'Volume', 'Matching documents']);
    expect(byVolume).toHaveLength(2);
    expect(byVolume[1]?.[0]).toBe('treaties');
    expect(byVolume[1]?.[2]).toBe('2');
    // A breakdown's row opens its documents in Search.
    await expect(page.locator('.analytics-table').getByRole('link', { name: byVolume[1]?.[1] ?? '' })).toBeVisible();
    await expect(page.getByText('The year range applies to the time views; the breakdowns show the whole span.')).toBeVisible();
    await axeCheck(page);

    // Back to By Year, and the unit, by keyboard: Measure's arrow keys move from Documents to Occurrences.
    for (let step = 0; step < 4; step += 1) await page.keyboard.press('ArrowUp');
    await expect(page.getByRole('heading', { level: 2, name: '"treaties" — by Year' })).toBeVisible();
    const documents = page.getByRole('radio', { name: 'Documents', exact: true });
    await tabTo(page, documents);
    await expect(documents).toBeChecked();
    await page.keyboard.press('ArrowRight');
    await expect(page.getByRole('radio', { name: 'Occurrences', exact: true })).toBeChecked();
    await expect(page).toHaveURL(/measure=occurrences/);
    await expect.poll(async () => (await table(page))[0]?.[2]).toBe('Occurrences (index stems)');
    expect((await table(page))[1]).toEqual(['treaties', '1960', '2', '2', '100', '2']);
    await expect(page.getByText('2 occurrences', { exact: true })).toBeVisible();
    // Values are a share of documents alone, so they yield under Occurrences.
    await expect(page.getByRole('radio', { name: '% of documents', exact: true })).toBeDisabled();
    await axeCheck(page);

    // The CSV, its method block the kit's, and the figure, PNG and SVG, drawn in the browser.
    const exportMenu = page.getByRole('button', { name: 'Export' });
    await tabTo(page, exportMenu);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Chart data (CSV)…' })).toBeFocused();
    const csvSaving = page.waitForEvent('download');
    await page.keyboard.press('Enter');
    const csv = await csvSaving;
    expect(csv.suggestedFilename()).toMatch(/^FRUS-Analytics-treaties-By-Year-\d{4}-\d{2}-\d{2}\.csv$/);
    const text = await readFile(await csv.path(), 'utf8');
    expect(text).toContain('# FRUS Explorer — analytics export\n#\n# Figure: "treaties" — By Year\n# Term(s): treaties\n# Grouped by: By Year\n');
    expect(text).toContain('# Counting: Occurrences (stems)\n');
    expect(text).toContain('\nTerm,Year,Occurrences (index stems),Indexed documents in period,Share of indexed documents (%),Plotted value\ntreaties,1960,2,2,100,2\n');
    // The menu hands the focus back to its button once an item is chosen, as the app's menus do.
    await expect(exportMenu).toBeFocused();
    for (const [item, steps, extension, start] of [
      ['Figure (PNG)…', 1, 'png', [0x89, 0x50, 0x4e, 0x47]],
      ['Figure (SVG)…', 2, 'svg', [0x3c, 0x73, 0x76, 0x67]],
    ] as const) {
      await page.keyboard.press('Enter');
      for (let step = 0; step < steps; step += 1) await page.keyboard.press('ArrowDown');
      await expect(page.getByRole('menuitem', { name: item })).toBeFocused();
      const saving = page.waitForEvent('download');
      await page.keyboard.press('Enter');
      const figure = await saving;
      expect(figure.suggestedFilename()).toMatch(new RegExp(`^FRUS-Analytics-treaties-By-Year-\\d{4}-\\d{2}-\\d{2}\\.${extension}$`));
      expect([...(await readFile(await figure.path())).subarray(0, 4)]).toEqual([...start]);
      await expect(exportMenu).toBeFocused();
    }
    await expect(page.getByRole('alert')).toHaveCount(0);
  } finally {
    await forget(page);
  }
});

test('shows a range in Chronology, filters its list by the legend by keyboard, and reads its table', async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('search');
  await forget(page);
  try {
    // The header's Analytics menu, its last item past the divider, by keyboard.
    const menu = page.getByRole('navigation', { name: 'Main' }).getByRole('button', { name: 'Analytics' });
    await tabTo(page, menu);
    await page.keyboard.press('Enter');
    await page.keyboard.press('End');
    await expect(page.getByRole('menuitem', { name: 'Chronology' })).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/chronology$/);
    await expect(page.getByRole('heading', { level: 1, name: 'Chronology' })).toBeFocused();
    await expect(page.getByRole('heading', { level: 2, name: 'Choose a Date Range' })).toBeVisible();
    // The range opens on the corpus's last year; one of November 1960 is shown by keyboard.
    await page.getByLabel('From', { exact: true }).fill('1960-11-01');
    await page.getByLabel('To', { exact: true }).fill('1960-11-30');
    await tabTo(page, page.getByRole('button', { name: 'Show', exact: true }));
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/from=1960-11-01&to=1960-11-30/);
    await expect(page.getByText('2 documents', { exact: true })).toBeVisible();
    await expect(page.getByRole('heading', { level: 2, name: /^November 9, 1960/ })).toBeVisible();
    await expect(page.getByRole('heading', { level: 2, name: /^November 10, 1960/ })).toBeVisible();
    await expect(page.getByRole('link', { name: '1. Telegram From the Embassy in the Soviet Union' })).toBeVisible();
    const rows = await table(page);
    expect(rows[0]).toEqual(['Date', 'Volume', 'Documents']);
    expect(rows.slice(1).map((row) => [row[0], row[2]])).toEqual([
      ['November 9, 1960', '1'],
      ['November 10, 1960', '1'],
    ]);
    await expect(page.getByRole('link', { name: 'Search in this range' })).toBeVisible();
    await axeCheck(page);

    // A range of both volumes: 1890 to 1965, a year a section, one document of 1894 and two of 1960.
    await page.getByLabel('From', { exact: true }).fill('1890-01-01');
    await page.getByLabel('To', { exact: true }).fill('1965-12-31');
    await tabTo(page, page.getByRole('button', { name: 'Show', exact: true }));
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/from=1890-01-01&to=1965-12-31/);
    await expect(page.getByText('3 documents', { exact: true })).toBeVisible();
    await expect(page.locator('.chronology-section h2')).toHaveText([/^1894/, /^1960/]);
    const entries = page.getByRole('list', { name: 'Volumes' }).getByRole('button');
    await expect(entries).toHaveCount(2);

    // The legend's entry filters the list to its volume, by keyboard; the other entry stays legible, and Show all
    // clears the filter.
    await tabTo(page, entries.first());
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/series=frus1961-63v06/);
    await expect(entries.first()).toHaveAttribute('aria-pressed', 'true');
    await expect(entries.nth(1)).toHaveAttribute('aria-pressed', 'false');
    await expect(page.getByText(/^Showing .* only$/)).toBeVisible();
    await expect(page.locator('.chronology-section h2')).toHaveText([/^1960/]);
    await axeCheck(page);
    await page.getByRole('button', { name: 'Show all', exact: true }).click();
    await expect(page).not.toHaveURL(/series=/);
    await expect(page.locator('.chronology-section h2')).toHaveCount(2);

    // Newest first, by keyboard, and the chart hidden and shown.
    await tabTo(page, page.getByRole('button', { name: 'Oldest first' }));
    await page.keyboard.press('Enter');
    await expect(page.getByRole('button', { name: 'Newest first' })).toBeVisible();
    await expect(page.locator('.chronology-section h2').first()).toHaveText(/^1960/);
    await page.getByRole('button', { name: 'Hide chart' }).click();
    await expect(page.locator('.chronology-chart')).toHaveCount(0);
    await page.getByRole('button', { name: 'Show chart' }).click();
    await expect(page.locator('.chronology-chart')).toBeVisible();
  } finally {
    await forget(page);
  }
});
