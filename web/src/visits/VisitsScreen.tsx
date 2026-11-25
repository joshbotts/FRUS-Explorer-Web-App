// The Archives Visits list (PLAN's S30c), at /visits, as the app's `ArchiveVisitListView` draws it: the user's plans, the
// most recently changed first, each row its name, the kit's count of what it derives or how many documents seed it, the
// day it was changed, and, amber, how many of its documents this server holds when it lacks some; each row's Rename,
// Duplicate, which opens the copy, and Delete, which asks first; and the list's last row, New Archives Visit, which makes
// a plan under the active project and opens its editor.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { createVisit, deleteVisit, duplicateVisit, editVisit, visitsQuery, type VisitPlanItem } from '../api/visits';
import { shortDate } from '../browse/CorporaScreen';
import { copy } from '../copy';
import { ResearchNav } from '../research/ResearchNav';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton } from '../shell/MenuButton';
import { closeAtOnce, Modal } from '../shell/Modal';
import { useDocumentTitle } from '../shell/useDocumentTitle';

/** A row's line (`summaryLine`): the kit's count once derived, its documents' until then, and the day it changed. */
export function visitRowLine(plan: VisitPlanItem): string {
  const parts = [plan.summary ?? copy.visits.documents(plan.documentCount)];
  const modified = shortDate(plan.lastModified ?? undefined);
  if (modified) parts.push(copy.visits.modified(modified));
  return parts.join(' · ');
}

export function VisitsScreen() {
  const client = useQueryClient();
  const navigate = useNavigate();
  const visits = useQuery(visitsQuery);
  useDocumentTitle(copy.visits.title);
  useHeadingReady(!visits.isPending);
  const [failure, setFailure] = useState<string | null>(null);
  const [renaming, setRenaming] = useState<VisitPlanItem | null>(null);
  const [deleting, setDeleting] = useState<VisitPlanItem | null>(null);
  const newButton = useRef<HTMLButtonElement>(null);
  const items = visits.data?.items;

  async function create() {
    setFailure(null);
    try {
      const plan = await createVisit(client);
      void navigate({ to: '/visits/$planId', params: { planId: plan.id } });
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  async function duplicate(plan: VisitPlanItem) {
    setFailure(null);
    try {
      const copied = await duplicateVisit(client, plan.id);
      void navigate({ to: '/visits/$planId', params: { planId: copied.id } });
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  return (
    <section className="screen research visits">
      <h1 tabIndex={-1}>{copy.visits.title}</h1>
      <ResearchNav />
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {visits.isError ? (
        <p className="error" role="alert">
          {errorMessage(visits.error)}
        </p>
      ) : !items ? (
        <p role="status">{copy.visits.loading}</p>
      ) : items.length === 0 ? (
        <div className="empty">
          <h2>{copy.visits.emptyTitle}</h2>
          <p>{copy.visits.emptyDetail}</p>
        </div>
      ) : (
        <>
          <ul className="visit-list" aria-label={copy.visits.title}>
            {items.map((plan) => (
              <li key={plan.id} className="visit-row">
                <Link to="/visits/$planId" params={{ planId: plan.id }} className="visit-name">
                  {plan.displayName}
                </Link>
                <MenuButton
                  label="⋯"
                  accessibleLabel={copy.visits.rowMenu(plan.displayName)}
                  className="visit-row-menu"
                  entries={[
                    { kind: 'item', label: copy.visits.rename, onSelect: () => setRenaming(plan) },
                    { kind: 'item', label: copy.visits.duplicate, onSelect: () => void duplicate(plan) },
                    { kind: 'item', label: copy.visits.delete, destructive: true, onSelect: () => setDeleting(plan) },
                  ]}
                />
                <p className="meta">{visitRowLine(plan)}</p>
                {plan.indexedDocumentCount < plan.documentCount && (
                  <p className="count warning">
                    {copy.visits.coverage(plan.indexedDocumentCount, copy.visits.documents(plan.documentCount))}
                  </p>
                )}
              </li>
            ))}
          </ul>
          <p className="note">{copy.visits.footer}</p>
        </>
      )}
      {/* Every list ends with its New row, reachable from the empty state too. */}
      <div className="manage">
        <button ref={newButton} type="button" onClick={() => void create()}>
          {copy.visits.new}
        </button>
      </div>
      {renaming && (
        <RenameVisitDialog
          plan={renaming}
          onClose={() => {
            setRenaming(null);
            newButton.current?.focus();
          }}
        />
      )}
      {deleting && (
        <DeleteVisitDialog
          plan={deleting}
          onClose={() => {
            setDeleting(null);
            newButton.current?.focus();
          }}
        />
      )}
    </section>
  );
}

/** Rename Archives Visit: the name as typed, trimmed by the server's rule; an empty one renames nothing. */
function RenameVisitDialog({ plan, onClose }: { plan: VisitPlanItem; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const [draft, setDraft] = useState(plan.name);
  const [failure, setFailure] = useState<string | null>(null);
  function close() {
    field.current?.closest('dialog')?.close();
  }
  async function save() {
    try {
      await editVisit(client, plan.id, { name: draft });
      closeAtOnce(close);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal className="visit-rename" labelledBy={headingId} initial={field} onCancel={close} onClose={onClose}>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          void save();
        }}
      >
        <h2 id={headingId} tabIndex={-1}>
          {copy.visits.renameTitle}
        </h2>
        <label>
          {copy.visits.renamePlaceholder}{' '}
          <input ref={field} type="text" value={draft} onChange={(event) => setDraft(event.target.value)} />
        </label>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.visits.cancel}
          </button>
          <button type="submit">{copy.visits.save}</button>
        </div>
      </form>
    </Modal>
  );
}

/** The question before a delete, which names what goes with the plan. */
export function DeleteVisitDialog({ plan, onClose }: { plan: { id: string }; onClose: (deleted: boolean) => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const deleted = useRef(false);
  const [failure, setFailure] = useState<string | null>(null);
  function close() {
    cancel.current?.closest('dialog')?.close();
  }
  async function remove() {
    try {
      await deleteVisit(client, plan.id);
      deleted.current = true;
      closeAtOnce(close);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal
      className="confirm"
      role="alertdialog"
      labelledBy={headingId}
      describedBy={messageId}
      initial={cancel}
      onCancel={close}
      onClose={() => onClose(deleted.current)}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.visits.deleteTitle}
      </h2>
      <p id={messageId}>{copy.visits.deleteMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" onClick={close}>
          {copy.visits.cancel}
        </button>
        <button type="button" className="destructive" onClick={() => void remove()}>
          {copy.visits.delete}
        </button>
      </div>
    </Modal>
  );
}
