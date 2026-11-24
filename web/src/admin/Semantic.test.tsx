// Administration ▸ Semantic (PLAN's S27b): Search Model, the model in the image and the encoder, in each of its
// states: idle with the model verified, loaded with its memory and when it stops, off by FRUS_ENCODER, and a
// model that is not the bundled vectors' index's; with nothing to download or remove. Then Vectors (S26c): the
// bundled generation and every shard in the image, checked; a shard refused and one missing, each with why; and
// vectors the server refused whole; with nothing to download or remove either.
import { cleanup, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SearchModelReport, SemanticReport, VectorsReport } from '../api/admin';
import { copy } from '../copy';
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

const generation = '89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101';

/** Every shard in the image, each held to the bundled manifest, as the server reports the image's folder. */
const vectors = (fields: Partial<NonNullable<VectorsReport['shards']>> = {}): VectorsReport => ({
  state: 'available',
  generation: {
    digest: generation,
    name: '89481b18',
    generated: '2026-10-15',
    model: 'embeddinggemma-2-Q8_0',
    nativeDimensions: 768,
    dimensions: 512,
    documents: 314_616,
    volumes: 553,
    rerankPool: 800,
    measuredRecallAt10: 0.9021,
  },
  shards: {
    folder: '/usr/share/frus-light/semantic/shards',
    held: 553,
    heldBytes: 162_377_248,
    published: 553,
    publishedBytes: 162_377_248,
    checked: 553,
    verified: 553,
    refused: [],
    missing: [],
    ...fields,
  },
});

/** The facts of the pane's region `name`, each term with its definition. */
function factsOf(name: string) {
  const section = screen.getByRole('region', { name });
  const terms = within(section).getAllByRole('term').map((term) => term.textContent);
  const definitions = within(section).getAllByRole('definition').map((definition) => definition.textContent);
  return Object.fromEntries(terms.map((term, index) => [term, definitions[index]]));
}

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

  it('gives Vectors: the bundled generation, and every shard in the image, each held to the bundled manifest', async () => {
    const both: SemanticReport = { ...report(), vectors: vectors() };
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/semantic': both });
    renderAt('/admin/semantic');
    expect(await screen.findByRole('heading', { level: 2, name: 'Semantic Vectors' })).toBeTruthy();
    expect(factsOf('Semantic Vectors')).toEqual({
      Generation: `89481b18, made on October 15, 2026 ${generation}`,
      Model: 'embeddinggemma-2-Q8_0, its 768 dimensions cut to 512',
      Documents: '314,616 in 553 volumes',
      'In the Image': '553 of 553 — 162.4 MB of 162.4 MB on this server.',
      Problems: 'Nothing has gone wrong. The server checked all 553 files in its image against the bundled manifest.',
    });
    const section = screen.getByRole('region', { name: 'Semantic Vectors' });
    expect(within(section).getByText(/^The server can find documents on the same subject/)).toBeTruthy();
    // Nothing to download or remove: every shard is the image's.
    expect(within(section).queryByRole('button')).toBeNull();
    expect(within(section).queryByRole('table')).toBeNull();
  });

  it('lists a shard refused and one missing, each with why', async () => {
    const refused = vectors({
      held: 552,
      heldBytes: 162_305_976,
      checked: 552,
      verified: 551,
      refused: [
        {
          volumeId: 'frus1961-63v06',
          reason: 'This file was made for a different version of the app, so it cannot be used with this one.',
          detail: 'Its header names the vectors 00000000; the bundled index’s are 89481b18.',
        },
      ],
      missing: ['frus1894Nicaragua'],
    });
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/semantic': { ...report(), vectors: refused } });
    renderAt('/admin/semantic');
    await screen.findByRole('heading', { level: 2, name: 'Semantic Vectors' });
    const read = factsOf('Semantic Vectors');
    expect(read['In the Image']).toBe('552 of 553 — 162.3 MB of 162.4 MB on this server.');
    expect(read.Problems).toBe('2 found. The server checked all 552 files in its image against the bundled manifest.');
    expect(read.Missing).toBe('1: frus1894Nicaragua. The file is not in the image.');
    const table = screen.getByRole('table', { name: 'The shards this server refused, by volume' });
    const rows = within(table).getAllByRole('row');
    expect(rows.map((row) => row.textContent)).toEqual([
      'VolumeWhy',
      'frus1961-63v06This file was made for a different version of the app, so it cannot be used with this one. Its header names the vectors 00000000; the bundled index’s are 89481b18.',
    ]);
  });

  it('says when the server refused the bundled vectors whole', async () => {
    const whole: VectorsReport = {
      state: 'unavailable',
      problem: 'The bundled vectors are refused: semantic-vectors-binary.bin is not among this server’s data files.',
    };
    stubServer({ '/readyz': ready, '/api/v1/me': alice, '/api/v1/admin/semantic': { ...report(), vectors: whole } });
    renderAt('/admin/semantic');
    await screen.findByRole('heading', { level: 2, name: 'Semantic Vectors' });
    expect(factsOf('Semantic Vectors')).toEqual({
      'Not available':
        'This server cannot match documents by subject, so that part of Related Documents is unavailable. Nothing is wrong with its library.',
      Problem: 'The bundled vectors are refused: semantic-vectors-binary.bin is not among this server’s data files.',
    });
  });

  it('writes a size as the app’s section does', () => {
    const size = copy.admin.semantic.vectors.fileSize;
    expect([0, 1, 999, 1_096, 61_984, 199_368, 999_499, 162_377_248, 1_000_000_000, 1_234_567_890].map(size)).toEqual([
      'Zero KB',
      '1 byte',
      '999 bytes',
      '1 KB',
      '62 KB',
      '199 KB',
      '999 KB',
      '162.4 MB',
      '1 GB',
      '1.23 GB',
    ]);
  });
});
