// Saved searches, working corpora and volume scopes (PLAN's S17e), under /api/v1/me: what a search is
// saved as, captured as, or runs inside. Each list is the user's, read as the server sorts it, and asked
// again after a change to it, and after an import, which can bring any of the three (`researchImported`).
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import { formEncode } from './form';
import type { Coverage } from './types';
import { change } from './userData';
import { filterFields, type SearchState } from '../search/searchState';

const segment = encodeURIComponent;

/** One of the user's saved searches. */
export interface SavedSearch {
  id: string;
  name: string;
  /** The search box's words, which the list shows under the name. */
  queryText: string;
  /** The search a recall runs, as the search's query fields, its own document gates left out. */
  search: Record<string, string[]>;
  /** What the saved search sets that a recall here runs without, a Mac's own: `booleanMode`, `personRef`, `projectId`, `subjectRef`. */
  notRecalled: string[];
  /** Its watermark: when it was last run, what it matched then, and how many volumes the index held. */
  lastRunAt?: string;
  matchCountAtLastRun?: number;
  indexedVolumeCountAtLastRun?: number;
  createdAt?: string;
  lastModified?: string;
}

export interface SavedSearchList {
  total: number;
  items: SavedSearch[];
}

/** One evaluation of a saved search's watermark: "+N since last run", or no badge. */
export interface SavedSearchFreshness {
  newResults?: number;
  savedSearch: SavedSearch;
}

/** What the served index reaches of a working corpus, by the kit's resolver. */
export interface CorpusCoverage {
  indexedCount: number;
  totalCount: number;
  missingVolumeIds: string[];
  isComplete: boolean;
}

/** One of the user's working corpora. */
export interface WorkingCorpus {
  id: string;
  /** May be empty, as an import can leave it: Untitled Corpus. */
  name: string;
  documentCount: number;
  capturedAt?: string;
  sourceQuery?: string;
  /** Those words as a list quotes them, by the kit's rule: a query that is one phrase, once, without its own marks. */
  quotableSourceQuery?: string;
  sourceDescription?: string;
  indexedVolumeCountAtCapture?: number;
  wasTruncatedAtCapture?: boolean;
  totalMatchCountAtCapture?: number;
  createdAt?: string;
  lastModified?: string;
  isMeaningCapture: boolean;
  /** The kit's line for its capture's completeness, absent for a capture of every match. */
  truncationLine?: string;
  /** Whether that line warns: a capture cut short of its match. */
  truncationWarns: boolean;
  /** Absent while the server serves no index. */
  coverage?: CorpusCoverage;
}

export interface WorkingCorpusList {
  total: number;
  items: WorkingCorpus[];
}

/** A working corpus opened, a section a volume, as Browse's drill shows it. */
export interface WorkingCorpusDetail {
  corpus: WorkingCorpus;
  sections: {
    volumeId: string;
    title?: string;
    /** Whether the index holds the volume, whose documents then open. */
    indexed: boolean;
    documents: { volumeId: string; documentId: string; displayTitle?: string; dateISO?: string }[];
  }[];
  coverage: Coverage;
}

/** What Save would capture of a search's rows, as the Save Working Corpus sheet shows it. */
export interface CorpusCapturePreview {
  documentCount: number;
  sourceQuery?: string;
  narrowing: string[];
  indexedVolumeCount: number;
  truncationWarning?: string;
  checklistWarning?: string;
  sourceDescription: string;
  wasTruncated: boolean;
  totalMatchCount: number;
}

/** One of the user's volume scopes. */
export interface VolumeScope {
  id: string;
  /** May be empty, as New Scope makes one: Untitled Scope. */
  name: string;
  volumeIds: string[];
  createdAt?: string;
  lastModified?: string;
  /** The members the index holds, which a search's volume filter takes; absent when it holds none. */
  indexedVolumeIds?: string[];
  indexedResolution?: 'resolved' | 'noIndexedMembers';
  /** How many of its members the catalogue lists. */
  cataloguedCount: number;
}

export interface VolumeScopeList {
  total: number;
  items: VolumeScope[];
}

/** A search as the server reads it in a body: its fields as a query string. */
function searchString(state: SearchState): string {
  return formEncode(filterFields(state)).toString();
}

export const savedSearchesQuery = queryOptions({
  queryKey: ['savedSearches'],
  queryFn: ({ signal }) => getJSON<SavedSearchList>('/api/v1/me/saved-searches', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

export async function saveSearch(client: QueryClient, name: string, state: SearchState): Promise<SavedSearch> {
  const saved = (await change<SavedSearch>(client, 'POST', '/api/v1/me/saved-searches', { name, search: searchString(state) }))!;
  void client.invalidateQueries({ queryKey: ['savedSearches'] });
  return saved;
}

export async function renameSavedSearch(client: QueryClient, id: string, name: string): Promise<SavedSearch> {
  const saved = (await change<SavedSearch>(client, 'PATCH', `/api/v1/me/saved-searches/${segment(id)}`, { name }))!;
  savedSearchesChanged(client);
  return saved;
}

export async function deleteSavedSearch(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', `/api/v1/me/saved-searches/${segment(id)}`);
  savedSearchesChanged(client);
}

/**
 * After a saved search is renamed or deleted: the list, and the collections a smart collection's link names it
 * in, with their results (S18f).
 */
function savedSearchesChanged(client: QueryClient) {
  void client.invalidateQueries({ queryKey: ['savedSearches'] });
  void client.invalidateQueries({ queryKey: ['collection'] });
  void client.invalidateQueries({ queryKey: ['collectionResults'] });
}

/** A recall's stamp, from the saved search's own count, which its badge is measured against. */
export async function recordRun(client: QueryClient, id: string): Promise<SavedSearch> {
  const saved = (await change<SavedSearch>(client, 'POST', `/api/v1/me/saved-searches/${segment(id)}/run`))!;
  void client.invalidateQueries({ queryKey: ['savedSearches'] });
  return saved;
}

/** "+N since last run" for one saved search: the server counts it, and writes the baseline it may backfill. */
export async function evaluateFreshness(client: QueryClient, id: string): Promise<SavedSearchFreshness> {
  return (await change<SavedSearchFreshness>(client, 'POST', `/api/v1/me/saved-searches/${segment(id)}/freshness`))!;
}

export const workingCorporaQuery = queryOptions({
  queryKey: ['workingCorpora'],
  queryFn: ({ signal }) => getJSON<WorkingCorpusList>('/api/v1/me/working-corpora', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

export function workingCorpusQuery(id: string) {
  return queryOptions({
    queryKey: ['workingCorpus', id],
    queryFn: ({ signal }) => getJSON<WorkingCorpusDetail>(`/api/v1/me/working-corpora/${segment(id)}`, undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/** What Save as Working Corpus would capture of the search's rows, less those Checklist Mode hides. */
export async function previewCapture(client: QueryClient, state: SearchState, reviewed: readonly string[]): Promise<CorpusCapturePreview> {
  return (await change<CorpusCapturePreview>(client, 'POST', '/api/v1/me/working-corpora/capture', {
    search: searchString(state),
    reviewed,
  }))!;
}

export async function saveCorpus(client: QueryClient, name: string, state: SearchState, reviewed: readonly string[]): Promise<WorkingCorpus> {
  const corpus = (await change<WorkingCorpus>(client, 'POST', '/api/v1/me/working-corpora', {
    name,
    search: searchString(state),
    reviewed,
  }))!;
  void client.invalidateQueries({ queryKey: ['workingCorpora'] });
  return corpus;
}

export async function renameCorpus(client: QueryClient, id: string, name: string): Promise<WorkingCorpus> {
  const corpus = (await change<WorkingCorpus>(client, 'PATCH', `/api/v1/me/working-corpora/${segment(id)}`, { name }))!;
  void client.invalidateQueries({ queryKey: ['workingCorpora'] });
  void client.invalidateQueries({ queryKey: ['workingCorpus', id] });
  return corpus;
}

export async function deleteCorpus(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', `/api/v1/me/working-corpora/${segment(id)}`);
  void client.invalidateQueries({ queryKey: ['workingCorpora'] });
  client.removeQueries({ queryKey: ['workingCorpus', id] });
}

export const volumeScopesQuery = queryOptions({
  queryKey: ['volumeScopes'],
  queryFn: ({ signal }) => getJSON<VolumeScopeList>('/api/v1/me/volume-scopes', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

/** One of the user's scopes, by its id in any letter case, as its page and its editor read it. */
export function volumeScopeQuery(id: string) {
  return queryOptions({
    queryKey: ['volumeScope', id.toUpperCase()],
    queryFn: ({ signal }) => getJSON<VolumeScope>(`/api/v1/me/volume-scopes/${segment(id)}`, undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/** Each change to a scope answers the scope as it then stands, which its page and editor show at once. */
function scopeChanged(client: QueryClient, scope: VolumeScope) {
  client.setQueryData(volumeScopeQuery(scope.id).queryKey, scope);
  void client.invalidateQueries({ queryKey: ['volumeScopes'] });
}

export async function createScope(client: QueryClient, fields: { name?: string; volumeIds?: string[] } = {}): Promise<VolumeScope> {
  const scope = (await change<VolumeScope>(client, 'POST', '/api/v1/me/volume-scopes', fields))!;
  scopeChanged(client, scope);
  return scope;
}

export async function editScope(client: QueryClient, id: string, fields: { name?: string; volumeIds?: string[] }): Promise<VolumeScope> {
  const scope = (await change<VolumeScope>(client, 'PATCH', `/api/v1/me/volume-scopes/${segment(id)}`, fields))!;
  scopeChanged(client, scope);
  return scope;
}

export async function deleteScope(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', `/api/v1/me/volume-scopes/${segment(id)}`);
  client.removeQueries({ queryKey: volumeScopeQuery(id).queryKey });
  void client.invalidateQueries({ queryKey: ['volumeScopes'] });
}
