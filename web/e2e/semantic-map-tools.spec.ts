// S28e's done-when (docs/PLAN.md): Playwright saves a region as a corpus, sets two poles and resets them, by keyboard on
// Chromium with no axe violations. Against the image with the synthetic export imported, which serves frus1961-63v06's d1
// and d2, both in the region the bundled map names "edc nato nuclear", the largest of the 79 of that volume's documents in
// a region of their own. Scoped to the volume, the region's card saves its 79 as a working corpus, named by the map's
// rule and described as a Semantic map selection scoped to the volume, which Working Corpora lists. From d1's card, its
// volume is the axis's low end; the largest region's first document, of another volume, is its high end; the two lay the
// series out as a slice, which the address carries; and Back to the map draws the map again. With Lasso on, a drag
// around d1 gathers what it encloses, which its card saves; and Export writes the regions' CSV with the kit's method block
// and the figure as PNG, drawn in the browser.
import { readFile } from 'node:fs/promises';
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';
import { getJSON, send } from './notes';

/** The map's frame, once it has drawn the view it was asked for, with its names laid out for it, or none on a slice. */
async function drawn(page: Page, view?: RegExp | string, names: 'laid-out' | 'none' = 'laid-out') {
  const map = page.locator('.semantic-map-frame');
  await expect(map).toHaveAttribute('data-view', view ?? /./, { timeout: 60_000 });
  await expect(map).toHaveAttribute('data-names', names);
  return map;
}

/** Removes the corpora named, from a page that lists none, since the suite runs twice on one store. */
async function forget(page: Page, names: string[]) {
  await page.goto('browse');
  const corpora = await getJSON<{ items: { id: string; name: string }[] }>(page, 'api/v1/me/working-corpora');
  for (const corpus of corpora.items) if (names.includes(corpus.name)) await send(page, 'DELETE', `api/v1/me/working-corpora/${corpus.id}`);
}

test('saves a region as a working corpus from its card, by keyboard', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('analytics/semantic?volume=frus1961-63v06');
  await drawn(page, '1.000 0 0');
  const keys = page.getByRole('listbox', { name: 'Semantic map' });
  await tabTo(page, keys);
  await expect(keys.getByRole('option').first()).toHaveText(/^edc nato nuclear, region, 79 documents/);
  await page.keyboard.press('Enter');
  const region = page.getByRole('region', { name: 'Region', exact: true });
  await expect(region.getByText(/ documents in the series · 79 in scope$/)).toBeVisible();
  // The app's Save as Working Corpus, after the era's caveat, the keyboard's path from the map to a corpus.
  const save = region.getByRole('button', { name: 'Save as Working Corpus' });
  await tabTo(page, save);
  await page.keyboard.press('Enter');
  const saved = region.getByText(/^Saved as “edc nato nuclear — .+”\. Find it under Working Corpora, where it can scope a search\.$/);
  await expect(saved).toBeFocused();
  await expect(save).toHaveCount(0);
  await axeCheck(page);
  const name = /^Saved as “(.+)”\./.exec((await saved.textContent()) ?? '')?.[1] ?? '';
  try {
    // Working Corpora lists it: the region's 79, described by the map's capture and its scope.
    await page.goto('browse/corpora');
    const row = page.getByRole('listitem').filter({ has: page.getByRole('link', { name: `${name}, 79 documents` }) });
    await expect(row.locator('.meta').first()).toHaveText(/^79 documents · Semantic map selection, scoped to .+ · /);
    await axeCheck(page);
  } finally {
    await forget(page, [name]);
  }
});

test('sets the axis’s two poles from points’ cards and resets them, by keyboard', async ({ page }) => {
  test.setTimeout(150_000);
  // d1's card, as the rail's On the Map opens it: its volume the axis's low end.
  await page.goto('analytics/semantic?document=frus1961-63v06%2Fd1');
  const map = await drawn(page, '33.333 -19710 -219');
  const d1 = page.getByRole('region', { name: /· d1$/ });
  await expect(d1.getByText(/^On the map no direction has a meaning\./)).toBeVisible();
  await expect(d1.getByRole('button', { name: '…to here' })).toBeDisabled();
  await tabTo(page, d1.getByRole('button', { name: 'Axis: from here' }));
  await page.keyboard.press('Enter');
  const axis = page.getByRole('region', { name: 'Axis', exact: true });
  await expect(axis.getByText('frus1961-63v06', { exact: true })).toBeVisible();
  await expect(axis.getByText(/^Select a document in a different volume and choose “…to here”\./)).toBeVisible();
  await axeCheck(page);

  // The largest region's first document, of another volume, from its card by keyboard: the map's list box is above the
  // cards.
  const keys = page.getByRole('listbox', { name: 'Semantic map' });
  await backTabTo(page, keys);
  await page.keyboard.press('Home');
  await page.keyboard.press('Enter');
  const region = page.getByRole('region', { name: 'Region', exact: true });
  const first = region.getByRole('button', { name: /^Show on the map: / }).first();
  await tabTo(page, first);
  await page.keyboard.press('Enter');
  const other = page.getByRole('region', { name: /· d\d+[a-z]*$/ }).filter({ hasNot: page.getByText('frus1961-63v06 · d1', { exact: true }) });
  await expect(other.getByRole('heading', { level: 2 })).toBeFocused();
  const ids = (await other.locator('.semantic-card-ids').first().textContent()) ?? '';
  const volume = ids.split(' · ')[0] ?? '';
  expect(volume).not.toBe('frus1961-63v06');
  expect(volume).toMatch(/^frus/);
  await tabTo(page, other.getByRole('button', { name: '…to here' }));
  await page.keyboard.press('Enter');

  // The slice: the address carries both ends, the card names them, the map is laid out again with no names, the caveat is
  // the slice's, and a point's card no longer says what a slice adds.
  await expect(page).toHaveURL(new RegExp(`[?&]from=frus1961-63v06&to=${volume}(&|$)`));
  await expect(axis.getByText(`frus1961-63v06 → ${volume}`, { exact: true })).toBeVisible();
  await expect(map).toHaveAttribute('data-layout', `slice:frus1961-63v06|${volume}`, { timeout: 60_000 });
  await drawn(page, '1.000 0 0', 'none');
  await expect(page.getByText(new RegExp(`^Left to right is how far each document leans from frus1961-63v06 toward ${volume}\\.`))).toBeVisible();
  await expect(page.locator('.semantic-slice-pole').first()).toHaveText('← frus1961-63v06');
  await expect(page.locator('.semantic-slice-tick').first()).toHaveText(/^\d{4}$/);
  await expect(other.getByText(/^On the map no direction has a meaning\./)).toHaveCount(0);
  await axeCheck(page);

  // Back to the map: the poles cleared, the address with them, the map's own plane, and the keyboard on the map.
  await backTabTo(page, axis.getByRole('button', { name: 'Back to the map' }));
  await page.keyboard.press('Enter');
  await expect(page).not.toHaveURL(/[?&](from|to)=/);
  await expect(axis).toHaveCount(0);
  await expect(keys).toBeFocused();
  await expect(map).toHaveAttribute('data-layout', 'map');
  await drawn(page, '1.000 0 0');
  await expect(page.getByText('Layout preserves local similarity; distances between far regions are not meaningful.')).toBeVisible();
  await axeCheck(page);
});

test('draws a lasso by pointer around a document, saves what it caught, and exports the regions and the figure', async ({ page }) => {
  test.setTimeout(150_000);
  await page.goto('analytics/semantic?document=frus1961-63v06%2Fd1');
  const map = await drawn(page, '33.333 -19710 -219');
  const lasso = page.getByRole('button', { name: 'Lasso' });
  await tabTo(page, lasso);
  await page.keyboard.press('Enter');
  await expect(lasso).toHaveAttribute('aria-pressed', 'true');
  await expect(map).toHaveAttribute('data-lassoing', 'true');
  // A ring around d1, at the middle of the view the reveal centred on it.
  const box = (await map.boundingBox()) ?? { x: 0, y: 0, width: 0, height: 0 };
  const [cx, cy] = [box.x + box.width / 2, box.y + box.height / 2];
  const caught = page.waitForResponse((response) => response.url().includes('/api/v1/semantic/map/lasso') && response.request().method() === 'POST');
  await page.mouse.move(cx - 60, cy - 60);
  await page.mouse.down();
  for (const [x, y] of [[cx + 60, cy - 60], [cx + 60, cy + 60], [cx - 60, cy + 60], [cx - 60, cy - 50]]) await page.mouse.move(x, y, { steps: 8 });
  await page.mouse.up();
  const answer = (await (await caught).json()) as { capture?: { total: number; kept: number; regionNames: string[] } };
  const total = answer.capture?.total ?? 0;
  expect(total).toBeGreaterThan(0);
  const card = page.getByRole('region', { name: 'Lasso', exact: true });
  await expect(card.getByRole('heading', { level: 2 })).toHaveText(total === 1 ? '1 document' : `${total.toLocaleString('en-US')} documents`);
  await expect(card.getByText(answer.capture?.regionNames.join(' · ') ?? '', { exact: true })).toBeVisible();
  await expect(card.getByRole('img', { name: 'Source: computed by this app.' })).toBeVisible();
  await expect(card.getByText(/ indexed on this server$/)).toBeVisible();
  await axeCheck(page);
  await tabTo(page, card.getByRole('button', { name: 'Save as Working Corpus' }));
  await page.keyboard.press('Enter');
  // The button gives way to the corpus's name, which takes the keyboard.
  const saved = card.locator('.semantic-card-saved');
  await expect(saved).toBeFocused();
  await expect(saved).toHaveText(/Saved as .+ — .+$/);
  const name = /Saved as (.+)$/.exec((await saved.textContent()) ?? '')?.[1] ?? '';

  try {
    // The regions' CSV with the kit's method block, and the figure as PNG, drawn here, by keyboard.
    const exportMenu = page.getByRole('button', { name: 'Export map data' });
    await backTabTo(page, exportMenu);
    await page.keyboard.press('Enter');
    await expect(page.getByRole('menuitem', { name: 'Chart data (CSV)…' })).toBeFocused();
    const csvSaving = page.waitForEvent('download');
    await page.keyboard.press('Enter');
    const csv = await csvSaving;
    expect(csv.suggestedFilename()).toMatch(/^FRUS-Analytics-Semantic-map-regions-\d{4}-\d{2}-\d{2}\.csv$/);
    const text = await readFile(await csv.path(), 'utf8');
    expect(text).toContain('# Figure: Semantic map regions\n');
    expect(text).toContain('\nRegion,Terms,Documents,Center X,Center Y,');
    await expect(exportMenu).toBeFocused();
    await page.keyboard.press('Enter');
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Figure (PNG)…' })).toBeFocused();
    const pngSaving = page.waitForEvent('download');
    await page.keyboard.press('Enter');
    const png = await pngSaving;
    expect(png.suggestedFilename()).toMatch(/^FRUS-Analytics-Semantic-map-\d{4}-\d{2}-\d{2}\.png$/);
    const bytes = await readFile(await png.path());
    expect([...bytes.subarray(0, 4)]).toEqual([0x89, 0x50, 0x4e, 0x47]);
    // Twice the plate's 1,144 points wide, and more with the band's margins.
    expect(bytes.readUInt32BE(16)).toBeGreaterThanOrEqual(2 * 1_144);
    // The plate holds the points drawn: the figure's middle row, across the plate, has colours no caption's grey has.
    const coloured = await page.evaluate(async (base64) => {
      const image = new Image();
      image.src = `data:image/png;base64,${base64}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width;
      canvas.height = image.height;
      const context = canvas.getContext('2d');
      if (!context) return 0;
      context.drawImage(image, 0, 0);
      const row = context.getImageData(0, Math.floor(image.height / 2), image.width, 1).data;
      let count = 0;
      for (let at = 0; at < row.length; at += 4) {
        const [r, g, b] = [row[at] ?? 0, row[at + 1] ?? 0, row[at + 2] ?? 0];
        if (Math.max(r, g, b) - Math.min(r, g, b) > 24) count += 1;
      }
      return count;
    }, bytes.toString('base64'));
    expect(coloured).toBeGreaterThan(20);
    await expect(page.getByRole('alert')).toHaveCount(0);
  } finally {
    await forget(page, [name]);
  }
});
