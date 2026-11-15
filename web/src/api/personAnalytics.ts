// Person Analytics (PLAN's S24g): the most-mentioned people of a range, the trajectories of up to five, the relationship of
// two and the co-mention network around one, computed on the server by the kit's `PersonMentionStore`,
// `PersonAnalyticsMath`, `PersonRelationshipMath` and `PersonCoMentionNetwork` over the served index, with the method
// block's CSV and a figure's caption band. Its queries are kept under `people`, so that the shell asks them again when the
// index changes and a curator's correction of the people asks them again too, as the app's view reloads after one.
import { keepPreviousData, queryOptions } from '@tanstack/react-query';
import type { AnalyticsPlate, AnalyticsScope, AnalyticsTable } from './analytics';
import { getFile, getJSON } from './client';

/** Raw counts or shares of dated documents, `PersonTrajectoryNormalization`. */
export type PersonValues = 'raw' | 'percentOfDocuments';

/** The Trends dashboard's request: the years, the scope, the people compared in the order added, by decade or not. */
export interface PersonAsk {
  from?: number;
  to?: number;
  scope?: AnalyticsScope;
  people: number[];
  decade: boolean;
  values: PersonValues;
}

export interface PersonWords {
  title: string;
  detail: string;
}

export interface PersonAnswer {
  years: { start: number; end: number; isCustom: boolean };
  scope: { label: string; volumeIds?: string[] };
  ranking: {
    heading: string;
    subtitle: string;
    rows: { rollupId: number; name: string; axisLabel: string; mentions: number; mentionsLabel: string }[];
    empty?: PersonWords;
    table: AnalyticsTable;
  };
  comparison: {
    heading: string;
    people: { rollupId: number; name: string }[];
    atCap: boolean;
    capNote: string;
    prompt: string;
    isNormalized: boolean;
    byDecade: boolean;
    periodLabel: string;
    xAxisLabel: string;
    valueAxisLabel: string;
    points: { rollupId: number; name: string; period: number; value: number }[];
    empty?: PersonWords;
    caption: string;
    table: AnalyticsTable;
  };
  relationship?: {
    heading: string;
    subtitle: string;
    xAxisLabel: string;
    valueAxisLabel: string;
    points: { period: number; coMentions: number }[];
    empty?: PersonWords;
    caption: string;
    table: AnalyticsTable;
  };
}

export interface PersonMatches {
  people: { rollupId: number; name: string; mentions: number }[];
}

export interface NetworkNode {
  rollupId: number;
  name: string;
  label: string;
  sharedWithFocus: number;
  isFocus: boolean;
  accessibilityValue?: string;
  sharedLine?: string;
}

export interface NetworkAnswer {
  focus: NetworkNode;
  state: 'graph' | 'empty';
  empty?: PersonWords;
  nodes: NetworkNode[];
  edges: { a: number; b: number; sharedDocuments: number; isSpoke: boolean }[];
  totalPartnerCount: number;
  capApplied: boolean;
  footer: string;
}

/** The charts Person Analytics exports. */
export type PersonChart = 'ranking' | 'trajectories' | 'relationship';

/** A scope's fields, as every analytics route reads them. */
export function appendScope(params: URLSearchParams, scope: AnalyticsScope | undefined) {
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
}

/** The browser's time zone, in which the method block writes the export's moment. */
export function withZone(params: URLSearchParams): URLSearchParams {
  const zoned = new URLSearchParams(params);
  zoned.set('timeZone', Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');
  return zoned;
}

export function personParams(ask: PersonAsk): URLSearchParams {
  const params = new URLSearchParams({ decade: String(ask.decade), values: ask.values });
  if (ask.from !== undefined) params.set('from', String(ask.from));
  if (ask.to !== undefined) params.set('to', String(ask.to));
  for (const id of ask.people) params.append('people', String(id));
  appendScope(params, ask.scope);
  return params;
}

export function personAnalyticsQuery(ask: PersonAsk) {
  const params = personParams(ask);
  return queryOptions({
    queryKey: ['people', 'analytics', params.toString()],
    queryFn: ({ signal }) => getJSON<PersonAnswer>('/api/v1/analytics/people', params, signal),
    staleTime: 60_000,
    retry: false,
    // The charts on show stay while the next are computed, so the controls keep their place.
    placeholderData: keepPreviousData,
  });
}

/** The people whose name holds `text`, for the add field and the focus search; none for a blank field. */
export function personMatchesQuery(text: string) {
  const q = text.trim();
  return queryOptions({
    queryKey: ['people', 'matches', q],
    queryFn: ({ signal }) => getJSON<PersonMatches>('/api/v1/analytics/people/search', new URLSearchParams({ q }), signal),
    enabled: q !== '',
    staleTime: 60_000,
    retry: false,
  });
}

export function networkQuery(focus: number | undefined, scope: AnalyticsScope | undefined) {
  const params = new URLSearchParams({ focus: String(focus ?? '') });
  appendScope(params, scope);
  return queryOptions({
    queryKey: ['people', 'network', params.toString()],
    queryFn: ({ signal }) => getJSON<NetworkAnswer>('/api/v1/analytics/people/network', params, signal),
    enabled: focus !== undefined,
    staleTime: 60_000,
    retry: false,
  });
}

/** A chart's CSV with the kit's method block, named as the app names it. */
export function personCSV(ask: PersonAsk, chart: PersonChart): Promise<{ blob: Blob; name: string }> {
  const params = withZone(personParams(ask));
  params.set('chart', chart);
  return getFile(`/api/v1/analytics/people/export?${params.toString()}`, 'FRUS-Analytics.csv');
}

/** A figure's caption band, written at the moment of its export. */
export function personPlate(ask: PersonAsk, chart: PersonChart): Promise<AnalyticsPlate> {
  const params = withZone(personParams(ask));
  params.set('chart', chart);
  return getJSON<AnalyticsPlate>('/api/v1/analytics/people/plate', params);
}
