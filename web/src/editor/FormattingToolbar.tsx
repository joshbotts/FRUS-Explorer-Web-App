// The note editor's formatting bar (PLAN's S15d), as the app's `RichTextFormattingBar`: Bold, Italic
// and Underline, each pressed when the selection's start has it; Text Color, any colour, as the
// app's colour panel gives, near-black meaning none; and Link selected text to a URL, offered only
// over a selection, pressed when its start has a link. A toolbar for the keyboard: one stop in the
// Tab order, the arrow keys, Home and End between its controls. A press keeps the selection, as the
// app's buttons take no focus, and goes back to the text.
import type { Editor } from '@tiptap/core';
import { useEditorState } from '@tiptap/react';
import { useEffect, useRef, useState } from 'react';
import { copy } from '../copy';
import { activeAtStart, marksAtStart, type ToggledMark, toggleAtStart } from './noteExtensions';
import { nearBlack } from './runs';

/** The link at the selection's start, or null: what the link dialog starts with. */
export function linkAtStart(editor: Editor): string | null {
  const link = marksAtStart(editor.state).find((mark) => mark.type.name === 'link');
  return typeof link?.attrs.href === 'string' && link.attrs.href !== '' ? link.attrs.href : null;
}

/** The colour at the selection's start, `RRGGBB`, or null. */
function colorAtStart(editor: Editor): string | null {
  const color = marksAtStart(editor.state).find((mark) => mark.type.name === 'noteColor');
  return typeof color?.attrs.hex === 'string' ? color.attrs.hex : null;
}

/**
 * A colour picked, over the selection, or at a caret for what is typed next, in one change, as the
 * app's colour panel applies it: near-black takes the colour off, which the app's span reads as none.
 */
export function applyColor(editor: Editor, value: string) {
  const hex = value.replace(/^#/, '').toUpperCase();
  if (!/^[0-9A-F]{6}$/.test(hex)) return;
  const chain = editor.chain().focus();
  if (nearBlack(hex)) chain.unsetMark('noteColor').run();
  else chain.setMark('noteColor', { hex }).run();
}

const toggles: readonly ToggledMark[] = ['bold', 'italic', 'underline'];

export function FormattingToolbar({ editor, controls, onLink }: { editor: Editor; controls: string; onLink: () => void }) {
  const state = useEditorState({
    editor,
    selector: ({ editor: current }) => ({
      bold: activeAtStart(current.state, 'bold'),
      italic: activeAtStart(current.state, 'italic'),
      underline: activeAtStart(current.state, 'underline'),
      link: linkAtStart(current),
      color: colorAtStart(current),
      hasSelection: !current.state.selection.empty,
    }),
  });
  const controlRefs = useRef<(HTMLElement | null)[]>([]);
  const colorInput = useRef<HTMLInputElement>(null);
  const [active, setActive] = useState(0);
  const count = toggles.length + 2;

  // The colour input shows the selection's start's colour, or black; it is not React's to hold, so
  // a drag in the picker is not undone on every step.
  useEffect(() => {
    if (colorInput.current) colorInput.current.value = state.color ? `#${state.color.toLowerCase()}` : '#000000';
  }, [state.color]);
  // Applied once, when the picker commits it (change, not each input on the way).
  useEffect(() => {
    const input = colorInput.current;
    if (!input) return;
    const commit = () => applyColor(editor, input.value);
    input.addEventListener('change', commit);
    return () => input.removeEventListener('change', commit);
  }, [editor]);

  function move(to: number) {
    const next = (to + count) % count;
    setActive(next);
    controlRefs.current[next]?.focus();
  }

  /** A control's place in the toolbar's one Tab stop. */
  const place = (index: number) => ({ tabIndex: index === active ? 0 : -1, onFocus: () => setActive(index) });

  return (
    <div
      role="toolbar"
      aria-label={copy.richText.toolbar}
      aria-controls={controls}
      className="formatting-bar"
      onKeyDown={(event) => {
        const keys: Partial<Record<string, number>> = { ArrowRight: active + 1, ArrowDown: active + 1, ArrowLeft: active - 1, ArrowUp: active - 1, Home: 0, End: count - 1 };
        const to = keys[event.key];
        if (to === undefined) return;
        event.preventDefault();
        move(to);
      }}
    >
      {toggles.map((mark, index) => (
        <button
          key={mark}
          type="button"
          className={`format-${mark}`}
          ref={(element) => {
            controlRefs.current[index] = element;
          }}
          {...place(index)}
          aria-pressed={state[mark]}
          title={copy.richText[mark]}
          // The selection stays in the text, as the app's buttons take no focus.
          onMouseDown={(event) => event.preventDefault()}
          onClick={() => toggleAtStart(editor, mark)}
        >
          <span aria-hidden="true">{copy.richText.glyphs[mark]}</span>
          <span className="visually-hidden">{copy.richText[mark]}</span>
        </button>
      ))}
      <input
        type="color"
        className="format-color"
        {...place(toggles.length)}
        ref={(element) => {
          controlRefs.current[toggles.length] = element;
          colorInput.current = element;
        }}
        aria-label={copy.richText.color}
        title={copy.richText.color}
        defaultValue="#000000"
      />
      <button
        type="button"
        className="format-link"
        ref={(element) => {
          controlRefs.current[toggles.length + 1] = element;
        }}
        {...place(toggles.length + 1)}
        aria-pressed={state.link !== null}
        // aria-disabled, not disabled, so it keeps its place for the keyboard.
        aria-disabled={!state.hasSelection}
        title={copy.richText.link}
        onMouseDown={(event) => event.preventDefault()}
        onClick={() => {
          if (state.hasSelection) onLink();
        }}
      >
        <span aria-hidden="true">{copy.richText.glyphs.link}</span>
        <span className="visually-hidden">{copy.richText.link}</span>
      </button>
    </div>
  );
}
