// The semantic map's cards (PLAN's S28c), the app's (`SemanticMapSpikeView`'s `regionCard` and `selectionCard`) in the
// web's page: a region's card, its name, the kit's headline and era rows, what a region is and the era's caveat, to
// which the web adds the region's documents in the scope, the set the app's card saves, each of which shows its point
// on the map; and a point's card, its headline, its ids, its heading where the server serves it, its region or Between
// regions, and Open Document, or that its volume is not on this server. And the notice for a document a link names that
// has no place on the map. Every count, name and row is the server's, the kit's.
import { useInfiniteQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type Ref, useEffect, useId, useRef } from 'react';
import { errorMessage } from '../api/client';
import { type SemanticMapPoint, type SemanticMapScopeAsk, semanticMapRegionPages } from '../api/semanticMap';
import { copy } from '../copy';

const words = copy.semanticAnalytics;

/** A region's card, with its documents in the scope, a page at a time. */
export function RegionCard({
  region,
  layout,
  scope,
  scoped,
  onDismiss,
  onShow,
}: {
  region: number;
  layout: string;
  scope: SemanticMapScopeAsk;
  scoped: boolean;
  onDismiss: () => void;
  /** Shows one of its documents' points on the map. */
  onShow: (key: string) => void;
}) {
  const heading = useId();
  const listHeading = useId();
  const list = useRef<HTMLUListElement>(null);
  const card = useInfiniteQuery(semanticMapRegionPages(region, layout, scope));
  const pages = card.data?.pages ?? [];
  const answer = pages[0]?.id === region ? pages[0] : undefined;
  const documents = pages.flatMap((each) => each.documents);

  // Show More keeps its place while the page comes, and then the keyboard goes on to the first document it added.
  const focusFrom = useRef<number | undefined>(undefined);
  function more() {
    if (card.isFetchingNextPage) return;
    focusFrom.current = documents.length;
    void card.fetchNextPage();
  }
  useEffect(() => {
    const from = focusFrom.current;
    if (from === undefined || documents.length <= from) return;
    focusFrom.current = undefined;
    list.current?.querySelectorAll<HTMLButtonElement>('button[data-key]')[from]?.focus();
  }, [documents.length]);
  return (
    <section className="semantic-card" aria-labelledby={heading}>
      <div className="semantic-card-head">
        <h2 id={heading}>{words.region.title}</h2>
        <button type="button" className="semantic-card-dismiss" aria-label={words.region.dismiss} title={words.region.dismissHelp}
                onClick={onDismiss}>
          ×
        </button>
      </div>
      {card.error && !answer ? (
        <p className="analytics-alert" role="alert">{errorMessage(card.error)}</p>
      ) : !answer ? (
        <p className="analytics-loading" role="status">{words.loading}</p>
      ) : (
        <>
          <p className="semantic-card-name">{answer.name}</p>
          <p className="semantic-card-count">{answer.countSummary}</p>
          <p className="semantic-card-note">{words.region.whatItIs}</p>
          <dl className="semantic-card-eras">
            {answer.eraRows.map((row) => (
              <div key={row.label}>
                <dt>{row.label}</dt>
                <dd>{row.count}</dd>
              </div>
            ))}
          </dl>
          <p className="semantic-card-note">{words.region.eraCaveat}</p>
          <h3 id={listHeading}>{scoped ? words.region.documentsInScope : words.region.documents}</h3>
          {answer.total === 0 ? (
            <p className="semantic-card-note">{words.region.none}</p>
          ) : (
            <>
              <p className="semantic-card-note">
                {words.region.shown(documents.length, answer.total)}
                {!card.hasNextPage && answer.kept < answer.total ? ` ${words.region.capped(answer.kept, answer.total)}` : ''}
              </p>
              <ul ref={list} className="semantic-card-documents" aria-labelledby={listHeading}>
                {documents.map((document) => {
                  const key = `${document.volumeId}/${document.documentId}`;
                  return (
                    <li key={key}>
                      <button type="button" className="link-button" data-key={key} onClick={() => onShow(key)}
                              aria-label={words.region.show(document.title ?? document.headline)}>
                        {document.title ?? document.headline}
                      </button>
                      {document.title && <span className="semantic-card-ids">{document.headline}</span>}
                    </li>
                  );
                })}
              </ul>
              {card.error && pages.length > 0 && <p className="analytics-alert" role="alert">{errorMessage(card.error)}</p>}
              {card.hasNextPage && (
                <button type="button" aria-disabled={card.isFetchingNextPage} onClick={more}>
                  {words.region.more}
                </button>
              )}
            </>
          )}
        </>
      )}
    </section>
  );
}

/** A point's card: what the reader picked or a link revealed, and what they can do about it. */
export function PointCard({
  point,
  headingRef,
  onDismiss,
}: {
  point: SemanticMapPoint;
  headingRef?: Ref<HTMLHeadingElement>;
  onDismiss: () => void;
}) {
  const heading = useId();
  return (
    <section className="semantic-card" aria-labelledby={heading}>
      <div className="semantic-card-head">
        <h2 id={heading} ref={headingRef} tabIndex={-1}>{point.headline}</h2>
        <button type="button" className="semantic-card-dismiss" aria-label={words.point.dismiss} onClick={onDismiss}>
          ×
        </button>
      </div>
      <p className="semantic-card-ids">{point.ids}</p>
      {point.title && <p className="semantic-card-title">{point.title}</p>}
      <p className="semantic-card-region">{point.regionName ?? words.point.betweenRegions}</p>
      {point.served ? (
        <Link to="/doc/$volumeId/$documentId" params={{ volumeId: point.volumeId, documentId: point.documentId }} className="button">
          {words.point.open}
        </Link>
      ) : (
        <p className="semantic-card-absent">{words.point.notServed}</p>
      )}
    </section>
  );
}

/** That a document a link names has no place on the map, until the reader picks another or dismisses it. */
export function NotOnMap({ volumeTitle, onDismiss }: { volumeTitle: string; onDismiss: () => void }) {
  const heading = useId();
  return (
    <section className="semantic-card semantic-card-notice" aria-labelledby={heading}>
      <div className="semantic-card-head">
        <h2 id={heading}>{words.notOnMap.title}</h2>
        <button type="button" className="semantic-card-dismiss" aria-label={words.notOnMap.dismiss} onClick={onDismiss}>
          ×
        </button>
      </div>
      <p className="semantic-card-note">{words.notOnMap.detail(volumeTitle)}</p>
    </section>
  );
}
