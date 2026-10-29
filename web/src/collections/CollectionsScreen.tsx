// The Collections tab (PLAN's S18d), as the app's `CollectionListView` lists the user's collections:
// the most recently changed first, each by the name its row prints, with its count of documents, or
// Smart collection for one linked to a saved search, and the day it last changed; every project's at
// first, with the banner that scopes the list to the project the user works in, and back; New
// Collection, the Mac's sheet, which names it and opens its editor; Import Collection…, which makes a
// collection of a `.fruscollection` file and opens it (S18f); and on each row Duplicate, the app's,
// Create Static Snapshot for a smart collection, which opens the snapshot, as the app's context menu
// does (S18f), and Delete…, which asks first, the web's own where the app deletes by a swipe. A failed
// import or snapshot says why under the app's alert's title, the web's own place for it.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  collectionsQuery,
  createCollection,
  deleteCollection,
  duplicateCollection,
  importCollectionFile,
  snapshotCollection,
  type CollectionListItem,
} from '../api/collections';
import { projectsQuery } from '../api/userData';
import { shortDate } from '../browse/CorporaScreen';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { closeAtOnce, Modal } from '../shell/Modal';
import { useActiveProjectId } from '../shell/ProjectPicker';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { hiddenCollectionCount, managerDefaultShowAllCollections, visibleCollections } from './collectionRules';

/** A row's caption, as `CollectionRow` gives it: Smart collection or its documents, then its day. */
export function collectionCaption(collection: CollectionListItem): string {
  const holds = collection.isSmart ? copy.collections.smartLabel : copy.collections.documentCount(collection.documentCount);
  const day = shortDate(collection.lastModified);
  return day ? `${holds} · ${day}` : holds;
}

export function CollectionsScreen() {
  const client = useQueryClient();
  const navigate = useNavigate();
  const collections = useQuery(collectionsQuery);
  const projects = useQuery(projectsQuery);
  const active = useActiveProjectId(projects.data) ?? null;
  useDocumentTitle(copy.collections.title);
  useHeadingReady(!collections.isPending);
  const [showAll, setShowAll] = useState(managerDefaultShowAllCollections);
  const [creating, setCreating] = useState(false);
  const [deleting, setDeleting] = useState<{ collection: CollectionListItem; index: number } | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  // 'import' while a file is imported, or the id of the smart collection being snapshotted.
  const [busy, setBusy] = useState<string | null>(null);
  const newButton = useRef<HTMLButtonElement>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const list = useRef<HTMLUListElement>(null);
  const all = collections.data?.items;
  const shown = all ? visibleCollections(all, active, showAll) : undefined;
  const project = projects.data?.items.find((item) => item.id === active);
  const projectName = project && project.name !== '' ? project.name : copy.collections.untitledProject;

  async function duplicate(collection: CollectionListItem) {
    setFailure(null);
    try {
      await duplicateCollection(client, collection.id);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  /** `importCollection(from:)`: the file chosen made a collection, whose editor then opens. */
  async function importFile(file: File) {
    if (busy) return;
    setBusy('import');
    setFailure(null);
    try {
      const made = await importCollectionFile(client, file);
      void navigate({ to: '/collections/$collectionId', params: { collectionId: made.id } });
    } catch (error) {
      setFailure(`${copy.collections.importFailedTitle}: ${errorMessage(error)}`);
    } finally {
      setBusy(null);
    }
  }

  /** `snapshotSmartCollection(_:)`: the smart collection's results made a collection, whose editor then opens. */
  async function snapshot(collection: CollectionListItem) {
    if (busy) return;
    setBusy(collection.id);
    setFailure(null);
    try {
      const made = await snapshotCollection(client, collection.id);
      void navigate({ to: '/collections/$collectionId', params: { collectionId: made.id } });
    } catch (error) {
      setFailure(`${copy.collections.snapshotFailedTitle}: ${errorMessage(error)}`);
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="screen collections">
      <div className="screen-header">
        <h1 tabIndex={-1}>{copy.collections.title}</h1>
        <button ref={newButton} type="button" onClick={() => setCreating(true)}>
          {copy.collections.new}
        </button>
        {/* aria-disabled, not disabled, so the button keeps its focus while the file is read. */}
        <button type="button" aria-disabled={busy !== null} onClick={() => busy === null && fileInput.current?.click()}>
          {copy.collections.importCollection}
        </button>
        <input
          ref={fileInput}
          type="file"
          className="visually-hidden"
          tabIndex={-1}
          aria-hidden="true"
          accept=".fruscollection,application/json"
          onChange={(event) => {
            const file = event.currentTarget.files?.[0];
            event.currentTarget.value = '';
            if (file) void importFile(file);
          }}
        />
      </div>
      <p className="visually-hidden" role="status">
        {busy === 'import' ? copy.collections.importing : busy ? copy.collections.snapshotting : ''}
      </p>
      {active && all && (
        <div className="scope-banner">
          {showAll ? (
            <>
              <p>{copy.collections.showingAll(projectName)}</p>
              <button type="button" onClick={() => setShowAll(false)}>
                {copy.collections.scopeToProject(projectName)}
              </button>
            </>
          ) : (
            <>
              <p>
                {hiddenCollectionCount(all, active) > 0
                  ? copy.collections.filteredWithHidden(projectName, hiddenCollectionCount(all, active))
                  : copy.collections.filteredNoHidden(projectName)}
              </p>
              {hiddenCollectionCount(all, active) > 0 && (
                <button type="button" onClick={() => setShowAll(true)}>
                  {copy.collections.showAll}
                </button>
              )}
            </>
          )}
        </div>
      )}
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {collections.isError ? (
        <p className="error" role="alert">
          {errorMessage(collections.error)}
        </p>
      ) : !shown ? (
        <p role="status">{copy.collections.loading}</p>
      ) : shown.length === 0 ? (
        <div className="empty">
          <h2>{copy.collections.emptyTitle}</h2>
          <p>{copy.collections.emptyDetail}</p>
          <button type="button" onClick={() => setCreating(true)}>
            {copy.collections.emptyAction}
          </button>
        </div>
      ) : (
        <ul ref={list} className="collection-list" aria-label={copy.collections.title}>
          {shown.map((collection, index) => (
            <li key={collection.id} className="collection-row">
              <Link to="/collections/$collectionId" params={{ collectionId: collection.id }}>
                {collection.listName}
              </Link>
              <p className="meta">{collectionCaption(collection)}</p>
              <div className="row-actions">
                <button type="button" aria-label={`${copy.collections.duplicate} ${collection.listName}`} onClick={() => void duplicate(collection)}>
                  {copy.collections.duplicate}
                </button>
                {collection.isSmart && (
                  <button
                    type="button"
                    aria-label={`${copy.collections.snapshot}: ${collection.listName}`}
                    aria-disabled={busy !== null}
                    onClick={() => void snapshot(collection)}
                  >
                    {copy.collections.snapshot}
                  </button>
                )}
                <button
                  type="button"
                  className="destructive"
                  data-id={collection.id}
                  aria-label={`${copy.collections.delete} ${collection.listName}`}
                  onClick={() => setDeleting({ collection, index })}
                >
                  {copy.collections.delete}
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
      {creating && (
        <NewCollection
          onClose={(made) => {
            setCreating(false);
            if (made) void navigate({ to: '/collections/$collectionId', params: { collectionId: made } });
            else requestAnimationFrame(() => newButton.current?.focus());
          }}
          onCreate={async (name) => (await createCollection(client, name)).id}
        />
      )}
      {deleting && (
        <DeleteCollection
          collection={deleting.collection}
          onClose={(deleted) => {
            const { collection: gone, index } = deleting;
            setDeleting(null);
            requestAnimationFrame(() => {
              const buttons = [...(list.current?.querySelectorAll<HTMLButtonElement>('button.destructive') ?? [])];
              if (!deleted) {
                buttons.find((button) => button.dataset.id === gone.id)?.focus();
                return;
              }
              // To the next row's Delete…, else the one before, else New Collection; never the removed row's own,
              // which stays until the list is read again.
              const rest = buttons.filter((button) => button.dataset.id !== gone.id);
              (rest[index] ?? rest[index - 1] ?? newButton.current)?.focus();
            });
          }}
          onDelete={() => deleteCollection(client, deleting.collection.id)}
        />
      )}
    </section>
  );
}

/** The Mac's New Collection sheet: a name, Cancel, and Create once the name has text. */
export function NewCollection({
  onClose,
  onCreate,
}: {
  /** With the new collection's id, or none for Cancel. */
  onClose: (made?: string) => void;
  onCreate: (name: string) => Promise<string>;
}) {
  const headingId = useId();
  const fieldId = useId();
  const field = useRef<HTMLInputElement>(null);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const empty = name.trim() === '';

  async function create() {
    if (empty || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      const made = await onCreate(name);
      closeAtOnce(() => onClose(made));
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  return (
    <Modal className="new-collection" labelledBy={headingId} initial={field} onCancel={() => onClose()} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {copy.collections.newTitle}
      </h2>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          void create();
        }}
      >
        <label htmlFor={fieldId}>{copy.collections.newName}</label>
        <input
          ref={field}
          id={fieldId}
          type="text"
          value={name}
          placeholder={copy.collections.newNamePlaceholder}
          onChange={(event) => setName(event.target.value)}
        />
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="dialog-actions">
          <button type="button" onClick={() => onClose()}>
            {copy.collections.newCancel}
          </button>
          {/* aria-disabled, not disabled, so Create pressed by keyboard keeps its focus while it is made. */}
          <button type="submit" className="primary" aria-disabled={empty || busy}>
            {copy.collections.newCreate}
          </button>
        </div>
      </form>
    </Modal>
  );
}

/** Delete…'s question, the web's own. */
function DeleteCollection({
  collection,
  onClose,
  onDelete,
}: {
  collection: CollectionListItem;
  onClose: (deleted: boolean) => void;
  onDelete: () => Promise<void>;
}) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function confirm() {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await onDelete();
      closeAtOnce(() => onClose(true));
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
      onCancel={() => onClose(false)}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.collections.deleteTitle}
      </h2>
      <p id={messageId}>
        <strong>{collection.listName}</strong> — {copy.collections.deleteMessage}
      </p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="dialog-actions">
        <button ref={cancel} type="button" onClick={() => onClose(false)}>
          {copy.collections.deleteCancel}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void confirm()}>
          {copy.collections.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}
