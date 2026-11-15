// Cross-Reference Analytics (PLAN's S24g): the most-referenced documents, the degree distribution, the volume heat
// matrix and the PageRank landmarks, with the broken references excluded and said, computed on the server by the kit's
// `CrossReferenceStore`, `CrossReferenceStats` and `PageRank` over the served index, with the method block's CSV and a
// figure's caption band.
import { keepPreviousData, queryOptions } from '@tanstack/react-query';
import type { AnalyticsPlate, AnalyticsScope, AnalyticsTable } from './analytics';
import { getFile, getJSON } from './client';
import { appendScope, withZone } from './personAnalytics';

export interface CrossReferenceAsk {
  from?: number;
  to?: number;
  scope?: AnalyticsScope;
  outDegree: boolean;
}

export interface ReferencedDocument {
  volumeId: string;
  documentId: string;
  label: string;
  isIndexed: boolean;
}

export interface DegreeBucket {
  degree: number;
  label: string;
  documentCount: number;
}

export interface CrossReferenceAnswer {
  years: { start: number; end: number; isCustom: boolean };
  scope: { label: string; volumeIds?: string[] };
  resolvedCaption: string;
  excludedBrokenCount: number;
  excludedBrokenCaption?: string;
  emptyTitle: string;
  ranking: {
    heading: string;
    subtitle: string;
    rows: { document: ReferencedDocument; axisLabel: string; inDegree: number; valueLabel: string }[];
    empty?: string;
    table: AnalyticsTable;
  };
  distribution: {
    heading: string;
    subtitle: string;
    inDegree: DegreeBucket[];
    outDegree: DegreeBucket[];
    showsOutDegree: boolean;
    empty?: string;
    table: AnalyticsTable;
  };
  matrix: {
    heading: string;
    subtitle: string;
    volumes: { id: string; code: string; topic: string; tag: string; title: string }[];
    rows: { count: number; help: string; accessibilityLabel: string }[][];
    maxCount: number;
    empty?: string;
    legend: { low: string; high: string; max?: string };
    table: AnalyticsTable;
  };
  landmarks: {
    heading: string;
    subtitle: string;
    rows: { document: ReferencedDocument; score: number; scoreLabel: string; fraction: number }[];
    empty?: string;
    table: AnalyticsTable;
  };
}

/** The charts Cross-Reference Analytics exports. */
export type CrossReferenceChart = 'ranking' | 'distribution' | 'matrix' | 'landmarks';

export function crossReferenceParams(ask: CrossReferenceAsk): URLSearchParams {
  const params = new URLSearchParams({ outDegree: String(ask.outDegree) });
  if (ask.from !== undefined) params.set('from', String(ask.from));
  if (ask.to !== undefined) params.set('to', String(ask.to));
  appendScope(params, ask.scope);
  return params;
}

export function crossReferenceAnalyticsQuery(ask: CrossReferenceAsk) {
  const params = crossReferenceParams(ask);
  return queryOptions({
    queryKey: ['crossReferenceAnalytics', params.toString()],
    queryFn: ({ signal }) => getJSON<CrossReferenceAnswer>('/api/v1/analytics/cross-references', params, signal),
    staleTime: 60_000,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

export function crossReferenceCSV(ask: CrossReferenceAsk, chart: CrossReferenceChart): Promise<{ blob: Blob; name: string }> {
  const params = withZone(crossReferenceParams(ask));
  params.set('chart', chart);
  return getFile(`/api/v1/analytics/cross-references/export?${params.toString()}`, 'FRUS-Analytics.csv');
}

export function crossReferencePlate(ask: CrossReferenceAsk, chart: CrossReferenceChart): Promise<AnalyticsPlate> {
  const params = withZone(crossReferenceParams(ask));
  params.set('chart', chart);
  return getJSON<AnalyticsPlate>('/api/v1/analytics/cross-references/plate', params);
}
