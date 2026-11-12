// Related Documents (PLAN's S23d): the documents related to one, ranked by the kit's engine on the
// server, with the app's weights, scope and "why related" chips; and the tuning this browser keeps, as
// the app keeps its device's (`SettingsKeys.relatedAxisWeights`), which Suggested Next's Refresh hands
// the server for a project with no tuning of its own.
import { queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';

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
  /** Whether it can contribute on this server (the lexical and semantic axes cannot yet). */
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
