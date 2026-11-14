// The rail's Classification (PLAN's S21g), the app's classification control (`ClassificationInfoSection`, the footer
// of its rail's Document tools, and the rail's `applyReclassification`, `DocumentView/ResearchRailView.swift`): the
// document's classification as the index gives it, Editorial note or Document; when this server keeps a correction
// of it, what FRUS says, the TEI's own, or that FRUS now agrees; and for a curator, the flip, Reclassify as Document…
// or Reclassify as Editorial Note…, or Restore FRUS's Classification, each after the app's question. The web's own:
// the section, which the web's rail has in place of the app's info popover; a document the index does not hold, for
// which the app shows nothing; who made the correction; and a correction or a restore that waits, for an Import
// server's next export or a job, which the section shows as the document will be once it is applied, with a line
// saying it waits, and whose flip the server checks against that.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { classificationQuery, type DocumentClassification, reclassify, restoreClassification } from '../api/people';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';

/**
 * What the section says the document is: the correction kept, a restore waiting, else the index's; so what the index
 * says once what waits is applied, as the server checks a flip against it.
 */
export function shownClassification(data: DocumentClassification): boolean | null {
  if (data.isEditorialNote == null) return null;
  if (data.correction) return data.correction.isEditorialNote;
  if (data.waiting === 'restore') return data.parsedIsEditorialNote ?? data.isEditorialNote;
  return data.isEditorialNote;
}

/** The control's title, the app's `reclassifyTitle`: the restore while a correction is kept, else the flip. */
export function actionTitle(data: DocumentClassification): string {
  if (data.correction) return copy.classification.restore;
  return shownClassification(data) ? copy.classification.toDocument : copy.classification.toNote;
}

/** The line under a kept correction, the app's: what FRUS tags it as, or that FRUS now tags it the same way. */
export function correctionLine(data: DocumentClassification): string | null {
  if (!data.correction || data.parsedIsEditorialNote == null) return null;
  if (data.parsedIsEditorialNote === data.correction.isEditorialNote) return copy.classification.nowRedundant;
  const what = data.parsedIsEditorialNote ? copy.classification.noteInline : copy.classification.documentInline;
  return data.correction.madeBy ? copy.classification.overriddenBy(what, data.correction.madeBy) : copy.classification.overridden(what);
}

export function ClassificationSection({
  volumeId,
  documentId,
  onChanged,
}: {
  volumeId: string;
  documentId: string;
  /** Told once a correction is applied, so the reader shows the text as the new classification shapes it. */
  onChanged?: () => void;
}) {
  const client = useQueryClient();
  const classification = useQuery(classificationQuery(volumeId, documentId));
  const button = useRef<HTMLButtonElement>(null);
  const [asking, setAsking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const data = classification.data;

  if (classification.isError) {
    return (
      <p className="error" role="alert">
        {errorMessage(classification.error)}
      </p>
    );
  }
  if (!data) return <p role="status">{copy.classification.loading}</p>;
  const shown = shownClassification(data);
  if (!data.indexed || shown == null) return <p className="note">{copy.classification.notIndexed}</p>;
  const title = actionTitle(data);
  const line = correctionLine(data);
  const waiting =
    data.waiting === 'restore'
      ? data.mode === 'import' ? copy.classification.waitingRestore : copy.classification.waitingJob
      : data.waiting === 'correction'
        ? data.mode === 'import' ? copy.classification.waitingExport : copy.classification.waitingJob
        : null;

  async function apply() {
    if (busy || !data) return;
    setBusy(true);
    setFailure(null);
    try {
      const restoring = !!data.correction;
      const outcome = restoring
        ? await restoreClassification(client, volumeId, documentId)
        : await reclassify(client, volumeId, documentId, !shown);
      await client.invalidateQueries({ queryKey: ['classification', volumeId, documentId] });
      setStatus(
        outcome.state === 'applied' ? copy.classification.applied
          : outcome.state === 'nextExport' ? (restoring ? copy.classification.waitingRestore : copy.classification.waitingExport)
            : copy.classification.waitingJob,
      );
      if (outcome.state === 'applied') onChanged?.();
    } catch (error) {
      setFailure(errorMessage(error));
    }
    setBusy(false);
    requestAnimationFrame(() => button.current?.focus());
  }

  return (
    <div className="classification">
      <p>{shown ? copy.classification.note : copy.classification.document}</p>
      {line && <p className="note">{line}</p>}
      {waiting && <p className="note">{waiting}</p>}
      <p className="visually-hidden" role="status">
        {status}
      </p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {data.canCorrect && (
        <button ref={button} type="button" aria-disabled={busy} onClick={() => !busy && setAsking(true)}>
          {title}
        </button>
      )}
      {asking && (
        <ClassificationQuestion
          title={title}
          importMode={data.mode === 'import'}
          onClose={(confirmed) => {
            setAsking(false);
            if (confirmed) void apply();
            else requestAnimationFrame(() => button.current?.focus());
          }}
        />
      )}
    </div>
  );
}

/** The app's confirmation: the action's title, its warning, the action and Cancel; on an Import server, when. */
function ClassificationQuestion({ title, importMode, onClose }: { title: string; importMode: boolean; onClose: (confirmed: boolean) => void }) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const confirmed = useRef(false);

  function close() {
    body.current?.closest('dialog')?.close();
  }

  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel}
      onCancel={close} onClose={() => onClose(confirmed.current)}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {title}
        </h2>
        <p id={messageId}>
          {copy.classification.warning}
          {importMode && ` ${copy.classification.warningImport}`}
        </p>
        <div className="actions">
          <button ref={cancel} type="button" onClick={close}>
            {copy.classification.cancel}
          </button>
          <button type="button" onClick={() => {
            confirmed.current = true;
            close();
          }}>
            {title}
          </button>
        </div>
      </div>
    </Modal>
  );
}
