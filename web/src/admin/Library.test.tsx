// Administration ▸ Library (PLAN's S21c): the catalogue's volumes with their states, a download of one or
// of all, a removal after a question, and an Import server's or an offline server's Library, which
// downloads nothing and says why; and the library's indexing (S21d), Index for one and for all waiting.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdminJob } from '../api/admin';
import type { AdminLibrary, LibraryVolume } from '../api/library';
import type { Me } from '../api/types';
import { me } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';

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
  ...fields,
});

function library(volumes: LibraryVolume[], fields: Partial<AdminLibrary> = {}): AdminLibrary {
  const counts: AdminLibrary['counts'] = {};
  for (const { status } of volumes) counts[status] = (counts[status] ?? 0) + 1;
  return { mode: 'standalone', offline: false, downloads: true, source: 'github', counts, indexing: { active: false }, volumes, ...fields };
}

const job: AdminJob = { id: 'J1', kind: 'libraryDownload', subject: 'frus1894Nicaragua', state: 'queued', queuedAt: '2026-11-11T12:00:00.000Z', cancellable: true };

const sent = (fetch: ReturnType<typeof stubServer>, method: string, path: string) =>
  fetch.mock.calls.filter(([url, init]) => init?.method === method && String(url).endsWith(path));

describe('Administration ▸ Library', () => {
  it('lists each volume with its state, downloads one and removes another after a question', async () => {
    let volumes = [
      volume({ volumeId: 'frus1894Nicaragua', status: 'notDownloaded', catalogueBytes: 1_273_810 }),
      volume({
        volumeId: 'frus1969-76ve09p1',
        status: 'downloaded',
        downloaded: true,
        bytes: 1_890_303,
        downloadedAt: '2026-11-11T11:00:00.000Z',
        figures: 7,
        figuresRefused: 1,
      }),
      volume({ volumeId: 'frus1961-63v06', status: 'failed', error: 'api.github.com answered 500.' }),
      volume({ volumeId: 'frus1969-76v01', status: 'indexed', indexed: true }),
    ];
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/library': () => library(volumes),
      'POST /api/v1/admin/library/downloads': () => {
        volumes = [{ ...volumes[0]!, status: 'queued', requestedBy: 'alice' }, ...volumes.slice(1)];
        return job;
      },
      'DELETE /api/v1/admin/library/volumes/frus1969-76ve09p1': () => {
        volumes = [volumes[0]!, { ...volumes[1]!, status: 'notDownloaded', downloaded: false, bytes: undefined }, ...volumes.slice(2)];
        return null;
      },
    });
    renderAt('/admin/library');
    const table = await screen.findByRole('table', { name: 'The catalogue’s volumes, with what this server holds of each' });
    const row = (id: string) => within(table).getByRole('row', { name: new RegExp(`^${id}`) });
    expect(within(row('frus1894Nicaragua')).getByText('Not downloaded')).toBeTruthy();
    expect(within(row('frus1894Nicaragua')).getByText('1.2 MB in the catalogue')).toBeTruthy();
    expect(within(row('frus1969-76ve09p1')).getByText('7 figure images', { exact: false })).toBeTruthy();
    expect(within(row('frus1961-63v06')).getByText('api.github.com answered 500.')).toBeTruthy();
    expect(within(row('frus1969-76v01')).getByText('Its file is not downloaded', { exact: false })).toBeTruthy();
    expect(within(row('frus1969-76v01')).queryByRole('button', { name: /Remove/ })).toBeNull();
    expect(screen.getByText('1 downloaded · 1 indexed · 1 failed · 1 not downloaded')).toBeTruthy();
    expect(screen.getByText('Volumes come from GitHub’s HistoryAtState/frus repository, and their figure images from history.state.gov.')).toBeTruthy();

    await userEvent.click(within(row('frus1894Nicaragua')).getByRole('button', { name: 'Download frus1894Nicaragua' }));
    await waitFor(() => expect(within(row('frus1894Nicaragua')).getByText('Waiting to download')).toBeTruthy());
    expect(within(row('frus1894Nicaragua')).getByText('Asked for by alice')).toBeTruthy();
    expect(within(row('frus1894Nicaragua')).queryByRole('button')).toBeNull();
    expect(screen.getAllByRole('status').some((line) => line.textContent === 'The download of frus1894Nicaragua is queued as a job: Jobs follows it.')).toBe(true);
    // Its Download has gone with the download queued, so focus goes to its row.
    await waitFor(() => expect(document.activeElement).toBe(within(table).getByRole('rowheader', { name: /^frus1894Nicaragua/ })));
    const posted = sent(fetch, 'POST', '/api/v1/admin/library/downloads');
    expect(posted).toHaveLength(1);
    expect(JSON.parse(String(posted[0]![1]?.body))).toEqual({ volumeIds: ['frus1894Nicaragua'] });

    await userEvent.click(within(row('frus1969-76ve09p1')).getByRole('button', { name: 'Remove frus1969-76ve09p1' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Remove frus1969-76ve09p1?' });
    expect(document.activeElement).toBe(within(dialog).getByRole('button', { name: 'Keep It' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Remove' }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    await waitFor(() => expect(within(row('frus1969-76ve09p1')).getByText('Not downloaded')).toBeTruthy());
    expect(document.activeElement).toBe(within(table).getByRole('rowheader', { name: /^frus1969-76ve09p1/ }));
    expect(sent(fetch, 'DELETE', '/api/v1/admin/library/volumes/frus1969-76ve09p1')).toHaveLength(1);
  });

  it('downloads every volume not downloaded with Download All, and finds a volume by its id or title', async () => {
    const volumes = [
      volume({ volumeId: 'frus1894Nicaragua', status: 'notDownloaded', title: 'Nicaragua (Mosquito Territory)' }),
      volume({ volumeId: 'frus1961-63v06', status: 'notDownloaded', title: 'Kennedy-Khrushchev Exchanges' }),
    ];
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/library': () => library(volumes),
      'POST /api/v1/admin/library/downloads': () => ({ ...job, subject: '2 volumes' }),
    });
    renderAt('/admin/library');
    expect(await screen.findByText('Every volume not downloaded: 2 of the catalogue’s, less any GitHub’s listing no longer names.')).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Download All' }));
    await waitFor(() =>
      expect(screen.getAllByRole('status').some((line) => line.textContent === 'The download of 2 volumes is queued as a job: Jobs follows it.')).toBe(true),
    );
    expect(JSON.parse(String(sent(fetch, 'POST', '/api/v1/admin/library/downloads')[0]![1]?.body))).toEqual({ all: true });
    await userEvent.type(screen.getByRole('searchbox', { name: 'Find a volume' }), 'khrushchev');
    const table = screen.getByRole('table', { name: 'The catalogue’s volumes, with what this server holds of each' });
    expect(within(table).getAllByRole('rowheader').map((header) => header.textContent)).toEqual(['frus1961-63v06Kennedy-Khrushchev Exchanges']);
    expect(screen.getByText('1 of 2 volumes')).toBeTruthy();
  });

  it('counts for Download All every volume whose file is missing and no download holds, and offers no Download Again for an indexed file', async () => {
    let volumes = [
      volume({ volumeId: 'frus1894Nicaragua', status: 'failed', error: 'api.github.com answered 500.' }),
      volume({ volumeId: 'frus1969-76v01', status: 'indexed', indexed: true }),
      volume({ volumeId: 'frus1961-63v06', status: 'indexed', indexed: true, downloaded: true, bytes: 1_646_822 }),
      volume({ volumeId: 'frus1969-76ve09p1', status: 'queued', requestedBy: 'alice' }),
    ];
    stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/library': () => library(volumes),
      'POST /api/v1/admin/library/downloads': () => {
        volumes = volumes.map((each) => (each.downloaded ? each : { ...each, status: 'queued' }));
        return { ...job, subject: '2 volumes' };
      },
    });
    renderAt('/admin/library');
    expect(await screen.findByText('Every volume not downloaded: 2 of the catalogue’s, less any GitHub’s listing no longer names.')).toBeTruthy();
    const table = screen.getByRole('table', { name: 'The catalogue’s volumes, with what this server holds of each' });
    expect(within(table).queryByRole('button', { name: 'Download Again frus1961-63v06' })).toBeNull();
    expect(within(table).getByRole('button', { name: 'Download frus1969-76v01' })).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Download All' }));
    expect(await screen.findByText('The 3 volumes not downloaded wait for their download.')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Download All' }).getAttribute('aria-disabled')).toBe('true');
  });

  it('indexes a volume whose last pass did not index it, and every volume waiting, saying what the job indexes', async () => {
    let volumes = [
      volume({
        volumeId: 'frus1961-63v06',
        status: 'failed',
        downloaded: true,
        bytes: 1_646_822,
        error: 'Its XML could not be parsed while its XML was read: the parser’s error 5 at line 3.',
        index: { state: 'failed', stage: 'reading', at: '2026-11-11T12:00:00.000Z' },
      }),
      volume({ volumeId: 'frus1969-76ve09p1', status: 'downloaded', downloaded: true, bytes: 1_890_303 }),
      volume({ volumeId: 'frus1894Nicaragua', status: 'indexed', indexed: true, downloaded: true, bytes: 1_273_810 }),
    ];
    let indexing: AdminLibrary['indexing'] = { active: false };
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/library': () => library(volumes, { indexing }),
      'POST /api/v1/admin/library/index': () => {
        indexing = { active: true, volume: 'frus1961-63v06' };
        volumes = [{ ...volumes[0]!, status: 'indexing', index: undefined, error: undefined }, ...volumes.slice(1)];
        return { ...job, kind: 'libraryIndex', subject: 'frus1961-63v06' };
      },
    });
    renderAt('/admin/library');
    const table = await screen.findByRole('table', { name: 'The catalogue’s volumes, with what this server holds of each' });
    const row = (id: string) => within(table).getByRole('row', { name: new RegExp(`^${id}`) });
    expect(within(row('frus1961-63v06')).getByText('Its XML could not be parsed', { exact: false })).toBeTruthy();
    expect(within(row('frus1894Nicaragua')).queryByRole('button', { name: /^Index/ })).toBeNull();
    expect(screen.getByText('2 volumes are downloaded and not indexed, or their last pass did not index them.')).toBeTruthy();

    await userEvent.click(within(row('frus1961-63v06')).getByRole('button', { name: 'Index frus1961-63v06' }));
    await waitFor(() => expect(within(row('frus1961-63v06')).getByText('Indexing', { exact: true })).toBeTruthy());
    expect(screen.getByText('Indexing frus1961-63v06: Jobs follows it.')).toBeTruthy();
    expect(screen.getAllByRole('status').some((line) => line.textContent === 'The indexing of frus1961-63v06 is queued as a job: Jobs follows it.')).toBe(true);
    // Its Index has gone with the job that holds it, so focus goes to its row.
    await waitFor(() => expect(document.activeElement).toBe(within(table).getByRole('rowheader', { name: /^frus1961-63v06/ })));
    expect(within(row('frus1961-63v06')).queryByRole('button')).toBeNull();
    expect(JSON.parse(String(sent(fetch, 'POST', '/api/v1/admin/library/index')[0]![1]?.body))).toEqual({ volumeIds: ['frus1961-63v06'] });

    expect(screen.getByText('One volume is downloaded and not indexed, or its last pass did not index it.')).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Index All Waiting' }));
    await waitFor(() => expect(sent(fetch, 'POST', '/api/v1/admin/library/index')).toHaveLength(2));
    expect(JSON.parse(String(sent(fetch, 'POST', '/api/v1/admin/library/index')[1]![1]?.body))).toEqual({ all: true });
  });

  it('says why an Import server and an offline one download nothing, offering neither Download nor Remove', async () => {
    const volumes = [volume({ volumeId: 'frus1894Nicaragua', status: 'downloaded', downloaded: true, bytes: 1_273_810 })];
    stubServer({
      '/readyz': ready,
      '/api/v1/me': alice,
      '/api/v1/admin/library': () =>
        library(volumes, {
          mode: 'import',
          downloads: false,
          unavailable: 'An Import server reads the TEI folder mounted at /data/volumes, and downloads nothing into it.',
        }),
    });
    renderAt('/admin/library');
    expect(await screen.findByText('An Import server reads the TEI folder mounted at /data/volumes, and downloads nothing into it.')).toBeTruthy();
    expect(screen.getByText('1 in the TEI folder')).toBeTruthy();
    const table = screen.getByRole('table', { name: 'The catalogue’s volumes, with what this server holds of each' });
    expect(within(table).getByText('In the TEI folder')).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Download All' })).toBeNull();
    expect(within(table).queryByRole('button')).toBeNull();
  });
});
