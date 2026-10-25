// The note editor's schema and keys (PLAN's S15d): paragraphs of text with the app's five
// formattings, Bold, Italic, Underline, a colour and a link, and nothing else, so a pasted list or
// heading falls back to paragraphs, as the app's span model has no place for them. A colour is a
// mark of its own whose markup names it in `data-color` and never in a style attribute, which the
// page's policy refuses; the editor draws it through the CSSOM, lighter on the dark theme where it
// would be too dark to read, the web's own. A pasted link's address is written as the link dialog
// writes one. Bold, Italic and Underline turn on or off by the selection's start, as the app's bar
// does, from their buttons and their keys alike.
import { type Attributes, type Editor, Extension, Mark, MarkView, type MarkViewRendererProps, mergeAttributes } from '@tiptap/core';
import { Bold } from '@tiptap/extension-bold';
import { Document } from '@tiptap/extension-document';
import { Italic } from '@tiptap/extension-italic';
import { Link } from '@tiptap/extension-link';
import { Paragraph } from '@tiptap/extension-paragraph';
import { Text } from '@tiptap/extension-text';
import { Underline } from '@tiptap/extension-underline';
import { UndoRedo } from '@tiptap/extensions';
import type { Mark as ProseMirrorMark } from '@tiptap/pm/model';
import { type EditorState, Plugin, PluginKey } from '@tiptap/pm/state';
import { pasteProps } from './paste';
import { followableLink, followableScheme } from './runs';

/** The marks a toolbar button or key turns on or off. */
export type ToggledMark = 'bold' | 'italic' | 'underline';

/**
 * The marks at the selection's start, as the app's `refreshSelectionState` reads them: the first
 * selected character's, or at a caret what typing would take. A selection that starts at a line's
 * end, an empty line's included, starts with the line break, the app's "\n", which has the
 * formatting of the text before it, as a note's runs give it (none at the start), its link included.
 */
export function marksAtStart(state: EditorState): readonly ProseMirrorMark[] {
  const { selection, doc } = state;
  if (selection.empty) return state.storedMarks ?? selection.$from.marks();
  let found: readonly ProseMirrorMark[] | null = null;
  doc.nodesBetween(selection.from, selection.to, (node, pos) => {
    if (found || !node.isTextblock) return !found;
    const start = pos + 1;
    const end = start + node.content.size;
    const at = Math.max(selection.from, start);
    // The first selected character is in this line's text, or is the break at its end.
    if (at < Math.min(selection.to, end)) found = node.childAfter(at - start).node?.marks ?? [];
    else if (end < selection.to) found = marksBefore(state, end);
    return false;
  });
  return found ?? selection.$from.marks();
}

/** The marks of the last text before `pos`, which a line break there has; none at the start. */
function marksBefore(state: EditorState, pos: number): readonly ProseMirrorMark[] {
  let marks: readonly ProseMirrorMark[] = [];
  state.doc.nodesBetween(0, pos, (node) => {
    if (node.isText) marks = node.marks;
    return true;
  });
  return marks;
}

/** Whether the selection's start has `name`, as each button shows and each toggle reads. */
export function activeAtStart(state: EditorState, name: string): boolean {
  return marksAtStart(state).some((mark) => mark.type.name === name);
}

/**
 * Turns `name` off over the selection when its start has it, else on, so a mixed selection
 * converges as the app's `toggleTrait` makes it; at a caret, for what is typed next.
 */
export function toggleAtStart(editor: Editor, name: ToggledMark, focus = true): boolean {
  const chain = focus ? editor.chain().focus() : editor.chain();
  return activeAtStart(editor.state, name) ? chain.unsetMark(name).run() : chain.setMark(name).run();
}

/** The page under the note's text in the dark theme, app.css's `--bg` there. */
const darkPage = [0x1c, 0x1c, 0x1e];

/** WCAG's relative luminance of an sRGB colour, its channels 0 to 255. */
function luminance(channels: readonly number[]): number {
  const [r = 0, g = 0, b = 0] = channels.map((channel) => {
    const value = channel / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/**
 * The colour a note's text is drawn in on the dark theme: its own when it is at 4.5:1 or more on the
 * dark page (WCAG 1.4.3), else mixed with white just enough to be, the web's own. The Mac draws a
 * stored colour as it is in either appearance, so one picked on a light page can be unreadable on a
 * dark one; the note keeps its own colour either way.
 */
export function darkThemeColor(hex: string): string {
  const channels = [0, 2, 4].map((at) => Number.parseInt(hex.slice(at, at + 2), 16));
  const page = luminance(darkPage);
  let mixed = channels;
  for (let white = 0; white <= 100; white++) {
    mixed = channels.map((channel) => Math.round(channel + ((255 - channel) * white) / 100));
    if ((luminance(mixed) + 0.05) / (page + 0.05) >= 4.5) break;
  }
  return `#${mixed.map((channel) => channel.toString(16).padStart(2, '0')).join('')}`.toUpperCase();
}

/**
 * A colour's mark, drawn by its own view, which sets the colour through the CSSOM: its own, and the
 * one app.css draws it in on the dark theme.
 */
class NoteColorView extends MarkView<null> {
  private readonly span: HTMLSpanElement;

  constructor(props: MarkViewRendererProps) {
    super(null, props);
    this.span = document.createElement('span');
    const hex = String(props.mark.attrs.hex);
    this.span.dataset.color = hex;
    this.span.style.setProperty('--note-color', `#${hex}`);
    this.span.style.setProperty('--note-color-dark', darkThemeColor(hex));
  }

  override get dom(): HTMLElement {
    return this.span;
  }

  override get contentDOM(): HTMLElement {
    return this.span;
  }
}

const hexPattern = /^[0-9A-Fa-f]{6}$/;

/** A text colour, uppercase `RRGGBB`, as the app's span carries it. */
export const NoteColor = Mark.create({
  name: 'noteColor',

  addAttributes() {
    return {
      hex: {
        default: null,
        parseHTML: (element) => element.getAttribute('data-color')?.toUpperCase() ?? null,
        renderHTML: (attributes) => ({ 'data-color': attributes.hex as string }),
      },
    };
  },

  parseHTML() {
    return [{ tag: 'span[data-color]', getAttrs: (element) => (hexPattern.test(element.getAttribute('data-color') ?? '') ? null : false) }];
  },

  renderHTML({ HTMLAttributes }) {
    return ['span', HTMLAttributes, 0];
  },

  addMarkView() {
    return (props) => new NoteColorView(props);
  },
});

/**
 * A link, as the app's: never made as one types or pastes, and not followed on a click, which places
 * the caret. Only http, https and mailto are made here and drawn with an address; a Mac note's link
 * of another kind is kept, drawn as linked text without one. A pasted link's address is written as
 * the link dialog writes a typed one, so the server's writer can hold it; one that cannot be is
 * pasted as its text alone.
 */
export const NoteLink = Link.extend({
  addAttributes() {
    const parent: Attributes = this.parent?.() ?? {};
    return {
      ...parent,
      href: { ...parent.href, parseHTML: (element: HTMLElement) => followableLink(element.getAttribute('href') ?? '') },
    };
  },

  parseHTML() {
    return [{ tag: 'a[href]', getAttrs: (element) => (followableLink(element.getAttribute('href') ?? '') ? null : false) }];
  },

  renderHTML({ HTMLAttributes }) {
    const { href, ...rest } = HTMLAttributes as { href?: unknown };
    const attributes = mergeAttributes(this.options.HTMLAttributes, rest);
    return ['a', followableScheme(href) ? { ...attributes, href } : attributes, 0];
  },
}).configure({
  autolink: false,
  linkOnPaste: false,
  openOnClick: false,
  HTMLAttributes: { target: null, rel: 'noopener noreferrer nofollow', class: null },
  isAllowedUri: (url) => followableScheme(url),
});

/** Bold, Italic and Underline, each with its keys turning it on or off by the selection's start. */
function toggled<T extends typeof Bold | typeof Italic | typeof Underline>(mark: T, name: ToggledMark, key: string): T {
  return mark.extend({
    addKeyboardShortcuts() {
      return {
        [`Mod-${key}`]: () => toggleAtStart(this.editor, name, false),
        [`Mod-${key.toUpperCase()}`]: () => toggleAtStart(this.editor, name, false),
      };
    },
  }) as T;
}

/** The extensions whose nodes and marks make the note's schema, in the order its marks rank. */
export function schemaExtensions() {
  return [Document, Paragraph, Text, toggled(Bold, 'bold', 'b'), toggled(Italic, 'italic', 'i'), toggled(Underline, 'underline', 'u'), NoteColor, NoteLink];
}

/**
 * The editor's own keys: Escape is the editor's Discard, as the app's sheet takes it, since the
 * editor would otherwise keep it from the dialog; and ⌘K, or Ctrl+K, the link dialog, the web's own.
 * Each is told to the editor's element, as `discardEvent` and `linkEvent`, which bubble to the
 * component's own element, where it listens: the editor's view may not be mounted when it does.
 */
export const discardEvent = 'frus-note-discard';
export const linkEvent = 'frus-note-link';

const NoteKeys = Extension.create({
  name: 'noteKeys',

  addKeyboardShortcuts() {
    const tell = (name: string) => {
      this.editor.view.dom.dispatchEvent(new CustomEvent(name, { bubbles: true }));
      return true;
    };
    return {
      Escape: () => tell(discardEvent),
      'Mod-k': () => tell(linkEvent),
    };
  },
});

/**
 * How the editor reads pasted markup, as paste.ts sets out: with the formatting a style gave its
 * text, and a paragraph for each line the markup broke. The parser needs the editor's own schema,
 * and each editor its own, which remembers what it marked until the paste is made.
 */
const NotePaste = Extension.create({
  name: 'notePaste',

  addProseMirrorPlugins() {
    return [new Plugin({ key: new PluginKey('notePaste'), props: pasteProps(this.editor.schema) })];
  },
});

/** Every extension the editor runs: the schema's, undo and redo, its own keys and its paste. */
export function editorExtensions() {
  return [...schemaExtensions(), UndoRedo, NoteKeys, NotePaste];
}
