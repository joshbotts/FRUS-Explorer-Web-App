// The app's collection view rules S18d mirrors: the list's project scope, the rows Contents lists, Move
// Up and Move Down, a document row's chips, the pickers' depths and the Add to Collection picker's
// order and search; CollectionParityTests holds each to the app's source.
import { describe, expect, it } from 'vitest';
import type { CollectionEntry, CollectionListItem } from '../api/collections';
import {
  bodyDepthOptions,
  canMoveDown,
  contentsRows,
  entryChips,
  heldOrder,
  hiddenCollectionCount,
  listNameMatches,
  moveDown,
  moveRequest,
  moveUp,
  outlineSteps,
  visibleCollections,
} from './collectionRules';

const listed = (id: string, projectIds: string[] = []): CollectionListItem => ({
  id,
  name: id,
  listName: id,
  documentCount: 0,
  isSmart: false,
  projectIds,
});

function entry(id: string, kind: CollectionEntry['kind'], depth: number, extra: Partial<CollectionEntry> = {}): CollectionEntry {
  return {
    id,
    kind,
    sortOrder: 0,
    level: Math.max(depth, 1),
    depth,
    documentId: kind === 'document' ? id : '',
    volumeId: kind === 'document' ? 'frus1961-63v06' : '',
    formattingKept: false,
    selectedNoteIds: [],
    selectedHighlightIds: [],
    canIndent: false,
    canOutdent: false,
    leftOut: false,
    isDuplicate: false,
    ...extra,
  };
}

/** Europe (1) › Berlin (2) › d1, then d2 under Europe, then Asia (1) › d3: the server's depths and sections. */
const outline = [
  entry('europe', 'heading', 1, { sectionEnd: 4 }),
  entry('berlin', 'heading', 2, { sectionEnd: 3 }),
  entry('d1', 'document', 2),
  entry('d2', 'document', 1),
  entry('asia', 'heading', 1, { sectionEnd: 6 }),
  entry('d3', 'document', 1),
];

describe('the Collections list’s project scope', () => {
  const all = [listed('a', ['P1']), listed('b', ['p2']), listed('c', [])];

  it('shows every collection with the scope lifted or no project worked in, else the project’s', () => {
    expect(visibleCollections(all, null, false).map((c) => c.id)).toEqual(['a', 'b', 'c']);
    expect(visibleCollections(all, 'p1', true).map((c) => c.id)).toEqual(['a', 'b', 'c']);
    // The project's id matches in any letter case.
    expect(visibleCollections(all, 'p1', false).map((c) => c.id)).toEqual(['a']);
  });

  it('counts the collections the scope hides', () => {
    expect(hiddenCollectionCount(all, 'P2')).toBe(2);
    expect(hiddenCollectionCount(all, null)).toBe(0);
  });
});

describe('the rows Contents lists', () => {
  it('lists every row a collapsed heading does not hide, each at its depth', () => {
    expect(contentsRows({ entries: outline }, new Set()).map((row) => row.entry.id)).toEqual(['europe', 'berlin', 'd1', 'd2', 'asia', 'd3']);
    expect(contentsRows({ entries: outline }, new Set(['berlin'])).map((row) => row.entry.id)).toEqual(['europe', 'berlin', 'd2', 'asia', 'd3']);
    expect(contentsRows({ entries: outline }, new Set(['europe', 'd3'])).map((row) => row.entry.id)).toEqual(['europe', 'asia', 'd3']);
  });

  it('lists a smart collection’s kept entries alone, flush', () => {
    const smart = { entries: [entry('h', 'heading', 1, { leftOut: true }), entry('g', 'generated', 1)], savedSearchId: 'S' };
    expect(contentsRows(smart, new Set()).map((row) => [row.entry.id, row.depth])).toEqual([['g', 0]]);
  });

  it('indents a heading by its depth above 1, any other row by its heading’s', () => {
    const rows = contentsRows({ entries: outline }, new Set());
    expect(rows.map(outlineSteps)).toEqual([0, 1, 2, 1, 0, 1]);
  });
});

describe('Move Up and Move Down', () => {
  const rows = contentsRows({ entries: outline }, new Set());

  it('moves a row before the visible row above it, and the first nowhere', () => {
    expect(moveUp(rows, 0, outline.length)).toBeNull();
    expect(moveRequest(outline, moveUp(rows, 3, outline.length)!)).toEqual({ entryId: 'd2', before: 'd1' });
  });

  it('moves a heading past the first row after its section, a collapsed section hopped whole', () => {
    // Berlin carries d1, and goes after d2.
    expect(canMoveDown(rows, outline, 1)).toBe(true);
    expect(moveRequest(outline, moveDown(rows, outline, 1)!)).toEqual({ entryId: 'berlin', before: 'asia' });
    // Europe carries all of Berlin and d2, and goes after Asia, the first row past it.
    expect(moveRequest(outline, moveDown(rows, outline, 0)!)).toEqual({ entryId: 'europe', before: 'd3' });
    // Asia's section runs to the end: nothing is past it.
    expect(canMoveDown(rows, outline, 4)).toBe(false);
    expect(moveDown(rows, outline, 4)).toBeNull();
    // With Asia collapsed, d2 hops it whole, to the end.
    const collapsed = contentsRows({ entries: outline }, new Set(['asia']));
    expect(moveRequest(outline, moveDown(collapsed, outline, 3)!)).toEqual({ entryId: 'd2', before: null });
  });
});

describe('a document row’s chips', () => {
  const collection = { defaultIncludeHeadnote: false };

  it('shows nothing for an untouched row whose document has no notes', () => {
    expect(entryChips(entry('d', 'document', 0, { noteCount: 0 }), collection)).toEqual([]);
  });

  it('shows its depth, its notes counted as the app counts them, and its flags', () => {
    const touched = entry('d', 'document', 0, {
      bodyDepthOverride: 'summaryOnly',
      noteCount: 7,
      applyHighlightsOverride: false,
      includeRelatedDocuments: true,
    });
    expect(entryChips(touched, collection)).toEqual([
      { kind: 'bodyDepth', depth: 'summaryOnly' },
      { kind: 'notes', count: 7 },
      { kind: 'highlightsOff' },
      { kind: 'seeAlso' },
    ]);
    expect(entryChips(entry('d', 'document', 0, { noteCount: 7, selectedNoteIds: ['a', 'b'] }), collection)).toEqual([{ kind: 'notes', count: 2 }]);
    expect(entryChips(entry('d', 'document', 0, { noteCount: 7, researchNoteId: 'a' }), collection)).toEqual([{ kind: 'notes', count: 1 }]);
    expect(entryChips(entry('d', 'document', 0, { noteCount: 7, includeNotesOverride: false }), collection)).toEqual([{ kind: 'notesOff' }]);
  });

  it('shows Headnote wherever it resolves on, the collection’s default among them', () => {
    expect(entryChips(entry('d', 'document', 0), { defaultIncludeHeadnote: true })).toEqual([{ kind: 'headnote' }]);
    expect(entryChips(entry('d', 'document', 0, { includeHeadnote: false }), { defaultIncludeHeadnote: true })).toEqual([]);
  });
});

describe('the pickers’ body depths', () => {
  it('offers those available and the one set, though it is not', () => {
    expect(bodyDepthOptions(['full', 'index'], 'full')).toEqual(['full', 'index']);
    expect(bodyDepthOptions(['full', 'index'], 'summaryOnly')).toEqual(['full', 'index', 'summaryOnly']);
    expect(bodyDepthOptions(['full', 'index'], undefined)).toEqual(['full', 'index']);
  });
});

describe('the Add to Collection picker', () => {
  it('keeps the order it opened with, any made since ahead', () => {
    const items = [listed('new'), listed('b'), listed('a')];
    expect(heldOrder(items, ['a', 'b']).map((c) => c.id)).toEqual(['new', 'a', 'b']);
    expect(heldOrder(items, null).map((c) => c.id)).toEqual(['new', 'b', 'a']);
  });

  it('finds a collection by the name its row prints, case aside', () => {
    expect(listNameMatches('Untitled Collection', 'untitled')).toBe(true);
    expect(listNameMatches('Berlin', 'BER')).toBe(true);
    expect(listNameMatches('Berlin', 'Cuba')).toBe(false);
  });
});
