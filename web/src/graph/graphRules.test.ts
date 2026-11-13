// The cross-reference graph's rules, mirrored from the app's view model and view (PLAN's S23e): a node's
// size, the network's two layouts, a node's passage and a row's edge, and the keyboard's order.
import { describe, expect, it } from 'vitest';
import type { GraphEdge, GraphNode } from '../api/graph';
import {
  contextForNode,
  directionLabel,
  edgeDirectionLabel,
  focusKeys,
  forceDirectedLayout,
  initialPositions,
  keyboardOrder,
  labelledNodes,
  networkLayout,
  primaryEdge,
  radius,
  standardLayout,
  undownloadedBanner,
  usesForceLayout,
} from './graphRules';

function node(id: string, kind: GraphNode['kind'], fields: Partial<GraphNode> = {}): GraphNode {
  return {
    id,
    kind,
    degree: kind === 'central' ? 0 : 1,
    isDownloaded: true,
    label: id,
    rowTitle: id,
    isPageNode: false,
    opens: true,
    ...fields,
  };
}

function edge(source: string, target: string, fields: Partial<GraphEdge> = {}): GraphEdge {
  return { id: `${source}->${target}`, source, target, referenceType: 'footnote', contexts: [], referenceCount: 1, degree: 1, ...fields };
}

const central = 'v/d1';

describe('the graph’s rules', () => {
  it('sizes a node as the app does', () => {
    expect(radius('central', 1)).toBe(24);
    expect(radius('clusterInbound', 500)).toBe(18);
    expect(radius('dateCluster', 1, 2)).toBe(18);
    expect(radius('dateCluster', 1, 64)).toBe(24);
    // 12 + 3 log2(count + 1), at least 12, at most 22, or 18 further out.
    expect(radius('inbound', 1)).toBe(15);
    expect(radius('outbound', 0)).toBe(15);
    expect(radius('inbound', 7)).toBe(21);
    expect(radius('inbound', 1000)).toBe(22);
    expect(radius('extended', 1000)).toBe(18);
    expect(radius('unit', 1)).toBe(15);
  });

  it('lays a small graph out in three columns, and a larger one by force', () => {
    const nodes = [node(central, 'central'), node('v/d2', 'inbound'), node('v/d3', 'inbound'), node('v/d4', 'outbound')];
    expect(usesForceLayout(nodes)).toBe(false);
    const places = standardLayout(nodes, central, 800, 600);
    expect(places[central]).toEqual({ x: 400, y: 300 });
    // The citing documents on the left, a third of the height less 60 apart and centred; the cited one on the right.
    expect(places['v/d2']).toEqual({ x: 200, y: 210 });
    expect(places['v/d3']).toEqual({ x: 200, y: 390 });
    expect(places['v/d4']).toEqual({ x: 600, y: 300 });
    expect(usesForceLayout([...nodes, node('v/d5', 'extended', { degree: 2 })])).toBe(true);
    const many = [node(central, 'central'), ...Array.from({ length: 21 }, (_, i) => node(`v/x${i}`, 'inbound'))];
    expect(usesForceLayout(many)).toBe(true);
  });

  it('starts the force-directed layout on a circle, and lays the same graph out the same way each time', () => {
    const nodes = [node(central, 'central'), ...Array.from({ length: 30 }, (_, i) => node(`v/x${i}`, i % 2 ? 'inbound' : 'extended'))];
    const edges = nodes.slice(1).map((each, i) => (i % 2 ? edge(each.id, central) : edge(nodes[i]!.id, each.id, { degree: 2 })));
    const start = initialPositions(nodes, central, 900, 600);
    expect(start[central]).toEqual({ x: 450, y: 300 });
    expect(Math.hypot(start['v/x0']!.x - 450, start['v/x0']!.y - 300)).toBeCloseTo(210);
    const once = networkLayout(nodes, edges, central, 900, 600);
    const twice = networkLayout(nodes, edges, central, 900, 600);
    expect(twice).toEqual(once);
    // The central document stays at the centre, and every node inside the canvas's pad.
    expect(once[central]).toEqual({ x: 450, y: 300 });
    for (const place of Object.values(once)) {
      expect(place.x).toBeGreaterThanOrEqual(32);
      expect(place.x).toBeLessThanOrEqual(868);
      expect(place.y).toBeGreaterThanOrEqual(32);
      expect(place.y).toBeLessThanOrEqual(568);
    }
    // Batches that take the schedule's steps in order end where one call taking all of them ends.
    let batched = start;
    for (let batch = 0; batch < 10; batch++) batched = forceDirectedLayout(nodes, edges, batched, central, 900, 600, 20, batch * 20, 200);
    expect(batched).toEqual(once);
  });

  it('reads a node’s passage and a row’s edge as the app does', () => {
    const edges = [
      edge('v/d2', central, { contexts: ['See the telegram.'] }),
      edge(central, 'v/d3', { contexts: ['Printed as Document 3.', 'And again.'] }),
      edge('v/d3', 'v/d9', { degree: 2, contexts: [] }),
      edge('v/d9', 'v/d8', { degree: 2, contexts: ['Further out.'] }),
    ];
    expect(contextForNode(node('v/d2', 'inbound'), edges, central)).toBe('See the telegram.');
    expect(contextForNode(node('v/d3', 'outbound'), edges, central)).toBe('Printed as Document 3.\n\nAnd again.');
    expect(contextForNode(node('v/d9', 'extended', { degree: 2 }), edges, central)).toBe('Further out.');
    expect(contextForNode(node(central, 'central'), edges, central)).toBeUndefined();
    expect(contextForNode(node('unit/v/d2/c1', 'unit'), edges, central)).toBeUndefined();
    expect(primaryEdge('v/d3', edges, central)?.id).toBe(`${central}->v/d3`);
    expect(primaryEdge('v/d8', edges, central)?.id).toBe('v/d9->v/d8');
    expect(directionLabel('inbound')).toBe('Referenced in');
    expect(directionLabel('outbound')).toBe('References from');
    expect(directionLabel('extended')).toBe('Extended reference');
    expect(directionLabel('central')).toBe('Context');
    expect(edgeDirectionLabel(edges[0]!, central)).toBe('Referenced in');
    expect(edgeDirectionLabel(edges[1]!, central)).toBe('References from');
    expect(edgeDirectionLabel(edges[3]!, central)).toBe('Extended reference');
  });

  it('walks the drawn nodes from the central one through the reference list’s sections', () => {
    const drawn = [
      node(central, 'central'),
      node('v/d3', 'outbound'),
      node('v/d2', 'inbound'),
      node('unit/v/d2/c1', 'unit'),
      node('datecluster/v/d5', 'dateCluster'),
      node('v/d9', 'extended'),
    ];
    const order = keyboardOrder(drawn, central, { inbound: ['v/d2', 'v/d4'], outbound: ['v/d3'], extended: ['v/d9'] });
    expect(order.map((each) => each.id)).toEqual([central, 'v/d2', 'v/d3', 'v/d9', 'datecluster/v/d5', 'unit/v/d2/c1']);
  });

  it('labels a small graph whole, and a larger one around the centre, the clusters and the selection', () => {
    const small = [node(central, 'central'), node('v/d2', 'inbound')];
    expect([...labelledNodes(small, [])]).toEqual([central, 'v/d2']);
    const large = [
      node(central, 'central'),
      node('cluster/inbound/w', 'clusterInbound'),
      ...Array.from({ length: 45 }, (_, i) => node(`v/x${i}`, 'extended')),
    ];
    const edges = [edge('v/x3', 'v/x4'), edge('v/x5', 'v/x3')];
    expect([...labelledNodes(large, edges)].sort()).toEqual([central, 'cluster/inbound/w'].sort());
    expect([...labelledNodes(large, edges, 'v/x3')].sort()).toEqual([central, 'cluster/inbound/w', 'v/x3', 'v/x4', 'v/x5'].sort());
    expect([...focusKeys(edges, 'v/x3')!].sort()).toEqual(['v/x3', 'v/x4', 'v/x5']);
    expect([...focusKeys(edges, undefined, 'v/x5->v/x3')!].sort()).toEqual(['v/x3', 'v/x5']);
    expect(focusKeys(edges)).toBeUndefined();
  });

  it('counts the citing documents the server does not hold, in the app’s banner', () => {
    expect(undownloadedBanner(12, 3)).toBe(
      '12 documents in 3 volumes this server does not hold also cite this one. They are shown without titles.',
    );
    expect(undownloadedBanner(1, 1)).toBe(
      '1 document in 1 volume this server does not hold also cites this one. It is shown without a title.',
    );
    expect(undownloadedBanner(0, 0)).toBe('Some volumes that may reference this document are not on this server.');
  });
});
