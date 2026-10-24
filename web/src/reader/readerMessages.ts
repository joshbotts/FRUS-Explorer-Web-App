// What the reader's page posts to the app, through the server's /reader/host.js: a link, the kit's
// selection bridge's reports (selectionChanged, selectionScrolled), a tap on a highlight the kit's
// renderer drew (highlightTapped), the keys pressed in the frame that the app acts on (⇧⌘H or
// Ctrl+Shift+H, Alt+F10, Escape), and what the host drew of the highlights it was sent.

/** Where a selection is in the frame's viewport, in CSS pixels, as the kit's bridge measures it. */
export interface SelectionRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export type ReaderMessage =
  | { kind: 'link'; href: string }
  /**
   * The selection, in the kit's flat-text offsets: `start >= 0 && end > start` inside the
   * document's text, -1 for both in a footnote or when nothing is selected, as `text` then says.
   */
  | { kind: 'selectionChanged'; start: number; end: number; text?: string; rect?: SelectionRect }
  | { kind: 'selectionScrolled' }
  | { kind: 'highlightTapped'; startOffset: number; endOffset: number; color: string }
  /** ⇧⌘H or Ctrl+Shift+H, Highlight Selection ▸ Yellow, or Alt+F10, the bar: over a selection in the text. */
  | { kind: 'highlightShortcut' | 'selectionBarShortcut'; start: number; end: number; rect?: SelectionRect }
  | { kind: 'selectionEscape' }
  | { kind: 'highlightsRendered'; drawn: number; skipped: number[] };

const isNumber = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);
const isOffset = (value: unknown): value is number => Number.isInteger(value);

function rect(value: unknown): SelectionRect | undefined {
  const r = value as Partial<SelectionRect> | undefined;
  return r && isNumber(r.x) && isNumber(r.y) && isNumber(r.w) && isNumber(r.h) ? { x: r.x, y: r.y, w: r.w, h: r.h } : undefined;
}

/**
 * The message from the app's own reader frame, or null for anything else, a message of the wrong
 * shape included. The frame is sandboxed without `allow-same-origin`, so its messages come from the
 * origin "null": the event's source, the frame's window, is what identifies it.
 */
export function readerMessage(event: Pick<MessageEvent, 'data' | 'origin' | 'source'>, frame: Window | null | undefined): ReaderMessage | null {
  if (!frame || event.source !== frame) return null;
  if (event.origin !== 'null' && event.origin !== window.location.origin) return null;
  const data: unknown = event.data;
  if (!data || typeof data !== 'object') return null;
  const message = data as { source?: unknown; kind?: unknown; detail?: unknown };
  if (message.source !== 'frus-reader') return null;
  const detail = (message.detail ?? {}) as Record<string, unknown>;
  if (typeof detail !== 'object') return null;
  switch (message.kind) {
    case 'link': {
      const href = detail.href;
      return typeof href === 'string' && href.startsWith('frusexplorer:') ? { kind: 'link', href } : null;
    }
    case 'selectionChanged': {
      if (!isOffset(detail.start) || !isOffset(detail.end)) return null;
      const text = typeof detail.text === 'string' ? detail.text : undefined;
      return { kind: 'selectionChanged', start: detail.start, end: detail.end, text, rect: rect(detail.rect) };
    }
    case 'selectionScrolled':
      return { kind: 'selectionScrolled' };
    case 'highlightTapped':
      return isOffset(detail.startOffset) && isOffset(detail.endOffset) && typeof detail.color === 'string'
        ? { kind: 'highlightTapped', startOffset: detail.startOffset, endOffset: detail.endOffset, color: detail.color }
        : null;
    case 'highlightShortcut':
    case 'selectionBarShortcut':
      return isOffset(detail.start) && isOffset(detail.end) ? { kind: message.kind, start: detail.start, end: detail.end, rect: rect(detail.rect) } : null;
    case 'selectionEscape':
      return { kind: 'selectionEscape' };
    case 'highlightsRendered':
      return isOffset(detail.drawn) && Array.isArray(detail.skipped) && detail.skipped.every(isOffset)
        ? { kind: 'highlightsRendered', drawn: detail.drawn, skipped: detail.skipped }
        : null;
    default:
      return null;
  }
}
