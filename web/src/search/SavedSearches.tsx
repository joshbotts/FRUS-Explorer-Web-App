// Saved searches (S17e) in Search, as the Mac's window offers them: Save this search, which names the
// search in the Save Search sheet, offering its words (`SaveSearchSheet`), and Saved searches, the sheet
// that lists them newest first (`SavedSearchesView`): a row recalls its search, whose run the server
// stamps from the saved search's own count; each row's watermark is evaluated in turn once the sheet
// opens, so a search that matches more than at its last run carries the NEW capsule and "+N since last
// run"; and a row is renamed or deleted. Each sheet is a modal dialog: Escape is Cancel or Done.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  deleteSavedSearch,
  evaluateFreshness,
  renameSavedSearch,
  saveSearch,
  savedSearchesQuery,
  type SavedSearch,
} from '../api/searchSets';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import type { SearchState } from './searchState';

/** The name a search is saved under: the text without the spaces around it, or none, when Save is off. */
export function savedName(text: string): string | undefined {
  const trimmed = text.replace(/^[ \t]+|[ \t]+$/g, '');
  return trimmed === '' ? undefined : trimmed;
}

/** The Save Search sheet: a name for the search, offered as its words, and Save, off while the name is empty. */
export function SaveSearchDialog({ state, onClose }: { state: SearchState; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const words = state.keywords ?? '';
  const [name, setName] = useState(words.trim());
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  function close() {
    body.current?.closest('dialog')?.close();
  }

  async function save() {
    const saved = savedName(name);
    if (!saved || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await saveSearch(client, saved, state);
      closeAtOnce(close);
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal className="save-search" labelledBy={headingId} initial={field} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.savedSearches.saveTitle}
        </h2>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void save();
          }}
        >
          <label>
            {copy.savedSearches.nameLabel}{' '}
            <input
              ref={field}
              type="text"
              value={name}
              placeholder={copy.savedSearches.namePlaceholder}
              onChange={(event) => setName(event.target.value)}
            />
          </label>
          {words.trim() !== '' && (
            <p className="query">
              <span className="label">{copy.savedSearches.queryLabel}</span> {words}
            </p>
          )}
        </form>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.savedSearches.cancel}
          </button>
          <button type="button" disabled={savedName(name) === undefined || busy} onClick={() => void save()}>
            {copy.savedSearches.saveButton}
          </button>
        </div>
      </div>
    </Modal>
  );
}

/**
 * The Saved Searches sheet. A row's click hands its saved search to `onRecall`, which runs it and
 * stamps the run, and the sheet closes.
 */
export function SavedSearchesDialog({ onRecall, onClose }: { onRecall: (search: SavedSearch) => void; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const body = useRef<HTMLDivElement>(null);
  const searches = useQuery(savedSearchesQuery);
  const items = searches.data?.items;
  // A missing key is no badge: never run, nothing new, or not yet evaluated.
  const [fresh, setFresh] = useState<Record<string, number>>({});
  const [renaming, setRenaming] = useState<{ id: string; text: string } | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  // Each row's watermark, one after another, as the Mac evaluates them: a cold count can take a while,
  // and one request per row at once would contend the index. Stopped when the list changes or the sheet
  // closes. Rows never run are counted by nothing.
  const identity = (items ?? []).map((item) => `${item.id}|${item.lastRunAt ?? ''}|${item.matchCountAtLastRun ?? ''}`).join(',');
  useEffect(() => {
    let stopped = false;
    void (async () => {
      for (const item of items ?? []) {
        if (stopped) return;
        if (item.lastRunAt === undefined) continue;
        try {
          const result = await evaluateFreshness(client, item.id);
          if (stopped) return;
          setFresh((counts) => {
            const next = { ...counts };
            if (result.newResults !== undefined) next[item.id] = result.newResults;
            else delete next[item.id];
            return next;
          });
        } catch {
          // A count that fails shows no badge, as the Mac's does.
        }
      }
    })();
    return () => {
      stopped = true;
    };
    // The identity says when the rows or their watermarks change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [identity]);

  function close() {
    body.current?.closest('dialog')?.close();
  }

  /**
   * Where the focus goes once a row has changed, and only once: back on a row's Rename when its form has
   * gone, or on the heading when a deleted row has left the list.
   */
  const refocus = useRef<{ id: string; deleted: boolean } | null>(null);
  useEffect(() => {
    const target = refocus.current;
    if (target === null) return;
    const row = body.current?.querySelector<HTMLElement>(`[data-rename="${CSS.escape(target.id)}"]`);
    // A deleted row stays until the list is read again.
    if (target.deleted && row) return;
    refocus.current = null;
    (target.deleted ? body.current?.querySelector<HTMLElement>('h2') : row)?.focus();
  }, [renaming, items]);

  function stopRenaming(id: string) {
    refocus.current = { id, deleted: false };
    setRenaming(null);
  }

  async function rename(id: string, name: string) {
    setFailure(null);
    try {
      await renameSavedSearch(client, id, name);
      stopRenaming(id);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  async function remove(id: string) {
    setFailure(null);
    try {
      refocus.current = { id, deleted: true };
      await deleteSavedSearch(client, id);
    } catch (error) {
      refocus.current = null;
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal className="saved-searches" labelledBy={headingId} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.savedSearches.title}
        </h2>
        {searches.isError ? (
          <p className="error" role="alert">
            {errorMessage(searches.error)}
          </p>
        ) : items && items.length === 0 ? (
          <div className="empty">
            <h3>{copy.savedSearches.emptyTitle}</h3>
            <p>{copy.savedSearches.emptyDetail}</p>
          </div>
        ) : (
          <ul className="saved-search-list" aria-label={copy.savedSearches.title}>
            {(items ?? []).map((item) =>
              renaming?.id === item.id ? (
                <li key={item.id}>
                  <form
                    className="rename"
                    onSubmit={(event) => {
                      event.preventDefault();
                      void rename(item.id, renaming.text);
                    }}
                  >
                    <label>
                      {copy.savedSearches.renameTitle}{' '}
                      <input
                        type="text"
                        // A rename is a choice the reader just made: the field takes the focus.
                        autoFocus
                        value={renaming.text}
                        placeholder={copy.savedSearches.renamePlaceholder}
                        onChange={(event) => setRenaming({ id: item.id, text: event.target.value })}
                      />
                    </label>
                    <button type="submit">{copy.savedSearches.renameSave}</button>
                    <button type="button" onClick={() => stopRenaming(item.id)}>
                      {copy.savedSearches.renameCancel}
                    </button>
                  </form>
                </li>
              ) : (
                <li key={item.id}>
                  <button
                    type="button"
                    className="recall"
                    onClick={() => {
                      onRecall(item);
                      close();
                    }}
                  >
                    <span className="name">
                      {item.name}
                      {item.id in fresh && <span className="new-badge">{copy.savedSearches.newBadge}</span>}
                    </span>
                    {item.queryText !== '' && <span className="caption">{item.queryText}</span>}
                    {/* The count is exact, which is what licenses printing a number rather than a vague "new results". */}
                    {item.id in fresh && <span className="fresh">{copy.savedSearches.fresh(fresh[item.id] ?? 0)}</span>}
                    {item.notRecalled.length > 0 && (
                      <span className="caption">
                        {copy.savedSearches.notRecalled(item.notRecalled.map((name) => copy.savedSearches.notRecalledNames[name] ?? name))}
                      </span>
                    )}
                  </button>
                  <div className="row-actions">
                    <button
                      type="button"
                      data-rename={item.id}
                      aria-label={`${copy.savedSearches.rename} ${item.name}`}
                      onClick={() => setRenaming({ id: item.id, text: item.name })}
                    >
                      {copy.savedSearches.rename}
                    </button>
                    <button
                      type="button"
                      className="destructive"
                      aria-label={`${copy.savedSearches.delete} ${item.name}`}
                      onClick={() => void remove(item.id)}
                    >
                      {copy.savedSearches.delete}
                    </button>
                  </div>
                </li>
              ),
            )}
          </ul>
        )}
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.savedSearches.done}
          </button>
        </div>
      </div>
    </Modal>
  );
}
