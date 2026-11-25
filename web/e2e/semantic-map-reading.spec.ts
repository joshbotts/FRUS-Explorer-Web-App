// S28c's done-when (docs/PLAN.md): Playwright changes the lens, reaches a region and a document by keyboard and opens it,
// and opens the map from a document's rail, on Chromium with no axe violations. Against the image with the synthetic
// export imported, which serves two documents of frus1961-63v06, d1 and d2, both in the region the bundled map names
// "edc nato nuclear", the largest of the 79 of that volume's documents in a region of their own. Scoped to the volume,
// the map ghosts the rest; Color by changes the lens, each with the app's key; the list box over the canvas, the
// canvas's one stop, opens the region's card, whose first document in the scope is d1, shown on the map with its card,
// whence Open Document opens it. The rail's On the Map opens the map on d1, its point revealed; a link that names a
// region opens on its card, in the layout it was named in alone; and a document with no place on the map is said to have
// none.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

/** The map's frame, once it has drawn the view it was asked for with its names laid out for it. */
async function drawn(page: Page, view?: RegExp | string) {
  const map = page.locator('.semantic-map-frame');
  await expect(map).toHaveAttribute('data-view', view ?? /./, { timeout: 60_000 });
  await expect(map).toHaveAttribute('data-names', 'laid-out');
  return map;
}

test('changes the lens, reaches a region and one of its documents by keyboard, and opens the document', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('analytics/semantic?volume=frus1961-63v06');
  await expect(page.getByRole('heading', { level: 1, name: 'Semantic Analytics' })).toBeVisible();
  const map = await drawn(page, '1.000 0 0');
  await expect(map).toHaveAttribute('data-scope', 'volume:frus1961-63v06');
  await expect(page.getByText('In scope: 120 mapped documents — whole volumes, 1 of 553.')).toBeVisible();
  await expect(page.getByRole('combobox', { name: 'Analysis scope' })).toHaveValue('volume:frus1961-63v06');

  // Color by, by keyboard: Era, with its four eras in the key; then On This Server, the app's Downloaded.
  const lens = page.getByRole('combobox', { name: 'Color by' });
  await tabTo(page, lens);
  await expect(lens).toHaveValue('cluster');
  await page.keyboard.press('ArrowDown');
  await expect(page).toHaveURL(/[?&]lens=era(&|$)/);
  await expect(map).toHaveAttribute('data-lens', 'era');
  for (const era of ['Before 1900', '1900–1944', '1945–1990']) await expect(page.getByText(era, { exact: true })).toBeVisible();
  await page.keyboard.press('ArrowDown');
  await expect(map).toHaveAttribute('data-lens', 'availability');
  await expect(page.getByText('Not on this server', { exact: true })).toBeVisible();
  await expect(page.getByText('On this server', { exact: true })).toBeVisible();
  await axeCheck(page);

  // The canvas's one stop: the regions the scope fills, largest first, the first ringed on the map.
  const keys = page.getByRole('listbox', { name: 'Semantic map' });
  await tabTo(page, keys);
  await expect(keys).toHaveAccessibleDescription(/Up and Down move between its regions, largest first, and Enter opens a region’s card/);
  const first = keys.getByRole('option').first();
  await expect(first).toHaveText(/^edc nato nuclear, region, 79 documents/);
  await expect(keys).toHaveAttribute('aria-activedescendant', (await first.getAttribute('id')) ?? '');
  await expect(page.locator('.semantic-map-name.is-active, .semantic-map-ring')).toHaveCount(1);
  await page.keyboard.press('ArrowDown');
  await expect(keys).toHaveAttribute('aria-activedescendant', (await keys.getByRole('option').nth(1).getAttribute('id')) ?? '');
  await page.keyboard.press('ArrowUp');
  await page.keyboard.press('Enter');
  await expect(first).toHaveAttribute('aria-selected', 'true');

  // Its card: the app's, with the kit's headline and era rows, and its documents in the scope, d1 first.
  const region = page.getByRole('region', { name: 'Region', exact: true });
  await expect(region.getByText('edc nato nuclear', { exact: true })).toBeVisible();
  await expect(region.getByText(/ documents in the series · 79 in scope$/)).toBeVisible();
  await expect(region.getByText('Era is the volume’s coverage midpoint, not each document’s own date.')).toBeVisible();
  await expect(region.getByRole('heading', { level: 3, name: 'Its documents in the scope' })).toBeVisible();
  const document = region.getByRole('button', { name: 'Show on the map: 1. Telegram From the Embassy in the Soviet Union' });
  await tabTo(page, document);
  await axeCheck(page);
  await page.keyboard.press('Enter');

  // The document's point, shown on the map, and its card, which takes the focus.
  const point = page.getByRole('region', { name: /· d1$/ });
  await expect(point.getByRole('heading', { level: 2 })).toBeFocused();
  await expect(point.getByText('frus1961-63v06 · d1', { exact: true })).toBeVisible();
  await expect(point.getByText('edc nato nuclear', { exact: true })).toBeVisible();
  await expect(map).toHaveAttribute('data-marker', '-19710 -219');
  await expect(map).toHaveAttribute('data-view', '33.333 -19710 -219');
  const open = point.getByRole('link', { name: 'Open Document' });
  await tabTo(page, open);
  await axeCheck(page);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/doc\/frus1961-63v06\/d1(\?|$)/);
  await expect(page.getByRole('heading', { level: 1, name: /1\. Telegram From the Embassy in the Soviet Union/ })).toBeVisible();
});

test('opens the map from a document’s rail, revealing it, and a link that names a region on its card', async ({ page, request }) => {
  test.setTimeout(120_000);
  await page.goto('doc/frus1961-63v06/d1');
  // The rail's On the Map, after Related, by keyboard.
  const tile = page.getByRole('group', { name: 'Document' }).getByRole('link', { name: 'On the Map', exact: true });
  await expect(tile).toHaveAttribute('title', 'Show where this document sits on the semantic map, among the documents whose language is most like it');
  await tabTo(page, tile);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/analytics\/semantic\?document=frus1961-63v06%2Fd1$/);
  // The document revealed: its point ringed, the camera brought to it, and its card with Open Document.
  const map = await drawn(page, '33.333 -19710 -219');
  await expect(map).toHaveAttribute('data-marker', '-19710 -219');
  const point = page.getByRole('region', { name: /· d1$/ });
  await expect(point.getByText('1. Telegram From the Embassy in the Soviet Union', { exact: true })).toBeVisible();
  await expect(point.getByText('edc nato nuclear', { exact: true })).toBeVisible();
  await expect(point.getByRole('link', { name: 'Open Document' })).toHaveAttribute('href', /\/doc\/frus1961-63v06\/d1$/);
  await axeCheck(page);

  // A document of a volume the server does not serve has its point and its card, which says so.
  await page.goto('analytics/semantic?document=frus1969-76v12%2Fd45');
  await drawn(page, /^33\.333 /);
  const absent = page.getByRole('region', { name: /· d45$/ });
  await expect(absent.getByText('This volume is not on this server.')).toBeVisible();
  await expect(absent.getByRole('link', { name: 'Open Document' })).toHaveCount(0);

  // A link that names a region opens the map on its card, in the layout it was named in; in another, unfocused.
  const regions = (await (await request.get('api/v1/semantic/map/regions')).json()) as { layoutIdentity: string; regions: { id: number; centreX: number; centreY: number }[] };
  const named = regions.regions.find((each) => each.id === 115);
  expect(named).toBeTruthy();
  await page.goto(`analytics/semantic?region=115&layout=${encodeURIComponent(regions.layoutIdentity)}`);
  await drawn(page, `8.333 ${named?.centreX} ${named?.centreY}`);
  await expect(page.getByRole('region', { name: 'Region', exact: true }).getByText('edc nato nuclear', { exact: true })).toBeVisible();
  await expect(page.getByRole('listbox', { name: 'Semantic map' }).getByRole('option', { selected: true })).toHaveText(/^edc nato nuclear, region/);
  await axeCheck(page);
  // The request is answered before the map is read for it, so that a focus landing late would be seen.
  const refused = page.waitForResponse((response) => response.url().includes('/api/v1/semantic/map/request') && response.url().includes('region=115'));
  await page.goto('analytics/semantic?region=115&layout=00000000%3A2026-01-01%3A1');
  expect(((await (await refused).json()) as { focus?: { focused: boolean } }).focus?.focused).toBe(false);
  await drawn(page, '1.000 0 0');
  await expect(page.getByRole('region', { name: 'Region', exact: true })).toHaveCount(0);

  // A document the map has no point for: a chapter's opening.
  await page.goto('analytics/semantic?document=frus1961-63v06%2Fch1');
  await drawn(page, '1.000 0 0');
  const notice = page.getByRole('region', { name: 'This document has no place on the map' });
  await expect(notice.getByText(/^Chapter openers, front matter and appendix material were not included when the map was built, so .+ has no point to show\. The rest of the series is here\.$/)).toBeVisible();
  await axeCheck(page);
});
