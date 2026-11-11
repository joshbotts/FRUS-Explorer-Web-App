// The admin's Library (PLAN's S21c), under /api/v1/admin/library: every catalogue volume with its state, a
// download of some or all of them, a job of the server's queue, and Remove; and from S21d its indexing,
// which follows each download and which Index asks for. An admin's, as every route under /api/v1/admin
// is; a change carries the user's token, as every change does.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import type { AdminJob } from './admin';
import { getJSON } from './client';
import { change } from './userData';

/**
 * Where a volume stands: a download waiting or under way first, then one that failed, then its pass under way,
 * then a pass that did not index it, then the index, then the file.
 */
export type LibraryStatus = 'notDownloaded' | 'queued' | 'downloading' | 'downloaded' | 'indexing' | 'indexed' | 'failed';

/**
 * A volume's last pass, which did not index it (PLAN's S21d): `failed` for a reason of its own; `stopped` by a
 * cancel or a problem of the server's; `interrupted` by a stop of the server. Its `stage` is where it was.
 */
export interface LibraryIndexPass {
  state: 'failed' | 'stopped' | 'interrupted';
  stage?: 'starting' | 'reading' | 'storingDocuments' | 'storingTables';
  at?: string;
}

/** One catalogue volume, as the Library lists it. */
export interface LibraryVolume {
  volumeId: string;
  title: string;
  subseries: string;
  /** The catalogue's length of its file, in bytes. */
  catalogueBytes: number;
  status: LibraryStatus;
  /** Whether its file is in the volumes folder. */
  downloaded: boolean;
  /** Whether the served index holds it. */
  indexed: boolean;
  sideloaded: boolean;
  bytes?: number;
  blobSha?: string;
  downloadedAt?: string;
  figures?: number;
  figuresRefused?: number;
  /** Why its download failed, or what of it was left undone, or why its last pass did not index it. */
  error?: string;
  /** Its last pass, when it did not index the volume whose file is in place. */
  index?: LibraryIndexPass;
  /** Who asked for a download waiting or under way. */
  requestedBy?: string;
}

/** `GET /api/v1/admin/library`. */
export interface AdminLibrary {
  mode: 'import' | 'standalone';
  offline: boolean;
  /** Whether this server downloads: in Standalone mode, and not offline. */
  downloads: boolean;
  /** Why it downloads nothing, in the server's words. */
  unavailable?: string;
  source: 'github' | 'mirror';
  counts: Partial<Record<LibraryStatus, number>>;
  /** The library's indexing: whether a job waits or runs, and the volume it indexes now. */
  indexing: { active: boolean; volume?: string };
  volumes: LibraryVolume[];
}

/** Whether a download waits for the volume or is under way. */
export const isDownloading = (volume: LibraryVolume) => volume.status === 'queued' || volume.status === 'downloading';

/**
 * Whether Index takes the volume, as the server does: its file is in place, no download or pass holds it, and
 * the index lacks it, or holds it from a pass that did not finish.
 */
export const waitsForIndex = (volume: LibraryVolume) =>
  volume.downloaded && !isDownloading(volume) && volume.status !== 'indexing' && (!volume.indexed || volume.index !== undefined);

/**
 * The Library, read again every two seconds while a download waits or runs, or an indexing job does, else every
 * thirty, and not after a reading failed.
 */
export const libraryQuery = queryOptions({
  queryKey: ['admin', 'library'],
  queryFn: ({ signal }) => getJSON<AdminLibrary>('/api/v1/admin/library', undefined, signal),
  staleTime: 0,
  retry: false,
  refetchInterval: (query) => {
    if (query.state.status === 'error') return false;
    const data = query.state.data;
    return data?.volumes.some(isDownloading) || data?.indexing.active ? 2_000 : 30_000;
  },
});

/** Queues a download of these volumes, or of every one not downloaded; the Library and the jobs are read again. */
export async function downloadVolumes(client: QueryClient, request: { volumeIds: string[] } | { all: true }): Promise<AdminJob | null> {
  const job = await change<AdminJob>(client, 'POST', '/api/v1/admin/library/downloads', request);
  await client.refetchQueries({ queryKey: ['admin', 'library'] });
  void client.invalidateQueries({ queryKey: ['admin'] });
  return job;
}

/** Queues the indexing of these volumes, or of every one waiting (PLAN's S21d); the Library and the jobs are read again. */
export async function indexVolumes(client: QueryClient, request: { volumeIds: string[] } | { all: true }): Promise<AdminJob | null> {
  const job = await change<AdminJob>(client, 'POST', '/api/v1/admin/library/index', request);
  await client.refetchQueries({ queryKey: ['admin', 'library'] });
  void client.invalidateQueries({ queryKey: ['admin'] });
  return job;
}

/** Removes a downloaded volume's file and figure images; the Library is read again. */
export async function removeVolume(client: QueryClient, volumeId: string): Promise<void> {
  await change<null>(client, 'DELETE', `/api/v1/admin/library/volumes/${encodeURIComponent(volumeId)}`);
  await client.refetchQueries({ queryKey: ['admin', 'library'] });
  void client.invalidateQueries({ queryKey: ['admin'] });
}
