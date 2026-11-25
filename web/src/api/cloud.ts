// The Word Cloud (PLAN's S24i, S29e): the language family's clouds (S29d), which the server's own tagger counted from the
// corpus, for the corpus, each subseries and each volume, and since S29e every scope the app's cloud takes counted live
// on the server from the served index's text by the kit's count with the same tagger, under the reader's own Word Cloud
// settings, which follow them in their synced preferences; a count that outlasts a request is a job, which the page
// follows here; and the settings' writes, the criteria through the preferences and the hidden words through routes of
// their own, as the app's settings write each.
import { keepPreviousData, type QueryClient, queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';
import { type Preferences, preferencesQuery } from './research';
import { change } from './userData';

export interface CloudLens {
  /** The lens's raw value, `WordCloudLens`'. */
  id: string;
  /** The lens bar's name, "Topics (nouns)", and the chip's, "Topics". */
  label: string;
  shortLabel: string;
  colorsBySentiment: boolean;
  /** Whether the server's tagger draws it, by the kit's health: not the entity lenses, which name people, places and organizations. */
  available: boolean;
}

export interface CloudContext {
  lenses: CloudLens[];
  /** "Size words by": Frequency and Distinctive. */
  measures: { id: string; label: string }[];
  /** "Entire Corpus". */
  corpus: string;
  subseries: { id: string; volumes: { id: string; title: string }[] }[];
  /** By Subject's categories that narrow, each with its sub-categories, each a scope. */
  subjects: { label: string; subcategories: string[] }[];
  /** The range Date Range opens on, the corpus's last year, `yyyy-MM-dd`. */
  dateRange: { from: string; to: string };
  /** The clouds' own account, and the tagger that counted them, the language family's name and version (S29d). */
  made?: { generated: string; volumeCount: number; documentCount: number; topTermsPerList: number; family: string; line: string };
}

export interface CloudTerm {
  term: string;
  count: number;
  /** On the sentiment lens, the lexicon's polarity: 1, -1, or 0 for none. */
  polarity?: number;
}

/** A count's job, which the page follows until it ends. */
export interface CloudJob {
  id: string;
  state: 'queued' | 'running' | 'succeeded' | 'failed' | 'cancelled';
  /** What it does now, or what it did, in the server's words. */
  progress?: string;
  /** How far through it is, 0 to 1, where it can tell. */
  fraction?: number;
  /** Why it failed, in the server's words. */
  error?: string;
}

export interface CloudAnswer {
  scope: { signature: string; title: string };
  lens: CloudLens;
  /** The lens's name, and the era's where a thin volume's own list stood aside for its subseries'. */
  chip: string;
  fallbackSubseries?: string;
  /** The family's files, or a count of the scope's documents. */
  source: 'family' | 'live';
  state: 'terms' | 'noTerms' | 'insufficientSignal' | 'noCloud' | 'noIndexedText' | 'lensUnavailable' | 'counting';
  message?: { title: string; detail: string };
  countLine?: string;
  terms: CloudTerm[];
  listed: number;
  removed: number;
  settingsNotShown?: string;
  analyzeWithin?: { label: string; volumeIds: string[]; scopeLabel: string };
  /** How many documents a count read. */
  documentCount?: number;
  /** What a count says of itself: its documents, the tagger and whose settings. */
  account?: string;
  /** The job counting the scope, while it is `counting`. */
  job?: CloudJob;
}

export interface CloudSample {
  kept: CloudTerm[];
  sampleSize: number;
  summary: string;
  provenance: string;
}

/** The word cloud's criteria a change may set (Settings ▸ Word Cloud). */
export type WordCloudCriteria = Pick<Preferences['wordCloud'], 'minLength' | 'minCount' | 'foldPlurals' | 'filterMarkings' | 'excludeBoilerplate'>;

export const cloudContextQuery = queryOptions({
  queryKey: ['cloudContext'],
  queryFn: ({ signal }) => getJSON<CloudContext>('/api/v1/cloud/context', undefined, signal),
  staleTime: Infinity,
  retry: false,
});

/**
 * A scope's cloud under a lens. `settings` names the reader's settings it was asked under, so the cloud is asked
 * again whenever they change; the server reads them itself.
 */
export function cloudQuery(scope: string, lens: string, settings: string) {
  const params = new URLSearchParams({ scope, lens });
  return queryOptions({
    queryKey: ['cloud', scope, lens, settings],
    queryFn: ({ signal }) => getJSON<CloudAnswer>('/api/v1/cloud', params, signal),
    // A count's job is asked about again whenever the page comes back to it, never answered from what was kept.
    staleTime: (query) => (query.state.data?.state === 'counting' ? 0 : 5 * 60_000),
    retry: false,
    placeholderData: keepPreviousData,
  });
}

/** Where a count's job stands, asked every second while it waits or runs. */
export function cloudJobQuery(id: string) {
  return queryOptions({
    queryKey: ['cloudJob', id],
    queryFn: ({ signal }) => getJSON<CloudJob>(`/api/v1/cloud/jobs/${encodeURIComponent(id)}`, undefined, signal),
    // One poll that fails is asked again before the page says so.
    retry: 2,
    refetchInterval: (query) => {
      const state = query.state.data?.state;
      return state === undefined || state === 'queued' || state === 'running' ? 1_000 : false;
    },
  });
}

/** The settings bench under a lens, or every cloud's for none, asked again whenever the settings change. */
export function cloudSampleQuery(lens: string | undefined, settings: string) {
  const params = new URLSearchParams(lens ? { lens } : {});
  return queryOptions({
    queryKey: ['cloudSample', lens ?? '', settings],
    queryFn: ({ signal }) => getJSON<CloudSample>('/api/v1/me/preferences/word-cloud-sample', params, signal),
    staleTime: 5 * 60_000,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

/** A token of the reader's word cloud settings as the server has kept them, which the clouds and the bench are asked under. */
export function settingsToken(preferences: Preferences | undefined): string {
  return preferences ? JSON.stringify(preferences.wordCloud) : 'standard';
}

/**
 * The criteria changes sent and not yet answered, held as `updatePreferences` holds the preferences': each shows at once
 * over the server's copy, as a control's own choice does, until the newest is answered; then the server's copy stands,
 * or, when the server refuses it, its copy as it was. The clouds and the bench are asked under the server's copy alone,
 * so none is asked before the change it is asked under has been kept; and an older answer arriving after a newer change
 * is sent is not the copy, since it lacks the newer change.
 */
let pendingCriteria: Partial<WordCloudCriteria> = {};
let criteriaChangesSent = 0;
const criteriaListeners = new Set<() => void>();

function setPendingCriteria(next: Partial<WordCloudCriteria>) {
  pendingCriteria = next;
  for (const listener of criteriaListeners) listener();
}

export function subscribePendingCriteria(listener: () => void): () => void {
  criteriaListeners.add(listener);
  return () => {
    criteriaListeners.delete(listener);
  };
}

export function pendingCriteriaChanges(): Partial<WordCloudCriteria> {
  return pendingCriteria;
}

/** Sets the criteria named, shown at once over the server's copy until the newest change is answered. */
export async function updateWordCloud(client: QueryClient, changed: Partial<WordCloudCriteria>): Promise<Preferences> {
  const sent = ++criteriaChangesSent;
  setPendingCriteria({ ...pendingCriteria, ...changed });
  try {
    const preferences = (await change<Preferences>(client, 'PATCH', '/api/v1/me/preferences', { wordCloud: changed }))!;
    if (sent === criteriaChangesSent) {
      client.setQueryData(preferencesQuery.queryKey, preferences);
      setPendingCriteria({});
    }
    return preferences;
  } catch (error) {
    if (sent === criteriaChangesSent) {
      setPendingCriteria({});
      void client.invalidateQueries({ queryKey: preferencesQuery.queryKey });
    }
    throw error;
  }
}

/** Hides a word from every cloud, or under `lens` alone (`addGlobalStopword`, `addLensStopword`). */
export async function hideWord(client: QueryClient, word: string, lens?: string): Promise<Preferences> {
  const preferences = (await change<Preferences>(client, 'POST', '/api/v1/me/preferences/hidden-words', lens ? { word, lens } : { word }))!;
  client.setQueryData(preferencesQuery.queryKey, preferences);
  return preferences;
}

/** Shows a hidden word again (`removeGlobalStopword`, `removeLensStopword`). */
export async function showWord(client: QueryClient, word: string, lens?: string): Promise<Preferences> {
  const params = new URLSearchParams(lens ? { word, lens } : { word });
  const preferences = (await change<Preferences>(client, 'DELETE', `/api/v1/me/preferences/hidden-words?${params.toString()}`))!;
  client.setQueryData(preferencesQuery.queryKey, preferences);
  return preferences;
}
