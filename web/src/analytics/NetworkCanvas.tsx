// The co-mention network's canvas (PLAN's S24g), drawn by Cytoscape.js as the app's `PersonCoMentionGraphView` draws its
// Canvas: the focus at the centre in the accent colour, its partners around it where the app's spring layout settles them
// (`networkLayout`, mirrored), each disc sized by its shared documents with the focus, the one shown larger and ringed,
// and each edge thicker and darker for more documents mentioning both, a spoke to the focus in the accent colour. The
// canvas is hidden from screen readers, as the app's is: the list box the page lays over it is the keyboard's way through
// it, and the table beside it its numbers. A click on a partner is the page's to act on; a drag pans and the wheel zooms,
// between a quarter and four times, as the app's pinch does.
import cytoscape, { type Core, type ElementDefinition, type StylesheetJson } from 'cytoscape';
import { useEffect, useRef, useState } from 'react';
import type { NetworkAnswer } from '../api/personAnalytics';
import { edgeStyle, networkLayout, nodeRadius } from './personReferenceRules';

export interface NetworkCanvasProps {
  answer: NetworkAnswer;
  /** The partner the dock shows, and the one the keyboard is on. */
  shown?: number;
  active?: number;
  /** Changed to put the view back where it was laid out. */
  resetToken: number;
  reducedMotion: boolean;
  onPartner: (rollupId: number) => void;
}

/** The theme's colours, read from the page's tokens as each theme sets them. */
function tokens() {
  const css = getComputedStyle(document.documentElement);
  const read = (name: string, fallback: string) => css.getPropertyValue(name).trim() || fallback;
  return {
    accent: read('--accent', '#0a58b8'),
    teal: read('--tone-teal', '#0a6563'),
    secondary: read('--tone-secondary', '#555559'),
    text: read('--text', '#1d1d1f'),
    textSecondary: read('--text-secondary', '#555559'),
    bg: read('--bg', '#ffffff'),
    focus: read('--focus', '#0a58b8'),
  };
}

function stylesheet(): StylesheetJson {
  const t = tokens();
  return [
    {
      selector: 'node',
      style: {
        width: 'data(size)',
        height: 'data(size)',
        'background-color': t.teal,
        'background-opacity': 0.6,
        label: 'data(text)',
        'text-valign': 'bottom',
        'text-halign': 'center',
        'text-margin-y': 2,
        'font-size': 8,
        color: t.textSecondary,
        'text-background-color': t.bg,
        'text-background-opacity': 0.85,
        'text-background-padding': '1px',
        'border-width': 0,
      },
    },
    { selector: 'node.focus', style: { 'background-color': t.accent, 'background-opacity': 1, 'font-size': 9, 'font-weight': 'bold', color: t.text, 'border-width': 2, 'border-color': t.bg } },
    { selector: 'node.shown', style: { 'background-opacity': 1, 'border-width': 1.5, 'border-color': t.bg } },
    { selector: 'node.active', style: { 'outline-width': 3, 'outline-color': t.focus, 'outline-offset': 2, 'outline-opacity': 1 } },
    {
      selector: 'edge',
      style: { width: 'data(width)', 'line-color': t.secondary, 'line-opacity': (edge) => Number(edge.data('opacity')), 'curve-style': 'straight' },
    },
    { selector: 'edge.spoke', style: { 'line-color': t.accent } },
  ];
}

/** The id of the stylesheet Cytoscape would otherwise add to the page. */
const cytoscapeStylesheetId = '__________cytoscape_stylesheet';

export function NetworkCanvas({ answer, shown, active, resetToken, reducedMotion, onPartner }: NetworkCanvasProps) {
  const container = useRef<HTMLDivElement>(null);
  const cy = useRef<Core | null>(null);
  const handler = useRef(onPartner);
  const [size, setSize] = useState<{ width: number; height: number } | undefined>(undefined);
  useEffect(() => {
    handler.current = onPartner;
  }, [onPartner]);

  // One instance for the page's life, restyled when the theme changes.
  useEffect(() => {
    if (!container.current) return;
    // Cytoscape prepends a <style> giving its container `position: relative` unless an element with this id is in the
    // page; the server's policy refuses an inline style, and app.css positions the container already.
    if (!document.getElementById(cytoscapeStylesheetId)) {
      const marker = document.createElement('meta');
      marker.id = cytoscapeStylesheetId;
      document.head.append(marker);
    }
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
    instance.on('tap', 'node.partner', (event) => handler.current(Number(event.target.data('rollupId'))));
    cy.current = instance;
    const theme = new MutationObserver(() => instance.style(stylesheet()));
    theme.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    // The canvas's size, which the layout is computed for, as the app's `onCanvasSizeChanged` reruns it.
    const observer = new ResizeObserver(([entry]) => {
      if (!entry) return;
      const { width, height } = entry.contentRect;
      if (width > 0 && height > 0) setSize((last) => (last && last.width === width && last.height === height ? last : { width, height }));
    });
    observer.observe(container.current);
    return () => {
      observer.disconnect();
      theme.disconnect();
      instance.destroy();
      cy.current = null;
    };
  }, []);

  // The network drawn afresh at its settled places whenever it or the canvas's size changes.
  useEffect(() => {
    const instance = cy.current;
    if (!instance || !size) return;
    const places = networkLayout(answer, size, reducedMotion);
    const elements: ElementDefinition[] = [];
    for (const node of answer.nodes) {
      const place = places.get(node.rollupId);
      if (!place) continue;
      elements.push({
        group: 'nodes',
        data: { id: `p${node.rollupId}`, rollupId: node.rollupId, text: node.label, size: 2 * nodeRadius(answer, node.rollupId) },
        position: { x: place.x, y: place.y },
        classes: node.isFocus ? 'focus' : 'partner',
      });
    }
    for (const edge of answer.edges) {
      if (!places.has(edge.a) || !places.has(edge.b)) continue;
      const style = edgeStyle(answer, edge.sharedDocuments);
      elements.push({
        group: 'edges',
        data: { id: `e${edge.a}-${edge.b}`, source: `p${edge.a}`, target: `p${edge.b}`, width: style.width, opacity: style.opacity },
        classes: edge.isSpoke ? 'spoke' : '',
        selectable: false,
      });
    }
    instance.batch(() => {
      instance.elements().remove();
      instance.add(elements);
    });
    instance.resize();
    instance.viewport({ zoom: 1, pan: { x: 0, y: 0 } });
  }, [answer, size, reducedMotion]);

  // The partner shown and the keyboard's, as classes, with the shown disc 3 points larger (`nodeRadius(for:)`).
  useEffect(() => {
    const instance = cy.current;
    if (!instance) return;
    instance.batch(() => {
      instance.nodes().removeClass('shown active');
      for (const node of answer.nodes) {
        const drawn = instance.getElementById(`p${node.rollupId}`);
        if (drawn.nonempty()) drawn.data('size', 2 * nodeRadius(answer, node.rollupId, shown));
      }
      if (shown !== undefined) instance.getElementById(`p${shown}`).addClass('shown');
      if (active !== undefined) instance.getElementById(`p${active}`).addClass('active');
    });
  }, [answer, shown, active, size]);

  useEffect(() => {
    if (resetToken > 0) cy.current?.viewport({ zoom: 1, pan: { x: 0, y: 0 } });
  }, [resetToken]);

  return <div ref={container} className="network-cy" aria-hidden="true" />;
}
