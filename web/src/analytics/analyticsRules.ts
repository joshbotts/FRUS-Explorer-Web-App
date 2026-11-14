// Corpus Analytics' and Chronology's rules in the browser (PLAN's S24f): what the app's views decide that the
// server's answer leaves to the page, each mirrored from the app's source and held to it by
// CorpusAnalyticsParityTests: the palette (`ChartSeriesPalette`), the year fields' bounds
// (`AnalyticsYearRangeBar`), the scope menu's items (`AnalyticsScopeBar`), the axis menu's sections
// (`groupByChip`), and the charts themselves, drawn by Vega-Lite from the server's series as the app's Swift
// Charts draw them: the stacked bars of By Year and By Decade with their fit line, By Month's bars and By Day's
// points, the breakdowns' horizontal bars with their counts, and Chronology's stacked distribution. The series,
// their folding, shares, tables and words are the kit's, computed on the server.
import type {
  AnalyticsAxis,
  AnalyticsContext,
  AnalyticsMeasure,
  AnalyticsPlate,
  AnalyticsScope,
  AnalyticsValues,
  ChronologyAnswer,
  CorpusAnswer,
} from '../api/analytics';
import type { VolumeScope } from '../api/searchSets';
import { copy } from '../copy';

const words = copy.corpusAnalytics;

// ─── The palette ────────────────────────────────────────────────────────────

/**
 * `ChartSeriesPalette.colors`, the app's twelve system colours in order, as their sRGB values in the light
 * appearance: blue, orange, green, purple, pink, teal, indigo, red, mint, cyan, brown, yellow.
 */
export const chartPalette = [
  '#007AFF', '#FF9500', '#34C759', '#AF52DE', '#FF2D55', '#30B0C7',
  '#5856D6', '#FF3B30', '#00C7BE', '#32ADE6', '#A2845E', '#FFCC00',
];
/** The folded Other volumes' grey (`Color.gray`). */
export const otherGray = '#8E8E93';
/** The app's key for the folded series, the kit's `otherSourceKey` and `chronologyOtherSeriesKey`. */
export const otherKey = '__other__';

/** A series' colour: the palette by its place in the legend, grey for the folded Other (`sourceColor`). */
export function seriesColor(key: string, index: number): string {
  return key === otherKey ? otherGray : (chartPalette[index % chartPalette.length] ?? otherGray);
}

// ─── The year fields ────────────────────────────────────────────────────────

/** A start year as its field takes it: clamped into `1776...end` (`AnalyticsYearRangeBar.yearEntryField`). */
export function clampStart(value: number, end: number, earliest: number): number {
  return Math.min(Math.max(value, earliest), end);
}

/** An end year as its field takes it: clamped into `start...corpusMaxYear`. */
export function clampEnd(value: number, start: number, corpusMaxYear: number): number {
  return Math.min(Math.max(value, start), corpusMaxYear);
}

// ─── The axis menu ──────────────────────────────────────────────────────────

/** Whether an axis places documents in time (`isDateBased`), and whether it breaks them down (`isCategorical`). */
export function isDateBased(axis: AnalyticsAxis): boolean {
  return axis !== 'bySubseries' && axis !== 'byVolume';
}

/** The Group by menu's two sections, Over time and Broken down by, in the axes' order. */
export function axisSections(): { label: string; axes: AnalyticsAxis[] }[] {
  const all: AnalyticsAxis[] = ['byDecade', 'byYear', 'byMonth', 'byDay', 'bySubseries', 'byVolume'];
  return [
    { label: words.overTime, axes: all.filter(isDateBased) },
    { label: words.brokenDown, axes: all.filter((axis) => !isDateBased(axis)) },
  ];
}

// ─── The scope menu ─────────────────────────────────────────────────────────

/** One choice of the scope menu, under a heading, disabled where it holds no indexed volume. */
export interface ScopeOption {
  value: string;
  label: string;
  scope?: AnalyticsScope;
  disabled?: boolean;
}

export interface ScopeGroup {
  label: string;
  options: ScopeOption[];
}

/** The value a scope is chosen by in the menu, and found again by. */
export function scopeValue(scope: AnalyticsScope | undefined): string {
  if (!scope) return 'whole';
  switch (scope.kind) {
    case 'subseries':
      return `subseries:${scope.subseries}`;
    case 'volume':
      return `volume:${scope.volumeId}`;
    case 'topic':
      return `topic:${scope.category}\u001f${scope.subcategory}`;
    case 'volumes':
      return `volumes:${scope.volumeIds.join(',')}`;
  }
}

/**
 * The scope menu's choices, as `AnalyticsScopeBar.scopeMenuItems` offers them: Whole corpus; By Subseries, each
 * indexed subseries; By Volume, each subseries's indexed volumes; My Volume Scopes, the user's, sorted by name,
 * each with its indexed count or disabled when none is indexed; and By Detected Topic, each category's
 * sub-categories with their counts, a sub-category none of whose volumes is indexed disabled.
 */
export function scopeGroups(context: AnalyticsContext, scopes: VolumeScope[] | undefined): ScopeGroup[] {
  const groups: ScopeGroup[] = [{ label: '', options: [{ value: 'whole', label: words.wholeCorpus }] }];
  if (context.subseries.length > 0) {
    groups.push({
      label: words.bySubseries,
      options: context.subseries.map((sub) => ({
        value: `subseries:${sub.name}`,
        label: sub.name,
        scope: { kind: 'subseries', subseries: sub.name },
      })),
    });
    for (const sub of context.subseries) {
      groups.push({
        label: words.byVolumeIn(sub.name),
        options: sub.volumes.map((volume) => ({
          value: `volume:${volume.id}`,
          label: volume.title,
          scope: { kind: 'volume', volumeId: volume.id },
        })),
      });
    }
  }
  if (scopes && scopes.length > 0) {
    const sorted = [...scopes].sort((a, b) => a.name.localeCompare(b.name, 'en', { numeric: true }));
    groups.push({
      label: words.customScopes,
      options: sorted.map((scope) => {
        const indexed = scope.indexedVolumeIds ?? [];
        return indexed.length > 0
          ? {
              value: `volumes:${[...indexed].sort().join(',')}`,
              label: words.customScope(scope.name, indexed.length, scope.volumeIds.length),
              scope: { kind: 'volumes', volumeIds: [...indexed].sort(), label: scope.name },
            }
          : { value: `none:${scope.id}`, label: words.customScopeNone(scope.name), disabled: true };
      }),
    });
  }
  for (const category of context.topics) {
    groups.push({
      label: words.topicGroup(category.label),
      options: category.items.map((item) =>
        item.indexed > 0
          ? {
              value: `topic:${category.label}\u001f${item.subcategory}`,
              label: item.label,
              scope: { kind: 'topic', category: category.label, subcategory: item.subcategory },
            }
          : { value: `none:${category.label}\u001f${item.subcategory}`, label: item.label, disabled: true },
      ),
    });
  }
  return groups;
}

// ─── The addresses ──────────────────────────────────────────────────────────

/** Corpus Analytics' address: the committed term and the chart's state. */
export interface CorpusSearch {
  term?: string;
  axis?: AnalyticsAxis;
  measure?: AnalyticsMeasure;
  values?: AnalyticsValues;
  from?: number;
  to?: number;
  colors?: number;
  fit?: 'off';
  subseries?: string;
  volume?: string;
  topic?: string;
  subtopic?: string;
  volumes?: string[];
  scopeLabel?: string;
}

function text(value: unknown): string | undefined {
  const single = Array.isArray(value) ? value[0] : value;
  return typeof single === 'string' && single !== '' ? single : typeof single === 'number' ? String(single) : undefined;
}

function year(value: unknown): number | undefined {
  const raw = text(value);
  return raw !== undefined && /^\d{4}$/.test(raw) ? Number(raw) : undefined;
}

/** The address's fields, each checked; what does not fit is dropped. */
export function validateCorpusSearch(raw: Record<string, unknown>): CorpusSearch {
  const axis = text(raw.axis);
  const measure = text(raw.measure);
  const values = text(raw.values);
  const colors = Number(text(raw.colors));
  const volumes = (Array.isArray(raw.volumes) ? raw.volumes : raw.volumes === undefined ? [] : [raw.volumes])
    .filter((value): value is string => typeof value === 'string' && value !== '');
  return {
    term: text(raw.term),
    axis: axis && (['byDecade', 'byYear', 'byMonth', 'byDay', 'bySubseries', 'byVolume'] as string[]).includes(axis)
      ? (axis as AnalyticsAxis) : undefined,
    measure: measure === 'documents' || measure === 'occurrences' ? measure : undefined,
    values: values === 'raw' || values === 'percentOfDocuments' ? values : undefined,
    from: year(raw.from),
    to: year(raw.to),
    colors: Number.isInteger(colors) && colors >= 6 && colors <= 12 ? colors : undefined,
    fit: text(raw.fit) === 'off' ? 'off' : undefined,
    subseries: text(raw.subseries),
    volume: text(raw.volume),
    topic: text(raw.topic),
    subtopic: text(raw.subtopic),
    volumes: volumes.length > 0 ? volumes : undefined,
    scopeLabel: text(raw.scopeLabel),
  };
}

/** The scope the address names. */
export function addressScope(search: CorpusSearch): AnalyticsScope | undefined {
  if (search.subseries) return { kind: 'subseries', subseries: search.subseries };
  if (search.volume) return { kind: 'volume', volumeId: search.volume };
  if (search.topic && search.subtopic) return { kind: 'topic', category: search.topic, subcategory: search.subtopic };
  if (search.volumes) return { kind: 'volumes', volumeIds: search.volumes, label: search.scopeLabel };
  return undefined;
}

/** A scope as the address's fields: each of them set or cleared. */
export function scopeFields(scope: AnalyticsScope | undefined): Pick<CorpusSearch, 'subseries' | 'volume' | 'topic' | 'subtopic' | 'volumes' | 'scopeLabel'> {
  return {
    subseries: scope?.kind === 'subseries' ? scope.subseries : undefined,
    volume: scope?.kind === 'volume' ? scope.volumeId : undefined,
    topic: scope?.kind === 'topic' ? scope.category : undefined,
    subtopic: scope?.kind === 'topic' ? scope.subcategory : undefined,
    volumes: scope?.kind === 'volumes' ? scope.volumeIds : undefined,
    scopeLabel: scope?.kind === 'volumes' ? scope.label : undefined,
  };
}

/** Chronology's address: the range shown, its order, the colours, the legend's filter and whether the chart is hidden. */
export interface ChronologySearch {
  from?: string;
  to?: string;
  order?: 'newest';
  colors?: number;
  series?: string;
  chart?: 'hidden';
}

const isoDay = /^\d{4}-\d{2}-\d{2}$/;

export function validateChronologySearch(raw: Record<string, unknown>): ChronologySearch {
  const from = text(raw.from);
  const to = text(raw.to);
  const colors = Number(text(raw.colors));
  const ranged = from !== undefined && to !== undefined && isoDay.test(from) && isoDay.test(to);
  return {
    from: ranged ? from : undefined,
    to: ranged ? to : undefined,
    order: text(raw.order) === 'newest' ? 'newest' : undefined,
    colors: Number.isInteger(colors) && colors >= 6 && colors <= 12 ? colors : undefined,
    series: text(raw.series),
    chart: text(raw.chart) === 'hidden' ? 'hidden' : undefined,
  };
}

// ─── The preferences this browser keeps ─────────────────────────────────────

/** The app's keys for the measure, the values and the colours, which its devices keep (`@AppStorage`). */
export const storageKeys = {
  measure: 'frus.analytics.valueUnit',
  values: 'frus.analytics.normalizationMode',
  colors: 'frus.display.chartSeriesCount',
} as const;

export function stored(key: string): string | undefined {
  try {
    return window.localStorage.getItem(key) ?? undefined;
  } catch {
    return undefined;
  }
}

export function store(key: string, value: string) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // A browser that keeps nothing still draws the chart chosen.
  }
}

// ─── The charts ─────────────────────────────────────────────────────────────

/** A Vega-Lite specification, as the page hands it to Vega. */
export type ChartSpec = Record<string, unknown>;

const font = 'system-ui, -apple-system, "Segoe UI", sans-serif';

/** The look every chart shares: the page's font, no frame, the axes' grid faint. */
function config(dark: boolean): ChartSpec {
  const ink = dark ? '#e6e6e6' : '#1d1d1f';
  const faint = dark ? '#5a5a5e' : '#d2d2d7';
  return {
    font,
    background: null,
    view: { stroke: null },
    axis: { labelColor: ink, titleColor: ink, gridColor: faint, domainColor: faint, tickColor: faint, labelFont: font, titleFont: font },
    title: { color: ink, subtitleColor: ink, font, subtitleFont: font },
    legend: { labelColor: ink, titleColor: ink, labelFont: font },
    text: { color: ink, font },
  };
}

/** The colour scale of a chart's series, in the legend's order. */
function colorScale(series: { key: string }[]) {
  return { domain: series.map((s) => s.key), range: series.map((s, index) => seriesColor(s.key, index)) };
}

/**
 * By Year's and By Decade's chart (`singleTermDateChart`): each period's segments stacked by volume in the
 * legend's order, a period with no denominator left out as the server leaves it, each bar a year or a decade wide
 * over the range's years, and the fit line through the bars' middles.
 */
export function stackedPeriodSpec(answer: CorpusAnswer, options: { fitLine: boolean; dark: boolean }): ChartSpec {
  const decade = answer.axis === 'byDecade';
  const width = decade ? 10 : 1;
  const order = new Map(answer.series.map((s, index) => [s.key, index]));
  const sorted = answer.segments
    .filter((s) => s.plotted !== undefined)
    .sort((a, b) => a.period - b.period || (order.get(a.seriesKey) ?? 0) - (order.get(b.seriesKey) ?? 0));
  const tops = new Map<number, number>();
  const titles = new Map(answer.series.map((s) => [s.key, s.title]));
  const bars = sorted.map((segment) => {
    const base = tops.get(segment.period) ?? 0;
    const top = base + (segment.plotted ?? 0);
    tops.set(segment.period, top);
    return {
      start: segment.period,
      end: segment.period + width,
      y0: base,
      y1: top,
      series: segment.seriesKey,
      volume: titles.get(segment.seriesKey) ?? segment.seriesKey,
      value: segment.plotted,
      count: segment.count,
    };
  });
  const percent = answer.values.isNormalized;
  const domainEnd = decade ? Math.floor(answer.years.end / 10) * 10 + 10 : answer.years.end + 1;
  const domainStart = decade ? Math.floor(answer.years.start / 10) * 10 : answer.years.start;
  const xAxis = { title: answer.periodLabel, format: 'd', labelFlush: true, tickMinStep: width };
  const layers: ChartSpec[] = [
    {
      data: { values: bars },
      mark: { type: 'bar', tooltip: true },
      encoding: {
        x: { field: 'start', type: 'quantitative', scale: { domain: [domainStart, domainEnd], nice: false }, axis: xAxis },
        x2: { field: 'end' },
        y: { field: 'y0', type: 'quantitative', title: answer.valueAxisLabel, axis: percent ? { labelExpr: "datum.label + '%'" } : {} },
        y2: { field: 'y1' },
        color: { field: 'series', type: 'nominal', scale: colorScale(answer.series), legend: null },
        tooltip: [
          { field: 'start', type: 'quantitative', title: answer.periodLabel, format: 'd' },
          { field: 'volume', type: 'nominal', title: words.volume },
          { field: 'value', type: 'quantitative', title: answer.valueAxisLabel, format: percent ? '.1f' : ',d' },
        ],
      },
    },
  ];
  if (options.fitLine && answer.fit.length > 1) {
    layers.push({
      data: { values: answer.fit.map((point) => ({ x: point.period + width / 2, y: point.value })) },
      mark: { type: 'line', interpolate: 'catmull-rom', color: options.dark ? '#bbbbbb' : '#6e6e73', strokeWidth: 2 },
      encoding: { x: { field: 'x', type: 'quantitative' }, y: { field: 'y', type: 'quantitative' } },
    });
  }
  return {
    $schema: 'https://vega.github.io/schema/vega-lite/v6.json',
    description: words.chartDescription(answer.heading),
    width: 'container',
    height: 280,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(options.dark),
    layer: layers,
  };
}

/** A day as Vega-Lite's `DateTime`, in UTC, at its start or its last second. */
function dateTime(year: number, month: number, date: number, end: boolean): ChartSpec {
  return end
    ? { year, month, date, hours: 23, minutes: 59, seconds: 59, utc: true }
    : { year, month, date, utc: true };
}

/** An ISO day as Vega-Lite's `DateTime`. */
function isoDateTime(iso: string, end: boolean): ChartSpec {
  return dateTime(Number(iso.slice(0, 4)), Number(iso.slice(5, 7)), Number(iso.slice(8, 10)), end);
}

/** The day each By Month or By Day label names, at UTC midnight, which Vega places by. */
function labelDate(label: string): string {
  return label.length === 7 ? `${label}-01` : label;
}

/**
 * By Month's bars and By Day's points (`monthChartSection`, `dayChartSection`), over the range's years, with the
 * fit line through them.
 */
export function timeSpec(answer: CorpusAnswer, options: { fitLine: boolean; dark: boolean }): ChartSpec {
  const month = answer.axis === 'byMonth';
  const unit = month ? 'utcyearmonth' : 'utcyearmonthdate';
  const values = answer.points.map((point) => ({ date: labelDate(point.label), label: point.label, count: point.count }));
  // The range's years, 1 January of the first to 31 December of the last (`exportDateDomain`).
  const domain = [dateTime(answer.years.start, 1, 1, false), dateTime(answer.years.end, 12, 31, true)];
  const x = { field: 'date', type: 'temporal', timeUnit: unit, title: answer.periodLabel, scale: { type: 'utc', domain } };
  const ink = options.dark ? '#64a8ff' : '#007AFF';
  const layers: ChartSpec[] = [
    {
      mark: month ? { type: 'bar', color: ink, opacity: 0.65, tooltip: true } : { type: 'point', filled: true, size: 20, color: ink, opacity: 0.55, tooltip: true },
      encoding: {
        x,
        y: { field: 'count', type: 'quantitative', title: answer.valueAxisLabel },
        tooltip: [
          { field: 'label', type: 'nominal', title: answer.periodLabel },
          { field: 'count', type: 'quantitative', title: answer.valueAxisLabel, format: ',d' },
        ],
      },
    },
  ];
  if (options.fitLine && values.length > 1) {
    layers.push({
      mark: { type: 'line', interpolate: 'catmull-rom', color: ink, opacity: month ? 1 : 0.8 },
      encoding: { x: { field: 'date', type: 'temporal', timeUnit: unit }, y: { field: 'count', type: 'quantitative' } },
    });
  }
  return {
    $schema: 'https://vega.github.io/schema/vega-lite/v6.json',
    description: words.chartDescription(answer.heading),
    width: 'container',
    height: 280,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(options.dark),
    data: { values },
    layer: layers,
  };
}

/** By Subseries' and By Volume's horizontal bars, each with its count beside it (`subseriesChartSection`). */
export function breakdownSpec(answer: CorpusAnswer, options: { dark: boolean }): ChartSpec {
  const values = answer.bars.map((bar, index) => ({ label: bar.label, count: bar.count, index }));
  const ink = options.dark ? '#64a8ff' : '#007AFF';
  return {
    $schema: 'https://vega.github.io/schema/vega-lite/v6.json',
    description: words.chartDescription(answer.heading),
    width: 'container',
    height: Math.max(240, answer.bars.length * 28),
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(options.dark),
    data: { values },
    encoding: {
      y: { field: 'label', type: 'nominal', sort: null, title: answer.periodLabel, axis: { labelLimit: 280 } },
      x: { field: 'count', type: 'quantitative', title: answer.valueAxisLabel },
    },
    layer: [
      { mark: { type: 'bar', color: ink, opacity: 0.65, cursor: 'pointer', tooltip: true } },
      { mark: { type: 'text', align: 'left', dx: 4, color: options.dark ? '#bbbbbb' : '#6e6e73' }, encoding: { text: { field: 'count', type: 'quantitative' } } },
    ],
  };
}

/** The chart a corpus answer draws. */
export function corpusSpec(answer: CorpusAnswer, options: { fitLine: boolean; dark: boolean }): ChartSpec {
  if (answer.axis === 'byYear' || answer.axis === 'byDecade') return stackedPeriodSpec(answer, options);
  if (answer.axis === 'byMonth' || answer.axis === 'byDay') return timeSpec(answer, options);
  return breakdownSpec(answer, options);
}

/** Vega's time unit for a Chronology granularity. */
function chronologyUnit(granularity: ChronologyAnswer['granularity']): string {
  return granularity === 'day' ? 'utcyearmonthdate' : granularity === 'month' ? 'utcyearmonth' : 'utcyear';
}

/**
 * Chronology's distribution chart (`distributionChart`): each bucket's documents stacked by volume, the domain the
 * range rounded out to whole buckets.
 */
export function chronologySpec(answer: ChronologyAnswer, options: { dark: boolean }): ChartSpec {
  const order = new Map(answer.series.map((s, index) => [s.key, index]));
  const titles = new Map(answer.series.map((s) => [s.key, s.title]));
  const values = answer.buckets.flatMap((bucket) =>
    bucket.segments.map((segment) => ({
      date: bucket.date,
      bucket: bucket.key,
      label: bucket.label,
      series: segment.seriesKey,
      volume: titles.get(segment.seriesKey) ?? segment.seriesKey,
      count: segment.count,
      order: order.get(segment.seriesKey) ?? 0,
    })),
  );
  return {
    $schema: 'https://vega.github.io/schema/vega-lite/v6.json',
    description: copy.chronology.chartDescription,
    width: 'container',
    height: 150,
    autosize: { type: 'fit-x', contains: 'padding' },
    config: config(options.dark),
    data: { values },
    mark: { type: 'bar', cursor: 'pointer', tooltip: true },
    encoding: {
      x: {
        field: 'date', type: 'temporal', timeUnit: chronologyUnit(answer.granularity), title: copy.chronology.chartX,
        scale: { type: 'utc', domain: [isoDateTime(answer.domainFrom, false), isoDateTime(answer.domainTo, true)] },
        axis: { tickCount: 5 },
      },
      y: { field: 'count', type: 'quantitative', title: copy.chronology.chartY, stack: 'zero' },
      color: { field: 'series', type: 'nominal', scale: colorScale(answer.series), legend: null },
      order: { field: 'order', type: 'quantitative' },
      tooltip: [
        { field: 'label', type: 'nominal', title: copy.chronology.chartX },
        { field: 'volume', type: 'nominal', title: copy.chronology.chartSeries },
        { field: 'count', type: 'quantitative', title: copy.chronology.chartY },
      ],
    },
  };
}

// ─── The exported figure ────────────────────────────────────────────────────

/** A caption line broken into lines of at most `width` characters, at spaces. */
export function wrapped(text: string, width: number): string[] {
  const lines: string[] = [];
  let line = '';
  for (const word of text.split(/\s+/).filter(Boolean)) {
    if (line && line.length + 1 + word.length > width) {
      lines.push(line);
      line = word;
    } else {
      line = line ? `${line} ${word}` : word;
    }
  }
  if (line) lines.push(line);
  return lines.length > 0 ? lines : [''];
}

/**
 * The exported figure (`AnalyticsFigureCanvas`): the plate's title and facts above the chart, its colour key
 * beside the legend's names and totals where the chart has one, and its caveats, the attribution and the pointer to
 * the CSV below, each line the kit's (`plateLines(for:)`), drawn on white at a fixed width.
 */
export function figureSpec(chart: ChartSpec, plate: AnalyticsPlate, legend: { title: string; label: string; color: string }[]): ChartSpec {
  const width = 900;
  const title = plate.lines.find((line) => line.role === 'title')?.text ?? '';
  const facts = plate.lines.filter((line) => line.role === 'facts').map((line) => line.text);
  const below = plate.lines.filter((line) => line.role !== 'title' && line.role !== 'facts');
  const textRows: { y: number; text: string; size: number }[] = [];
  let y = 0;
  for (const line of below) {
    const size = line.role === 'caveat' ? 11 : 10;
    for (const piece of wrapped(line.text, 150)) {
      textRows.push({ y, text: piece, size });
      y += size + 4;
    }
    y += 4;
  }
  // The chart's own layers and data at the figure's width, without its page-wide settings.
  const body = Object.fromEntries(
    Object.entries(chart).filter(([key]) => !['$schema', 'config', 'width', 'autosize', 'description'].includes(key)),
  );
  const parts: ChartSpec[] = [];
  if (legend.length > 0) {
    const legendRows = legend.map((entry, index) => ({ ...entry, column: index % 3, row: Math.floor(index / 3) }));
    parts.push({
      width,
      height: Math.ceil(legend.length / 3) * 16,
      data: { values: legendRows },
      layer: [
        {
          mark: { type: 'square', size: 80 },
          encoding: {
            x: { field: 'column', type: 'quantitative', scale: { domain: [0, 3] }, axis: null },
            y: { field: 'row', type: 'quantitative', scale: { reverse: true, domain: [-0.5, Math.ceil(legend.length / 3) - 0.5] }, axis: null },
            color: { field: 'color', type: 'nominal', scale: null, legend: null },
          },
        },
        {
          mark: { type: 'text', align: 'left', dx: 9, fontSize: 11, limit: width / 3 - 24, color: '#333333' },
          encoding: {
            x: { field: 'column', type: 'quantitative', scale: { domain: [0, 3] }, axis: null },
            y: { field: 'row', type: 'quantitative', scale: { reverse: true, domain: [-0.5, Math.ceil(legend.length / 3) - 0.5] }, axis: null },
            text: { field: 'label', type: 'nominal' },
          },
        },
      ],
    });
  }
  parts.push({ ...body, width });
  parts.push({
    width,
    height: Math.max(y, 1),
    data: { values: textRows },
    mark: { type: 'text', align: 'left', baseline: 'top', color: '#333333' },
    encoding: {
      x: { value: 0 },
      y: { field: 'y', type: 'quantitative', scale: { domain: [0, Math.max(y, 1)], range: [0, Math.max(y, 1)] }, axis: null },
      text: { field: 'text', type: 'nominal' },
      size: { field: 'size', type: 'quantitative', scale: null, legend: null },
    },
  });
  return {
    $schema: 'https://vega.github.io/schema/vega-lite/v6.json',
    title: { text: title, subtitle: facts, anchor: 'start', fontSize: 15, subtitleFontSize: 11, offset: 12 },
    background: '#ffffff',
    padding: 24,
    config: { ...config(false), background: '#ffffff' },
    spacing: 16,
    vconcat: parts,
  };
}
