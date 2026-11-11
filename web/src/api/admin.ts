// An admin's routes, under /api/v1/admin (PLAN's S20d): Status, the server's jobs and a cancel, the
// users and an admin's changes to their accounts, a user's research and its erasure, the backups, the
// index's reset, and the instance's NARA key (S20c's `/api/v1/admin/secrets`). Every one needs the admin
// role, which the server checks; a change carries the user's token, as every change does.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import type { SecretList, SecretName, SecretStatus } from './secrets';
import type { Readiness } from './types';
import { change } from './userData';

/** One job, as the queue holds it. */
export interface AdminJob {
  id: string;
  /** `indexImport`, `researchImport` or `indexReset`, and from the library's rows theirs. */
  kind: string;
  /** What it works on, in the server's words, such as an export's file name. */
  subject?: string;
  state: 'queued' | 'running' | 'succeeded' | 'failed' | 'cancelled';
  /** A line of what it does now, or of what it did. */
  progress?: string;
  /** How far through it is, 0 to 1, where it can tell. */
  fraction?: number;
  /** The user who asked for it; absent for the server itself. */
  requestedBy?: string;
  queuedAt: string;
  startedAt?: string;
  finishedAt?: string;
  error?: string;
  cancellable: boolean;
  cancelRequestedBy?: string;
  cancelRequestedAt?: string;
}

export interface AdminJobList {
  jobs: AdminJob[];
}

/** What an index served holds, as `/api/v1/status` gives it. */
export interface IndexSummary {
  documents: number;
  volumes: number;
  indexVersion: number;
  ftsSchemaVersion: number;
  exportedAt?: string;
  appVersion?: string;
  appBuild?: string;
}

/** A backup or a copy the server keeps, as the backup archive's manifest lists it. */
export interface BackupVersion {
  name: string;
  kind: 'daily' | 'beforeMigration' | 'beforeRestore';
  takenAt: string;
  bytes: number;
  migration?: number;
  copied?: boolean;
}

/** `GET /api/v1/admin/status`. */
export interface AdminStatus {
  version: string;
  mode: 'import' | 'standalone';
  auth: string;
  userData: boolean;
  startedAt: string;
  supportedIndexVersion: number;
  readiness: Readiness;
  index?: IndexSummary;
  catalogueVolumes: number;
  store: { kind: 'sqlite' | 'postgreSQL'; migration: number; latestMigration: number };
  /** Absent for a PostgreSQL store, whose backups are its database service's. */
  backups?: { daily: number; kept: number; newest?: BackupVersion; hour: string; timeZone: string; copiedToHost: boolean };
  keys: { keyFileId: string; stored: number };
  jobs: { queued: number; running?: AdminJob };
}

/** `GET /api/v1/admin/backups`. */
export interface AdminBackups {
  backups: BackupVersion[];
  backedUp: boolean;
  copiedToHost: boolean;
}

export type Role = 'reader' | 'curator' | 'admin';

/** A user, as the Users list shows them. */
export interface AdminUser {
  id: string;
  displayName: string;
  role: Role;
  hasPassword: boolean;
  disabledAt?: string;
  lastSignInAt?: string;
  createdAt?: string;
}

/** `GET /api/v1/admin/users`: under `local` the accounts are this server's to change. */
export interface AdminUserList {
  auth: string;
  users: AdminUser[];
}

/** One table's rows of a user's that an erasure removes. */
export interface ResearchHolding {
  /** The app's model type, such as `ResearchNote`, or `StoredKey`. */
  type: string;
  table: string;
  count: number;
}

/** What a user holds, or what an erasure removed. */
export interface ResearchHoldings {
  userId: string;
  holdings: ResearchHolding[];
  total: number;
}

/** A user's name as a path's segment. */
export const userSegment = (name: string) => encodeURIComponent(name);

/** The jobs, read again every two seconds while one waits or runs. */
export const jobsQuery = queryOptions({
  queryKey: ['admin', 'jobs'],
  queryFn: ({ signal }) => getJSON<AdminJobList>('/api/v1/admin/jobs', undefined, signal),
  staleTime: 0,
  retry: false,
  refetchInterval: (query) => (query.state.data?.jobs.some((job) => job.state === 'queued' || job.state === 'running') ? 2_000 : 30_000),
});

export const statusQuery = queryOptions({
  queryKey: ['admin', 'status'],
  queryFn: ({ signal }) => getJSON<AdminStatus>('/api/v1/admin/status', undefined, signal),
  staleTime: 0,
  retry: false,
  refetchInterval: (query) => (query.state.data && (query.state.data.jobs.running || query.state.data.jobs.queued > 0) ? 2_000 : 30_000),
});

export const usersQuery = queryOptions({
  queryKey: ['admin', 'users'],
  queryFn: ({ signal }) => getJSON<AdminUserList>('/api/v1/admin/users', undefined, signal),
  staleTime: 0,
  retry: false,
});

export const backupsQuery = queryOptions({
  queryKey: ['admin', 'backups'],
  queryFn: ({ signal }) => getJSON<AdminBackups>('/api/v1/admin/backups', undefined, signal),
  staleTime: 0,
  retry: false,
});

export const instanceSecretsQuery = queryOptions({
  queryKey: ['admin', 'secrets'],
  queryFn: ({ signal }) => getJSON<SecretList>('/api/v1/admin/secrets', undefined, signal),
  staleTime: 0,
  retry: false,
});

/** What `name` holds, read when an erasure is asked for, never kept. */
export function researchHoldings(name: string, signal?: AbortSignal): Promise<ResearchHoldings> {
  return getJSON<ResearchHoldings>(`/api/v1/admin/users/${userSegment(name)}/research`, undefined, signal);
}

/** Every admin list is read again after a change, and the user's own, which an admin's own change may touch. */
function changed(client: QueryClient) {
  void client.invalidateQueries({ queryKey: ['admin'] });
}

export async function cancelJob(client: QueryClient, id: string): Promise<AdminJob | null> {
  const job = await change<AdminJob>(client, 'POST', `/api/v1/admin/jobs/${encodeURIComponent(id)}/cancel`);
  changed(client);
  return job;
}

export async function resetIndex(client: QueryClient): Promise<AdminJob | null> {
  const job = await change<AdminJob>(client, 'POST', '/api/v1/admin/index/reset');
  changed(client);
  void client.invalidateQueries({ queryKey: ['readyz'] });
  return job;
}

export async function addAccount(
  client: QueryClient,
  account: { name: string; displayName?: string; role: Role; password: string },
): Promise<AdminUser | null> {
  const made = await change<AdminUser>(client, 'POST', '/api/v1/admin/users', account);
  changed(client);
  return made;
}

export async function changeAccount(client: QueryClient, name: string, fields: { role?: Role; disabled?: boolean }): Promise<AdminUser | null> {
  const account = await change<AdminUser>(client, 'PATCH', `/api/v1/admin/users/${userSegment(name)}`, fields);
  changed(client);
  // An admin who changes their own account changes what the app may show them.
  void client.invalidateQueries({ queryKey: ['me'] });
  return account;
}

export async function setPassword(client: QueryClient, name: string, password: string): Promise<void> {
  await change(client, 'PUT', `/api/v1/admin/users/${userSegment(name)}/password`, { password });
  changed(client);
}

/** Erases `name`'s research if they still hold what `counted` says; the answer is what was erased. */
export async function eraseResearch(client: QueryClient, counted: ResearchHoldings): Promise<ResearchHoldings | null> {
  const expected = Object.fromEntries(counted.holdings.map((holding) => [holding.table, holding.count]));
  const erased = await change<ResearchHoldings>(client, 'POST', `/api/v1/admin/users/${userSegment(counted.userId)}/research/erase`, {
    expected,
  });
  changed(client);
  return erased;
}

/** Keeps `value` as the instance's key `name`; the answer names it as set. */
export async function setInstanceSecret(client: QueryClient, name: SecretName, value: string): Promise<SecretStatus | null> {
  const status = await change<SecretStatus>(client, 'PUT', `/api/v1/admin/secrets/${name}`, { value });
  await client.invalidateQueries({ queryKey: ['admin', 'secrets'] });
  void client.invalidateQueries({ queryKey: ['secrets'] });
  return status;
}

export async function removeInstanceSecret(client: QueryClient, name: SecretName): Promise<void> {
  await change(client, 'DELETE', `/api/v1/admin/secrets/${name}`);
  await client.invalidateQueries({ queryKey: ['admin', 'secrets'] });
  void client.invalidateQueries({ queryKey: ['secrets'] });
}
