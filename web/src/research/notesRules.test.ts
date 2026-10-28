import { describe, expect, it } from 'vitest';
import type { NoteSummary } from '../api/types';
import { countLine, filterNotes, noteCount, noteDate, noteDetail, noteTitle, railText, summaryPreview, timeSince } from './notesRules';

function note(fields: Partial<NoteSummary> & Pick<NoteSummary, 'id'>): NoteSummary {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    bodyText: 'A note.',
    projectIds: [],
    userTagIds: [],
    selectedSummaryIds: [],
    linkedHighlightIds: [],
    createdAt: '2026-10-24T09:00:00.000Z',
    lastModified: '2026-10-24T09:00:00.000Z',
    fromResearchDatabase: false,
    ...fields,
  };
}

describe('a row’s title', () => {
  it('is the first line with anything in it, trimmed of spaces and tabs, or Empty note', () => {
    expect(noteTitle('')).toBe('Empty note');
    expect(noteTitle(' \t\n\u{3000}\n')).toBe('Empty note');
    expect(noteTitle('\n\n  First line \t\nSecond')).toBe('First line');
  });

  it('splits on every newline the app’s set holds: CRLF, CR, U+0085, U+2028, U+2029, \\v and \\f', () => {
    for (const separator of ['\r\n', '\r', '\u{0085}', '\u{2028}', '\u{2029}', '\u{000B}', '\u{000C}']) {
      expect(noteTitle(`Title${separator}Rest`), JSON.stringify(separator)).toBe('Title');
    }
  });

  it('is cut at 90 characters, counted as Swift counts them, trimmed again and ended with an ellipsis', () => {
    expect(noteTitle('a'.repeat(90))).toBe('a'.repeat(90));
    expect(noteTitle('a'.repeat(91))).toBe(`${'a'.repeat(90)}…`);
    // A space at the cut is trimmed before the ellipsis.
    expect(noteTitle(`${'a'.repeat(89)} bbb`)).toBe(`${'a'.repeat(89)}…`);
    // An emoji is one character, however many code units: one at the 90th place is kept whole.
    const flags = '🇺🇸'.repeat(91);
    expect(noteTitle(flags)).toBe(`${'🇺🇸'.repeat(90)}…`);
    expect(noteTitle(`${'a'.repeat(89)}👩🏽‍🔬 more`)).toBe(`${'a'.repeat(89)}👩🏽‍🔬…`);
  });
});

describe('a row’s detail and date', () => {
  const projects = new Map([['P1', 'Berlin Crisis']]);
  const tags = new Map([
    ['T1', 'Cables'],
    ['T2', 'Revisit'],
  ]);

  it('names where the note is, then its projects and its tags in the note’s order, an id with no name left out', () => {
    expect(noteDetail(note({ id: 'a', projectIds: ['p1', 'GONE'], userTagIds: ['T2', 'T1'] }), projects, tags)).toBe(
      'frus1961-63v06 / d1 · Berlin Crisis · Revisit · Cables',
    );
    expect(noteDetail(note({ id: 'a' }), projects, tags)).toBe('frus1961-63v06 / d1');
  });

  it('dates a row as the app’s abbreviated date, and gives none without one', () => {
    // The local day, read in the zone vite.config.ts pins for every run, so it is the same day everywhere.
    expect(new Intl.DateTimeFormat().resolvedOptions().timeZone).toBe('UTC');
    expect(noteDate('2026-10-24T12:00:00.000Z')).toBe('Oct 24, 2026');
    expect(noteDate(null)).toBeNull();
    expect(noteDate(undefined)).toBeNull();
  });
});

describe('the filters', () => {
  const unfiled = note({ id: 'u', bodyText: 'Kennedy and Khrushchev' });
  const filed = note({ id: 'f', projectIds: ['P1'], userTagIds: ['T1'], documentId: 'd16' });
  const dangling = note({ id: 'd', projectIds: ['GONE'], volumeId: 'frus1969-76v01' });
  const all = [unfiled, filed, dangling];
  const ids = (rows: NoteSummary[]) => rows.map((row) => row.id);

  it('keeps every note under All projects, and under Not in a project only those with no project at all', () => {
    expect(ids(filterNotes(all, {}))).toEqual(['u', 'f', 'd']);
    expect(ids(filterNotes(all, { project: 'unfiled' }))).toEqual(['u']);
    expect(ids(filterNotes(all, { project: 'p1' }))).toEqual(['f']);
    // A note whose only project is gone is neither unfiled nor in a project still listed.
    expect(ids(filterNotes(all, { project: 'P2' }))).toEqual([]);
  });

  it('keeps the notes carrying the tag', () => {
    expect(ids(filterNotes(all, { tag: 't1' }))).toEqual(['f']);
  });

  it('finds the text, trimmed of spaces and tabs only, in the note, its volume’s id or its document’s, whatever the case', () => {
    expect(ids(filterNotes(all, { query: ' \tKHRUSHCHEV ' }))).toEqual(['u']);
    expect(ids(filterNotes(all, { query: 'D16' }))).toEqual(['f']);
    expect(ids(filterNotes(all, { query: 'v01' }))).toEqual(['d']);
    expect(ids(filterNotes(all, { query: '  ' }))).toEqual(['u', 'f', 'd']);
    // A line break is not trimmed, as `.whitespaces` holds none.
    expect(ids(filterNotes(all, { query: 'Kennedy\n' }))).toEqual([]);
    expect(ids(filterNotes(all, { query: 'kennedy', tag: 'T1' }))).toEqual([]);
  });

  it('finds an accent typed as one character in text that holds a letter and a mark, and the reverse', () => {
    const composed = note({ id: 'nfc', bodyText: 'Le caf\u{00E9} de la Paix' });
    const decomposed = note({ id: 'nfd', bodyText: 'Le cafe\u{0301} de la Paix' });
    expect(ids(filterNotes([composed, decomposed], { query: 'CAF\u{00C9}' }))).toEqual(['nfc', 'nfd']);
    expect(ids(filterNotes([composed, decomposed], { query: 'cafe\u{0301}' }))).toEqual(['nfc', 'nfd']);
  });
});

describe('the count', () => {
  it('is the notes phrase, grouped, or Showing n of it when the filters show fewer', () => {
    expect(noteCount(1)).toBe('1 note');
    expect(noteCount(0)).toBe('0 notes');
    expect(noteCount(1204)).toBe('1,204 notes');
    expect(countLine(3, 3)).toBe('3 notes');
    expect(countLine(3, 1204)).toBe('Showing 3 of 1,204 notes');
    expect(countLine(0, 1)).toBe('Showing 0 of 1 note');
  });
});

describe('the rail', () => {
  it('shows a note’s text as it is, and Empty note only when it has none at all', () => {
    expect(railText('')).toBe('Empty note');
    expect(railText('  ')).toBe('  ');
    expect(railText('Line\nline')).toBe('Line\nline');
  });

  it('previews the summary shown, trimmed, at 80 characters and an ellipsis', () => {
    expect(summaryPreview('\n  Short summary.\u{2029}')).toBe('Short summary.…');
    expect(summaryPreview(`${'x'.repeat(79)}👩🏽‍🔬tail`)).toBe(`${'x'.repeat(79)}👩🏽‍🔬…`);
  });

  it('gives the time since a note changed in its two largest units, and a note with no time as now', () => {
    const now = Date.parse('2026-10-24T12:00:00.000Z');
    const ago = (seconds: number) => new Date(now - seconds * 1000).toISOString();
    expect(timeSince(ago(2 * 3600 + 23 * 60 + 5), now)).toBe('2 hours, 23 minutes');
    expect(timeSince(ago(3600 + 5), now)).toBe('1 hour');
    expect(timeSince(ago(45), now)).toBe('45 seconds');
    expect(timeSince(ago(61), now)).toBe('1 minute, 1 second');
    expect(timeSince(ago(9 * 86_400), now)).toBe('1 week, 2 days');
    expect(timeSince(ago(400 * 86_400), now)).toBe('1 year, 1 month');
    expect(timeSince(null, now)).toBe('0 seconds');
  });
});
