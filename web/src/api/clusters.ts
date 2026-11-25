// Browse's clusters (PLAN's S28d): the semantic map's regions as the Mac's Browse lists them (`ClustersIndexView`) and a
// region's documents as it opens one (`ClusterDocumentsView`), each the kit's `ClustersAxis` (S28a) on the server, over
// the map's reading (S28c); and Save as Working Corpus, the kit's capture of a region's members, at the app's 7,500.
import { infiniteQueryOptions, queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import type { CorpusCoverage, WorkingCorpus, WorkingCorpusDetail } from './searchSets';
import { change } from './userData';

/** One bar of a region's eras' histogram: an era's documents, or the pooled bar of the volumes no era dates. */
export interface ClusterEraBar {
  /** The coverage era's number, or absent for the pooled bar. */
  era?: number;
  count: number;
  /** One of the two largest bars, which the app accents. */
  isPeak: boolean;
}

/** A region, as the index's row shows it. */
export interface ClusterRow {
  id: number;
  /** Its four terms, a term list: `shah · iran · iranian · mosadeq`. */
  label: string;
  documentCount: number;
  /** Oldest era first, each era in its slot, so that every row's histogram lines up. */
  eras: ClusterEraBar[];
}

/** `GET /api/v1/clusters`: the regions, largest first, ties by id. */
export interface ClustersIndex {
  /** The layout's identity, against which alone a region's id means anything. */
  layoutIdentity: string;
  clusterCount: number;
  documentCount: number;
  /** The documents between regions, which no list reaches. */
  unclusteredCount: number;
  clusters: ClusterRow[];
}

/** `GET /api/v1/clusters/{id}`: a region's documents, a page of its members at a time. */
export interface ClusterDocuments {
  id: number;
  label: string;
  /** The map's form of its name, its first three terms, which a saved corpus is named by. */
  name: string;
  layoutIdentity: string;
  /** Documents in the series. */
  documentCount: number;
  /** Its eras' rows, the kit's, in US English. */
  eraRows: { label: string; count: string }[];
  /** Every member, which Save as Working Corpus captures from. */
  total: number;
  /** What the served index holds of the members; absent while no index is served. */
  coverage?: CorpusCoverage;
  /** How many members, in volume order, the page lists; and how many the pages before it listed. */
  shown: number;
  after: number;
  /** The listed members' sections: every one, or after the first page, those of the volumes with a member it added. */
  sections: WorkingCorpusDetail['sections'];
}

/** How many members the app's drill lists first and adds at each "Show more". */
export const clusterPage = 500;

export const clustersIndexQuery = queryOptions({
  queryKey: ['clusters'],
  queryFn: ({ signal }) => getJSON<ClustersIndex>('/api/v1/clusters', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

/** A page of a region's documents: the members listed, and those listed by the pages before. */
interface ClusterPageParam {
  shown: number;
  after: number;
}

/**
 * A region's documents, 500 more at each page, as the app's "Show more" adds them, by the id its address names, in the
 * layout `layout` names: every section of the first page, and after it the sections a page changed, which
 * `clusterSections` merges. Kept for half an hour, so that a document opened from deep in the list comes back to the
 * list as it was.
 */
export function clusterDocumentsQuery(id: string, layout: string | undefined) {
  return infiniteQueryOptions({
    queryKey: ['clusters', id, layout ?? ''],
    queryFn: ({ signal, pageParam }: { signal: AbortSignal; pageParam: ClusterPageParam }) => {
      const params = new URLSearchParams({ shown: String(pageParam.shown) });
      if (pageParam.after > 0) params.set('after', String(pageParam.after));
      if (layout) params.set('layout', layout);
      return getJSON<ClusterDocuments>(`/api/v1/clusters/${encodeURIComponent(id)}`, params, signal);
    },
    initialPageParam: { shown: clusterPage, after: 0 } as ClusterPageParam,
    getNextPageParam: (last: ClusterDocuments): ClusterPageParam | undefined =>
      last.shown < last.total ? { shown: Math.min(last.shown + clusterPage, last.total), after: last.shown } : undefined,
    staleTime: 60_000,
    gcTime: 30 * 60_000,
    refetchOnWindowFocus: false,
    retry: false,
  });
}

/**
 * The sections of every member the pages list: each page's sections in order, a section of a volume an earlier page
 * listed replacing it where it stands, since the server gives the volume a page boundary split whole, ordered over every
 * member listed; the members come in volume order, so a volume no earlier page listed follows the rest.
 */
export function clusterSections(pages: readonly ClusterDocuments[]): WorkingCorpusDetail['sections'] {
  const sections: WorkingCorpusDetail['sections'] = [];
  const at = new Map<string, number>();
  for (const page of pages) {
    for (const section of page.sections) {
      const index = at.get(section.volumeId);
      if (index === undefined) {
        at.set(section.volumeId, sections.length);
        sections.push(section);
      } else sections[index] = section;
    }
  }
  return sections;
}

/** The reader's time zone, which the saved corpus's name says its time in. */
function timeZone(): string | undefined {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch {
    return undefined;
  }
}

/**
 * Save as Working Corpus: the server captures the region's members as the kit does, the first 7,500 with the whole count
 * beside them, and names the corpus by the map's rule and the time; the corpora's lists are asked again.
 */
export async function saveClusterCorpus(client: QueryClient, cluster: number, layout: string): Promise<WorkingCorpus> {
  const saved = (await change<WorkingCorpus>(client, 'POST', '/api/v1/me/working-corpora/cluster', { cluster, layout, timeZone: timeZone() }))!;
  void client.invalidateQueries({ queryKey: ['workingCorpora'] });
  return saved;
}
