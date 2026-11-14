// Corpus Analytics and Chronology (PLAN's S24f): a term's chart and a range's documents, computed on the server by
// the kit's `CorpusAnalyticsService` and `ChronologyGrouping` over the served index, with the method block's CSV
// and a figure's caption band (`AnalyticsProvenance`), and the context both screens open on.
import { keepPreviousData, queryOptions } from '@tanstack/react-query';
import { getFile, getJSON } from './client';

/** One of the app's six axes, `AnalyticsChartAxis`. */
export type AnalyticsAxis = 'byDecade' | 'byYear' | 'byMonth' | 'byDay' | 'bySubseries' | 'byVolume';
/** What the numbers count, `AnalyticsValueUnit`. */
export type AnalyticsMeasure = 'documents' | 'occurrences';
/** Raw counts or shares, `AnalyticsNormalizationMode`. */
export type AnalyticsValues = 'raw' | 'percentOfDocuments';

/** The axes in the app's order, the date-based first (`AnalyticsChartAxis.allCases`). */
export const analyticsAxes: AnalyticsAxis[] = ['byDecade', 'byYear', 'byMonth', 'byDay', 'bySubseries', 'byVolume'];

/** The scope a chart counts: the whole corpus, or one the scope menu names. */
export type AnalyticsScope =
  | { kind: 'subseries'; subseries: string }
  | { kind: 'volume'; volumeId: string }
  | { kind: 'topic'; category: string; subcategory: string }
  | { kind: 'volumes'; volumeIds: string[]; label?: string };

/** A chart's request: the term, the axis, the measure and values, the years, the scope and the colours. */
export interface CorpusAsk {
  term: string;
  axis: AnalyticsAxis;
  measure: AnalyticsMeasure;
  values: AnalyticsValues;
  from?: number;
  to?: number;
  colors?: number;
  scope?: AnalyticsScope;
}

export interface AnalyticsPreset {
  label: string;
  start: number;
  end: number;
}

export interface AnalyticsTopicItem {
  subcategory: string;
  /** "Arms control (3 of 5 indexed)", or "… — none indexed yet". */
  label: string;
  indexed: number;
  total: number;
}

export interface AnalyticsContext {
  floorYear: number;
  corpusMaxYear: number;
  earliestYear: number;
  chronologyFrom: string;
  chronologyTo: string;
  presets: AnalyticsPreset[];
  colorCounts: number[];
  defaultColors: number;
  indexedVolumeCount: number;
  subseries: { name: string; volumes: { id: string; title: string }[] }[];
  topics: { label: string; items: AnalyticsTopicItem[] }[];
}

/** A table behind a chart, the kit's `ChartInspectorData`. */
export interface AnalyticsTable {
  title: string;
  columns: string[];
  rows: string[][];
}

export interface CorpusAnswer {
  term: string;
  axis: AnalyticsAxis;
  axisLabel: string;
  state: 'chart' | 'exactUnsupported' | 'empty';
  stateTitle?: string;
  stateDetail?: string;
  heading: string;
  figureTitle: string;
  valueAxisLabel: string;
  periodLabel: string;
  measure: { chosen: AnalyticsMeasure; effective: AnalyticsMeasure; applies: boolean; available: boolean; reason?: string; notice?: string };
  values: { chosen: AnalyticsValues; applies: boolean; enabled: boolean; isNormalized: boolean };
  years: { start: number; end: number; isCustom: boolean; applies: boolean };
  scope: { label: string; volumeIds?: string[] };
  colors: number;
  segments: { period: number; seriesKey: string; count: number; plotted?: number }[];
  series: { key: string; title: string; total: number; totalLabel: string; isOther: boolean }[];
  fit: { period: number; value: number }[];
  points: { label: string; count: number }[];
  notice?: { title: string; detail: string };
  bars: { label: string; count: number; volumeIds: string[] }[];
  normalizationCaption?: string;
  footnote?: string;
  fullCorpusTotal?: string;
  matchedDocumentCount: number;
  table: AnalyticsTable;
}

/** Search's count of the documents the hand-off link opens, and the search it opens. */
export interface CorpusDocuments {
  count: number;
  linkTitle: string;
  dispersion?: string;
  search: {
    keywords: string;
    dateRangeEarliest?: string;
    dateRangeLatest?: string;
    volumeIds?: string[];
    includeNotes: boolean;
    includeSummaries: boolean;
  };
}

/** A range's request: two days, the order, the colours and the legend's filter. */
export interface ChronologyAsk {
  from: string;
  to: string;
  newest?: boolean;
  colors?: number;
  series?: string;
}

export interface ChronologyRow {
  volumeId: string;
  documentId: string;
  snippet: string;
  volumeTitle: string;
  dateline?: string;
  spanLabel?: string;
  approximate: boolean;
  isEditorialNote: boolean;
  isFrontMatter: boolean;
}

export interface ChronologyApart {
  chipTitle: string;
  chipBreakdown?: string;
  chipAccessibilityLabel: string;
  header: string;
  footer: string;
  rows: ChronologyRow[];
}

export interface ChronologyAnswer {
  from: string;
  to: string;
  ascending: boolean;
  granularity: 'day' | 'month' | 'year';
  domainFrom: string;
  domainTo: string;
  state: 'loaded' | 'noDocuments';
  totalShown: number;
  isCapped: boolean;
  chartShowsFullDistribution: boolean;
  summary: string;
  buckets: { key: string; label: string; date: string; segments: { seriesKey: string; count: number }[]; total: number }[];
  series: { key: string; title: string; total: number; totalPhrase: string; isOther: boolean }[];
  colors: number;
  filter?: { key: string; title: string; banner: string };
  groups: { key: string; label: string; count: number; aggregate: string; showAll?: string; rows: ChronologyRow[] }[];
  spanning?: ChronologyApart;
  overflow?: ChronologyApart;
  table: AnalyticsTable;
}

/** A figure's caption band, the kit's `plateLines(for:)`, and the name its file is saved under. */
export interface AnalyticsPlate {
  lines: { role: 'title' | 'facts' | 'caveat' | 'attribution' | 'dataPointer'; text: string }[];
  fileName: string;
}

/** A chart's request as the routes read it. */
export function corpusParams(ask: CorpusAsk): URLSearchParams {
  const params = new URLSearchParams({ term: ask.term, axis: ask.axis, measure: ask.measure, values: ask.values });
  if (ask.from !== undefined) params.set('from', String(ask.from));
  if (ask.to !== undefined) params.set('to', String(ask.to));
  if (ask.colors !== undefined) params.set('colors', String(ask.colors));
  const scope = ask.scope;
  if (scope?.kind === 'subseries') params.set('subseries', scope.subseries);
  if (scope?.kind === 'volume') params.set('volume', scope.volumeId);
  if (scope?.kind === 'topic') {
    params.set('topic', scope.category);
    params.set('subtopic', scope.subcategory);
  }
  if (scope?.kind === 'volumes') {
    for (const id of scope.volumeIds) params.append('volumes', id);
    if (scope.label) params.set('scopeLabel', scope.label);
  }
  return params;
}

/** A range's request as the route reads it. */
export function chronologyParams(ask: ChronologyAsk): URLSearchParams {
  const params = new URLSearchParams({ from: ask.from, to: ask.to, order: ask.newest ? 'newest' : 'oldest' });
  if (ask.colors !== undefined) params.set('colors', String(ask.colors));
  if (ask.series) params.set('series', ask.series);
  return params;
}

export const analyticsContextQuery = queryOptions({
  queryKey: ['analyticsContext'],
  queryFn: ({ signal }) => getJSON<AnalyticsContext>('/api/v1/analytics/context', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

export function corpusChartQuery(ask: CorpusAsk) {
  const params = corpusParams(ask);
  return queryOptions({
    queryKey: ['corpusChart', params.toString()],
    queryFn: ({ signal }) => getJSON<CorpusAnswer>('/api/v1/analytics/corpus', params, signal),
    staleTime: 60_000,
    retry: false,
    // The chart on show stays while the next is computed, so the controls keep their place.
    placeholderData: keepPreviousData,
  });
}

export function corpusDocumentsQuery(ask: CorpusAsk) {
  const params = corpusParams(ask);
  return queryOptions({
    queryKey: ['corpusDocuments', params.toString()],
    queryFn: ({ signal }) => getJSON<CorpusDocuments>('/api/v1/analytics/corpus/documents', params, signal),
    staleTime: 60_000,
    retry: false,
  });
}

export function chronologyQuery(ask: ChronologyAsk) {
  const params = chronologyParams(ask);
  return queryOptions({
    queryKey: ['chronology', params.toString()],
    queryFn: ({ signal }) => getJSON<ChronologyAnswer>('/api/v1/chronology', params, signal),
    staleTime: 60_000,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

/** The browser's time zone, in which the method block writes the export's moment. */
function withZone(params: URLSearchParams): URLSearchParams {
  const zoned = new URLSearchParams(params);
  zoned.set('timeZone', Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');
  return zoned;
}

/** A chart's CSV with the kit's method block, named as the app names it. */
export function corpusCSV(ask: CorpusAsk): Promise<{ blob: Blob; name: string }> {
  return getFile(`/api/v1/analytics/corpus/export?${withZone(corpusParams(ask)).toString()}`, 'FRUS-Analytics.csv');
}

export function chronologyCSV(ask: ChronologyAsk): Promise<{ blob: Blob; name: string }> {
  return getFile(`/api/v1/chronology/export?${withZone(chronologyParams(ask)).toString()}`, 'FRUS-Analytics.csv');
}

/** A figure's caption band, written at the moment of its export. */
export function corpusPlate(ask: CorpusAsk): Promise<AnalyticsPlate> {
  return getJSON<AnalyticsPlate>('/api/v1/analytics/corpus/plate', withZone(corpusParams(ask)));
}

export function chronologyPlate(ask: ChronologyAsk): Promise<AnalyticsPlate> {
  return getJSON<AnalyticsPlate>('/api/v1/chronology/plate', withZone(chronologyParams(ask)));
}
