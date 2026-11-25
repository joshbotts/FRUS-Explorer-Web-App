// Project Home's reach (PLAN's S26d): the volumes the project's documents reach that the served index does not hold,
// the kit's `SemanticProjectReach` on the server, read beside Project Home with the tuning this browser keeps, which
// the project's own replaces there, as a Refresh brings it.
import { queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';
import { storedWeights } from './related';

export interface ProjectReach {
  /** Ranked by the seeds that reach each, then its documents, five at most. */
  volumes: { volumeId: string; title: string; documentCount: number; reachingSeeds: number }[];
  documentCount: number;
  seedsProbed: number;
}

const segment = encodeURIComponent;

export function projectReachQuery(projectId: string) {
  const weights = storedWeights();
  const params = new URLSearchParams();
  if (weights) params.set('weights', weights);
  return queryOptions({
    queryKey: ['projectReach', projectId, weights ?? ''],
    queryFn: ({ signal }) => getJSON<ProjectReach>(`/api/v1/me/projects/${segment(projectId)}/reach`, params, signal),
    staleTime: 30_000,
    retry: false,
  });
}
