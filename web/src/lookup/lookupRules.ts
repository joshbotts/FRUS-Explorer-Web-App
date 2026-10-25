// The few lines of the app's Citation Lookup view the browser app mirrors (CitationLookupView.swift,
// held to it by CitationLookupViewParityTests): each match's colour and symbol by its strategy, the
// action it offers, the label, colour and symbol of a Batch row's outcome, the match a row opens,
// and the order Needs work first sorts the table in. Every label and count is the kit's, from the
// server; only how they are drawn is the view's.
import type { CitationBatchRow, CitationLookupMatch, MatchStrategy } from '../api/types';
import { copy } from '../copy';

/** The app's colours, which app.css draws in each appearance at 4.5:1 or more. */
export type Tone = 'green' | 'blue' | 'orange' | 'teal' | 'purple' | 'secondary' | 'red';

/** The app's SF Symbols, which SymbolIcon draws. */
export type SymbolName =
  | 'checkmark.seal.fill'
  | 'number.circle'
  | 'doc.on.doc'
  | 'number.square'
  | 'text.magnifyingglass'
  | 'doc.circle'
  | 'lightbulb'
  | 'checkmark.circle.fill'
  | 'questionmark.circle.fill'
  | 'minus.circle'
  | 'exclamationmark.triangle.fill';

/**
 * A match's badge by its strategy, as the app's result row colours it (`confidenceLabelColor`) and
 * draws its symbol beside the label (`confidenceLabelIcon`), so that no confidence is told by colour
 * alone.
 */
export const strategyBadges: Record<MatchStrategy, { tone: Tone; symbol: SymbolName }> = {
  exactDocumentNumber: { tone: 'green', symbol: 'checkmark.seal.fill' },
  pageRange: { tone: 'blue', symbol: 'number.circle' },
  sharedPage: { tone: 'orange', symbol: 'doc.on.doc' },
  superimposedDocumentNumber: { tone: 'teal', symbol: 'number.square' },
  titleFragmentMatch: { tone: 'purple', symbol: 'text.magnifyingglass' },
  manifestOnly: { tone: 'secondary', symbol: 'doc.circle' },
  bestGuess: { tone: 'orange', symbol: 'lightbulb' },
};

/**
 * What a result offers, as the app's result row does: a volume the server does not hold its own
 * action, where the app offers Download Volume, and a document View Document; a row naming a volume
 * and no document, nothing.
 */
export function matchAction(match: CitationLookupMatch): 'volume' | 'document' | null {
  if (match.requiresDownload) return 'volume';
  return match.documentId !== '' ? 'document' : null;
}

/** The match a Batch row opens: its first, when it names a document, as the app's row tap opens it. */
export function batchRowTarget(row: CitationBatchRow): CitationLookupMatch | undefined {
  const primary = row.matches[0];
  return primary && primary.documentId !== '' ? primary : undefined;
}

/** A Batch row's outcome, as the app's table labels, colours and marks it (`batchOutcomeLabel`). */
export function batchOutcome(row: CitationBatchRow): { label: string; tone: Tone; symbol: SymbolName } {
  const primary = row.matches[0];
  switch (row.outcome) {
    case 'resolved':
      return { label: copy.lookup.resolved(primary ? `${primary.volumeId} ${primary.documentId}` : ''), tone: 'green', symbol: 'checkmark.circle.fill' };
    case 'ambiguous':
      return { label: row.loneCandidateLabel ?? copy.lookup.possibleDocuments(row.count ?? 0), tone: 'orange', symbol: 'questionmark.circle.fill' };
    case 'bestGuess':
      return { label: row.loneCandidateLabel ?? '', tone: 'orange', symbol: 'lightbulb' };
    case 'missing':
      return { label: copy.lookup.noMatch, tone: 'secondary', symbol: 'minus.circle' };
    case 'failed':
      return { label: row.reason ?? '', tone: 'red', symbol: 'exclamationmark.triangle.fill' };
  }
}

/**
 * The rows in the order the table shows them: as pasted, or with Needs work first by the kit's
 * triage order, worst first, and in the order of the paste within one (`sortedBatchRows`), so two
 * rows of one kind never swap places between answers.
 */
export function sortedBatchRows(rows: readonly CitationBatchRow[], needsWorkFirst: boolean): CitationBatchRow[] {
  if (!needsWorkFirst) return [...rows];
  return rows
    .map((row, offset) => ({ row, offset }))
    .sort((a, b) => (a.row.triageOrder === b.row.triageOrder ? a.offset - b.offset : a.row.triageOrder - b.row.triageOrder))
    .map(({ row }) => row);
}
