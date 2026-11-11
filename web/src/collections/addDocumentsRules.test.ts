// The lines of the app's Add Documents sheet S25d mirrors for its Citations and Tags tabs: a pass that chooses at
// once, the counts over a paste's lines, what Resolve chooses, and a row's words; CollectionParityTests holds each
// to the app's source.
import { describe, expect, it } from 'vitest';
import type { CitationLine } from '../api/addDocuments';
import { citationCounts, pickLabel, preselected, resolvedDocuments } from './addDocumentsRules';

const pick = (documentId: string, volumeId = 'frus1961-63v06') => ({ volumeId, documentId });

describe("Add Documents' passes", () => {
  it('chooses each document once, after those held, passing over what the reader unchose', () => {
    const held = [pick('d1')];
    const unchosen = new Set(['frus1961-63v06/d3']);
    expect(preselected(held, [pick('d2'), pick('d1'), pick('d3'), pick('d2'), pick('d4', 'frus1964-68v30')], unchosen)).toEqual([
      pick('d1'),
      pick('d2'),
      pick('d4', 'frus1964-68v30'),
    ]);
  });

  it('gives the held list itself when a pass adds nothing', () => {
    const held = [pick('d1')];
    expect(preselected(held, [pick('d1'), pick('d2')], new Set(['frus1961-63v06/d2']))).toBe(held);
  });
});

describe("Add Documents' Citations", () => {
  const lines: CitationLine[] = [
    { line: 'a', outcome: 'resolved', volumeId: 'frus1961-63v06', documentId: 'd1' },
    { line: 'b', outcome: 'ambiguous', volumeId: 'frus1961-63v06', documentId: 'd2', note: 'Exact match — top of 2 candidates' },
    { line: 'c', outcome: 'unresolved', reason: 'No match found in the local manifest or index' },
    { line: 'd', outcome: 'resolved', volumeId: 'frus1964-68v30', documentId: 'd12' },
  ];

  it('counts the lines that resolved and those to review', () => {
    expect(citationCounts(lines)).toEqual({ resolved: 2, toReview: 1 });
    expect(citationCounts([])).toEqual({ resolved: 0, toReview: 0 });
  });

  it('chooses at once the lines that resolved, in line order', () => {
    expect(resolvedDocuments(lines).map((line) => line.line)).toEqual(['a', 'd']);
  });

  it("words a row as the app's does: its head or its id, then its id where the head shows, and its volume's title or id", () => {
    expect(pickLabel({ ...pick('d1'), header: '1. Telegram', volumeTitle: 'Kennedy-Khrushchev Exchanges' })).toEqual({
      title: '1. Telegram',
      line: 'd1 · Kennedy-Khrushchev Exchanges',
    });
    expect(pickLabel({ ...pick('d12', 'frus1964-68v30'), volumeTitle: 'China' })).toEqual({ title: 'd12', line: 'China' });
    expect(pickLabel(pick('d9', 'frus1800x'))).toEqual({ title: 'd9', line: 'frus1800x' });
  });
});
