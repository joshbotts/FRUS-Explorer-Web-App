// The semantic map's cards (PLAN's S28c), the app's (`SemanticMapSpikeView`'s `regionCard` and `selectionCard`) in the
// web's page: a region's card, its name, the kit's headline and era rows, what a region is and the era's caveat, to
// which the web adds the region's documents in the scope, the set the app's card saves, each of which shows its point
// on the map; and a point's card, its headline, its ids, its heading where the server serves it, its region or Between
// regions, and Open Document, or that its volume is not on this server. And the notice for a document a link names that
// has no place on the map. Every count, name and row is the server's, the kit's.
//
// Since S28e (the map's tools): a region's card saves its region as a working corpus, as the app's does, the keyboard's
// path to a corpus; a point's card offers the axis's two poles, "Axis: from here" and "…to here", with what a slice adds,
// and lists its ten nearest in language, each showing its point; the axis's card says what the slice runs between, or the
// pole set so far, with the app's refusals, and goes back to the map; and the lasso's card says what a lasso caught, as
// the app's: its count, its regions, that its membership is the model's, the capture's cap, what the server holds of it,
// and Save as Working Corpus.
import { useInfiniteQuery, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type Ref, useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  type SemanticMapLassoCapture,
  type SemanticMapPoint,
  type SemanticMapScopeAsk,
  saveRegionCorpus,
  semanticMapNearestQuery,
  semanticMapRegionPages,
} from '../api/semanticMap';
import type { WorkingCorpus } from '../api/searchSets';
import { copy } from '../copy';
import { ProvenanceChip } from '../sources/Chips';

const words = copy.semanticAnalytics;

/** A region's card, with its documents in the scope, a page at a time. */
export function RegionCard({
  region,
  layout,
  scope,
  scoped,
  canSave = false,
  onDismiss,
  onShow,
}: {
  region: number;
  layout: string;
  scope: SemanticMapScopeAsk;
  scoped: boolean;
  /** Whether the server keeps user data, so that the region can be saved as a working corpus. */
  canSave?: boolean;
  onDismiss: () => void;
  /** Shows one of its documents' points on the map. */
  onShow: (key: string) => void;
}) {
  const heading = useId();
  const listHeading = useId();
  const list = useRef<HTMLUListElement>(null);
  const card = useInfiniteQuery(semanticMapRegionPages(region, layout, scope));
  const client = useQueryClient();
  // The app's `savedRegionCorpusName` and `regionCaptureTruncation`, each of this region in this scope alone: the card is
  // made again for another.
  const [saved, setSaved] = useState<WorkingCorpus | undefined>(undefined);
  const [saving, setSaving] = useState(false);
  const [saveFailure, setSaveFailure] = useState<string | undefined>(undefined);
  const savedLine = useRef<HTMLParagraphElement>(null);
  async function save() {
    if (saving) return;
    setSaving(true);
    setSaveFailure(undefined);
    try {
      setSaved(await saveRegionCorpus(client, region, layout, scope));
    } catch (error) {
      setSaveFailure(errorMessage(error));
    } finally {
      setSaving(false);
    }
  }
  // The button gives way to the line that says where the corpus is, which takes the keyboard from it.
  useEffect(() => {
    if (saved) savedLine.current?.focus();
  }, [saved]);
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
          {canSave && answer.total > 0 && (
            <div className="semantic-card-save">
              {saved ? (
                <p ref={savedLine} tabIndex={-1} className="semantic-card-note">
                  {words.regionSave.saved(saved.name)}
                </p>
              ) : (
                <button type="button" aria-disabled={saving ? 'true' : undefined} onClick={() => void save()}>
                  {words.regionSave.save}
                </button>
              )}
              {saved?.wasTruncatedAtCapture && saved.totalMatchCountAtCapture !== undefined && (
                <p className="semantic-card-absent">{words.regionSave.truncated(saved.documentCount, saved.totalMatchCountAtCapture)}</p>
              )}
              {saveFailure && (
                <p className="analytics-alert" role="alert">
                  {saveFailure}
                </p>
              )}
            </div>
          )}
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

/** The axis's two poles, as a point's card offers them: its volume as either end, the high end once the low end is set. */
export interface PoleControls {
  /** Whether a slice is drawn, which the card's sentence of what a slice adds gives way to. */
  sliced: boolean;
  /** Whether the low end is set, which "…to here" waits for. */
  canSetTo: boolean;
  onFrom: () => void;
  onTo: () => void;
}

/** A point's card: what the reader picked or a link revealed, and what they can do about it. */
export function PointCard({
  point,
  headingRef,
  onDismiss,
  poles,
  onShow,
}: {
  point: SemanticMapPoint;
  headingRef?: Ref<HTMLHeadingElement>;
  onDismiss: () => void;
  /** The axis's poles, from S28e. */
  poles?: PoleControls;
  /** Shows a neighbour's point on the map; with it, the card lists the point's nearest in language. */
  onShow?: (key: string) => void;
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
      {poles && (
        <>
          {!poles.sliced && <p className="semantic-card-note">{words.axis.whatItAdds}</p>}
          <div className="semantic-card-actions">
            <button type="button" onClick={poles.onFrom}>
              {words.axis.from}
            </button>
            <button type="button" disabled={!poles.canSetTo} onClick={poles.onTo}>
              {words.axis.to}
            </button>
          </div>
        </>
      )}
      {onShow && <Nearest key={`${point.volumeId}/${point.documentId}`} point={point} onShow={onShow} />}
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

/**
 * A point's ten nearest in language (`nearestSection`): the semantic source's, each its heading and the score the app's
 * row prints, a button that shows its point; with the sentence that they are drawn from the volumes this server serves,
 * and, for none, why: the anchor's vectors not here, no index served, or none found.
 */
function Nearest({ point, onShow }: { point: SemanticMapPoint; onShow: (key: string) => void }) {
  const heading = useId();
  const nearest = useQuery(semanticMapNearestQuery(`${point.volumeId}/${point.documentId}`));
  const answer = nearest.data;
  return (
    <div className="semantic-card-nearest">
      {nearest.isPending ? (
        <p className="semantic-card-note" role="status">
          {words.nearest.loading}
        </p>
      ) : nearest.error ? (
        <p className="semantic-card-note">{words.nearest.failed}</p>
      ) : answer && answer.neighbours.length > 0 ? (
        <>
          <h3 id={heading}>{words.nearest.header}</h3>
          <ul className="semantic-card-documents" aria-labelledby={heading}>
            {answer.neighbours.map((neighbour) => {
              const key = `${neighbour.volumeId}/${neighbour.documentId}`;
              return (
                <li key={key}>
                  <button type="button" className="link-button" data-key={key} onClick={() => onShow(key)}>
                    {neighbour.title}
                  </button>
                  <span className="semantic-card-score">{words.nearest.score(neighbour.percent)}</span>
                </li>
              );
            })}
          </ul>
          <p className="semantic-card-note">{words.nearest.fence}</p>
        </>
      ) : (
        <p className="semantic-card-note">
          {answer?.empty === 'noShard' ? words.nearest.noShard : answer?.empty === 'noIndex' ? words.nearest.noIndex : words.nearest.none}
        </p>
      )}
    </div>
  );
}

/**
 * The axis's card (`sliceCard`): the two volumes the slice runs between, with the way back to the map; or the one pole
 * set so far, with what the second costs; and a refusal's notice, said when it comes.
 */
export function AxisCard({
  slice,
  pole,
  notice,
  laying,
  onClear,
}: {
  slice?: { from: string; to: string };
  pole?: string;
  notice?: string;
  /** Whether the slice is being laid out. */
  laying: boolean;
  onClear: () => void;
}) {
  const heading = useId();
  return (
    <section className="semantic-card" aria-labelledby={heading}>
      <div className="semantic-card-head">
        <h2 id={heading}>{words.axis.title}</h2>
        <button type="button" className="semantic-card-dismiss" aria-label={words.axis.clear} onClick={onClear}>
          ×
        </button>
      </div>
      {slice ? (
        <>
          <p className="semantic-card-ids">{words.axis.poles(slice.from, slice.to)}</p>
          <button type="button" onClick={onClear}>
            {words.axis.back}
          </button>
        </>
      ) : (
        pole && (
          <>
            <p className="semantic-card-ids">{pole}</p>
            <p className="semantic-card-note">{words.axis.needsSecondPole}</p>
          </>
        )
      )}
      {/* There before its words, so that a refusal, or the slice's coming, is said when it comes. */}
      <p className={notice ? 'semantic-card-absent' : 'semantic-card-note'} role="status">
        {notice ?? (laying ? words.axis.laying : '')}
      </p>
    </section>
  );
}

/**
 * The lasso's card (`lassoCard`): what it caught, its count or that nothing in the scope is there, the regions it caught
 * most of, that the set is the model's reading (the chip), the capture's cap said before the corpus is made, what the
 * server holds of it, and Save as Working Corpus, where the server keeps user data.
 */
export function LassoCard({
  capture,
  canSave,
  onSave,
  onDismiss,
}: {
  capture: SemanticMapLassoCapture;
  canSave: boolean;
  /** Saves the capture, answering the corpus made. */
  onSave: () => Promise<WorkingCorpus>;
  onDismiss: () => void;
}) {
  const heading = useId();
  const [saved, setSaved] = useState<WorkingCorpus | undefined>(undefined);
  const [saving, setSaving] = useState(false);
  const [failure, setFailure] = useState<string | undefined>(undefined);
  const savedLine = useRef<HTMLParagraphElement>(null);
  async function save() {
    if (saving) return;
    setSaving(true);
    setFailure(undefined);
    try {
      setSaved(await onSave());
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setSaving(false);
    }
  }
  useEffect(() => {
    if (saved) savedLine.current?.focus();
  }, [saved]);
  const empty = capture.total === 0;
  return (
    <section className="semantic-card" aria-label={words.lasso.title}>
      <div className="semantic-card-head">
        <h2 id={heading}>{empty ? words.lasso.emptyInScope : words.lasso.documents(capture.total)}</h2>
        <button type="button" className="semantic-card-dismiss" aria-label={words.lasso.dismiss} onClick={onDismiss}>
          ×
        </button>
      </div>
      {capture.regionNames.length > 0 && <p className="semantic-card-region">{capture.regionNames.join(' · ')}</p>}
      {!empty && <ProvenanceChip source="appModel" />}
      {capture.total > capture.kept && <p className="semantic-card-absent">{words.lasso.truncated(capture.kept, capture.total)}</p>}
      {empty ? (
        <p className="semantic-card-note">{words.lasso.emptyInScopeDetail}</p>
      ) : (
        capture.coverage && (
          <p className={capture.coverage.isComplete ? 'semantic-card-note' : 'semantic-card-absent'}>
            {copy.corpora.coverage(capture.coverage.indexedCount, capture.coverage.totalCount)}
          </p>
        )
      )}
      {!empty && canSave && (
        saved ? (
          <p ref={savedLine} tabIndex={-1} className="semantic-card-saved">
            <span aria-hidden="true">✓ </span>
            {words.lasso.saved(saved.name)}
          </p>
        ) : (
          <button type="button" aria-disabled={saving ? 'true' : undefined} onClick={() => void save()}>
            {words.lasso.save}
          </button>
        )
      )}
      {failure && (
        <p className="analytics-alert" role="alert">
          {failure}
        </p>
      )}
    </section>
  );
}
