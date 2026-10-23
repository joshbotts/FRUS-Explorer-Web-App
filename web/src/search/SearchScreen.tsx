// Search (SPEC, Search): the query box with the app's query language, the filters, the Query
// Inspector's strip, and a page of results in the order chosen, with the exact count and what it
// was counted over, beside the facet panel when it is open. A result is named as the Mac's search
// window names it, with the document's label beside its volume unless the title already opens with
// its number. A facet's narrowing shows as a filter token, and a search that found nothing names
// the term responsible, as the Mac's do.
import { useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type FormEvent, type ReactNode, type RefObject, useId, useRef, useState } from 'react';
import { ApiError } from '../api/client';
import { inspectQuery, searchQuery, volumesQuery } from '../api/endpoints';
import type { DocumentType, SearchResultList, SortOrder, Volume } from '../api/types';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';
import { FacetPanel, useFacetPanelState } from './FacetPanel';
import { inspectorFields, QueryInspectorStrip, ZeroResult } from './QueryInspector';
import {
  defaultLimit,
  documentTypes,
  filterFields,
  isPartialEvidence,
  pageCount,
  pageSizes,
  retainedLimit,
  type SearchState,
} from './searchState';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { Snippet } from './Snippet';

const route = getRouteApi('/search');

export function SearchScreen() {
  const state = route.useSearch();
  const navigate = route.useNavigate();
  const results = useQuery(searchQuery(state));
  const volumes = useQuery(volumesQuery);
  const queryClient = useQueryClient();

  /** A new search, or a changed filter, starts at the first page. */
  function update(changes: Partial<SearchState>) {
    void navigate({ search: (previous: SearchState) => ({ ...previous, ...changes, offset: undefined }) });
  }

  // What a facet narrowed from, so the count can say it while the panel is open, as the Mac's does:
  // the figure exists only at the moment of the click, and belongs to the search the click made.
  const panelOpen = state.panel === 'facets';
  const signature = JSON.stringify(filterFields(state));
  const [narrowed, setNarrowed] = useState<{ signature: string; from: number } | null>(null);
  // The panel's sections keep their sort and page size while it is closed, as the Mac's do.
  const facetPanel = useFacetPanelState(state);
  // While the search shown is still the last one's, its count describes that one.
  const shown = results.isPlaceholderData ? undefined : results.data;

  function search(keywords: string) {
    // The same search again leaves the URL as it is, so it asks the server again itself: after a
    // refusal or a server fault, or once an index is ready. So does the account of a search that
    // found nothing.
    if (keywords === state.keywords && state.offset === undefined) {
      void queryClient.refetchQueries({ queryKey: searchQuery(state).queryKey, exact: true });
      void queryClient.refetchQueries({
        queryKey: inspectQuery(inspectorFields(state, keywords), { emptyConjuncts: true }).queryKey,
        exact: true,
      });
    } else {
      update({ keywords });
    }
  }

  function narrowTo(next: SearchState) {
    if (results.data) setNarrowed({ signature: JSON.stringify(filterFields(next)), from: results.data.total });
    void navigate({ search: next });
  }

  /** Opens or closes the panel in place of the history entry, so Back leaves the search. */
  function setPanel(open: boolean) {
    void navigate({ search: (previous: SearchState) => ({ ...previous, panel: open ? 'facets' : undefined }), replace: true });
  }

  const titles = new Map((volumes.data?.items ?? []).map((volume: Volume) => [volume.volumeId, volume.title]));
  useDocumentTitle(state.keywords ? `${copy.search.title}: ${state.keywords}` : copy.search.title);

  return (
    <section className="screen search">
      <h1 tabIndex={-1}>{copy.search.title}</h1>
      <SearchEntry state={state} titles={titles} update={update} onSearch={search} />
      {state.keywords !== undefined && (
        <div className={panelOpen ? 'search-body with-facets' : 'search-body'}>
          <Results
            state={state}
            titles={titles}
            results={results}
            // Said only when the narrowing made the match smaller, as the Mac says it.
            narrowedFrom={
              panelOpen && shown && narrowed?.signature === signature && narrowed.from > shown.total ? narrowed.from : undefined
            }
            facets={
              <button
                type="button"
                className="facets-toggle"
                title={panelOpen ? copy.facets.hideHelp : copy.facets.toggleHelp}
                aria-expanded={panelOpen}
                aria-controls={panelOpen ? 'facet-panel' : undefined}
                // Nothing to break down while nothing matches; an open panel can always be closed.
                disabled={!panelOpen && !(results.data && results.data.total > 0)}
                onClick={() => setPanel(!panelOpen)}
              >
                {copy.facets.toggle}
              </button>
            }
          />
          {panelOpen && <FacetPanel state={state} total={shown?.total} panel={facetPanel} onSearch={narrowTo} />}
        </div>
      )}
    </section>
  );
}

/**
 * The search box, the filters and the Query Inspector's strip, which follows the box's text as it is
 * typed, before the search is made. The text is held here rather than by the screen, so a keystroke
 * renders these and not the results or the facet panel.
 */
function SearchEntry({
  state,
  titles,
  update,
  onSearch,
}: {
  state: SearchState;
  titles: Map<string, string>;
  update: (changes: Partial<SearchState>) => void;
  onSearch: (keywords: string) => void;
}) {
  // A filter's token removes itself, so focus goes to the search box rather than nowhere.
  const searchBox = useRef<HTMLInputElement>(null);
  // Going to another search shows its text; the box is not remounted for it, so a search made from
  // it keeps its focus.
  const [text, setText] = useState(state.keywords ?? '');
  const [shownKeywords, setShownKeywords] = useState(state.keywords ?? '');
  if ((state.keywords ?? '') !== shownKeywords) {
    setShownKeywords(state.keywords ?? '');
    setText(state.keywords ?? '');
  }
  // Whether the strip shows its term detail, kept from search to search, as the Mac's window keeps it.
  const [inspectorExpanded, setInspectorExpanded] = useState(false);
  return (
    <>
      <SearchForm inputRef={searchBox} text={text} onTextChange={setText} onSubmit={onSearch} />
      <Filters state={state} titles={titles} update={update} onCleared={() => searchBox.current?.focus()} />
      <QueryInspectorStrip fields={inspectorFields(state, text)} expanded={inspectorExpanded} onExpandedChange={setInspectorExpanded} />
    </>
  );
}

function SearchForm({
  inputRef,
  text,
  onTextChange,
  onSubmit,
}: {
  inputRef: RefObject<HTMLInputElement | null>;
  /** The box's text, which the search entry holds. */
  text: string;
  onTextChange: (text: string) => void;
  onSubmit: (keywords: string) => void;
}) {
  const inputId = useId();

  function submit(event: FormEvent) {
    event.preventDefault();
    onSubmit(text);
  }

  return (
    <form role="search" onSubmit={submit} className="search-form">
      <label htmlFor={inputId}>{copy.search.label}</label>
      <div className="search-row">
        <input
          ref={inputRef}
          id={inputId}
          type="search"
          value={text}
          onChange={(event) => onTextChange(event.target.value)}
          spellCheck={false}
          autoCapitalize="off"
          autoComplete="off"
        />
        <button type="submit">{copy.search.submit}</button>
      </div>
      <details className="syntax">
        <summary>{copy.search.syntax}</summary>
        <p>{copy.search.syntaxBody}</p>
      </details>
    </form>
  );
}

function Filters({
  state,
  titles,
  update,
  onCleared,
}: {
  state: SearchState;
  titles: Map<string, string>;
  update: (changes: Partial<SearchState>) => void;
  /** Called when a chip or a token has cleared its filter, and so removed itself. */
  onCleared: () => void;
}) {
  return (
    <fieldset className="filters">
      <legend>{copy.search.filters}</legend>
      <label>
        {copy.search.documentType}{' '}
        <select
          value={state.documentType ?? 'all'}
          onChange={(event) => {
            const value = event.target.value as DocumentType;
            update({ documentType: value === 'all' ? undefined : value });
          }}
        >
          {documentTypes.map((type) => (
            <option key={type} value={type}>
              {copy.search.documentTypes[type]}
            </option>
          ))}
        </select>
      </label>
      <label>
        {copy.search.dateFrom}{' '}
        <input
          type="date"
          value={state.dateRangeEarliest ?? ''}
          onChange={(event) => update({ dateRangeEarliest: event.target.value || undefined })}
        />
      </label>
      <label>
        {copy.search.dateTo}{' '}
        <input
          type="date"
          value={state.dateRangeLatest ?? ''}
          onChange={(event) => update({ dateRangeLatest: event.target.value || undefined })}
        />
      </label>
      {(state.dateRangeEarliest || state.dateRangeLatest) && <p className="note">{copy.search.dateNote}</p>}
      <label>
        <input
          type="checkbox"
          checked={state.includeFrontMatter !== false}
          onChange={(event) => update({ includeFrontMatter: event.target.checked ? undefined : false })}
        />{' '}
        {copy.search.frontMatter}
      </label>
      {state.volumeIds && state.volumeIds.length > 0 && (
        <div className="chips" role="group" aria-label={copy.search.volumes}>
          {state.volumeIds.map((volumeId) => {
            const title = titles.get(volumeId) ?? volumeId;
            return (
              <button
                key={volumeId}
                type="button"
                className="chip"
                aria-label={copy.search.removeVolume(title)}
                onClick={() => {
                  const remaining = state.volumeIds?.filter((other) => other !== volumeId) ?? [];
                  update({ volumeIds: remaining.length > 0 ? remaining : undefined });
                  onCleared();
                }}
              >
                {title} ×
              </button>
            );
          })}
        </div>
      )}
      {(state.yearKeys || state.personRollupId || state.subjectBucket || state.subjectBucketKey) && (
        <div className="chips" role="group" aria-label={copy.search.narrowedBy}>
          {state.yearKeys && (
            <FilterToken
              field={copy.search.filterFields.years}
              value={copy.search.years(state.yearKeys)}
              onClear={() => {
                update({ yearKeys: undefined });
                onCleared();
              }}
            />
          )}
          {state.personRollupId && (
            <FilterToken
              field={copy.search.filterFields.person}
              value={state.personLabel ?? `#${state.personRollupId}`}
              onClear={() => {
                update({ personRollupId: undefined, personLabel: undefined });
                onCleared();
              }}
            />
          )}
          {(state.subjectBucket || state.subjectBucketKey) && (
            <FilterToken
              field={copy.search.filterFields.subject}
              value={state.subjectLabel ?? state.subjectBucketKey ?? `#${state.subjectBucket}`}
              onClear={() => {
                update({ subjectBucket: undefined, subjectBucketKey: undefined, subjectLabel: undefined });
                onCleared();
              }}
            />
          )}
        </div>
      )}
    </fieldset>
  );
}

/** A filter a facet set, by its field and value, as the Mac's token shows it; a click clears it. */
function FilterToken({ field, value, onClear }: { field: string; value: string; onClear: () => void }) {
  return (
    <button type="button" className="chip" aria-label={`${field} ${value}, ${copy.search.clearThisFilter}`} onClick={onClear}>
      <span className="chip-field">{field}</span> {value} <span aria-hidden="true">×</span>
    </button>
  );
}

function Results({
  state,
  titles,
  results,
  narrowedFrom,
  facets,
}: {
  state: SearchState;
  titles: Map<string, string>;
  results: UseQueryResult<SearchResultList, unknown>;
  /** The count the last facet narrowed from, while the panel shows it. */
  narrowedFrom: number | undefined;
  /** The control that opens the facet panel. */
  facets: ReactNode;
}) {
  // The last page stays on screen while the next loads, so the pager keeps its focus and the
  // count stays one live region.
  const list = results.data;
  const failed = results.isError && !results.isFetching;
  const error = results.error;
  const first = list && list.items.length > 0 ? list.offset + 1 : 0;
  const last = list ? list.offset + list.items.length : 0;
  return (
    <section className="results" aria-labelledby="results-heading" aria-busy={results.isFetching}>
      <h2 id="results-heading" className="visually-hidden">
        {copy.search.results}
      </h2>
      <div className="results-header">
        <p className="count" role="status">
          {failed ? '' : list ? (
            <>
              {copy.search.count(list.total, list.countBasis)}
              {narrowedFrom !== undefined && <> · {copy.search.narrowedFrom(narrowedFrom)}</>}
              {list.items.length > 0 && <> · {copy.search.showing(first, last)}</>} ·{' '}
              {copy.search.coverage(list.coverage.indexedVolumes, list.coverage.manifestVolumes)}
            </>
          ) : (
            copy.search.searching
          )}
        </p>
        {list && !failed && <SortOrders state={state} list={list} />}
        {facets}
      </div>
      {list && !failed && isPartialEvidence(list.total) && (
        // As the Mac's window says it on every page: an order, a page or a reading of what a search
        // keeps is of its most relevant 7,500, not of the whole match.
        <div className="over-cap">
          <p>
            <span className="over-cap-mark" aria-hidden="true">
              ⚠{' '}
            </span>
            {copy.search.overCap(Math.min(list.total, retainedLimit), list.total)}
          </p>
          <p className="caption">{copy.search.overCapGuidance}</p>
        </div>
      )}
      {failed && (
        <p className="error" role="alert">
          {error instanceof ApiError
            ? error.code === 'INDEX_NOT_READY'
              ? copy.search.notReady(error.problem?.detail ?? '')
              : error.message
            : String(error)}
        </p>
      )}
      {list && !failed && (
        <>
          {list.items.length === 0 ? (
            list.total > 0 ? (
              <p>{copy.search.pastEnd}</p>
            ) : results.isPlaceholderData ? null : (state.keywords ?? '').trim() !== '' ? (
              // Only once the search shown is this one, as the Mac's window waits for its search.
              <ZeroResult state={state} />
            ) : (
              <p>{copy.search.none}</p>
            )
          ) : (
            <ol className="result-list" aria-label={copy.search.results} start={first}>
              {list.items.map((item) => (
                <li key={`${item.volumeId}/${item.documentId}`} className="result">
                  <h3>
                    <Link to="/doc/$volumeId/$documentId" params={{ volumeId: item.volumeId, documentId: item.documentId }}>
                      {item.displayTitle}
                    </Link>
                  </h3>
                  <p className="meta">
                    {titles.get(item.volumeId) ?? item.volumeId}
                    {!item.headerRepeatsNumber && <> · {item.documentLabel}</>}
                    {/* Its dateline, or for a row that prints none the day or span the index dates
                        it by, as the Mac's window draws `dateline ?? drawnDate`. */}
                    {(item.dateline ?? item.drawnDate) && <> · {item.dateline ?? item.drawnDate}</>}
                    {item.isEditorialNote && <Badge>{copy.search.editorialNote}</Badge>}
                    {item.isFrontMatter && <Badge>{copy.search.frontMatterBadge}</Badge>}
                  </p>
                  <p className="snippet">
                    <Snippet text={item.snippet} />
                  </p>
                </li>
              ))}
            </ol>
          )}
          <Pager state={state} list={list} />
        </>
      )}
    </section>
  );
}

/**
 * The orders the results can be read in, as the Mac's sort bar offers them, by the kit's labels: a
 * click starts the order at its first page. The pressed order is the reader's choice, which the
 * page on screen follows once it has loaded.
 */
function SortOrders({ state, list }: { state: SearchState; list: SearchResultList }) {
  const navigate = route.useNavigate();
  const labelId = useId();
  const chosen: SortOrder = state.sort ?? 'relevance';
  return (
    <div className="sort-orders" role="group" aria-labelledby={labelId}>
      <span id={labelId}>{copy.search.sort}</span>
      {list.sortChoices.map((choice) => (
        <button
          key={choice.value}
          type="button"
          aria-pressed={choice.value === chosen}
          title={copy.search.sortHelp[choice.value]}
          onClick={() => {
            const sort = choice.value === 'dateAscending' || choice.value === 'dateDescending' ? choice.value : undefined;
            void navigate({ search: (previous: SearchState) => ({ ...previous, sort, offset: undefined }) });
          }}
        >
          {choice.title}
        </button>
      ))}
    </div>
  );
}

function Pager({ state, list }: { state: SearchState; list: SearchResultList }) {
  const navigate = route.useNavigate();
  const limit = state.limit ?? defaultLimit;
  const pages = pageCount(list.total, limit);
  // An offset past the last result, from an edited URL or a changed index, counts as past the
  // last page, and Previous goes to the last page.
  const page = Math.floor(list.offset / limit) + 1;
  const go = (offset: number) =>
    void navigate({ search: (previous: SearchState) => ({ ...previous, offset: offset > 0 ? offset : undefined }) });
  return (
    <nav className="pager" aria-label={copy.search.pages}>
      <button type="button" disabled={page <= 1} onClick={() => go(Math.min(list.offset - limit, (pages - 1) * limit))}>
        {copy.search.previous}
      </button>
      <span aria-current="page">{page <= pages ? copy.search.page(page, pages) : copy.search.pageCount(pages)}</span>
      <button type="button" disabled={page >= pages} onClick={() => go(list.offset + limit)}>
        {copy.search.next}
      </button>
      <label>
        {copy.search.pageSize}{' '}
        <select
          value={limit}
          onChange={(event) => {
            const next = Number(event.target.value);
            void navigate({
              search: (previous: SearchState) => ({ ...previous, limit: next === defaultLimit ? undefined : next, offset: undefined }),
            });
          }}
        >
          {pageSizes.map((size) => (
            <option key={size} value={size}>
              {size}
            </option>
          ))}
        </select>
      </label>
    </nav>
  );
}
