import { describe, expect, it } from 'vitest';
import type { NoteRun } from '../api/types';
import { holdsChanges, type NoteSnapshot } from './noteEditorRules';

const plain = { bold: false, italic: false, underline: false };
const run = (text: string, format: Partial<NoteRun> = {}): NoteRun => ({ text, ...plain, ...format });

const opening: NoteSnapshot = {
  text: 'Kennedy writes warmly.',
  runs: null,
  edited: false,
  formattingKept: false,
  userTagIds: ['B0000000-0000-4000-8000-000000000000'],
  projectIds: ['P0000000-0000-4000-8000-000000000000'],
  selectedSummaryIds: [],
};

const now = (changes: Partial<NoteSnapshot>): NoteSnapshot => ({ ...opening, ...changes });

describe('whether leaving the note editor would lose something done in it (`hasChanges`)', () => {
  it('holds nothing as it opened', () => {
    expect(holdsChanges(opening, opening)).toBe(false);
  });

  it('holds a change of the text, whatever its formatting', () => {
    expect(holdsChanges(opening, now({ text: 'Kennedy writes warmly. More.', edited: true }))).toBe(true);
    expect(holdsChanges(opening, now({ text: 'Kennedy writes warmly. ', edited: true }))).toBe(true);
  });

  it('reads the tags, projects and summaries as sets in any letter case, as the app compares its sets of ids', () => {
    expect(holdsChanges(opening, now({ userTagIds: ['b0000000-0000-4000-8000-000000000000'] }))).toBe(false);
    expect(holdsChanges(opening, now({ userTagIds: [...opening.userTagIds, ...opening.userTagIds] }))).toBe(false);
    expect(holdsChanges(opening, now({ userTagIds: [] }))).toBe(true);
    expect(holdsChanges(opening, now({ projectIds: [] }))).toBe(true);
    expect(holdsChanges(opening, now({ selectedSummaryIds: ['S0000000-0000-4000-8000-000000000000'] }))).toBe(true);
    const two = now({ userTagIds: ['A', 'B'] });
    expect(holdsChanges(two, now({ userTagIds: ['B', 'A'] }))).toBe(false);
  });

  it('counts the formatting only where an edit would write another, and only while there is text to carry it', () => {
    const formatted = now({ runs: [run('Kennedy '), run('writes', { bold: true }), run(' warmly.')] });
    // Typed and taken back with formatting on: the same runs, in any split, are no change.
    expect(holdsChanges(formatted, now({ runs: [run('Kennedy '), run('writes', { bold: true }), run(' warm'), run('ly.')], edited: true }))).toBe(false);
    // Another formatting is.
    expect(holdsChanges(formatted, now({ runs: [run('Kennedy writes warmly.')], edited: true }))).toBe(true);
    expect(holdsChanges(formatted, now({ runs: [run('Kennedy '), run('writes', { bold: true, colorHex: '0000FF' }), run(' warmly.')], edited: true }))).toBe(true);
    // Typed with formatting off, which drops it, as the app's `setPlainBody` does.
    expect(holdsChanges(formatted, now({ runs: null, edited: true }))).toBe(true);
    // A plain note edited with formatting on: Save would keep formatting where there was none, as the app's editor's
    // fresh copy counts.
    expect(holdsChanges(opening, now({ runs: [run('Kennedy writes warmly.')], edited: true }))).toBe(true);
    // A plain note typed plain and taken back is no change.
    expect(holdsChanges(opening, now({ runs: null, edited: true }))).toBe(false);
    // No edit, no formatting written.
    expect(holdsChanges(formatted, now({ runs: null, edited: false }))).toBe(false);
    // An empty note has no formatting worth asking about.
    const empty = now({ text: '', runs: null });
    expect(holdsChanges(empty, now({ text: '', runs: [], edited: true }))).toBe(false);
  });

  it('counts any edit of a note whose formatting the server keeps as it is, which the edit replaces', () => {
    const kept = now({ formattingKept: true });
    expect(holdsChanges(kept, now({ runs: null, edited: true }))).toBe(true);
    expect(holdsChanges(kept, now({ runs: [run('Kennedy writes warmly.')], edited: true }))).toBe(true);
    expect(holdsChanges(kept, now({}))).toBe(false);
  });
});
