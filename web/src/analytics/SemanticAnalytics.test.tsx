// Semantic Analytics (PLAN's S28b): the regions' table, largest first, with the app's summary; a browser without WebGL2
// given the table and a sentence, with no points fetched; the map's refusal from the server in the app's words; and an
// answer of the wrong length refused before anything is drawn. jsdom has no WebGL, so the canvas is the browser suite's.
import { cleanup, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { SemanticMapRegions } from '../api/semanticMap';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

const webGL2 = vi.hoisted(() => ({ supported: false }));
vi.mock('./semanticMapRenderer', () => ({
  supportsWebGL2: () => webGL2.supported,
  SemanticMapRenderer: class {
    constructor() {
      throw new Error('jsdom has no WebGL2');
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

function rows() {
  const table = screen.getByRole('table', { name: 'Semantic map regions' });
  return within(table)
    .getAllByRole('row')
    .map((row) => [...row.querySelectorAll('th, td')].map((cell) => cell.textContent));
}

describe('Semantic Analytics', () => {
  it('gives a browser without WebGL2 the regions’ table, largest first, and a sentence, and fetches no points', async () => {
    const server = stubServer({ '/readyz': ready, '/api/v1/semantic/map/regions': regions });
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
    expect(screen.queryByRole('application', { name: 'Semantic map' })).toBeNull();
    expect(server.mock.calls.map(([url]) => new URL(url, 'http://localhost').pathname)).not.toContain('/api/v1/semantic/map');
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
    stubServer({
      '/readyz': ready,
      '/api/v1/semantic/map/regions': regions,
      '/api/v1/semantic/map': () => new Response(new ArrayBuffer(6 * 9), { headers: { 'content-type': 'application/octet-stream' } }),
    });
    renderAt('/analytics/semantic');
    expect(await screen.findByRole('heading', { level: 2, name: 'Map unavailable' })).toBeTruthy();
    expect(screen.getByText('The semantic map could not be read.')).toBeTruthy();
    expect(rows()).toHaveLength(4);
  });

  it('falls back to the sentence when the browser’s WebGL2 fails as the map is made', async () => {
    webGL2.supported = true;
    stubServer({
      '/readyz': ready,
      '/api/v1/semantic/map/regions': regions,
      '/api/v1/semantic/map': () => new Response(new ArrayBuffer(6 * 10), { headers: { 'content-type': 'application/octet-stream' } }),
    });
    renderAt('/analytics/semantic');
    expect(await screen.findByText('This browser cannot draw the map, which needs WebGL2. Its regions are in the table.')).toBeTruthy();
    expect(rows()).toHaveLength(4);
  });
});
