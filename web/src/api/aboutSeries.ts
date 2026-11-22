// About the Series (PLAN's S24h): the four dashboards the app's Research Guide shows under About the Series, computed on
// the server from the bundled catalogue and data by the kit's series types (FRUS-Explorer#1899, #1901), each chart with
// the kit's table, the method block's CSV and its figure's caption band.
import { keepPreviousData, queryOptions } from '@tanstack/react-query';
import type { AnalyticsPlate, AnalyticsTable } from './analytics';
import { getFile, getJSON } from './client';
import { withZone } from './personAnalytics';

export type SeriesDashboard = 'production' | 'geography' | 'sourcing' | 'administrations';
export const seriesDashboards: SeriesDashboard[] = ['production', 'geography', 'sourcing', 'administrations'];

/** The series scope (`SeriesScopeBar`): a subseries, a subject, or a reader's volume scope resolved against the series. */
export type SeriesScope =
  | { kind: 'subseries'; subseries: string }
  | { kind: 'topic'; category: string; subcategory: string }
  | { kind: 'volumes'; volumeIds: string[]; label?: string };

export interface SeriesContext {
  pages: { id: string; title: string; subtitle: string; defaultEnd: number }[];
  decades: { label: string; subseries: string[] }[];
  topics: { label: string; items: string[] }[];
  seriesVolumeIds: string[];
  floorYear: number;
  earliestYear: number;
}

export interface SeriesAsk {
  from?: number;
  to?: number;
  scope?: SeriesScope;
  hidden?: string[];
  editorialNotes?: boolean;
  administration?: string;
}

export interface SeriesMark {
  x: string;
  y: number;
  series?: string;
}

export interface SeriesChart {
  id: string;
  title: string;
  caption: string;
  xLabel: string;
  yLabel: string;
  legendTitle?: string;
  table?: AnalyticsTable;
  marks: SeriesMark[];
  steps?: SeriesMark[];
  domain?: number[];
  series: string[];
}

export interface SeriesFrame {
  scopeLabel: string;
  /** The scope's own name, which the menu shows for a scope it does not list. */
  scopeName: string;
  isNarrowed: boolean;
  start: number;
  end: number;
  defaultEnd: number;
  isCustomRange: boolean;
}

export interface SeriesCaveats {
  title: string;
  lines: string[];
}

interface SeriesAnswerBase {
  frame: SeriesFrame;
  empty?: SeriesCaveats;
  intro: string;
  charts: SeriesChart[];
  caveats: SeriesCaveats;
}

export type ProductionAnswer = SeriesAnswerBase;
export type GeographyAnswer = SeriesAnswerBase;

export interface SourcingAnswer extends SeriesAnswerBase {
  supportsScope: boolean;
  filter: {
    label: string;
    accessibilityLabel: string;
    accessibilityValue: string;
    categories: { value: string; name: string; shown: boolean; enabled: boolean }[];
    showAll?: string;
  };
  topCollections: {
    title: string;
    caption: string;
    notice?: string;
    rows: { id: string; label: string; value: number; category: string; categoryName: string; bar: number; opens: boolean }[];
    legend: { category: string; name: string }[];
    footnotes: string[];
    method?: string;
  };
  archivalLink: string;
  archivalLinkDetail: string;
}

export interface AdministrationsAnswer extends SeriesAnswerBase {
  narrowedEmpty?: SeriesCaveats;
  toggle: { title: string; subtitle: string; isOn: boolean };
  detail?: {
    title: string;
    pickerLabel: string;
    choices: { id: string; label: string }[];
    focus: string;
    president: string;
    party: string;
    partyName: string;
    stats: { label: string; value: string }[];
    volumesHeader: string;
    volumesCaption: string;
    volumesEmpty?: string;
    volumes: { id: string; title: string; documents: string; proportion: string }[];
  };
}

export type SeriesAnswer = ProductionAnswer | GeographyAnswer | SourcingAnswer | AdministrationsAnswer;

export function seriesParams(ask: SeriesAsk): URLSearchParams {
  const params = new URLSearchParams();
  if (ask.from !== undefined) params.set('from', String(ask.from));
  if (ask.to !== undefined) params.set('to', String(ask.to));
  const scope = ask.scope;
  if (scope?.kind === 'subseries') params.set('subseries', scope.subseries);
  if (scope?.kind === 'topic') {
    params.set('topic', scope.category);
    params.set('subtopic', scope.subcategory);
  }
  if (scope?.kind === 'volumes') {
    for (const id of scope.volumeIds) params.append('volumes', id);
    if (scope.label) params.set('scopeLabel', scope.label);
  }
  for (const category of ask.hidden ?? []) params.append('hidden', category);
  if (ask.editorialNotes) params.set('editorialNotes', 'true');
  if (ask.administration !== undefined) params.set('administration', ask.administration);
  return params;
}

export const seriesContextQuery = queryOptions({
  queryKey: ['seriesContext'],
  queryFn: ({ signal }) => getJSON<SeriesContext>('/api/v1/about/context', undefined, signal),
  staleTime: 5 * 60_000,
  retry: false,
});

export function seriesQuery<T extends SeriesAnswer>(dashboard: SeriesDashboard, ask: SeriesAsk) {
  const params = seriesParams(ask);
  return queryOptions({
    queryKey: ['seriesDashboard', dashboard, params.toString()],
    queryFn: ({ signal }) => getJSON<T>(`/api/v1/about/${dashboard}`, params, signal),
    staleTime: 5 * 60_000,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

function exportParams(dashboard: SeriesDashboard, chart: string, ask: SeriesAsk): URLSearchParams {
  const params = withZone(seriesParams(ask));
  params.set('dashboard', dashboard);
  params.set('chart', chart);
  return params;
}

export function seriesCSV(dashboard: SeriesDashboard, chart: string, ask: SeriesAsk): Promise<{ blob: Blob; name: string }> {
  return getFile(`/api/v1/about/export?${exportParams(dashboard, chart, ask).toString()}`, 'FRUS-Analytics.csv');
}

export function seriesPlate(dashboard: SeriesDashboard, chart: string, ask: SeriesAsk): Promise<AnalyticsPlate> {
  return getJSON<AnalyticsPlate>('/api/v1/about/plate', exportParams(dashboard, chart, ask));
}
