// The Add to Collection picker (PLAN's S18d), the app's `CollectionPickerSheet` in its two modes: a
// document, which a collection holding it among its documents takes no second time, and an excerpt of
// the reader's selection, frozen from the page the frame holds. Its collections are listed in the
// order it opened with, the most recently changed first, any made since ahead of them; its search
// finds a collection by the name its row prints; a smart collection is listed, saying what it is, and
// takes nothing; New Collection makes one, which the list then offers; and a choice shows Added, or
// Already here for a document the collection held, says which aloud, and the picker closes a moment
// after, as the app's does since FRUS-Explorer#1941 (L19).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  addDocumentToCollection,
  addExcerpts,
  collectionsQuery,
  createCollection,
  type DocumentRef,
} from '../api/collections';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { heldOrder, listNameMatches, pickerTakesEntries } from './collectionRules';
import { NewCollection, useStillOpen } from './CollectionsScreen';

/** How long the picker shows Added before it closes, as the app's waits (0.6 s, 0.8 s for one it held). */
export const addedPause = 600;
export const heldPause = 800;

export interface ExcerptCapture extends DocumentRef {
  startOffset: number;
  endOffset: number;
  renderingVersion: string;
}

export function CollectionPicker({
  document,
  excerpt,
  onClose,
}: {
  document: DocumentRef;
  /** The selection to freeze, in excerpt mode. */
  excerpt?: ExcerptCapture;
  onClose: () => void;
}) {
  const client = useQueryClient();
  const headingId = useId();
  const searchId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const collections = useQuery(collectionsQuery);
  const [order, setOrder] = useState<string[] | null>(null);
  const [search, setSearch] = useState('');
  /** The collection chosen, and whether it already held the document (`CollectionPickerOutcome`). */
  const [added, setAdded] = useState<{ id: string; held: boolean } | null>(null);
  const [making, setMaking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const words = copy.collections;
  if (order === null && collections.data) setOrder(collections.data.items.map((item) => item.id));
  const listed = heldOrder(collections.data?.items ?? [], order);
  const shown = search === '' ? listed : listed.filter((item) => listNameMatches(item.listName, search));
  const closing = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(closing.current), []);
  const stillOpen = useStillOpen();
  // Set at the press, as the app sets its added collection at once, so a second press adds nothing.
  const choosing = useRef(false);

  /** The name a choice is announced by, its row's (`CollectionEditorNaming.listName`). */
  function announcedName(id: string): string {
    return collections.data?.items.find((item) => item.id === id)?.listName ?? '';
  }

  async function choose(id: string) {
    // One add to a presentation: the picker closes a moment after it.
    if (choosing.current) return;
    choosing.current = true;
    setFailure(null);
    try {
      let held = false;
      if (excerpt) await addExcerpts(client, id, excerpt);
      else held = !(await addDocumentToCollection(client, id, document)).added;
      // An add answered after Cancel or Escape stands, and leaves the screen alone: a close set once the
      // picker had gone would never be cleared, and would close a picker opened since.
      if (!stillOpen.current) return;
      setAdded({ id, held });
      closing.current = setTimeout(() => closeAtOnce(onClose), held ? heldPause : addedPause);
    } catch (error) {
      if (!stillOpen.current) return;
      choosing.current = false;
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal className="collection-picker" labelledBy={headingId} initial={cancel} onCancel={onClose} onClose={() => {}}>
      <div className="dialog-header">
        <h2 id={headingId} tabIndex={-1}>
          {excerpt ? words.pickerTitleExcerpt : words.pickerTitle}
        </h2>
        <button type="button" title={words.pickerNewHelp} onClick={() => setMaking(true)}>
          {words.pickerNew}
        </button>
      </div>
      {collections.isError ? (
        <p className="error" role="alert">
          {errorMessage(collections.error)}
        </p>
      ) : !collections.data ? (
        <p role="status">{words.loading}</p>
      ) : collections.data.items.length === 0 ? (
        <div className="empty">
          <h3>{words.pickerEmpty}</h3>
          <p>{words.pickerEmptyHint}</p>
        </div>
      ) : (
        <>
          <label htmlFor={searchId} className="visually-hidden">
            {words.pickerSearch}
          </label>
          <input id={searchId} type="search" value={search} placeholder={words.pickerSearch} onChange={(event) => setSearch(event.target.value)} />
          {shown.length === 0 ? (
            <p>{words.pickerNoResults(search)}</p>
          ) : (
            <ul className="picker-list" aria-label={words.title}>
              {shown.map((item) => (
                <li key={item.id}>
                  <button
                    type="button"
                    className="picker-row"
                    // aria-disabled, so a smart collection is read with its sentence and takes no choice.
                    aria-disabled={!pickerTakesEntries(item) || undefined}
                    onClick={() => pickerTakesEntries(item) && void choose(item.id)}
                  >
                    <span className="picker-name">{item.listName}</span>
                    <span className="meta">{item.isSmart ? words.smartSentence : words.documentCount(item.documentCount)}</span>
                    {added?.id === item.id &&
                      (added.held ? (
                        <span className="added held">
                          <span aria-hidden="true">{words.pickerAlreadyIn}</span>
                          <span className="visually-hidden">{words.pickerAlreadyInLabel}</span>
                        </span>
                      ) : (
                        <span className="added">{words.pickerAdded}</span>
                      ))}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
      {failure && (
        <div role="alert">
          <p className="error-title">{words.addFailedTitle}</p>
          <p className="error">{failure}</p>
        </div>
      )}
      {/* Said at once, as the app posts it at high priority (`TransientToast.announcement`), which the sheet's
          closing does not cut off: a polite region, gone with the picker 0.6 s later, could leave the tap unsaid. */}
      <p role="alert" className="visually-hidden">
        {added ? (added.held ? words.pickerAnnounceAlreadyIn : words.pickerAnnounceAdded)(announcedName(added.id)) : ''}
      </p>
      <div className="dialog-actions">
        <button ref={cancel} type="button" onClick={onClose}>
          {words.pickerCancel}
        </button>
      </div>
      {making && (
        <NewCollection
          onCreate={async (name) => (await createCollection(client, name)).id}
          onClose={() => {
            setMaking(false);
            requestAnimationFrame(() => cancel.current?.focus());
          }}
        />
      )}
    </Modal>
  );
}
