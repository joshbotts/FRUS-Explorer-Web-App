// One function per endpoint the app calls, and the query options that cache them.
import { keepPreviousData, queryOptions } from '@tanstack/react-query';
import { servedPath } from './base';
import { ApiError, getJSON, postForm } from './client';
import { formEncode, type FormValue } from './form';
import type {
  CitationBatch,
  CitationFields,
  CitationLookupForm,
  CitationLookupMatch,
  CitationLookupMode,
  CitationStyleName,
  DocumentCitation,
  FacetSectionName,
  SearchFacetSection,
  SearchFacetSelection,
  DocumentDetail,
  DocumentList,
  Readiness,
  ReaderLinkTarget,
  SearchConcordance,
  SearchInspection,
  SearchResultList,
  SearchTimeline,
  Volume,
  VolumeList,
  VolumeSectionPage,
} from './types';
import type { SearchState } from '../search/searchState';
import { filterFields, searchFields } from '../search/searchState';

const segment = encodeURIComponent;

/** A document's path at the server's root, which `getJSON` and the URLs below put under the base path. */
export function documentPath(volumeId: string, documentId: string): string {
  return `/api/v1/volumes/${segment(volumeId)}/documents/${segment(documentId)}`;
}

/** The reader's page for the frame, in the app's appearance, text size and reading width. */
export function readerPageURL(
  volumeId: string,
  documentId: string,
  colorScheme: 'light' | 'dark',
  textSize: TextSize,
  readingWidth: ReadingWidth,
): string {
  return `${servedPath(documentPath(volumeId, documentId))}/html?${formEncode({ colorScheme, textSize, readingWidth })}`;
}

export type TextSize = 'small' | 'medium' | 'large' | 'extraLarge';

/** The app's Reading Width, whose measure for the page's column the server sets: 70, 87 or 120ch. */
export type ReadingWidth = 'narrow' | 'standard' | 'wide';

/** `/readyz` answers 503 with the step until an index is served, so its body is read either way. */
export async function fetchReadiness(signal?: AbortSignal): Promise<Readiness> {
  const response = await fetch(servedPath('/readyz'), { signal, headers: { Accept: 'application/json' } });
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

/** Whether an earlier query's answer is the same search's, which may stand in while the next loads. */
function sameSearch(query: { queryKey: readonly unknown[] } | undefined, search: Record<string, FormValue>): boolean {
  return query !== undefined && JSON.stringify(query.queryKey[1]) === JSON.stringify(search);
}

/**
 * The search's timeline: its years and counts, and with `documents` each year's documents in the
 * order chosen. The same search's last timeline stays while the next loads, as the results' last
 * page does; another search's never stands in, since it would describe a match no longer shown.
 */
export function timelineQuery(state: SearchState, documents: boolean) {
  const search = filterFields(state);
  const fields = { ...search, ...(documents ? { documents: true, sort: state.sort } : {}) };
  return queryOptions<SearchTimeline, unknown, SearchTimeline, unknown[]>({
    queryKey: ['timeline', search, documents ? (state.sort ?? 'relevance') : null],
    queryFn: ({ signal }) => getJSON<SearchTimeline>('/api/v1/search/timeline', formEncode(fields), signal),
    enabled: state.keywords !== undefined,
    staleTime: 5 * 60_000,
    placeholderData: (previous, query) => (sameSearch(query, search) ? previous : undefined),
    retry: retryServerFaults,
  });
}

/**
 * The concordance of the page the results show, by its fields. The same search's last page stays
 * while the next loads, as the results' does; another search's never stands in.
 */
export function concordanceQuery(state: SearchState) {
  const search = filterFields(state);
  const fields = searchFields(state);
  return queryOptions<SearchConcordance, unknown, SearchConcordance, unknown[]>({
    queryKey: ['concordance', search, fields],
    queryFn: ({ signal }) => getJSON<SearchConcordance>('/api/v1/search/concordance', formEncode(fields), signal),
    enabled: state.keywords !== undefined,
    staleTime: 5 * 60_000,
    placeholderData: (previous, query) => (sameSearch(query, search) ? previous : undefined),
    retry: retryServerFaults,
  });
}

/** The Query Inspector's expensive passes: each term counted within the filters, and the terms that match nothing. */
export interface InspectorPasses {
  scopedCounts?: true;
  emptyConjuncts?: true;
}

/**
 * The Query Inspector's account of the search `fields` say, with each expensive pass asked for. A
 * pass runs when the reader's action asks for it, as on the Mac, and never again on its own: only a
 * new index, which invalidates every account, asks for it again.
 */
export function inspectQuery(fields: Record<string, FormValue>, passes: InspectorPasses = {}) {
  const asked = { ...fields, ...passes };
  const expensive = passes.scopedCounts === true || passes.emptyConjuncts === true;
  return queryOptions<SearchInspection, unknown, SearchInspection, unknown[]>({
    queryKey: ['inspect', asked],
    queryFn: ({ signal }) => getJSON<SearchInspection>('/api/v1/search/inspect', formEncode(asked), signal),
    ...(expensive ? { staleTime: Infinity, refetchOnWindowFocus: false, refetchOnReconnect: false } : { staleTime: 5 * 60_000 }),
    retry: retryServerFaults,
  });
}

/** How a facet section's rows are cut: the kit's sort, page size, page and filter, each its standard when absent. */
export interface FacetDisplay {
  sort?: string;
  pageSize?: string;
  page?: number;
  filter?: string;
}

/** One section of a search's facets, as the panel shows it. */
export function facetSectionQuery(state: SearchState, section: FacetSectionName, display: FacetDisplay) {
  const search = filterFields(state);
  const fields = {
    ...search,
    section,
    facetSort: display.sort,
    facetPageSize: display.pageSize,
    facetPage: display.page ? display.page : undefined,
    facetFilter: display.filter ? display.filter : undefined,
  };
  return queryOptions<SearchFacetSection, unknown, SearchFacetSection, unknown[]>({
    queryKey: ['facets', search, section, fields],
    queryFn: ({ signal }) => getJSON<SearchFacetSection>('/api/v1/search/facets', formEncode(fields), signal),
    staleTime: 5 * 60_000,
    // The section's last page stays while another of the same search loads, so its controls keep
    // their focus; a section of another search never stands in, since its rows would describe a
    // match that is no longer shown.
    placeholderData: (previous, query) =>
      query && JSON.stringify(query.queryKey[1]) === JSON.stringify(search) && query.queryKey[2] === section ? previous : undefined,
    retry: retryServerFaults,
  });
}

/** What a staged selection of years or volumes narrows the search to, as Apply sets it. */
export function fetchFacetSelection(
  state: SearchState,
  section: 'years' | 'volumes',
  included: readonly string[],
  excluded: readonly string[],
): Promise<SearchFacetSelection> {
  const fields = {
    ...filterFields(state),
    section,
    include: included.length > 0 ? included : undefined,
    exclude: excluded.length > 0 ? excluded : undefined,
  };
  return getJSON<SearchFacetSelection>('/api/v1/search/facets/selection', formEncode(fields));
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

/** A document's BibTeX or RIS record as a file to save, named as the Mac names its .bib file. */
export function citationFileURL(volumeId: string, documentId: string, suffix: 'bib' | 'ris'): string {
  return `${servedPath(documentPath(volumeId, documentId))}/citation.${suffix}`;
}

/** What Citation Lookup's form holds for a request: its mode, the paste's text, and the fields given. */
export interface CitationFormRequest {
  mode: CitationLookupMode;
  /** Paste Citation's and Batch's text; Structured Entry reads none. */
  text?: string;
  /** The fields given: in Paste Citation the reader's edits alone, which stand over what the text yields. */
  fields?: Partial<CitationFields>;
}

function citationFormFields(request: CitationFormRequest): Record<string, FormValue> {
  return { mode: request.mode, text: request.mode === 'structured' ? undefined : (request.text ?? ''), ...request.fields };
}

/**
 * The kit's form for `request`: the Parsed Fields a paste yields with the reader's edits over them,
 * and whether Look Up has anything to go on. The last answer stays while the next loads, so the
 * fields and Look Up do not flicker as the text is typed.
 */
export function citationFormQuery(request: CitationFormRequest) {
  const fields = citationFormFields(request);
  return queryOptions<CitationLookupForm, unknown, CitationLookupForm, unknown[]>({
    queryKey: ['citationForm', fields],
    queryFn: ({ signal }) => getJSON<CitationLookupForm>('/api/v1/citation-lookup/fields', formEncode(fields), signal),
    staleTime: Infinity,
    placeholderData: keepPreviousData,
    retry: retryServerFaults,
  });
}

/**
 * One lookup, Paste Citation's or Structured Entry's, as Look Up ran it. Its answer depends on the
 * index, so readiness refetches it; it is kept for half an hour, so a document opened from it and
 * Back find it as it was, as the app's window keeps its matches while the reader works through them.
 */
export function citationLookupQuery(request: CitationFormRequest | undefined) {
  const fields = request ? citationFormFields(request) : null;
  return queryOptions<CitationLookupMatch[], unknown, CitationLookupMatch[], unknown[]>({
    queryKey: ['citationLookup', fields],
    queryFn: ({ signal }) => getJSON<CitationLookupMatch[]>('/api/v1/citation-lookup', formEncode(fields ?? {}), signal),
    enabled: fields !== null,
    staleTime: Infinity,
    gcTime: 30 * 60_000,
    retry: retryServerFaults,
  });
}

/** Batch's table for a block of notes, as Look Up ran it, kept as a lookup is. */
export function citationBatchQuery(text: string | undefined) {
  return queryOptions<CitationBatch, unknown, CitationBatch, unknown[]>({
    queryKey: ['citationBatch', text ?? null],
    queryFn: ({ signal }) => postForm<CitationBatch>('/api/v1/citation-lookup/batch', formEncode({ text: text ?? '' }), signal),
    enabled: text !== undefined,
    staleTime: Infinity,
    gcTime: 30 * 60_000,
    retry: retryServerFaults,
  });
}

/** Retries a network failure or a server fault twice; never a refusal, nor a 503 while importing. */
export function retryServerFaults(failures: number, error: unknown): boolean {
  if (failures >= 2) return false;
  if (error instanceof ApiError) return error.status >= 500 && error.status !== 503;
  return true;
}
