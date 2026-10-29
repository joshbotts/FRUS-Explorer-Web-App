import { describe, expect, it } from 'vitest';
import type { Highlight } from '../api/types';
import { barPosition, hasOffsets, offeredVerbs, readerHighlight, reviewOrder, selectionVerbs, staleLine, tappedHighlight } from './highlightRules';

function highlight(fields: Partial<Highlight> & Pick<Highlight, 'id'>): Highlight {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    startOffset: 0,
    endOffset: 10,
    colorTag: 'yellow',
    selectedText: 'Allow me',
    renderingVersion: 'v1',
    ...fields,
  };
}

describe('the selection’s verbs', () => {
  it('are the kit’s, in its order: the four colours, then Excerpt, Look Up in NARA and Note', () => {
    expect(selectionVerbs.map((verb) => (verb.kind === 'highlight' ? verb.color : verb.kind))).toEqual([
      'yellow',
      'green',
      'blue',
      'pink',
      'excerpt',
      'lookUpInNARA',
      'note',
    ]);
    expect(selectionVerbs.filter((verb) => verb.needsDocumentOffsets).map((verb) => verb.kind)).toEqual([
      'highlight',
      'highlight',
      'highlight',
      'highlight',
      'excerpt',
    ]);
  });

  it('offer the four colours, Excerpt and Note for a selection in the text, and Note alone for a footnote’s', () => {
    expect(offeredVerbs(true)).toEqual([
      { kind: 'highlight', color: 'yellow', needsDocumentOffsets: true },
      { kind: 'highlight', color: 'green', needsDocumentOffsets: true },
      { kind: 'highlight', color: 'blue', needsDocumentOffsets: true },
      { kind: 'highlight', color: 'pink', needsDocumentOffsets: true },
      { kind: 'excerpt', needsDocumentOffsets: true },
      { kind: 'note', needsDocumentOffsets: false },
    ]);
    expect(offeredVerbs(false)).toEqual([{ kind: 'note', needsDocumentOffsets: false }]);
  });
});

describe('hasOffsets', () => {
  it('holds for a selection in the text only, as the app’s does: not a footnote’s, an empty one or a backward one', () => {
    expect(hasOffsets(0, 1)).toBe(true);
    expect(hasOffsets(12, 40)).toBe(true);
    expect(hasOffsets(-1, -1)).toBe(false);
    expect(hasOffsets(-1, 5)).toBe(false);
    expect(hasOffsets(5, 5)).toBe(false);
    expect(hasOffsets(9, 3)).toBe(false);
  });
});

describe('staleLine', () => {
  it('gives no line to a highlight that is not stale, and one of two to a stale one, by whether it stored its words', () => {
    expect(staleLine(highlight({ id: 'a' }))).toBeNull();
    expect(staleLine(highlight({ id: 'a', isStale: false }))).toBeNull();
    expect(staleLine(highlight({ id: 'a', isStale: true }))).toBe('stale');
    expect(staleLine(highlight({ id: 'a', isStale: true, selectedText: '' }))).toBe('staleNoPassage');
    // A highlight with no words is not stale for that alone.
    expect(staleLine(highlight({ id: 'a', isStale: false, selectedText: '' }))).toBeNull();
  });
});

describe('reviewOrder', () => {
  it('lists by place in the text, then by time with none first, then by id in uppercase, and leaves the list it was given', () => {
    const late = highlight({ id: 'late', startOffset: 50 });
    const second = highlight({ id: 'second', startOffset: 10, createdAt: '2026-10-02T09:00:00Z' });
    const timeless = highlight({ id: 'timeless', startOffset: 10 });
    const first = highlight({ id: 'first', startOffset: 10, createdAt: '2026-10-01T09:00:00Z' });
    const lower = highlight({ id: 'a2', startOffset: 10, createdAt: '2026-10-03T09:00:00Z' });
    const upper = highlight({ id: 'B1', startOffset: 10, createdAt: '2026-10-03T09:00:00Z' });
    const earliest = highlight({ id: 'earliest', startOffset: 0, createdAt: '2026-10-09T09:00:00Z' });
    const given = [late, upper, second, timeless, lower, first, earliest];
    expect(reviewOrder(given).map((row) => row.id)).toEqual(['earliest', 'timeless', 'first', 'second', 'a2', 'B1', 'late']);
    expect(given.map((row) => row.id)).toEqual(['late', 'B1', 'second', 'timeless', 'a2', 'first', 'earliest']);
  });
});

describe('readerHighlight', () => {
  it('gives the kit’s renderer the offsets, the colour and whether the server found it stale, and nothing else', () => {
    expect(readerHighlight(highlight({ id: 'a', startOffset: 12, endOffset: 40, colorTag: 'blue', createdAt: '2026-10-01T09:00:00Z' }))).toEqual({
      startOffset: 12,
      endOffset: 40,
      color: 'blue',
      isStale: false,
    });
    expect(readerHighlight(highlight({ id: 'a', isStale: true }))).toEqual({ startOffset: 0, endOffset: 10, color: 'yellow', isStale: true });
    // An imported colour the web does not offer is drawn as the Mac's export names it.
    expect(readerHighlight(highlight({ id: 'a', colorTag: 'purple' })).color).toBe('purple');
  });
});

describe('tappedHighlight', () => {
  const stale = highlight({ id: 'stale', startOffset: 12, endOffset: 40, colorTag: 'green', isStale: true });
  const live = highlight({ id: 'live', startOffset: 12, endOffset: 40, colorTag: 'green' });
  const twin = highlight({ id: 'twin', startOffset: 12, endOffset: 40, colorTag: 'green', isStale: false });
  const other = highlight({ id: 'other', startOffset: 12, endOffset: 40, colorTag: 'pink' });

  it('is the first highlight sent that is not stale, with the tap’s offsets and colour', () => {
    expect(tappedHighlight([stale, other, live, twin], { startOffset: 12, endOffset: 40, color: 'green' })?.id).toBe('live');
    expect(tappedHighlight([stale, other, live, twin], { startOffset: 12, endOffset: 40, color: 'pink' })?.id).toBe('other');
  });

  it('is none when no highlight sent matches the tap, or only a stale one does', () => {
    expect(tappedHighlight([stale], { startOffset: 12, endOffset: 40, color: 'green' })).toBeUndefined();
    expect(tappedHighlight([live], { startOffset: 12, endOffset: 41, color: 'green' })).toBeUndefined();
    expect(tappedHighlight([live], { startOffset: 11, endOffset: 40, color: 'green' })).toBeUndefined();
    expect(tappedHighlight([live], { startOffset: 12, endOffset: 40, color: 'yellow' })).toBeUndefined();
    expect(tappedHighlight([], { startOffset: 12, endOffset: 40, color: 'green' })).toBeUndefined();
  });
});

describe('barPosition', () => {
  const viewport = { width: 1024, height: 768 };
  const bar = { width: 160, height: 40 };
  const frame = { left: 100, top: 50, width: 600, height: 400 };

  it('centres the bar on the selection, 8 px above it', () => {
    // The selection's centre is at 100 + 200 + 50 = 350; its top at 50 + 100 = 150.
    expect(barPosition({ x: 200, y: 100, w: 100, h: 20 }, frame, viewport, bar)).toEqual({ left: 270, top: 102 });
  });

  it('goes 8 px below the selection when there is no room above it inside the frame', () => {
    // Above, it would start at 50 + 20 - 8 - 40 = 22, outside the frame's top margin at 58.
    expect(barPosition({ x: 200, y: 20, w: 100, h: 20 }, frame, viewport, bar)).toEqual({ left: 270, top: 98 });
    // Exactly at the margin it still fits above.
    expect(barPosition({ x: 200, y: 56, w: 100, h: 20 }, frame, viewport, bar)).toEqual({ left: 270, top: 58 });
  });

  it('keeps the bar 8 px inside the frame’s sides', () => {
    expect(barPosition({ x: 0, y: 100, w: 20, h: 20 }, frame, viewport, bar).left).toBe(108);
    expect(barPosition({ x: 580, y: 100, w: 20, h: 20 }, frame, viewport, bar).left).toBe(532);
  });

  it('keeps the bar inside the part of the frame the window shows', () => {
    // A frame scrolled up past the window's top: room above is measured from the window's edge.
    const tall = { left: 100, top: -200, width: 600, height: 1200 };
    expect(barPosition({ x: 200, y: 250, w: 100, h: 20 }, tall, viewport, bar)).toEqual({ left: 270, top: 78 });
    // A selection below the window's bottom keeps the bar 8 px above that edge.
    expect(barPosition({ x: 200, y: 1000, w: 100, h: 20 }, tall, viewport, bar)).toEqual({ left: 270, top: 720 });
    // A frame running past the window's right edge keeps the bar 8 px inside the window's.
    const wide = { left: 600, top: 50, width: 600, height: 400 };
    expect(barPosition({ x: 380, y: 100, w: 20, h: 20 }, wide, viewport, bar).left).toBe(856);
    // And past its left edge, 8 px inside the window's left.
    const offLeft = { left: -300, top: 50, width: 600, height: 400 };
    expect(barPosition({ x: 300, y: 100, w: 20, h: 20 }, offLeft, viewport, bar).left).toBe(8);
  });

  it('pins the bar 8 px inside the visible part’s top left when it fits neither above, below nor across', () => {
    const short = { left: 100, top: 50, width: 120, height: 50 };
    expect(barPosition({ x: 10, y: 10, w: 20, h: 20 }, short, viewport, bar)).toEqual({ left: 108, top: 58 });
    expect(barPosition({ x: 100, y: 40, w: 20, h: 10 }, short, viewport, bar)).toEqual({ left: 108, top: 58 });
  });
});
