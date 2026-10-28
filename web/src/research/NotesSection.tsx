// The Research rail's Notes section (PLAN's S15d), as the app's rail lists a document's notes: the
// last changed first, each its plain text to three lines, or Empty note, and the time since it
// changed, a row that opens the note in the editor; then, just after a highlight is made, Add Note
// to Highlight, which makes a note that the highlight takes as its own, as the app's link; and Add
// Note. No row is deleted here, as none is in the app's rail: All Notes and the editor delete. A
// document's note block from a research database says so under its text (S16e), the web's own line.
import { useEffect, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { NoteSummary } from '../api/types';
import { copy } from '../copy';
import { NoteEditor } from './NoteEditor';
import { railText, timeSince } from './notesRules';

/** What the editor is open on: a note, a new one, or a new one for the pending highlight. */
type Composing = { note: NoteSummary } | { linkedHighlightId?: string };

/** The time now, again every 15 seconds while the rows show times since. */
function useNow(): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const tick = setInterval(() => setNow(Date.now()), 15_000);
    return () => clearInterval(tick);
  }, []);
  return now;
}

export function NotesSection({
  volumeId,
  documentId,
  notes,
  error,
  pendingHighlightId,
  onPendingUsed,
  toggle,
}: {
  volumeId: string;
  documentId: string;
  notes?: NoteSummary[];
  error: unknown;
  /** The highlight made last on this page, which Add Note to Highlight makes a note for. */
  pendingHighlightId?: string | null;
  /** Add Note to Highlight was chosen: the highlight is no longer pending, saved or not, as the app's. */
  onPendingUsed?: () => void;
  /** The section's disclosure, which takes focus when the row that opened the editor has gone. */
  toggle: { current: HTMLButtonElement | null };
}) {
  const now = useNow();
  const list = useRef<HTMLDivElement>(null);
  const [composing, setComposing] = useState<Composing | null>(null);
  /** What opened the editor, which focus goes back to. */
  const opener = useRef<{ noteId?: string; action?: 'add' | 'addToHighlight' } | null>(null);

  function closed() {
    const from = opener.current;
    setComposing(null);
    // Once the dialog has gone: while it is open, all else is inert.
    // A new note's editor hands focus to Add Note, opened from it or from Add Note to Highlight, which
    // is gone once chosen and stays after Add Note: Enter again never links a note by surprise.
    requestAnimationFrame(() => {
      const root = list.current;
      const target =
        from?.noteId !== undefined
          ? root?.querySelector<HTMLButtonElement>(`button.note-row[data-id="${CSS.escape(from.noteId)}"]`)
          : root?.querySelector<HTMLButtonElement>('button.add-note:not(.add-to-highlight)');
      (target ?? toggle.current)?.focus();
    });
  }

  if (error) {
    return (
      <p className="error" role="alert">
        {errorMessage(error)}
      </p>
    );
  }
  if (!notes) return <p role="status">{copy.notes.loading}</p>;
  return (
    <div ref={list}>
      {notes.length > 0 && (
        <ul className="note-list">
          {notes.map((note) => (
            <li key={note.id}>
              <button
                type="button"
                className="note-row"
                data-id={note.id}
                aria-haspopup="dialog"
                onClick={() => {
                  opener.current = { noteId: note.id };
                  setComposing({ note });
                }}
              >
                <span className={note.bodyText === '' ? 'note-row-text empty' : 'note-row-text'}>{railText(note.bodyText)}</span>
                {note.fromResearchDatabase && <span className="note-row-origin">{copy.notes.fromResearchDatabase}</span>}
                <time className="note-row-time" dateTime={note.lastModified ?? undefined}>
                  {timeSince(note.lastModified, now)}
                </time>
              </button>
            </li>
          ))}
        </ul>
      )}
      <div className="note-actions">
        {pendingHighlightId && (
          <button
            type="button"
            className="add-note add-to-highlight"
            aria-haspopup="dialog"
            onClick={() => {
              opener.current = { action: 'addToHighlight' };
              setComposing({ linkedHighlightId: pendingHighlightId });
              onPendingUsed?.();
            }}
          >
            {copy.notes.addToHighlight}
          </button>
        )}
        <button
          type="button"
          className="add-note"
          aria-haspopup="dialog"
          onClick={() => {
            opener.current = { action: 'add' };
            setComposing({});
          }}
        >
          <span aria-hidden="true">+</span> {copy.notes.add}
        </button>
      </div>
      {composing && (
        <NoteEditor
          volumeId={volumeId}
          documentId={documentId}
          note={'note' in composing ? composing.note : undefined}
          linkedHighlightId={'note' in composing ? undefined : composing.linkedHighlightId}
          onClose={closed}
        />
      )}
    </div>
  );
}
