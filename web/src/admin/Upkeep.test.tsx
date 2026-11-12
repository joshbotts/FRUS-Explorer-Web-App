// A Standalone server's side-load and the index's upkeep in Administration (PLAN's S21e): Side-Load a Volume,
// which sends the file as it is; Remove… of an indexed volume, a job; the upgrade's line; Status's index
// upkeep, Compact the Index and Check the Index, and Standalone's reset; and a side-loaded volume's citation,
// with the app's sentence and no link.
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { cleanup, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminIndex, AdminJob, AdminStatus } from '../api/admin';
import type { AdminLibrary, LibraryVolume } from '../api/library';
import type { DocumentCitation, Me } from '../api/types';
import { CitePanel } from '../cite/CitePanel';
import { me } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const alice: Me = { ...me, userId: 'alice', displayName: 'Alice', auth: 'local' };

const volume = (fields: Partial<LibraryVolume> & Pick<LibraryVolume, 'volumeId' | 'status'>): LibraryVolume => ({
  title: `Foreign Relations, ${fields.volumeId}`,
  subseries: '1969-76',
  catalogueBytes: 1_890_303,
  downloaded: false,
  indexed: false,
  sideloaded: false,
  catalogued: true,
  ...fields,
});

function library(volumes: LibraryVolume[], fields: Partial<AdminLibrary> = {}): AdminLibrary {
  const counts: AdminLibrary['counts'] = {};
  for (const { status } of volumes) counts[status] = (counts[status] ?? 0) + 1;
  return { mode: 'standalone', offline: false, downloads: true, source: 'github', counts, indexing: { active: false }, removing: [], volumes, ...fields };
}

const job = (fields: Partial<AdminJob> & Pick<AdminJob, 'id' | 'kind'>): AdminJob => ({
  state: 'queued',
  queuedAt: '2026-11-12T12:00:00.000Z',
  cancellable: true,
  ...fields,
});

const sent = (fetch: ReturnType<typeof stubServer>, method: string, path: string) =>
  fetch.mock.calls.filter(([url, init]) => init?.method === method && new URL(String(url), 'http://localhost').pathname === path);

describe('Administration ▸ Library, a Standalone server’s side-load and removal', () => {
  it('side-loads a chosen file as it is, names its volume, and says why a file is refused', async () => {
    let volumes = [volume({ volumeId: 'frus1894Nicaragua', status: 'indexed', indexed: true, downloaded: true, bytes: 1_273_810 })];
    let refuse = false;
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/library': () => library(volumes),
      'POST /api/v1/admin/library/sideload': () => {
        if (refuse) return new ProblemAnswer(409, 'VOLUME_EXISTS', 'Volume ‘draft-volume’ is already present. Delete it first to replace it.');
        volumes = [...volumes, volume({ volumeId: 'draft-volume', status: 'downloaded', downloaded: true, sideloaded: true, catalogued: false, subseries: 'sideloaded' })];
        return { volumeId: 'draft-volume', catalogued: false, job: job({ id: 'J2', kind: 'libraryIndex', subject: 'draft-volume' }) };
      },
    });
    renderAt('/admin/library');
    const section = await screen.findByRole('region', { name: 'Side-Load a Volume' });
    await userEvent.click(within(section).getByRole('button', { name: 'Side-Load' }));
    expect(within(section).getByRole('alert').textContent).toBe('Choose a volume’s TEI file first.');

    const file = new File(['<TEI xmlns="http://www.tei-c.org/ns/1.0"/>'], 'draft-volume.xml', { type: 'text/xml' });
    await userEvent.upload(within(section).getByLabelText('TEI file'), file);
    await userEvent.click(within(section).getByRole('button', { name: 'Side-Load' }));
    await waitFor(() =>
      expect(screen.getAllByRole('status').some((line) => line.textContent === 'draft-volume is side-loaded: its indexing is queued as a job, which Jobs follows.')).toBe(true),
    );
    const posts = sent(fetch, 'POST', '/api/v1/admin/library/sideload');
    expect(posts).toHaveLength(1);
    const [url, init] = posts[0]!;
    expect(new URL(String(url), 'http://localhost').searchParams.get('file')).toBe('draft-volume.xml');
    expect(init?.body).toBe(file);
    const headers = init?.headers as Record<string, string>;
    expect(headers['Content-Type']).toBe('application/xml');
    expect(headers['X-CSRF-Token']).toBe(alice.csrfToken);
    const table = await screen.findByRole('table', { name: 'The catalogue’s volumes, with what this server holds of each' });
    await waitFor(() => expect(within(table).getByRole('row', { name: /^draft-volume/ })).toBeTruthy());
    const draft = within(table).getByRole('row', { name: /^draft-volume/ });
    expect(within(draft).getByText('Side-loaded', { exact: false })).toBeTruthy();
    // The catalogue does not list it, so nothing can download it.
    expect(within(draft).queryByRole('button', { name: /Download/ })).toBeNull();
    expect(within(draft).getByRole('button', { name: 'Remove draft-volume' })).toBeTruthy();

    refuse = true;
    await userEvent.upload(within(section).getByLabelText('TEI file'), file);
    await userEvent.click(within(section).getByRole('button', { name: 'Side-Load' }));
    await waitFor(() => expect(within(section).getByRole('alert').textContent).toBe('Volume ‘draft-volume’ is already present. Delete it first to replace it.'));
  });

  it('removes an indexed volume through a job after a question that says it leaves the index, and says how far an upgrade is', async () => {
    const volumes = [volume({ volumeId: 'frus1894Nicaragua', status: 'indexed', indexed: true, downloaded: true, bytes: 1_273_810 })];
    let removing: string[] = [];
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/library': () =>
        library(volumes, { removing, indexing: { active: false, upgrade: { from: 73, to: 74, volumes: ['frus1894Nicaragua', 'frus1961-63v06'] } } }),
      'DELETE /api/v1/admin/library/volumes/frus1894Nicaragua': () => {
        removing = ['frus1894Nicaragua'];
        return job({ id: 'J3', kind: 'libraryRemove', subject: 'frus1894Nicaragua' });
      },
    });
    renderAt('/admin/library');
    expect(await screen.findByText('Re-indexing for index version 74: 2 volumes are still to go, while search answers.')).toBeTruthy();
    const table = await screen.findByRole('table', { name: 'The catalogue’s volumes, with what this server holds of each' });
    const row = within(table).getByRole('row', { name: /^frus1894Nicaragua/ });
    await userEvent.click(within(row).getByRole('button', { name: 'Remove frus1894Nicaragua' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Remove frus1894Nicaragua?' });
    expect(within(dialog).getByText(/Its documents leave the index, in a job that Jobs follows/)).toBeTruthy();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Remove' }));
    await waitFor(() =>
      expect(screen.getAllByRole('status').some((line) => line.textContent === 'The removal of frus1894Nicaragua is queued as a job: Jobs follows it.')).toBe(true),
    );
    expect(sent(fetch, 'DELETE', '/api/v1/admin/library/volumes/frus1894Nicaragua')).toHaveLength(1);
    // While its removal waits or runs, the row says so and offers nothing.
    await waitFor(() => expect(within(row).getByText('Being removed, in a job: Jobs follows it.')).toBeTruthy());
    expect(within(row).queryByRole('button')).toBeNull();
  });
});

describe('Administration ▸ Status, a Standalone server’s index upkeep', () => {
  const status: AdminStatus = {
    version: '0.1.0',
    mode: 'standalone',
    auth: 'local',
    userData: true,
    startedAt: '2026-11-12T10:00:00.000Z',
    supportedIndexVersion: 74,
    readiness: { ready: true, step: 'ready', detail: 'Serving 393 documents from 3 volumes, index version 74' },
    index: { documents: 393, volumes: 3, indexVersion: 74, ftsSchemaVersion: 4 },
    catalogueVolumes: 553,
    store: { kind: 'sqlite', migration: 7, latestMigration: 7 },
    backups: { daily: 1, kept: 7, hour: '03:00', timeZone: 'America/New_York', copiedToHost: false },
    keys: { keyFileId: '9f3a6c0d51e27b48', stored: 0 },
    jobs: { queued: 0 },
  };
  const room: AdminIndex = {
    mode: 'standalone',
    upkeep: true,
    storage: {
      fileBytes: 900 * 1_048_576,
      liveBytes: 600 * 1_048_576,
      reclaimableBytes: 300 * 1_048_576,
      availableBytes: 9_000 * 1_048_576,
      requiredBytes: 690 * 1_048_576,
      compaction: 'available',
    },
  };

  it('gives the index’s room with the app’s line, compacts and checks it, and resets it to index the library again', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/status': status,
      '/api/v1/admin/index': room,
      'POST /api/v1/admin/index/compact': () => job({ id: 'J4', kind: 'indexCompact' }),
      'POST /api/v1/admin/index/check': () => job({ id: 'J5', kind: 'indexCheck' }),
      'POST /api/v1/admin/index/reset': () => job({ id: 'J6', kind: 'indexReset' }),
    });
    renderAt('/admin/status');
    const upkeep = await screen.findByRole('region', { name: 'Index upkeep' });
    expect(await within(upkeep).findByText('900.0 MB, of which 300.0 MB is free space a compaction would give back')).toBeTruthy();
    expect(within(upkeep).getByText('300.0 MB of this is free space left by reindexing — 33% of the file.')).toBeTruthy();
    await userEvent.click(within(upkeep).getByRole('button', { name: 'Compact the Index' }));
    await waitFor(() => expect(within(upkeep).getByRole('status').textContent).toContain('The compaction is queued as a job: Jobs follows it.'));
    await userEvent.click(within(upkeep).getByRole('button', { name: 'Check the Index' }));
    await waitFor(() => expect(within(upkeep).getByRole('status').textContent).toContain('The check is queued as a job: Jobs follows it.'));
    expect(sent(fetch, 'POST', '/api/v1/admin/index/compact')).toHaveLength(1);
    expect(sent(fetch, 'POST', '/api/v1/admin/index/check')).toHaveLength(1);

    const recovery = screen.getByRole('region', { name: 'Recovery' });
    expect(within(recovery).getByText(/Empties the index and indexes every volume of the library into it again/)).toBeTruthy();
    await userEvent.click(within(recovery).getByRole('button', { name: 'Reset the Index…' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Reset the index?' });
    expect(within(dialog).getByText(/indexes every volume in its library again/)).toBeTruthy();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Reset' }));
    await waitFor(() => expect(sent(fetch, 'POST', '/api/v1/admin/index/reset')).toHaveLength(1));
  });
});

describe('Cite, a side-loaded volume’s document', () => {
  it('says that the server cannot confirm the volume is published, and offers no link', async () => {
    const note =
      'This volume was side-loaded, not downloaded from the published catalogue. This server cannot confirm it is published, so no history.state.gov link is included — check the citation before using it.';
    const cited: DocumentCitation = {
      volumeId: 'draft-volume',
      documentId: 'd1',
      style: 'historyAtState',
      citation: '_Foreign Relations of the United States_, a draft, Document 1.',
      plainText: 'Foreign Relations of the United States, a draft, Document 1.',
      provenanceNote: note,
      documentNumber: '1',
      documentLabel: 'Doc 1',
      numberSource: 'index',
      publicationYear: 'n.d.',
      bibtex: '@incollection{draft-volume_d1,\n  title     = {d1}\n}',
      ris: 'TY  - CHAP\nTI  - d1\nER  - ',
      styles: [{ style: 'historyAtState', name: 'History at State (Recommended)', shortName: 'history.state.gov' }],
    };
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(JSON.stringify(cited), { headers: { 'content-type': 'application/json' } })),
    );
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <CitePanel volumeId="draft-volume" documentId="d1" autoFocus onClose={() => {}} />
      </QueryClientProvider>,
    );
    expect(await screen.findByText(note)).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Copy URL' })).toBeNull();
    expect(screen.getByRole('button', { name: 'Copy Citation' })).toBeTruthy();
  });
});
