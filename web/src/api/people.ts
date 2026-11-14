// The People screen and a curator's corrections (PLAN's S21g): the served index's person rollup, as the app's
// People browser lists it, an identity's sheet, the corrections a curator makes to it, Merge and Separate, and the
// one made to a document's classification in the rail. Each correction is answered once the index has taken it, on a
// Standalone server, or kept for the next export an Import server installs; either way what the browser holds of
// the people, of search and of the document is asked for again.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import { change, searchesChanged } from './userData';

const segment = encodeURIComponent;

/** One identity of the rollup, as the app's People list prints it. */
export interface PersonRow {
  rollupId: number;
  name: string;
  /** The app's `role · era · N volumes`. */
  subtitle?: string | null;
  mentionCount: number;
  volumeCount: number;
  /** The bundled name authority's id, which a merge's question compares. */
  authorityId?: number | null;
  /** Whether a "possibly the same person" suggestion waits. */
  possibleDuplicate: boolean;
}

export interface PeopleList {
  /** The rollup it came from, which a correction sends back. */
  version: string;
  count: number;
  sections: { letter: string; people: PersonRow[] }[];
}

/** An identity's sheet. */
export interface PersonSheet {
  version: string;
  rollupId: number;
  name: string;
  description?: string | null;
  lifespan?: string | null;
  registerRole?: string | null;
  reconciled: boolean;
  authorityId?: number | null;
  mentionCount: number;
  mentions: string;
  active?: string | null;
  viafURL?: string | null;
  wikidataURL?: string | null;
  candidates: { rollupId: number; name: string; reason?: string | null }[];
  records: { volumeId: string; ref: string; name: string }[];
}

/** Where a correction stands once it is kept. */
export interface CorrectionOutcome {
  /** `applied`: the index holds it; `waiting`: a job will apply it; `nextExport`: the next export installed takes it. */
  state: 'applied' | 'waiting' | 'nextExport';
  entryId: string;
}

/** The person corrections kept, as the app's Corrections sheet lists them. */
export interface PersonCorrections {
  items: {
    id: string;
    kind: 'merge' | 'split';
    nameA: string;
    nameB?: string | null;
    madeBy?: string | null;
    madeAt?: string | null;
    applied: boolean;
  }[];
  mode: 'import' | 'standalone';
}

/** A document's classification, as the rail's Classification section shows it. */
export interface DocumentClassification {
  indexed: boolean;
  isEditorialNote?: boolean | null;
  parsedIsEditorialNote?: boolean | null;
  correction?: { isEditorialNote: boolean; madeBy?: string | null; madeAt?: string | null } | null;
  waiting?: 'correction' | 'restore' | null;
  canCorrect: boolean;
  mode: 'import' | 'standalone';
}

/**
 * The served rollup's people, some 18,000 on a full corpus: read once, and again only after a correction, or when a
 * correction finds the rollup rebuilt since (`PEOPLE_CHANGED`).
 */
export const peopleQuery = queryOptions({
  queryKey: ['people'],
  queryFn: ({ signal }) => getJSON<PeopleList>('/api/v1/people', undefined, signal),
  staleTime: Infinity,
});

export function personQuery(rollupId: number) {
  return queryOptions({
    queryKey: ['people', 'person', rollupId],
    queryFn: ({ signal }) => getJSON<PersonSheet>(`/api/v1/people/${rollupId}`, undefined, signal),
  });
}

export const personCorrectionsQuery = queryOptions({
  queryKey: ['people', 'corrections'],
  queryFn: ({ signal }) => getJSON<PersonCorrections>('/api/v1/me/people/corrections', undefined, signal),
});

export function classificationQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['classification', volumeId, documentId],
    queryFn: ({ signal }) =>
      getJSON<DocumentClassification>(`/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/classification`, undefined, signal),
  });
}

/**
 * After a correction: the people, every search and facet, whose type filter and counts read a document's
 * classification, and every document's classification and page, which the reader shapes by it.
 */
function corrected(client: QueryClient) {
  void client.invalidateQueries({ queryKey: ['people'] });
  void client.invalidateQueries({ queryKey: ['classification'] });
  void client.invalidateQueries({ queryKey: ['document'] });
  searchesChanged(client);
}

export async function mergePeople(client: QueryClient, rollupId: number, otherRollupId: number, version: string): Promise<CorrectionOutcome> {
  const outcome = (await change<CorrectionOutcome>(client, 'POST', '/api/v1/me/people/merges', { rollupId, otherRollupId, version }))!;
  corrected(client);
  return outcome;
}

export async function separatePerson(
  client: QueryClient,
  rollupId: number,
  record: { volumeId: string; ref: string },
  version: string,
): Promise<CorrectionOutcome> {
  const outcome = (await change<CorrectionOutcome>(client, 'POST', '/api/v1/me/people/separations', {
    rollupId,
    volumeId: record.volumeId,
    ref: record.ref,
    version,
  }))!;
  corrected(client);
  return outcome;
}

export async function undoPersonCorrection(client: QueryClient, id: string): Promise<CorrectionOutcome> {
  const outcome = (await change<CorrectionOutcome>(client, 'DELETE', `/api/v1/me/people/corrections/${segment(id)}`))!;
  corrected(client);
  return outcome;
}

export async function reclassify(client: QueryClient, volumeId: string, documentId: string, isEditorialNote: boolean): Promise<CorrectionOutcome> {
  const path = `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/classification`;
  const outcome = (await change<CorrectionOutcome>(client, 'PUT', path, { isEditorialNote }))!;
  corrected(client);
  return outcome;
}

export async function restoreClassification(client: QueryClient, volumeId: string, documentId: string): Promise<CorrectionOutcome> {
  const path = `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/classification`;
  const outcome = (await change<CorrectionOutcome>(client, 'DELETE', path))!;
  corrected(client);
  return outcome;
}
