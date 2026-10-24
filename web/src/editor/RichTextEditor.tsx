// The note body's editor (PLAN's S15d), as the app's `RichTextEditor` is the research note's: the
// formatting bar above the text, Tiptap below it, and the link dialog. Loaded only when a note is
// opened with formatting on, so Browse and Search never load it. Its content comes from the note's
// runs, or its plain text, through ProseMirror's JSON, never from markup; it reports each change as
// runs, and says when the note cannot be shown as written, so the note editor opens it plain.
// Tiptap's own stylesheet is in app.css, since the page's policy refuses the <style> it would add.
import type { Editor } from '@tiptap/core';
import { Fragment, Slice } from '@tiptap/pm/model';
import { EditorContent, useEditor } from '@tiptap/react';
import { type Ref, useEffect, useImperativeHandle, useRef, useState } from 'react';
import { flushSync } from 'react-dom';
import type { NoteRun } from '../api/types';
import { FormattingToolbar } from './FormattingToolbar';
import { LinkDialog } from './LinkDialog';
import { discardEvent, editorExtensions, linkEvent } from './noteExtensions';
import { pastedHTML } from './paste';
import { cleanText, docToRuns, lineBreak, runsToDoc, summaryParagraphs, textToDoc } from './runs';

/** What the note editor asks of the body while it is open. */
export interface RichTextEditorHandle {
  /** Adds a summary's text at the end, after a blank line unless the body is empty, keeping the formatting. */
  insertSummary: (text: string) => void;
  /** Puts focus in the text, at its end. */
  focus: () => void;
}

export default function RichTextEditor({
  id,
  label,
  runs,
  text,
  autoFocus,
  onChange,
  onDiscard,
  onUnreadable,
  ref,
}: {
  /** The editable's id, which the formatting bar controls. */
  id: string;
  /** Its name for assistive technology, the app's "Research note body". */
  label: string;
  /** The note's formatting, or null for its plain text alone. */
  runs: NoteRun[] | null;
  /** The note's plain text, which the editor must show exactly. */
  text: string;
  autoFocus: boolean;
  /** Each change to the text or its formatting, as runs. */
  onChange: (runs: NoteRun[]) => void;
  /** Escape in the text: the note editor's Discard. */
  onDiscard: () => void;
  /** The note could not be shown as its plain text reads, so it is to be opened plain. */
  onUnreadable: () => void;
  ref?: Ref<RichTextEditorHandle>;
}) {
  const [linking, setLinking] = useState(false);
  const contentError = useRef(false);
  const [extensions] = useState(editorExtensions);
  const [content] = useState(() => (runs ? runsToDoc(runs) : textToDoc(text)));
  const [expected] = useState(text);
  const wrapper = useRef<HTMLDivElement>(null);
  const report = useRef(onUnreadable);
  useEffect(() => {
    report.current = onUnreadable;
  });

  const editor = useEditor({
    extensions,
    content,
    autofocus: autoFocus ? 'end' : false,
    injectCSS: false,
    // The app's editor makes nothing of **, _ or a pasted address: what is typed is the text.
    enableInputRules: false,
    enablePasteRules: false,
    enableContentCheck: true,
    // Told after the editor exists, not while it is made.
    onContentError: () => {
      contentError.current = true;
    },
    // The content check, once the editor is made and mounted, not in an effect of this component's,
    // which can run before: invalid content, or a text other than the note's, is not shown as the note.
    onCreate: ({ editor: made }) => {
      if (contentError.current || made.getText({ blockSeparator: '\n' }) !== expected) report.current();
    },
    coreExtensionOptions: { clipboardTextSerializer: { blockSeparator: '\n' } },
    editorProps: {
      attributes: { id, 'aria-label': label, 'aria-multiline': 'true', class: 'note-body' },
      transformPastedHTML: (html) => pastedHTML(html),
      clipboardTextParser: (pasted, $context) => {
        const schema = $context.doc.type.schema;
        const paragraphs = pasted.split(lineBreak).map((line) => {
          const clean = cleanText(line);
          return schema.nodes.paragraph!.create(null, clean ? schema.text(clean, $context.marks()) : undefined);
        });
        return new Slice(Fragment.from(paragraphs), 1, 1);
      },
    },
    onUpdate: ({ editor: changed }) => onChange(docToRuns(changed.getJSON())),
    shouldRerenderOnTransaction: false,
  });

  // The editor's own keys: Escape discards, and ⌘K opens the link dialog over a selection, as the
  // bar's Link does; over none it does nothing.
  useEffect(() => {
    // On the component's element, never `editor.view`, which throws until Tiptap has mounted it.
    const element = wrapper.current;
    if (!editor || !element) return;
    // Committed at once: a custom event is no input React knows, so the dialog would otherwise stay
    // a moment, the page around it inert, while focus is sent back to what opened it.
    const discard = () => flushSync(() => onDiscard());
    const link = () => {
      if (!editor.state.selection.empty) setLinking(true);
    };
    element.addEventListener(discardEvent, discard);
    element.addEventListener(linkEvent, link);
    return () => {
      element.removeEventListener(discardEvent, discard);
      element.removeEventListener(linkEvent, link);
    };
  }, [editor, onDiscard]);

  useImperativeHandle(
    ref,
    () => ({
      insertSummary: (summary: string) => {
        if (!editor) return;
        const empty = editor.getText({ blockSeparator: '\n' }) === '';
        const paragraphs = summaryParagraphs(summary, empty);
        if (empty) editor.commands.setContent({ type: 'doc', content: paragraphs });
        else editor.commands.insertContentAt(editor.state.doc.content.size, paragraphs);
      },
      focus: () => editor?.commands.focus('end'),
    }),
    [editor],
  );

  if (!editor) return null;
  return (
    <div className="rich-text" ref={wrapper}>
      <FormattingToolbar editor={editor} controls={id} onLink={() => setLinking(true)} />
      <EditorContent editor={editor} />
      {linking && (
        <LinkDialog
          editor={editor}
          onClose={() => {
            setLinking(false);
            // Once the dialog has gone: while it is open, the text behind it is inert.
            requestAnimationFrame(() => focusKeepingSelection(editor));
          }}
        />
      )}
    </div>
  );
}

/** Focus back in the text with the selection it had, as the link popover leaves the Mac's. */
function focusKeepingSelection(editor: Editor) {
  if (!editor.isDestroyed) editor.commands.focus(null, { scrollIntoView: false });
}
