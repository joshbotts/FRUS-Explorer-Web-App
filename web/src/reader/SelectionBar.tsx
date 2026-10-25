// The selection bar over the reader's frame (SPEC, Reader rendering: "The parent page draws the
// floating selection bar"), as the Mac's `FloatingSelectionBar` draws it: a dark pill above the
// selection with the verbs the selection allows, in the kit's order. In the web edition so far those
// are the four colours, each a dot named as VoiceOver reads the app's, "Highlight Yellow", and from
// S15d Note, which opens a new note on the document, as the app's does; a footnote's selection
// allows Note alone. A toolbar for the keyboard, which Alt+F10 reaches from the text: the arrow keys,
// Home and End move between its buttons, Return or Space chooses one, and Escape puts the bar away.
import { type RefObject, useEffect, useEffectEvent, useLayoutEffect, useRef, useState } from 'react';
import type { HighlightColor } from '../api/types';
import { copy } from '../copy';
import { barPosition, offeredVerbs } from './highlightRules';
import type { SelectionRect } from './readerMessages';

export function SelectionBar({
  rect,
  frame,
  inText = true,
  focusRequest,
  onFocused = () => {},
  onChoose,
  onNote = () => {},
  onDismiss,
}: {
  /** The selection's rectangle in the frame's viewport, as the kit's bridge measured it. */
  rect: SelectionRect;
  frame: RefObject<HTMLIFrameElement | null>;
  /** Whether the selection is in the document's text, which a colour needs: not a footnote's. */
  inText?: boolean;
  /** Changes when the keyboard asks for the bar, 0 for no request: its first button then takes focus. */
  focusRequest: number;
  /** The request it answered, so that its owner asks no more. */
  onFocused?: (request: number) => void;
  onChoose: (color: HighlightColor) => void;
  onNote?: () => void;
  onDismiss: () => void;
}) {
  const bar = useRef<HTMLDivElement>(null);
  const dots = useRef<(HTMLButtonElement | null)[]>([]);
  const [active, setActive] = useState(0);
  const [position, setPosition] = useState<{ left: number; top: number } | null>(null);
  const verbs = offeredVerbs(inText).filter((verb) => verb.kind === 'highlight' || verb.kind === 'note');
  // The button in the Tab order, kept among those offered when a selection offers fewer.
  const at = Math.min(active, verbs.length - 1);

  // Placed before it is painted, inside the frame's content box, as the Mac's is kept inside its web view.
  useLayoutEffect(() => {
    const element = frame.current;
    const own = bar.current;
    if (!element || !own) return;
    const box = element.getBoundingClientRect();
    const content = { left: box.left + element.clientLeft, top: box.top + element.clientTop, width: element.clientWidth, height: element.clientHeight };
    setPosition(
      barPosition(rect, content, { width: window.innerWidth, height: window.innerHeight }, { width: own.offsetWidth, height: own.offsetHeight }),
    );
  }, [rect, frame]);

  // The first dot takes focus, and with it the bar's place in the Tab order (its onFocus), once the
  // bar is placed: until then it is hidden, and a hidden button takes no focus. Alt+F10 can mount the
  // bar before the selection's own report does. Each request is answered once.
  const answered = useRef(0);
  const report = useEffectEvent((request: number) => onFocused(request));
  useEffect(() => {
    if (focusRequest === 0) answered.current = 0;
    if (!position || focusRequest === 0 || answered.current === focusRequest) return;
    answered.current = focusRequest;
    dots.current[0]?.focus({ preventScroll: true });
    report(focusRequest);
  }, [focusRequest, position]);

  function move(to: number) {
    const next = (to + verbs.length) % verbs.length;
    setActive(next);
    dots.current[next]?.focus({ preventScroll: true });
  }

  return (
    <div
      ref={bar}
      role="toolbar"
      aria-label={copy.reader.selectionBar}
      className="selection-bar"
      // Through the CSSOM, which the app's policy allows; it is hidden until it is placed.
      style={position ? { left: `${position.left}px`, top: `${position.top}px` } : { visibility: 'hidden' }}
      onKeyDown={(event) => {
        const keys: Partial<Record<string, number>> = { ArrowRight: at + 1, ArrowDown: at + 1, ArrowLeft: at - 1, ArrowUp: at - 1, Home: 0, End: verbs.length - 1 };
        const to = keys[event.key];
        if (to !== undefined) {
          // Not the page's own move: with caret browsing on, an arrow would also move a caret.
          event.preventDefault();
          move(to);
        } else if (event.key === 'Escape') {
          event.preventDefault();
          event.stopPropagation();
          onDismiss();
        }
      }}
    >
      {verbs.map((verb, index) => {
        const place = {
          ref: (element: HTMLButtonElement | null) => {
            dots.current[index] = element;
          },
          tabIndex: index === at ? 0 : -1,
          onFocus: () => setActive(index),
        };
        return verb.kind === 'highlight' ? (
          <button
            key={verb.color}
            type="button"
            {...place}
            className={`selection-color hl-${verb.color}`}
            aria-label={copy.highlights.highlightColor(copy.highlights.colors[verb.color])}
            title={copy.highlights.colors[verb.color]}
            onClick={() => onChoose(verb.color)}
          />
        ) : (
          <button key={verb.kind} type="button" {...place} className="selection-verb" onClick={onNote}>
            {copy.notes.note}
          </button>
        );
      })}
    </div>
  );
}
