// The question a tap on a highlight asks before it is removed, as the app's alert asks it: Remove
// Highlight, its sentence, and Remove and Cancel. The Research rail's Remove… asks the same, as the
// app's review sheet does.
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { Highlight } from '../api/types';
import { deleteHighlight } from '../api/userData';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';

/** Asks, then removes `highlight`; `onClose` says whether it was removed. Cancel has focus first. */
export function RemoveHighlight({ highlight, onClose }: { highlight: Highlight; onClose: (removed: boolean) => void }) {
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
      await deleteHighlight(client, highlight);
      onClose(true);
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
      // While the removal is sent, Cancel and Escape wait for it: it cannot be called back.
      onCancel={() => {
        if (!busy) onClose(false);
      }}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.highlights.removeTitle}
      </h2>
      <p id={messageId}>{copy.highlights.removeMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" aria-disabled={busy} onClick={() => !busy && onClose(false)}>
          {copy.highlights.removeCancel}
        </button>
        {/* aria-disabled, not disabled, so a press by keyboard keeps its focus. */}
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void remove()}>
          {copy.highlights.removeConfirm}
        </button>
      </div>
    </Modal>
  );
}
