// The few lines of the app's view code that the reader's highlights mirror (PLAN: "mirrored with a
// parity test that reads the app's source at the pin"). FRUSParityTests' HighlightViewParityTests
// reads this file and the app's source, and holds each to the other: the selection verbs to the
// kit's `SelectionVerb.allInOrder`, the rule for a selection in the text to the app's `hasOffsets`,
// the bar's place to `FloatingSelectionBar.anchorCenter`, the stale lines to `HighlightReview.status`
// and the review sheet's order to its query.
import type { Highlight, HighlightColor } from '../api/types';
import { highlightColors } from '../api/types';
import type { SelectionRect } from './readerMessages';

/** A verb of the selection bar, in the kit's order, and whether it needs the selection's offsets. */
export type SelectionVerb =
  | { kind: 'highlight'; color: HighlightColor; needsDocumentOffsets: true }
  | { kind: 'excerpt'; needsDocumentOffsets: true }
  | { kind: 'lookUpInNARA'; needsDocumentOffsets: false }
  | { kind: 'note'; needsDocumentOffsets: false };

/** `SelectionVerb.allInOrder`: the four colours, then Excerpt, Look Up in NARA and Note. */
export const selectionVerbs: readonly SelectionVerb[] = [
  ...highlightColors.map((color) => ({ kind: 'highlight' as const, color, needsDocumentOffsets: true as const })),
  { kind: 'excerpt', needsDocumentOffsets: true },
  { kind: 'lookUpInNARA', needsDocumentOffsets: false },
  { kind: 'note', needsDocumentOffsets: false },
];

/**
 * The verbs the web edition has so far: the colours, from S15d Note, which needs no offsets, so a
 * footnote's selection offers it alone, and from S18d Excerpt. Look Up in NARA comes with phase 3.
 */
const available = new Set<SelectionVerb['kind']>(['highlight', 'excerpt', 'note']);

/**
 * What the bar offers a selection: every verb the web has, but a verb that needs offsets only for a
 * selection in the text, as the kit's `needsDocumentOffsets` rules a footnote's out.
 */
export function offeredVerbs(inText: boolean): SelectionVerb[] {
  return selectionVerbs.filter((verb) => available.has(verb.kind) && (inText || !verb.needsDocumentOffsets));
}

/** The app's `hasOffsets`: a selection in the document's text, not a footnote's and not nothing. */
export function hasOffsets(start: number, end: number): boolean {
  return start >= 0 && end > start;
}

/**
 * The stale line the review sheet gives a highlight made against an earlier version of the text,
 * as `HighlightReview.status` reads it: one for a highlight that stored its words, one for one that
 * did not; null for one that is not stale.
 */
export function staleLine(highlight: Highlight): 'stale' | 'staleNoPassage' | null {
  if (highlight.isStale !== true) return null;
  return highlight.selectedText !== '' ? 'stale' : 'staleNoPassage';
}

/**
 * A document's highlights as the review sheet lists them, by `startOffset`; then by time, one with
 * none first, and by id in uppercase, so two at one place keep an order.
 */
export function reviewOrder(highlights: readonly Highlight[]): Highlight[] {
  return [...highlights].sort(
    (a, b) =>
      a.startOffset - b.startOffset ||
      (a.createdAt ?? '').localeCompare(b.createdAt ?? '') ||
      a.id.toUpperCase().localeCompare(b.id.toUpperCase()),
  );
}

/** What the kit's renderer reads of a highlight (`ReaderHighlight`), stale by the server's word. */
export function readerHighlight(highlight: Highlight) {
  return {
    startOffset: highlight.startOffset,
    endOffset: highlight.endOffset,
    color: highlight.colorTag,
    isStale: highlight.isStale === true,
  };
}

/**
 * The highlight a tap reported, among those last sent to the frame: the first that is not stale with
 * its offsets and colour. The kit's listener took the first non-stale one holding the tap, and any
 * earlier one with the same offsets would hold it too, so this is the one it took.
 */
export function tappedHighlight(
  sent: readonly Highlight[],
  tap: { startOffset: number; endOffset: number; color: string },
): Highlight | undefined {
  return sent.find(
    (highlight) =>
      highlight.isStale !== true &&
      highlight.startOffset === tap.startOffset &&
      highlight.endOffset === tap.endOffset &&
      highlight.colorTag === tap.color,
  );
}

/**
 * Where the bar goes, in the parent's viewport, for a selection whose rectangle the frame reported in
 * its own: centred on the selection, `gap` above it, below it when there is no room above, and kept
 * `margin` inside the frame's visible part, as the Mac's `anchorCenter` keeps it inside the web view
 * (`below: false`). Gives the bar's top-left corner.
 */
export function barPosition(
  selection: SelectionRect,
  frame: { left: number; top: number; width: number; height: number },
  viewport: { width: number; height: number },
  bar: { width: number; height: number },
): { left: number; top: number } {
  const gap = 8;
  const margin = 8;
  const visible = {
    left: Math.max(frame.left, 0),
    top: Math.max(frame.top, 0),
    right: Math.min(frame.left + frame.width, viewport.width),
    bottom: Math.min(frame.top + frame.height, viewport.height),
  };
  const centre = frame.left + selection.x + selection.w / 2;
  const above = frame.top + selection.y - gap - bar.height;
  const below = frame.top + selection.y + selection.h + gap;
  const top = above >= visible.top + margin ? above : below;
  const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(value, Math.max(low, high)));
  return {
    left: clamp(centre - bar.width / 2, visible.left + margin, visible.right - margin - bar.width),
    top: clamp(top, visible.top + margin, visible.bottom - margin - bar.height),
  };
}
