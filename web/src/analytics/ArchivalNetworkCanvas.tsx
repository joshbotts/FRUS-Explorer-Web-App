// The archival network's canvas (PLAN's S24h), drawn as the app's `ArchivalNetworkView` draws its Canvas, at the places
// the kit's `ArchivalNetworkBuilder.layout` gives for this canvas's size: the four custodians' wedges with their
// captions, the rings at three quarters, a half and a quarter of the strongest link, the hull around the central-file
// classes while the Central Files record is expanded, a spoke from the focus to each partner, the partners' discs and
// squares in their custodian's colour, and the labels where the kit's `GraphNodeLabels.place` put them, the focus's on
// its plate. Cytoscape.js draws the discs and spokes; the wedges, rings and hull lie under it and the labels over it, in
// SVG that follows Cytoscape's pan and zoom. The canvas is hidden from screen readers, as the app's is: the list box the
// page lays over it is the keyboard's way through it, and the table below it its numbers. A click on a partner, or on
// a wedge, is the page's to act on; a drag pans and the wheel zooms, between half and four times, as the app's pinch does.
import cytoscape, { type Core, type ElementDefinition, type StylesheetJson } from 'cytoscape';
import { useEffect, useRef, useState } from 'react';
import type { NetworkAnswer } from '../api/archivalAnalytics';
import { custodianColors, nodeOpacity, sectorOpacity, sectorPath, spokeStyle } from './archivalRules';

export interface ArchivalNetworkCanvasProps {
  answer: NetworkAnswer;
  /** The partner the dock shows, and the one the keyboard is on. */
  shown?: string;
  active?: string;
  /** The custodian group selected, whose wedge is deepened. */
  group?: string;
  /** Changed to put the view back where it was laid out. */
  resetToken: number;
  onNode: (id: string) => void;
  onSector: (category: string) => void;
}

function tokens() {
  const css = getComputedStyle(document.documentElement);
  const read = (name: string, fallback: string) => css.getPropertyValue(name).trim() || fallback;
  return { accent: read('--accent', '#0a58b8'), bg: read('--bg', '#ffffff'), focus: read('--focus', '#0a58b8') };
}

function stylesheet(): StylesheetJson {
  const t = tokens();
  return [
    {
      selector: 'node',
      style: {
        width: 'data(size)',
        height: 'data(size)',
        shape: 'ellipse',
        'background-color': 'data(color)',
        'background-opacity': (node) => Number(node.data('opacity')),
        'border-width': 0,
      },
    },
    { selector: 'node.square', style: { shape: 'round-rectangle' } },
    { selector: 'node.focus', style: { 'background-color': t.accent, 'background-opacity': 1, 'border-width': 2, 'border-color': t.bg } },
    { selector: 'node.shown', style: { 'outline-width': 1.5, 'outline-color': '#ffffff', 'outline-offset': 2, 'outline-opacity': 1 } },
    { selector: 'node.active', style: { 'outline-width': 3, 'outline-color': t.focus, 'outline-offset': 2, 'outline-opacity': 1 } },
    {
      selector: 'edge',
      style: {
        width: 'data(width)',
        'line-color': 'data(color)',
        'line-opacity': (edge) => Number(edge.data('opacity')),
        'curve-style': 'straight',
      },
    },
  ];
}

/** The id of the stylesheet Cytoscape would otherwise add to the page. */
const cytoscapeStylesheetId = '__________cytoscape_stylesheet';

/** The wedge a point of the canvas falls in, by its angle about the centre and its distance from it. */
function wedgeAt(answer: NetworkAnswer, point: { x: number; y: number }): string | undefined {
  const layout = answer.layout;
  if (!layout) return undefined;
  for (const sector of answer.sectors) {
    const caption = layout.captions[sector.category];
    if (caption && point.x >= caption.rect.x && point.x <= caption.rect.x + caption.rect.width
        && point.y >= caption.rect.y && point.y <= caption.rect.y + caption.rect.height) return sector.category;
  }
  const dx = point.x - layout.center.x;
  const dy = point.y - layout.center.y;
  if (Math.hypot(dx, dy) > layout.outerRadius) return undefined;
  const degrees = ((Math.atan2(dy, dx) * 180) / Math.PI + 360) % 360;
  return answer.sectors.find((sector) => {
    const offset = (degrees - sector.start + 360) % 360;
    return offset < 90;
  })?.category;
}

export function ArchivalNetworkCanvas({ answer, shown, active, group, resetToken, onNode, onSector }: ArchivalNetworkCanvasProps) {
  const container = useRef<HTMLDivElement>(null);
  const cy = useRef<Core | null>(null);
  const handlers = useRef({ onNode, onSector, answer });
  const [view, setView] = useState({ zoom: 1, x: 0, y: 0 });
  useEffect(() => {
    handlers.current = { onNode, onSector, answer };
  }, [onNode, onSector, answer]);

  // One instance for the page's life, restyled when the theme changes.
  useEffect(() => {
    if (!container.current) return;
    if (!document.getElementById(cytoscapeStylesheetId)) {
      const marker = document.createElement('meta');
      marker.id = cytoscapeStylesheetId;
      document.head.append(marker);
    }
    const instance = cytoscape({
      container: container.current,
      style: stylesheet(),
      layout: { name: 'preset' },
      minZoom: 0.5,
      maxZoom: 4,
      autoungrabify: true,
      autounselectify: true,
      boxSelectionEnabled: false,
    });
    instance.on('tap', 'node.partner', (event) => handlers.current.onNode(String(event.target.data('nodeId'))));
    instance.on('tap', (event) => {
      if (event.target !== instance) return;
      const wedge = wedgeAt(handlers.current.answer, event.position);
      if (wedge) handlers.current.onSector(wedge);
    });
    instance.on('viewport', () => {
      const pan = instance.pan();
      setView({ zoom: instance.zoom(), x: pan.x, y: pan.y });
    });
    cy.current = instance;
    const theme = new MutationObserver(() => instance.style(stylesheet()));
    theme.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    return () => {
      theme.disconnect();
      instance.destroy();
      cy.current = null;
    };
  }, []);

  // The network drawn afresh at the kit's places whenever it changes.
  useEffect(() => {
    const instance = cy.current;
    const layout = answer.layout;
    if (!instance) return;
    const elements: ElementDefinition[] = [];
    if (layout && answer.focus) {
      elements.push({
        group: 'nodes',
        data: { id: 'focus', size: 52, color: '#000000', opacity: 1 },
        position: { x: layout.center.x, y: layout.center.y },
        classes: 'focus',
      });
      answer.nodes.forEach((node, index) => {
        const place = layout.positions[node.id];
        if (!place) return;
        const color = custodianColors[node.category] ?? '#8E8E93';
        const spoke = spokeStyle(node.relativeStrength);
        elements.push({
          group: 'edges',
          data: { id: `s${index}`, source: 'focus', target: `n${index}`, width: spoke.width, opacity: spoke.opacity, color },
          selectable: false,
        });
        elements.push({
          group: 'nodes',
          data: { id: `n${index}`, nodeId: node.id, size: 2 * node.radius, color, opacity: nodeOpacity(false) },
          position: { x: place.x, y: place.y },
          // A collection is a disc and a central-file class a square, as the app draws them.
          classes: node.kind === 'collection' ? 'partner' : 'partner square',
        });
      });
    }
    instance.batch(() => {
      instance.elements().remove();
      instance.add(elements);
    });
    instance.resize();
    instance.viewport({ zoom: 1, pan: { x: 0, y: 0 } });
  }, [answer]);

  // The partner shown, larger and ringed (`drawnRadius(for:isSelected:)`), and the keyboard's.
  useEffect(() => {
    const instance = cy.current;
    if (!instance) return;
    instance.batch(() => {
      instance.nodes().removeClass('shown active');
      answer.nodes.forEach((node, index) => {
        const drawn = instance.getElementById(`n${index}`);
        if (drawn.empty()) return;
        const isShown = node.id === shown;
        drawn.data('size', 2 * (isShown ? node.selectedRadius : node.radius));
        drawn.data('opacity', nodeOpacity(isShown));
        if (isShown) drawn.addClass('shown');
        if (node.id === active) drawn.addClass('active');
      });
    });
  }, [answer, shown, active]);

  useEffect(() => {
    if (resetToken > 0) cy.current?.viewport({ zoom: 1, pan: { x: 0, y: 0 } });
  }, [resetToken]);

  const layout = answer.layout;
  const transform = `translate(${view.x} ${view.y}) scale(${view.zoom})`;
  return (
    <div className="archival-network-canvas" aria-hidden="true">
      {layout && (
        <svg className="archival-network-under" width={layout.width} height={layout.height}>
          <g transform={transform}>
            {answer.sectors.map((sector) => {
              const color = custodianColors[sector.category] ?? '#8E8E93';
              return (
                <path
                  key={sector.category}
                  d={sectorPath(layout.center, layout.outerRadius, sector.start)}
                  fill={color}
                  fillOpacity={sectorOpacity(group, sector.category)}
                  stroke={group === sector.category ? color : 'none'}
                  strokeOpacity={0.45}
                  strokeWidth={1}
                />
              );
            })}
            {layout.ringRadii.map((radius) => (
              <circle key={radius} cx={layout.center.x} cy={layout.center.y} r={radius} fill="none"
                      className="archival-network-ring" strokeWidth={0.5} strokeDasharray="4 4" />
            ))}
            {layout.classHull && (
              <rect x={layout.classHull.x} y={layout.classHull.y} width={layout.classHull.width} height={layout.classHull.height}
                    rx={18} fill="none" stroke={custodianColors.stateDepartment} strokeOpacity={0.5} strokeWidth={1} strokeDasharray="5 4" />
            )}
            {answer.sectors.map((sector) => {
              const caption = layout.captions[sector.category];
              if (!caption) return null;
              return (
                <text key={sector.category} className="archival-network-caption" x={caption.rect.x + caption.rect.width / 2}
                      y={caption.rect.y + caption.rect.height / 2} fill={custodianColors[sector.category]}
                      fillOpacity={group === sector.category ? 0.95 : 0.55}>
                  {caption.text}
                </text>
              );
            })}
            {layout.hullCaption && (
              <text className="archival-network-caption" x={layout.hullCaption.rect.x + layout.hullCaption.rect.width / 2}
                    y={layout.hullCaption.rect.y + layout.hullCaption.rect.height / 2} fill={custodianColors.stateDepartment}>
                {layout.hullCaption.text}
              </text>
            )}
          </g>
        </svg>
      )}
      <div ref={container} className="network-cy" />
      {layout && (
        <svg className="archival-network-over" width={layout.width} height={layout.height}>
          <g transform={transform}>
            {answer.plate && (
              <rect className="archival-network-plate" x={answer.plate.x} y={answer.plate.y} width={answer.plate.width}
                    height={answer.plate.height} rx={3} />
            )}
            {answer.labels.map((label) => (
              <text key={label.id} className={label.isFocus ? 'archival-network-label focus' : 'archival-network-label'}
                    x={label.rect.x + label.rect.width / 2} y={label.rect.y + label.rect.height / 2}>
                {label.text}
              </text>
            ))}
          </g>
        </svg>
      )}
    </div>
  );
}
