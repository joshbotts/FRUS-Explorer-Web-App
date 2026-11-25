// Search Within These Results and the fallback (PLAN's S27e): a held list as its row names it, a layer's page inside it,
// and the Semantic matches (experimental) under a keyword search that found nothing, each the kit's on the server. The
// held list is named as the server reads it, `within`: the query string of the search that found it, with its engine and
// the rows Checklist Mode hid when it was held.
import { queryOptions } from '@tanstack/react-query';
import { getJSON, postForm } from './client';
import { retryServerFaults } from './endpoints';
import { formEncode } from './form';
import type { MeaningDisclosure } from './meaning';
import type { SearchResultList } from './types';
import { filterFields, searchFields, type SearchState } from '../search/searchState';

/** The ways a layer runs (the kit's `SearchLayerDirection`). */
export type LayerDirection = 'wordsInMatches' | 'rankByMeaning';

/** A held list, as its row says it (the kit's `PinnedResultBase`), every sentence the kit's in the server's words. */
export interface HeldListSummary {
  direction: LayerDirection;
  kind: 'meaning' | 'keywords' | 'browse';
  query: string;
  describedQuery?: string;
  rows: number;
  members: number;
  hiddenByChecklist: number;
  notDownloaded: number;
  wasCut: boolean;
  ranksWholeMatch: boolean;
  wholeMatchCount?: number;
  /** "100 closest matches to “…”". */
  setDescription: string;
  /** "Within 100 closest matches to “…”", and what a screen reader hears of the row. */
  rowDescription: string;
  accessibilityLabel: string;
  /** What the list held that a layer leaves out. */
  leftOutDescription?: string;
  /** "Back to the 100 Matches". */
  backTitle: string;
  captureLabel?: string;
  startTitle: string;
  fieldPrompt: string;
  signaturePart: string;
}

/** The route a layer's rows came from. */
export interface LayerRoute {
  kind: 'wordsInMatches' | 'rankedByMeaning';
  base?: number;
  unranked?: number;
  wholeMatch?: { size: number; filteredOut: number; notRanked: number; closest: number; isCut: boolean };
}

/** What the app says of a layer beside its rows. */
export interface LayerSummary {
  direction: LayerDirection;
  query: string;
  route: LayerRoute;
  /** The results header's sentence, the app's for the layered routes. */
  header: string;
  filtersNarrowed: boolean;
  /** The first row a ranking could not rank, as the list is shown, and the line over the rows from it. */
  unrankedTail?: { firstKey: string; count: number; line: string };
  /** What a layer of no row shows. */
  empty?: { statement: string; searchLibraryTitle?: string; backTitle: string };
  /** A ranking's account, the Meaning strip's sentences. */
  strip?: string[];
  disclosure?: MeaningDisclosure;
  /** The held list and this layer swapped, where both have words of their own. */
  swap?: { direction: LayerDirection; listQuery: string; layerQuery: string; help: string };
  renderedExpression?: string;
  signature: string;
  base: HeldListSummary;
}

/** A page of a layer: a keyword search's page in shape, and the layer's account. */
export interface LayeredSearchResult extends SearchResultList {
  layer: LayerSummary;
}

/** A fallback's hit: a document the server holds, which opens, or one of a volume it does not. */
export interface FallbackHit {
  volumeId: string;
  documentId: string;
  score: number;
  chip: string;
  opens: boolean;
  displayTitle?: string;
  dateline?: string;
  documentLabel?: string;
  isEditorialNote: boolean;
  volumeTitle: string;
}

/** The Semantic matches (experimental) under a keyword search that found nothing. */
export interface MeaningFallback {
  question: string;
  caption: string;
  hits: FallbackHit[];
  emptyStatement?: string;
  unscoredCandidates: number;
  unscoredVolumes: number;
  missingShards: string[];
}

/** Sends `fields` as a query string, or in a body once it is long, as a list whose checklist hid many rows makes it. */
function ask<T>(path: string, fields: URLSearchParams, signal: AbortSignal): Promise<T> {
  return fields.toString().length > 1_500 ? postForm<T>(path, fields, signal) : getJSON<T>(path, fields, signal);
}

/** What the row of the list `within` names says of it; the server keeps the list, so asking again costs nothing. */
export function heldQuery(within: string | undefined) {
  return queryOptions<HeldListSummary, unknown, HeldListSummary, unknown[]>({
    queryKey: ['held', within],
    queryFn: ({ signal }) => ask<HeldListSummary>('/api/v1/search/held', formEncode({ within }), signal),
    enabled: within !== undefined,
    staleTime: 5 * 60_000,
    retry: retryServerFaults,
  });
}

/**
 * A page of the layer `state` says inside the list `within` names: the field's words or question, the filters and the
 * corpus in force, its order and page, and the rows Checklist Mode hides now. The same layer's last page stays while the
 * next loads; another's never stands in. A layer the screen no longer wants is abandoned, and the server stops it.
 */
export function layerQuery(state: SearchState, within: string | undefined, reviewed: readonly string[], enabled: boolean) {
  const search = filterFields(state);
  const fields = searchFields(state);
  return queryOptions<LayeredSearchResult, unknown, LayeredSearchResult, unknown[]>({
    queryKey: ['layer', within, search, fields, reviewed],
    queryFn: ({ signal }) =>
      ask<LayeredSearchResult>(
        '/api/v1/search/within',
        formEncode({ ...fields, within, ...(reviewed.length > 0 ? { reviewed: [...reviewed].sort() } : {}) }),
        signal,
      ),
    enabled: enabled && within !== undefined && (state.keywords ?? '').trim() !== '',
    staleTime: 5 * 60_000,
    placeholderData: (previous, query) =>
      query !== undefined && query.queryKey[1] === within && JSON.stringify(query.queryKey[2]) === JSON.stringify(search) ? previous : undefined,
    retry: retryServerFaults,
  });
}

/**
 * The Semantic matches (experimental) under the keyword search `state` says, which found nothing: the nearest across the
 * whole series, its filters not applied, which the caption says where it had any. Asked for only while the server
 * searches by meaning.
 */
export function fallbackQuery(state: SearchState, enabled: boolean) {
  const search = filterFields(state);
  return queryOptions<MeaningFallback, unknown, MeaningFallback, unknown[]>({
    queryKey: ['fallback', search],
    queryFn: ({ signal }) => getJSON<MeaningFallback>('/api/v1/search/fallback', formEncode(search), signal),
    enabled: enabled && (state.keywords ?? '').trim() !== '',
    staleTime: 5 * 60_000,
    retry: false,
  });
}
