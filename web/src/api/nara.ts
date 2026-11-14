// The NARA Catalog proxy, Look Up and Send to Zotero Library (PLAN's S22e). The server asks NARA and Zotero
// with the keys it keeps, the user's own or for NARA the instance's, which never reach the page: a search is
// sent to the server, as a change is, with the user's token, and its answer is NARA's records alone. Look
// Up's candidates are the kit's reading of a selection and the passage around it, which needs no key; a
// send gives what Zotero took.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import { change } from './userData';

const segment = encodeURIComponent;

/**
 * A search of the NARA Catalog: Look Up's, a strategy of the kit's with its text; or Source Explorer's, the
 * query the app's `load()` runs for a note, as its NARA Catalog section names it.
 */
export interface NARASearch {
  strategy?: string;
  query?: string;
  route?: string;
  lot?: string;
  recordGroup?: string;
  keywords?: string;
  library?: string;
  collection?: string;
}

/** A NARA Catalog record as the app's rows show it. */
export interface NARACatalogRecord {
  naId: string;
  title: string;
  catalogURL: string;
  scopeNote?: string;
  recordGroupNumber?: string;
  seriesTitle?: string;
  dateRange?: string;
}

export interface NARASearchAnswer {
  results: NARACatalogRecord[];
  /** Whether the server kept the answer from an earlier search of the same query. */
  cached: boolean;
}

/** `GET /api/v1/nara`: whose key a search uses, and with the instance's the user's calls of the day. */
export interface NARAStatus {
  key?: 'user' | 'instance';
  quota?: { used: number; limit: number };
  offline: boolean;
}

export const naraStatusQuery = queryOptions({
  queryKey: ['nara'],
  queryFn: ({ signal }) => getJSON<NARAStatus>('/api/v1/nara', undefined, signal),
  staleTime: 0,
  retry: false,
});

/** Whether a search has a key to be asked with: the user's or the instance's. An offline server says why it asks nothing. */
export function canSearch(status: NARAStatus | undefined): boolean {
  return !!status?.key;
}

/** Runs `search`; the user's count of the day is read again after it. */
export async function searchNARA(client: QueryClient, search: NARASearch): Promise<NARASearchAnswer> {
  const answer = (await change<NARASearchAnswer>(client, 'POST', '/api/v1/nara/search', search))!;
  void client.invalidateQueries({ queryKey: naraStatusQuery.queryKey });
  return answer;
}

/** One reading of a selection (`NARALookupCandidate`), with the record the bundled indexes give it. */
export interface LookUpCandidate {
  id: string;
  label: string;
  query: string;
  strategy: string;
  origin: 'selection' | 'context';
  resolution?: { naId: string; title: string; catalogURL: string };
}

/** A strategy of the kit's, in its words, and whether it searches NARA, which needs a key. */
export interface LookUpStrategy {
  id: string;
  name: string;
  hint: string;
  searches: boolean;
}

/** A filing period and its manuals (`SourceExplorerPanels.allFilingPeriods`). */
export interface FilingPeriod {
  id: string;
  label: string;
  url: string;
  manuals: { url: string; label?: string }[];
}

/** Look Up's sheet: the readings, best first, the strategy it opens on, the strategies and the periods. */
export interface LookUpAnswer {
  candidates: LookUpCandidate[];
  strategy: string;
  strategies: LookUpStrategy[];
  periods: FilingPeriod[];
}

/**
 * What the reader sends of a selection: its text, and its offsets in the document's flat text when it is in
 * the text, or its footnote's text when it is in a footnote.
 */
export interface LookUpSelection {
  text: string;
  start?: number;
  end?: number;
  blockText?: string;
}

export function lookUpQuery(client: QueryClient, volumeId: string, documentId: string, selection: LookUpSelection) {
  return queryOptions({
    queryKey: ['lookUp', volumeId, documentId, selection],
    queryFn: async () =>
      (await change<LookUpAnswer>(client, 'POST', `/api/v1/volumes/${segment(volumeId)}/documents/${segment(documentId)}/lookup`, selection))!,
    staleTime: Infinity,
    retry: false,
  });
}

/** What a send to Zotero added (`ZoteroSendResult`). */
export interface ZoteroSent {
  addedItems: number;
  failedItems: number;
  addedNotes: number;
  webURL?: string;
}

/** Cite's send: the document, with the user's tags and notes, into their Zotero library. */
export async function sendDocumentToZotero(client: QueryClient, volumeId: string, documentId: string): Promise<ZoteroSent> {
  return (await change<ZoteroSent>(client, 'POST', `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/zotero`))!;
}

/** The export sheet's: the collection's documents, into a Zotero collection of its name; kept in the history. */
export async function sendCollectionToZotero(client: QueryClient, collectionId: string): Promise<ZoteroSent> {
  const sent = (await change<ZoteroSent>(client, 'POST', `/api/v1/me/collections/${segment(collectionId)}/zotero`))!;
  void client.invalidateQueries({ queryKey: ['history'] });
  return sent;
}
