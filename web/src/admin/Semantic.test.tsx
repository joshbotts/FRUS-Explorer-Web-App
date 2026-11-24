// Administration ▸ Semantic (PLAN's S27b): Search Model, the model in the image and the encoder, in each of its
// states: idle with the model verified, loaded with its memory and when it stops, off by FRUS_ENCODER, and a
// model that is not the bundled vectors' index's; with nothing to download or remove.
import { cleanup, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SearchModelReport } from '../api/admin';
import type { Me } from '../api/types';
import { me } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const alice: Me = { ...me, userId: 'alice', displayName: 'Alice', auth: 'local' };
const digest = '2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135';

const report = (fields: Partial<SearchModelReport> = {}): SearchModelReport => ({
  setting: 'on',
  state: 'idle',
  model: {
    name: 'embeddinggemma-2-Q8_0',
    file: 'embeddinggemma-2-Q8_0.gguf',
    path: '/usr/share/frus-light/model/embeddinggemma-2-Q8_0.gguf',
    present: true,
    bytes: 309_855_456,
    publishedBytes: 309_855_456,
    sha256: digest,
    bundledSHA256: digest,
    verified: true,
    licence: 'Apache 2.0',
  },
  engine: { path: '/usr/local/bin/llama-server', present: true, version: 'version: 0.6.0-dev (build 1, commit a0e6dc7)', commit: 'a0e6dc7' },
  idleSeconds: 180,
  queries: 0,
  starts: 0,
  maxTokens: 2048,
  ...fields,
});

/** The pane's facts, each term with its definition. */
function facts() {
  const section = screen.getByRole('region', { name: 'Search Model' });
  const terms = within(section).getAllByRole('term').map((term) => term.textContent);
  const definitions = within(section).getAllByRole('definition').map((definition) => definition.textContent);
  return Object.fromEntries(terms.map((term, index) => [term, definitions[index]]));
}

describe('Administration ▸ Semantic', () => {
  it('opens with Search Model: the model in the image, verified, and the encoder idle', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/semantic': report() });
    renderAt('/admin/semantic');
    expect(await screen.findByRole('heading', { level: 1, name: 'Semantic' })).toBeTruthy();
    expect(await screen.findByRole('heading', { level: 2, name: 'Search Model' })).toBeTruthy();
    const panes = screen.getByRole('navigation', { name: 'Administration' });
    expect(within(panes).getByRole('link', { name: 'Semantic' }).getAttribute('aria-current')).toBe('page');
    expect(facts()).toEqual({
      'Search Model': 'In the image and verified — 310 MB on this server.',
      'Model File': '/usr/share/frus-light/model/embeddinggemma-2-Q8_0.gguf',
      Size: '309,855,456 bytes, the length the app publishes',
      'SHA-256': `${digest} The digest the bundled vectors’ index names.`,
      Licence: 'Apache 2.0',
      Engine: 'llama.cpp’s llama-server, commit a0e6dc7',
      Encoder: 'On, and idle: it starts at the next search by meaning.',
      Searches: '0 queries embedded since the server started, in 0 starts',
    });
    expect(screen.getByText(/Google’s EmbeddingGemma 2, 310 MB in the image\. The feature is experimental\.$/)).toBeTruthy();
    expect(within(screen.getByRole('region', { name: 'Search Model' })).queryByRole('button')).toBeNull();
  });

  it('says the encoder is loaded, with its memory and when it stops', async () => {
    const loaded = report({
      state: 'loaded',
      loadedAt: '2026-11-23T18:31:00.000Z',
      stopsAt: '2026-11-23T18:35:00.000Z',
      lastQueryAt: '2026-11-23T18:32:00.000Z',
      pid: 42,
      residentBytes: 445_644_800,
      queries: 3,
      starts: 1,
    });
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/semantic': loaded });
    renderAt('/admin/semantic');
    await screen.findByRole('heading', { level: 2, name: 'Search Model' });
    const since = new Date('2026-11-23T18:31:00.000Z').toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    const stops = new Date('2026-11-23T18:35:00.000Z').toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    expect(facts().Encoder).toBe(
      `On, and loaded since ${since}, holding 446 MB. It stops at ${stops} unless another search comes, 3 minutes after the last, and gives back its memory.`,
    );
    expect(facts().Searches).toBe('3 queries embedded since the server started, in 1 start');
  });

  it('says when FRUS_ENCODER is off', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/semantic': report({ setting: 'off', state: 'off' }) });
    renderAt('/admin/semantic');
    await screen.findByRole('heading', { level: 2, name: 'Search Model' });
    expect(facts().Encoder).toBe('Off: FRUS_ENCODER is off, so it never starts, and this server offers no search by meaning.');
    expect(facts().Searches).toBeUndefined();
  });

  it('says why a model that is not the bundled index’s cannot be used', async () => {
    const other = 'a'.repeat(64);
    const refused = report({
      state: 'unavailable',
      model: { ...report().model, sha256: other, verified: false },
      problem: 'This server cannot search by meaning: its search model is not the one the bundled vectors were made with.',
    });
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/semantic': refused });
    renderAt('/admin/semantic');
    await screen.findByRole('heading', { level: 2, name: 'Search Model' });
    const read = facts();
    expect(read['Search Model']).toBe('In the image, and not the model the bundled vectors were made with: this server cannot search by meaning with it.');
    expect(read['SHA-256']).toBe(`${other} The bundled vectors’ index names ${digest}.`);
    expect(read.Encoder).toBe('On, and it cannot start.');
    expect(read.Problem).toBe('This server cannot search by meaning: its search model is not the one the bundled vectors were made with.');
  });
});
