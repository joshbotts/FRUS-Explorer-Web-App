// Browse's My Scopes (S17e), as the Mac's lists, opens and edits them (`ScopeIndexView`, `ScopeAxis`,
// `ScopeEditorView`): the user's volume scopes, the most recently edited first, with New Scope, which
// makes an empty one and opens its editor; a scope opened, its volumes the catalogue lists, by volume
// number, saying how many it names that the catalogue does not; and the editor, its name as typed and
// its volumes, each removable, with Add Volumes…, which chooses them from the All Volumes catalogue.
// Delete Scope is the web's own, where the Mac keeps it in its Settings.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link, useNavigate } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { volumesQuery } from '../api/endpoints';
import { createScope, deleteScope, editScope, volumeScopeQuery, volumeScopesQuery, type VolumeScope } from '../api/searchSets';
import type { Volume } from '../api/types';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { closeAtOnce, Modal } from '../shell/Modal';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { BrowseAxes } from './BrowseAxes';
import { Breadcrumb } from './Breadcrumb';
import { matchesFilter } from './CatalogueScreen';
import { shortDate } from './CorporaScreen';

/** A scope's name in a list, or Untitled Scope, as `ScopeAxis.displayName` gives it. */
export function scopeName(scope: Pick<VolumeScope, 'name'>): string {
  return scope.name === '' ? copy.scopes.untitled : scope.name;
}

/** A scope row's caption, as `ScopeIndexView` gives it. */
export function scopeCaption(scope: VolumeScope): string {
  return scope.volumeIds.length === 0 ? copy.scopes.rowEmpty : copy.scopes.rowCaption(scope.volumeIds.length, shortDate(scope.lastModified));
}

export function ScopesScreen() {
  const client = useQueryClient();
  const navigate = useNavigate();
  const scopes = useQuery(volumeScopesQuery);
  useDocumentTitle(copy.scopes.title);
  useHeadingReady(!scopes.isPending);
  const [failure, setFailure] = useState<string | null>(null);
  const items = scopes.data?.items;

  async function create() {
    setFailure(null);
    try {
      const scope = await createScope(client);
      void navigate({ to: '/browse/scopes/$scopeId/edit', params: { scopeId: scope.id } });
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  return (
    <section className="screen browse scopes">
      <h1 tabIndex={-1}>{copy.scopes.title}</h1>
      <BrowseAxes current="scopes" />
      <div className="manage">
        <button type="button" title={copy.scopes.newHelp} onClick={() => void create()}>
          {copy.scopes.new}
        </button>
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {scopes.isError ? (
        <p className="error" role="alert">
          {errorMessage(scopes.error)}
        </p>
      ) : !items ? (
        <p role="status">{copy.browse.loading}</p>
      ) : items.length === 0 ? (
        <div className="empty">
          <h2>{copy.scopes.emptyTitle}</h2>
          <p>{copy.scopes.emptyDetail}</p>
        </div>
      ) : (
        <>
          <p className="note">{copy.scopes.coverage}</p>
          <ul className="volume-list" aria-label={copy.scopes.title}>
            {items.map((scope) => (
              <li key={scope.id} className="volume-row">
                <Link
                  to="/browse/scopes/$scopeId"
                  params={{ scopeId: scope.id }}
                  aria-label={copy.scopes.rowLabel(scopeName(scope), scope.volumeIds.length)}
                >
                  {scopeName(scope)}
                </Link>{' '}
                <Link
                  to="/browse/scopes/$scopeId/edit"
                  params={{ scopeId: scope.id }}
                  className="edit"
                  title={copy.scopes.editHelp}
                  aria-label={copy.scopes.edit(scopeName(scope))}
                >
                  ✎
                </Link>
                <p className="meta">{scopeCaption(scope)}</p>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

/** The user's scope this route names, and whether it is gone: deleted, or never theirs. */
function useScope(scopeId: string): { scope: VolumeScope | undefined; gone: boolean; pending: boolean; error: unknown } {
  const scope = useQuery(volumeScopeQuery(scopeId));
  const gone = scope.error instanceof ApiError && scope.error.code === 'SCOPE_NOT_FOUND';
  return { scope: scope.data, gone, pending: scope.isPending, error: gone ? null : scope.error };
}

const scopeRoute = getRouteApi('/browse/scopes/$scopeId');

export function ScopeScreen() {
  const { scopeId } = scopeRoute.useParams();
  const { scope, gone, pending, error } = useScope(scopeId);
  const volumes = useQuery(volumesQuery);
  const title = gone ? copy.scopes.unavailableTitle : scope ? scopeName(scope) : copy.scopes.title;
  useDocumentTitle(title);
  useHeadingReady(!pending);
  const catalogue = new Map((volumes.data?.items ?? []).map((volume) => [volume.volumeId, volume]));
  // `ScopeAxis.spec`: its members the catalogue lists, in the scope's own order.
  const listed = (scope?.volumeIds ?? []).map((id) => catalogue.get(id)).filter((volume): volume is Volume => volume !== undefined);
  const missing = (scope?.volumeIds.length ?? 0) - listed.length;
  return (
    <section className="screen browse scope">
      <Breadcrumb crumbs={[{ label: copy.scopes.title, axis: 'scopes' }]} current={title} />
      <h1 tabIndex={-1}>{title}</h1>
      {gone ? (
        <p>{copy.scopes.unavailableDetail}</p>
      ) : error ? (
        <p className="error" role="alert">
          {errorMessage(error)}
        </p>
      ) : !scope || !volumes.data ? (
        <p role="status">{copy.browse.loading}</p>
      ) : (
        <>
          <p className="note">
            {copy.scopes.drillCaption(listed.length)}
            {missing > 0 && <> {copy.scopes.drillMissing(missing)}</>}
          </p>
          <div className="manage">
            <Link to="/browse/scopes/$scopeId/edit" params={{ scopeId: scope.id }} title={copy.scopes.editHelp}>
              {copy.scopes.editTitle}
            </Link>
          </div>
          <ul className="volume-list" aria-label={title}>
            {listed.map((volume) => (
              <li key={volume.volumeId} className="volume-row">
                <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }}>
                  {volume.title}
                </Link>
                <p className="meta">{volume.volumeId}</p>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

const editRoute = getRouteApi('/browse/scopes/$scopeId/edit');

export function ScopeEditorScreen() {
  const { scopeId } = editRoute.useParams();
  const client = useQueryClient();
  const navigate = useNavigate();
  const { scope, gone, pending } = useScope(scopeId);
  const volumes = useQuery(volumesQuery);
  useDocumentTitle(copy.scopes.editTitle);
  useHeadingReady(!pending);
  const [name, setName] = useState<string | null>(null);
  // The members as the editor last set them, which the page shows at once while the server takes them;
  // until the first edit, the scope's.
  const [members, setMembers] = useState<string[] | null>(null);
  const [picking, setPicking] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const addButton = useRef<HTMLButtonElement>(null);
  const deleteButton = useRef<HTMLButtonElement>(null);
  const nameField = useRef<HTMLInputElement>(null);
  // Each change is sent once the one before it has been answered, so two made quickly reach the server
  // in their order.
  const sending = useRef<Promise<void>>(Promise.resolve());
  const catalogue = new Map((volumes.data?.items ?? []).map((volume) => [volume.volumeId, volume]));
  const shownName = name ?? scope?.name ?? '';
  const shownMembers = members ?? scope?.volumeIds ?? [];

  function edit(fields: { name?: string; volumeIds?: string[] }) {
    if (!scope) return;
    setFailure(null);
    const id = scope.id;
    sending.current = sending.current.then(async () => {
      try {
        await editScope(client, id, fields);
      } catch (error) {
        setFailure(errorMessage(error));
        // What the server holds stands again.
        setMembers(null);
      }
    });
  }

  /** The name as typed, written when the field is left, as the editor's binding writes it. */
  function commitName() {
    if (name !== null && scope && name !== scope.name) edit({ name });
  }

  /** The members as one sorted set, as the editor writes them. */
  function setVolumes(volumeIds: string[]) {
    setMembers(volumeIds);
    edit({ volumeIds });
  }

  function remove(volumeId: string, index: number) {
    setVolumes(shownMembers.filter((id) => id !== volumeId));
    // Focus to the row that takes its place, or Add Volumes… past the last, once the list has gone without it.
    requestAnimationFrame(() => {
      const rows = document.querySelectorAll<HTMLButtonElement>('.scope-members button.remove');
      (rows[Math.min(index, rows.length - 1)] ?? addButton.current)?.focus();
    });
  }

  if (gone) {
    return (
      <section className="screen browse scope-editor">
        <h1 tabIndex={-1}>{copy.scopes.unavailableTitle}</h1>
        <p>{copy.scopes.unavailableDetail}</p>
      </section>
    );
  }
  return (
    <section className="screen browse scope-editor">
      <Breadcrumb crumbs={[{ label: copy.scopes.title, axis: 'scopes' }]} current={copy.scopes.editTitle} />
      <h1 tabIndex={-1}>{copy.scopes.editTitle}</h1>
      {!scope ? (
        <p role="status">{copy.browse.loading}</p>
      ) : (
        <>
          <h2>{copy.scopes.nameHeader}</h2>
          <div className="name-row">
            <input
              ref={nameField}
              type="text"
              value={shownName}
              aria-label={copy.scopes.nameHeader}
              placeholder={copy.scopes.namePrompt}
              onChange={(event) => setName(event.target.value)}
              onBlur={commitName}
              onKeyDown={(event) => {
                if (event.key === 'Enter') commitName();
              }}
            />
            {shownName !== '' && (
              <button
                type="button"
                aria-label={copy.scopes.clearName}
                onClick={() => {
                  setName('');
                  edit({ name: '' });
                  nameField.current?.focus();
                }}
              >
                ×
              </button>
            )}
          </div>
          <h2>{copy.scopes.volumesHeader(shownMembers.length)}</h2>
          <ul className="scope-members">
            {shownMembers.map((volumeId, index) => {
              const volume = catalogue.get(volumeId);
              return (
                <li key={volumeId}>
                  <button type="button" className="remove" aria-label={copy.scopes.remove(volumeId)} onClick={() => remove(volumeId, index)}>
                    −
                  </button>{' '}
                  {volume ? (
                    <span>
                      {volume.title}
                      <span className="meta">
                        {' '}
                        {volume.volumeId}
                        {volume.publicationDate && <> · {volume.publicationDate.slice(0, 4)}</>}
                      </span>
                    </span>
                  ) : (
                    <span>
                      {volumeId} <span className="meta warning">{copy.scopes.unresolved}</span>
                    </span>
                  )}
                </li>
              );
            })}
          </ul>
          <button ref={addButton} type="button" title={copy.scopes.addVolumesHelp} onClick={() => setPicking(true)}>
            {copy.scopes.addVolumes}
          </button>
          <p className="note">{copy.scopes.editorFooter}</p>
          {failure && (
            <p className="error" role="alert">
              {failure}
            </p>
          )}
          <div className="actions">
            <button ref={deleteButton} type="button" className="destructive" onClick={() => setDeleting(true)}>
              {copy.scopes.delete}
            </button>
            <button
              type="button"
              onClick={() => {
                commitName();
                void navigate({ to: '/browse/scopes' });
              }}
            >
              {copy.scopes.done}
            </button>
          </div>
          {picking && (
            <VolumePicker
              volumes={volumes.data?.items ?? []}
              chosen={shownMembers}
              onDone={(chosen) => {
                if (chosen) setVolumes(chosen);
              }}
              onClose={() => {
                setPicking(false);
                addButton.current?.focus();
              }}
            />
          )}
          {deleting && (
            <DeleteScopeDialog
              scope={scope}
              onClose={(deleted) => {
                setDeleting(false);
                if (deleted) void navigate({ to: '/browse/scopes' });
                else deleteButton.current?.focus();
              }}
            />
          )}
        </>
      )}
    </section>
  );
}

/**
 * Add Volumes…: the All Volumes catalogue in picker mode, its selection seeded from the scope's members,
 * narrowed by title or volume number; Done applies the selection as one sorted reassignment.
 */
function VolumePicker({
  volumes,
  chosen,
  onDone,
  onClose,
}: {
  volumes: Volume[];
  chosen: string[];
  onDone: (chosen: string[] | null) => void;
  onClose: () => void;
}) {
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const [selection, setSelection] = useState(() => new Set(chosen));
  const [text, setText] = useState('');
  const shown = volumes.filter((volume) => matchesFilter(volume, text));
  function close() {
    body.current?.closest('dialog')?.close();
  }
  return (
    <Modal className="volume-picker" labelledBy={headingId} initial={field} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.scopes.pickerTitle}
        </h2>
        <label>
          {copy.browse.filter}{' '}
          <input ref={field} type="search" value={text} onChange={(event) => setText(event.target.value)} spellCheck={false} />
        </label>
        <ul className="picker-list" aria-label={copy.browse.title}>
          {shown.map((volume) => (
            <li key={volume.volumeId}>
              <label>
                <input
                  type="checkbox"
                  checked={selection.has(volume.volumeId)}
                  onChange={(event) => {
                    const next = new Set(selection);
                    if (event.target.checked) next.add(volume.volumeId);
                    else next.delete(volume.volumeId);
                    setSelection(next);
                  }}
                />{' '}
                {volume.title} <span className="meta">{volume.volumeId}</span>
              </label>
            </li>
          ))}
        </ul>
        <div className="actions">
          <button
            type="button"
            onClick={() => {
              onDone(null);
              close();
            }}
          >
            {copy.scopes.pickerCancel}
          </button>
          <button
            type="button"
            onClick={() => {
              onDone([...selection].sort());
              closeAtOnce(close);
            }}
          >
            {copy.scopes.pickerDone}
          </button>
        </div>
      </div>
    </Modal>
  );
}

function DeleteScopeDialog({ scope, onClose }: { scope: VolumeScope; onClose: (deleted: boolean) => void }) {
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
      await deleteScope(client, scope.id);
      deleted.current = true;
      closeAtOnce(close);
    } catch (error) {
      setFailure(error instanceof ApiError ? error.message : String(error));
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
        {copy.scopes.deleteTitle}
      </h2>
      <p id={messageId}>{copy.scopes.deleteMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" onClick={close}>
          {copy.scopes.deleteCancel}
        </button>
        <button type="button" className="destructive" onClick={() => void remove()}>
          {copy.scopes.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}
