// The cross-reference graph (PLAN's S23e): a document's graph as the app's graph view draws it, built on
// the server by the kit's store and display half, with the timeline laid out at the canvas size the
// browser names. The network is laid out here, as the app's view lays its own out.
import { queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';

const segment = encodeURIComponent;

/** How a graph is drawn: chronologically along a date axis, or by its connections alone. */
export type GraphLayout = 'timeline' | 'network';

/** A node's kind, the kit's `DisplayNode.Kind`. */
export type GraphNodeKind =
  'central' | 'inbound' | 'outbound' | 'extended' | 'clusterInbound' | 'clusterOutbound' | 'dateCluster' | 'unit' | 'centralFileClass';

export interface GraphNode {
  /** `volumeId/documentId` for a document or a page, else the cluster's, unit's or class's own key. */
  id: string;
  kind: GraphNodeKind;
  /** Hops from the central document: 0 for it, 1 for its direct references, 2 or 3 further out. */
  degree: number;
  /** Whether the server serves its volume; true for an archival node, which has none. */
  isDownloaded: boolean;
  /** What a screen reader hears for it, the kit's words. */
  label: string;
  /** Its first label line on the canvas, as the app's view writes it. */
  title?: string;
  /** Its row in the reference list: its head less the number it prints, or its key, and the number. */
  rowTitle: string;
  rowNumber?: string;
  /** Its date as the canvas labels it. */
  dateLabel?: string;
  /** Its date as the timeline places it, in seconds since 2001. */
  dateValue?: number;
  volumeId?: string;
  documentId?: string;
  /** A page of a volume rather than a document, which opens nothing. */
  isPageNode: boolean;
  /** Whether its document can be opened: a header, no cited page, and its volume served. */
  opens: boolean;
  header?: string;
  dateline?: string;
  documentNumber?: string;
  citedPage?: number;
  dating?: 'pageIndex' | 'pageMap' | 'volume';
  /** The documents a volume or date cluster stands for. */
  count?: number;
  /** A date cluster's period. */
  period?: string;
  /** The keys of the documents a date cluster stands for. */
  members?: string[];
  /** A unit's collection record and name. */
  collectionId?: string;
  name?: string;
  /** A central-file class's number. */
  classKey?: string;
  gloss?: string;
  /** Its references across the index, which sizes it. */
  connectionCount?: number;
}

export interface GraphEdge {
  /** `source->target`. */
  id: string;
  source: string;
  target: string;
  referenceType: 'footnote' | 'editorialNote';
  /** The text of each note that held a reference, in order. */
  contexts: string[];
  referenceCount: number;
  degree: number;
}

export interface GraphPoint {
  x: number;
  y: number;
}

/** The timeline the kit lays out, at the canvas size the request named. */
export interface GraphTimeline {
  /** The canvas it was laid out on, its width at least 116. */
  width: number;
  height: number;
  /** The nodes drawn: the graph's nodes no date cluster holds, then the date clusters. */
  visible: string[];
  dateClusters: GraphNode[];
  /** The edges drawn, an edge to a member of a date cluster drawn to the cluster. */
  edges: GraphEdge[];
  positions: Record<string, GraphPoint>;
  ticks: { x: number; label: string }[];
  axisY: number;
  hasParkedNodes: boolean;
  /** The dated nodes' earliest and latest dates, for the brush, or none when they span no time. */
  fullRange?: { from: number; to: number };
  domain?: { from: number; to: number };
  expandedDateClusters: string[];
}

export interface DocumentGraph {
  volumeId: string;
  documentId: string;
  centralKey: string;
  chosenDegree?: number;
  /** The hops the graph was loaded at. */
  degree: number;
  /** Whether a sparse graph was widened to two hops. */
  widened: boolean;
  chosenLayout?: GraphLayout;
  /** The layout drawn. */
  layout: GraphLayout;
  timelineEligible: boolean;
  hasUndownloadedSources: boolean;
  undownloadedCitingVolumeIds: string[];
  undownloadedCitingCount: number;
  expandedClusters: string[];
  /** Every node the network draws and the reference list lists, in the display build's order. */
  nodes: GraphNode[];
  edges: GraphEdge[];
  /** The reference list's sections, each in the kit's order. */
  referenceList: { inbound: string[]; outbound: string[]; extended: string[] };
  timeline?: GraphTimeline;
}

/** What a graph's page asks of the server, as its address holds it. */
export interface GraphAsk {
  degree?: number;
  layout?: GraphLayout;
  expand?: string[];
  expandDates?: string[];
  from?: number;
  to?: number;
  width: number;
  height: number;
}

export function graphQuery(volumeId: string, documentId: string, ask: GraphAsk) {
  const params = new URLSearchParams();
  if (ask.degree !== undefined) params.set('degree', String(ask.degree));
  if (ask.layout) params.set('layout', ask.layout);
  for (const key of ask.expand ?? []) params.append('expand', key);
  for (const key of ask.expandDates ?? []) params.append('expandDates', key);
  if (ask.from !== undefined && ask.to !== undefined) {
    params.set('from', String(ask.from));
    params.set('to', String(ask.to));
  }
  params.set('width', String(Math.round(ask.width)));
  params.set('height', String(Math.round(ask.height)));
  return queryOptions({
    queryKey: ['graph', volumeId, documentId, params.toString()],
    queryFn: ({ signal }) =>
      getJSON<DocumentGraph>(`/api/v1/volumes/${segment(volumeId)}/documents/${segment(documentId)}/graph`, params, signal),
    staleTime: 5 * 60_000,
    retry: false,
  });
}
