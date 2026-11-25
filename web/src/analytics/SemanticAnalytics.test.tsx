// Semantic Analytics (PLAN's S28b, S28c): the regions' table, largest first, with the app's summary; a browser without
// WebGL2 given the table and a sentence, with no points fetched; the map's refusal from the server in the app's words;
// and an answer of the wrong length refused before anything is drawn. Since S28c: the lens picker and the scope menu
// with its presidencies, each choice in the address; the keyboard's list of the regions, in the app's words; a link's
// request revealing its document's card, with Open Document, or saying that it has no place on the map; and a region's
// card, the kit's rows from the server, whose documents each show their point. Since S28e, the map's tools: the axis's
// two poles from points' cards, the slice in the address and Back to the map, a refusal in the app's words; a region's
// save; a point's nearest in language; a lasso's card and its save; and the regions' CSV. jsdom has no WebGL, so the
// canvas is the browser suite's: here the renderer stands in, drawing nothing.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type {
  SemanticMapLassoAnswer,
  SemanticMapNearest,
  SemanticMapPoint,
  SemanticMapReadingContext,
  SemanticMapRegionCard,
  SemanticMapRegions,
  SemanticMapScope,
  SemanticMapSlice,
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
    release() {}
    get maximumSide() {
      return 4096;
    }
  },
}));

const saved = vi.hoisted(() => ({ files: [] as { name: string }[] }));
vi.mock('../shell/saveFile', () => ({
  saveFile: (_file: Blob, name: string) => saved.files.push({ name }),
}));

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

beforeEach(() => {
  webGL2.supported = false;
  webGL2.draws = false;
  saved.files = [];
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
  total: 2,
  kept: 2,
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
    // Said in a region that was there before it.
    expect(screen.getAllByRole('status').some((status) => status.textContent === 'This document has no place on the map')).toBe(true);
    fireEvent.click(screen.getByRole('button', { name: 'Dismiss' }));
    expect(screen.queryByRole('heading', { level: 2, name: 'This document has no place on the map' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('listbox', { name: 'Semantic map' }));
  });

  it('drops a point’s card when the scope changes, and does not bring it back with the scope', async () => {
    drawing();
    serve({ '/api/v1/semantic/map/request': { lens: 'cluster', reveal: { key: 'frus1961-63v06/d1', revealed: true, point, camera: { x: 120, y: 210, halfExtent: 900 }, volumeTitle: 'x' } } });
    renderAt('/analytics/semantic?document=frus1961-63v06%2Fd1');
    expect(await screen.findByRole('heading', { level: 2, name: point.headline })).toBeTruthy();
    const scope = screen.getByRole('combobox', { name: 'Analysis scope' });
    fireEvent.change(scope, { target: { value: 'administration:nixon' } });
    await waitFor(() => expect(screen.queryByRole('heading', { level: 2, name: point.headline })).toBeNull());
    fireEvent.change(scope, { target: { value: 'whole' } });
    await waitFor(() => expect((scope as HTMLSelectElement).value).toBe('whole'));
    expect(screen.queryByRole('heading', { level: 2, name: point.headline })).toBeNull();
  });

  it('says why when the lenses cannot be read, rather than waiting for them', async () => {
    drawing();
    serve({ '/api/v1/semantic/map/reading': new ProblemAnswer(503, 'SEMANTIC_MAP_UNAVAILABLE', 'The semantic map could not be read: a test.') });
    renderAt('/analytics/semantic');
    expect(await screen.findByText('The semantic map could not be read: a test.')).toBeTruthy();
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
    const shower = within(region).getByRole('button', { name: `Show on the map: ${point.title}` });
    fireEvent.click(shower);
    const heading = await screen.findByRole('heading', { level: 2, name: point.headline });
    await waitFor(() => expect(document.activeElement).toBe(heading));
    expect(within(region).getByRole('button', { name: 'Show on the map: Foreign Relations, 1969–1976, Volume XII · d45' })).toBeTruthy();
    expect(within(region).getByText('2 of 2, in their volumes’ order.')).toBeTruthy();
    expect(within(region).queryByRole('button', { name: 'Show More' })).toBeNull();
    // Closing the point's card sends the keyboard back to the document that showed it, and the region's to the map.
    fireEvent.click(screen.getByRole('button', { name: 'Dismiss' }));
    expect(screen.queryByRole('heading', { level: 2, name: point.headline })).toBeNull();
    expect(document.activeElement).toBe(shower);
    fireEvent.click(within(region).getByRole('button', { name: 'Dismiss region' }));
    expect(screen.queryByRole('region', { name: 'Region' })).toBeNull();
    expect(document.activeElement).toBe(keys);
  });

  it('lists a region’s documents a page at a time, through the capture, and says where the capture stops', async () => {
    drawing();
    const many = (offset: number, count: number) =>
      Array.from({ length: count }, (_, at) => ({ volumeId: 'frus1969-76v12', documentId: `d${offset + at + 1}`, headline: `Volume XII · d${offset + at + 1}`, served: false }));
    const server = serve({
      '/api/v1/semantic/map/regions/1': (url: URL) => {
        const offset = Number(url.searchParams.get('offset'));
        return { ...card, total: 9_000, kept: 60, offset, documents: many(offset, Math.min(50, 60 - offset)) };
      },
    });
    renderAt('/analytics/semantic');
    const keys = await screen.findByRole('listbox', { name: 'Semantic map' });
    fireEvent.focus(keys);
    fireEvent.keyDown(keys, { key: 'Enter' });
    const region = await screen.findByRole('region', { name: 'Region' });
    expect(await within(region).findByText('50 of 9,000, in their volumes’ order.')).toBeTruthy();
    fireEvent.click(within(region).getByRole('button', { name: 'Show More' }));
    expect(await within(region).findByText('60 of 9,000, in their volumes’ order. The first 60 of 9,000 can be listed here.')).toBeTruthy();
    expect(within(region).queryByRole('button', { name: 'Show More' })).toBeNull();
    await waitFor(() => expect(document.activeElement).toBe(within(region).getByRole('button', { name: 'Show on the map: Volume XII · d51' })));
    const offsets = server.mock.calls
      .map(([url]) => new URL(url, 'http://localhost'))
      .filter((url) => url.pathname === '/api/v1/semantic/map/regions/1')
      .map((url) => `${url.searchParams.get('offset')}+${url.searchParams.get('limit')}`);
    expect(offsets).toEqual(['0+50', '50+50']);
  });
});

describe('the map’s tools (S28e)', () => {
  const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
  const far: SemanticMapPoint = {
    ...point,
    row: 7,
    volumeId: 'frus1969-76v12',
    documentId: 'd45',
    x: -500,
    y: 600,
    headline: 'Foreign Relations, 1969–1976, Volume XII · d45',
    ids: 'frus1969-76v12 · d45',
    title: undefined,
    served: false,
  };
  const nearest: SemanticMapNearest = {
    document: 'frus1961-63v06/d1',
    neighbours: [
      { volumeId: 'frus1961-63v06', documentId: 'd2', title: '2. Letter From President Kennedy to Chairman Khrushchev', score: 0.8712, percent: 87 },
      { volumeId: 'frus1969-76ve09p1', documentId: 'd10', title: '10. Memorandum of Conversation', score: 0.6049, percent: 60 },
    ],
  };
  const slice: SemanticMapSlice = {
    from: 'frus1961-63v06',
    to: 'frus1969-76v12',
    gridExtent: 30_000,
    scale: { minYear: 1862, maxYear: 1988, undatedCount: 0 },
    ticks: [{ year: 1875, y: -24_000 }, { year: 1925, y: -2_000 }, { year: 1975, y: 20_000 }],
    caveat: 'Left to right is how far each document leans from frus1961-63v06 toward frus1969-76v12. The reading is approximate.',
  };
  /** A point of the slice's: row 4, d1's, at 1,000 and 2,000; the rest at the middle. */
  function slicePoints() {
    const bytes = new ArrayBuffer(6 * 10);
    const view = new DataView(bytes);
    view.setInt16(4 * 6, 1_000, true);
    view.setInt16(4 * 6 + 2, 2_000, true);
    return new Response(bytes, { headers: { 'content-type': 'application/octet-stream' } });
  }
  const reveals = (url: URL) =>
    url.searchParams.get('document') === 'frus1961-63v06/d1'
      ? { lens: 'cluster', reveal: { key: 'frus1961-63v06/d1', revealed: true, point, camera: { x: 120, y: 210, halfExtent: 900 }, volumeTitle: 'x' } }
      : url.searchParams.get('document') === 'frus1969-76v12/d45'
        ? { lens: 'cluster', reveal: { key: 'frus1969-76v12/d45', revealed: true, point: far, camera: { x: -500, y: 600, halfExtent: 900 }, volumeTitle: 'x' } }
        : { lens: 'cluster' };

  it('sets the axis’s two poles from points’ cards, lays out the slice in the address, and goes back to the map', async () => {
    drawing();
    const server = serve({
      '/api/v1/semantic/map/regions/1': card,
      '/api/v1/semantic/map/request': reveals,
      '/api/v1/semantic/map/nearest': nearest,
      '/api/v1/semantic/map/slice': slice,
      '/api/v1/semantic/map/slice/points': slicePoints,
    });
    const { router } = renderAt('/analytics/semantic?document=frus1961-63v06%2Fd1');
    const card1 = await screen.findByRole('region', { name: point.headline });
    // What a slice adds, until one is drawn, and the two ends, the high one once the low is set.
    expect(within(card1).getByText(/^On the map no direction has a meaning\./)).toBeTruthy();
    const to = within(card1).getByRole('button', { name: '…to here' }) as HTMLButtonElement;
    expect(to.disabled).toBe(true);
    fireEvent.click(within(card1).getByRole('button', { name: 'Axis: from here' }));
    const axis = await screen.findByRole('region', { name: 'Axis' });
    expect(within(axis).getByText('frus1961-63v06')).toBeTruthy();
    expect(within(axis).getByText(/^Select a document in a different volume and choose “…to here”\./)).toBeTruthy();
    expect(to.disabled).toBe(false);
    // Another volume's document, from a region's card, as the high end: the server lays the slice out.
    const keys = screen.getByRole('listbox', { name: 'Semantic map' });
    fireEvent.focus(keys);
    fireEvent.keyDown(keys, { key: 'Enter' });
    const region = await screen.findByRole('region', { name: 'Region' });
    fireEvent.click(await within(region).findByRole('button', { name: 'Show on the map: Foreign Relations, 1969–1976, Volume XII · d45' }));
    const card45 = await screen.findByRole('region', { name: far.headline });
    fireEvent.click(within(card45).getByRole('button', { name: '…to here' }));
    await waitFor(() => expect(router.state.location.search).toEqual({ document: 'frus1961-63v06/d1', from: 'frus1961-63v06', to: 'frus1969-76v12' }));
    expect(await within(axis).findByText('frus1961-63v06 → frus1969-76v12')).toBeTruthy();
    expect(await screen.findByText(slice.caveat ?? '')).toBeTruthy();
    await waitFor(() => expect(document.querySelector('.semantic-map-frame')?.getAttribute('data-layout')).toBe('slice:frus1961-63v06|frus1969-76v12'));
    // No names on a slice; its scale is drawn over the canvas, which jsdom gives no size (the browser suite reads it).
    expect(document.querySelector('.semantic-map-frame')?.getAttribute('data-names')).toBe('none');
    const asked = server.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/semantic/map/slice');
    expect(asked?.searchParams.get('from')).toBe('frus1961-63v06');
    expect(asked?.searchParams.get('to')).toBe('frus1969-76v12');
    // Back to the map: the poles cleared, the map's plane again, and the keyboard on the map.
    fireEvent.click(within(axis).getByRole('button', { name: 'Back to the map' }));
    await waitFor(() => expect(router.state.location.search).toEqual({ document: 'frus1961-63v06/d1' }));
    expect(screen.queryByRole('region', { name: 'Axis' })).toBeNull();
    expect(document.activeElement).toBe(keys);
    await waitFor(() => expect(document.querySelector('.semantic-map-frame')?.getAttribute('data-layout')).toBe('map'));
    expect(screen.getByText('Layout preserves local similarity; distances between far regions are not meaningful.')).toBeTruthy();
  });

  it('opens a slice the address names, and shows a document at its place on the slice', async () => {
    drawing();
    serve({ '/api/v1/semantic/map/request': reveals, '/api/v1/semantic/map/nearest': nearest, '/api/v1/semantic/map/slice': slice, '/api/v1/semantic/map/slice/points': slicePoints });
    renderAt('/analytics/semantic?document=frus1961-63v06%2Fd1&from=frus1961-63v06&to=frus1969-76v12');
    expect(await screen.findByRole('region', { name: point.headline })).toBeTruthy();
    const map = document.querySelector('.semantic-map-frame');
    await waitFor(() => expect(map?.getAttribute('data-marker')).toBe('1000 2000'));
    expect(map?.getAttribute('data-layout')).toBe('slice:frus1961-63v06|frus1969-76v12');
    // On a slice, a point's card no longer says what a slice adds.
    expect(screen.queryByText(/^On the map no direction has a meaning\./)).toBeNull();
  });

  it('refuses two ends in one volume in the app’s words, and keeps the low end', async () => {
    drawing();
    serve({
      '/api/v1/semantic/map/request': reveals,
      '/api/v1/semantic/map/nearest': nearest,
      '/api/v1/semantic/map/slice': {
        from: 'frus1961-63v06',
        to: 'frus1961-63v06',
        refusal: { reason: 'sameVolume', notice: 'An axis runs between two volumes, and both of these documents are in the same one. Pick a document from a different volume as the second end.' },
      },
    });
    const { router } = renderAt('/analytics/semantic?document=frus1961-63v06%2Fd1');
    const card1 = await screen.findByRole('region', { name: point.headline });
    fireEvent.click(within(card1).getByRole('button', { name: 'Axis: from here' }));
    fireEvent.click(within(card1).getByRole('button', { name: '…to here' }));
    const axis = await screen.findByRole('region', { name: 'Axis' });
    expect(await within(axis).findByText(/^An axis runs between two volumes, and both of these documents are in the same one\./)).toBeTruthy();
    expect(within(axis).getByRole('status').textContent).toMatch(/^An axis runs between two volumes/);
    expect(within(axis).getByText('frus1961-63v06')).toBeTruthy();
    expect(router.state.location.search).toEqual({ document: 'frus1961-63v06/d1' });
    // The low end stands, so the high end may be chosen again.
    expect((within(card1).getByRole('button', { name: '…to here' }) as HTMLButtonElement).disabled).toBe(false);
    // Clearing the axis takes the notice with it.
    fireEvent.click(within(axis).getByRole('button', { name: 'Clear axis and return to the map' }));
    expect(screen.queryByRole('region', { name: 'Axis' })).toBeNull();
  });

  it('lists a point’s nearest in language, each showing its point, and says why there are none', async () => {
    drawing();
    const server = serve({
      '/api/v1/semantic/map/request': reveals,
      '/api/v1/semantic/map/nearest': (url: URL) =>
        url.searchParams.get('document') === 'frus1961-63v06/d1' ? nearest : { document: url.searchParams.get('document'), neighbours: [], empty: 'noShard' },
      '/api/v1/semantic/map/regions/1': card,
    });
    renderAt('/analytics/semantic?document=frus1961-63v06%2Fd1');
    const card1 = await screen.findByRole('region', { name: point.headline });
    const list = await within(card1).findByRole('list', { name: 'Nearest in language' });
    expect(within(list).getAllByRole('listitem').map((item) => item.textContent)).toEqual([
      '2. Letter From President Kennedy to Chairman Khrushchev87%',
      '10. Memorandum of Conversation60%',
    ]);
    expect(within(card1).getByText(/^Drawn only from volumes on this server/)).toBeTruthy();
    fireEvent.click(within(list).getByRole('button', { name: '10. Memorandum of Conversation' }));
    await waitFor(() =>
      expect(
        server.mock.calls.some(([url]) => new URL(url, 'http://localhost').searchParams.get('document') === 'frus1969-76ve09p1/d10'),
      ).toBe(true),
    );
    // A point whose vectors the server lacks says so.
    const keys = screen.getByRole('listbox', { name: 'Semantic map' });
    fireEvent.focus(keys);
    fireEvent.keyDown(keys, { key: 'Enter' });
    const region = await screen.findByRole('region', { name: 'Region' });
    fireEvent.click(await within(region).findByRole('button', { name: 'Show on the map: Foreign Relations, 1969–1976, Volume XII · d45' }));
    const card45 = await screen.findByRole('region', { name: far.headline });
    expect(await within(card45).findByText('Finding nearest documents needs this volume’s vectors, which are not on this server.')).toBeTruthy();
  });

  it('saves a region as a working corpus where the server keeps user data, and says where it is', async () => {
    drawing();
    const server = serve({
      '/api/v1/me': me,
      '/api/v1/semantic/map/regions/1': { ...card, total: 9_000, kept: 7_500 },
      'POST /api/v1/me/working-corpora/region': {
        id: 'c1',
        name: 'berlin soviet access — Nov 25, 2026 at 9:41 AM',
        documentCount: 7_500,
        wasTruncatedAtCapture: true,
        totalMatchCountAtCapture: 9_000,
        truncationWarns: true,
        isMeaningCapture: false,
      },
    });
    renderAt('/analytics/semantic?volume=frus1961-63v06');
    const keys = await screen.findByRole('listbox', { name: 'Semantic map' });
    fireEvent.focus(keys);
    fireEvent.keyDown(keys, { key: 'Enter' });
    const region = await screen.findByRole('region', { name: 'Region' });
    fireEvent.click(await within(region).findByRole('button', { name: 'Save as Working Corpus' }));
    const line = await within(region).findByText('Saved as “berlin soviet access — Nov 25, 2026 at 9:41 AM”. Find it under Working Corpora, where it can scope a search.');
    await waitFor(() => expect(document.activeElement).toBe(line));
    expect(within(region).getByText('Saved the first 7,500 of 9,000.')).toBeTruthy();
    expect(within(region).queryByRole('button', { name: 'Save as Working Corpus' })).toBeNull();
    const [url, init] = server.mock.calls.find(([, init]) => init?.method === 'POST') ?? [];
    const asked = new URL(url ?? '', 'http://localhost');
    expect(asked.pathname).toBe('/api/v1/me/working-corpora/region');
    expect(asked.searchParams.get('volume')).toBe('frus1961-63v06');
    expect(JSON.parse(String(init?.body))).toMatchObject({ region: 1, layout: regions.layoutIdentity });
  });

  it('offers no save on a server that keeps no user data', async () => {
    drawing();
    serve({ '/api/v1/me': { ...me, userData: false }, '/api/v1/semantic/map/regions/1': card });
    renderAt('/analytics/semantic');
    const keys = await screen.findByRole('listbox', { name: 'Semantic map' });
    fireEvent.focus(keys);
    fireEvent.keyDown(keys, { key: 'Enter' });
    const region = await screen.findByRole('region', { name: 'Region' });
    expect(await within(region).findByText('3 documents in the series')).toBeTruthy();
    expect(within(region).queryByRole('button', { name: 'Save as Working Corpus' })).toBeNull();
  });

  it('draws a lasso by pointer with Lasso on, says what it caught as the app’s card does, and saves it', async () => {
    drawing();
    // jsdom captures no pointer.
    Object.defineProperty(HTMLElement.prototype, 'setPointerCapture', { value: () => undefined, configurable: true, writable: true });
    const caught: SemanticMapLassoAnswer = {
      scoped: false,
      capture: {
        total: 9_120,
        kept: 7_500,
        regionNames: ['berlin soviet', 'spanish salazar'],
        coverage: { indexedCount: 80, totalCount: 7_500, missingVolumeIds: ['frus1969-76v12'], isComplete: false },
      },
    };
    const server = serve({
      '/api/v1/me': me,
      'POST /api/v1/semantic/map/lasso': caught,
      'POST /api/v1/me/working-corpora/lasso': { id: 'c2', name: 'berlin soviet, spanish salazar — Nov 25, 2026 at 9:42 AM', documentCount: 7_500 },
    });
    renderAt('/analytics/semantic');
    await screen.findByRole('listbox', { name: 'Semantic map' });
    const lasso = screen.getByRole('button', { name: 'Lasso' });
    expect(lasso.getAttribute('aria-pressed')).toBe('false');
    fireEvent.click(lasso);
    expect(lasso.getAttribute('aria-pressed')).toBe('true');
    const frame = document.querySelector('.semantic-map-frame') as HTMLElement;
    expect(frame.getAttribute('data-lassoing')).toBe('true');
    fireEvent.pointerDown(frame, { pointerId: 1, pointerType: 'mouse', button: 0, buttons: 1, clientX: 10, clientY: 10 });
    for (const [x, y] of [[12, 11], [60, 10], [60, 60], [10, 60]]) {
      fireEvent.pointerMove(frame, { pointerId: 1, pointerType: 'mouse', buttons: 1, clientX: x, clientY: y });
    }
    fireEvent.pointerUp(frame, { pointerId: 1, pointerType: 'mouse', button: 0, clientX: 10, clientY: 60 });
    const card = await screen.findByRole('region', { name: 'Lasso' });
    expect(within(card).getByRole('heading', { level: 2, name: '9,120 documents' })).toBeTruthy();
    expect(within(card).getByText('berlin soviet · spanish salazar')).toBeTruthy();
    expect(within(card).getByRole('img', { name: 'Source: computed by this app.' }).textContent).toContain('This app\'s model');
    expect(within(card).getByText('Saving the first 7,500 of 9,120.')).toBeTruthy();
    expect(within(card).getByText('80 of 7,500 documents indexed on this server')).toBeTruthy();
    // The stroke as it was sent: thinned at four pixels, its first point, then three more, the second dropped.
    const sent = server.mock.calls.find(([url, init]) => init?.method === 'POST' && String(url).includes('/semantic/map/lasso'));
    expect((JSON.parse(String(sent?.[1]?.body)) as { polygon: number[][] }).polygon).toHaveLength(4);
    fireEvent.click(within(card).getByRole('button', { name: 'Save as Working Corpus' }));
    const line = await within(card).findByText('Saved as berlin soviet, spanish salazar — Nov 25, 2026 at 9:42 AM');
    await waitFor(() => expect(document.activeElement).toBe(line.closest('p')));
    // Lasso off drops the card, as the app's toggle does.
    fireEvent.click(lasso);
    expect(screen.queryByRole('region', { name: 'Lasso' })).toBeNull();
  });

  it('says why a slice the address names could not be drawn, and draws the map', async () => {
    drawing();
    serve({
      '/api/v1/semantic/map/slice': slice,
      '/api/v1/semantic/map/slice/points': new ProblemAnswer(503, 'SEMANTIC_MAP_UNAVAILABLE', 'The semantic map could not be read: a test.'),
    });
    renderAt('/analytics/semantic?from=frus1961-63v06&to=frus1969-76v12');
    const axis = await screen.findByRole('region', { name: 'Axis' });
    expect(await within(axis).findByText('The semantic map could not be read: a test.')).toBeTruthy();
    expect(within(axis).queryByText(/^Select a document in a different volume/)).toBeNull();
    expect(document.querySelector('.semantic-map-frame')?.getAttribute('data-layout')).toBe('map');
  });

  it('never draws a slice again once the map has been, while the next slice comes', async () => {
    drawing();
    const other: SemanticMapSlice = { ...slice, from: 'frus1969-76v12', to: 'frus1961-63v06' };
    serve({
      '/api/v1/semantic/map/request': reveals,
      '/api/v1/semantic/map/nearest': nearest,
      '/api/v1/semantic/map/slice': (url: URL) => (url.searchParams.get('from') === 'frus1961-63v06' ? slice : other),
      // The second slice's points never come.
      '/api/v1/semantic/map/slice/points': (url: URL) => (url.searchParams.get('from') === 'frus1961-63v06' ? slicePoints() : new Promise(() => undefined)),
    });
    const { router } = renderAt('/analytics/semantic?document=frus1961-63v06%2Fd1&from=frus1961-63v06&to=frus1969-76v12');
    const map = await waitFor(() => {
      const frame = document.querySelector('.semantic-map-frame');
      expect(frame?.getAttribute('data-layout')).toBe('slice:frus1961-63v06|frus1969-76v12');
      return frame;
    });
    const axis = await screen.findByRole('region', { name: 'Axis' });
    expect(within(axis).getByRole('status').textContent).toBe('Laid out from frus1961-63v06 to frus1969-76v12.');
    expect(within(axis).getByText('Up the side, the years 1862 to 1988.')).toBeTruthy();
    fireEvent.click(within(axis).getByRole('button', { name: 'Back to the map' }));
    await waitFor(() => expect(map?.getAttribute('data-layout')).toBe('map'));
    // The next slice, laid out but its points on their way: the map stays drawn, and the card says it is coming.
    await router.navigate({ to: '/analytics/semantic', search: { document: 'frus1961-63v06/d1', from: 'frus1969-76v12', to: 'frus1961-63v06' } });
    const coming = await screen.findByRole('region', { name: 'Axis' });
    await waitFor(() => expect(within(coming).getByRole('status').textContent).toBe('Laying out the slice…'));
    expect(map?.getAttribute('data-layout')).toBe('map');
  });

  it('drops a lasso’s answer still on its way when Lasso is turned off, and says why a lasso could not be read', async () => {
    drawing();
    Object.defineProperty(HTMLElement.prototype, 'setPointerCapture', { value: () => undefined, configurable: true, writable: true });
    let answer: (value: SemanticMapLassoAnswer) => void = () => undefined;
    let fail = false;
    serve({
      'POST /api/v1/semantic/map/lasso': () =>
        fail
          ? new ProblemAnswer(400, 'INVALID_PARAMETER', 'polygon: each point is two finite numbers on the map’s grid')
          : new Promise<SemanticMapLassoAnswer>((resolve) => {
              answer = resolve;
            }),
    });
    renderAt('/analytics/semantic');
    await screen.findByRole('listbox', { name: 'Semantic map' });
    const lasso = screen.getByRole('button', { name: 'Lasso' });
    const frame = document.querySelector('.semantic-map-frame') as HTMLElement;
    const draw = () => {
      fireEvent.pointerDown(frame, { pointerId: 1, pointerType: 'mouse', button: 0, buttons: 1, clientX: 10, clientY: 10 });
      for (const [x, y] of [[60, 10], [60, 60], [10, 60]]) fireEvent.pointerMove(frame, { pointerId: 1, pointerType: 'mouse', buttons: 1, clientX: x, clientY: y });
      fireEvent.pointerUp(frame, { pointerId: 1, pointerType: 'mouse', button: 0, clientX: 10, clientY: 60 });
    };
    fireEvent.click(lasso);
    draw();
    await waitFor(() => expect(screen.getAllByRole('status').some((status) => status.textContent === 'Gathering what the lasso enclosed…')).toBe(true));
    fireEvent.click(lasso);
    answer({ scoped: false, capture: { total: 3, kept: 3, regionNames: ['berlin soviet'] } });
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(screen.queryByRole('region', { name: 'Lasso' })).toBeNull();
    // A lasso the server refuses says why, as an alert.
    fail = true;
    fireEvent.click(lasso);
    draw();
    expect(await screen.findByText('polygon: each point is two finite numbers on the map’s grid')).toBeTruthy();
    expect(screen.getByRole('alert').textContent).toMatch(/^The lasso could not be read\./);
  });

  it('exports the regions’ CSV under the scope with the lens drawn', async () => {
    drawing();
    const server = serve({
      '/api/v1/semantic/map/export': () =>
        new Response('# Semantic map regions\nRegion,Terms\n', {
          headers: { 'content-type': 'text/csv', 'content-disposition': 'attachment; filename="FRUS-Analytics-Semantic-map-regions-2026-11-25.csv"' },
        }),
    });
    renderAt('/analytics/semantic?volume=frus1961-63v06&lens=era');
    await screen.findByRole('listbox', { name: 'Semantic map' });
    fireEvent.click(screen.getByRole('button', { name: 'Export map data' }));
    expect(await screen.findByRole('menuitem', { name: 'Figure (PNG)…' })).toBeTruthy();
    fireEvent.click(screen.getByRole('menuitem', { name: 'Chart data (CSV)…' }));
    await waitFor(() => expect(saved.files).toEqual([{ name: 'FRUS-Analytics-Semantic-map-regions-2026-11-25.csv' }]));
    const asked = server.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/semantic/map/export');
    expect(asked?.searchParams.get('volume')).toBe('frus1961-63v06');
    expect(asked?.searchParams.get('lens')).toBe('era');
    expect(asked?.searchParams.get('timeZone')).toBeTruthy();
  });
});
