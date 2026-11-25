// Semantic Analytics (PLAN's S28b, S28c): the regions' table, largest first, with the app's summary; a browser without
// WebGL2 given the table and a sentence, with no points fetched; the map's refusal from the server in the app's words;
// and an answer of the wrong length refused before anything is drawn. Since S28c: the lens picker and the scope menu
// with its presidencies, each choice in the address; the keyboard's list of the regions, in the app's words; a link's
// request revealing its document's card, with Open Document, or saying that it has no place on the map; and a region's
// card, the kit's rows from the server, whose documents each show their point. jsdom has no WebGL, so the canvas is
// the browser suite's: here the renderer stands in, drawing nothing.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type {
  SemanticMapPoint,
  SemanticMapReadingContext,
  SemanticMapRegionCard,
  SemanticMapRegions,
  SemanticMapScope,
} from '../api/semanticMap';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

const webGL2 = vi.hoisted(() => ({ supported: false, draws: false }));
vi.mock('./semanticMapRenderer', () => ({
  supportsWebGL2: () => webGL2.supported,
  SemanticMapRenderer: class {
    constructor() {
      if (!webGL2.draws) throw new Error('jsdom has no WebGL2');
    }
    setPoints() {}
    setLens() {}
    setScope() {}
    draw() {}
    dispose() {}
    get maximumSide() {
      return 4096;
    }
  },
}));

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

beforeEach(() => {
  webGL2.supported = false;
  webGL2.draws = false;
});

const regions: SemanticMapRegions = {
  layoutIdentity: '89481b18:2026-10-15:10',
  generated: '2026-10-15',
  documentCount: 10,
  unclusteredCount: 3,
  gridExtent: 30_000,
  method: 'PCA-50 -> UMAP-2 (cosine)',
  clustering: 'HDBSCAN(min_cluster_size=250) over the 2-D embedding',
  regions: [
    { id: 0, terms: ['spanish', 'salazar', 'spain', 'lagen'], documentCount: 2, centreX: -2259, centreY: -10310, eraCounts: { '1': 2 } },
    { id: 1, terms: ['berlin', 'soviet', 'access', 'wall'], documentCount: 3, centreX: 100, centreY: 200, eraCounts: { '2': 3 } },
    { id: 2, terms: ['oil', 'iran', 'shah', 'consortium'], documentCount: 2, centreX: 300, centreY: -400, eraCounts: { '3': 2 } },
  ],
};

const palette = Array.from({ length: 16 }, (_, slot) => [slot / 16, 0.5, 0.5, 0.7] as [number, number, number, number]);

const reading: SemanticMapReadingContext = {
  layoutIdentity: regions.layoutIdentity,
  lenses: [
    { id: 'cluster', name: 'Regions', legend: ['Between regions'], caption: 'Color separates neighboring regions rather than naming them; the names are on the map.', namesEveryColour: false, palette },
    { id: 'era', name: 'Era', legend: ['Before 1900', '1900–1944', '1945–1990', '1991–present'], namesEveryColour: true, palette },
    { id: 'availability', name: 'On This Server', legend: ['Not on this server', 'On this server'], namesEveryColour: true, palette },
  ],
  administrations: [
    { id: 'washington', president: 'George Washington', mappedVolumes: 0 },
    { id: 'nixon', president: 'Richard M. Nixon', mappedVolumes: 3 },
  ],
  mappedVolumes: 553,
};

const whole: SemanticMapScope = {
  documentCount: 10,
  volumeCount: 553,
  mappedVolumes: 553,
  regions: [
    { id: 1, name: 'berlin soviet access', documentCount: 3, accessibilityLabel: 'berlin soviet access, region', accessibilityValue: '3 documents, mostly 1945–1990' },
    { id: 0, name: 'spanish salazar spain', documentCount: 2, accessibilityLabel: 'spanish salazar spain, region', accessibilityValue: '2 documents, mostly 1900–1944' },
  ],
};

const point: SemanticMapPoint = {
  row: 4,
  volumeId: 'frus1961-63v06',
  documentId: 'd1',
  x: 120,
  y: 210,
  regionId: 1,
  regionName: 'berlin soviet access',
  headline: 'Foreign Relations, 1961–1963, Volume VI · d1',
  ids: 'frus1961-63v06 · d1',
  title: '1. Telegram From the Embassy in the Soviet Union',
  served: true,
};

const card: SemanticMapRegionCard = {
  id: 1,
  name: 'berlin soviet access',
  countSummary: '3 documents in the series',
  eraRows: [{ label: '1945–1990', count: '3' }],
  total: 3,
  kept: 3,
  offset: 0,
  documents: [
    { volumeId: 'frus1961-63v06', documentId: 'd1', headline: point.headline, title: point.title, served: true },
    { volumeId: 'frus1969-76v12', documentId: 'd45', headline: 'Foreign Relations, 1969–1976, Volume XII · d45', served: false },
  ],
};

function rows() {
  const table = screen.getByRole('table', { name: 'Semantic map regions' });
  return within(table)
    .getAllByRole('row')
    .map((row) => [...row.querySelectorAll('th, td')].map((cell) => cell.textContent));
}

/** A server serving the map and its reading, with the answers given beside them. */
function serve(more: Record<string, unknown> = {}) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/semantic/map/regions': regions,
    '/api/v1/semantic/map/reading': reading,
    '/api/v1/semantic/map/scope': whole,
    '/api/v1/semantic/map': () => new Response(new ArrayBuffer(6 * 10), { headers: { 'content-type': 'application/octet-stream' } }),
    '/api/v1/semantic/map/lens': () => new Response(new Uint8Array(10), { headers: { 'content-type': 'application/octet-stream' } }),
    ...more,
  });
}

/** A browser whose WebGL2 draws, as far as the page can tell: the renderer stands in, and nothing has a size. */
function drawing() {
  webGL2.supported = true;
  webGL2.draws = true;
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      disconnect() {}
    },
  );
}

describe('Semantic Analytics', () => {
  it('gives a browser without WebGL2 the regions’ table, largest first, and a sentence, and fetches no points', async () => {
    const server = serve();
    renderAt('/analytics/semantic');
    expect(await screen.findByRole('heading', { level: 1, name: 'Semantic Analytics' })).toBeTruthy();
    expect(await screen.findByText('This browser cannot draw the map, which needs WebGL2. Its regions are in the table.')).toBeTruthy();
    expect(rows()).toEqual([
      ['Region', 'Terms', 'Documents'],
      ['1', 'berlin soviet access wall', '3'],
      ['0', 'spanish salazar spain lagen', '2'],
      ['2', 'oil iran shah consortium', '2'],
    ]);
    expect(
      screen.getByText(
        'Semantic map: 3 regions covering 7 documents. 3 more sit between regions and are not listed. Position shows similarity, not time — distances between far-apart regions are not meaningful.',
      ),
    ).toBeTruthy();
    expect(screen.queryByRole('listbox', { name: 'Semantic map' })).toBeNull();
    const asked = server.mock.calls.map(([url]) => new URL(url, 'http://localhost').pathname);
    expect(asked).not.toContain('/api/v1/semantic/map');
    expect(asked).not.toContain('/api/v1/semantic/map/lens');
  });

  it('says why when the server refuses the map', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/semantic/map/regions': new ProblemAnswer(503, 'SEMANTIC_MAP_UNAVAILABLE', 'The map and the vectors come from different releases, so the map is not being drawn.'),
    });
    renderAt('/analytics/semantic');
    expect(await screen.findByRole('heading', { level: 2, name: 'Map unavailable' })).toBeTruthy();
    expect(screen.getByText('The map and the vectors come from different releases, so the map is not being drawn.')).toBeTruthy();
    expect(screen.queryByRole('table')).toBeNull();
  });

  it('refuses points whose length is not the regions’ count, and keeps the table', async () => {
    webGL2.supported = true;
    serve({ '/api/v1/semantic/map': () => new Response(new ArrayBuffer(6 * 9), { headers: { 'content-type': 'application/octet-stream' } }) });
    renderAt('/analytics/semantic');
    expect(await screen.findByRole('heading', { level: 2, name: 'Map unavailable' })).toBeTruthy();
    expect(screen.getByText('The semantic map could not be read.')).toBeTruthy();
    expect(rows()).toHaveLength(4);
  });

  it('falls back to a sentence of its own when the browser’s WebGL2 fails as the map is made', async () => {
    webGL2.supported = true;
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined);
    serve();
    renderAt('/analytics/semantic');
    expect(await screen.findByText('This browser could not draw the map. Its regions are in the table.')).toBeTruthy();
    expect(warn).toHaveBeenCalledWith('Semantic map: jsdom has no WebGL2');
    expect(rows()).toHaveLength(4);
  });

  it('offers the server’s lenses and the scope menu’s presidencies, and puts each choice in the address', async () => {
    serve({
      '/api/v1/semantic/map/scope': (url: URL) =>
        url.searchParams.get('administration') === 'nixon'
          ? { ...whole, label: 'Richard M. Nixon', volumeIds: ['frus1969-76v12'], documentCount: 229, volumeCount: 1, summary: 'In scope: 229 mapped documents — whole volumes, 1 of 553.', regionCounts: { '1': 3 } }
          : whole,
    });
    const { router } = renderAt('/analytics/semantic');
    const lens = await screen.findByRole('combobox', { name: 'Color by' });
    expect(within(lens).getAllByRole('option').map((option) => option.textContent)).toEqual(['Regions', 'Era', 'On This Server']);
    fireEvent.change(lens, { target: { value: 'era' } });
    await waitFor(() => expect(router.state.location.search).toEqual({ lens: 'era' }));

    const scope = screen.getByRole('combobox', { name: 'Analysis scope' });
    const none = within(scope).getByRole('option', { name: 'George Washington — no mapped volumes' }) as HTMLOptionElement;
    expect(none.disabled).toBe(true);
    fireEvent.change(scope, { target: { value: 'administration:nixon' } });
    await waitFor(() => expect(router.state.location.search).toEqual({ lens: 'era', administration: 'nixon' }));
    expect(await screen.findByText('In scope: 229 mapped documents — whole volumes, 1 of 553.')).toBeTruthy();
  });

  it('reveals the document a link names, with its card and Open Document, and lists the regions for the keyboard', async () => {
    drawing();
    const server = serve({ '/api/v1/semantic/map/request': { lens: 'cluster', reveal: { key: 'frus1961-63v06/d1', revealed: true, point, camera: { x: 120, y: 210, halfExtent: 900 }, volumeTitle: 'Foreign Relations, 1961–1963, Volume VI' } } });
    renderAt('/analytics/semantic?document=frus1961-63v06%2Fd1');
    expect(await screen.findByRole('heading', { level: 2, name: point.headline })).toBeTruthy();
    expect(screen.getByText(point.ids)).toBeTruthy();
    expect(screen.getByText(point.title ?? '')).toBeTruthy();
    expect(screen.getByText('berlin soviet access')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Open Document' }).getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    const request = server.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/semantic/map/request');
    expect(request?.searchParams.get('document')).toBe('frus1961-63v06/d1');
    // The canvas's one stop: the regions largest first, each in the app's words.
    const keys = screen.getByRole('listbox', { name: 'Semantic map' });
    expect(within(keys).getAllByRole('option').map((option) => option.textContent)).toEqual([
      'berlin soviet access, region, 3 documents, mostly 1945–1990',
      'spanish salazar spain, region, 2 documents, mostly 1900–1944',
    ]);
    // Escape closes the point's card.
    fireEvent.keyDown(keys, { key: 'Escape' });
    expect(screen.queryByRole('heading', { level: 2, name: point.headline })).toBeNull();
  });

  it('says so when a link names a document with no place on the map', async () => {
    drawing();
    serve({ '/api/v1/semantic/map/request': { lens: 'cluster', reveal: { key: 'frus1961-63v06/ch1', revealed: false, volumeTitle: 'Foreign Relations, 1961–1963, Volume VI' } } });
    renderAt('/analytics/semantic?document=frus1961-63v06%2Fch1');
    expect(await screen.findByRole('heading', { level: 2, name: 'This document has no place on the map' })).toBeTruthy();
    expect(
      screen.getByText(
        'Chapter openers, front matter and appendix material were not included when the map was built, so Foreign Relations, 1961–1963, Volume VI has no point to show. The rest of the series is here.',
      ),
    ).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Dismiss' }));
    expect(screen.queryByRole('heading', { level: 2, name: 'This document has no place on the map' })).toBeNull();
  });

  it('opens a region’s card from the keyboard’s list, and shows one of its documents’ points', async () => {
    drawing();
    const server = serve({
      '/api/v1/semantic/map/regions/1': card,
      '/api/v1/semantic/map/request': (url: URL) =>
        url.searchParams.get('document') === 'frus1961-63v06/d1'
          ? { lens: 'cluster', reveal: { key: 'frus1961-63v06/d1', revealed: true, point, camera: { x: 120, y: 210, halfExtent: 900 }, volumeTitle: 'x' } }
          : { lens: 'cluster' },
    });
    renderAt('/analytics/semantic');
    const keys = await screen.findByRole('listbox', { name: 'Semantic map' });
    fireEvent.focus(keys);
    fireEvent.keyDown(keys, { key: 'Enter' });
    const region = await screen.findByRole('region', { name: 'Region' });
    expect(await within(region).findByText('3 documents in the series')).toBeTruthy();
    expect(within(region).getByText('1945–1990')).toBeTruthy();
    expect(within(region).getByText('Era is the volume’s coverage midpoint, not each document’s own date.')).toBeTruthy();
    expect(within(keys).getAllByRole('option')[0]?.getAttribute('aria-selected')).toBe('true');
    const regionAsk = server.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/semantic/map/regions/1');
    expect(regionAsk?.searchParams.get('layout')).toBe(regions.layoutIdentity);
    // Its documents: the server's headings where it serves them, each showing its point and its card.
    fireEvent.click(within(region).getByRole('button', { name: `Show on the map: ${point.title}` }));
    const heading = await screen.findByRole('heading', { level: 2, name: point.headline });
    await waitFor(() => expect(document.activeElement).toBe(heading));
    expect(within(region).getByRole('button', { name: 'Show on the map: Foreign Relations, 1969–1976, Volume XII · d45' })).toBeTruthy();
    fireEvent.click(within(region).getByRole('button', { name: 'Dismiss region' }));
    expect(screen.queryByRole('region', { name: 'Region' })).toBeNull();
  });
});
