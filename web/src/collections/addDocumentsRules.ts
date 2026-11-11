// Add Documents' Citations and Tags (PLAN's S25d): the lines of the app's `CollectionAddDocumentsSheet` the
// browser app mirrors, each held to its source by CollectionParityTests: what a pass chooses at once and
// what it passes over, the counts of lines resolved and to review, and what a row of a citation or a tag
// shows. Which line resolves, and which documents a tag gathers, are the kit's, on the server.
import type { CitationLine } from '../api/addDocuments';
import { documentKey } from './collectionRules';

/** A document a tab offers, by its volume and its id. */
export interface DocumentChoice {
  volumeId: string;
  documentId: string;
}

/**
 * `preselect(_:)` over `select(_:)`: what the sheet holds chosen once a pass chooses `picks` at once, as Resolve
 * and a tag's drill-in do: each pick neither chosen already nor one the reader unchose in this sheet, once, in
 * the pass's order, after those held. `held` itself when the pass adds nothing.
 */
export function preselected<T extends DocumentChoice>(held: T[], picks: readonly T[], unchosen: ReadonlySet<string>): T[] {
  const keys = new Set(held.map((pick) => documentKey(pick.volumeId, pick.documentId)));
  const added: T[] = [];
  for (const pick of picks) {
    const key = documentKey(pick.volumeId, pick.documentId);
    if (unchosen.has(key) || keys.has(key)) continue;
    keys.add(key);
    added.push(pick);
  }
  return added.length > 0 ? [...held, ...added] : held;
}

/** `citationResultsHeader(_:)`'s counts: the lines that resolved, and the ambiguous ones, which the reader reviews. */
export function citationCounts(lines: readonly CitationLine[]): { resolved: number; toReview: number } {
  let resolved = 0;
  let toReview = 0;
  for (const line of lines) {
    if (line.outcome === 'resolved') resolved += 1;
    if (line.outcome === 'ambiguous') toReview += 1;
  }
  return { resolved, toReview };
}

/** What Resolve chooses at once (`resolveCitations()`): the documents of the lines that resolved, in line order. An ambiguous line waits for the reader. */
export function resolvedDocuments(lines: readonly CitationLine[]): CitationLine[] {
  return lines.filter((line) => line.outcome === 'resolved' && line.volumeId !== undefined && line.documentId !== undefined);
}

/**
 * A row's words (`DiscoveryPickRow`), for a document the Citations or the Tags tab offers, which has no date: its
 * head, or its id; and under it its id where the head shows, then its volume's title, or the volume's id.
 */
export function pickLabel(document: DocumentChoice & { header?: string; volumeTitle?: string }): { title: string; line: string } {
  return {
    title: document.header ?? document.documentId,
    line: [document.header !== undefined ? document.documentId : undefined, document.volumeTitle ?? document.volumeId]
      .filter((part): part is string => part !== undefined)
      .join(' · '),
  };
}
