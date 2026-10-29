// The app's rules S17f mirrors: the reader's own order (`ListOrderPreferences`), the History screen's
// filter and count (`HistoryPaneSnapshot`), and Project Home's lines; ProjectHistoryParityTests holds
// each to the app's source.
import { describe, expect, it } from 'vitest';
import type { DocumentVisit, ExportRecord, SearchRun } from '../api/research';
import { exportMatches, normalizingQuotationMarks, searchMatches, showingCount, visitMatches } from './historyRules';
import { applyOrder, moving } from './listOrder';
import { dateFocusText, leadContext, workingOnQuestion } from './projectRules';

const item = (id: string) => ({ id, name: id });

describe('the reader’s own order', () => {
  it('puts the ids it names first, in its order, the first place of each its own, and the rest as given', () => {
    const items = ['a', 'b', 'c', 'd'].map(item);
    expect(applyOrder(items, [], (x) => x.id).map((x) => x.id)).toEqual(['a', 'b', 'c', 'd']);
    expect(applyOrder(items, ['C', 'gone', 'a', 'c'], (x) => x.id).map((x) => x.id)).toEqual(['c', 'a', 'b', 'd']);
  });

  it('moves a row to the top, up or down, and gives nothing for a move that would change nothing', () => {
    expect(moving('c', 'toTop', ['a', 'b', 'c'])).toEqual(['c', 'a', 'b']);
    expect(moving('c', 'up', ['a', 'b', 'c'])).toEqual(['a', 'c', 'b']);
    expect(moving('a', 'down', ['a', 'b', 'c'])).toEqual(['b', 'a', 'c']);
    expect(moving('a', 'toTop', ['a', 'b'])).toBeUndefined();
    expect(moving('a', 'up', ['a', 'b'])).toBeUndefined();
    expect(moving('b', 'down', ['a', 'b'])).toBeUndefined();
    expect(moving('z', 'up', ['a', 'b'])).toBeUndefined();
  });
});

describe('the History screen’s filter', () => {
  const visit: DocumentVisit = { id: '1', volumeId: 'frus1969-76v01', documentId: 'd42', title: 'Mémorandum for the President', caption: 'x' };
  const search: SearchRun = { id: '2', queryText: '“cold war”', resultCount: 3, count: '3', countBasis: 'exact', scope: '' };
  const exported: ExportRecord = { id: '3', format: 'pdf', formatName: 'PDF', documentCount: 2, title: 'Grain' };

  it('matches a visit by its title, whatever the case and the accents, and by both its ids', () => {
    expect(visitMatches(visit, '  ')).toBe(true);
    expect(visitMatches(visit, 'memorandum')).toBe(true);
    expect(visitMatches(visit, 'FRUS1969')).toBe(true);
    expect(visitMatches(visit, 'd42')).toBe(true);
    expect(visitMatches(visit, 'telegram')).toBe(false);
  });

  it('matches a search by its words with the kit’s typographic double quotation marks folded on both sides', () => {
    expect(normalizingQuotationMarks('«a» „b‟ ＂c＂')).toBe('"a" "b" "c"');
    expect(searchMatches(search, '"cold war"')).toBe(true);
    expect(searchMatches(search, '“COLD')).toBe(true);
    expect(searchMatches(search, "'cold")).toBe(false);
  });

  it('matches an export by its title and both spellings of its format', () => {
    expect(exportMatches(exported, 'grain')).toBe(true);
    expect(exportMatches(exported, 'pdf')).toBe(true);
    expect(exportMatches(exported, 'docx')).toBe(false);
  });

  it('says what a section shows of its scope only when it shows less, its numbers ungrouped', () => {
    expect(showingCount(500, 12904)).toBe('Showing 500 of 12904');
    expect(showingCount(12, 12)).toBeUndefined();
  });
});

describe('Project Home’s lines', () => {
  it('gives the date focus from the years of the range', () => {
    expect(dateFocusText({ defaultDateRangeStart: '1969-06-01T12:00:00.000Z', defaultDateRangeEnd: '1973-06-01T12:00:00.000Z' })).toBe('1969–1973');
    expect(dateFocusText({ defaultDateRangeStart: '1969-06-01T12:00:00.000Z' })).toBe('From 1969');
    expect(dateFocusText({ defaultDateRangeEnd: '1973-06-01T12:00:00.000Z' })).toBe('Through 1973');
    expect(dateFocusText({})).toBeUndefined();
  });

  it('works on the active project’s question, trimmed, and on none for Global Context, a gone project or a blank question', () => {
    const projects = [
      { id: 'A0000000-0000-4000-8000-000000000001', name: 'Grain', researchQuestion: '  Why wheat?  ' },
      { id: 'A0000000-0000-4000-8000-000000000002', name: 'Blank', researchQuestion: '   ' },
    ];
    expect(workingOnQuestion('a0000000-0000-4000-8000-000000000001', projects)).toBe('Why wheat?');
    expect(workingOnQuestion(undefined, projects)).toBeUndefined();
    expect(workingOnQuestion('A0000000-0000-4000-8000-000000000002', projects)).toBeUndefined();
    expect(workingOnQuestion('A0000000-0000-4000-8000-000000000009', projects)).toBeUndefined();
  });

  it('says what a lead is related to, and that it is an editorial note', () => {
    expect(leadContext({ relatedCount: 1, isEditorialNote: false })).toBe('Related to 1 of your documents');
    expect(leadContext({ relatedCount: 1204, isEditorialNote: true })).toBe('Related to 1,204 of your documents · Editorial note');
  });
});
