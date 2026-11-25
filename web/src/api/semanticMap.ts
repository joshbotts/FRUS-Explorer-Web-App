// The semantic map (PLAN's S28b): the bundled map's 314,616 points, one binary answer of six bytes a point, and its 140
// regions, read on the server through SemanticVectorsKit and refused there, both alike, when the map's files and the
// bundled vectors disagree. Neither changes while the server runs, so each is fetched once a session.
import { infiniteQueryOptions, keepPreviousData, queryOptions } from '@tanstack/react-query';
import type { ArchivalScope } from './archivalAnalytics';
import { servedPath } from './base';
import { ApiError, getJSON } from './client';
import { appendScope } from './personAnalytics';

/** A region of the map, as the map's index has it. */
export interface SemanticMapRegion {
  /** The id a point's region names. */
  id: number;
  /** Its four terms, most distinctive first. */
  terms: string[];
  documentCount: number;
  /** Its centre on the map's grid. */
  centreX: number;
  centreY: number;
  /** Documents per coverage era, by the era's number. */
  eraCounts: Record<string, number>;
}

/** `GET /api/v1/semantic/map/regions`. */
export interface SemanticMapRegions {
  /** The layout's identity: the vectors' digest, the day it was made and its count. */
  layoutIdentity: string;
  generated: string;
  documentCount: number;
  /** The documents between regions. */
  unclusteredCount: number;
  /** Half the grid's width: every coordinate lies within it of zero. */
  gridExtent: number;
  method: string;
  clustering: string;
  /** By id. */
  regions: SemanticMapRegion[];
}

/** Bytes a point takes in the points' answer: int16 x, int16 y and uint16 region, little-endian. */
export const bytesPerPoint = 6;

/** `GET /api/v1/semantic/map`: the points, as the server sends them. Throws an `ApiError` for an error status. */
export async function semanticMapPoints(signal?: AbortSignal): Promise<ArrayBuffer> {
  const response = await fetch(servedPath('/api/v1/semantic/map'), { signal, headers: { Accept: 'application/octet-stream' } });
  if (!response.ok) throw await ApiError.from(response);
  return response.arrayBuffer();
}

export const semanticMapRegionsQuery = queryOptions({
  queryKey: ['semanticMap', 'regions'],
  queryFn: ({ signal }) => getJSON<SemanticMapRegions>('/api/v1/semantic/map/regions', undefined, signal),
  staleTime: Infinity,
  retry: false,
});

export const semanticMapPointsQuery = queryOptions({
  queryKey: ['semanticMap', 'points'],
  queryFn: ({ signal }) => semanticMapPoints(signal),
  staleTime: Infinity,
  // 1.9 MB, kept while the page is open and for a few minutes after, as it is.
  gcTime: 5 * 60_000,
  structuralSharing: false,
  retry: false,
});

// ─── The map's reading (PLAN's S28c) ─────────────────────────────────────────
// Each answer the kit's (FRUSCoreKit's `Semantic/`, S28a), computed on the server over the bundled map, the vectors'
// index, the catalogue, the bundled source-provenance aggregate and the volumes the server serves.

/** A lens the picker offers, with what its colours mean (`GET /api/v1/semantic/map/reading`). */
export interface SemanticMapLens {
  /** The kit's raw value. */
  id: string;
  name: string;
  /** The key's entries, in palette order. */
  legend: string[];
  caption?: string;
  /** Whether the key names every colour: not the regions', which cycle through the palette. */
  namesEveryColour: boolean;
  /** The sixteen slots' colours, red, green, blue and alpha, each 0 to 1. */
  palette: [number, number, number, number][];
}

export interface SemanticMapReadingContext {
  layoutIdentity: string;
  lenses: SemanticMapLens[];
  /** The administration menu's presidencies, with the volumes of each the map places. */
  administrations: { id: string; president: string; mappedVolumes: number }[];
  mappedVolumes: number;
}

/** A region the keyboard's list names (`GET /api/v1/semantic/map/scope`). */
export interface SemanticMapListedRegion {
  id: number;
  name: string;
  documentCount: number;
  accessibilityLabel: string;
  accessibilityValue: string;
}

export interface SemanticMapScope {
  label?: string;
  volumeIds?: string[];
  documentCount: number;
  volumeCount: number;
  mappedVolumes: number;
  /** The kit's sentence, under a scope alone. */
  summary?: string;
  /** Documents in the scope by region id, under a scope alone. */
  regionCounts?: Record<string, number>;
  /** The regions the names may name, largest first. */
  regions: SemanticMapListedRegion[];
}

/** One region's name for a view, at its middle in the view's CSS pixels (`GET /api/v1/semantic/map/labels`). */
export interface SemanticMapLabel {
  id: number;
  text: string;
  x: number;
  y: number;
  documentCount: number;
}

/** A point's card (`GET /api/v1/semantic/map/pick`). */
export interface SemanticMapPoint {
  row: number;
  volumeId: string;
  documentId: string;
  /** Its place on the grid. */
  x: number;
  y: number;
  regionId?: number;
  regionName?: string;
  headline: string;
  ids: string;
  /** The document's own heading, where the server serves it. */
  title?: string;
  served: boolean;
}

export interface SemanticMapCameraAnswer {
  x: number;
  y: number;
  halfExtent: number;
}

/** Where the map a link names opens (`GET /api/v1/semantic/map/request`). */
export interface SemanticMapRequestAnswer {
  lens: string;
  scopeLabel?: string;
  reveal?: { key: string; revealed: boolean; point?: SemanticMapPoint; camera?: SemanticMapCameraAnswer; volumeTitle: string };
  focus?: { region: number; focused: boolean; camera?: SemanticMapCameraAnswer };
}

/** A region's card, with a page of its documents in the scope (`GET /api/v1/semantic/map/regions/{id}`). */
export interface SemanticMapRegionCard {
  id: number;
  name: string;
  countSummary: string;
  eraRows: { label: string; count: string }[];
  total: number;
  kept: number;
  offset: number;
  documents: { volumeId: string; documentId: string; headline: string; title?: string; served: boolean }[];
}

/** The scope a map is read under: the analytics scope menu's, or a presidency's, as Archival Analytics names them. */
export type SemanticMapScopeAsk = ArchivalScope | undefined;

/** A scope's parameters, as Archival Analytics sends them. */
export function scopeParams(scope: SemanticMapScopeAsk): URLSearchParams {
  const params = new URLSearchParams();
  if (scope?.kind === 'administration') params.set('administration', scope.id);
  else appendScope(params, scope);
  return params;
}

async function bytes(path: string, params: URLSearchParams, signal?: AbortSignal): Promise<Uint8Array> {
  const query = params.toString();
  const url = servedPath(path);
  const response = await fetch(query ? `${url}?${query}` : url, { signal, headers: { Accept: 'application/octet-stream' } });
  if (!response.ok) throw await ApiError.from(response);
  return new Uint8Array(await response.arrayBuffer());
}

export const semanticMapReadingQuery = queryOptions({
  queryKey: ['semanticMap', 'reading'],
  queryFn: ({ signal }) => getJSON<SemanticMapReadingContext>('/api/v1/semantic/map/reading', undefined, signal),
  staleTime: Infinity,
  retry: false,
});

/** A lens's slot for every point, one byte a point, with the lens they are for. */
export function semanticMapLensQuery(lens: string) {
  return queryOptions({
    queryKey: ['semanticMap', 'lens', lens],
    queryFn: async ({ signal }) => ({ lens, slots: await bytes('/api/v1/semantic/map/lens', new URLSearchParams({ lens }), signal) }),
    // On This Server follows the volumes the server serves, so it is asked again when the page is opened again.
    staleTime: lens === 'availability' ? 0 : Infinity,
    gcTime: 5 * 60_000,
    structuralSharing: false,
    retry: false,
    // A lens is drawn until the next one's slots have come.
    placeholderData: keepPreviousData,
  });
}

export function semanticMapScopeQuery(scope: SemanticMapScopeAsk) {
  const params = scopeParams(scope);
  return queryOptions({
    queryKey: ['semanticMap', 'scope', params.toString()],
    queryFn: ({ signal }) => getJSON<SemanticMapScope>('/api/v1/semantic/map/scope', params, signal),
    staleTime: Infinity,
    retry: false,
    placeholderData: keepPreviousData,
  });
}

/** The scope's mask, one byte a point, 1 for a point outside it, with the scope's value it is for. */
export function semanticMapFlagsQuery(scope: SemanticMapScopeAsk, key: string) {
  const params = scopeParams(scope);
  return queryOptions({
    queryKey: ['semanticMap', 'flags', params.toString()],
    queryFn: async ({ signal }) => ({ key, flags: await bytes('/api/v1/semantic/map/scope/flags', params, signal) }),
    staleTime: Infinity,
    gcTime: 5 * 60_000,
    structuralSharing: false,
    retry: false,
    // A scope's ghost is drawn until the next one's mask has come.
    placeholderData: keepPreviousData,
  });
}

/** A view the names are laid out for: the camera on the grid and the view's size in CSS pixels. */
export interface SemanticMapView {
  x: number;
  y: number;
  halfExtent: number;
  width: number;
  height: number;
}

/** The names for a view, with the view they were laid out for. */
export function semanticMapLabelsQuery(view: SemanticMapView, scope: SemanticMapScopeAsk) {
  const params = scopeParams(scope);
  params.set('x', String(view.x));
  params.set('y', String(view.y));
  params.set('halfExtent', String(view.halfExtent));
  params.set('width', String(view.width));
  params.set('height', String(view.height));
  return queryOptions({
    queryKey: ['semanticMap', 'labels', params.toString()],
    queryFn: async ({ signal }) => ({
      view,
      labels: (await getJSON<{ labels: SemanticMapLabel[] }>('/api/v1/semantic/map/labels', params, signal)).labels,
    }),
    staleTime: Infinity,
    gcTime: 60_000,
    retry: false,
    // The last view's names are drawn, carried with the map, until the view at rest has its own.
    placeholderData: keepPreviousData,
  });
}

/** The point nearest a point of the grid, within `tolerance` grid units, under the scope; or none. */
export async function semanticMapPick(x: number, y: number, tolerance: number, scope: SemanticMapScopeAsk): Promise<SemanticMapPoint | undefined> {
  const params = scopeParams(scope);
  params.set('x', String(x));
  params.set('y', String(y));
  params.set('tolerance', String(tolerance));
  return (await getJSON<{ point?: SemanticMapPoint }>('/api/v1/semantic/map/pick', params)).point;
}

/** What a link asks of the map: its lens, its scope, and the document it reveals or the region it focuses. */
export interface SemanticMapLinkAsk {
  lens?: string;
  scope: SemanticMapScopeAsk;
  document?: string;
  region?: number;
  layout?: string;
}

/** Where the map a link names opens: the request's lens, and its reveal or its focus. */
export function semanticMapRequest(ask: SemanticMapLinkAsk, signal?: AbortSignal): Promise<SemanticMapRequestAnswer> {
  const params = scopeParams(ask.scope);
  if (ask.lens) params.set('lens', ask.lens);
  if (ask.document) params.set('document', ask.document);
  if (ask.region !== undefined) params.set('region', String(ask.region));
  if (ask.layout) params.set('layout', ask.layout);
  return getJSON<SemanticMapRequestAnswer>('/api/v1/semantic/map/request', params, signal);
}

/** A document's place, revealed as a link to it reveals it: its point and the camera brought to it, or none. */
export function semanticMapReveal(key: string, scope: SemanticMapScopeAsk): Promise<SemanticMapRequestAnswer> {
  return semanticMapRequest({ scope, document: key });
}

/** How many of a region's documents a page of its card lists. */
export const regionPage = 50;

/** A region's card, a page of its documents at a time, from the first: each page the next `regionPage`, to the capture's most. */
export function semanticMapRegionPages(region: number, layout: string, scope: SemanticMapScopeAsk) {
  const params = scopeParams(scope);
  params.set('layout', layout);
  return infiniteQueryOptions({
    queryKey: ['semanticMap', 'region', region, params.toString()],
    queryFn: ({ signal, pageParam }) => {
      const page = new URLSearchParams(params);
      page.set('offset', String(pageParam));
      page.set('limit', String(regionPage));
      return getJSON<SemanticMapRegionCard>(`/api/v1/semantic/map/regions/${region}`, page, signal);
    },
    initialPageParam: 0,
    getNextPageParam: (last: SemanticMapRegionCard) => {
      const next = last.offset + last.documents.length;
      return last.documents.length > 0 && next < last.kept ? next : undefined;
    },
    staleTime: Infinity,
    retry: false,
  });
}
