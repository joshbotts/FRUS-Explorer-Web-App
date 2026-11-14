// The People screen and a curator's corrections (PLAN's S21g): the served index's person rollup, as the app's
// People browser lists it, an identity's sheet, the corrections a curator makes to it, Merge and Separate, and the
// one made to a document's classification in the rail. Each correction is answered once the index has taken it, on a
// Standalone server, or kept for the next export an Import server installs; either way what the browser holds of
// the people, of search and of the document is asked for again. A sheet's subject chip asks for the volumes covering
// its subject, its pivot (S21g's follow-up), which the bundled files answer whatever the index holds.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import { corpusQueryKeys, retryServerFaults } from './endpoints';
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

/** A subject of the volumes a person is mentioned in, the kit's ranking's, as the sheet's chip draws it. */
export interface PersonSubject {
  ref: string;
  name: string;
  category: string;
  /** How many of the volumes the person is mentioned in carry it. */
  volumeCount: number;
}

/** An identity's sheet. */
export interface PersonSheet {
  version: string;
  rollupId: number;
  name: string;
  description?: string | null;
  /** The kit's lifespan line: the name authority's years, a gap filled from the register's career. */
  lifespan?: string | null;
  registerRole?: string | null;
  reconciled: boolean;
  authorityId?: number | null;
  mentionCount: number;
  mentions: string;
  active?: string | null;
  /** Subjects, in the kit's order; none where the sheet shows no section. */
  subjects: PersonSubject[];
  viafURL?: string | null;
  wikidataURL?: string | null;
  /** Career, the register's posts in its order, each the kit's title and dates; none where the sheet shows no section. */
  career: { title: string; dates?: string | null; note?: string | null }[];
  candidates: { rollupId: number; name: string; reason?: string | null }[];
  records: { volumeId: string; ref: string; name: string }[];
}

/** A chip's pivot: every volume covering a subject, by volume id, each with the catalogue's title. */
export interface SubjectVolumes {
  ref: string;
  volumes: { volumeId: string; title?: string | null }[];
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
/** One entry of the log, as an admin reads it. */
export interface CorrectionLogEntry {
  id: string;
  correction: 'classification' | 'person';
  action: 'made' | 'undone';
  overrideId: string;
  volumeId?: string | null;
  documentId?: string | null;
  isEditorialNote?: boolean | null;
  kind?: 'merge' | 'split' | null;
  userId: string;
  userName: string;
  madeAt: string;
  appliedAt?: string | null;
  title?: string | null;
  nameA?: string | null;
  nameB?: string | null;
}

export interface CorrectionLog {
  entries: CorrectionLogEntry[];
  mode: 'import' | 'standalone';
}

export const correctionLogQuery = queryOptions({
  queryKey: ['admin', 'corrections'],
  queryFn: ({ signal }) => getJSON<CorrectionLog>('/api/v1/admin/corrections', undefined, signal),
  staleTime: 0,
  retry: false,
});

export const peopleQuery = queryOptions({
  queryKey: ['people'],
  queryFn: ({ signal }) => getJSON<PeopleList>('/api/v1/people', undefined, signal),
  staleTime: Infinity,
  retry: retryServerFaults,
});

export function personQuery(rollupId: number) {
  return queryOptions({
    queryKey: ['people', 'person', rollupId],
    queryFn: ({ signal }) => getJSON<PersonSheet>(`/api/v1/people/${rollupId}`, undefined, signal),
    // A rollup built again since the list was read may number no one so: said at once, not after retries.
    retry: retryServerFaults,
  });
}

/** A subject's covering volumes, from the server's bundled files, which do not change while it runs. */
export function subjectVolumesQuery(ref: string) {
  return queryOptions({
    queryKey: ['subjects', ref, 'volumes'],
    queryFn: ({ signal }) => getJSON<SubjectVolumes>(`/api/v1/subjects/${segment(ref)}/volumes`, undefined, signal),
    staleTime: Infinity,
    retry: retryServerFaults,
  });
}

export const personCorrectionsQuery = queryOptions({
  queryKey: ['people', 'corrections'],
  queryFn: ({ signal }) => getJSON<PersonCorrections>('/api/v1/me/people/corrections', undefined, signal),
  retry: retryServerFaults,
});

export function classificationQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['classification', volumeId, documentId],
    queryFn: ({ signal }) =>
      getJSON<DocumentClassification>(`/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/classification`, undefined, signal),
    retry: retryServerFaults,
  });
}

/**
 * After a correction: every query that reads what the server indexes, as when its index changes, since a
 * document's classification shapes searches, their facets, Browse's badges and the reader's page, and a person
 * correction renumbers the people; and the searches' own.
 */
function corrected(client: QueryClient) {
  for (const key of corpusQueryKeys) void client.invalidateQueries({ queryKey: [key] });
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
