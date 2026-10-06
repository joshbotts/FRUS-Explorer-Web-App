// What the reader's page posts to the app, through the server's /reader/host.js.

export type ReaderMessage =
  | { kind: 'link'; href: string }
  | { kind: 'selectionChanged' | 'selectionScrolled' | 'highlightTapped'; detail: unknown };

/**
 * The message from the app's own reader frame, or null for anything else. The frame is sandboxed
 * without `allow-same-origin`, so its messages come from the origin "null": the event's source,
 * the frame's window, is what identifies it.
 */
export function readerMessage(event: Pick<MessageEvent, 'data' | 'origin' | 'source'>, frame: Window | null | undefined): ReaderMessage | null {
  if (!frame || event.source !== frame) return null;
  if (event.origin !== 'null' && event.origin !== window.location.origin) return null;
  const data: unknown = event.data;
  if (!data || typeof data !== 'object') return null;
  const message = data as { source?: unknown; kind?: unknown; detail?: unknown };
  if (message.source !== 'frus-reader') return null;
  if (message.kind === 'link') {
    const href = (message.detail as { href?: unknown } | undefined)?.href;
    return typeof href === 'string' && href.startsWith('frusexplorer:') ? { kind: 'link', href } : null;
  }
  if (message.kind === 'selectionChanged' || message.kind === 'selectionScrolled' || message.kind === 'highlightTapped') {
    return { kind: message.kind, detail: message.detail };
  }
  return null;
}
