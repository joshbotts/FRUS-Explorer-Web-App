// Archival Neighbors (PLAN's S22d), at /archival-neighbors: the app's `ArchivalNeighborsSheet`, the documents
// drawn from the same archival source as a document, a volume's Sources row, a collection or a central-file
// class. The title over the kit's line naming the source; the picker, This volume, This subseries where the
// volume's subseries has another volume, and All volumes, offered where the list is anchored on a volume, and
// set to All volumes for a document and to This volume for a Sources row; then the list, at most thirty rows,
// each the document's head or id, its volume and dateline, and the line for more than it shows. The query, the
// order, the cut and the line are the kit's, on the server. The web's own: the scope is in the address, and the
// way back.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { getRouteApi, Link, useCanGoBack, useRouter } from '@tanstack/react-router';
import { useId } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { archivalNeighboursQuery, type NeighbourScope, type NeighboursRequest } from '../api/sources';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';

const route = getRouteApi('/archival-neighbors');
const words = copy.archivalNeighbors;

export type NeighboursSearch = NeighboursRequest;

export function NeighboursScreen() {
  const request = route.useSearch();
  const navigate = route.useNavigate();
  const router = useRouter();
  const canGoBack = useCanGoBack();
  const scopeName = useId();
  // The list on show stays while another scope's is asked for, so the picker keeps its place and its focus.
  const neighbours = useQuery({ ...archivalNeighboursQuery(request), placeholderData: keepPreviousData });
  useDocumentTitle(words.title);
  useHeadingReady(!neighbours.isPending);
  const preparing = neighbours.isError && neighbours.error instanceof ApiError && neighbours.error.code === 'INDEX_NOT_READY';
  const data = neighbours.data;
  const scope: NeighbourScope = request.scope ?? data?.scope ?? 'all';

  return (
    <div className="neighbours">
      <p className="back">
        {request.volumeId && request.documentId ? (
          <Link to="/sources/$volumeId/$documentId" params={{ volumeId: request.volumeId, documentId: request.documentId }}>
            <span aria-hidden="true">← </span>
            {words.backToSources}
          </Link>
        ) : request.collection ? (
          <Link to="/archival-collection" search={{ id: request.collection }}>
            <span aria-hidden="true">← </span>
            {words.backToCollection}
          </Link>
        ) : canGoBack ? (
          <button type="button" className="link-button" onClick={() => router.history.back()}>
            <span aria-hidden="true">← </span>
            {words.back}
          </button>
        ) : null}
      </p>
      <h1 tabIndex={-1} data-loading={neighbours.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {data?.basis && <p className="neighbours-basis">{data.basis}</p>}
      {data && data.scopes.length > 1 && (
        <fieldset className="pane-picker">
          <legend className="visually-hidden">{words.scope}</legend>
          {data.scopes.map((each) => (
            <label key={each}>
              <input
                type="radio"
                name={scopeName}
                checked={scope === each}
                onChange={() => void navigate({ search: (previous: NeighboursSearch) => ({ ...previous, scope: each }), replace: true })}
              />
              <span>{words.scopes[each]}</span>
            </label>
          ))}
        </fieldset>
      )}
      <p className="note" role="status">
        {preparing ? words.preparing : neighbours.isFetching ? words.loading : ''}
      </p>
      {neighbours.isError && !preparing && (
        <p className="error" role="alert">
          {errorMessage(neighbours.error)}
        </p>
      )}
      {data && (
        <div aria-busy={neighbours.isPlaceholderData}>
          {data.documents.length === 0 ? (
            <div className="neighbours-empty">
              <h2>{words.empty}</h2>
              <p>{data.scope === 'all' ? words.emptyDetail : words.emptyDetailScoped}</p>
            </div>
          ) : (
            <>
              <ol className="neighbours-list">
                {data.documents.map((document) => (
                  <li key={`${document.volumeId}/${document.documentId}`}>
                    <Link to="/doc/$volumeId/$documentId" params={{ volumeId: document.volumeId, documentId: document.documentId }}>
                      {plainTitle(document.title)}
                    </Link>
                    <p className="se-dates">
                      {document.volumeId}
                      {document.dateline && (
                        <>
                          <span aria-hidden="true"> · </span>
                          {document.dateline}
                        </>
                      )}
                    </p>
                  </li>
                ))}
              </ol>
              {data.totalCount > data.documents.length && <p className="note">{words.overflow(data.totalCount - data.documents.length)}</p>}
            </>
          )}
        </div>
      )}
    </div>
  );
}
