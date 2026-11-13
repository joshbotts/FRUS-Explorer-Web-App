// The update review (PLAN's S21f): what an update changed in a document since the user annotated it, as the
// app's banner says it, and the review sheet, the web's own over the kit's rules on the server; Mark Reviewed,
// which records the user's own review; and a highlight's Confirm and Move Here. Administration's Check for
// Corrections and Volume updates are an admin's. A change carries the user's token, as every change does.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import type { AdminJob } from './admin';
import { getJSON } from './client';
import type { Highlight } from './types';
import { change } from './userData';

const segment = encodeURIComponent;

/** `GET …/change`: what the banner says of a document. */
export interface DocumentChange {
  volumeId: string;
  documentId: string;
  /** The banner's sentence, the app's; absent when there is nothing to say. */
  line?: string;
  /** The change stamped, while the user has not reviewed it. */
  changeKind?: 'body' | 'apparatus' | 'vanished' | string;
  changedAt?: string;
  reviewedAt?: string;
  /** The change's content hash, which Mark Reviewed sends back. */
  contentHash?: string;
  highlightsStale: boolean;
  vanished: boolean;
  canMarkReviewed: boolean;
  /** Whether an Import server's comparison with its TEI folder found the change. */
  foundInTEI: boolean;
}

/** One of the user's highlights on the document, with its standing and the search for its passage. */
export interface ReviewHighlight {
  id: string;
  colorTag: string;
  selectedText: string;
  startOffset: number;
  endOffset: number;
  status: 'aligned' | 'stale' | 'unverifiable';
  statusLine: string;
  search?: 'noPassage' | 'refused' | 'notFound' | 'here' | 'moved' | 'foundFar' | 'ambiguous';
  searchLine?: string;
  /** Where the search found the passage, once, with what surrounds it. */
  context?: { before: string; found: string; after: string; start: number; end: number };
  canMove: boolean;
  canConfirm: boolean;
}

/** A quotation one of the user's collections took from the document, with the kit's check of it. */
export interface ReviewExcerpt {
  id: string;
  collectionId: string;
  collectionName: string;
  text: string;
  finding: string;
  capture?: string;
  warning: boolean;
}

/** `GET …/review`: the review sheet. */
export interface DocumentReview {
  change: DocumentChange;
  currentVersion?: string;
  /** What the change section says. */
  changeLine: string;
  highlights: ReviewHighlight[];
  excerpts: ReviewExcerpt[];
  others: {
    notes: { id: string; title?: string }[];
    tagCount: number;
    collectionCount: number;
    summaryCount: number;
    inVisitPlan: boolean;
  };
}

function documentPath(volumeId: string, documentId: string): string {
  return `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}`;
}

/** What the banner says of a document, for the user. */
export function documentChangeQuery(volumeId: string, documentId: string, enabled = true) {
  return queryOptions({
    queryKey: ['documentChange', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentChange>(`${documentPath(volumeId, documentId)}/change`, undefined, signal),
    enabled,
    staleTime: 30_000,
    retry: false,
  });
}

/** The review sheet's reading of a document. */
export function documentReviewQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentReview', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentReview>(`${documentPath(volumeId, documentId)}/review`, undefined, signal),
    staleTime: 0,
    retry: false,
  });
}

/** After a review or a highlight's move, what reads the change or the highlights is read again. */
function reviewed(client: QueryClient, volumeId: string, documentId: string) {
  return Promise.all([
    client.invalidateQueries({ queryKey: ['documentChange', volumeId, documentId] }),
    client.invalidateQueries({ queryKey: ['documentReview', volumeId, documentId] }),
    client.invalidateQueries({ queryKey: ['documentHighlights', volumeId, documentId] }),
    client.invalidateQueries({ queryKey: ['researchPage'] }),
    client.invalidateQueries({ queryKey: ['researchDocuments'] }),
  ]);
}

/**
 * Mark Reviewed: the user's review of the change the sheet showed, as the app's ledger records it; refused
 * (`DOCUMENT_CHANGED`) when another update has changed the document since.
 */
export async function markReviewed(client: QueryClient, shown: DocumentChange): Promise<DocumentChange> {
  const answer = (await change<DocumentChange>(client, 'POST', `${documentPath(shown.volumeId, shown.documentId)}/review`, {
    contentHash: shown.contentHash ?? '',
    changeKind: shown.changeKind ?? null,
  }))!;
  await reviewed(client, shown.volumeId, shown.documentId);
  return answer;
}

/** Confirm: the highlight kept where it is, at the version of the text the sheet judged by. */
export async function confirmHighlight(client: QueryClient, volumeId: string, documentId: string, id: string, renderingVersion: string) {
  const answer = (await change<Highlight>(client, 'POST', `/api/v1/me/highlights/${segment(id)}/confirm`, { renderingVersion }))!;
  await reviewed(client, volumeId, documentId);
  return answer;
}

/** Move Here: the highlight moved to where the kit's search found its passage, which the server finds again. */
export async function moveHighlight(client: QueryClient, volumeId: string, documentId: string, id: string, renderingVersion: string) {
  const answer = (await change<Highlight>(client, 'POST', `/api/v1/me/highlights/${segment(id)}/move`, { renderingVersion }))!;
  await reviewed(client, volumeId, documentId);
  return answer;
}

/** After a highlight's removal, a note's edit or the tags' in the sheet: what reads the document's review again. */
export function reviewChanged(client: QueryClient, volumeId: string, documentId: string) {
  return reviewed(client, volumeId, documentId);
}

// ─── An admin's ────────────────────────────────────────────────────────────

/** `POST /api/v1/admin/library/corrections`: the downloaded volumes changed upstream. */
export interface Corrections {
  checkedAt: string;
  volumes: { volumeId: string; title: string; sideloaded: boolean; indexed: boolean }[];
}

/** Check for Corrections, as the app's Keeping Current runs it. */
export async function checkForCorrections(client: QueryClient): Promise<Corrections> {
  return (await change<Corrections>(client, 'POST', '/api/v1/admin/library/corrections'))!;
}

/** `GET /api/v1/admin/library/updates`: what the updates changed, by volume, and Import mode's comparison. */
export interface AdminUpdates {
  mode: 'import' | 'standalone';
  totals: { changedDocuments: number; volumes: number; annotatedDocuments: number };
  volumes: {
    volumeId: string;
    title: string;
    changedDocuments: number;
    annotatedDocuments: number;
    body: number;
    apparatus: number;
    vanished: number;
  }[];
  teiCheck?: {
    running: boolean;
    volume?: string;
    done: number;
    total: number;
    checkedAt?: string;
    checked?: number;
    changed?: string[];
    unchecked?: { volumeId: string; reason: string }[];
    problem?: string;
  };
}

export const adminUpdatesQuery = queryOptions({
  queryKey: ['admin', 'library', 'updates'],
  queryFn: ({ signal }) => getJSON<AdminUpdates>('/api/v1/admin/library/updates', undefined, signal),
  // Read again every few seconds while Import mode's comparison runs.
  refetchInterval: (query) => (query.state.data?.teiCheck?.running ? 3_000 : 30_000),
  retry: false,
});

export type { AdminJob };
