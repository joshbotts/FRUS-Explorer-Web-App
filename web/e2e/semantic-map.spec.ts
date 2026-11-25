// S28b's done-when (docs/PLAN.md): Playwright opens the map, zooms and pans it by keyboard and reads the table, on
// Chromium, with no axe violations and no console error. Against the image, whose bundled map the server reads, so
// nothing indexed is needed. Semantic Analytics opens from the header's Analytics menu by keyboard, after Archival
// Analytics; its map draws the 314,616 points (the frame says, as `data-view`, the view it last drew: the magnification and
// the centre); + zooms by the Mac's step, Shift and the arrow keys move the view (since S28c, whose list box of the
// regions is the canvas's one stop, its Up and Down moving from region to region) and − zooms out, each frame unlike the
// one before, and 0 fits the map again, to the first frame pixel for pixel, its names laid out again for the view; the
// buttons, a drag and the wheel do as much; and the regions' table lists the 140 regions largest first, with the app's
// summary. What a frame costs under this browser's renderer is printed: under CI's Chromium, its software one.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

/** The share of an image's pixels that are not the map's ground, read in the page from the screenshot's PNG. */
async function drawnShare(page: Page, image: Buffer): Promise<number> {
  return page.evaluate(async (bytes) => {
    const bitmap = await createImageBitmap(new Blob([new Uint8Array(bytes)], { type: 'image/png' }));
    const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    const context = canvas.getContext('2d');
    if (!context) return 0;
    context.drawImage(bitmap, 0, 0);
    const { data } = context.getImageData(0, 0, bitmap.width, bitmap.height);
    let drawn = 0;
    for (let index = 0; index < data.length; index += 4) {
      if (Math.abs((data[index] ?? 0) - 15) + Math.abs((data[index + 1] ?? 0) - 18) + Math.abs((data[index + 2] ?? 0) - 23) > 6) drawn++;
    }
    return drawn / (bitmap.width * bitmap.height);
  }, [...image]);
}

/** Presses `key` on the focused map and waits for the frame of the view it moves to, which must be another, with its
 *  names laid out for it. */
async function press(page: Page, map: Locator, key: string): Promise<string> {
  const before = (await map.getAttribute('data-view')) ?? '';
  await page.keyboard.press(key);
  await expect(map).not.toHaveAttribute('data-view', before);
  await expect(map).toHaveAttribute('data-names', 'laid-out');
  return (await map.getAttribute('data-view')) ?? '';
}

/** Each of `keys` dispatched on the map, and the time from the key to the frame it brings being done on the GPU, which a
 *  pixel read back waits for. */
async function frameTimes(page: Page, keys: string[]): Promise<number[]> {
  return page.evaluate(async (pressed) => {
    const frame = document.querySelector<HTMLElement>('.semantic-map-frame');
    const keys = frame?.querySelector<HTMLElement>('.semantic-map-keys');
    const gl = frame?.querySelector('canvas')?.getContext('webgl2');
    if (!frame || !keys || !gl) return [];
    const pixel = new Uint8Array(4);
    const times: number[] = [];
    for (const key of pressed) {
      const before = frame.dataset.view;
      const start = performance.now();
      keys.dispatchEvent(new KeyboardEvent('keydown', { key, shiftKey: key.startsWith('Arrow'), bubbles: true, cancelable: true }));
      for (let waited = 0; frame.dataset.view === before && waited < 300; waited++) {
        await new Promise((resolve) => requestAnimationFrame(resolve));
      }
      gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixel);
      times.push(performance.now() - start);
    }
    return times;
  }, keys);
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] ?? NaN;
}

test('opens the map from the Analytics menu, zooms and pans it by keyboard, fits it again and reads the regions', async ({ page }) => {
  test.setTimeout(150_000);
  await page.goto('search');

  // The header's Analytics menu, by keyboard: Semantic Analytics is its fifth item, after Archival Analytics.
  const menu = page.getByRole('navigation', { name: 'Main' }).getByRole('button', { name: 'Analytics' });
  await tabTo(page, menu);
  await page.keyboard.press('Enter');
  for (let step = 0; step < 4; step += 1) await page.keyboard.press('ArrowDown');
  await expect(page.getByRole('menuitem', { name: 'Semantic Analytics' })).toBeFocused();
  const opened = Date.now();
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/analytics\/semantic$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Semantic Analytics' })).toBeFocused();

  // The map, drawn: the whole of it, most of its frame the points' colours, with its regions' names over it.
  const map = page.locator('.semantic-map-frame');
  const keys = page.getByRole('listbox', { name: 'Semantic map' });
  await expect(map).toHaveAttribute('data-view', '1.000 0 0', { timeout: 60_000 });
  const firstFrame = Date.now() - opened;
  await expect(keys).toHaveAccessibleDescription(/Shift with an arrow key moves across the map, \+ and − zoom in and out, and 0 fits the whole map/);
  await expect(page.getByRole('status').filter({ hasText: 'The whole map.' })).toBeVisible();
  await expect(page.getByText('Between regions', { exact: true })).toBeVisible();
  await expect(page.getByText('Color separates neighboring regions rather than naming them; the names are on the map.')).toBeVisible();
  await expect(map).toHaveAttribute('data-names', 'laid-out');
  await axeCheck(page);

  // By keyboard: + zooms in by the Mac's step, Shift and the arrow keys move the view an eighth of it, − zooms out, and 0
  // fits it. Each frame is compared with the map focused, since the focus ring follows the frame's rounded corners into
  // the canvas's box, and with its names laid out for its view, the region the list is on ringed.
  await tabTo(page, keys);
  await expect(map).toHaveAttribute('data-names', 'laid-out');
  await expect(page.locator('.semantic-map-name.is-active, .semantic-map-ring')).toHaveCount(1);
  const canvas = map.locator('canvas');
  const whole = await canvas.screenshot();
  const share = await drawnShare(page, whole);
  // Neither the bare ground nor a canvas cleared and never drawn, which would be all one colour.
  expect(share, 'the share of the frame the points cover').toBeGreaterThan(0.05);
  expect(share, 'the share of the frame the points cover').toBeLessThan(0.9);
  let before = whole;
  for (const [key, view, status] of [
    ['+', /^1\.400 0 0$/, 'Zoomed in 1.4 times.'],
    ['Shift+ArrowRight', /^1\.400 [1-9]\d* 0$/, undefined],
    ['Shift+ArrowUp', /^1\.400 [1-9]\d* [1-9]\d*$/, undefined],
    ['-', /^1\.000 [1-9]\d* [1-9]\d*$/, 'Moved, at the whole map’s zoom.'],
    ['Shift+ArrowLeft', /^1\.000 -?\d+ [1-9]\d*$/, undefined],
  ] as const) {
    expect(await press(page, map, key)).toMatch(view);
    if (status) await expect(page.getByRole('status').filter({ hasText: status })).toBeVisible();
    const after = await canvas.screenshot();
    expect(after.equals(before), `the frame after ${key} is another`).toBe(false);
    before = after;
  }
  expect(await press(page, map, '0')).toBe('1.000 0 0');
  expect((await canvas.screenshot()).equals(whole), 'Fit the Map draws the first frame again').toBe(true);
  await axeCheck(page);

  // The Mac's buttons, by keyboard: they stand just before the map.
  const zoomIn = page.getByRole('button', { name: 'Zoom In', exact: true });
  expect(await backTabTo(page, zoomIn)).toBe(3);
  await page.keyboard.press('Enter');
  await expect(map).toHaveAttribute('data-view', '1.400 0 0');
  await page.keyboard.press('Tab');
  await expect(page.getByRole('button', { name: 'Zoom Out', exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
  await page.keyboard.press('Enter');
  await expect(map).toHaveAttribute('data-view', '0.714 0 0');
  await expect(page.getByRole('status').filter({ hasText: 'Zoomed out 1.4 times.' })).toBeVisible();
  await page.keyboard.press('Tab');
  await expect(page.getByRole('button', { name: 'Fit the Map', exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(map).toHaveAttribute('data-view', '1.000 0 0');

  // By pointer: a drag moves the map with it, and the wheel zooms about the pointer.
  const box = await map.boundingBox();
  if (!box) throw new Error('the map has no box');
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2 + 80, box.y + box.height / 2 + 40, { steps: 4 });
  await page.mouse.up();
  await expect(map).toHaveAttribute('data-view', /^1\.000 -\d+ \d+$/);
  await page.mouse.wheel(0, -200);
  await expect(map).toHaveAttribute('data-view', /^1\.[1-9]\d\d /);
  await keys.focus();
  expect(await press(page, map, '0')).toBe('1.000 0 0');

  // The regions' table: the 140 regions, largest first, with the app's summary over it.
  await expect(
    page.getByText(
      'Semantic map: 140 regions covering 226,557 documents. 88,059 more sit between regions and are not listed. Position shows similarity, not time — distances between far-apart regions are not meaningful.',
    ),
  ).toBeVisible();
  const table = page.getByRole('table', { name: 'Semantic map regions' });
  const rows = await table
    .locator('tr')
    .evaluateAll((elements) => elements.map((row) => [...row.querySelectorAll('th, td')].map((cell) => (cell.textContent ?? '').trim())));
  expect(rows).toHaveLength(141);
  expect(rows.slice(0, 4)).toEqual([
    ['Region', 'Terms', 'Documents'],
    ['3', 'nanking shanghai chinese tientsin', '37,899'],
    ['72', 'sanguily inclosure azcuy inclose', '15,484'],
    ['69', 'pichon lansing jugo clemenceau', '14,228'],
  ]);
  expect(rows.at(-1)).toEqual(['122', 'tittmann cicognani vatican holy', '254']);
  const region = page.getByRole('region', { name: /^Semantic map regions/ });
  await tabTo(page, region);
  await axeCheck(page);

  // What a frame costs here: from a key to its frame done, for ten moves of the view.
  const times = await frameTimes(page, ['+', 'ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp', '+', 'ArrowRight', '-', '-', '0']);
  expect(times).toHaveLength(10);
  // The map's budget under a software renderer is a frame in 100 ms (docs/DEVLOG.md, Session 28b); the suite fails only at
  // ten times it, so that no load fails it, but a renderer as slow as deck.gl's is under SwiftShader does.
  expect(median(times), 'the median frame after a key, done, in ms').toBeLessThan(1_000);
  const renderer = await page.evaluate(() => {
    const gl = document.querySelector<HTMLCanvasElement>('.semantic-map-frame canvas')?.getContext('webgl2');
    const info = gl?.getExtension('WEBGL_debug_renderer_info');
    return gl && info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : 'unknown';
  });
  console.log(
    `semantic map: first frame ${firstFrame} ms after the menu's Enter; a key's frame, done: median ${median(times).toFixed(1)} ms, ` +
      `slowest ${Math.max(...times).toFixed(1)} ms; ${(100 * share).toFixed(1)}% of the frame drawn; renderer ${renderer}`,
  );
});
