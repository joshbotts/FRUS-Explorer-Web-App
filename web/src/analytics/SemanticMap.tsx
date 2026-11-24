// Semantic Analytics' map (PLAN's S28b): the bundled map's points, drawn by the web's own WebGL2 renderer in the app's
// palette on its ground, with the Mac's Zoom In, Zoom Out and Fit the Map, and the app's legend for its Regions lens. A
// drag moves the map and the wheel, a pinch or a double click zooms it about the pointer; with the map focused, the
// arrow keys move it an eighth of the view, + and − zoom it by the Mac's step and 0 fits it. The canvas is hidden from
// screen readers, as the app's is: the regions' table beside it is their map, and the zoom is said in a status line.
import { type KeyboardEvent, type MouseEvent, type PointerEvent, useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { copy } from '../copy';
import { SemanticMapRenderer } from './semanticMapRenderer';
import {
  doubleClickZoom,
  fitCamera,
  gridPoint,
  magnification,
  type MapCamera,
  onGround,
  panned,
  regionPalette,
  steppedCamera,
  type ViewSize,
  wheelZoom,
  zoomed,
  zoomStep,
  zoomWords,
} from './semanticMapRules';

const words = copy.semanticAnalytics;

/** The view a drawn frame shows, on the map's frame as `data-view`: the magnification and the centre on the grid. */
function viewKey(camera: MapCamera, gridExtent: number): string {
  return `${magnification(camera, gridExtent).toFixed(3)} ${Math.round(camera.centre[0])} ${Math.round(camera.centre[1])}`;
}

/** How long the zoom's words wait for the view to settle before the status line says them. */
const statusDelay = 300;

export function SemanticMap({
  points,
  gridExtent,
  onUnavailable,
}: {
  /** The server's answer: six bytes a point. */
  points: ArrayBuffer;
  gridExtent: number;
  /** The browser could not draw the map after all: its WebGL2 failed, with why. */
  onUnavailable: (reason: string) => void;
}) {
  const helpId = useId();
  const frame = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const renderer = useRef<SemanticMapRenderer | null>(null);
  const size = useRef<ViewSize>({ width: 0, height: 0 });
  const latest = useRef<MapCamera>(fitCamera(gridExtent));
  const scheduled = useRef<number | null>(null);
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const [camera, setCamera] = useState<MapCamera>(() => fitCamera(gridExtent));
  const [status, setStatus] = useState(() => zoomWords(fitCamera(gridExtent), gridExtent, words.zoom));

  // One frame for however many changes come before the next animation frame.
  const requestDraw = useEffectEvent(() => {
    if (scheduled.current !== null) return;
    scheduled.current = requestAnimationFrame(() => {
      scheduled.current = null;
      const drawn = renderer.current;
      const view = frame.current;
      if (!drawn || !view) return;
      drawn.draw(latest.current);
      view.dataset.view = viewKey(latest.current, gridExtent);
    });
  });
  const unavailable = useEffectEvent((reason: string) => onUnavailable(reason));

  // The renderer, the points uploaded once, and the drawing buffer kept at the frame's size in the screen's own pixels.
  useEffect(() => {
    const element = canvas.current;
    const view = frame.current;
    if (!element || !view) return;
    const start = (): boolean => {
      try {
        const made = new SemanticMapRenderer(element, regionPalette);
        made.setPoints(points);
        renderer.current = made;
        return true;
      } catch (error) {
        renderer.current = null;
        unavailable(error instanceof Error ? error.message : String(error));
        return false;
      }
    };
    if (!start()) return;
    let pixels = { width: 0, height: 0 };
    const fit = () => {
      const drawn = renderer.current;
      if (!drawn) return;
      const side = drawn.maximumSide;
      element.width = Math.max(1, Math.min(side, pixels.width));
      element.height = Math.max(1, Math.min(side, pixels.height));
      requestDraw();
    };
    const observer = new ResizeObserver(([entry]) => {
      if (!entry) return;
      const { width, height } = entry.contentRect;
      size.current = { width, height };
      const device = entry.devicePixelContentBoxSize?.[0];
      const ratio = window.devicePixelRatio || 1;
      pixels = device
        ? { width: device.inlineSize, height: device.blockSize }
        : { width: Math.round(width * ratio), height: Math.round(height * ratio) };
      fit();
    });
    try {
      observer.observe(element, { box: 'device-pixel-content-box' });
    } catch {
      observer.observe(element);
    }
    // A lost context is let go and made again when the browser gives it back.
    const lost = (event: Event) => {
      event.preventDefault();
      renderer.current = null;
    };
    const restored = () => {
      if (start()) fit();
    };
    element.addEventListener('webglcontextlost', lost);
    element.addEventListener('webglcontextrestored', restored);
    return () => {
      observer.disconnect();
      element.removeEventListener('webglcontextlost', lost);
      element.removeEventListener('webglcontextrestored', restored);
      if (scheduled.current !== null) cancelAnimationFrame(scheduled.current);
      scheduled.current = null;
      renderer.current?.dispose();
      renderer.current = null;
    };
  }, [points]);

  // Each change of the view is drawn, and said once it settles.
  useEffect(() => {
    latest.current = camera;
    requestDraw();
    const timer = window.setTimeout(() => setStatus(zoomWords(camera, gridExtent, words.zoom)), statusDelay);
    return () => window.clearTimeout(timer);
  }, [camera, gridExtent]);

  // The wheel zooms about the pointer, so the page must not scroll under it: a listener that is not passive.
  useEffect(() => {
    const view = frame.current;
    if (!view) return;
    const wheel = (event: WheelEvent) => {
      event.preventDefault();
      const bounds = view.getBoundingClientRect();
      const at = { x: event.clientX - bounds.left, y: event.clientY - bounds.top };
      const factor = wheelZoom(event.deltaY, event.deltaMode);
      const current = size.current;
      setCamera((previous) => zoomed(previous, factor, gridExtent, gridPoint(previous, current, at.x, at.y)));
    };
    view.addEventListener('wheel', wheel, { passive: false });
    return () => view.removeEventListener('wheel', wheel);
  }, [gridExtent]);

  function zoomBy(factor: number) {
    setCamera((previous) => zoomed(previous, factor, gridExtent));
  }

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.altKey || event.ctrlKey || event.metaKey) return;
    const view = size.current;
    let next: ((previous: MapCamera) => MapCamera) | undefined;
    switch (event.key) {
      case 'ArrowLeft':
        next = (previous) => steppedCamera(previous, 'left', view, gridExtent);
        break;
      case 'ArrowRight':
        next = (previous) => steppedCamera(previous, 'right', view, gridExtent);
        break;
      case 'ArrowUp':
        next = (previous) => steppedCamera(previous, 'up', view, gridExtent);
        break;
      case 'ArrowDown':
        next = (previous) => steppedCamera(previous, 'down', view, gridExtent);
        break;
      case '+':
      case '=':
        next = (previous) => zoomed(previous, zoomStep, gridExtent);
        break;
      case '-':
      case '_':
      case '−':
        next = (previous) => zoomed(previous, 1 / zoomStep, gridExtent);
        break;
      case '0':
      case 'Home':
        next = () => fitCamera(gridExtent);
        break;
      default:
        return;
    }
    event.preventDefault();
    setCamera(next);
  }

  /** Where the pointer is in the frame, in CSS pixels from its top left. */
  function within(event: { clientX: number; clientY: number; currentTarget: HTMLElement }) {
    const bounds = event.currentTarget.getBoundingClientRect();
    return { x: event.clientX - bounds.left, y: event.clientY - bounds.top };
  }

  function onPointerDown(event: PointerEvent<HTMLDivElement>) {
    if (event.pointerType === 'mouse' && event.button !== 0) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
  }

  function onPointerMove(event: PointerEvent<HTMLDivElement>) {
    const held = pointers.current;
    const last = held.get(event.pointerId);
    if (!last) return;
    const view = size.current;
    if (held.size === 1) {
      const dx = event.clientX - last.x;
      const dy = event.clientY - last.y;
      held.set(event.pointerId, { x: event.clientX, y: event.clientY });
      if (dx !== 0 || dy !== 0) setCamera((previous) => panned(previous, dx, dy, view, gridExtent));
      return;
    }
    // Two fingers: the zoom is the change in their distance, about the point between them.
    const other = [...held.entries()].find(([id]) => id !== event.pointerId)?.[1];
    if (!other) return;
    const before = Math.hypot(last.x - other.x, last.y - other.y);
    const after = Math.hypot(event.clientX - other.x, event.clientY - other.y);
    held.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (before < 1 || after < 1) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    const middle = { x: (event.clientX + other.x) / 2 - bounds.left, y: (event.clientY + other.y) / 2 - bounds.top };
    setCamera((previous) => zoomed(previous, after / before, gridExtent, gridPoint(previous, view, middle.x, middle.y)));
  }

  function onPointerEnd(event: PointerEvent<HTMLDivElement>) {
    pointers.current.delete(event.pointerId);
  }

  function onDoubleClick(event: MouseEvent<HTMLDivElement>) {
    const at = within(event);
    const view = size.current;
    setCamera((previous) => zoomed(previous, doubleClickZoom, gridExtent, gridPoint(previous, view, at.x, at.y)));
  }

  return (
    <div className="semantic-map">
      <div className="semantic-map-controls">
        <div className="semantic-map-buttons" role="group" aria-label={words.controls}>
          <button type="button" onClick={() => zoomBy(zoomStep)}>
            {words.zoomIn}
          </button>
          <button type="button" onClick={() => zoomBy(1 / zoomStep)}>
            {words.zoomOut}
          </button>
          <button type="button" onClick={() => setCamera(fitCamera(gridExtent))}>
            {words.zoomFit}
          </button>
        </div>
        <p className="semantic-map-status" role="status">
          {status}
        </p>
      </div>
      <div
        ref={frame}
        className="semantic-map-frame"
        role="application"
        aria-label={words.map}
        aria-describedby={helpId}
        tabIndex={0}
        onKeyDown={onKeyDown}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerEnd}
        onPointerCancel={onPointerEnd}
        onDoubleClick={onDoubleClick}
      >
        <canvas ref={canvas} className="semantic-map-canvas" aria-hidden="true" />
      </div>
      <p id={helpId} className="semantic-map-help">
        {words.mapHelp}
      </p>
      <div className="semantic-map-legend">
        <span className="semantic-map-key">
          <span className="semantic-map-swatch" aria-hidden="true">
            <span style={{ background: onGround(regionPalette[0] ?? [0, 0, 0, 0]) }} />
          </span>
          {words.betweenRegions}
        </span>
        <p className="semantic-map-caption">{words.caption}</p>
      </div>
    </div>
  );
}
