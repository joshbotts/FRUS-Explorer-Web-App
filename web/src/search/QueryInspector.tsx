// The Query Inspector (SPEC, Search): what the text in the search box compiles to and what each of
// its terms matches, shown as the Mac's strip shows it while the reader types, between the filters
// and the results; and the search window's view of a search that found nothing, which names the term
// responsible. The server runs the kit's QueryInspector over the served index: its cheap pass each
// time the text or a filter settles, each term counted within the filters when the reader asks, and,
// for a search that found nothing, each term searched alone.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useEffect, useId, useRef, useState } from 'react';
import { inspectQuery } from '../api/endpoints';
import type { FormValue } from '../api/form';
import type { InspectedTerm, QueryInspection, SearchOperand } from '../api/types';
import { copy } from '../copy';
import { filterFields, type SearchState } from './searchState';

/** How long the strip waits for the text or a filter to settle before it asks again, as the Mac's controller waits. */
export const inspectorDelay = 300;

/**
 * The inspector's fields for a search with `text` in the box: the search's filters, and the text
 * trimmed, left out when nothing is left, as the Mac reads its field for the inspector and for the
 * search that ran.
 */
export function inspectorFields(state: SearchState, text: string): Record<string, FormValue> {
  const trimmed = text.trim();
  return { ...filterFields(state), keywords: trimmed === '' ? undefined : trimmed };
}

/** Whether `fields` hold anything to inspect: text, or a filter that might run without it. */
function holdsAnything(fields: Record<string, FormValue>): boolean {
  return Object.values(fields).some((value) => value !== undefined);
}

/** `value`, once it has stood for `delay` milliseconds. */
function useSettled(value: string, delay: number): string {
  const [settled, setSettled] = useState(value);
  useEffect(() => {
    if (value === settled) return;
    const timer = setTimeout(() => setSettled(value), delay);
    return () => clearTimeout(timer);
  }, [value, settled, delay]);
  return settled;
}

/**
 * The strip, for the search the box and the filters say now. It appears when the kit has something
 * to say: an expression, a search of filters alone, or a refusal. The account on show stays while the
 * next is asked for, though not one from before the box was emptied, and the scoped counts go when
 * the text or a filter changes, as on the Mac.
 */
export function QueryInspectorStrip({
  fields,
  expanded,
  onExpandedChange,
}: {
  fields: Record<string, FormValue>;
  /** Whether the term detail is shown, which the search entry keeps from search to search. */
  expanded: boolean;
  onExpandedChange: (expanded: boolean) => void;
}) {
  const settled = useSettled(JSON.stringify(fields), inspectorDelay);
  const asked = JSON.parse(settled) as Record<string, FormValue>;
  const anything = holdsAnything(asked);
  const cheap = useQuery({ ...inspectQuery(asked), enabled: anything, placeholderData: keepPreviousData });
  // An emptied box hides the strip, and the account it hid does not stand in for the next query's.
  const [emptied, setEmptied] = useState(!anything);
  if (!anything && !emptied) setEmptied(true);
  if (anything && emptied && cheap.data !== undefined && !cheap.isPlaceholderData) setEmptied(false);
  const [countedFor, setCountedFor] = useState<string | null>(null);
  if (countedFor !== null && countedFor !== settled) setCountedFor(null);
  const counting = countedFor === settled;
  const counted = useQuery({ ...inspectQuery(asked, { scopedCounts: true }), enabled: anything && counting });
  const toggle = useRef<HTMLButtonElement>(null);
  const detailId = useId();

  const shown = emptied && cheap.isPlaceholderData ? undefined : cheap.data?.inspection;
  const inspection = (counting ? counted.data?.inspection : undefined) ?? shown;
  if (!anything || !inspection?.showsStrip) return null;
  const toggleLabel = expanded ? copy.inspector.hideDetail : copy.inspector.showDetail;

  function countInScope() {
    // Asked again after a count that failed; otherwise asked for the first time.
    if (counting) void counted.refetch();
    else setCountedFor(settled);
    // The offer goes once it is taken, so focus stays in the strip.
    toggle.current?.focus();
  }

  return (
    <section className="query-inspector" aria-label={copy.inspector.label}>
      <div className="inspector-head">
        <Expression inspection={inspection} />
        <button
          ref={toggle}
          type="button"
          className="inspector-toggle"
          aria-expanded={expanded}
          aria-controls={expanded ? detailId : undefined}
          aria-label={toggleLabel}
          title={toggleLabel}
          onClick={() => onExpandedChange(!expanded)}
        >
          <span aria-hidden="true">{expanded ? '▴' : '▾'}</span>
        </button>
      </div>
      {expanded && (
        <div id={detailId} className="inspector-detail">
          {inspection.showsTermRows && (
            <>
              <ul className="inspector-terms">
                {inspection.operands.map((term, index) => (
                  <TermRow key={`term-${index}`} term={term} />
                ))}
                {inspection.notApplied.map((operand, index) => (
                  <NotAppliedRow key={`left-out-${index}`} operand={operand} />
                ))}
              </ul>
              <p className="caption" role="status">
                {counting && counted.isFetching ? copy.inspector.counting : ''}
              </p>
              {!(counting && counted.isFetching) && inspection.hasUncountedOperands && (
                <button type="button" className="link-button" onClick={countInScope}>
                  {copy.inspector.countInScope}
                </button>
              )}
            </>
          )}
          <p className="caption">{copy.inspector.denominator(inspection.indexedVolumeCount)}</p>
        </div>
      )}
    </section>
  );
}

/**
 * The expression row, which never collapses: MATCH and the expression, with the caption for one
 * narrower than typed; or, with no expression, the one line that says why. The Mac's caption for
 * expressions that differ between documents and the reader's own writing has no place here: the
 * browser app sends no scope that could make them differ.
 */
function Expression({ inspection }: { inspection: QueryInspection }) {
  const displayed = inspection.expression?.displayed;
  if (displayed !== undefined) {
    return (
      <div className="inspector-expression">
        <p>
          <MicroTag>{copy.inspector.matchTag}</MicroTag> <code>{displayed}</code>
        </p>
        {inspection.showsApproximateCaption && <p className="caption">{copy.inspector.approximate}</p>}
      </div>
    );
  }
  const line = inspection.isFilterOnly
    ? copy.inspector.filterOnly
    : inspection.malformedProximity !== undefined
      ? copy.inspector.refusedNear(inspection.malformedProximity)
      : inspection.isRefused
        ? copy.inspector.refused
        : undefined;
  return line === undefined ? null : <p className="inspector-expression caption">{line}</p>;
}

/** A term the search uses: its text and tags, what the index counts of it, and a warning when its stem widens it. */
function TermRow({ term }: { term: InspectedTerm }) {
  const { operand } = term;
  return (
    <li>
      <span className="inspector-term">{operand.text}</span>
      {operand.isNegated && (
        <>
          {' '}
          <MicroTag>{copy.inspector.excludedTag}</MicroTag>
        </>
      )}
      {operand.isExactApplied && (
        <>
          {' '}
          <MicroTag>{copy.inspector.exactTag}</MicroTag>
        </>
      )}
      {term.showsStructuredTag && (
        <>
          {' '}
          <MicroTag>{copy.inspector.structuredTag}</MicroTag>
        </>
      )}{' '}
      <span className="caption inspector-line">{countLine(term)}</span>
      {term.isStemBroadening && term.stem !== undefined && (
        <>
          {' '}
          <span className="inspector-warning inspector-line">
            <span aria-hidden="true">⚠ </span>
            {copy.inspector.stemWarning(operand.text, term.stem)}
          </span>
        </>
      )}
    </li>
  );
}

/** A term the query typed that the search leaves out: an exclusion with nothing to exclude from. */
function NotAppliedRow({ operand }: { operand: SearchOperand }) {
  return (
    <li className="inspector-left-out">
      <span className="inspector-term">{operand.text}</span> <MicroTag>{copy.inspector.notAppliedTag}</MicroTag>{' '}
      <span className="caption inspector-line">{copy.inspector.notAppliedDetail}</span>
    </li>
  );
}

/**
 * A term's count line, as the Mac's strip writes it: an excluded term says what excluding does;
 * another gives its count in scope once counted, its documents across the index, and its
 * occurrences where they come to 1.5 a document or more, which is when they say something the
 * document count does not.
 */
export function countLine(term: InspectedTerm): string {
  if (term.operand.isNegated) return copy.inspector.excludedDetail;
  const parts: string[] = [];
  if (term.scopedCount !== undefined) parts.push(copy.inspector.scopedCount(term.scopedCount));
  if (term.corpusDocumentFrequency !== undefined) parts.push(copy.inspector.corpusCount(term.corpusDocumentFrequency));
  const perDocument = term.corpusOccurrencesPerDocument;
  if (term.corpusOccurrences !== undefined && perDocument !== undefined && perDocument >= 1.5) {
    parts.push(copy.inspector.occurrences(term.corpusOccurrences, perDocument));
  }
  return parts.length === 0 ? copy.inspector.noCount : parts.join(' · ');
}

function MicroTag({ children }: { children: string }) {
  return <span className="micro-tag">{children}</span>;
}

/**
 * The view of a search that found nothing, in place of its results: the term that matched nothing
 * in the reader's scope, or that the combination is what matches nothing, from each term of the
 * search that ran, searched alone under its filters.
 */
export function ZeroResult({ state }: { state: SearchState }) {
  const blame = useQuery(inspectQuery(inspectorFields(state, state.keywords ?? ''), { emptyConjuncts: true }));
  const inspection = blame.data?.inspection;
  const empty = blame.data?.emptyConjuncts;
  // An answer outlasts a later failure to ask again; a failure with no answer says what the Mac's
  // view says with none.
  const message =
    inspection && empty
      ? empty.length > 1
        ? copy.zeroResult.severalEmpty(empty.map((operand) => operand.text))
        : empty[0]
          ? copy.zeroResult.oneEmpty(empty[0].text)
          : inspection.hasOperands
            ? copy.zeroResult.combination
            : copy.zeroResult.detail
      : blame.isError
        ? copy.zeroResult.detail
        : undefined;
  return (
    <div className="zero-result" aria-busy={blame.isFetching}>
      <h3>{copy.zeroResult.title}</h3>
      {message !== undefined && <p>{message}</p>}
      {inspection && <p className="caption">{copy.zeroResult.denominator(inspection.indexedVolumeCount)}</p>}
    </div>
  );
}
