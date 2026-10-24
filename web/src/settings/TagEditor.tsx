// The tag editor behind a row of Settings ▸ Tags, as the app's `TagEditorView` lays it out: the name,
// then Manage, with Merge into Another Tag… and Delete Tag and the sentence that says what each does;
// Delete Tag asks first, as the app's confirmation does. And Merge Tag (`MergeTagSheet`), which the
// editor hands to its host, as the app's does. Each is a modal dialog: Escape is Cancel.
import { useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { UserTag } from '../api/types';
import { deleteTag, mergeTag, renameTag } from '../api/userData';
import { copy } from '../copy';

/** A modal dialog, open while it is drawn, that focuses `initial` or its heading when it opens. */
function Modal({
  className,
  role,
  labelledBy,
  describedBy,
  initial,
  onCancel,
  onClose,
  children,
}: {
  className: string;
  role?: 'alertdialog';
  labelledBy: string;
  describedBy?: string;
  initial?: { current: HTMLElement | null };
  onCancel: () => void;
  onClose: () => void;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const element = dialog.current;
    if (element && !element.open) element.showModal();
    (initial?.current ?? element?.querySelector<HTMLElement>('h2'))?.focus();
    // Only when it opens.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <dialog
      ref={dialog}
      className={`card ${className}`}
      role={role}
      aria-labelledby={labelledBy}
      aria-describedby={describedBy}
      onClose={onClose}
      onCancel={(event) => {
        event.preventDefault();
        onCancel();
      }}
    >
      {children}
    </dialog>
  );
}

export function TagEditor({
  tag,
  peerTagCount,
  isNew,
  onMerge,
  onClose,
}: {
  tag: UserTag;
  /** How many tags there are, so Merge can say there is nothing to merge into. */
  peerTagCount: number;
  /** A tag just made, opened to be named: Merge and Delete are hidden, as the app hides them. */
  isNew: boolean;
  onMerge: () => void;
  /** Called once the editor has closed, with whether the tag is gone. */
  onClose: (gone: boolean) => void;
}) {
  const client = useQueryClient();
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const [name, setName] = useState(tag.name);
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const deleteButton = useRef<HTMLButtonElement>(null);
  const outcome = useRef<{ gone: boolean; merge: boolean }>({ gone: false, merge: false });
  const dialog = useRef<HTMLDivElement>(null);

  function close(result: { gone: boolean; merge: boolean } = { gone: false, merge: false }) {
    outcome.current = result;
    dialog.current?.closest('dialog')?.close();
  }

  async function save() {
    const trimmed = name.trim();
    if (!trimmed || busy) return;
    if (trimmed === tag.name) return close();
    setBusy(true);
    setFailure(null);
    try {
      await renameTag(client, tag.id, trimmed);
      close();
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  async function remove() {
    setBusy(true);
    setFailure(null);
    try {
      await deleteTag(client, tag.id);
      setConfirming(false);
      close({ gone: true, merge: false });
    } catch (error) {
      setBusy(false);
      setConfirming(false);
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal
      className="tag-editor"
      labelledBy={headingId}
      initial={field}
      onCancel={() => close()}
      onClose={() => (outcome.current.merge ? onMerge() : onClose(outcome.current.gone))}
    >
      <div ref={dialog}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.tagEditor.title}
        </h2>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void save();
          }}
        >
          <h3>{copy.tagEditor.nameHeader}</h3>
          <input
            ref={field}
            type="text"
            value={name}
            placeholder={copy.tagEditor.namePlaceholder}
            aria-label={copy.tagEditor.nameField}
            onChange={(event) => setName(event.target.value)}
          />
        </form>
        {!isNew && (
          <>
            <h3>{copy.tagEditor.manage}</h3>
            <div className="manage">
              <button type="button" disabled={peerTagCount < 2 || busy} onClick={() => close({ gone: false, merge: true })}>
                {copy.tagEditor.merge}
              </button>
              <button ref={deleteButton} type="button" className="destructive" disabled={busy} onClick={() => setConfirming(true)}>
                {copy.tagEditor.delete}
              </button>
            </div>
            <p className="note">{peerTagCount < 2 ? copy.tagEditor.manageFooterOnly : copy.tagEditor.manageFooter}</p>
          </>
        )}
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={() => close()}>
            {copy.tagEditor.cancel}
          </button>
          <button type="button" disabled={name.trim() === '' || busy} onClick={() => void save()}>
            {copy.tagEditor.save}
          </button>
        </div>
      </div>
      {confirming && (
        <DeleteConfirmation
          busy={busy}
          onDelete={() => void remove()}
          onCancel={() => {
            setConfirming(false);
            deleteButton.current?.focus();
          }}
        />
      )}
    </Modal>
  );
}

/** "Delete Tag?", as the app's confirmation asks it, with Delete and Cancel. */
function DeleteConfirmation({ busy, onDelete, onCancel }: { busy: boolean; onDelete: () => void; onCancel: () => void }) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Modal
      className="confirm"
      role="alertdialog"
      labelledBy={headingId}
      describedBy={messageId}
      initial={cancel}
      onCancel={onCancel}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.tagEditor.deleteTitle}
      </h2>
      <p id={messageId}>{copy.tagEditor.deleteMessage}</p>
      <div className="actions">
        <button ref={cancel} type="button" onClick={onCancel}>
          {copy.tagEditor.deleteCancel}
        </button>
        <button type="button" className="destructive" disabled={busy} onClick={onDelete}>
          {copy.tagEditor.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}

/** Merge Tag: the tag chosen takes this one's notes, projects and documents, and this one goes. */
export function MergeTagDialog({
  source,
  others,
  onClose,
}: {
  source: UserTag;
  /** The tags it can be merged into, in the list's order. */
  others: UserTag[];
  /** Called once it has closed, with whether the tag was merged, and so is gone. */
  onClose: (merged: boolean) => void;
}) {
  const client = useQueryClient();
  const headingId = useId();
  const [target, setTarget] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const merged = useRef(false);
  const body = useRef<HTMLDivElement>(null);

  function close() {
    body.current?.closest('dialog')?.close();
  }

  async function merge() {
    if (!target || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await mergeTag(client, source.id, target);
      merged.current = true;
      close();
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal className="merge-tag" labelledBy={headingId} onCancel={close} onClose={() => onClose(merged.current)}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.mergeTag.title}
        </h2>
        <fieldset>
          <legend>{copy.mergeTag.into(source.name)}</legend>
          {others.map((tag) => (
            <label key={tag.id}>
              <input type="radio" name="merge-into" value={tag.id} checked={target === tag.id} onChange={() => setTarget(tag.id)} />{' '}
              {tag.name}
            </label>
          ))}
        </fieldset>
        <p className="note">{copy.mergeTag.explanation(source.name)}</p>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.mergeTag.cancel}
          </button>
          <button type="button" disabled={!target || busy} onClick={() => void merge()}>
            {copy.mergeTag.confirm}
          </button>
        </div>
      </div>
    </Modal>
  );
}
