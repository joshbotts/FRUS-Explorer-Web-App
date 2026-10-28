import { afterEach, describe, expect, it } from 'vitest';
import {
  anchorFor,
  checklistStore,
  hiddenKeys,
  isSameSearch,
  mark,
  markBulk,
  noMarks,
  normalizingQuotationMarks,
  undoableCount,
  undoLastBulk,
} from './checklist';

afterEach(() => checklistStore.reset());

describe('the checklist’s marks, as the app’s ReviewedMarks keeps them', () => {
  it('keeps the last bulk mark apart, so Undo takes back that and no hand mark', () => {
    let marks = mark(noMarks, 'v/a');
    const bulk = markBulk(marks, ['v/a', 'v/b', 'v/c']);
    expect([...bulk.fresh]).toEqual(['v/b', 'v/c']);
    marks = bulk.marks;
    expect([...marks.keys].sort()).toEqual(['v/a', 'v/b', 'v/c']);
    expect([...marks.lastBulkBatch].sort()).toEqual(['v/b', 'v/c']);
    // A bulk mark that hides nothing new changes nothing, and the batch before it stays.
    expect(markBulk(marks, ['v/a', 'v/b']).marks).toBe(marks);
    // A key of the batch then marked by hand leaves it.
    marks = mark(marks, 'v/c');
    expect([...marks.lastBulkBatch]).toEqual(['v/b']);
    marks = undoLastBulk(marks);
    expect([...marks.keys].sort()).toEqual(['v/a', 'v/c']);
    expect(marks.lastBulkBatch.size).toBe(0);
  });

  it('counts what Undo would bring back among the loaded results, less those an opening hides', () => {
    const { marks } = markBulk(noMarks, ['v/a', 'v/b', 'v/c']);
    expect(undoableCount(marks, ['v/a', 'v/b', 'v/x'], new Set(['v/b']))).toBe(1);
    expect(undoableCount(noMarks, ['v/a'], new Set())).toBe(0);
  });
});

describe('the search a checklist belongs to, as the app’s ChecklistAnchor says it', () => {
  it('keeps its marks for the same words in other quotation marks, whatever the filters, and not for other words', () => {
    const anchor = anchorFor({ keywords: '  “cold war” ' });
    expect(anchor.query).toBe('“cold war”');
    expect(normalizingQuotationMarks(anchor.query)).toBe('"cold war"');
    expect(isSameSearch(anchor, anchorFor({ keywords: '"cold war"', dateRangeEarliest: '1950-01-01' }))).toBe(true);
    expect(isSameSearch(anchor, anchorFor({ keywords: 'cold war' }))).toBe(false);
    expect(isSameSearch(anchor, anchorFor({ keywords: '"cold war"', phrase: 'iron curtain' })), 'a phrase is words too').toBe(false);
  });

  it('keeps a browse’s marks through a narrowing, and not for another person or subject', () => {
    const person = anchorFor({ keywords: '', personRollupId: '7' });
    expect(person.browse).toEqual({ personRollupId: '7', subjectBucket: undefined });
    expect(isSameSearch(person, anchorFor({ keywords: '', personRollupId: '7', subjectBucketKey: 'Warfare/Korea' }))).toBe(true);
    expect(isSameSearch(person, anchorFor({ keywords: '', personRollupId: '8' }))).toBe(false);
    expect(isSameSearch(person, anchorFor({ keywords: '' })), 'a browse given up').toBe(false);
    // With words, a person is a filter like any other.
    expect(anchorFor({ keywords: 'berlin', personRollupId: '7' }).browse).toBeUndefined();
  });
});

describe('the checklist, kept for the session', () => {
  it('hides what is marked and opened while it is on, starts again for another search, and forgets all when turned off', () => {
    const search = { keywords: 'treaties' };
    checklistStore.opened('v/x');
    expect(checklistStore.get().on).toBe(false);
    checklistStore.setOn(true, search);
    checklistStore.mark('v/a');
    checklistStore.opened('v/b');
    expect([...hiddenKeys(checklistStore.get())].sort()).toEqual(['v/a', 'v/b']);
    expect(checklistStore.markPage(['v/b', 'v/c', 'v/d']), 'the opened one was hidden already').toBe(2);
    expect(checklistStore.undo()).toBe(2);
    expect([...hiddenKeys(checklistStore.get())].sort()).toEqual(['v/a', 'v/b']);

    checklistStore.settle({ keywords: 'treaties', yearKeys: ['1960'] });
    expect(hiddenKeys(checklistStore.get()).size, 'a narrowing keeps them').toBe(2);
    checklistStore.settle({ keywords: 'canal' });
    expect(hiddenKeys(checklistStore.get()).size, 'another search starts again').toBe(0);
    checklistStore.mark('v/a');
    checklistStore.setOn(false, search);
    expect(hiddenKeys(checklistStore.get()).size).toBe(0);
    checklistStore.setOn(true, search);
    expect(hiddenKeys(checklistStore.get()).size, 'no marks outlive the mode').toBe(0);
  });
});
