// Chronology (PLAN's S24f), at /chronology: the app's `ChronologyView` as a page. Its range, From and To, opening
// on the corpus's last year and loaded by Show; the summary with Search in this range; the toolbar's chart, order
// and colours; the chart pane, the legend whose entries filter the list, its banner with Show all, and the
// distribution chart, drawn by Vega-Lite from the kit's buckets; the chips for the documents that span more than a
// year and those whose dates reach past the range, each opening its section; and the sections, each with its
// count, density bar and line, a dense one showing its first 25 rows until Show all, its rows opening the
// documents. The rows, sections, chart, chips, summary and lines are the kit's or the view's, from the server. The
// web's own: the range, order, colours, legend filter and hidden chart in the address, so Back returns to a range
// as it was; the chart's table beside it, its CSV with the kit's method block, and its figure, which the app's
// Chronology does not export; and a bar of the chart, chosen, bringing its section into view, as the app's tap
// scrolls to it.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type FormEvent, lazy, Suspense, useId, useMemo, useState } from 'react';
import { analyticsContextQuery, type ChronologyAnswer, type ChronologyApart, type ChronologyAsk, chronologyCSV, chronologyPlate, chronologyQuery, type ChronologyRow } from '../api/analytics';
import { ApiError, errorMessage } from '../api/client';
import { copy } from '../copy';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton } from '../shell/MenuButton';
import { saveFile } from '../shell/saveFile';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { type ChronologySearch, chronologySpec, figureSpec, seriesColor, store, storageKeys, stored } from './analyticsRules';

const route = getRouteApi('/chronology');
const words = copy.chronology;
const exportWords = copy.corpusAnalytics;

const VegaChart = lazy(() => import('./VegaChart').then((module) => ({ default: module.VegaChart })));

/** `ChronologyView.denseThreshold`: the rows a section shows before its Show all. */
const denseThreshold = 25;

export function ChronologyScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const context = useQuery(analyticsContextQuery);
  const scheme = useScheme();
  const kept = Number(stored(storageKeys.colors));
  const colors = search.colors ?? (Number.isInteger(kept) && kept >= 6 && kept <= 12 ? kept : (context.data?.defaultColors ?? 8));
  const ask: ChronologyAsk | undefined =
    search.from && search.to ? { from: search.from, to: search.to, newest: search.order === 'newest', colors, series: search.series } : undefined;
  const loaded = useQuery({ ...chronologyQuery(ask ?? { from: '', to: '' }), enabled: ask !== undefined });
  const answer = loaded.data;
  useDocumentTitle(words.title);
  useHeadingReady(!context.isPending);

  const [draftFrom, setDraftFrom] = useState(search.from ?? '');
  const [draftTo, setDraftTo] = useState(search.to ?? '');
  // The range the address shows, or the corpus's last year until one is shown (`seedDefaultsAndApply`).
  const [shown, setShown] = useState(`${search.from ?? ''}|${search.to ?? ''}`);
  if (shown !== `${search.from ?? ''}|${search.to ?? ''}`) {
    setShown(`${search.from ?? ''}|${search.to ?? ''}`);
    setDraftFrom(search.from ?? '');
    setDraftTo(search.to ?? '');
  }
  const from = draftFrom || (context.data?.chronologyFrom ?? '');
  const to = draftTo || (context.data?.chronologyTo ?? '');
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [open, setOpen] = useState<{ spanning: boolean; overflow: boolean }>({ spanning: false, overflow: false });
  const [exportError, setExportError] = useState<string | undefined>(undefined);
  const fromId = useId();
  const toId = useId();

  function change(fields: Partial<ChronologySearch>) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  /** Show: loads the range, every reload clearing the legend's filter (`reload()`). */
  function show(event: FormEvent) {
    event.preventDefault();
    if (!from || !to) return;
    setExpanded(new Set());
    change({ from, to, series: undefined });
  }

  async function exportCSV() {
    if (!ask) return;
    setExportError(undefined);
    try {
      const file = await chronologyCSV(ask);
      saveFile(file.blob, file.name);
    } catch (error) {
      setExportError(errorMessage(error));
    }
  }

  async function exportFigure(format: 'png' | 'svg') {
    if (!ask || !answer) return;
    setExportError(undefined);
    try {
      const [{ renderFigure }, plate] = await Promise.all([import('./VegaChart'), chronologyPlate(ask)]);
      const legend = answer.series.map((series, index) => ({
        title: series.title,
        label: `${series.title}  ${series.total}`,
        color: seriesColor(series.key, index),
      }));
      saveFile(await renderFigure(figureSpec(chronologySpec(answer, { dark: false }), plate, legend), format), `${plate.fileName}.${format}`);
    } catch (error) {
      setExportError(error instanceof ApiError ? errorMessage(error) : exportWords.renderError);
    }
  }

  const unavailable = context.error instanceof ApiError && context.error.code === 'INDEX_NOT_READY';
  const hasChart = answer !== undefined && answer.buckets.length > 0;
  return (
    <div className="chronology-page">
      <h1 tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {unavailable ? (
        <Empty title={words.unavailableTitle} detail={words.unavailableDetail} />
      ) : context.error ? (
        <Empty title={words.errorTitle} detail={errorMessage(context.error)} />
      ) : (
        <>
          <form className="chronology-range" onSubmit={show}>
            <label htmlFor={fromId}>{words.from}</label>
            <input id={fromId} type="date" value={from} max={to || undefined} required onChange={(event) => setDraftFrom(event.target.value)} />
            <span aria-hidden="true">–</span>
            <label htmlFor={toId}>{words.to}</label>
            <input id={toId} type="date" value={to} min={from || undefined} required onChange={(event) => setDraftTo(event.target.value)} />
            <button type="submit" className="primary" disabled={loaded.isFetching}>
              {words.show}
            </button>
          </form>
          {answer && answer.state === 'loaded' && answer.groups.length + (answer.spanning?.rows.length ?? 0) + (answer.overflow?.rows.length ?? 0) > 0 && (
            <p className="chronology-summary">
              <span>{answer.summary}</span>{' '}
              <Link to="/search" search={{ dateRangeEarliest: answer.from, dateRangeLatest: answer.to }}>
                {words.searchRange}
              </Link>
            </p>
          )}
          {answer && answer.state === 'loaded' && (
            <div className="analytics-options">
              <button type="button" aria-pressed={search.chart !== 'hidden'} title={words.chartToggleHelp} disabled={!hasChart}
                onClick={() => change({ chart: search.chart === 'hidden' ? undefined : 'hidden' })}>
                {search.chart === 'hidden' ? words.showChart : words.hideChart}
              </button>
              <button type="button" title={words.sortHelp} onClick={() => change({ order: search.order === 'newest' ? undefined : 'newest' })}>
                {search.order === 'newest' ? words.newestFirst : words.oldestFirst}
              </button>
              <ColorsPicker colors={colors} counts={context.data?.colorCounts ?? [6, 7, 8, 9, 10, 11, 12]} disabled={!hasChart}
                onChange={(count) => {
                  store(storageKeys.colors, String(count));
                  change({ colors: count });
                }} />
              <MenuButton
                label={exportWords.export}
                entries={[
                  { kind: 'item', label: exportWords.exportCSV, onSelect: () => void exportCSV(), disabled: !hasChart },
                  { kind: 'item', label: exportWords.exportPNG, onSelect: () => void exportFigure('png'), disabled: !hasChart },
                  { kind: 'item', label: exportWords.exportSVG, onSelect: () => void exportFigure('svg'), disabled: !hasChart },
                ]}
              />
            </div>
          )}
          {exportError && (
            <div className="analytics-alert" role="alert">
              <strong>{exportWords.exportFailed}</strong> {exportError}
            </div>
          )}
          {!ask ? (
            <Empty title={words.promptTitle} detail={words.promptDetail} />
          ) : loaded.error ? (
            <Empty title={words.errorTitle} detail={errorMessage(loaded.error)} />
          ) : !answer ? (
            <p className="analytics-loading" role="status">
              {words.loading}
            </p>
          ) : answer.state === 'noDocuments' ? (
            <Empty title={words.emptyTitle} detail={words.emptyDetail} />
          ) : (
            <Loaded
              answer={answer}
              dark={scheme === 'dark'}
              showChart={search.chart !== 'hidden'}
              expanded={expanded}
              onExpand={(key) => setExpanded((previous) => new Set(previous).add(key))}
              open={open}
              onToggle={(part) => setOpen((previous) => ({ ...previous, [part]: !previous[part] }))}
              onFilter={(key) => change({ series: answer.filter?.key === key ? undefined : key })}
            />
          )}
        </>
      )}
    </div>
  );
}

function Empty({ title, detail }: { title: string; detail: string }) {
  return (
    <div className="analytics-empty">
      <h2>{title}</h2>
      <p>{detail}</p>
    </div>
  );
}

function ColorsPicker({ colors, counts, disabled, onChange }: { colors: number; counts: number[]; disabled: boolean; onChange: (count: number) => void }) {
  const id = useId();
  return (
    <div className="analytics-field">
      <label htmlFor={id}>{words.colors}</label>
      <select id={id} value={colors} disabled={disabled} title={words.colorsHelp} onChange={(event) => onChange(Number(event.target.value))}>
        {counts.map((count) => (
          <option key={count} value={count}>
            {count}
          </option>
        ))}
      </select>
    </div>
  );
}

/** The loaded range: the chart pane and its table, the chips and their sections, and the date sections. */
function Loaded({
  answer,
  dark,
  showChart,
  expanded,
  onExpand,
  open,
  onToggle,
  onFilter,
}: {
  answer: ChronologyAnswer;
  dark: boolean;
  showChart: boolean;
  expanded: Set<string>;
  onExpand: (key: string) => void;
  open: { spanning: boolean; overflow: boolean };
  onToggle: (part: 'spanning' | 'overflow') => void;
  onFilter: (key: string) => void;
}) {
  const spec = useMemo(() => chronologySpec(answer, { dark }), [answer, dark]);
  const maxCount = Math.max(1, ...answer.groups.map((group) => group.count));
  const spanningId = useId();
  const overflowId = useId();
  return (
    <>
      {showChart && answer.buckets.length > 0 && (
        <section className="analytics-pane chronology-chart" aria-label={words.chartDescription}>
          <div className="analytics-figure">
            <ul className="analytics-legend chronology-legend" aria-label={words.legend}>
              {answer.series.map((series, index) => (
                <li key={series.key}>
                  <button
                    type="button"
                    aria-pressed={answer.filter?.key === series.key}
                    title={words.legendHint}
                    className={answer.filter && answer.filter.key !== series.key ? 'dimmed' : undefined}
                    onClick={() => onFilter(series.key)}
                  >
                    <span className="swatch" style={{ background: seriesColor(series.key, index) }} aria-hidden="true" />
                    <span className="name">{series.title}</span> <span className="total" aria-hidden="true">{series.total}</span>
                    <span className="visually-hidden">, {series.totalPhrase}</span>
                  </button>
                </li>
              ))}
            </ul>
            {answer.filter && (
              <p className="chronology-filter">
                <span>{answer.filter.banner}</span>{' '}
                <button type="button" className="link" onClick={() => onFilter(answer.filter?.key ?? '')}>
                  {words.showAll}
                </button>
              </p>
            )}
            <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
              <VegaChart
                spec={spec}
                label={words.chartDescription}
                onChoose={(datum) => document.getElementById(sectionId(String(datum.bucket ?? '')))?.scrollIntoView({ block: 'start' })}
              />
            </Suspense>
          </div>
          <div className="analytics-table">
            <table>
              <caption>{words.table}</caption>
              <thead>
                <tr>
                  {answer.table.columns.map((column) => (
                    <th key={column} scope="col">
                      {column}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {answer.table.rows.map((row, index) => (
                  <tr key={`${row[0]}-${row[1]}-${index}`}>
                    {row.map((cell, column) => (
                      <td key={column}>{cell}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
      {answer.spanning && <Chip part={answer.spanning} open={open.spanning} controls={spanningId} onToggle={() => onToggle('spanning')} />}
      {answer.overflow && <Chip part={answer.overflow} open={open.overflow} controls={overflowId} onToggle={() => onToggle('overflow')} />}
      <div className="chronology-sections">
        {answer.groups.map((group) => {
          const visible = expanded.has(group.key) ? group.rows : group.rows.slice(0, denseThreshold);
          return (
            <section key={group.key} id={sectionId(group.key)} className="chronology-section" aria-labelledby={`${sectionId(group.key)}-h`}>
              <header>
                <h2 id={`${sectionId(group.key)}-h`}>
                  {group.label} <span className="count">{group.count}</span>
                </h2>
                <span className="density" aria-hidden="true">
                  <span style={{ width: `${Math.max(3, (56 * group.count) / maxCount)}px` }} />
                </span>
                <p>{group.aggregate}</p>
              </header>
              <ul>
                {visible.map((row) => (
                  <Row key={`${row.volumeId}/${row.documentId}`} row={row} />
                ))}
              </ul>
              {group.showAll && !expanded.has(group.key) && (
                <button type="button" className="link" onClick={() => onExpand(group.key)}>
                  {group.showAll}
                </button>
              )}
            </section>
          );
        })}
        {answer.spanning && open.spanning && <ApartSection id={spanningId} part={answer.spanning} />}
        {answer.overflow && open.overflow && <ApartSection id={overflowId} part={answer.overflow} />}
        {answer.totalShown > 0 && <p className="analytics-caption">{words.undatedNote}</p>}
      </div>
    </>
  );
}

/** A section's id among the page's, from its bucket's key. */
function sectionId(key: string): string {
  return `chronology-${key}`;
}

/** A chip under the chart that opens its section of documents set apart. */
function Chip({ part, open, controls, onToggle }: { part: ChronologyApart; open: boolean; controls: string; onToggle: () => void }) {
  return (
    <button type="button" className="chronology-chip" aria-expanded={open} aria-controls={controls} aria-label={part.chipAccessibilityLabel} onClick={onToggle}>
      <span aria-hidden="true">↔ </span>
      <span>{part.chipTitle}</span>
      {part.chipBreakdown && <span className="breakdown"> {part.chipBreakdown}</span>}
    </button>
  );
}

function ApartSection({ id, part }: { id: string; part: ChronologyApart }) {
  return (
    <section id={id} className="chronology-section" aria-labelledby={`${id}-h`}>
      <header>
        <h2 id={`${id}-h`}>{part.header}</h2>
      </header>
      <ul>
        {part.rows.map((row) => (
          <Row key={`${row.volumeId}/${row.documentId}`} row={row} />
        ))}
      </ul>
      <p className="analytics-caption">{part.footer}</p>
    </section>
  );
}

/** A document's row (`ChronologyRowView`): its summary or head, its volume, its dateline or span, its badges. */
function Row({ row }: { row: ChronologyRow }) {
  return (
    <li className="chronology-row">
      <Link to="/doc/$volumeId/$documentId" params={{ volumeId: row.volumeId, documentId: row.documentId }}>
        {row.snippet}
      </Link>
      <span className="volume">{row.volumeTitle}</span>
      <span className="details">
        {row.spanLabel ? <span>{row.spanLabel}</span> : row.dateline ? <span className="dateline">{row.dateline}</span> : null}
        {row.approximate && <span className="badge">{words.approximate}</span>}
        {row.isEditorialNote && <span className="badge">{words.editorialNote}</span>}
        {row.isFrontMatter && <span className="badge">{words.frontMatter}</span>}
      </span>
    </li>
  );
}
