// Search by meaning (PLAN's S27d): the server's status, which says whether it searches by meaning, and a page of a
// search by meaning, the kit's Meaning engine's run over the served index, with what the app's Meaning mode shows of
// it: the strip's sentences, every count the run owes the reader, and the hits in volumes this server does not serve.
import { queryOptions } from '@tanstack/react-query';
import { getJSON, postForm } from './client';
import { retryServerFaults } from './endpoints';
import { formEncode } from './form';
import type { SearchResultList } from './types';
import { filterFields, searchFields, type SearchState } from '../search/searchState';

/** Which of the semantic features the server serves (`SemanticFeatures`, PLAN's S26c). */
export interface SemanticFeatures {
  vectors: boolean;
  generation?: string;
  shardsHeld: number;
  shardsPublished: number;
  map: boolean;
  encoder: boolean;
  relatedDocuments: boolean;
  /** Whether the server searches by meaning: its vectors served, and its encoder able to start (S27d). */
  searchByMeaning: boolean;
}

/** `GET /api/v1/status`, of which the browser app reads the semantic features. */
export interface ServerStatus {
  version: string;
  semantic?: SemanticFeatures;
}

/** The server's status: what it serves changes only when it starts again, so it is read once a while. */
export const serverStatusQuery = queryOptions({
  queryKey: ['status'],
  queryFn: ({ signal }) => getJSON<ServerStatus>('/api/v1/status', undefined, signal),
  staleTime: 5 * 60_000,
  retry: retryServerFaults,
});

/** Every count a Meaning search owes the reader (the kit's `SemanticSearchBackend.Disclosure`). */
export interface MeaningDisclosure {
  unscoredCandidates: number;
  unscoredVolumes: number;
  downloadingVolumes: number;
  filtersApplied: boolean;
  filteredOut: number;
  beyondUncheckedByFilters: boolean;
  /** The set a search inside a working corpus ranked, or absent for one of the whole series. */
  rankedWithin?: number;
  withoutVector: number;
  notIndexedHere: number;
  rankedCount?: number;
}

/** A hit in a volume this server does not serve, titled from the catalogue, with the kit's chip. */
export interface MeaningBeyondHit {
  volumeId: string;
  documentId: string;
  volumeTitle: string;
  score: number;
  chip: string;
}

/** What a run of a search by meaning says beside its rows. */
export interface MeaningRunSummary {
  /** The question as the kit ranked it, trimmed. */
  question: string;
  /** The strip's sentences, the kit's, in the server's words: the opening, then each thing the run owes the reader. */
  strip: string[];
  /** The sentence under "No semantic matches yet", for a run that listed no row. */
  emptyStatement: string;
  disclosure: MeaningDisclosure;
  beyondLibrary: MeaningBeyondHit[];
  /** The heading over the hits beyond the library, when there are any. */
  beyondHeader?: string;
  /** The volumes whose match file the server lacks, whose candidates were dropped: none while the image holds every one. */
  missingShards: string[];
  renderedExpression: string;
  signature: string;
}

/** A page of a search by meaning: a keyword search's page in shape, its rows ranked by meaning, and the run's account. */
export interface MeaningSearchResult extends SearchResultList {
  meaning: MeaningRunSummary;
}

/**
 * A page of the search by meaning `state` says, with the rows Checklist Mode hides left out of its pages. The server
 * keeps the run a while, so another page, another order or a mark asks its encoder nothing again. The same search's last
 * page stays while the next loads; another question's never stands in, since its strip and its rows would describe a
 * run no longer asked for. A request the screen no longer wants is abandoned, and the server stops the search.
 */
export function meaningQuery(state: SearchState, reviewed: readonly string[], enabled: boolean) {
  const search = filterFields(state);
  const fields = searchFields(state);
  return queryOptions<MeaningSearchResult, unknown, MeaningSearchResult, unknown[]>({
    queryKey: ['meaning', search, fields, reviewed],
    queryFn: ({ signal }) =>
      reviewed.length > 0
        ? postForm<MeaningSearchResult>('/api/v1/search/meaning', formEncode({ ...fields, reviewed: [...reviewed].sort() }), signal)
        : getJSON<MeaningSearchResult>('/api/v1/search/meaning', formEncode(fields), signal),
    enabled: enabled && state.keywords !== undefined,
    staleTime: 5 * 60_000,
    placeholderData: (previous, query) => (query !== undefined && JSON.stringify(query.queryKey[1]) === JSON.stringify(search) ? previous : undefined),
    retry: retryServerFaults,
  });
}
