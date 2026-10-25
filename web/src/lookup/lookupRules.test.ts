import { describe, expect, it } from 'vitest';
import type { BatchOutcome, CitationBatchRow, CitationLookupMatch } from '../api/types';
import { batchOutcome, batchRowTarget, matchAction, sortedBatchRows } from './lookupRules';

const match: CitationLookupMatch = {
  documentId: 'd84',
  volumeId: 'frus1961-63v05',
  rank: 1,
  matchStrategy: 'exactDocumentNumber',
  confidenceLabel: 'Exact match',
  correctionNote: null,
  requiresDownload: false,
  awaitingIndex: false,
  volumeManifestEntry: null,
  sharedPageTotal: null,
  volumeIsBestGuess: false,
  isBestGuess: false,
  bestGuessExplanation: null,
  sharedPageDocuments: null,
};

const triage: Record<BatchOutcome, number> = { failed: 0, missing: 1, bestGuess: 2, ambiguous: 3, resolved: 4 };

function row(outcome: BatchOutcome, index = 1, overrides: Partial<CitationBatchRow> = {}): CitationBatchRow {
  return { index, marker: String(index), text: 'FRUS', outcome, count: null, reason: null, triageOrder: triage[outcome], loneCandidateLabel: null, matches: [], ...overrides };
}

describe('Citation Lookup’s view rules', () => {
  // The kit's BatchTriageSortTests, which pin the rule the app's view applies.
  it('sorts the rows worst first, unresolved, best guesses, ambiguous and resolved, and keeps the paste’s order within one', () => {
    const rows = [row('resolved', 1), row('missing', 2), row('ambiguous', 3), row('failed', 4), row('bestGuess', 5)];
    expect(sortedBatchRows(rows, true).map((each) => each.index)).toEqual([4, 2, 5, 3, 1]);
    expect(sortedBatchRows([row('missing', 1), row('missing', 2), row('missing', 3)], true).map((each) => each.index)).toEqual([1, 2, 3]);
    expect(sortedBatchRows([row('resolved', 1), row('missing', 2), row('resolved', 3), row('missing', 4)], true).map((each) => each.index)).toEqual([2, 4, 1, 3]);
    expect(sortedBatchRows(rows, false)).toEqual(rows);
  });

  it('offers a document View Document, a volume the server does not hold its own action, and a volume alone nothing', () => {
    expect(matchAction(match)).toBe('document');
    expect(matchAction({ ...match, documentId: '', requiresDownload: true, matchStrategy: 'manifestOnly' })).toBe('volume');
    expect(matchAction({ ...match, documentId: '', matchStrategy: 'manifestOnly', awaitingIndex: true })).toBeNull();
  });

  it('opens a row’s first answer when it names a document', () => {
    expect(batchRowTarget(row('resolved', 1, { matches: [match] }))).toBe(match);
    expect(batchRowTarget(row('ambiguous', 1, { matches: [{ ...match, documentId: '' }, match] }))).toBeUndefined();
    expect(batchRowTarget(row('missing'))).toBeUndefined();
  });

  it('labels each outcome in the app’s words, or the lone candidate’s own label', () => {
    expect(batchOutcome(row('resolved', 1, { matches: [match] }))).toEqual({ label: 'Resolved — frus1961-63v05 d84', tone: 'green', symbol: 'checkmark.circle.fill' });
    expect(batchOutcome(row('ambiguous', 1, { count: 12 }))).toEqual({ label: '12 possible documents', tone: 'orange', symbol: 'questionmark.circle.fill' });
    expect(batchOutcome(row('ambiguous', 1, { count: 1, loneCandidateLabel: 'Volume identified — download to find the specific document' })).label).toBe(
      'Volume identified — download to find the specific document',
    );
    expect(batchOutcome(row('bestGuess', 1, { loneCandidateLabel: 'Best guess — this volume does not match the cited part 2' }))).toEqual({
      label: 'Best guess — this volume does not match the cited part 2',
      tone: 'orange',
      symbol: 'lightbulb',
    });
    expect(batchOutcome(row('missing'))).toEqual({ label: 'No match', tone: 'secondary', symbol: 'minus.circle' });
    expect(batchOutcome(row('failed', 1, { reason: 'The index could not be read.' }))).toEqual({
      label: 'The index could not be read.',
      tone: 'red',
      symbol: 'exclamationmark.triangle.fill',
    });
  });
});
