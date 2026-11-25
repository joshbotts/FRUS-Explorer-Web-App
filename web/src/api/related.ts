// Related Documents (PLAN's S23d): the documents related to one, ranked by the kit's engine on the
// server, with the app's weights, scope and "why related" chips; and the tuning this browser keeps, as
// the app keeps its device's (`SettingsKeys.relatedAxisWeights`), which Suggested Next's Refresh hands
// the server for a project with no tuning of its own. Since S26d each row says its semantic score and the
// verdict the user gave it, a verdict is sent from a row's menu, and a list carries Beyond your library.
import { type QueryClient, queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';
import { change } from './userData';

const segment = encodeURIComponent;

/** A scope of the app's picker: this volume, this subseries, or all volumes. */
export type RelatedScope = 'volume' | 'subseries' | 'all';

/** One of the app's eight axes, as this list was ranked. */
export interface RelatedAxis {
  /** Its stored name, which a tuning keys it by. */
  id: string;
  /** Its name in the app's words. */
  name: string;
  weight: number;
  defaultWeight: number;
  /** Whether it can contribute on this server: not shared subjects without the subject index, nor the semantic axis without the vectors. */
  available: boolean;
}

/** One "why related" chip: the axis's name, which a screen reader hears first, and the chip's words. */
export interface RelatedChip {
  axis: string;
  name: string;
  text: string;
}

export interface RelatedRow {
  volumeId: string;
  documentId: string;
  /** Its head, which may be empty: the row then shows the document's id, as the app's does. */
  header: string;
  dateline?: string;
  documentNumber?: string;
  isEditorialNote: boolean;
  score: number;
  snippet?: string;
  chips: RelatedChip[];
  /** The semantic axis's score of it, when that axis scored it: only such a row carries the verdicts' menu. */
  semanticScore?: number;
  /** The verdict the user gave on it, if any. */
  verdict?: SemanticVerdict;
}

/** The app's two verdicts on a semantic match. */
export type SemanticVerdict = 'helpful' | 'notHelpful';

/** Beyond your library: what the semantic axis saw in volumes this server does not serve. */
export interface BeyondLibrary {
  /** The kit's sentence. */
  caption: string;
  documentCount: number;
  volumeCount: number;
  isCapped: boolean;
  /**
   * Up to five documents named and scored, where both shards are held; `served` where this server serves the volume,
   * as a scoped list's leads, which look past its scope, may name.
   */
  documents: { volumeId: string; documentId: string; volumeTitle: string; score: number; chip: string; served: boolean }[];
  /** The first five volumes, most matches first, each with its count in the kit's words. */
  volumes: { volumeId: string; title: string; count: number; countText: string }[];
  /** The kit's line for the volumes past five. */
  moreVolumes?: string;
}

export interface RelatedDocuments {
  volumeId: string;
  documentId: string;
  scope: RelatedScope;
  /** The scopes the picker offers, in its order. */
  scopes: RelatedScope[];
  /** The tuning ranked with, in the app's stored form. */
  weights: string;
  axes: RelatedAxis[];
  rows: RelatedRow[];
  /** How many documents scored before the list was cut: the app's "N more related". */
  totalBeforeLimit: number;
  /** The footer under a list whose archival pool was cut. */
  poolCut?: string;
  beyondLibrary?: BeyondLibrary;
  /** The served volumes whose shards are missing, whose documents the semantic axis dropped. */
  missingShards: string[];
}

export function relatedQuery(volumeId: string, documentId: string, scope: RelatedScope, weights: string) {
  const params = new URLSearchParams({ scope });
  if (weights) params.set('weights', weights);
  return queryOptions({
    queryKey: ['related', volumeId, documentId, scope, weights],
    queryFn: ({ signal }) =>
      getJSON<RelatedDocuments>(`/api/v1/volumes/${segment(volumeId)}/documents/${segment(documentId)}/related`, params, signal),
    staleTime: 5 * 60_000,
    retry: false,
  });
}

/**
 * A verdict on a row of `anchor`'s list, `volumeId/documentId` each, kept with the user's account: the row says it in
 * every list of the anchor the browser holds, and Settings ▸ Data's summary is read again. A list of the anchor still
 * coming may have been ranked before the verdict was kept, so it is stopped, and asked for again once the verdict is
 * written into the lists the browser holds.
 */
export async function recordVerdict(client: QueryClient, anchor: string, neighbour: string, verdict: SemanticVerdict): Promise<void> {
  await change(client, 'POST', '/api/v1/me/semantic-feedback', { anchor, neighbour, verdict });
  const [volumeId, documentId] = anchor.split('/');
  const lists = { queryKey: ['related', volumeId, documentId] };
  const coming = client.isFetching(lists) > 0;
  if (coming) await client.cancelQueries(lists);
  client.setQueriesData<RelatedDocuments>(lists, (list) =>
    list && {
      ...list,
      rows: list.rows.map((row) => (`${row.volumeId}/${row.documentId}` === neighbour ? { ...row, verdict } : row)),
    },
  );
  if (coming) void client.invalidateQueries(lists);
  void client.invalidateQueries({ queryKey: ['semanticFeedback'] });
}

/** Where this browser keeps its tuning: the app's own key for it. */
const weightsKey = 'frus.related.weights';

/** The tuning this browser keeps, or undefined for none: the app's defaults. */
export function storedWeights(): string | undefined {
  try {
    return localStorage.getItem(weightsKey) ?? undefined;
  } catch {
    return undefined;
  }
}

/** Keeps a tuning for the next list this browser opens, or forgets it, as the app's Reset clears its key. */
export function storeWeights(weights: string | undefined): void {
  try {
    if (weights === undefined) localStorage.removeItem(weightsKey);
    else localStorage.setItem(weightsKey, weights);
  } catch {
    // A browser that keeps nothing opens each list at the defaults.
  }
}
