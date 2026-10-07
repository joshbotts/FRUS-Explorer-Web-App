// Search (SPEC, Search): the query box with the app's query language, the first filters, and a
// page of results by relevance, with the exact count and what it was counted over.
import { useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type FormEvent, useId, useState } from 'react';
import { ApiError } from '../api/client';
import { searchQuery, volumesQuery } from '../api/endpoints';
import type { DocumentType, SearchResultList, Volume } from '../api/types';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';
import { defaultLimit, documentTypes, pageCount, pageSizes, retainedLimit, type SearchState } from './searchState';
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

  const titles = new Map((volumes.data?.items ?? []).map((volume: Volume) => [volume.volumeId, volume.title]));
  useDocumentTitle(state.keywords ? `${copy.search.title}: ${state.keywords}` : copy.search.title);

  return (
    <section className="screen search">
      <h1 tabIndex={-1}>{copy.search.title}</h1>
      <SearchForm
        keywords={state.keywords ?? ''}
        onSubmit={(keywords) => {
          // The same search again leaves the URL as it is, so it asks the server again itself:
          // after a refusal or a server fault, or once an index is ready.
          if (keywords === state.keywords && state.offset === undefined) {
            void queryClient.refetchQueries({ queryKey: searchQuery(state).queryKey, exact: true });
          } else {
            update({ keywords });
          }
        }}
      />
      <Filters state={state} titles={titles} update={update} />
      {state.keywords !== undefined && <Results state={state} titles={titles} results={results} />}
    </section>
  );
}

function SearchForm({ keywords, onSubmit }: { keywords: string; onSubmit: (keywords: string) => void }) {
  const [text, setText] = useState(keywords);
  // Going back to another search shows its text. The box is not remounted for it, so a search
  // made from it keeps its focus.
  const [shown, setShown] = useState(keywords);
  if (keywords !== shown) {
    setShown(keywords);
    setText(keywords);
  }
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
          id={inputId}
          type="search"
          value={text}
          onChange={(event) => setText(event.target.value)}
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
}: {
  state: SearchState;
  titles: Map<string, string>;
  update: (changes: Partial<SearchState>) => void;
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
                }}
              >
                {title} ×
              </button>
            );
          })}
        </div>
      )}
    </fieldset>
  );
}

function Results({
  state,
  titles,
  results,
}: {
  state: SearchState;
  titles: Map<string, string>;
  results: UseQueryResult<SearchResultList, unknown>;
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
      <p className="count" role="status">
        {failed ? '' : list ? (
          <>
            {copy.search.count(list.total, list.countBasis)}
            {list.items.length > 0 && <> · {copy.search.showing(first, last)}</>} ·{' '}
            {copy.search.coverage(list.coverage.indexedVolumes, list.coverage.manifestVolumes)}
          </>
        ) : (
          copy.search.searching
        )}
      </p>
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
            <p>{list.total > 0 ? copy.search.pastEnd : copy.search.none}</p>
          ) : (
            <ol className="result-list" aria-label={copy.search.results} start={first}>
              {list.items.map((item) => (
                <li key={`${item.volumeId}/${item.documentId}`} className="result">
                  <h3>
                    <Link to="/doc/$volumeId/$documentId" params={{ volumeId: item.volumeId, documentId: item.documentId }}>
                      {item.header}
                    </Link>
                  </h3>
                  <p className="meta">
                    {titles.get(item.volumeId) ?? item.volumeId}
                    {item.dateline && <> · {item.dateline}</>}
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
      {list.total > retainedLimit && page >= pages && <p className="note">{copy.search.retained}</p>}
    </nav>
  );
}
