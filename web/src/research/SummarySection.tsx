// The Research rail's Summary section (PLAN's S15d), as the Mac's summary block shows a document's
// summaries: one at a time, the newest first, with its label and, while the user's prompts hold the
// prompt that made it, that prompt's name; the history control when there is more than one; and its
// text, raw. The label is the web's own mapping onto the app's words: AI summary for the model's,
// and the headnote chips' AI · edited and Yours for the others, since the app's rail says AI summary
// of every one. A summary the researcher writes here is the web's own, as are Write a Summary and its
// Edit… and Delete…: the app writes none by hand, and nothing here makes or remakes one by a model. A
// summary from a research database, whose prompt the index does not keep, says so in the prompt's
// place (S16e).
import { useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { Summary } from '../api/types';
import { createSummary, deleteSummary, updateSummary } from '../api/userData';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';

/** The app's rail shows the 20 newest (`DocumentViewModel.loadSummaries`' fetch limit). */
export const shownSummaries = 20;

/** A summary's label, by who wrote it. */
export function summaryLabel(summary: Pick<Summary, 'authorship'>): string {
  return summary.authorship === 'userWritten'
    ? copy.summary.userWritten
    : summary.authorship === 'aiEdited'
      ? copy.summary.aiEdited
      : copy.summary.label;
}

export function SummarySection({
  volumeId,
  documentId,
  summaries,
  error,
  index,
  onIndex,
  toggle,
}: {
  volumeId: string;
  documentId: string;
  /** The document's summaries, the newest first, at most 20. */
  summaries?: Summary[];
  error: unknown;
  /** Which is shown: 0 the newest. */
  index: number;
  onIndex: (index: number) => void;
  /** The section's disclosure, which takes focus when the summary it showed is deleted. */
  toggle: { current: HTMLButtonElement | null };
}) {
  const textId = useId();
  const writeButton = useRef<HTMLButtonElement>(null);
  const [writing, setWriting] = useState<{ summary?: Summary } | null>(null);
  const [deleting, setDeleting] = useState<Summary | null>(null);
  const opener = useRef<HTMLElement | null>(null);

  function returnFocus() {
    const target = opener.current;
    requestAnimationFrame(() => (target?.isConnected ? target : (writeButton.current ?? toggle.current))?.focus());
  }

  if (error) {
    return (
      <p className="error" role="alert">
        {errorMessage(error)}
      </p>
    );
  }
  if (!summaries) return <p role="status">{copy.summary.loading}</p>;
  const shown = summaries[Math.min(index, summaries.length - 1)];
  const position = summaries.length > 0 ? Math.min(index, summaries.length - 1) : 0;
  return (
    <>
      {shown && (
        <div className="summary-block">
          <div className="summary-header">
            <span className="summary-label">{summaryLabel(shown)}</span>
            {shown.promptName && <span className="summary-prompt">{copy.summary.prompt(shown.promptName)}</span>}
            {shown.fromResearchDatabase && <span className="summary-prompt">{copy.summary.fromResearchDatabase}</span>}
            {summaries.length > 1 && (
              <span className="summary-history">
                {/* aria-disabled, not disabled, so the button pressed by keyboard keeps its focus at either end. */}
                <button
                  type="button"
                  aria-label={copy.summary.older}
                  title={copy.summary.olderHelp}
                  aria-disabled={position >= summaries.length - 1}
                  onClick={() => position < summaries.length - 1 && onIndex(position + 1)}
                >
                  <span aria-hidden="true">‹</span>
                </button>
                <span aria-hidden="true">{copy.summary.position(position + 1, summaries.length)}</span>
                <span className="visually-hidden">{copy.summary.positionLabel(position + 1, summaries.length)}</span>
                <button
                  type="button"
                  aria-label={copy.summary.newer}
                  title={copy.summary.newerHelp}
                  aria-disabled={position <= 0}
                  onClick={() => position > 0 && onIndex(position - 1)}
                >
                  <span aria-hidden="true">›</span>
                </button>
              </span>
            )}
          </div>
          <p id={textId} className="summary-text">
            {shown.responseText}
          </p>
          {shown.editable && (
            <div className="summary-actions">
              <button
                type="button"
                aria-haspopup="dialog"
                aria-describedby={textId}
                onClick={(event) => {
                  opener.current = event.currentTarget;
                  setWriting({ summary: shown });
                }}
              >
                {copy.summary.edit}
              </button>
              <button
                type="button"
                className="destructive"
                aria-haspopup="dialog"
                aria-describedby={textId}
                onClick={(event) => {
                  opener.current = event.currentTarget;
                  setDeleting(shown);
                }}
              >
                {copy.summary.delete}
              </button>
            </div>
          )}
        </div>
      )}
      <button
        ref={writeButton}
        type="button"
        className="write-summary"
        aria-haspopup="dialog"
        onClick={(event) => {
          opener.current = event.currentTarget;
          setWriting({});
        }}
      >
        {copy.summary.write}
      </button>
      {writing && (
        <SummaryEditor
          volumeId={volumeId}
          documentId={documentId}
          summary={writing.summary}
          onClose={(saved) => {
            setWriting(null);
            // After a write the newest is shown, as the app's list starts again at its newest.
            if (saved) onIndex(0);
            returnFocus();
          }}
        />
      )}
      {deleting && (
        <DeleteSummary
          summary={deleting}
          onClose={(deleted) => {
            setDeleting(null);
            if (deleted) {
              onIndex(0);
              opener.current = null;
            }
            returnFocus();
          }}
        />
      )}
    </>
  );
}

/** Write a Summary, or Edit Summary for one of the researcher's own: its text, Cancel, which Escape is, and Save. */
function SummaryEditor({
  volumeId,
  documentId,
  summary,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  summary?: Summary;
  onClose: (saved: boolean) => void;
}) {
  const client = useQueryClient();
  const headingId = useId();
  const field = useRef<HTMLTextAreaElement>(null);
  const [text, setText] = useState(summary?.responseText ?? '');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  // As the server takes it: something besides spaces and line breaks.
  const empty = text.trim() === '';

  async function save() {
    if (busy || empty) return;
    setBusy(true);
    setFailure(null);
    try {
      if (summary) await updateSummary(client, summary, text);
      else await createSummary(client, volumeId, documentId, text);
      onClose(true);
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  return (
    <Modal className="summary-editor" labelledBy={headingId} initial={field} onCancel={() => !busy && onClose(false)} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {summary ? copy.summary.editTitle : copy.summary.write}
      </h2>
      <textarea ref={field} value={text} rows={10} aria-labelledby={headingId} onChange={(event) => setText(event.target.value)} />
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button type="button" aria-disabled={busy} onClick={() => !busy && onClose(false)}>
          {copy.summary.cancel}
        </button>
        <button type="button" aria-disabled={busy || empty} onClick={() => void save()}>
          {copy.summary.save}
        </button>
      </div>
    </Modal>
  );
}

/** The question before one's own summary is deleted, as All Notes asks before a note is: Cancel first. */
function DeleteSummary({ summary, onClose }: { summary: Summary; onClose: (deleted: boolean) => void }) {
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
      await deleteSummary(client, summary);
      onClose(true);
    } catch (error) {
      setFailure(errorMessage(error));
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
      onCancel={() => !busy && onClose(false)}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.summary.deleteTitle}
      </h2>
      <p id={messageId}>{copy.summary.deleteMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" aria-disabled={busy} onClick={() => !busy && onClose(false)}>
          {copy.summary.deleteCancel}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void remove()}>
          {copy.summary.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}
