// The People screen's Corrections (PLAN's S21g), the app's `PersonCorrectionsSheet`: every merge and separation kept
// on this server, newest first, each titled in prose by the names of the records it anchors on, with when it was made
// and by whom, the web's own, and Undo, which removes it and has the index build the rollup again. One undone
// elsewhere meanwhile is gone, which the list says by losing it. On an Import server a correction not yet given to an
// export says so.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { personCorrectionsQuery, type PersonCorrections, undoPersonCorrection } from '../api/people';
import { shortDate } from '../browse/CorporaScreen';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { outcomeLine } from './PersonSheet';
import { correctionTitle } from './peopleRules';

export function CorrectionsSheet({
  onClose,
  onSaid,
}: {
  onClose: (said?: string) => void;
  /** Told what an Undo did when the sheet had closed before the server answered; its own line says it otherwise. */
  onSaid?: (said: string) => void;
}) {
  const client = useQueryClient();
  const corrections = useQuery(personCorrectionsQuery);
  const headingId = useId();
  const footerId = useId();
  const body = useRef<HTMLDivElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const said = useRef<string | undefined>(undefined);
  const closed = useRef(false);
  const data = corrections.data;

  function close() {
    body.current?.closest('dialog')?.close();
  }

  async function undo(item: PersonCorrections['items'][number]) {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    setStatus(copy.people.undoInProgress);
    try {
      const outcome = await undoPersonCorrection(client, item.id);
      said.current = outcomeLine(copy.people.undoDone, outcome, true);
      setStatus(said.current);
      if (closed.current) onSaid?.(said.current);
    } catch (error) {
      // Undone elsewhere: the list, read again, no longer holds it.
      if (!(error instanceof ApiError && error.code === 'CORRECTION_NOT_FOUND')) setFailure(errorMessage(error));
      setStatus('');
    }
    await client.invalidateQueries({ queryKey: ['people'] });
    setBusy(false);
    // The row has gone: the sheet's heading takes the focus, as the list it held is read again.
    requestAnimationFrame(() => heading.current?.focus());
  }

  return (
    <Modal className="corrections-sheet" labelledBy={headingId} onCancel={() => !busy && close()} onClose={() => {
      closed.current = true;
      onClose(said.current);
    }}>
      <div ref={body}>
        <h2 ref={heading} id={headingId} tabIndex={-1}>
          {copy.people.correctionsTitle}
        </h2>
        <p className="visually-hidden" role="status">
          {status}
        </p>
        {corrections.isError ? (
          <p className="error" role="alert">
            {errorMessage(corrections.error)}
          </p>
        ) : !data ? (
          <p role="status">{copy.people.loading}</p>
        ) : data.items.length === 0 ? (
          <div className="empty">
            <h3>{copy.people.correctionsEmptyTitle}</h3>
            <p>{copy.people.correctionsEmptyDetail}</p>
          </div>
        ) : (
          <>
            <ul className="correction-rows" aria-describedby={footerId}>
              {data.items.map((item) => {
                const title = correctionTitle(item);
                const when = shortDate(item.madeAt ?? undefined);
                return (
                  <li key={item.id}>
                    <span>{title}</span>
                    {when && <span className="meta">{item.madeBy ? copy.people.madeBy(when, item.madeBy) : when}</span>}
                    {!item.applied && (
                      <span className="meta">{data.mode === 'import' ? copy.people.waitingExport : copy.people.waitingJob}</span>
                    )}
                    <button type="button" className="destructive" aria-disabled={busy} aria-label={copy.people.undoSpoken(title)}
                      onClick={() => void undo(item)}>
                      {copy.people.undo}
                    </button>
                  </li>
                );
              })}
            </ul>
            <p id={footerId} className="note">
              {copy.people.correctionsFooter}
            </p>
          </>
        )}
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" aria-disabled={busy} onClick={() => !busy && close()}>
            {copy.people.done}
          </button>
        </div>
      </div>
    </Modal>
  );
}
