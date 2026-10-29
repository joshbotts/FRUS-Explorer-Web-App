// The Add to Collection picker (PLAN's S18d), the app's `CollectionPickerSheet` in its two modes: a
// document, which a collection holding it among its documents takes no second time, and an excerpt of
// the reader's selection, frozen from the page the frame holds. Its collections are listed in the
// order it opened with, the most recently changed first, any made since ahead of them; its search
// finds a collection by the name its row prints; a smart collection is listed, saying what it is, and
// takes nothing; New Collection makes one, which the list then offers; and a choice shows Added, and
// the picker closes a moment after, as the app's does.
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
import { NewCollection } from './CollectionsScreen';

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
  const [added, setAdded] = useState<string | null>(null);
  const [making, setMaking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const words = copy.collections;
  if (order === null && collections.data) setOrder(collections.data.items.map((item) => item.id));
  const listed = heldOrder(collections.data?.items ?? [], order);
  const shown = search === '' ? listed : listed.filter((item) => listNameMatches(item.listName, search));
  const closing = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(closing.current), []);

  async function choose(id: string) {
    // One add to a presentation: the picker closes a moment after it.
    if (added) return;
    setFailure(null);
    try {
      let pause = addedPause;
      if (excerpt) await addExcerpts(client, id, excerpt);
      else if (!(await addDocumentToCollection(client, id, document)).added) pause = heldPause;
      setAdded(id);
      closing.current = setTimeout(() => closeAtOnce(onClose), pause);
    } catch (error) {
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
                    {added === item.id && <span className="added">{words.pickerAdded}</span>}
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
