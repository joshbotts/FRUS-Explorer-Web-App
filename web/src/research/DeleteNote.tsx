// The question All Notes asks before a note is deleted, as the app's: Delete Note?, its sentence,
// and Delete and Cancel, Cancel first. The editor's own Delete asks nothing, as the app's does not.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { NoteSummary } from '../api/types';
import { deleteNote } from '../api/userData';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';

/** Asks, then deletes `note`; `onClose` says whether it was deleted. */
export function DeleteNote({ note, onClose }: { note: NoteSummary; onClose: (deleted: boolean) => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function remove() {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await deleteNote(client, note);
      closeAtOnce(() => onClose(true));
    } catch (problem) {
      setFailure(errorMessage(problem));
      setBusy(false);
    }
  }

  return (
    <Modal
      className="confirm"
      role="alertdialog"
      labelledBy={headingId}
      describedBy={messageId}
      initial={cancel}
      // While the deletion is sent, Cancel and Escape wait for it: it cannot be called back.
      onCancel={() => {
        if (!busy) onClose(false);
      }}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.allNotes.deleteTitle}
      </h2>
      <p id={messageId}>{copy.allNotes.deleteMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" aria-disabled={busy} onClick={() => !busy && onClose(false)}>
          {copy.allNotes.deleteCancel}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void remove()}>
          {copy.allNotes.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}
