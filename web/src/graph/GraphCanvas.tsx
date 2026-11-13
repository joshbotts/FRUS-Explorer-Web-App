// The cross-reference graph's canvas (PLAN's S23e), drawn by Cytoscape.js: each node the page draws at its
// place, the timeline's from the kit on the server and the network's from the app's layout here, sized
// by its connections and coloured by its kind as the app's canvas draws it, with a dashed ring for a
// volume the server does not serve; each edge with its arrow at the cited document, heavier for more
// references; and on the timeline its date axis, its ticks and the Undated column's caption. The canvas is
// hidden from screen readers, as the app's is: the page's node list beside it is the keyboard's way
// through it, and the reference list its text. A click on a node or an edge is the page's to act on; a
// click on empty canvas does nothing, as in the app (its decision D8); a drag pans and the wheel zooms,
// between a quarter and four times, as the app's pinch does.
import cytoscape, { type Core, type ElementDefinition, type StylesheetJson } from 'cytoscape';
import { useEffect, useRef } from 'react';
import type { GraphEdge, GraphNode, GraphPoint, GraphTimeline } from '../api/graph';
import { copy } from '../copy';
import { nodeRadius, terminatesWalk } from './graphRules';

export interface GraphCanvasProps {
  /** The nodes drawn, each with a place in `positions`. */
  nodes: GraphNode[];
  edges: GraphEdge[];
  positions: Record<string, GraphPoint>;
  /** The timeline's axis, when the timeline is drawn. */
  timeline?: GraphTimeline;
  /** The nodes whose labels are drawn. */
  labelled: Set<string>;
  /** The node or edge whose details show, and the node the keyboard is on. */
  selectedNode?: string;
  selectedEdge?: string;
  activeNode?: string;
  /** The selected node and its neighbours, which stay bright while the rest dim, or none. */
  focus?: Set<string>;
  /** Changed to put the view back where it was laid out. */
  resetToken: number;
  /** Whether to move the view to a node at once rather than gliding there. */
  reducedMotion: boolean;
  onNode: (id: string) => void;
  onEdge: (id: string) => void;
}

/** The theme's colours, read from the page's tokens as each theme sets them. */
function tokens() {
  const css = getComputedStyle(document.documentElement);
  const read = (name: string, fallback: string) => css.getPropertyValue(name).trim() || fallback;
  return {
    accent: read('--accent', '#0a58b8'),
    blue: read('--tone-blue', '#0a58b8'),
    orange: read('--tone-orange', '#8a4b00'),
    teal: read('--tone-teal', '#0a6563'),
    purple: read('--tone-purple', '#6a3d9a'),
    secondary: read('--tone-secondary', '#555559'),
    text: read('--text', '#1d1d1f'),
    textSecondary: read('--text-secondary', '#555559'),
    bg: read('--bg', '#ffffff'),
    focus: read('--focus', '#0a58b8'),
  };
}

/** The canvas's style: the app's colours and weights, in the page's tokens. */
function stylesheet(): StylesheetJson {
  const t = tokens();
  return [
    {
      selector: 'node.graph-node',
      style: {
        width: 'data(size)',
        height: 'data(size)',
        'background-color': t.secondary,
        'background-opacity': 0.2,
        label: 'data(text)',
        'text-wrap': 'wrap',
        'text-max-width': '140px',
        'text-valign': 'bottom',
        'text-halign': 'center',
        'text-margin-y': 3,
        'font-size': 8,
        'line-height': 1.2,
        color: t.text,
        'text-background-color': t.bg,
        'text-background-opacity': 0.8,
        'text-background-padding': '1px',
        'border-width': 0,
      },
    },
    { selector: 'node.central', style: { 'background-color': t.accent, 'background-opacity': 1, 'font-size': 10 } },
    { selector: 'node.inbound', style: { 'background-color': t.blue, 'background-opacity': 0.3 } },
    { selector: 'node.outbound', style: { 'background-color': t.orange, 'background-opacity': 0.3 } },
    { selector: 'node.extended', style: { 'background-color': t.secondary, 'background-opacity': 0.2, color: t.textSecondary } },
    { selector: 'node.clusterInbound', style: { 'background-color': t.blue, 'background-opacity': 0.2 } },
    { selector: 'node.clusterOutbound', style: { 'background-color': t.orange, 'background-opacity': 0.2 } },
    { selector: 'node.dateCluster', style: { 'background-color': t.purple, 'background-opacity': 0.25 } },
    { selector: 'node.unit, node.centralFileClass', style: { 'background-color': t.teal, 'background-opacity': 0.3 } },
    // Dashed: a volume the server does not serve, as the app's ring says one is not downloaded.
    {
      selector: 'node.undownloaded',
      style: { 'border-width': 1.5, 'border-style': 'dashed', 'border-color': t.textSecondary, 'border-opacity': 0.8 },
    },
    {
      selector: 'node.selected',
      style: { 'background-opacity': 0.7, 'border-width': 2.5, 'border-style': 'solid', 'border-color': t.text },
    },
    { selector: 'node.central.selected', style: { 'background-opacity': 1 } },
    // The node the keyboard is on.
    { selector: 'node.active', style: { 'outline-width': 3, 'outline-color': t.focus, 'outline-offset': 2, 'outline-opacity': 1 } },
    { selector: '.dimmed', style: { opacity: 0.3 } },
    {
      selector: 'edge.graph-edge',
      style: {
        width: 'data(width)',
        'line-color': t.secondary,
        'line-opacity': 0.4,
        'curve-style': 'bezier',
        'target-arrow-shape': 'chevron',
        'target-arrow-color': t.secondary,
        'arrow-scale': 0.8,
      },
    },
    { selector: 'edge.editorial', style: { 'line-color': t.accent, 'target-arrow-color': t.accent } },
    { selector: 'edge.extended', style: { 'line-opacity': 0.25 } },
    {
      selector: 'edge.selected',
      style: { width: 'data(selectedWidth)', 'line-color': t.accent, 'target-arrow-color': t.accent, 'line-opacity': 0.7 },
    },
    // The timeline's axis, its ticks and the Undated caption, which nothing selects.
    { selector: 'node.decor', style: { width: 1, height: 1, 'background-opacity': 0, events: 'no', label: 'data(text)' } },
    { selector: 'edge.axis', style: { width: 0.75, 'line-color': t.secondary, 'line-opacity': 0.35, events: 'no' } },
    {
      selector: 'node.tick',
      style: {
        shape: 'rectangle',
        width: 0.75,
        height: 8,
        'background-color': t.secondary,
        'background-opacity': 0.5,
        'font-size': 9,
        'text-valign': 'bottom',
        'text-margin-y': 3,
        color: t.textSecondary,
      },
    },
    { selector: 'node.caption', style: { 'font-size': 9, 'font-weight': 500, color: t.textSecondary, 'text-valign': 'center' } },
  ];
}

/** An edge's width, the app's `drawEdge`: 1.5, or 1 further out, and half a point more for each further reference, two at most. */
function edgeWidth(edge: GraphEdge, selected: boolean): number {
  const base = selected ? 2.5 : edge.degree > 1 ? 1.0 : 1.5;
  return base + Math.min((edge.referenceCount - 1) * 0.5, 2.0);
}

/** The node's label: its title over its date, or nothing when it is not labelled. */
function labelText(node: GraphNode, labelled: Set<string>): string {
  if (!labelled.has(node.id)) return '';
  return [node.title, node.dateLabel].filter((line) => line !== undefined && line !== '').join('\n');
}

function elements(
  nodes: readonly GraphNode[],
  edges: readonly GraphEdge[],
  positions: Record<string, GraphPoint>,
  timeline: GraphTimeline | undefined,
  labelled: Set<string>,
): ElementDefinition[] {
  const drawn = nodes.flatMap((node) => {
    const at = positions[node.id];
    return at ? [{ node, at }] : [];
  });
  const ids = new Set(drawn.map(({ node }) => node.id));
  const out: ElementDefinition[] = drawn.map(({ node, at }) => ({
    group: 'nodes',
    data: { id: node.id, size: nodeRadius(node) * 2, text: labelText(node, labelled) },
    position: { x: at.x, y: at.y },
    classes: ['graph-node', node.kind, !node.isDownloaded && !terminatesWalk(node) ? 'undownloaded' : ''].join(' '),
    selectable: false,
    grabbable: false,
  }));
  for (const edge of edges) {
    if (!ids.has(edge.source) || !ids.has(edge.target)) continue;
    out.push({
      group: 'edges',
      data: {
        id: `edge:${edge.id}`,
        source: edge.source,
        target: edge.target,
        width: edgeWidth(edge, false),
        selectedWidth: edgeWidth(edge, true),
        key: edge.id,
      },
      classes: ['graph-edge', edge.degree > 1 ? 'extended' : '', edge.referenceType === 'editorialNote' ? 'editorial' : ''].join(' '),
      selectable: false,
    });
  }
  if (timeline) {
    // The axis as the app draws it: from 40 points in to 64 short of the trailing edge, each tick a mark of
    // 8 points with its label under it, and the Undated caption over the parked column.
    const decor = (id: string, x: number, y: number, classes: string, text = '') =>
      out.push({
        group: 'nodes',
        data: { id, text },
        position: { x, y },
        classes: `decor ${classes}`,
        selectable: false,
        grabbable: false,
      });
    decor('decor:axis-start', 40, timeline.axisY, 'axis-end');
    decor('decor:axis-end', timeline.width - 64, timeline.axisY, 'axis-end');
    out.push({
      group: 'edges',
      data: { id: 'decor:axis', source: 'decor:axis-start', target: 'decor:axis-end' },
      classes: 'axis',
      selectable: false,
    });
    timeline.ticks.forEach((tick, index) => decor(`decor:tick-${index}`, tick.x, timeline.axisY, 'tick', tick.label));
    if (timeline.hasParkedNodes) decor('decor:undated', timeline.width - 44, 46, 'caption', copy.graph.undated);
  }
  return out;
}

export function GraphCanvas(props: GraphCanvasProps) {
  const container = useRef<HTMLDivElement>(null);
  const cy = useRef<Core | null>(null);
  const handlers = useRef({ onNode: props.onNode, onEdge: props.onEdge });
  const { onNode, onEdge } = props;
  useEffect(() => {
    handlers.current = { onNode, onEdge };
  }, [onNode, onEdge]);

  // One instance for the page's life, restyled when the theme changes.
  useEffect(() => {
    if (!container.current) return;
    const instance = cytoscape({
      container: container.current,
      style: stylesheet(),
      layout: { name: 'preset' },
      minZoom: 0.25,
      maxZoom: 4,
      autoungrabify: true,
      autounselectify: true,
      boxSelectionEnabled: false,
    });
    instance.on('tap', 'node.graph-node', (event) => handlers.current.onNode(event.target.id()));
    instance.on('tap', 'edge.graph-edge', (event) => handlers.current.onEdge(event.target.data('key')));
    cy.current = instance;
    const theme = new MutationObserver(() => instance.style(stylesheet()));
    theme.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    return () => {
      theme.disconnect();
      instance.destroy();
      cy.current = null;
    };
  }, []);

  // The graph drawn afresh whenever what is drawn changes, at the places it was laid out at.
  const { nodes, edges, positions, timeline, labelled } = props;
  useEffect(() => {
    const instance = cy.current;
    if (!instance) return;
    instance.batch(() => {
      instance.elements().remove();
      instance.add(elements(nodes, edges, positions, timeline, labelled));
    });
    instance.resize();
    instance.viewport({ zoom: 1, pan: { x: 0, y: 0 } });
  }, [nodes, edges, positions, timeline, labelled]);

  // The selection, the keyboard's node and the dimming, as classes on what is drawn.
  const { selectedNode, selectedEdge, activeNode, focus } = props;
  useEffect(() => {
    const instance = cy.current;
    if (!instance) return;
    instance.batch(() => {
      instance.$('.graph-node, .graph-edge').removeClass('selected active dimmed');
      if (selectedNode) instance.getElementById(selectedNode).addClass('selected');
      if (activeNode) instance.getElementById(activeNode).addClass('active');
      if (selectedEdge) instance.getElementById(`edge:${selectedEdge}`).addClass('selected');
      if (focus) {
        instance.$('.graph-node').forEach((node) => {
          if (!focus.has(node.id())) node.addClass('dimmed');
        });
        instance.$('.graph-edge').forEach((edge) => {
          if (!focus.has(edge.data('source')) || !focus.has(edge.data('target'))) edge.addClass('dimmed');
        });
      }
    });
  }, [selectedNode, selectedEdge, activeNode, focus, nodes, edges, positions]);

  // The node the keyboard reaches is brought into view when it is off the canvas.
  const reducedMotion = props.reducedMotion;
  useEffect(() => {
    const instance = cy.current;
    if (!instance || !activeNode) return;
    const node = instance.getElementById(activeNode);
    if (node.empty()) return;
    const box = node.renderedBoundingBox();
    if (box.x1 >= 0 && box.y1 >= 0 && box.x2 <= instance.width() && box.y2 <= instance.height()) return;
    if (reducedMotion) instance.center(node);
    else instance.animate({ center: { eles: node } }, { duration: 200 });
  }, [activeNode, reducedMotion]);

  const resetToken = props.resetToken;
  useEffect(() => {
    if (resetToken > 0) cy.current?.viewport({ zoom: 1, pan: { x: 0, y: 0 } });
  }, [resetToken]);

  return <div ref={container} className="graph-cy" aria-hidden="true" />;
}
