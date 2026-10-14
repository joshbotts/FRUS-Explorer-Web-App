// The facet panel (SPEC, Search): what a search's whole match holds, by year, volume, person,
// document type, provenance and subject, each section computed when it is opened, as the Mac's
// panel computes it. The server cuts every section with the kit: FacetPaging sorts, filters and
// pages its rows, FacetNarrowing says how a row narrows the search, and FacetSelection resolves an
// Apply. Years and volumes stage rows to include or exclude, then Apply them together; people,
// document type and subjects narrow on a click; provenance only describes. The staged rows' three
// states are the browser's, in the order of the kit's FacetRowState.
import { useQuery } from '@tanstack/react-query';
import { useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { ApiError } from '../api/client';
import { type FacetDisplay, facetSectionQuery, fetchFacetSelection } from '../api/endpoints';
import type { FacetSectionName, SearchFacetSection } from '../api/types';
import { copy } from '../copy';
import { applySearchChange, filterFields, isPartialEvidence, type SearchState } from './searchState';

const sections: readonly FacetSectionName[] = ['years', 'volumes', 'people', 'documentType', 'provenance', 'subjects'];

/** A staged section's chosen rows. */
interface Selection {
  included: readonly string[];
  excluded: readonly string[];
}

const nothingChosen: Selection = { included: [], excluded: [] };

type RowState = keyof typeof copy.facets.rowStates;

function rowState(selection: Selection, key: string): RowState {
  if (selection.included.includes(key)) return 'included';
  if (selection.excluded.includes(key)) return 'excluded';
  return 'neutral';
}

/** The row's next state: neutral, then included, then excluded, then neutral again. */
function cycled(selection: Selection, key: string): Selection {
  switch (rowState(selection, key)) {
    case 'neutral':
      return { ...selection, included: [...selection.included, key] };
    case 'included':
      return { included: selection.included.filter((other) => other !== key), excluded: [...selection.excluded, key] };
    case 'excluded':
      return { ...selection, excluded: selection.excluded.filter((other) => other !== key) };
  }
}

/** How each section is cut, and what it has staged: the panel's state, which outlasts the panel. */
export interface FacetPanelState {
  displays: Partial<Record<FacetSectionName, FacetDisplay>>;
  setDisplay: (section: FacetSectionName, display: FacetDisplay) => void;
  selections: Partial<Record<FacetSectionName, Selection>>;
  setSelection: (section: FacetSectionName, selection: Selection) => void;
}

/**
 * The panel's state, held by the screen so it outlasts the panel, as the Mac's controller outlasts
 * its inspector. Another search keeps each section's sort and page size, the reader's choice, and
 * drops its page, its filter and its staged rows, which described the last search's rows.
 */
export function useFacetPanelState(state: SearchState): FacetPanelState {
  const [displays, setDisplays] = useState<Partial<Record<FacetSectionName, FacetDisplay>>>({});
  const [selections, setSelections] = useState<Partial<Record<FacetSectionName, Selection>>>({});
  const signature = JSON.stringify(filterFields(state));
  const [shownFor, setShownFor] = useState(signature);
  if (shownFor !== signature) {
    setShownFor(signature);
    setDisplays((previous) => {
      const kept: Partial<Record<FacetSectionName, FacetDisplay>> = {};
      for (const section of sections) {
        const display = previous[section];
        if (display) kept[section] = { sort: display.sort, pageSize: display.pageSize };
      }
      return kept;
    });
    setSelections({});
  }
  return {
    displays,
    setDisplay: (section, display) => setDisplays((previous) => ({ ...previous, [section]: display })),
    selections,
    setSelection: (section, selection) => setSelections((previous) => ({ ...previous, [section]: selection })),
  };
}

export function FacetPanel({
  state,
  total,
  panel,
  onSearch,
}: {
  state: SearchState;
  /** The match's exact count, once the search shown has one. */
  total: number | undefined;
  panel: FacetPanelState;
  /** Runs the search a row or an Apply narrows this one to. */
  onSearch: (next: SearchState) => void;
}) {
  const [open, setOpen] = useState<ReadonlySet<FacetSectionName>>(() => new Set());
  const headingId = useId();

  return (
    <aside id="facet-panel" className="facet-panel" aria-labelledby={headingId}>
      <h2 id={headingId} className="visually-hidden">
        {copy.facets.panel}
      </h2>
      <p className="caption">{total !== undefined ? copy.facets.describing(total) : copy.facets.describingUnknown}</p>
      <p className="caption">{copy.facets.wholeMatch}</p>
      {sections.map((section) => (
        <FacetSectionView
          key={section}
          section={section}
          state={state}
          open={open.has(section)}
          onToggle={() =>
            setOpen((previous) => {
              const next = new Set(previous);
              if (next.has(section)) next.delete(section);
              else next.add(section);
              return next;
            })
          }
          display={panel.displays[section] ?? {}}
          onDisplay={(display) => panel.setDisplay(section, display)}
          selection={panel.selections[section] ?? nothingChosen}
          onSelection={(selection) => panel.setSelection(section, selection)}
          onSearch={onSearch}
        />
      ))}
    </aside>
  );
}

function FacetSectionView({
  section,
  state,
  open,
  onToggle,
  display,
  onDisplay,
  selection,
  onSelection,
  onSearch,
}: {
  section: FacetSectionName;
  state: SearchState;
  open: boolean;
  onToggle: () => void;
  display: FacetDisplay;
  onDisplay: (display: FacetDisplay) => void;
  selection: Selection;
  onSelection: (selection: Selection) => void;
  onSearch: (next: SearchState) => void;
}) {
  const bodyId = useId();
  const hintId = useId();
  const toggle = useRef<HTMLButtonElement>(null);
  const query = useQuery({ ...facetSectionQuery(state, section, display), enabled: open });
  const [applying, setApplying] = useState(false);
  // An Apply's failure belongs to the search it was for, and so does its answer.
  const signature = JSON.stringify(filterFields(state));
  const [applyError, setApplyError] = useState<{ signature: string; message: string } | null>(null);
  const current = useRef(signature);
  useEffect(() => {
    current.current = signature;
  }, [signature]);

  // The filter field asks for its rows once typing pauses; a new search empties it.
  const [filterText, setFilterText] = useState(display.filter ?? '');
  const [shownFilter, setShownFilter] = useState(display.filter ?? '');
  if ((display.filter ?? '') !== shownFilter) {
    setShownFilter(display.filter ?? '');
    setFilterText(display.filter ?? '');
  }
  const commitFilter = useEffectEvent((text: string) => onDisplay({ ...display, filter: text, page: 0 }));
  useEffect(() => {
    if (filterText === shownFilter) return;
    const timer = setTimeout(() => commitFilter(filterText), 300);
    return () => clearTimeout(timer);
  }, [filterText, shownFilter]);

  /** The search the change makes, run, with focus back on the section, whose rows are counted again. */
  function narrow(next: SearchState) {
    onSearch(next);
    toggle.current?.focus();
  }

  async function apply() {
    if (section !== 'years' && section !== 'volumes') return;
    const asked = signature;
    setApplying(true);
    setApplyError(null);
    try {
      const resolved = await fetchFacetSelection(state, section, selection.included, selection.excluded);
      // A search made meanwhile is the reader's latest word; this answer was for the one before it.
      if (current.current === asked) narrow(applySearchChange(state, resolved.change));
    } catch (error) {
      if (error instanceof ApiError && error.code === 'SECTION_CHANGED') {
        // The rows chosen are not this search's any more, as after a new index: they are
        // counted again, and the choice starts afresh.
        onSelection(nothingChosen);
        void query.refetch();
        setApplyError({ signature: asked, message: copy.facets.sectionChanged });
      } else {
        setApplyError({ signature: asked, message: error instanceof ApiError ? error.message : String(error) });
      }
    } finally {
      setApplying(false);
    }
  }

  const title = copy.facets.sections[section];
  return (
    <section className="facet-section">
      <h3>
        <button ref={toggle} type="button" className="facet-toggle" aria-expanded={open} aria-controls={open ? bodyId : undefined} onClick={onToggle}>
          <span aria-hidden="true">{open ? '▾ ' : '▸ '}</span>
          {title}
        </button>
      </h3>
      {open && (
        <div id={bodyId} className="facet-body">
          {query.isPending ? (
            <p role="status" className="caption">
              {copy.facets.counting}
            </p>
          ) : query.isError ? (
            query.error instanceof ApiError && query.error.code === 'EMPTY_QUERY' ? (
              <p className="caption">{copy.facets.none}</p>
            ) : (
              <p className="error" role="alert">
                {copy.facets.failed} {query.error instanceof ApiError ? query.error.message : String(query.error)}
              </p>
            )
          ) : (
            <SectionBody
              data={query.data}
              section={section}
              display={display}
              onDisplay={onDisplay}
              filterText={filterText}
              onFilterText={setFilterText}
              selection={selection}
              onSelection={onSelection}
              hintId={hintId}
              onClearSelection={() => {
                onSelection(nothingChosen);
                toggle.current?.focus();
              }}
              onNarrow={(row) => {
                if (!row.narrowing) return;
                const next = applySearchChange(state, row.narrowing);
                narrow(section === 'subjects' ? { ...next, subjectLabel: row.label } : next);
              }}
              applying={applying}
              onApply={() => void apply()}
            />
          )}
          {applyError?.signature === signature && (
            <p className="error" role="alert">
              {applyError.message}
            </p>
          )}
        </div>
      )}
    </section>
  );
}

function SectionBody({
  data,
  section,
  display,
  onDisplay,
  filterText,
  onFilterText,
  selection,
  onSelection,
  hintId,
  onClearSelection,
  onNarrow,
  applying,
  onApply,
}: {
  data: SearchFacetSection;
  section: FacetSectionName;
  display: FacetDisplay;
  onDisplay: (display: FacetDisplay) => void;
  filterText: string;
  onFilterText: (text: string) => void;
  selection: Selection;
  onSelection: (selection: Selection) => void;
  hintId: string;
  /** Drops the staged rows, with focus back on the section, since the strip goes with them. */
  onClearSelection: () => void;
  onNarrow: (row: SearchFacetSection['rows'][number]) => void;
  applying: boolean;
  onApply: () => void;
}) {
  const filterField = useRef<HTMLInputElement>(null);
  const { page, rows } = data;
  if (page.totalCount === 0) return <p className="caption">{copy.facets.none}</p>;
  const label = (row: SearchFacetSection['rows'][number]) =>
    section === 'documentType' ? (copy.facets.documentTypes[row.key] ?? row.label) : row.label;
  const filtered = page.matchingCount !== page.totalCount;
  const showingEverything = page.pageCount <= 1 && !filtered;
  const first = page.firstRowNumber;
  const last = first + rows.length - 1;
  const chosen = [
    selection.included.length > 0 ? copy.facets.included(selection.included.length) : null,
    selection.excluded.length > 0 ? copy.facets.excluded(selection.excluded.length) : null,
  ].filter((part) => part !== null);

  return (
    <>
      <div className="facet-controls">
        {data.sortChoices.length > 0 && (
          <select
            aria-label={copy.facets.sortOrder}
            value={display.sort ?? data.display.sort}
            onChange={(event) => onDisplay({ ...display, sort: event.target.value, page: 0 })}
          >
            {data.sortChoices.map((choice) => (
              <option key={choice.value} value={choice.value}>
                {choice.title}
              </option>
            ))}
          </select>
        )}
        {page.totalCount > 5 && (
          <select
            aria-label={copy.facets.rowsPerPage}
            value={display.pageSize ?? data.display.pageSize}
            onChange={(event) => onDisplay({ ...display, pageSize: event.target.value, page: 0 })}
          >
            {data.pageSizeChoices.map((choice) => (
              <option key={choice.value} value={choice.value}>
                {choice.title}
              </option>
            ))}
          </select>
        )}
        {(section === 'volumes' || section === 'people') && page.totalCount > 100 && (
          <span className="facet-filter">
            <input
              ref={filterField}
              type="search"
              aria-label={copy.facets.filterRows(page.totalCount)}
              placeholder={copy.facets.filterRows(page.totalCount)}
              value={filterText}
              onChange={(event) => onFilterText(event.target.value)}
            />
            {filterText !== '' && (
              <button
                type="button"
                onClick={() => {
                  onFilterText('');
                  filterField.current?.focus();
                }}
              >
                {copy.facets.clearRowFilter}
              </button>
            )}
          </span>
        )}
      </div>
      {rows.length === 0 && <p className="caption">{copy.facets.filterNoMatches(page.totalCount)}</p>}
      {data.selection === 'staged' && (
        <p id={hintId} className="visually-hidden">
          {copy.facets.stagedHint}
        </p>
      )}
      <ul className="facet-rows">
        {rows.map((row) => {
          const name = label(row);
          const count = row.count.toLocaleString('en-US');
          if (data.selection === 'staged') {
            const state = rowState(selection, row.key);
            return (
              <li key={row.key}>
                <button
                  type="button"
                  className={`facet-row ${state}`}
                  // Named in so many words, so every browser reads the row and its state alike.
                  aria-label={`${name} ${count}, ${copy.facets.rowStates[state]}`}
                  aria-describedby={hintId}
                  onClick={() => onSelection(cycled(selection, row.key))}
                >
                  <span className="facet-glyph" aria-hidden="true">
                    {state === 'included' ? '✓' : state === 'excluded' ? '−' : '○'}
                  </span>
                  <span className="facet-label">{name}</span>{' '}
                  <span className="facet-count">{count}</span>
                </button>
              </li>
            );
          }
          if (data.selection === 'immediate' && row.narrowing) {
            return (
              <li key={row.key}>
                <button
                  type="button"
                  className="facet-row"
                  // The Mac's tooltip, which is the row's description too.
                  title={copy.facets.narrowTo(name)}
                  aria-label={`${name} ${count}`}
                  onClick={() => onNarrow(row)}
                >
                  <span className="facet-label">{name}</span>{' '}
                  <span className="facet-count">{count}</span>
                </button>
              </li>
            );
          }
          return (
            <li key={row.key} className="facet-row descriptive">
              <span className="facet-label">{name}</span>{' '}
              <span className="facet-count">{count}</span>
            </li>
          );
        })}
      </ul>
      {!showingEverything && rows.length > 0 && (
        <div className="facet-footer">
          <span className="caption">
            {filtered ? copy.facets.rangeFiltered(first, last, page.matchingCount, page.totalCount) : copy.facets.range(first, last, page.matchingCount)}
          </span>
          {page.pageCount > 1 && (
            <span className="facet-pager">
              <button
                type="button"
                aria-label={copy.facets.previousPage}
                disabled={page.pageIndex === 0}
                onClick={() => onDisplay({ ...display, page: page.pageIndex - 1 })}
              >
                ‹
              </button>
              <span>{copy.facets.pageIndicator(page.pageIndex + 1, page.pageCount)}</span>
              <button
                type="button"
                aria-label={copy.facets.nextPage}
                disabled={page.pageIndex >= page.pageCount - 1}
                onClick={() => onDisplay({ ...display, page: page.pageIndex + 1 })}
              >
                ›
              </button>
            </span>
          )}
        </div>
      )}
      {data.selection === 'staged' && chosen.length > 0 && (
        <div className="facet-strip">
          <span className="caption">{chosen.join(' · ')}</span>
          <button type="button" onClick={onClearSelection}>
            {copy.facets.clear}
          </button>
          <button type="button" className="primary" disabled={applying} onClick={onApply}>
            {copy.facets.apply}
          </button>
        </div>
      )}
      {section === 'years' && (data.undatedCount ?? 0) > 0 && <p className="caption">{copy.facets.undated(data.undatedCount ?? 0)}</p>}
      {data.bound?.isTruncated && <p className="caption">{copy.facets.bound(data.bound.shown, data.bound.total)}</p>}
      {section === 'provenance' && data.provenanceCoverage && (
        <>
          <p className="caption">
            {copy.facets.provenanceCoverage(
              data.provenanceCoverage.parsed,
              data.provenanceCoverage.matchCount,
              data.provenanceCoverage.withRecordGroup,
            )}
          </p>
          <p className="caption">{copy.facets.provenanceDescriptive}</p>
        </>
      )}
      {section === 'subjects' && (
        <>
          <p className="caption">
            {data.subjectsPrepared === false
              ? copy.facets.subjectsPreparing
              : copy.facets.subjectsCoverage(data.subjectCoverage ?? 0, data.matchCount)}
          </p>
          <p className="caption">{copy.facets.subjectsSource}</p>
        </>
      )}
      {/* Said only of a real concentration, as the Mac says it: the three largest volumes holding a
          quarter or more. Never said of a match larger than what the app keeps, where, as the Mac
          has it, no caveat can repair a concentration figure. */}
      {section === 'volumes' && !isPartialEvidence(data.matchCount) && (data.topVolumeShare ?? 0) >= 0.25 && (
        <p className="caption">{copy.facets.concentration(Math.round((data.topVolumeShare ?? 0) * 100))}</p>
      )}
    </>
  );
}
