// Related Documents (PLAN's S23d), at /related/{volumeId}/{documentId}, which the reader's Related opens:
// the app's `RelatedDocumentsContent`, its tuning bar above its list. The scope, This volume, This
// subseries where the volume's subseries has another volume, or All volumes; Adjust weights, a slider for
// each of the app's eight axes, from 0 to 1, whose tuning re-ranks the list once a slider settles and is
// kept for the next list this browser opens, as the app keeps its device's, with Reset to app defaults,
// which forgets it; and the ranked list, each row the document's head or id, its volume and dateline, the
// opening of its text and its "why related" chips, strongest first, then the app's lines for more than it
// shows and for an archival pool cut short. The ranking, the chips' words and the pool's line are the
// kit's, on the server. The web's own: the scope and the tuning are in the address, so Back from a
// document returns to the list as it was; a slider of an axis this server does not rank by yet is shown
// set aside, and says so; and the list says it is ranked while the server ranks it.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { useEffect, useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { documentQuery } from '../api/endpoints';
import { type RelatedAxis, type RelatedDocuments, relatedQuery, type RelatedScope, storedWeights, storeWeights } from '../api/related';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { emptyDetail, encodedWeights, overflowLine, rowTitle, weightText } from './relatedRules';

const route = getRouteApi('/related/$volumeId/$documentId');

/** The list's address: its scope and its tuning, in the app's stored form. */
export interface RelatedSearch {
  scope?: RelatedScope;
  weights?: string;
}

/** How long a slider rests before the list is ranked again with it: the app re-ranks once a drag settles. */
const settle = 500;

export function RelatedScreen() {
  const { volumeId, documentId } = route.useParams();
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const scope = search.scope ?? 'all';
  // A list opens with the tuning this browser keeps, as the app's opens with its device's.
  const [opened] = useState(() => storedWeights() ?? '');
  const weights = search.weights ?? opened;
  const anchor = useQuery(documentQuery(volumeId, documentId));
  // The list on show stays while the next is ranked, so the tuning bar and its focus stay where they are.
  const related = useQuery({ ...relatedQuery(volumeId, documentId, scope, weights), placeholderData: keepPreviousData });
  const title = anchor.data ? plainTitle(anchor.data.document.displayTitle ?? documentId) : documentId;
  useDocumentTitle(copy.related.title);
  useHeadingReady(!related.isPending);

  function retune(next: string, keep: boolean) {
    if (keep) storeWeights(next === '' ? undefined : next);
    void navigate({ search: (previous: RelatedSearch) => ({ ...previous, weights: next }), replace: true });
  }

  let list;
  if (related.isError) {
    const preparing = related.error instanceof ApiError && related.error.code === 'INDEX_NOT_READY';
    list = preparing ? (
      <p role="status">{copy.related.preparing}</p>
    ) : (
      <p className="error" role="alert">
        {errorMessage(related.error)}
      </p>
    );
  } else if (!related.data) {
    list = <p role="status">{copy.related.ranking}</p>;
  } else {
    list = (
      <div aria-busy={related.isPlaceholderData}>
        <RelatedList related={related.data} />
      </div>
    );
  }

  return (
    <div className="related">
      <p className="back">
        <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId }}>
          <span aria-hidden="true">← </span>
          {copy.related.back(title)}
        </Link>
      </p>
      <h1 tabIndex={-1} data-loading={related.isPending ? 'true' : undefined}>
        {copy.related.title}
      </h1>
      {related.data && (
        <Tuning
          related={related.data}
          hasStored={storedWeights() !== undefined}
          onScope={(next) => void navigate({ search: (previous: RelatedSearch) => ({ ...previous, scope: next }), replace: true })}
          onWeights={(next) => retune(next, true)}
          onReset={() => {
            storeWeights(undefined);
            retune('', false);
          }}
        />
      )}
      {list}
    </div>
  );
}

function Tuning({
  related,
  hasStored,
  onScope,
  onWeights,
  onReset,
}: {
  related: RelatedDocuments;
  hasStored: boolean;
  onScope: (scope: RelatedScope) => void;
  onWeights: (weights: string) => void;
  onReset: () => void;
}) {
  const scopeName = useId();
  // Each slider's value while it moves, the list's tuning otherwise; the list is ranked again once they settle.
  const [draft, setDraft] = useState<Record<string, number> | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  useEffect(() => () => clearTimeout(timer.current), []);
  const shown = draft ?? Object.fromEntries(related.axes.map((axis) => [axis.id, axis.weight]));

  function move(axis: RelatedAxis, value: number) {
    const next = { ...shown, [axis.id]: value };
    setDraft(next);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      setDraft(null);
      const encoded = encodedWeights(next, related.axes);
      if (encoded !== related.weights) onWeights(encoded);
    }, settle);
  }

  return (
    <div className="related-tuning">
      {related.scopes.length > 1 && (
        <fieldset className="pane-picker">
          <legend className="visually-hidden">{copy.related.scope}</legend>
          {related.scopes.map((scope) => (
            <label key={scope}>
              <input type="radio" name={scopeName} checked={related.scope === scope} onChange={() => onScope(scope)} />
              <span>{copy.related.scopes[scope]}</span>
            </label>
          ))}
        </fieldset>
      )}
      <details className="related-weights">
        <summary>{copy.related.weights}</summary>
        <ul>
          {related.axes.map((axis) => (
            <WeightRow key={axis.id} axis={axis} value={shown[axis.id] ?? axis.weight} onChange={(value) => move(axis, value)} />
          ))}
        </ul>
        <button type="button" className="reset" disabled={!hasStored} onClick={onReset}>
          {copy.related.reset}
        </button>
      </details>
    </div>
  );
}

/** One axis's slider (`AxisWeightRow`): its name and its weight, to one decimal place. */
function WeightRow({ axis, value, onChange }: { axis: RelatedAxis; value: number; onChange: (value: number) => void }) {
  const id = useId();
  const note = axis.available ? undefined : (copy.related.notRanked[axis.id] ?? copy.related.subjectsUnavailable);
  return (
    <li className="weight-row">
      <label htmlFor={id}>{axis.name}</label>
      <output htmlFor={id}>{weightText(value)}</output>
      <input
        id={id}
        type="range"
        min={0}
        max={1}
        step={0.1}
        value={value}
        disabled={!axis.available}
        aria-valuetext={weightText(value)}
        aria-describedby={note ? `${id}-note` : undefined}
        onChange={(event) => onChange(Number(event.target.value))}
      />
      {note && (
        <p id={`${id}-note`} className="note">
          {note}
        </p>
      )}
    </li>
  );
}

function RelatedList({ related }: { related: RelatedDocuments }) {
  if (related.rows.length === 0) {
    return (
      <div className="related-empty">
        <h2>{copy.related.empty}</h2>
        <p>{emptyDetail(related.scope)}</p>
      </div>
    );
  }
  const more = overflowLine(related.totalBeforeLimit, related.rows.length);
  return (
    <>
      <ol className="related-list">
        {related.rows.map((row) => (
          <li key={`${row.volumeId}/${row.documentId}`}>
            <Link to="/doc/$volumeId/$documentId" params={{ volumeId: row.volumeId, documentId: row.documentId }}>
              {plainTitle(rowTitle(row))}
            </Link>
            <p className="related-place">
              {row.volumeId}
              {row.dateline && (
                <>
                  <span aria-hidden="true"> · </span>
                  {row.dateline}
                </>
              )}
            </p>
            {row.snippet && <p className="related-snippet">{row.snippet}</p>}
            {row.chips.length > 0 && (
              <ul className="related-chips" aria-label={copy.related.chips}>
                {row.chips.map((chip) => (
                  <li key={chip.axis} className={`related-chip axis-${chip.axis}`} title={chip.name}>
                    <span className="visually-hidden">{chip.name}, </span>
                    {chip.text}
                  </li>
                ))}
              </ul>
            )}
          </li>
        ))}
      </ol>
      {more && <p className="note">{more}</p>}
      {related.poolCut && <p className="note pool-cut">{related.poolCut}</p>}
    </>
  );
}
