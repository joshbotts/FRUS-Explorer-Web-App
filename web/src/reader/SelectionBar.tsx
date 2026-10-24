// The selection bar over the reader's frame (SPEC, Reader rendering: "The parent page draws the
// floating selection bar"), as the Mac's `FloatingSelectionBar` draws it: a dark pill above the
// selection with the verbs the selection allows, in the kit's order. In the web edition so far those
// are the four colours, each a dot named as VoiceOver reads the app's, "Highlight Yellow"; a
// footnote's selection allows none of them, so it has no bar. A toolbar for the keyboard, which
// Alt+F10 reaches from the text: the arrow keys, Home and End move between the dots, Return or Space
// chooses one, and Escape puts the bar away.
import { type RefObject, useEffect, useLayoutEffect, useRef, useState } from 'react';
import type { HighlightColor } from '../api/types';
import { copy } from '../copy';
import { barPosition, offeredVerbs } from './highlightRules';
import type { SelectionRect } from './readerMessages';

export function SelectionBar({
  rect,
  frame,
  focusRequest,
  onChoose,
  onDismiss,
}: {
  /** The selection's rectangle in the frame's viewport, as the kit's bridge measured it. */
  rect: SelectionRect;
  frame: RefObject<HTMLIFrameElement | null>;
  /** Changes when the keyboard asks for the bar: its first dot then takes focus. */
  focusRequest: number;
  onChoose: (color: HighlightColor) => void;
  onDismiss: () => void;
}) {
  const bar = useRef<HTMLDivElement>(null);
  const dots = useRef<(HTMLButtonElement | null)[]>([]);
  const [active, setActive] = useState(0);
  const [position, setPosition] = useState<{ left: number; top: number } | null>(null);
  const colors = offeredVerbs(true).flatMap((verb) => (verb.kind === 'highlight' ? [verb.color] : []));

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

  // The first dot takes focus, and with it the bar's place in the Tab order (its onFocus).
  useEffect(() => {
    if (focusRequest !== 0) dots.current[0]?.focus({ preventScroll: true });
  }, [focusRequest]);

  function move(to: number) {
    const next = (to + colors.length) % colors.length;
    setActive(next);
    dots.current[next]?.focus({ preventScroll: true });
  }

  return (
    <div
      ref={bar}
      role="toolbar"
      aria-label={copy.highlights.bar}
      className="selection-bar"
      // Through the CSSOM, which the app's policy allows; it is hidden until it is placed.
      style={position ? { left: `${position.left}px`, top: `${position.top}px` } : { visibility: 'hidden' }}
      onKeyDown={(event) => {
        const keys: Partial<Record<string, number>> = { ArrowRight: active + 1, ArrowDown: active + 1, ArrowLeft: active - 1, ArrowUp: active - 1, Home: 0, End: colors.length - 1 };
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
      {colors.map((color, index) => (
        <button
          key={color}
          ref={(element) => {
            dots.current[index] = element;
          }}
          type="button"
          tabIndex={index === active ? 0 : -1}
          className={`selection-color hl-${color}`}
          aria-label={copy.highlights.highlightColor(copy.highlights.colors[color])}
          title={copy.highlights.colors[color]}
          onFocus={() => setActive(index)}
          onClick={() => onChoose(color)}
        />
      ))}
    </div>
  );
}
