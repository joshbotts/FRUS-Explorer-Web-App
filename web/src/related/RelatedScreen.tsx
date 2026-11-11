// Related Documents (PLAN's S23d), at /related/{volumeId}/{documentId}, which the reader's Related opens:
// the app's `RelatedDocumentsContent`, its tuning bar above its list. The scope, This volume, This
// subseries where the volume's subseries has another volume, or All volumes; Adjust weights, a slider for
// each of the app's eight axes, from 0 to 1, whose tuning re-ranks the list once a slider is let go, or
// rests under the keyboard, and is kept for the next list this browser opens, as the app keeps its
// device's, with Reset to app defaults, which forgets it; and the ranked list, each row the document's
// head or id, its volume and dateline, the opening of its text and its "why related" chips, strongest
// first, then the app's lines for more than it shows and for an archival pool cut short. The ranking, the
// chips' words and the pool's line are the kit's, on the server. The web's own: the scope and the tuning
// are in the address, so Back from a document returns to the list as it was; the controls show what was
// asked for at once, and keep their place and the focus while the server ranks, which a status line says;
// a slider of an axis this server does not rank by yet is shown set aside, and says so; and a chip names
// its axis in words, where the app draws the axis's symbol.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { useEffect, useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { documentQuery } from '../api/endpoints';
import { type RelatedAxis, type RelatedDocuments, relatedQuery, type RelatedScope, storedWeights, storeWeights } from '../api/related';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { decodedWeights, emptyDetail, encodedWeights, overflowLine, rowTitle, weightText } from './relatedRules';

const route = getRouteApi('/related/$volumeId/$documentId');

/** The list's address: its scope and its tuning, in the app's stored form. */
export interface RelatedSearch {
  scope?: RelatedScope;
  weights?: string;
}

/** How long a slider moved by the keyboard rests before the list is ranked again with it. */
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
  // The axes and scopes of the last list the server gave, for the tuning bar while a list cannot be had.
  const [lastGood, setLastGood] = useState<RelatedDocuments | undefined>(undefined);
  if (related.data && related.data !== lastGood && !related.isPlaceholderData) setLastGood(related.data);
  const shape = related.data ?? lastGood;
  const title = anchor.data ? plainTitle(anchor.data.document.displayTitle ?? documentId) : documentId;
  useDocumentTitle(copy.related.title);
  useHeadingReady(!related.isPending);

  function retune(next: string) {
    void navigate({ search: (previous: RelatedSearch) => ({ ...previous, weights: next }), replace: true });
  }

  const preparing = related.isError && related.error instanceof ApiError && related.error.code === 'INDEX_NOT_READY';
  let list;
  if (related.isError) {
    list = preparing ? null : (
      <p className="error" role="alert">
        {errorMessage(related.error)}
      </p>
    );
  } else if (related.data) {
    list = (
      <div aria-busy={related.isPlaceholderData}>
        <RelatedList related={related.data} />
      </div>
    );
  }
  const status = preparing ? copy.related.preparing : related.isFetching ? copy.related.ranking : '';

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
      {shape && (
        <Tuning
          shape={shape}
          scope={scope}
          weights={weights}
          canReset={storedWeights() !== undefined || weights !== ''}
          onScope={(next) => void navigate({ search: (previous: RelatedSearch) => ({ ...previous, scope: next }), replace: true })}
          onWeights={(next) => {
            storeWeights(next === '' ? undefined : next);
            retune(next);
          }}
          onReset={() => {
            storeWeights(undefined);
            retune('');
          }}
        />
      )}
      <p className="note related-status" role="status">
        {status}
      </p>
      {list}
    </div>
  );
}

function Tuning({
  shape,
  scope,
  weights,
  canReset,
  onScope,
  onWeights,
  onReset,
}: {
  /** The axes and scopes of the list on show. */
  shape: RelatedDocuments;
  /** The scope and the tuning asked for, which the controls show before the server answers with them. */
  scope: RelatedScope;
  weights: string;
  canReset: boolean;
  onScope: (scope: RelatedScope) => void;
  onWeights: (weights: string) => void;
  onReset: () => void;
}) {
  const scopeName = useId();
  const summary = useRef<HTMLElement>(null);
  // Each slider's value while it moves; the tuning asked for otherwise.
  const [draft, setDraft] = useState<Record<string, number> | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const dragging = useRef(false);
  const pending = useRef<Record<string, number> | null>(null);
  const shown = draft ?? decodedWeights(weights, shape.axes);
  const axes = shape.axes;

  // A tuning moved and not yet ranked when the page goes is kept for the next list, as a settled one is.
  useEffect(
    () => () => {
      clearTimeout(timer.current);
      if (pending.current) storeWeights(encodedWeights(pending.current, axes) || undefined);
    },
    [axes],
  );

  function commit() {
    clearTimeout(timer.current);
    const next = pending.current;
    pending.current = null;
    setDraft(null);
    if (!next) return;
    const encoded = encodedWeights(next, axes);
    if (encoded !== weights) onWeights(encoded);
  }

  function move(axis: RelatedAxis, value: number) {
    const next = { ...shown, [axis.id]: value };
    pending.current = next;
    setDraft(next);
    clearTimeout(timer.current);
    // A drag commits when it is let go; the keyboard's steps once they rest.
    if (!dragging.current) timer.current = setTimeout(commit, settle);
  }

  function reset() {
    clearTimeout(timer.current);
    pending.current = null;
    setDraft(null);
    onReset();
    // Reset is unavailable once it has reset, so the focus goes back to the weights' heading.
    summary.current?.focus();
  }

  return (
    <div className="related-tuning">
      {shape.scopes.length > 1 && (
        <fieldset className="pane-picker">
          <legend className="visually-hidden">{copy.related.scope}</legend>
          {shape.scopes.map((each) => (
            <label key={each}>
              <input type="radio" name={scopeName} checked={scope === each} onChange={() => onScope(each)} />
              <span>{copy.related.scopes[each]}</span>
            </label>
          ))}
        </fieldset>
      )}
      <details className="related-weights">
        <summary ref={summary}>{copy.related.weights}</summary>
        <ul>
          {axes.map((axis) => (
            <WeightRow
              key={axis.id}
              axis={axis}
              value={shown[axis.id] ?? axis.weight}
              onChange={(value) => move(axis, value)}
              onGrab={() => {
                dragging.current = true;
              }}
              onRelease={() => {
                dragging.current = false;
                if (pending.current) commit();
              }}
            />
          ))}
        </ul>
        <button type="button" className="reset" disabled={!canReset} onClick={reset}>
          {copy.related.reset}
        </button>
      </details>
    </div>
  );
}

/** One axis's slider (`AxisWeightRow`): its name and its weight, to one decimal place. */
function WeightRow({
  axis,
  value,
  onChange,
  onGrab,
  onRelease,
}: {
  axis: RelatedAxis;
  value: number;
  onChange: (value: number) => void;
  onGrab: () => void;
  onRelease: () => void;
}) {
  const id = useId();
  const note = axis.available ? undefined : (copy.related.notRanked[axis.id] ?? copy.related.subjectsUnavailable);
  return (
    <li className="weight-row">
      <label htmlFor={id}>{axis.name}</label>
      {/* The slider says its value itself; this is for the eye. */}
      <output htmlFor={id} aria-hidden="true">
        {weightText(value)}
      </output>
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
        onPointerDown={onGrab}
        onPointerUp={onRelease}
        onPointerCancel={onRelease}
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
                  <li key={chip.axis} className={`related-chip axis-${chip.axis}`}>
                    <span className="related-chip-axis">{chip.name}</span> {chip.text}
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
