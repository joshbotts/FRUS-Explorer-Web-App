// The reader's highlights (PLAN's S15c), as the app's reader makes, draws and removes them. The frame
// draws the document's highlights with the kit's renderer each time its page loads and whenever they
// change; a selection in the text shows the selection bar, whose colour makes a highlight over the
// selection's offsets, as ⇧⌘H, or Ctrl+Shift+H, makes a yellow one, as the app's Highlight
// Selection ▸ Yellow does; and a tap on a highlight asks to remove it. The selection's offsets are
// the kit's bridge's, held only while the selection lasts: a footnote's, a cleared one, a new page
// and a highlight made from them let them go, as the app's reader lets its range go. From S15d the
// bar's Note, offered for a footnote's selection too, lets the selection go and opens a new note on
// the document, as the app's does; and each highlight made is reported, for the rail's Add Note to
// Highlight. A footnote's Note has no key of its own: the host script asks the bar only over the
// text, and the rail's Add Note makes the same note.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, type RefObject, useEffect, useEffectEvent, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import type { Highlight, HighlightColor } from '../api/types';
import { createHighlight, documentHighlightsQuery } from '../api/userData';
import { hasOffsets, readerHighlight, tappedHighlight } from './highlightRules';
import type { ReaderMessage, SelectionRect } from './readerMessages';
import { RemoveHighlight } from './RemoveHighlight';
import { SelectionBar } from './SelectionBar';

/** How long a cleared selection keeps its bar and offsets, as the Mac's bar waits out a false clear. */
const clearDelay = 200;

interface Selected {
  start: number;
  end: number;
  rect?: SelectionRect;
}

/** ⇧⌘H on a Mac and Ctrl+Shift+H elsewhere, the app's Highlight Selection ▸ Yellow; Alt+F10, the bar. */
function chord(event: KeyboardEvent): 'highlight' | 'bar' | null {
  if (event.shiftKey && (event.metaKey || event.ctrlKey) && !event.altKey && event.key.toLowerCase() === 'h') return 'highlight';
  if (event.altKey && !event.metaKey && !event.ctrlKey && event.key === 'F10') return 'bar';
  return null;
}

/**
 * Whether focus is in a field the keys belong to, or in a dialog over the reader, as the note
 * editor, where the shortcuts are left alone.
 */
function editing(target: EventTarget | null): boolean {
  return (
    target instanceof HTMLElement &&
    (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName) || target.closest('dialog[open]') !== null)
  );
}

export function useReaderHighlights({
  volumeId,
  documentId,
  enabled,
  frame,
  frameURL,
  pageVersion,
  say,
  onHighlightMade,
  onNote,
}: {
  volumeId: string;
  documentId: string;
  /** Whether the server keeps user data: with FRUS_USER_DATA=off there are no highlights. */
  enabled: boolean;
  frame: RefObject<HTMLIFrameElement | null>;
  /** The page the frame shows; a new one is a new frame. */
  frameURL: string;
  /** The rendering version the page was sent with, which a new highlight's request names. */
  pageVersion: string | null | undefined;
  /** Puts a sentence in the reader's notice. */
  say: (sentence: string) => void;
  /** A highlight was made, from the bar or the shortcut. */
  onHighlightMade?: (highlight: Highlight) => void;
  /** The bar's Note was chosen: a new note on the document. */
  onNote?: () => void;
}) {
  const client = useQueryClient();
  const highlights = useQuery({ ...documentHighlightsQuery(volumeId, documentId), enabled });
  // The page the frame has loaded, and how many times: each load is drawn on, a reload of one
  // address included.
  const [loaded, setLoaded] = useState<{ url: string; count: number } | null>(null);
  const sent = useRef<Highlight[]>([]);
  const [undrawn, setUndrawn] = useState<ReadonlySet<string>>(new Set());
  const [selected, setSelected] = useState<Selected | null>(null);
  const [barShown, setBarShown] = useState(false);
  const [focusRequest, setFocusRequest] = useState(0);
  const [removing, setRemoving] = useState<Highlight | null>(null);
  const making = useRef(false);
  const clearing = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const version = pageVersion ?? highlights.data?.renderingVersion;

  function post(message: Record<string, unknown>) {
    frame.current?.contentWindow?.postMessage({ source: 'frus-app', ...message }, '*');
  }

  function forget() {
    clearTimeout(clearing.current);
    setSelected(null);
    setBarShown(false);
  }

  // A new page starts with no selection; its highlights are drawn once it has loaded.
  const [shownURL, setShownURL] = useState(frameURL);
  if (shownURL !== frameURL) {
    setShownURL(frameURL);
    setLoaded(null);
    setSelected(null);
    setBarShown(false);
  }
  useEffect(() => () => clearTimeout(clearing.current), []);

  // Drawn on every load of the page, and whenever the list changes while it is loaded, as the app
  // renders them after each load and each change.
  useEffect(() => {
    if (!enabled || loaded?.url !== frameURL || !highlights.data) return;
    sent.current = highlights.data.items;
    frame.current?.contentWindow?.postMessage(
      { source: 'frus-app', kind: 'highlights', highlights: highlights.data.items.map(readerHighlight) },
      '*',
    );
  }, [enabled, loaded, frameURL, highlights.data, frame]);

  /** A colour chosen: a highlight over the selection's offsets, in the page's version of the text. */
  async function make(color: HighlightColor, over: Selected | null = selected) {
    if (!enabled || !over || !hasOffsets(over.start, over.end) || !version || making.current) return;
    making.current = true;
    setBarShown(false);
    try {
      const made = await createHighlight(client, volumeId, documentId, {
        startOffset: over.start,
        endOffset: over.end,
        colorTag: color,
        renderingVersion: version,
      });
      onHighlightMade?.(made);
      setSelected(null);
      // The web's own, as the app's iPhone and iPad reader clears it: the new colour is not hidden
      // under the selection's, and a caret stays where the selection ended.
      post({ kind: 'collapseSelection' });
    } catch (error) {
      say(errorMessage(error));
      // The text the selection was made in is not the server's now: its offsets go, and the page's
      // version stays, so nothing is made in the frame's old text until the page is loaded again,
      // as the server's sentence asks.
      if (error instanceof ApiError && error.code === 'DOCUMENT_CHANGED') forget();
    } finally {
      making.current = false;
      // Back to the text either way, from the bar a colour was chosen in.
      frame.current?.focus({ preventScroll: true });
    }
  }

  function onMessage(message: ReaderMessage) {
    if (!enabled) return;
    switch (message.kind) {
      case 'selectionChanged':
        if (hasOffsets(message.start, message.end)) {
          clearTimeout(clearing.current);
          // A selection made by pointer or caret: the bar it shows does not take focus.
          setFocusRequest(0);
          setSelected({ start: message.start, end: message.end, rect: message.rect });
          setBarShown(message.rect !== undefined && !!message.text);
        } else if (message.text) {
          // A footnote's selection: its bar offers Note alone, which needs no offsets.
          clearTimeout(clearing.current);
          setFocusRequest(0);
          setSelected({ start: -1, end: -1, rect: message.rect });
          setBarShown(message.rect !== undefined);
        } else {
          clearTimeout(clearing.current);
          clearing.current = setTimeout(forget, clearDelay);
        }
        return;
      case 'selectionScrolled':
        // The selection has moved on the screen: its rectangle is the frame's to give again.
        setBarShown(false);
        setSelected((held) => held && { start: held.start, end: held.end });
        return;
      case 'selectionEscape':
        setBarShown(false);
        return;
      case 'highlightTapped': {
        const highlight = tappedHighlight(sent.current, message);
        if (highlight) {
          setBarShown(false);
          setRemoving(highlight);
        }
        return;
      }
      case 'highlightShortcut':
        void make('yellow', { start: message.start, end: message.end, rect: message.rect });
        return;
      case 'selectionBarShortcut':
        clearTimeout(clearing.current);
        setSelected({ start: message.start, end: message.end, rect: message.rect });
        setBarShown(message.rect !== undefined);
        setFocusRequest((request) => request + 1);
        return;
      case 'highlightsRendered':
        setUndrawn(new Set(message.skipped.flatMap((index) => (sent.current[index] ? [sent.current[index].id] : []))));
        return;
      case 'link':
        return;
    }
  }

  // The same keys with focus in the app around the frame, over the selection the frame still holds;
  // and the bar put away by a press or focus elsewhere in the app, the selection kept.
  const onKey = useEffectEvent((event: KeyboardEvent) => {
    const pressed = chord(event);
    if (!pressed || !selected || editing(event.target)) return;
    event.preventDefault();
    // Yellow at once; the bar from the frame, which places the selection as it is now.
    if (pressed === 'highlight') void make('yellow');
    else post({ kind: 'selectionBarRequest' });
  });
  const onElsewhere = useEffectEvent((event: Event) => {
    const target = event.target as Node | null;
    if (!barShown || !target) return;
    if (target === frame.current || (target instanceof Element && target.closest('.selection-bar'))) return;
    setBarShown(false);
  });
  const onMoved = useEffectEvent(() => {
    setBarShown(false);
    setSelected((held) => held && { start: held.start, end: held.end });
  });
  useEffect(() => {
    window.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onElsewhere, true);
    document.addEventListener('focusin', onElsewhere, true);
    window.addEventListener('scroll', onMoved, { capture: true, passive: true });
    window.addEventListener('resize', onMoved);
    return () => {
      window.removeEventListener('keydown', onKey);
      document.removeEventListener('pointerdown', onElsewhere, true);
      document.removeEventListener('focusin', onElsewhere, true);
      window.removeEventListener('scroll', onMoved, { capture: true });
      window.removeEventListener('resize', onMoved);
    };
  }, []);

  const elements: ReactNode = (
    <>
      {enabled && barShown && selected?.rect && (
        <SelectionBar
          rect={selected.rect}
          frame={frame}
          // A colour needs the selection's offsets and the version of the text they are in.
          inText={hasOffsets(selected.start, selected.end) && !!version}
          focusRequest={focusRequest}
          onChoose={(color) => void make(color)}
          onNote={() => {
            // The selection goes, as after a highlight: the note is on the document, not on it.
            forget();
            post({ kind: 'collapseSelection' });
            onNote?.();
          }}
          onDismiss={() => {
            setBarShown(false);
            frame.current?.focus({ preventScroll: true });
          }}
        />
      )}
      {removing && (
        <RemoveHighlight
          highlight={removing}
          onClose={() => {
            setRemoving(null);
            // Once the question has gone: while a modal dialog is open, the frame is inert.
            requestAnimationFrame(() => frame.current?.focus({ preventScroll: true }));
          }}
        />
      )}
    </>
  );

  return {
    /** The frame's page has loaded: its scripts have run, so its highlights can be drawn. */
    onFrameLoad: () => setLoaded((last) => ({ url: frameURL, count: last?.url === frameURL ? last.count + 1 : 1 })),
    onMessage,
    /** Puts the bar away, as the app's does when the rail opens or closes. */
    hideBar: () => setBarShown(false),
    /** The ids of the highlights the frame could not draw. */
    undrawn,
    elements,
  };
}
