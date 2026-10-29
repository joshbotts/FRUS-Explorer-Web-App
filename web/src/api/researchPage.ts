// The Research page (PLAN's S19b), under /api/v1/me: its categories with their counts, and one
// category's documents, each as the app's `ResearchView` computes it over the kit's
// `ResearchDocumentAggregation`. Both are asked again each time the page opens, since a note,
// highlight, tag or collection changed anywhere else changes them.
import { queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';
import type { HighlightColor } from './types';

/** A collection or a tag in the sidebar: what its row prints and how many documents its list holds. */
export interface ResearchGroup {
  id: string;
  name: string;
  count: number;
}

/** The page's categories, as the app's sidebar lists them, with their counts. */
export interface ResearchPage {
  allAnnotated: number;
  hasNotes: number;
  notes: number;
  /** By Collection: by the name each prints. */
  collections: ResearchGroup[];
  /** By Tag: the most used first. */
  tags: ResearchGroup[];
  /** By Highlight: in the kit's order of the colours. */
  highlightColors: { color: HighlightColor; count: number }[];
}

/** A row of a Research list, as the app's draws it. */
export interface ResearchDocument {
  volumeId: string;
  documentId: string;
  /** The kit's display title of the served index's head, or the document's id. */
  title: string;
  volumeTitle: string;
  /** Its newest note's change or its newest highlight, the later; absent for neither. */
  annotatedAt?: string;
  /** Its newest note's text; absent for no note, or an empty one. */
  latestNote?: string;
  noteCount: number;
  summaryCount: number;
  isInVisitPlan: boolean;
  /** Its three newest highlights, newest first; `highlightCount` says how many it has. */
  highlights: { id: string; color: HighlightColor; selectedText: string }[];
  highlightCount: number;
  /** Its tags by name, and its collections by the name each prints. */
  tags: { id: string; name: string }[];
  collections: { id: string; name: string }[];
}

/** One category's documents, the most recently annotated first. */
export interface ResearchDocumentList {
  group: string;
  /** A tag's name, absent for a tag the user has none of, or the name a collection's row prints. */
  name?: string;
  total: number;
  items: ResearchDocument[];
}

export const researchPageQuery = queryOptions({
  queryKey: ['researchPage'],
  queryFn: ({ signal }) => getJSON<ResearchPage>('/api/v1/me/research', undefined, signal),
  staleTime: 0,
  retry: false,
});

/** A category's documents, by its key: `allAnnotated`, `hasNotes`, `tag.{id}`, `collection.{id}` or `highlightColor.{color}`. */
export function researchDocumentsQuery(group: string) {
  return queryOptions({
    queryKey: ['researchDocuments', group],
    queryFn: ({ signal }) => getJSON<ResearchDocumentList>('/api/v1/me/research/documents', new URLSearchParams({ group }), signal),
    staleTime: 0,
    retry: false,
  });
}
