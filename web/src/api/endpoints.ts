// One function per endpoint the app calls, and the query options that cache them.
import { keepPreviousData, queryOptions } from '@tanstack/react-query';
import { ApiError, getJSON } from './client';
import { formEncode } from './form';
import type {
  CitationStyleName,
  DocumentCitation,
  DocumentDetail,
  DocumentList,
  Readiness,
  ReaderLinkTarget,
  SearchResultList,
  Volume,
  VolumeList,
  VolumeSectionPage,
} from './types';
import type { SearchState } from '../search/searchState';
import { searchFields } from '../search/searchState';

const segment = encodeURIComponent;

export function documentPath(volumeId: string, documentId: string): string {
  return `/api/v1/volumes/${segment(volumeId)}/documents/${segment(documentId)}`;
}

/** The reader's page for the frame, in the app's appearance and text size. */
export function readerPageURL(
  volumeId: string,
  documentId: string,
  colorScheme: 'light' | 'dark',
  textSize: TextSize,
): string {
  return `${documentPath(volumeId, documentId)}/html?${formEncode({ colorScheme, textSize })}`;
}

export type TextSize = 'small' | 'medium' | 'large' | 'extraLarge';

/** `/readyz` answers 503 with the step until an index is served, so its body is read either way. */
export async function fetchReadiness(signal?: AbortSignal): Promise<Readiness> {
  const response = await fetch('/readyz', { signal, headers: { Accept: 'application/json' } });
  return (await response.json()) as Readiness;
}

export const readinessQuery = queryOptions({
  queryKey: ['readyz'],
  queryFn: ({ signal }) => fetchReadiness(signal),
  refetchInterval: (query) => (query.state.data?.ready ? 30_000 : 2_000),
});

/** The whole catalogue, 553 volumes, in one request; it changes only with the server's build. */
export const volumesQuery = queryOptions({
  queryKey: ['volumes'],
  queryFn: ({ signal }) => getJSON<VolumeList>('/api/v1/volumes', formEncode({ limit: 1000 }), signal),
  staleTime: Infinity,
});

/** One volume with its sections; they change with the index, so readiness refetches them. */
export function volumeQuery(volumeId: string) {
  return queryOptions({
    queryKey: ['volume', volumeId],
    queryFn: ({ signal }) => getJSON<Volume>(`/api/v1/volumes/${segment(volumeId)}`, undefined, signal),
    staleTime: 5 * 60_000,
    retry: retryServerFaults,
  });
}

export function sectionQuery(volumeId: string, sectionId: string) {
  return queryOptions({
    queryKey: ['section', volumeId, sectionId],
    queryFn: ({ signal }) =>
      getJSON<VolumeSectionPage>(`/api/v1/volumes/${segment(volumeId)}/sections/${segment(sectionId)}`, undefined, signal),
    staleTime: 5 * 60_000,
    retry: retryServerFaults,
  });
}

/** A volume's reading order from the index, for a volume whose sections neither the index nor the TEI gives. */
export function readingOrderQuery(volumeId: string) {
  return queryOptions({
    queryKey: ['readingOrder', volumeId],
    queryFn: ({ signal }) =>
      getJSON<DocumentList>(`/api/v1/volumes/${segment(volumeId)}/documents`, formEncode({ limit: 1000 }), signal),
    staleTime: 5 * 60_000,
    retry: retryServerFaults,
  });
}

/** What a link in a document's page leads to; the same link always leads to the same place. */
export function linkQuery(volumeId: string, documentId: string, href: string) {
  return queryOptions({
    queryKey: ['link', volumeId, documentId, href],
    queryFn: ({ signal }) => getJSON<ReaderLinkTarget>(`${documentPath(volumeId, documentId)}/link`, formEncode({ href }), signal),
    staleTime: Infinity,
    retry: retryServerFaults,
  });
}

export function searchQuery(state: SearchState) {
  return queryOptions({
    queryKey: ['search', searchFields(state)],
    queryFn: ({ signal }) => getJSON<SearchResultList>('/api/v1/search', formEncode(searchFields(state)), signal),
    enabled: state.keywords !== undefined,
    staleTime: 5 * 60_000,
    // The page before stays while the next loads, so the results and the pager stay mounted.
    placeholderData: keepPreviousData,
    retry: retryServerFaults,
  });
}

export function documentQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['document', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentDetail>(documentPath(volumeId, documentId), undefined, signal),
    staleTime: Infinity,
    retry: retryServerFaults,
  });
}

export function citationQuery(volumeId: string, documentId: string, style: CitationStyleName) {
  return queryOptions<DocumentCitation, unknown, DocumentCitation, string[]>({
    queryKey: ['citation', volumeId, documentId, style],
    queryFn: ({ signal }) =>
      getJSON<DocumentCitation>(`${documentPath(volumeId, documentId)}/citation`, formEncode({ style }), signal),
    staleTime: Infinity,
    // Another style of the same document stays while the new one loads, so the style choices stay
    // mounted and keep their focus; another document's citation never stands in.
    placeholderData: (previous: DocumentCitation | undefined) =>
      previous?.volumeId === volumeId && previous.documentId === documentId ? previous : undefined,
    retry: retryServerFaults,
  });
}

/** Retries a network failure or a server fault twice; never a refusal, nor a 503 while importing. */
export function retryServerFaults(failures: number, error: unknown): boolean {
  if (failures >= 2) return false;
  if (error instanceof ApiError) return error.status >= 500 && error.status !== 503;
  return true;
}
