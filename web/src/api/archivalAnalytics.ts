// Archival Analytics (PLAN's S24h): where the FRUS editors found what they published, in four modes, computed on the
// server by the kit's archival derivations (FRUS-Explorer#1901) over the bundled authority, usage index, flows and
// citations, and over the served index for Your Library, with the method block's CSV and the ranking's caption band.
import { keepPreviousData, queryOptions } from '@tanstack/react-query';
import type { AnalyticsContext, AnalyticsPlate, AnalyticsScope, AnalyticsTable } from './analytics';
import { getFile, getJSON } from './client';
import { appendScope, withZone } from './personAnalytics';

export type ArchivalMode = 'collections' | 'network' | 'flows' | 'yourLibrary';
export const archivalModes: ArchivalMode[] = ['collections', 'network', 'flows', 'yourLibrary'];

/** A control's choice, its value and the kit's title for it. */
export interface ArchivalOption {
  value: string;
  title: string;
}

/** The archival surface's scope: the analytics scope menu's, over the series, or a presidency's volumes. */
export type ArchivalScope = AnalyticsScope | { kind: 'administration'; id: string };

export interface ArchivalContext {
  modes: ArchivalOption[];
  bands: ArchivalOption[];
  defaultBand: string;
  lenses: ArchivalOption[];
  weights: ArchivalOption[];
  measures: ArchivalOption[];
  expansions: ArchivalOption[];
  layers: ArchivalOption[];
  directions: ArchivalOption[];
  thresholds: number[];
  defaultThreshold: number;
  subseries: AnalyticsContext['subseries'];
  topics: AnalyticsContext['topics'];
  administrations: { id: string; president: string }[];
  seriesVolumeIds: string[];
  indexedVolumeCount: number;
  researchGuide: string;
  methodPointer: string;
  networkUnavailable?: string;
  flowsUnavailable?: string;
}

export interface CollectionsAsk {
  band?: string;
  lens?: string;
  weight?: string;
  umbrella: boolean;
  scope?: ArchivalScope;
}

export interface CollectionsRow {
  id: string;
  label: string;
  category: string;
  categoryName: string;
  value: number;
  gloss?: string;
  glossAlternates: string[];
  accessibilityLabel: string;
  accessibilityValue: string;
  opens: boolean;
}

export interface CollectionsAnswer {
  scope: { label: string; isNarrowed: boolean };
  band: string;
  lens: string;
  weight: string;
  weights: { value: string; title: string; enabled: boolean }[];
  hidesUmbrella: boolean;
  /** The Central Files chip: its caption, the value in force and its two words, the record's spoken name. */
  umbrella?: { caption: string; value: string; accessibilityLabel: string; hidden: string; shown: string };
  denominator?: { sentence: string; pointer?: string };
  ranking: { title: string; caption: string; empty?: string; axisLabel: string; rows: CollectionsRow[]; table?: AnalyticsTable };
  drillInHint?: string;
  showAllUnits?: string;
  families?: { title: string; caption: string; items: { name: string; count: string; leaves: { key: string; gloss?: string; tag: string; value: number }[] }[] };
  caveats: string[];
  timingPointer: string;
}

export interface UnitsAnswer {
  title: string;
  header: string;
  footer: string;
  rows: { rank: string; id: string; label: string; gloss?: string; glossAlternates: string[]; value: number; opens: boolean }[];
}

export interface NetworkAsk {
  focus?: string;
  measure?: string;
  expansion?: string;
  threshold?: number;
  width: number;
  height: number;
  selected?: string;
  group?: string;
  only: boolean;
}

export interface NetworkRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface NetworkNode {
  id: string;
  label: string;
  /** The unit's own name: a class's key, which its documents are asked by. */
  name: string;
  drawnLabel?: string;
  kind: 'collection' | 'centralFileClass';
  category: string;
  categoryName: string;
  sharedVolumes: number;
  sharedDocuments?: number;
  relativeStrength: number;
  radius: number;
  selectedRadius: number;
  accessibilityValue: string;
  isCollection: boolean;
}

export interface NetworkAnswer {
  focus?: { id: string; name: string; label: string; drawnLabel: string };
  measure: string;
  usageAvailable: boolean;
  expansion: string;
  threshold: number;
  thresholdText: string;
  nodes: NetworkNode[];
  layout?: {
    width: number;
    height: number;
    center: { x: number; y: number };
    outerRadius: number;
    ringRadii: number[];
    positions: Record<string, { x: number; y: number }>;
    classHull?: NetworkRect;
    hullCaption?: { text: string; rect: NetworkRect };
    captions: Record<string, { text: string; rect: NetworkRect }>;
  };
  labels: { id: string; text: string; isFocus: boolean; rect: NetworkRect }[];
  plate?: NetworkRect;
  sectors: { category: string; name: string; start: number }[];
  dock: {
    title: string;
    summary: string;
    legend: string[];
    node?: { id: string; name: string; caption: string; detail: string; isCollection: boolean };
    group?: {
      category: string;
      name: string;
      caption: string;
      detail: string;
      rescaled?: string;
      toggle?: string;
      onlyThisGroup: boolean;
      clearLabel: string;
    };
  };
  /** The toolbar's chip for the group selected, whenever one is, a partner in the dock or not. */
  groupChip?: { category: string; name: string; clearLabel: string };
  empty?: { title: string; detail: string };
  table?: AnalyticsTable;
}

export interface FocusCandidates {
  title: string;
  prompt: string;
  candidates: { id: string; name: string; caption: string }[];
}

export interface FlowsAsk {
  layer?: string;
  focus?: string;
  direction?: string;
  selected?: string;
}

export interface FlowEndpoint {
  id: string;
  label: string;
  repository?: string;
  category: string;
  categoryName: string;
  count: number;
  isRemainder: boolean;
  accessibilityValue: string;
  hint: string;
}

export interface FlowsAnswer {
  layer: string;
  direction: string;
  focus?: { id: string; name: string };
  intro: string;
  focusCaption: string;
  focusValue: string;
  clearFocus: string;
  corpusWide?: { title: string; caption: string; pairs: { source: FlowEndpoint; target: FlowEndpoint; count: number; accessibilityLabel: string }[] };
  diagram?: {
    title: string;
    countLabel: string;
    caption: string;
    focusName: string;
    focusCategory: string;
    focusTotal: string;
    endpoints: FlowEndpoint[];
    remainderTitle: string;
    remainder: FlowEndpoint[];
  };
  none?: { title: string; detail: string };
  card?: { title: string; detail: string; collectionId?: string; neighbors: string; openCollection: string };
  caveats: { title: string; lines: string[] };
  table?: AnalyticsTable;
}

export interface LibraryAnswer {
  empty?: { title: string; detail: string };
  intro: string;
  composition: {
    title: string;
    caption: string;
    axisLabel: string;
    legendTitle: string;
    items: { category: string; categoryName: string; documents: number; share: string; accessibilityValue: string }[];
    table: AnalyticsTable;
  };
  bands: {
    title: string;
    caption: string;
    xLabel: string;
    yLabel: string;
    legendTitle: string;
    items: { band: string; category: string; categoryName: string; documents: number }[];
    table: AnalyticsTable;
  };
  collections: {
    title: string;
    caption: string;
    empty?: string;
    hint: string;
    rows: { id: string; name: string; repository?: string; count: string }[];
    table: AnalyticsTable;
  };
  footer: { title: string; lines: string[] };
}

/** The charts Archival Analytics exports. */
export type ArchivalChart = 'ranking' | 'units' | 'network' | 'flows' | 'composition' | 'bands' | 'collections';

function appendArchivalScope(params: URLSearchParams, scope: ArchivalScope | undefined) {
  if (scope?.kind === 'administration') params.set('administration', scope.id);
  else appendScope(params, scope);
}

export function collectionsParams(ask: CollectionsAsk): URLSearchParams {
  const params = new URLSearchParams({ umbrella: String(ask.umbrella) });
  if (ask.band !== undefined) params.set('band', ask.band);
  if (ask.lens !== undefined) params.set('lens', ask.lens);
  if (ask.weight !== undefined) params.set('weight', ask.weight);
  appendArchivalScope(params, ask.scope);
  return params;
}

export function networkParams(ask: NetworkAsk): URLSearchParams {
  const params = new URLSearchParams({ width: String(ask.width), height: String(ask.height) });
  if (ask.focus !== undefined) params.set('focus', ask.focus);
  if (ask.measure !== undefined) params.set('measure', ask.measure);
  if (ask.expansion !== undefined) params.set('expansion', ask.expansion);
  if (ask.threshold !== undefined) params.set('threshold', ask.threshold.toFixed(2));
  if (ask.selected !== undefined) params.set('selected', ask.selected);
  if (ask.group !== undefined) params.set('group', ask.group);
  if (ask.only) params.set('only', 'true');
  return params;
}

export function flowsParams(ask: FlowsAsk): URLSearchParams {
  const params = new URLSearchParams();
  if (ask.layer !== undefined) params.set('layer', ask.layer);
  if (ask.focus !== undefined) params.set('focus', ask.focus);
  if (ask.direction !== undefined) params.set('direction', ask.direction);
  if (ask.selected !== undefined) params.set('selected', ask.selected);
  return params;
}

export const archivalContextQuery = queryOptions({
  queryKey: ['archivalContext'],
  queryFn: ({ signal }) => getJSON<ArchivalContext>('/api/v1/analytics/archives/context', undefined, signal),
  staleTime: 5 * 60_000,
  retry: false,
});

export function collectionsQuery(ask: CollectionsAsk) {
  const params = collectionsParams(ask);
  return queryOptions({
    queryKey: ['archivalCollections', params.toString()],
    queryFn: ({ signal }) => getJSON<CollectionsAnswer>('/api/v1/analytics/archives', params, signal),
    staleTime: 5 * 60_000,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

export function unitsQuery(ask: CollectionsAsk, enabled: boolean) {
  const params = collectionsParams(ask);
  return queryOptions({
    queryKey: ['archivalUnits', params.toString()],
    queryFn: ({ signal }) => getJSON<UnitsAnswer>('/api/v1/analytics/archives/units', params, signal),
    staleTime: 5 * 60_000,
    retry: false,
    enabled,
  });
}

export function networkQuery(ask: NetworkAsk, enabled: boolean) {
  const params = networkParams(ask);
  return queryOptions({
    queryKey: ['archivalNetwork', params.toString()],
    queryFn: ({ signal }) => getJSON<NetworkAnswer>('/api/v1/analytics/archives/network', params, signal),
    staleTime: 5 * 60_000,
    retry: false,
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function networkCandidatesQuery(text: string, enabled: boolean) {
  return queryOptions({
    queryKey: ['archivalNetworkCandidates', text],
    queryFn: ({ signal }) => getJSON<FocusCandidates>('/api/v1/analytics/archives/network/candidates', new URLSearchParams({ q: text }), signal),
    staleTime: 5 * 60_000,
    retry: false,
    enabled,
    placeholderData: keepPreviousData,
  });
}

export function flowsQuery(ask: FlowsAsk, enabled = true) {
  const params = flowsParams(ask);
  return queryOptions({
    queryKey: ['archivalFlows', params.toString()],
    queryFn: ({ signal }) => getJSON<FlowsAnswer>('/api/v1/analytics/archives/flows', params, signal),
    enabled,
    staleTime: 5 * 60_000,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

export function flowsCandidatesQuery(layer: string | undefined, text: string, enabled: boolean) {
  const params = new URLSearchParams({ q: text });
  if (layer !== undefined) params.set('layer', layer);
  return queryOptions({
    queryKey: ['archivalFlowsCandidates', params.toString()],
    queryFn: ({ signal }) => getJSON<FocusCandidates>('/api/v1/analytics/archives/flows/candidates', params, signal),
    staleTime: 5 * 60_000,
    retry: false,
    enabled,
    placeholderData: keepPreviousData,
  });
}

/** Your Library, the served index's: asked again when the index changes (`corpusQueryKeys`). */
export const libraryQuery = queryOptions({
  queryKey: ['archivalLibrary'],
  queryFn: ({ signal }) => getJSON<LibraryAnswer>('/api/v1/analytics/archives/library', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

/** A chart's parameters: the mode's own. */
function chartParams(chart: ArchivalChart, asks: { collections: CollectionsAsk; network: NetworkAsk; flows: FlowsAsk }): URLSearchParams {
  switch (chart) {
    case 'ranking':
    case 'units':
      return collectionsParams(asks.collections);
    case 'network': {
      const params = networkParams(asks.network);
      // The neighbourhood's table is the graph's, whatever the canvas draws.
      for (const name of ['width', 'height', 'selected', 'group', 'only']) params.delete(name);
      return params;
    }
    case 'flows': {
      const params = flowsParams(asks.flows);
      params.delete('selected');
      return params;
    }
    default:
      return new URLSearchParams();
  }
}

export function archivalCSV(
  chart: ArchivalChart,
  asks: { collections: CollectionsAsk; network: NetworkAsk; flows: FlowsAsk },
): Promise<{ blob: Blob; name: string }> {
  const params = withZone(chartParams(chart, asks));
  params.set('chart', chart);
  return getFile(`/api/v1/analytics/archives/export?${params.toString()}`, 'FRUS-Analytics.csv');
}

export function archivalPlate(collections: CollectionsAsk): Promise<AnalyticsPlate> {
  const params = withZone(collectionsParams(collections));
  params.set('chart', 'ranking');
  return getJSON<AnalyticsPlate>('/api/v1/analytics/archives/plate', params);
}
