// Administration ▸ Library's Keeping Current and After an Update (PLAN's S21f): Check for Corrections lists the
// volumes changed upstream, a side-loaded copy said, and Update downloads one, or all; After an Update gives the
// kit's tallies, and an Import server's comparison with its TEI folder.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminLibrary } from '../api/library';
import type { AdminUpdates, Corrections } from '../api/reviews';
import { copy } from '../copy';
import { me } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const library = (fields: Partial<AdminLibrary> = {}): AdminLibrary => ({
  mode: 'standalone',
  offline: false,
  downloads: true,
  source: 'github',
  counts: { indexed: 2 },
  indexing: { active: false },
  removing: [],
  volumes: [
    { volumeId: 'frus1894Nicaragua', title: 'Nicaragua', subseries: '1894', catalogueBytes: 1, status: 'indexed', downloaded: true, indexed: true, sideloaded: false, catalogued: true },
    { volumeId: 'frus1961-63v06', title: 'Kennedy-Khrushchev', subseries: '1961-63', catalogueBytes: 1, status: 'indexed', downloaded: true, indexed: true, sideloaded: true, catalogued: true },
  ],
  ...fields,
});

const corrections: Corrections = {
  checkedAt: '2026-11-13T12:00:00.000Z',
  volumes: [
    { volumeId: 'frus1894Nicaragua', title: 'Nicaragua', sideloaded: false, indexed: true },
    { volumeId: 'frus1961-63v06', title: 'Kennedy-Khrushchev', sideloaded: true, indexed: true },
  ],
};

const updates: AdminUpdates = {
  mode: 'standalone',
  totals: { changedDocuments: 3, volumes: 1, annotatedDocuments: 1 },
  volumes: [{ volumeId: 'frus1894Nicaragua', title: 'Nicaragua', changedDocuments: 3, annotatedDocuments: 1, body: 1, apparatus: 0, vanished: 0 }],
};

const sent = (fetch: ReturnType<typeof stubServer>, method: string, path: string) =>
  fetch.mock.calls.filter(([url, init]) => init?.method === method && String(url).endsWith(path)).map(([, init]) => init?.body);

describe('Administration ▸ Library’s corrections', () => {
  it('checks for corrections and updates one volume, then the other with Update All', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/admin/library': library(),
      '/api/v1/admin/library/updates': updates,
      'POST /api/v1/admin/library/corrections': corrections,
      'POST /api/v1/admin/library/downloads': { id: 'J1', kind: 'libraryDownload', subject: 'frus1894Nicaragua', state: 'queued', queuedAt: '2026-11-13T12:00:00.000Z', cancellable: true },
    });
    renderAt('/admin/library');
    const section = await screen.findByRole('region', { name: 'Keeping Current' });
    await userEvent.click(within(section).getByRole('button', { name: 'Check for Corrections' }));
    expect(await within(section).findByText('2 downloaded volumes changed upstream.')).toBeTruthy();
    expect(within(section).getByText(/Your side-loaded copy\. Update replaces it with the published volume\./)).toBeTruthy();
    await userEvent.click(within(section).getByRole('button', { name: 'Update frus1894Nicaragua' }));
    await waitFor(() => expect(sent(fetch, 'POST', '/api/v1/admin/library/downloads')).toEqual(['{"volumeIds":["frus1894Nicaragua"]}']));
    expect(await within(section).findByText('The update of frus1894Nicaragua is queued as a job, which Jobs follows: its indexing follows it.')).toBeTruthy();
    expect(within(section).queryByRole('button', { name: 'Update frus1894Nicaragua' })).toBeNull();
    // After an Update: the kit's tallies, of everyone's research.
    const after = screen.getByRole('region', { name: 'After an Update' });
    expect(await within(after).findByText('3 documents changed in 1 updated volumes. 1 of them carry research on this server.')).toBeTruthy();
    expect(within(after).getByText('1 of 3 changed documents carry research · 1 with changed text')).toBeTruthy();
  });

  it('says when every downloaded volume is up to date, and gives an Import server’s comparison with its TEI folder', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/admin/library': library({ mode: 'import', downloads: false, unavailable: 'An Import server reads the TEI folder.' }),
      '/api/v1/admin/library/updates': {
        ...updates,
        mode: 'import',
        teiCheck: {
          running: false,
          waiting: false,
          recheck: false,
          done: 3,
          total: 3,
          checked: 3,
          changed: ['frus1894Nicaragua'],
          unchecked: [{ volumeId: 'frus1964-68v01', reason: 'Its file is not in the TEI folder.' }],
        },
      },
    });
    renderAt('/admin/library');
    const after = await screen.findByRole('region', { name: 'After an Update' });
    expect(await within(after).findByText('1 of the 3 volumes compared have a document whose TEI changed after the export was indexed.')).toBeTruthy();
    expect(within(after).getByText('frus1964-68v01: Its file is not in the TEI folder.')).toBeTruthy();
    // An Import server downloads nothing, so it offers no check.
    expect(screen.queryByRole('region', { name: 'Keeping Current' })).toBeNull();
  });

  it('says how far an Import server’s comparison has come, while it waits for the jobs it gave way to, and of a re-check', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/admin/library': library({ mode: 'import', downloads: false, unavailable: 'An Import server reads the TEI folder.' }),
      '/api/v1/admin/library/updates': {
        ...updates,
        mode: 'import',
        teiCheck: { running: true, waiting: true, recheck: false, done: 12, total: 553 },
      },
    });
    renderAt('/admin/library');
    const after = await screen.findByRole('region', { name: 'After an Update' });
    expect(
      await within(after).findByText('Comparing the index with the TEI folder: 12 of 553 volumes, going on once the jobs waiting have run.'),
    ).toBeTruthy();
    expect(
      copy.admin.library.teiCheckRunning(0, 1, 'frus1894Nicaragua', false, true),
    ).toBe('Comparing the volumes whose TEI file changed since the last comparison: 0 of 1 volumes, now frus1894Nicaragua.');
  });
});
