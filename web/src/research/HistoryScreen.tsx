// The History screen (PLAN's S17f), as the app's `HistoryView` lays it out: the project's scope and a
// search field, then the documents visited, the searches executed and the collections exported, each
// newest first, a page of each, with Show More and "Showing N of M" while the scope holds more; each
// row deleted at once with Delete, as a history list deletes one; a visit reopened, and a search run
// again by its words; and, under the documents, the line saying that nothing new is recorded while Log
// Research Sessions is off. A search's scope under its count is the web's own, as SPEC's History has it.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type ReactNode, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { deleteHistoryEntry, type HistoryScope, historyPageIncrement, historyPageLimit, historyQuery } from '../api/research';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useNow } from '../shell/useNow';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { exportMatches, isFiltering, searchMatches, showingCount, visitMatches } from './historyRules';
import { timeSince } from './notesRules';
import { ResearchNav } from './ResearchNav';

export function HistoryScreen() {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const [scope, setScope] = useState<HistoryScope>('all');
  const [limit, setLimit] = useState(historyPageLimit);
  const [query, setQuery] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const history = useQuery({ ...historyQuery(scope, limit), enabled: keepsUserData });
  const page = history.data;
  const heading = useRef<HTMLHeadingElement>(null);
  useDocumentTitle(copy.history.title);
  useHeadingReady(!me.isPending && (!keepsUserData || !history.isPending));

  // A project gone from under the picker returns the scope to every project, as the app's does.
  if (page && scope !== 'all' && scope !== 'unfiled' && !page.projects.some((project) => project.id === scope)) {
    setScope('all');
  }
  const filtering = isFiltering(scope, query);
  const now = useNow();

  async function remove(kind: 'documents' | 'searches' | 'exports', id: string, row: HTMLElement | null) {
    setFailure(null);
    // The focus goes on to the next row's Delete, or the last, or the heading.
    const list = row?.closest('ul');
    const buttons = [...(list?.querySelectorAll<HTMLButtonElement>('button.delete') ?? [])];
    const index = buttons.findIndex((button) => button.closest('li') === row);
    try {
      await deleteHistoryEntry(client, kind, id);
      await client.refetchQueries({ queryKey: historyQuery(scope, limit).queryKey, exact: true });
      // The deleted row's own Delete is passed over, should the list not have lost it yet.
      const left = [...(list?.querySelectorAll<HTMLButtonElement>('button.delete') ?? [])].filter((button) => button.dataset.id !== id);
      (left[index] ?? left[index - 1] ?? heading.current)?.focus();
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  let body: ReactNode;
  if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else if (history.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(history.error)}
      </p>
    );
  } else if (!page) {
    body = <p role="status">{copy.history.loading}</p>;
  } else {
    const documents = page.documents.filter((row) => visitMatches(row, query));
    const searches = page.searches.filter((row) => searchMatches(row, query));
    const exports = page.exports.filter((row) => exportMatches(row, query));
    const showMore = (
      <li key="show-more" className="show-more">
        <button type="button" onClick={() => setLimit((current) => current + historyPageIncrement)}>
          {copy.history.showMore}
        </button>
      </li>
    );
    body = (
      <>
        <div className="history-filters">
          <label title={copy.history.scopeHelp}>
            {copy.history.scopeLabel}{' '}
            <select value={scope} onChange={(event) => setScope(event.target.value)}>
              <option value="all">{copy.history.scopeAll}</option>
              <option value="unfiled">{copy.history.scopeUnfiled}</option>
              {page.projects.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name}
                </option>
              ))}
            </select>
          </label>
          <input
            type="search"
            value={query}
            placeholder={copy.history.search}
            aria-label={copy.history.searchA11y}
            onChange={(event) => setQuery(event.target.value)}
          />
        </div>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <Section
          title={copy.history.documents}
          showing={showingCount(page.documents.length, page.totalDocuments)}
          empty={filtering ? [copy.history.filteredTitle, copy.history.filteredDetail] : [copy.history.documentsEmptyTitle, copy.history.documentsEmpty]}
          footer={page.loggingEnabled ? undefined : copy.history.loggingOff}
        >
          {documents.map((row) => (
            <li key={row.id}>
              <span className="row-text">
                <Link to="/doc/$volumeId/$documentId" params={{ volumeId: row.volumeId, documentId: row.documentId }}>
                  {row.title}
                </Link>
                <span className="caption">
                  {[row.caption, row.accessedAt ? timeSince(row.accessedAt, now) : undefined].filter(Boolean).join(' · ')}
                </span>
              </span>
              <DeleteButton id={row.id} name={row.title} onDelete={(item) => void remove('documents', row.id, item)} />
            </li>
          ))}
          {documents.length > 0 && page.documents.length < page.totalDocuments && showMore}
        </Section>
        <Section
          title={copy.history.searches}
          showing={showingCount(page.searches.length, page.totalSearches)}
          empty={filtering ? [copy.history.filteredTitle, copy.history.filteredDetail] : [copy.history.searchesEmptyTitle, copy.history.searchesEmpty]}
        >
          {searches.map((row) => (
            <li key={row.id}>
              <span className="row-text">
                <Link to="/search" search={{ keywords: row.queryText }}>
                  {row.queryText}
                </Link>
                <span className="caption">
                  {[copy.history.resultCount(row.resultCount), row.executedAt ? timeSince(row.executedAt, now) : undefined]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
                <span className="caption">{row.scope}</span>
              </span>
              <DeleteButton id={row.id} name={row.queryText} onDelete={(item) => void remove('searches', row.id, item)} />
            </li>
          ))}
          {searches.length > 0 && page.searches.length < page.totalSearches && showMore}
        </Section>
        <Section
          title={copy.history.exports}
          showing={showingCount(page.exports.length, page.totalExports)}
          empty={filtering ? [copy.history.filteredTitle, copy.history.filteredDetail] : [copy.history.exportsEmptyTitle, copy.history.exportsEmpty]}
        >
          {exports.map((row) => (
            <li key={row.id}>
              <span className="row-text">
                <span>{row.title}</span>
                <span className="caption">
                  {[row.formatName, copy.history.documentCount(row.documentCount), row.exportedAt ? timeSince(row.exportedAt, now) : undefined]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
              </span>
              <DeleteButton id={row.id} name={row.title} onDelete={(item) => void remove('exports', row.id, item)} />
            </li>
          ))}
          {exports.length > 0 && page.exports.length < page.totalExports && showMore}
        </Section>
      </>
    );
  }

  return (
    <div className="history">
      <ResearchNav />
      <h1 ref={heading} tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
        {copy.history.title}
      </h1>
      {body}
    </div>
  );
}

/** A section of the trail: its title, with "Showing N of M" while it holds more, its rows or what it says of none. */
function Section({
  title,
  showing,
  empty,
  footer,
  children,
}: {
  title: string;
  showing: string | undefined;
  empty: [string, string];
  footer?: string;
  children: ReactNode[];
}) {
  const headingId = useId();
  const rows = children.flat().filter(Boolean);
  return (
    <section className="history-section" aria-labelledby={headingId}>
      <h2 id={headingId}>{title}</h2>
      {showing && <p className="note">{showing}</p>}
      {rows.length === 0 ? (
        <p className="empty">
          <strong>{empty[0]}</strong> {empty[1]}
        </p>
      ) : (
        <ul className="history-rows">{rows}</ul>
      )}
      {footer && <p className="note">{footer}</p>}
    </section>
  );
}

function DeleteButton({ id, name, onDelete }: { id: string; name: string; onDelete: (row: HTMLElement | null) => void }) {
  return (
    <button
      type="button"
      className="delete"
      data-id={id}
      aria-label={copy.history.deleteNamed(name)}
      onClick={(event) => onDelete(event.currentTarget.closest('li'))}
    >
      {copy.history.delete}
    </button>
  );
}
