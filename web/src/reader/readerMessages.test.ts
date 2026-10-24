import { describe, expect, it } from 'vitest';
import { readerMessage } from './readerMessages';

const frame = {} as Window;
const other = {} as Window;
const link = { source: 'frus-reader', kind: 'link', detail: { href: 'frusexplorer://doc/d2' } };
const from = (kind: string, detail?: unknown) => readerMessage({ data: { source: 'frus-reader', kind, detail }, origin: 'null', source: frame }, frame);

describe('readerMessage', () => {
  it('takes a link from the app’s own frame, whose sandboxed origin is "null"', () => {
    expect(readerMessage({ data: link, origin: 'null', source: frame }, frame)).toEqual({ kind: 'link', href: 'frusexplorer://doc/d2' });
  });

  it('ignores another window, another origin, another shape and another kind of link', () => {
    expect(readerMessage({ data: link, origin: 'null', source: other }, frame)).toBeNull();
    expect(readerMessage({ data: link, origin: 'https://example.com', source: frame }, frame)).toBeNull();
    expect(readerMessage({ data: 'frus-reader', origin: 'null', source: frame }, frame)).toBeNull();
    expect(readerMessage({ data: { ...link, source: 'other' }, origin: 'null', source: frame }, frame)).toBeNull();
    expect(
      readerMessage({ data: { ...link, detail: { href: 'javascript:alert(1)' } }, origin: 'null', source: frame }, frame),
    ).toBeNull();
    expect(readerMessage({ data: link, origin: 'null', source: frame }, null)).toBeNull();
    expect(from('somethingElse', {})).toBeNull();
  });

  it('reads the kit’s selection bridge: offsets in the text, -1 in a footnote or when nothing is selected', () => {
    const rect = { x: 10, y: 20.5, w: 100, h: 18 };
    expect(from('selectionChanged', { start: 12, end: 40, text: 'Allow me', rect, scale: 1 })).toEqual({
      kind: 'selectionChanged',
      start: 12,
      end: 40,
      text: 'Allow me',
      rect,
    });
    expect(from('selectionChanged', { start: -1, end: -1, text: 'a note', blockText: 'the note', rect })).toEqual({
      kind: 'selectionChanged',
      start: -1,
      end: -1,
      text: 'a note',
      rect,
    });
    expect(from('selectionChanged', { start: -1, end: -1 })).toEqual({ kind: 'selectionChanged', start: -1, end: -1, text: undefined, rect: undefined });
    expect(from('selectionChanged', { start: 1.5, end: 3 })).toBeNull();
    expect(from('selectionChanged', { start: '1', end: 3 })).toBeNull();
    expect(from('selectionChanged', { start: 1, end: 3, rect: { x: 'a', y: 0, w: 0, h: 0 } })?.kind).toBe('selectionChanged');
    expect(from('selectionScrolled', {})).toEqual({ kind: 'selectionScrolled' });
  });

  it('reads a tap on a highlight, the keys pressed in the frame and what the host drew', () => {
    expect(from('highlightTapped', { startOffset: 3, endOffset: 9, color: 'green' })).toEqual({
      kind: 'highlightTapped',
      startOffset: 3,
      endOffset: 9,
      color: 'green',
    });
    expect(from('highlightTapped', { startOffset: 3, endOffset: 9 })).toBeNull();
    const rect = { x: 1, y: 2, w: 3, h: 4 };
    expect(from('highlightShortcut', { start: 4, end: 9, rect })).toEqual({ kind: 'highlightShortcut', start: 4, end: 9, rect });
    expect(from('selectionBarShortcut', { start: 4, end: 9 })).toEqual({ kind: 'selectionBarShortcut', start: 4, end: 9, rect: undefined });
    expect(from('highlightShortcut', {})).toBeNull();
    expect(from('selectionEscape', {})).toEqual({ kind: 'selectionEscape' });
    expect(from('highlightsRendered', { drawn: 2, skipped: [1] })).toEqual({ kind: 'highlightsRendered', drawn: 2, skipped: [1] });
    expect(from('highlightsRendered', { drawn: 2, skipped: ['1'] })).toBeNull();
    expect(from('highlightTapped', 7)).toBeNull();
  });
});
