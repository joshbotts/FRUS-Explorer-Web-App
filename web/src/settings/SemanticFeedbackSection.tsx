// Settings ▸ Data's Semantic Match Feedback (PLAN's S26d), the app's screen of that name (`SemanticFeedbackView`) as a
// section of the pane: About this experiment, How to give feedback, the verdicts recorded with the user's account, the
// totals and each era's count as the app's summary gives them, its footer, Download Feedback File, which saves the
// app's file, `frus-semantic-feedback.json`, and Clear Recorded Feedback after the app's question; the two offered
// while a verdict is recorded, as the app's are. The web's own: the file is saved by the browser where the app prepares
// it to share or to mail, so its two buttons are one link; and a line says once the verdicts are deleted.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { servedPath } from '../api/base';
import { errorMessage } from '../api/client';
import { clearSemanticFeedback, semanticFeedbackFilePath, semanticFeedbackQuery } from '../api/semanticFeedback';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';

const words = copy.semanticFeedback;

export function SemanticFeedbackSection() {
  const client = useQueryClient();
  const summary = useQuery(semanticFeedbackQuery);
  const headingId = useId();
  const heading = useRef<HTMLHeadingElement>(null);
  const clearButton = useRef<HTMLButtonElement>(null);
  const [asking, setAsking] = useState(false);
  const [said, setSaid] = useState('');
  const total = summary.data?.total ?? 0;

  return (
    <section className="semantic-feedback" aria-labelledby={headingId}>
      <h2 id={headingId} ref={heading} tabIndex={-1}>
        {words.title}
      </h2>
      <h3>{words.aboutHeader}</h3>
      <p>{words.what}</p>
      <p className="note">{words.unknown}</p>
      <h3>{words.howHeader}</h3>
      <p>{words.how}</p>
      <h3>{words.recordedHeader}</h3>
      {summary.isError ? (
        // Said where it is read, not announced: the pane's other sections say their own failures.
        <p className="note warning">{errorMessage(summary.error)}</p>
      ) : !summary.data ? (
        <p className="note">{words.loading}</p>
      ) : (
        <dl className="feedback-counts">
          <div>
            <dt>{words.total}</dt>
            <dd>{summary.data.total.toLocaleString('en-US')}</dd>
          </div>
          <div>
            <dt>{words.helpful}</dt>
            <dd>{summary.data.helpful.toLocaleString('en-US')}</dd>
          </div>
          {/* The era split, on screen rather than only in the file, as the app's is: what says whether the feedback can
              answer the question it replaced. */}
          {summary.data.byEra.map((era) => (
            <div key={era.era}>
              <dt>{era.label}</dt>
              <dd>{era.count.toLocaleString('en-US')}</dd>
            </div>
          ))}
        </dl>
      )}
      {summary.data && <p className="note">{words.footer(summary.data.address)}</p>}
      <div className="actions">
        {total > 0 ? (
          // The server names the file as the app names it, and the browser saves it.
          <a className="button" href={servedPath(semanticFeedbackFilePath)} download={summary.data?.fileName}>
            {words.download}
          </a>
        ) : (
          <button type="button" disabled>
            {words.download}
          </button>
        )}
        <button ref={clearButton} type="button" className="destructive" disabled={total === 0} onClick={() => setAsking(true)}>
          {words.clear}
        </button>
      </div>
      <p className="note" aria-live="polite">
        {said}
      </p>
      {asking && (
        <ClearQuestion
          onClose={(cleared) => {
            setAsking(false);
            if (cleared) {
              setSaid(words.cleared);
              // Nothing is left to download or clear, so the focus goes back to the section's heading.
              heading.current?.focus();
            } else {
              clearButton.current?.focus();
            }
          }}
          clear={() => clearSemanticFeedback(client)}
        />
      )}
    </section>
  );
}

/** The app's question before the verdicts are deleted: Delete Feedback, and Cancel first. */
function ClearQuestion({ onClose, clear }: { onClose: (cleared: boolean) => void; clear: () => Promise<number> }) {
  const headingId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function remove() {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await clear();
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
      initial={cancel}
      onCancel={() => {
        if (!busy) onClose(false);
      }}
      onEscape={() => {
        if (!busy) onClose(false);
      }}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {words.clearConfirm}
      </h2>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" aria-disabled={busy} onClick={() => !busy && onClose(false)}>
          {words.cancel}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void remove()}>
          {words.clearAction}
        </button>
      </div>
    </Modal>
  );
}
