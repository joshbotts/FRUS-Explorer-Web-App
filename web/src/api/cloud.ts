// The Word Cloud (PLAN's S24i): the clouds bundled with the app, for the corpus, each subseries and each volume under
// the four lenses they carry, read on the server by the kit and filtered there by the reader's own Word Cloud settings,
// which follow them in their synced preferences; and the settings' writes, the criteria through the preferences and the
// hidden words through routes of their own, as the app's settings write each.
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
}

export interface CloudContext {
  lenses: CloudLens[];
  /** "Size words by": Frequency and Distinctive. */
  measures: { id: string; label: string }[];
  /** "Entire Corpus". */
  corpus: string;
  subseries: { id: string; volumes: { id: string; title: string }[] }[];
  made?: { generated: string; volumeCount: number; documentCount: number; topTermsPerList: number; line: string };
}

export interface CloudTerm {
  term: string;
  count: number;
  /** On the sentiment lens, the lexicon's polarity: 1, -1, or 0 for none. */
  polarity?: number;
}

export interface CloudAnswer {
  scope: { signature: string; title: string };
  lens: CloudLens;
  /** The lens's name, and the era's where a thin volume's own list stood aside for its subseries'. */
  chip: string;
  fallbackSubseries?: string;
  state: 'terms' | 'noTerms' | 'insufficientSignal' | 'noCloud';
  message?: { title: string; detail: string };
  countLine?: string;
  terms: CloudTerm[];
  listed: number;
  removed: number;
  settingsNotShown?: string;
  analyzeWithin?: { label: string; volumeIds: string[]; scopeLabel: string };
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
    staleTime: 5 * 60_000,
    retry: false,
    placeholderData: keepPreviousData,
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
