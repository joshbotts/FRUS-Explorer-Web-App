// Add Documents (PLAN's S18d), the app's `CollectionAddDocumentsSheet`: its four tabs, Search, Browse, and since
// PLAN's S25d Citations and Tags, with one selection across them, in the order chosen, which Add puts at the end
// of the collection; a document the collection holds shows In collection and can be chosen again, as the app's
// can. Resolve chooses at once the lines that resolved, and a tag opened its documents, each passing over what
// the reader unchose in this sheet, as the app's `preselect(_:)` does; an ambiguous line waits for the reader.
// The paste and its lines stay while the sheet is open, as the app's sheet keeps them across its tabs.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useEffect, useId, useRef, useState } from 'react';
import { type CitationLine, discoveryTagsQuery, resolveCitations, tagDocumentsQuery, type TaggedDocument } from '../api/addDocuments';
import { addDocuments, type CollectionDetail, type DocumentRef } from '../api/collections';
import { errorMessage } from '../api/client';
import { readingOrderQuery, searchQuery, volumesQuery } from '../api/endpoints';
import { matchesFilter } from '../browse/CatalogueScreen';
import { copy } from '../copy';
import { validateSearch } from '../search/searchState';
import { closeAtOnce, Modal } from '../shell/Modal';
import { citationCounts, pickLabel, preselected, resolvedDocuments } from './addDocumentsRules';
import { documentKey } from './collectionRules';

/** One document chosen, with what its row shows. */
interface Chosen extends DocumentRef {
  title: string;
  line: string;
}

/** The tabs, in the app's order (`DiscoveryTab.allCases`). */
type Tab = 'search' | 'browse' | 'citations' | 'tags';

/** A row's lines under its caption, a citation's: the line pasted, and the resolver's note, a warning on a line to review. */
interface RowMore {
  source: string;
  note?: string;
  warning: boolean;
}

/** Draws a document's row: its checkbox, its words, and In collection for a document the collection holds. */
type Row = (pick: Chosen, extra?: string, more?: RowMore, rowKey?: string) => ReactNode;

/** The Citations tab's paste and its lines, kept while the sheet is open. */
interface Citations {
  text: string;
  /** The lines the last Resolve gave; null before one. */
  lines: CitationLine[] | null;
  resolving: boolean;
  failure: string | null;
}

/** A document the Citations or the Tags tab offers, as a choice with its row's words. */
function choice(document: TaggedDocument): Chosen {
  return { volumeId: document.volumeId, documentId: document.documentId, ...pickLabel(document) };
}

export function AddDocuments({ detail, onClose }: { detail: CollectionDetail; onClose: (added?: number) => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const [tab, setTab] = useState<Tab>('search');
  const [picks, setPicks] = useState<Chosen[]>([]);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [citations, setCitations] = useState<Citations>({ text: '', lines: null, resolving: false, failure: null });
  // The keys the reader unchose in this sheet, which a pass that chooses at once passes over, and which choosing
  // one again forgets (`explicitlyDeselectedKeys`).
  const unchosen = useRef(new Set<string>());
  const searchTab = useRef<HTMLButtonElement>(null);
  const held = new Set(detail.entries.filter((entry) => entry.kind === 'document').map((entry) => documentKey(entry.volumeId, entry.documentId)));
  const chosen = new Set(picks.map((pick) => documentKey(pick.volumeId, pick.documentId)));
  const words = copy.addDocuments;

  function toggle(pick: Chosen, on: boolean) {
    const key = documentKey(pick.volumeId, pick.documentId);
    if (on) unchosen.current.delete(key);
    else unchosen.current.add(key);
    setPicks((list) => (on ? (list.some((p) => documentKey(p.volumeId, p.documentId) === key) ? list : [...list, pick]) : list.filter((p) => documentKey(p.volumeId, p.documentId) !== key)));
  }

  /** `preselect(_:)`: chooses `list` at once, but what the reader unchose. */
  function preselect(list: Chosen[]) {
    const skipped = new Set(unchosen.current);
    setPicks((held) => preselected(held, list, skipped));
  }

  /** `resolveCitations()`: each line of the paste, and the lines that resolved chosen at once. */
  async function resolve() {
    const text = citations.text;
    if (citations.resolving || text.trim() === '') return;
    setCitations((state) => ({ ...state, resolving: true, failure: null }));
    try {
      const answer = await resolveCitations(client, text);
      setCitations((state) => ({ ...state, lines: answer.items, resolving: false }));
      preselect(resolvedDocuments(answer.items).map((line) => choice({ ...line, volumeId: line.volumeId ?? '', documentId: line.documentId ?? '' })));
    } catch (error) {
      setCitations((state) => ({ ...state, lines: null, resolving: false, failure: errorMessage(error) }));
    }
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

  const row: Row = (pick, extra, more, rowKey) => {
    const key = documentKey(pick.volumeId, pick.documentId);
    const described = rowKey && more ? [`${rowKey}-source`, more.note ? `${rowKey}-note` : ''].filter(Boolean).join(' ') : undefined;
    return (
      <li key={rowKey ?? key} className="pick-row">
        <label>
          <input type="checkbox" checked={chosen.has(key)} aria-describedby={described} onChange={(event) => toggle(pick, event.target.checked)} />{' '}
          <span className="pick-title">{pick.title}</span>
        </label>
        <p className="meta">
          {pick.line}
          {extra ? ` · ${extra}` : ''}
          {held.has(key) && <span className="badge-line"> · {words.inCollection}</span>}
        </p>
        {more && rowKey && (
          <>
            <p id={`${rowKey}-source`} className="pick-source">
              {more.source}
            </p>
            {more.note && (
              <p id={`${rowKey}-note`} className={more.warning ? 'pick-note warning' : 'pick-note'}>
                {more.note}
              </p>
            )}
          </>
        )}
      </li>
    );
  };

  const tabs: [Tab, string][] = [
    ['search', words.search],
    ['browse', words.browse],
    ['citations', words.citations],
    ['tags', words.tags],
  ];
  return (
    <Modal className="add-documents-sheet" labelledBy={headingId} initial={searchTab} onCancel={() => onClose()} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.title}
      </h2>
      <div className="tabs" role="group" aria-label={words.tabs}>
        {tabs.map(([id, name]) => (
          <button key={id} ref={id === 'search' ? searchTab : undefined} type="button" aria-pressed={tab === id} onClick={() => setTab(id)}>
            {name}
          </button>
        ))}
      </div>
      {tab === 'search' ? (
        <SearchTab row={row} />
      ) : tab === 'browse' ? (
        <BrowseTab row={row} />
      ) : tab === 'citations' ? (
        <CitationsTab state={citations} onText={(text) => setCitations((state) => ({ ...state, text }))} onResolve={() => void resolve()} row={row} />
      ) : (
        <TagsTab row={row} preselect={preselect} />
      )}
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
function SearchTab({ row }: { row: Row }) {
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
function BrowseTab({ row }: { row: Row }) {
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

/**
 * The Citations tab: the paste, Resolve, and a row for every line, as the app's sheet lists them: a line that names a
 * document is a row to choose, with the line under it and the resolver's note, a warning on a line to review; a line
 * that names none says why. A status line says how many resolved and how many are to review.
 */
function CitationsTab({ state, onText, onResolve, row }: { state: Citations; onText: (text: string) => void; onResolve: () => void; row: Row }) {
  const fieldId = useId();
  const rowsId = useId();
  const words = copy.addDocuments;
  const blank = state.text.trim() === '';
  let summary = '';
  if (state.resolving) summary = words.resolving;
  else if (state.lines?.length === 0) summary = words.citationsEmpty;
  else if (state.lines) {
    const counts = citationCounts(state.lines);
    summary = words.resolvedCount(counts.resolved, state.lines.length) + (counts.toReview > 0 ? ` ${words.toReview(counts.toReview)}` : '');
  }
  return (
    <div className="tab-panel">
      <div className="pick-paste">
        <label htmlFor={fieldId} className="visually-hidden">
          {words.citationsPlaceholder}
        </label>
        <textarea id={fieldId} value={state.text} placeholder={words.citationsPlaceholder} rows={5} spellCheck={false} onChange={(event) => onText(event.target.value)} />
        <button type="button" aria-disabled={state.resolving || blank} onClick={onResolve}>
          {words.resolve}
        </button>
      </div>
      <p role="status" className="pick-summary">
        {summary}
      </p>
      {state.failure && (
        <p className="error" role="alert">
          {state.failure}
        </p>
      )}
      {state.lines === null
        ? !state.resolving && !state.failure && <p className="note">{words.citationsHint}</p>
        : state.lines.length > 0 && (
            <ul className="pick-list" aria-label={words.citations}>
              {state.lines.map((line, index) => {
                const rowKey = `${rowsId}${index}`;
                if (line.outcome === 'unresolved' || line.volumeId === undefined || line.documentId === undefined) {
                  return (
                    <li key={rowKey} className="pick-row unresolved">
                      <p className="pick-source">{line.line}</p>
                      <p className="meta">{words.noMatch(line.reason ?? '')}</p>
                    </li>
                  );
                }
                const document = choice({ ...line, volumeId: line.volumeId, documentId: line.documentId });
                return row(document, undefined, { source: line.line, note: line.note, warning: line.outcome === 'ambiguous' }, rowKey);
              })}
            </ul>
          )}
    </div>
  );
}

/**
 * The Tags tab: the reader's tags, each with how many documents it gathers, then a tag's documents, chosen at once
 * as it opens. Focus follows the view a press replaced, as Browse's does.
 */
function TagsTab({ row, preselect }: { row: Row; preselect: (list: Chosen[]) => void }) {
  const tags = useQuery(discoveryTagsQuery);
  const [tagId, setTagId] = useState<string | null>(null);
  const documents = useQuery({ ...tagDocumentsQuery(tagId ?? ''), enabled: tagId !== null });
  const back = useRef<HTMLButtonElement>(null);
  const tagList = useRef<HTMLUListElement>(null);
  // The tag Tags came back from, whose button takes focus again.
  const cameFrom = useRef<string | null>(null);
  useEffect(() => {
    if (tagId) back.current?.focus();
    else if (cameFrom.current) tagList.current?.querySelector<HTMLElement>(`button[data-tag="${CSS.escape(cameFrom.current)}"]`)?.focus();
  }, [tagId]);
  // `openTag(_:)`: a tag's documents, chosen at once, all but what the reader unchose; again on a second visit,
  // which adds nothing the first did not, or the reader unchose.
  const gathered = documents.data;
  useEffect(() => {
    if (gathered && gathered.id === tagId) preselect(gathered.items.map(choice));
    // eslint-disable-next-line react-hooks/exhaustive-deps -- chosen once for each answer, not each time the sheet draws
  }, [gathered]);
  const words = copy.addDocuments;
  const tag = tags.data?.items.find((item) => item.id === tagId);
  if (tagId) {
    return (
      <div className="tab-panel">
        <button
          ref={back}
          type="button"
          onClick={() => {
            cameFrom.current = tagId;
            setTagId(null);
          }}
        >
          {words.tagsBack}
        </button>
        <h3>{tag?.name ?? gathered?.name}</h3>
        {documents.isError ? (
          <p className="error" role="alert">
            {errorMessage(documents.error)}
          </p>
        ) : !gathered ? (
          <p role="status">{words.loading}</p>
        ) : gathered.items.length === 0 ? (
          <p className="note">{words.tagsEmpty}</p>
        ) : (
          <ul className="pick-list" aria-label={gathered.name}>
            {gathered.items.map((item) => row(choice(item)))}
          </ul>
        )}
      </div>
    );
  }
  return (
    <div className="tab-panel">
      {tags.isError ? (
        <p className="error" role="alert">
          {errorMessage(tags.error)}
        </p>
      ) : !tags.data ? (
        <p role="status">{words.loading}</p>
      ) : tags.data.items.length === 0 ? (
        <p className="note">{words.tagsNone}</p>
      ) : (
        <ul ref={tagList} className="pick-tags" aria-label={words.tags}>
          {tags.data.items.map((item) => (
            <li key={item.id}>
              <button type="button" data-tag={item.id} onClick={() => setTagId(item.id)}>
                <span className="pick-tag-name">{item.name}</span> <span className="meta">{item.count}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
