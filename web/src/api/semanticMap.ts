// The semantic map (PLAN's S28b): the bundled map's 314,616 points, one binary answer of six bytes a point, and its 140
// regions, read on the server through SemanticVectorsKit and refused there, both alike, when the map's files and the
// bundled vectors disagree. Neither changes while the server runs, so each is fetched once a session.
import { queryOptions } from '@tanstack/react-query';
import { servedPath } from './base';
import { ApiError, getJSON } from './client';

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
