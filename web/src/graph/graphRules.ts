// The cross-reference graph's rules in the browser (PLAN's S23e), mirrored from the app's
// `CrossReferenceGraphViewModel` and `CrossReferenceGraphView` and held to their source by
// `CrossReferenceGraphParityTests`: a node's size by its connections; the network layouts, the three
// columns of a small graph and the Fruchterman–Reingold layout of a larger one or one with nodes further
// out (#1764); the passage a node's details show and the edge a reference list row reads; and the words
// of a context's direction. The rest of the display, the nodes and edges themselves, their dates, the
// timeline's clusters and places and the reference list's order, is the kit's, from the server.
import type { GraphEdge, GraphNode, GraphNodeKind, GraphPoint } from '../api/graph';
import { copy } from '../copy';

/** Whether a node is a volume cluster (`isCluster`). */
export function isCluster(node: Pick<GraphNode, 'kind'>): boolean {
  return node.kind === 'clusterInbound' || node.kind === 'clusterOutbound';
}

/** Whether a node is archival, a unit or a central-file class, which ends the walk (`terminatesWalk`). */
export function terminatesWalk(node: Pick<GraphNode, 'kind'>): boolean {
  return node.kind === 'unit' || node.kind === 'centralFileClass';
}

/**
 * A node's radius on the canvas, the app's `radius(for:connectionCount:)`: the central document's and a
 * cluster's fixed, a date cluster's growing gently with its size, and every other's with its connections
 * across the corpus, a node further out capped below a direct reference.
 */
export function radius(kind: GraphNodeKind, connectionCount: number, count = 0): number {
  switch (kind) {
    case 'central':
      return 24;
    case 'clusterInbound':
    case 'clusterOutbound':
      return 18;
    case 'dateCluster':
      return Math.min(16 + 2 * Math.log2(Math.max(count, 2)), 24);
    default: {
      const connections = Math.max(connectionCount, 1);
      const size = 12.0 + 3.0 * Math.log2(connections + 1);
      const cap = kind === 'extended' ? 18 : 22;
      return Math.min(Math.max(size, 12), cap);
    }
  }
}

/** The radius the canvas draws `node` at, its count read as the app's `nodeConnectionCounts[id] ?? 1`. */
export function nodeRadius(node: GraphNode): number {
  return radius(node.kind, node.connectionCount ?? 1, node.count ?? 0);
}

/** Whether the network takes the force-directed layout (`rerunLayout`): more than 21 nodes, or any further out. */
export function usesForceLayout(nodes: readonly GraphNode[]): boolean {
  const hasExtended = nodes.some((node) => node.kind === 'extended');
  return nodes.length > 21 || hasExtended;
}

/**
 * The three-column layout of a small graph, the app's `standardLayout`: the central document at the
 * centre, the documents and clusters citing it in the left column, those it cites in the right, each
 * column spread with at least 60 points between its nodes.
 */
export function standardLayout(nodes: readonly GraphNode[], centralKey: string, width: number, height: number): Record<string, GraphPoint> {
  const positions: Record<string, GraphPoint> = {};
  const cx = width / 2;
  const cy = height / 2;
  positions[centralKey] = { x: cx, y: cy };
  const inbound = nodes.filter((node) => node.kind === 'inbound' || node.kind === 'clusterInbound');
  const outbound = nodes.filter((node) => node.kind === 'outbound' || node.kind === 'clusterOutbound');
  const minSep = 60;
  function placeColumn(column: GraphNode[], x: number) {
    if (column.length === 0) return;
    const [only] = column;
    if (column.length === 1 && only) {
      positions[only.id] = { x, y: cy };
      return;
    }
    const step = Math.max(minSep, (height - 60) / (column.length + 1));
    const totalH = step * (column.length - 1);
    const startY = cy - totalH / 2;
    column.forEach((node, i) => {
      positions[node.id] = { x, y: startY + i * step };
    });
  }
  placeColumn(inbound, width / 4);
  placeColumn(outbound, (width * 3) / 4);
  return positions;
}

/** The force-directed layout's starting places, the app's `initialPositions`: a circle around the centre. */
export function initialPositions(
  nodes: readonly GraphNode[],
  centralKey: string,
  width: number,
  height: number,
): Record<string, GraphPoint> {
  const positions: Record<string, GraphPoint> = {};
  const cx = width / 2;
  const cy = height / 2;
  const r = Math.min(width, height) * 0.35;
  positions[centralKey] = { x: cx, y: cy };
  const others = nodes.filter((node) => node.id !== centralKey);
  others.forEach((node, i) => {
    const angle = (2 * Math.PI * i) / Math.max(others.length, 1);
    positions[node.id] = { x: cx + r * Math.cos(angle), y: cy + r * Math.sin(angle) };
  });
  return positions;
}

/** The app's network layout's constants (#1764). */
export const layoutIterations = 200;
export const layoutPad = 32;
export const layoutMaximumDistance = 100;
export const layoutEdgeRepulsion = 0.5;
export const directReferenceWeight = 4;

/**
 * A node's weight in the layout's repulsion, the app's `layoutWeight(for:)`: the central document and its
 * direct references, documents and volume clusters, 4; every other node 1.
 */
export function layoutWeight(kind: GraphNodeKind): number {
  switch (kind) {
    case 'central':
    case 'inbound':
    case 'outbound':
    case 'clusterInbound':
    case 'clusterOutbound':
      return directReferenceWeight;
    default:
      return 1;
  }
}

/**
 * The network layout, the app's `forceDirectedLayout` (#1764): Fruchterman–Reingold with its repulsion cut
 * off at twice the ideal distance, which is each node's share of the canvas at most 100 points, the
 * central document and its direct references weighing 4, the canvas's edges repelling a node near them,
 * and a temperature cooling linearly over `layoutIterations` steps, the central document pinned at the
 * centre. The same nodes and canvas give the same places at every visit. `firstIteration` and
 * `totalIterations` take one schedule's steps in batches, as the app's animated settling does.
 */
export function forceDirectedLayout(
  nodes: readonly GraphNode[],
  edges: readonly Pick<GraphEdge, 'source' | 'target'>[],
  initial: Record<string, GraphPoint>,
  centralKey: string,
  width: number,
  height: number,
  iterations: number,
  firstIteration = 0,
  totalIterations?: number,
): Record<string, GraphPoint> {
  const count = nodes.length;
  if (count === 0) return {};
  const schedule = Math.max(totalIterations ?? iterations, 1);
  const pad = layoutPad;
  const minX = pad;
  const maxX = Math.max(width - pad, pad);
  const minY = pad;
  const maxY = Math.max(height - pad, pad);
  const k = Math.min(Math.sqrt((Math.max(maxX - minX, 1) * Math.max(maxY - minY, 1)) / count), layoutMaximumDistance);
  const weights = nodes.map((node) => layoutWeight(node.kind));
  const repulsionK = k / (weights.reduce((sum, weight) => sum + weight, 0) / count);
  const repulsionKSquared = repulsionK * repulsionK;
  const startTemperature = Math.min(maxX - minX, maxY - minY) / 10;

  const ids = nodes.map((node) => node.id);
  const index = new Map<string, number>();
  ids.forEach((id, i) => {
    if (!index.has(id)) index.set(id, i);
  });
  const centre = { x: width / 2, y: height / 2 };
  // Arrays by index: the step is all pairs, and a lookup by key per pair would cost seconds.
  const x = Float64Array.from(ids, (id) => initial[id]?.x ?? centre.x);
  const y = Float64Array.from(ids, (id) => initial[id]?.y ?? centre.y);
  const weight = Float64Array.from(weights);
  const pinned = index.get(centralKey) ?? -1;
  const springs: number[] = [];
  for (const edge of edges) {
    const a = index.get(edge.source);
    const b = index.get(edge.target);
    if (a !== undefined && b !== undefined && a !== b) springs.push(a, b);
  }
  const forceX = new Float64Array(count);
  const forceY = new Float64Array(count);
  /** The push away from one edge on a node `gap` points from it, nothing beyond `2k′`. */
  function edgeRepulsion(gap: number): number {
    const d = Math.max(gap, 0.5);
    return d < 2 * repulsionK ? (layoutEdgeRepulsion * repulsionKSquared) / d : 0;
  }

  for (let step = firstIteration; step < firstIteration + Math.max(iterations, 0); step++) {
    const temperature = startTemperature * Math.max(0, 1 - step / schedule);
    forceX.fill(0);
    forceY.fill(0);
    // Repulsion between every pair within reach, which grows with the pair's weight.
    for (let i = 0; i < count; i++) {
      const xi = x[i]!;
      const yi = y[i]!;
      const wi = weight[i]!;
      for (let j = i + 1; j < count; j++) {
        const pair = wi * weight[j]!;
        let dx = xi - x[j]!;
        let dy = yi - y[j]!;
        let d = Math.sqrt(dx * dx + dy * dy);
        if (d < 0.01) {
          // A direction fixed by the pair: the golden angle times a number of its own.
          const angle = ((i * count + j) * 2.399_963_229_728_653) % (2 * Math.PI);
          dx = Math.cos(angle) * 0.01;
          dy = Math.sin(angle) * 0.01;
          d = 0.01;
        }
        if (!(d < 2 * repulsionK * Math.sqrt(pair))) continue;
        const f = (repulsionKSquared * pair) / d;
        const fx = (dx / d) * f;
        const fy = (dy / d) * f;
        forceX[i]! += fx;
        forceY[i]! += fy;
        forceX[j]! -= fx;
        forceY[j]! -= fy;
      }
    }
    // Attraction along every edge.
    for (let s = 0; s < springs.length; s += 2) {
      const a = springs[s]!;
      const b = springs[s + 1]!;
      const dx = x[a]! - x[b]!;
      const dy = y[a]! - y[b]!;
      const d = Math.max(Math.sqrt(dx * dx + dy * dy), 0.01);
      const f = (d * d) / k;
      const fx = (dx / d) * f;
      const fy = (dy / d) * f;
      forceX[a]! -= fx;
      forceY[a]! -= fy;
      forceX[b]! += fx;
      forceY[b]! += fy;
    }
    // The canvas's edges, each repelling a node from its nearest point on it.
    for (let i = 0; i < count; i++) {
      forceX[i]! += edgeRepulsion(x[i]! - minX) - edgeRepulsion(maxX - x[i]!);
      forceY[i]! += edgeRepulsion(y[i]! - minY) - edgeRepulsion(maxY - y[i]!);
    }
    // Each node moves along its force by at most the temperature, inside the canvas.
    for (let i = 0; i < count; i++) {
      if (i === pinned) continue;
      const fx = forceX[i]!;
      const fy = forceY[i]!;
      const length = Math.sqrt(fx * fx + fy * fy);
      if (!(length > 0)) continue;
      const scale = Math.min(length, temperature) / length;
      x[i] = Math.min(maxX, Math.max(minX, x[i]! + fx * scale));
      y[i] = Math.min(maxY, Math.max(minY, y[i]! + fy * scale));
    }
  }
  const positions: Record<string, GraphPoint> = {};
  ids.forEach((id, i) => {
    positions[id] = { x: x[i]!, y: y[i]! };
  });
  return positions;
}

/**
 * The network's places, as the app's `rerunLayout` chooses its layout: the three columns of a small graph
 * with no node further out, else the force-directed layout from the circle, all its steps at once, as the
 * app lays it out under Reduce Motion.
 */
export function networkLayout(
  nodes: readonly GraphNode[],
  edges: readonly GraphEdge[],
  centralKey: string,
  width: number,
  height: number,
): Record<string, GraphPoint> {
  if (!usesForceLayout(nodes)) return standardLayout(nodes, centralKey, width, height);
  const initial = initialPositions(nodes, centralKey, width, height);
  return forceDirectedLayout(nodes, edges, initial, centralKey, width, height, layoutIterations);
}

/**
 * The passage a node's details show, the app's `contextForSelectedNode`: for a document citing the
 * central one, its edge's notes; for one it cites, the central document's; for one further out, any edge
 * of its that carries notes; none for the central document, a cluster or an archival node.
 */
export function contextForNode(node: GraphNode, edges: readonly GraphEdge[], centralKey: string): string | undefined {
  const combined = (edge: GraphEdge | undefined) => (edge && edge.contexts.length > 0 ? edge.contexts.join('\n\n') : undefined);
  switch (node.kind) {
    case 'inbound':
      return combined(edges.find((edge) => edge.source === node.id && edge.target === centralKey));
    case 'outbound':
      return combined(edges.find((edge) => edge.source === centralKey && edge.target === node.id));
    case 'extended':
      return combined(edges.find((edge) => (edge.source === node.id || edge.target === node.id) && edge.contexts.length > 0));
    default:
      return undefined;
  }
}

/**
 * The edge a reference list row reads its count and its passage from, the app's `primaryEdge(for:)`: the
 * edge citing the central document first, then the one from it, then any edge of the node.
 */
export function primaryEdge(nodeKey: string, edges: readonly GraphEdge[], centralKey: string): GraphEdge | undefined {
  return (
    edges.find((edge) => edge.source === nodeKey && edge.target === centralKey) ??
    edges.find((edge) => edge.source === centralKey && edge.target === nodeKey) ??
    edges.find((edge) => edge.source === nodeKey || edge.target === nodeKey)
  );
}

/** The direction a node's passage is read in (`GraphNodeDetailView.directionLabel`). */
export function directionLabel(kind: GraphNodeKind): string {
  switch (kind) {
    case 'inbound':
      return copy.graph.referencedIn;
    case 'outbound':
      return copy.graph.referencesFrom;
    case 'extended':
      return copy.graph.extendedReference;
    default:
      return copy.graph.context;
  }
}

/** The direction an edge's passage is read in (`GraphEdgeDetailView.edgeDirectionLabel`). */
export function edgeDirectionLabel(edge: GraphEdge, centralKey: string): string {
  if (edge.degree > 1) return copy.graph.extendedReference;
  return edge.source === centralKey ? copy.graph.referencesFrom : copy.graph.referencedIn;
}

/** A detail's title: the document's head, a cluster's description, or the node's key (`detailTitle`). */
export function detailTitle(node: GraphNode): string {
  if (node.header !== undefined) return node.header;
  if (isCluster(node) || node.kind === 'dateCluster') return node.label;
  return node.id;
}

/**
 * The order the keyboard walks the canvas's nodes in, the web's own: the central document, then the
 * reference list's three sections in its order, the kit's, then the date clusters and the archival nodes
 * as drawn. A node not drawn, as one a date cluster holds or one outside the brushed window, is left out.
 */
export function keyboardOrder(
  drawn: readonly GraphNode[],
  centralKey: string,
  sections: { inbound: string[]; outbound: string[]; extended: string[] },
): GraphNode[] {
  const byId = new Map(drawn.map((node) => [node.id, node]));
  const order: GraphNode[] = [];
  const seen = new Set<string>();
  function add(id: string) {
    const node = byId.get(id);
    if (node && !seen.has(id)) {
      seen.add(id);
      order.push(node);
    }
  }
  add(centralKey);
  for (const id of [...sections.inbound, ...sections.outbound, ...sections.extended]) add(id);
  for (const node of drawn) if (node.kind === 'dateCluster') add(node.id);
  for (const node of drawn) add(node.id);
  return order;
}

/**
 * Which nodes the canvas labels, the web's own: every node of a graph of 40 nodes or fewer, and on a
 * larger one the central document, the clusters and the selected node with its neighbours, as the app
 * labelled them until #1764, whose placement measures each label as the app's canvas draws it.
 */
export function labelledNodes(drawn: readonly GraphNode[], edges: readonly GraphEdge[], selected?: string): Set<string> {
  if (drawn.length <= 40) return new Set(drawn.map((node) => node.id));
  const labelled = new Set<string>();
  for (const node of drawn) {
    if (node.kind === 'central' || isCluster(node) || node.kind === 'dateCluster') labelled.add(node.id);
  }
  if (selected) {
    labelled.add(selected);
    for (const edge of edges) {
      if (edge.source === selected) labelled.add(edge.target);
      if (edge.target === selected) labelled.add(edge.source);
    }
  }
  return labelled;
}

/**
 * The nodes that stay bright while the rest dim, the app's `focusKeys` (`makeRenderSnapshot`): the
 * selected node and every node an edge joins it to, or a selected edge's two ends; none while nothing is
 * selected.
 */
export function focusKeys(edges: readonly GraphEdge[], selectedNode?: string, selectedEdge?: string): Set<string> | undefined {
  if (selectedNode) {
    const keys = new Set([selectedNode]);
    for (const edge of edges) {
      if (edge.source === selectedNode || edge.target === selectedNode) {
        keys.add(edge.source);
        keys.add(edge.target);
      }
    }
    return keys;
  }
  const edge = selectedEdge ? edges.find((each) => each.id === selectedEdge) : undefined;
  return edge ? new Set([edge.source, edge.target]) : undefined;
}

/** The banner over a graph some volumes the server does not serve cite (#262), in the app's words. */
export function undownloadedBanner(count: number, volumes: number): string {
  return volumes === 0 ? copy.graph.undownloaded : copy.graph.undownloadedCounted(count, volumes);
}
