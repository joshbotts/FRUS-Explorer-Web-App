// Add Documents (PLAN's S18d), the app's `CollectionAddDocumentsSheet` with its Search and Browse tabs
// and one selection across them, in the order chosen, which Add puts at the end of the collection; a
// document the collection holds shows In collection and can be chosen again, as the app's can. Its
// Citations and Tags tabs wait for the kit's line resolver and tag union, internal to it at the pin.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useEffect, useId, useRef, useState } from 'react';
import { addDocuments, type CollectionDetail, type DocumentRef } from '../api/collections';
import { errorMessage } from '../api/client';
import { readingOrderQuery, searchQuery, volumesQuery } from '../api/endpoints';
import { matchesFilter } from '../browse/CatalogueScreen';
import { copy } from '../copy';
import { validateSearch } from '../search/searchState';
import { closeAtOnce, Modal } from '../shell/Modal';
import { documentKey } from './collectionRules';

/** One document chosen, with what its row shows. */
interface Chosen extends DocumentRef {
  title: string;
  line: string;
}

export function AddDocuments({ detail, onClose }: { detail: CollectionDetail; onClose: (added?: number) => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const [tab, setTab] = useState<'search' | 'browse'>('search');
  const [picks, setPicks] = useState<Chosen[]>([]);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const searchTab = useRef<HTMLButtonElement>(null);
  const held = new Set(detail.entries.filter((entry) => entry.kind === 'document').map((entry) => documentKey(entry.volumeId, entry.documentId)));
  const chosen = new Set(picks.map((pick) => documentKey(pick.volumeId, pick.documentId)));
  const words = copy.addDocuments;

  function toggle(pick: Chosen, on: boolean) {
    const key = documentKey(pick.volumeId, pick.documentId);
    setPicks((list) => (on ? (list.some((p) => documentKey(p.volumeId, p.documentId) === key) ? list : [...list, pick]) : list.filter((p) => documentKey(p.volumeId, p.documentId) !== key)));
  }

  async function add() {
    if (picks.length === 0 || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await addDocuments(client, detail.id, picks.map(({ volumeId, documentId }) => ({ volumeId, documentId })));
      closeAtOnce(() => onClose(picks.length));
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  const row = (pick: Chosen, extra?: string) => {
    const key = documentKey(pick.volumeId, pick.documentId);
    return (
      <li key={key} className="pick-row">
        <label>
          <input type="checkbox" checked={chosen.has(key)} onChange={(event) => toggle(pick, event.target.checked)} />{' '}
          <span className="pick-title">{pick.title}</span>
        </label>
        <p className="meta">
          {pick.line}
          {extra ? ` · ${extra}` : ''}
          {held.has(key) && <span className="badge-line"> · {words.inCollection}</span>}
        </p>
      </li>
    );
  };

  return (
    <Modal className="add-documents-sheet" labelledBy={headingId} initial={searchTab} onCancel={() => onClose()} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.title}
      </h2>
      <div className="tabs" role="group" aria-label={words.tabs}>
        <button ref={searchTab} type="button" aria-pressed={tab === 'search'} onClick={() => setTab('search')}>
          {words.search}
        </button>
        <button type="button" aria-pressed={tab === 'browse'} onClick={() => setTab('browse')}>
          {words.browse}
        </button>
      </div>
      {tab === 'search' ? <SearchTab row={row} /> : <BrowseTab row={row} />}
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="dialog-actions">
        <button type="button" onClick={() => onClose()}>
          {words.cancel}
        </button>
        <button type="button" className="primary" aria-disabled={picks.length === 0 || busy} onClick={() => void add()}>
          {words.add(picks.length)}
        </button>
      </div>
    </Modal>
  );
}

/** The Search tab: a keyword search of the served index, its rows the results'. */
function SearchTab({ row }: { row: (pick: Chosen, extra?: string) => ReactNode }) {
  const fieldId = useId();
  const [text, setText] = useState('');
  const [keywords, setKeywords] = useState<string | null>(null);
  const results = useQuery({ ...searchQuery(validateSearch({ keywords: keywords ?? '' })), enabled: keywords !== null && keywords !== '' });
  const words = copy.addDocuments;
  return (
    <div className="tab-panel">
      <form
        className="pick-search"
        role="search"
        onSubmit={(event) => {
          event.preventDefault();
          setKeywords(text.trim());
        }}
      >
        <label htmlFor={fieldId} className="visually-hidden">
          {words.searchPlaceholder}
        </label>
        <input id={fieldId} type="search" value={text} placeholder={words.searchPlaceholder} onChange={(event) => setText(event.target.value)} />
        <button type="submit">{words.search}</button>
      </form>
      {keywords === null || keywords === '' ? (
        <p className="note">{words.searchHint}</p>
      ) : results.isError ? (
        <p className="error" role="alert">
          {errorMessage(results.error)}
        </p>
      ) : !results.data ? (
        <p role="status">{words.loading}</p>
      ) : results.data.items.length === 0 ? (
        <p>{words.noResults}</p>
      ) : (
        <ul className="pick-list" aria-label={words.search}>
          {results.data.items.map((item) =>
            row(
              {
                volumeId: item.volumeId,
                documentId: item.documentId,
                title: item.displayTitle,
                line: [item.volumeId, item.dateISO].filter(Boolean).join(' · '),
              },
              item.isEditorialNote ? words.editorialNote : undefined,
            ),
          )}
        </ul>
      )}
    </div>
  );
}

/** The Browse tab: the catalogue's volumes, filtered by title or id, then a volume's indexed documents in its reading order. */
function BrowseTab({ row }: { row: (pick: Chosen, extra?: string) => ReactNode }) {
  const fieldId = useId();
  const volumes = useQuery(volumesQuery);
  const [filter, setFilter] = useState('');
  const [volumeId, setVolumeId] = useState<string | null>(null);
  const back = useRef<HTMLButtonElement>(null);
  const volumeList = useRef<HTMLUListElement>(null);
  // The volume Volumes came back from, whose button takes focus again.
  const cameFrom = useRef<string | null>(null);
  // Focus follows the view a press replaced: into a volume, its Volumes; back, the volume left.
  useEffect(() => {
    if (volumeId) back.current?.focus();
    else if (cameFrom.current) volumeList.current?.querySelector<HTMLElement>(`button[data-volume="${CSS.escape(cameFrom.current)}"]`)?.focus();
  }, [volumeId]);
  const words = copy.addDocuments;
  const volume = volumes.data?.items.find((item) => item.volumeId === volumeId);
  const documents = useQuery({ ...readingOrderQuery(volumeId ?? ''), enabled: volumeId !== null && volume?.indexed === true });
  if (volumeId && volume) {
    return (
      <div className="tab-panel">
        <button
          ref={back}
          type="button"
          onClick={() => {
            cameFrom.current = volumeId;
            setVolumeId(null);
          }}
        >
          {words.back}
        </button>
        <h3>{volume.title}</h3>
        {!volume.indexed ? (
          <p className="note">{words.notIndexed}</p>
        ) : documents.isError ? (
          <p className="error" role="alert">
            {errorMessage(documents.error)}
          </p>
        ) : !documents.data ? (
          <p role="status">{words.loading}</p>
        ) : (
          <ul className="pick-list" aria-label={volume.title}>
            {documents.data.items.map((item) =>
              row({ volumeId: item.volumeId, documentId: item.documentId, title: item.displayTitle, line: [item.documentId, item.dateISO].filter(Boolean).join(' · ') }),
            )}
          </ul>
        )}
      </div>
    );
  }
  const listed = (volumes.data?.items ?? []).filter((item) => matchesFilter(item, filter)).slice(0, 200);
  return (
    <div className="tab-panel">
      <label htmlFor={fieldId} className="visually-hidden">
        {words.filter}
      </label>
      <input id={fieldId} type="search" value={filter} placeholder={words.filter} onChange={(event) => setFilter(event.target.value)} />
      {volumes.isError ? (
        <p className="error" role="alert">
          {errorMessage(volumes.error)}
        </p>
      ) : !volumes.data ? (
        <p role="status">{words.loading}</p>
      ) : (
        <ul ref={volumeList} className="pick-volumes" aria-label={words.browse}>
          {listed.map((item) => (
            <li key={item.volumeId}>
              <button type="button" data-volume={item.volumeId} onClick={() => setVolumeId(item.volumeId)}>
                {item.title}
              </button>
              <span className="meta"> {item.volumeId}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
