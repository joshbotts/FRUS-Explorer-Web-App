// The Research page (PLAN's S19b), at /research, as the app's `ResearchView` lays it out: its categories,
// All Research Documents, Contains Notes and All Notes, then By Collection, By Tag and By Highlight,
// each with its count, and History; and the chosen category's documents, the most recently annotated
// first, each row the app's: the document's title, which opens it, its volume and the time since its
// newest annotation, its summaries and visit plan, its three newest highlights, its newest note, and
// its tags, notes and collections. The Mac's split on a wide window, All Research Documents shown
// until another is chosen, as the Mac's opens; below 900 px the iPhone's stack, the categories, then a
// category's list with the way back. All Notes and History open their screens, as the app's rows push
// them. The web's own: Changed by an update's line, since this server does not review changed text
// yet; a choice sends focus to the list's title; and a highlight's colour named for a screen reader.
import { type UseQueryResult, useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type MouseEvent, type ReactNode, useEffect, useId, useRef, useSyncExternalStore } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { type ResearchDocument, type ResearchDocumentList, researchDocumentsQuery, type ResearchPage, researchPageQuery } from '../api/researchPage';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useNow } from '../shell/useNow';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { timeSince } from './notesRules';
import { emptyDescription, groupKey, hasFooter, listTitle, moreHighlights, parseGroup, type ResearchGroup, sameGroup } from './researchRules';

const route = getRouteApi('/research');

export interface ResearchSearch {
  /** The category shown, by its key; absent for the page's first, All Research Documents. */
  group?: string;
}

/** A category's key, kept only when it names one, so an old bookmark's shows All Research Documents. */
export function validateResearchSearch(raw: Record<string, unknown>): ResearchSearch {
  const value = Array.isArray(raw.group) ? raw.group[0] : raw.group;
  return { group: typeof value === 'string' && parseGroup(value) ? value : undefined };
}

/** Where focus goes once a choice has rendered: the list's title, or back to the categories. */
type Pending = 'list' | 'categories' | null;

/** The iPhone's stack, below 900 px, as the stylesheet lays the page out. */
const narrowQuery = '(max-width: 899.98px)';

/** Whether the window is narrow enough for the stack; never, where the browser cannot say. */
function useNarrow(): boolean {
  return useSyncExternalStore(
    (changed) => {
      if (typeof window.matchMedia !== 'function') return () => {};
      const list = window.matchMedia(narrowQuery);
      list.addEventListener('change', changed);
      return () => list.removeEventListener('change', changed);
    },
    () => typeof window.matchMedia === 'function' && window.matchMedia(narrowQuery).matches,
  );
}

/** A click that follows the link here: not one the browser sends to a new tab or window. */
function followsHere(event: MouseEvent): boolean {
  return event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey && !event.defaultPrevented;
}

export function ResearchScreen() {
  const { group } = route.useSearch();
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const shown: ResearchGroup = (group && parseGroup(group)) || { kind: 'allAnnotated' };
  const shownKey = group ?? groupKey(shown);
  const page = useQuery({ ...researchPageQuery, enabled: keepsUserData });
  const documents = useQuery({ ...researchDocumentsQuery(shownKey), enabled: keepsUserData && shown.kind !== 'updated' });
  const heading = useRef<HTMLHeadingElement>(null);
  const listHeading = useRef<HTMLHeadingElement>(null);
  const categories = useRef<HTMLElement>(null);
  const listId = useId();
  const now = useNow();
  const narrow = useNarrow();
  useDocumentTitle(copy.researchPage.title);
  useHeadingReady(!me.isPending);

  // A choice sends focus to the list's title, and the way back to the category it left, once each has
  // rendered. Back and Forward, which can hide where focus was in a narrow window, send it to what shows:
  // the list's title, or the category left where the categories show again.
  const pending = useRef<Pending>(null);
  const previous = useRef(group);
  useEffect(() => {
    if (previous.current === group) return;
    const from = previous.current;
    previous.current = group;
    const want = pending.current;
    pending.current = null;
    if (want === 'list') {
      listHeading.current?.focus();
      return;
    }
    const left = [...(categories.current?.querySelectorAll<HTMLAnchorElement>('a[data-group]') ?? [])].find(
      (link) => from !== undefined && sameGroup(link.dataset.group ?? '', from) && link.getClientRects().length > 0,
    );
    if (want !== 'categories') {
      const active = document.activeElement;
      if (active instanceof HTMLElement && active !== document.body && active.getClientRects().length > 0) return;
    }
    (group !== undefined && want !== 'categories' ? listHeading.current : (left ?? heading.current))?.focus();
  }, [group]);

  /** A category chosen: its list's title takes focus, at once when it is the one shown. */
  function choose(event: MouseEvent, key: string) {
    if (!followsHere(event)) return;
    if (group !== undefined && sameGroup(key, group)) listHeading.current?.focus();
    else pending.current = 'list';
  }

  let body: ReactNode;
  if (me.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(me.error)}
      </p>
    );
  } else if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else {
    // A tag's or a collection's list is titled by its answer once it has come, as `listTitle(for:)`
    // names it, and by its row in the categories until then.
    let title: string | undefined;
    if (shown.kind === 'tag' || shown.kind === 'collection') {
      const rows = shown.kind === 'tag' ? page.data?.tags : page.data?.collections;
      title = documents.data ? listTitle(shown, documents.data.name) : rows?.find((item) => sameGroup(item.id, shown.id))?.name;
      // A list that could not be read, of a tag or collection the categories do not name, is titled
      // as the app titles one it cannot find.
      if (title === undefined && documents.isError) title = listTitle(shown, undefined) ?? copy.collectionEditor.untitled;
    } else {
      title = listTitle(shown, undefined);
    }
    body = (
      <div className="research-columns">
        <nav ref={categories} className="research-categories" aria-label={copy.researchPage.categories}>
          {page.isError ? (
            <p className="error" role="alert">
              {errorMessage(page.error)}
            </p>
          ) : !page.data ? (
            <p role="status">{copy.researchPage.loading}</p>
          ) : (
            // The Mac's split shows All Research Documents until another is chosen; the iPhone's stack
            // has none chosen until one is.
            <Categories page={page.data} current={group ?? (narrow ? undefined : shownKey)} onChoose={choose} />
          )}
        </nav>
        <section className="research-list" aria-labelledby={listId}>
          {/* Exact, so the router does not call it the current page beside a list, and with the scroll
              left alone, so the category focus goes back to is where the page shows it. */}
          <Link
            to="/research"
            search={{}}
            activeOptions={{ exact: true }}
            resetScroll={false}
            className="research-back"
            onClick={(event) => {
              if (followsHere(event)) pending.current = 'categories';
            }}
          >
            <span aria-hidden="true">‹ </span>
            {copy.researchPage.categories}
          </Link>
          <h2 id={listId} ref={listHeading} tabIndex={-1}>
            {title ?? copy.researchPage.loading}
          </h2>
          <DocumentList group={shown} documents={documents} now={now} />
        </section>
      </div>
    );
  }

  return (
    <section className="screen research-page" data-chosen={group !== undefined ? 'true' : undefined}>
      <h1 ref={heading} tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
        {copy.researchPage.title}
      </h1>
      {body}
    </section>
  );
}

/**
 * The categories, as the app's sidebar lists them: All Research Documents, Contains Notes and All Notes
 * with their counts, Changed by an update's line and History; then each section with something in it.
 */
function Categories({
  page,
  current,
  onChoose,
}: {
  page: ResearchPage;
  current: string | undefined;
  onChoose: (event: MouseEvent, key: string) => void;
}) {
  const collectionsId = useId();
  const tagsId = useId();
  const highlightsId = useId();
  const category = (key: string, name: ReactNode, count: number) => (
    <li key={key}>
      <Link
        to="/research"
        search={{ group: key }}
        className="research-category"
        data-group={key}
        aria-current={current !== undefined && sameGroup(key, current) ? 'page' : undefined}
        onClick={(event) => onChoose(event, key)}
      >
        <span className="research-category-name">{name}</span>
        <span className="visually-hidden">, </span>
        <span className="research-category-count">{copy.researchPage.count(count)}</span>
      </Link>
    </li>
  );
  return (
    <>
      <ul className="research-categories-list">
        {category('allAnnotated', copy.researchPage.allAnnotated, page.allAnnotated)}
        {category('hasNotes', copy.researchPage.hasNotes, page.hasNotes)}
        <li>
          <Link to="/research/notes" className="research-category">
            <span className="research-category-name">{copy.researchPage.notes}</span>
            <span className="visually-hidden">, </span>
            <span className="research-category-count">{copy.researchPage.count(page.notes)}</span>
          </Link>
        </li>
        <li className="research-waits">
          <span className="research-category-name">{copy.researchPage.updated}</span>
          <span className="research-category-detail">{copy.researchPage.updatedWaits}</span>
        </li>
        <li>
          <Link to="/research/history" className="research-category">
            <span className="research-category-name">{copy.researchPage.history}</span>
            <span className="visually-hidden">, </span>
            <span className="research-category-detail">{copy.researchPage.historyDetail}</span>
          </Link>
        </li>
      </ul>
      {page.collections.length > 0 && (
        <>
          <h2 id={collectionsId}>{copy.researchPage.collections}</h2>
          <ul className="research-categories-list" aria-labelledby={collectionsId}>
            {page.collections.map((item) => category(`collection.${item.id}`, item.name, item.count))}
          </ul>
        </>
      )}
      {page.tags.length > 0 && (
        <>
          <h2 id={tagsId}>{copy.researchPage.tags}</h2>
          <ul className="research-categories-list" aria-labelledby={tagsId}>
            {page.tags.map((item) => category(`tag.${item.id}`, item.name, item.count))}
          </ul>
        </>
      )}
      {page.highlightColors.length > 0 && (
        <>
          <h2 id={highlightsId}>{copy.researchPage.highlights}</h2>
          <ul className="research-categories-list" aria-labelledby={highlightsId}>
            {page.highlightColors.map((item) =>
              category(
                `highlightColor.${item.color}`,
                <span className={`research-color hl-${item.color}`}>{copy.highlights.colors[item.color]}</span>,
                item.count,
              ),
            )}
          </ul>
        </>
      )}
    </>
  );
}

/** A category's documents, or what its list says of none, or why it waits. */
function DocumentList({
  group,
  documents,
  now,
}: {
  group: ResearchGroup;
  documents: UseQueryResult<ResearchDocumentList>;
  now: number;
}) {
  if (group.kind === 'updated' || (documents.error instanceof ApiError && documents.error.code === 'UPDATE_REVIEW_NOT_OFFERED')) {
    return <p className="note">{copy.researchPage.updatedWaits}</p>;
  }
  if (documents.isError) {
    return (
      <p className="error" role="alert">
        {errorMessage(documents.error)}
      </p>
    );
  }
  if (!documents.data) return <p role="status">{copy.researchPage.loading}</p>;
  if (documents.data.items.length === 0) {
    return (
      <p className="empty">
        <strong>{copy.researchPage.noDocs}</strong> {emptyDescription(group)}
      </p>
    );
  }
  return (
    <ul className="research-documents">
      {documents.data.items.map((row) => (
        <DocumentRow key={`${row.volumeId}/${row.documentId}`} row={row} now={now} />
      ))}
    </ul>
  );
}

/**
 * A row, as the app's: the title, which opens the document; its volume and the time since its newest
 * annotation; its summaries and visit plan; its three newest highlights, each beside a bar of its colour,
 * and how many more; its newest note; and its tags, its notes past one and its collections.
 */
function DocumentRow({ row, now }: { row: ResearchDocument; now: number }) {
  const more = moreHighlights(row.highlightCount);
  return (
    <li className="research-document">
      <Link className="research-document-title" to="/doc/$volumeId/$documentId" params={{ volumeId: row.volumeId, documentId: row.documentId }}>
        {row.title}
      </Link>
      <p className="research-document-volume">
        <span>{row.volumeTitle}</span>
        {row.annotatedAt && <span className="research-document-time">{timeSince(row.annotatedAt, now)}</span>}
      </p>
      {(row.summaryCount > 0 || row.isInVisitPlan) && (
        <p className="research-document-counts">
          {row.summaryCount > 0 && <span>{copy.researchPage.summaries(row.summaryCount)}</span>}
          {row.isInVisitPlan && <span>{copy.researchPage.inVisitPlan}</span>}
        </p>
      )}
      {row.highlights.length > 0 && (
        <ul className="research-highlights">
          {row.highlights.map((highlight) => (
            <li key={highlight.id} className={`research-highlight hl-${highlight.color}`}>
              <span className="visually-hidden">{copy.researchPage.highlightColor(copy.highlights.colors[highlight.color])}</span>
              {highlight.selectedText === '' ? <em>{copy.researchPage.noText}</em> : highlight.selectedText}
            </li>
          ))}
        </ul>
      )}
      {more && <p className="research-more">{more}</p>}
      {row.latestNote && <p className="research-note">{row.latestNote}</p>}
      {hasFooter(row) && (
        <p className="research-footer">
          {row.tags.map((tag) => (
            <span key={tag.id} className="research-tag">
              <span aria-hidden="true">◆ </span>
              <span className="visually-hidden">{copy.researchPage.tagLabel}</span>
              {tag.name}
            </span>
          ))}
          {row.noteCount > 1 && <span className="research-notes">{copy.researchPage.noteCount(row.noteCount)}</span>}
          {row.collections.map((collection) => (
            <span key={collection.id} className="research-collection">
              <span className="visually-hidden">{copy.researchPage.collectionLabel}</span>
              {collection.name}
            </span>
          ))}
        </p>
      )}
    </li>
  );
}
