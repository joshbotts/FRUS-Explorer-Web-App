// The readings of a search's results beside the list (SPEC, Search), as the Mac's window offers them
// in its Reading picker: the timeline, which counts by year the results the search keeps, and the
// concordance, which lines up every occurrence of the search's terms in the page on screen. Each says
// which set it read, in the Mac's words. The server computes both with the kit: the timeline's years
// are its Years facet over what the search keeps, and the concordance its lines for the page, with
// each of its orders, so the browser sorts nothing and counts nothing itself.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { memo, useId, useLayoutEffect, useRef, useState } from 'react';
import { ApiError } from '../api/client';
import { concordanceQuery, timelineQuery } from '../api/endpoints';
import type { ConcordanceLine, ConcordanceOrder, SearchTimeline, TimelineDocument } from '../api/types';
import { copy } from '../copy';
import { pageCount, type Reading, readings, type SearchState } from './searchState';

/**
 * The Reading picker, as the Mac's toolbar draws it: one control whose choices exclude each other,
 * with the set each covers on its tooltip. It reads the words a match found, so it waits for one.
 */
export function ReadingPicker({
  reading,
  disabled,
  onChange,
}: {
  reading: Reading;
  disabled: boolean;
  onChange: (reading: Reading) => void;
}) {
  const labelId = useId();
  return (
    <div className="sort-orders reading-picker" role="group" aria-labelledby={labelId} title={copy.readings.help}>
      <span id={labelId}>{copy.readings.label}</span>
      {readings.map((choice) => (
        <button key={choice} type="button" aria-pressed={choice === reading} disabled={disabled} onClick={() => onChange(choice)}>
          {copy.readings.titles[choice]}
        </button>
      ))}
    </div>
  );
}

/** A reading's failure, in its own words, or the server's when it gives one. */
function failure(error: unknown, fallback: string): string {
  if (error instanceof ApiError) return error.code === 'INDEX_NOT_READY' ? copy.search.notReady(error.problem?.detail ?? '') : error.message;
  return fallback;
}

/** The timeline's two modes, as the Mac's picker offers them. */
export type TimelineMode = 'chart' | 'list';

/**
 * The timeline: the results the search keeps, by year, as a chart with its table or as a list under
 * each year, as the Mac's `DocumentTimelineView` shows them. Above it, when the search reaches the
 * results it keeps, the Mac's caption that the shape is the ranking's; below it, the results it left
 * out for want of a date. With no year to show, only the Mac's view of none dated.
 */
export function TimelineReading({
  state,
  titles,
  mode,
  onMode,
  reviewed = [],
  total,
}: {
  state: SearchState;
  titles: Map<string, string>;
  mode: TimelineMode;
  onMode: (mode: TimelineMode) => void;
  /** The results Checklist Mode hides (S17e), which the timeline leaves out, as the Mac's plots what it leaves. */
  reviewed?: readonly string[];
  /** The match's count, which says whether the results kept were cut, however many the checklist hides. */
  total?: number;
}) {
  const timeline = useQuery(timelineQuery(state, mode === 'list', reviewed));
  const data = timeline.data;
  // The list needs each year's documents; a chart's answer standing in while they load has none.
  const shown = data && (mode === 'chart' || data.years.every((year) => year.documents !== undefined)) ? data : undefined;
  const modeLabel = useId();
  // The Mac's caption follows its rule for a keyword search: the results kept reached their ceiling.
  const partial = data !== undefined && (data.retainedCount >= data.retainedLimit || (total ?? 0) >= data.retainedLimit);
  return (
    <div className="timeline" aria-busy={timeline.isFetching}>
      {/* The modes stay while the list's documents load, so the one chosen keeps its focus. */}
      {data && data.years.length > 0 && (
        <div className="sort-orders timeline-modes" role="group" aria-labelledby={modeLabel}>
          <span id={modeLabel} className="visually-hidden">
            {copy.timeline.viewMode}
          </span>
          {(['chart', 'list'] as const).map((choice) => (
            <button key={choice} type="button" aria-pressed={choice === mode} onClick={() => onMode(choice)}>
              {copy.timeline.modes[choice]}
            </button>
          ))}
        </div>
      )}
      {partial && <p className="caption">{copy.timeline.bias}</p>}
      {timeline.isError && !timeline.isFetching ? (
        <p className="error" role="alert">
          {failure(timeline.error, copy.timeline.failed)}
        </p>
      ) : !shown ? (
        <p role="status">{copy.timeline.loading}</p>
      ) : shown.years.length === 0 ? (
        <div className="empty-reading">
          <h3>{copy.timeline.emptyTitle}</h3>
          <p>{copy.timeline.emptyDetail}</p>
        </div>
      ) : (
        <>
          {mode === 'chart' ? <TimelineChart timeline={shown} /> : <TimelineList timeline={shown} titles={titles} />}
          {shown.undatedCount > 0 && <p className="caption">{copy.timeline.undated(shown.undatedCount)}</p>}
        </>
      )}
    </div>
  );
}

/**
 * The width an element is drawn at, measured before it is first painted and followed as it changes;
 * `fallback` where nothing measures it.
 */
function useWidth(fallback: number) {
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(fallback);
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const initial = element.getBoundingClientRect().width;
    if (initial) setWidth(Math.round(initial));
    if (typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver((entries) => {
      const measured = entries[0]?.contentRect.width;
      if (measured) setWidth(Math.round(measured));
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  return [ref, width] as const;
}

/** A step of 1, 2 or 5 times a power of ten, the least that cuts `span` into at most `count` parts. */
export function niceStep(span: number, count: number): number {
  const raw = Math.max(span, 1) / Math.max(count, 1);
  const power = 10 ** Math.floor(Math.log10(raw));
  for (const multiple of [1, 2, 5]) if (multiple * power >= raw) return multiple * power;
  return 10 * power;
}

/** A column with a 4px round end, square at the baseline, as a chart's data end is drawn. */
function columnPath(x: number, y: number, width: number, height: number): string {
  const radius = Math.min(4, width / 2, height);
  return [
    `M${x},${y + height}`,
    `V${y + radius}`,
    `A${radius},${radius} 0 0 1 ${x + radius},${y}`,
    `H${x + width - radius}`,
    `A${radius},${radius} 0 0 1 ${x + width},${y + radius}`,
    `V${y + height}`,
    'Z',
  ].join(' ');
}

const plotHeight = 180;
const axisBand = 28;
const topPad = 10;
const axisWidth = 40;

/**
 * The chart: a column for each year that holds a result, on an axis from the first year to the last,
 * widened by a year on each side when there is one, as the Mac's chart is. One series, so one colour
 * and no legend; its figures are all in the table beneath it, which assistive technology and the
 * keyboard reach, and the pointer reads a column's year and count above the plot.
 */
function TimelineChart({ timeline }: { timeline: SearchTimeline }) {
  const [plot, width] = useWidth(640);
  const [hovered, setHovered] = useState<string | null>(null);
  const years = timeline.years.map((year) => ({ ...year, number: Number(year.year) })).filter((year) => Number.isFinite(year.number));
  const first = years[0]?.number ?? 0;
  const last = years[years.length - 1]?.number ?? 0;
  const [start, end] = first === last ? [first - 1, last + 1] : [first, last];
  const plotWidth = Math.max(width - axisWidth - 8, 80);
  const band = plotWidth / (end - start + 1);
  const columnWidth = Math.max(1, Math.min(24, band - 2));
  const highest = Math.max(1, ...years.map((year) => year.count));
  const yStep = Math.max(1, niceStep(highest, 4));
  const yTop = Math.ceil(highest / yStep) * yStep;
  const y = (count: number) => topPad + plotHeight - (count / yTop) * plotHeight;
  // A year is the least step the axis takes: two adjacent years would otherwise read "1961.5".
  const xStep = Math.max(1, niceStep(end - start, Math.min(10, Math.max(2, years.length))));
  const xTicks: number[] = [];
  for (let tick = Math.ceil(start / xStep) * xStep; tick <= end; tick += xStep) xTicks.push(tick);
  const x = (year: number) => axisWidth + (year - start) * band;
  const total = years.reduce((sum, year) => sum + year.count, 0);
  const label = copy.timeline.chartLabel(timeline.years[0]?.year ?? '', timeline.years[timeline.years.length - 1]?.year ?? '', total, years.length);
  const hoveredYear = years.find((year) => year.year === hovered);
  return (
    <figure className="timeline-chart">
      <p className="chart-readout" aria-hidden="true">
        {hoveredYear ? copy.timeline.readout(hoveredYear.year, hoveredYear.count) : ' '}
      </p>
      <div ref={plot} className="chart-plot">
        <svg
          role="img"
          aria-label={label}
          width={width}
          height={topPad + plotHeight + axisBand}
          onPointerLeave={() => setHovered(null)}
        >
          {Array.from({ length: yTop / yStep + 1 }, (_, index) => index * yStep).map((tick) => (
            <g key={`y${tick}`}>
              <line className="chart-grid" x1={axisWidth} x2={axisWidth + plotWidth} y1={y(tick)} y2={y(tick)} />
              <text className="chart-tick" x={axisWidth - 6} y={y(tick)} dy="0.32em" textAnchor="end">
                {tick.toLocaleString('en-US')}
              </text>
            </g>
          ))}
          {xTicks.map((tick) => (
            <text key={`x${tick}`} className="chart-tick" x={x(tick) + band / 2} y={topPad + plotHeight + 18} textAnchor="middle">
              {tick}
            </text>
          ))}
          {years.map((year) => {
            const top = y(year.count);
            return (
              <g key={year.year} onPointerEnter={() => setHovered(year.year)}>
                {/* The hit area is the year's whole band, wider than its column. */}
                <rect className="chart-hit" x={x(year.number)} y={topPad} width={band} height={plotHeight} />
                <path
                  className={year.year === hovered ? 'chart-column hovered' : 'chart-column'}
                  d={columnPath(x(year.number) + (band - columnWidth) / 2, top, columnWidth, topPad + plotHeight - top)}
                />
              </g>
            );
          })}
          <line className="chart-axis" x1={axisWidth} x2={axisWidth + plotWidth} y1={topPad + plotHeight} y2={topPad + plotHeight} />
        </svg>
      </div>
      <details className="chart-table">
        <summary>{copy.timeline.table}</summary>
        <table>
          <thead>
            <tr>
              <th scope="col">{copy.timeline.year}</th>
              <th scope="col">{copy.timeline.documents}</th>
            </tr>
          </thead>
          <tbody>
            {timeline.years.map((year) => (
              <tr key={year.year}>
                <th scope="row">{year.year}</th>
                <td>{year.count.toLocaleString('en-US')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </details>
    </figure>
  );
}

/**
 * The list: each year's documents under it, earliest year first, in the order the results are in.
 * Up to 7,500 rows, so it renders again only when its answer or the catalogue's titles change.
 */
const TimelineList = memo(function TimelineList({ timeline, titles }: { timeline: SearchTimeline; titles: Map<string, string> }) {
  return (
    <div className="timeline-list">
      {timeline.years.map((year) => (
        <div key={year.year} className="timeline-year">
          <h3>{year.year}</h3>
          <ul>
            {(year.documents ?? []).map((document) => (
              <TimelineRow key={`${document.volumeId}/${document.documentId}`} document={document} titles={titles} />
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
});

function TimelineRow({ document, titles }: { document: TimelineDocument; titles: Map<string, string> }) {
  return (
    <li>
      <Link to="/doc/$volumeId/$documentId" params={{ volumeId: document.volumeId, documentId: document.documentId }}>
        {document.displayTitle}
      </Link>
      {/* Its volume on a line of its own beneath, as the Mac's timeline lists a document. */}
      <span className="meta">
        {titles.get(document.volumeId) ?? document.volumeId}
        {!document.headerRepeatsNumber && <> · {document.documentLabel}</>}
      </span>
    </li>
  );
}

/**
 * The concordance of the page the results show, as the Mac's `ConcordanceView` lays it out: each
 * occurrence on a line, the term in a column of its own between its left and right contexts, in a
 * monospaced face so the margins line up, and wider than a narrow screen, which scrolls it. Align by
 * chooses among the kit's orders, which the server gives with the lines, so a change of order asks
 * nothing. The count says which documents it read, and two notes what it could not show.
 */
export function ConcordanceReading({
  state,
  total,
  order,
  onOrder,
  reviewed = [],
}: {
  state: SearchState;
  /** The match's count, which the list shows: whether the results have more than one page. */
  total: number;
  order: ConcordanceOrder;
  onOrder: (order: ConcordanceOrder) => void;
  /** The results Checklist Mode hides (S17e), which leave the page the concordance reads. */
  reviewed?: readonly string[];
}) {
  const concordance = useQuery(concordanceQuery(state, reviewed));
  const data = concordance.data;
  const alignId = useId();
  // Lines wider than the screen open with their terms in view, the column a concordance is read down.
  const scroller = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const lines = scroller.current;
    if (lines && lines.scrollWidth > lines.clientWidth) lines.scrollLeft = (lines.scrollWidth - lines.clientWidth) / 2;
  }, [data]);
  if (concordance.isError && !concordance.isFetching) {
    return (
      <p className="error" role="alert">
        {failure(concordance.error, copy.concordance.failed)}
      </p>
    );
  }
  if (!data) return <p role="status">{copy.concordance.loading}</p>;
  const positions = data.orders[order] ?? data.items.map((_, index) => index);
  const singlePage = pageCount(total, data.limit) <= 1;
  return (
    <div className="concordance" aria-busy={concordance.isFetching}>
      <div className="concordance-header">
        <div className="sort-orders" role="group" aria-labelledby={alignId}>
          <span id={alignId}>{copy.concordance.alignBy}</span>
          {data.orderChoices.map((choice) => (
            <button
              key={choice.value}
              type="button"
              aria-pressed={choice.value === order}
              onClick={() => onOrder(choice.value as ConcordanceOrder)}
            >
              {choice.title}
            </button>
          ))}
        </div>
        <p className="caption">{copy.concordance.count(data.items.length, data.documentsOnPage, singlePage)}</p>
      </div>
      {data.items.length === 0 ? (
        <div className="empty-reading">
          <h3>{copy.concordance.emptyTitle}</h3>
          <p>{copy.concordance.emptyDetail}</p>
        </div>
      ) : (
        <div ref={scroller} className="kwic-scroll">
          <ConcordanceLines items={data.items} positions={positions} />
        </div>
      )}
      {(data.omittedCount > 0 || data.documentsWithoutLines > 0) && (
        <div className="caption">
          {data.omittedCount > 0 && data.linesPerDocumentLimit !== undefined && (
            <p>{copy.concordance.omitted(data.omittedCount, data.linesPerDocumentLimit)}</p>
          )}
          {data.documentsWithoutLines > 0 && <p>{copy.concordance.unaligned(data.documentsWithoutLines)}</p>}
        </div>
      )}
    </div>
  );
}

/**
 * The lines in the order chosen. A page of 100 documents can give 20,000, so they render again only
 * when the answer or the order changes.
 */
const ConcordanceLines = memo(function ConcordanceLines({ items, positions }: { items: ConcordanceLine[]; positions: number[] }) {
  return (
    <ol className="kwic" aria-label={copy.concordance.lines}>
      {positions.map((position) => {
        const line = items[position];
        return line ? <ConcordanceRow key={`${line.volumeId}/${line.documentId}#${line.characterOffset}`} line={line} /> : null;
      })}
    </ol>
  );
});

/**
 * One occurrence, which opens its document, as a row of the list does. Read aloud, the line is a
 * sentence, then its document and date, as the Mac's VoiceOver label reads it, since the alignment
 * carries no meaning aloud; the document is named as its row in the results names it, where the
 * Mac's label gives the header as the index stores it.
 */
function ConcordanceRow({ line }: { line: ConcordanceLine }) {
  const source = [line.displayTitle, line.dateISO?.slice(0, 10)].filter(Boolean).join(' · ');
  return (
    <li>
      <Link
        className="kwic-line"
        to="/doc/$volumeId/$documentId"
        params={{ volumeId: line.volumeId, documentId: line.documentId }}
        aria-label={`${line.left} ${line.keyword} ${line.right}. ${source}`.trim()}
      >
        {/* The spaces between the columns are no grid item, and keep a copied line's words apart. */}
        <span className="kwic-left">
          <bdi>{line.left}</bdi>
        </span>{' '}
        <b className="kwic-keyword">{line.keyword}</b> <span className="kwic-right">{line.right}</span>{' '}
        <span className="kwic-source">{source}</span>
      </Link>
    </li>
  );
}
