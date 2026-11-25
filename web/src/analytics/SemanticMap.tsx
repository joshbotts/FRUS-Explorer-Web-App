// Semantic Analytics' map (PLAN's S28b, S28c): the bundled map's points, drawn by the web's own WebGL2 renderer on the
// app's ground, each in its slot of the lens's palette, the server's, and ghosted outside a scope as the app's renderer
// ghosts them; the regions' names over them, twenty-two at most, laid out by the kit on the server for the view at rest
// and carried with the map while it moves; a ring on the point the page has selected. A click on a name opens its
// region's card, as the app's tap does, and anywhere else picks the point nearest it, on the server, in the map's own
// coordinates. A drag moves the map and the wheel, a pinch or a double click zooms it about the pointer, with the Mac's
// Zoom In, Zoom Out and Fit the Map beside it.
//
// For the keyboard, the canvas is one stop, as the networks' are: a list box of the regions over it, largest first,
// whose Up and Down move from region to region, ringed on the map, and whose Enter opens the region's card, the
// web's path from there to a point; with it focused, Shift and an arrow move the view an eighth of it, + and − zoom
// it by the Mac's step and 0 fits it, and Escape closes the card the page shows. The canvas and the names are hidden
// from screen readers, as the app's are: the list box is their map, and the zoom is said in a status line.
//
// Since S28e it draws a slice as it draws the map, its points the slice's, with the slice's scale over them, the app's
// `sliceScaleOverlay`: the years up the side, the poles at the two ends and the undated volumes' row; and no names, as
// the app hides them there. With Lasso on, a drag draws a lasso, closed as it is drawn and thinned at the app's four
// points, whose path the page is given in the grid's own coordinates when the pointer lifts.
import { useQuery } from '@tanstack/react-query';
import { type KeyboardEvent, type MouseEvent, type PointerEvent, type RefObject, useEffect, useEffectEvent, useId, useMemo, useRef, useState } from 'react';
import {
  type SemanticMapListedRegion,
  type SemanticMapScopeAsk,
  type SemanticMapView,
  semanticMapLabelsQuery,
} from '../api/semanticMap';
import { copy } from '../copy';
import { SemanticMapRenderer } from './semanticMapRenderer';
import {
  carried,
  clampCamera,
  doubleClickZoom,
  extendedLasso,
  fitCamera,
  gridPoint,
  labelAt,
  magnification,
  type MapCamera,
  type MapView,
  panned,
  pickTolerance,
  type Rgba,
  steppedCamera,
  type ViewSize,
  viewPoint,
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
/** How long the view must rest before its names are asked for. */
const labelDelay = 120;
/** How far a press may move, in CSS pixels, and still be a click rather than a drag. */
const clickSlop = 4;

/** A camera the page brings the map to, by a reveal or a focus: each new serial moves it once. */
export interface MapFocus {
  readonly camera: MapCamera;
  readonly serial: number;
}

/** A slice's scale, as the page has it from the server: the years and the gutter on its grid, and its poles. */
export interface SliceScale {
  readonly from: string;
  readonly to: string;
  readonly ticks: readonly { year: number; y: number }[];
  readonly gutterY?: number;
  readonly undatedCount: number;
}

export function SemanticMap({
  points,
  gridExtent,
  lens,
  slots,
  palette,
  flags,
  scope,
  scopeKey,
  regions,
  centres,
  selectedRegion,
  marker,
  focus,
  onRegion,
  onPick,
  onEscape,
  onUnavailable,
  keysRef,
  layoutKey = 'map',
  names = true,
  slice,
  lassoing = false,
  onLasso,
  viewRef,
}: {
  /** The server's answer: six bytes a point. */
  points: ArrayBuffer;
  gridExtent: number;
  /** The lens drawn, its slot for every point and its palette. */
  lens: string;
  slots: Uint8Array;
  palette: readonly Rgba[];
  /** The scope's mask, a byte a point, or none for the whole series. */
  flags?: Uint8Array;
  scope: SemanticMapScopeAsk;
  /** The scope's value, on the frame as `data-scope`. */
  scopeKey: string;
  /** The regions the keyboard's list names, largest first. */
  regions: SemanticMapListedRegion[];
  /** Each region's centre on the grid, where its ring is drawn when it has no name in view. */
  centres: ReadonlyMap<number, readonly [number, number]>;
  /** The region whose card the page shows. */
  selectedRegion?: number;
  /** The selected point's place on the grid. */
  marker?: readonly [number, number];
  focus?: MapFocus;
  onRegion: (id: number) => void;
  /** A click away from the names: the grid point under it and the kit's tolerance for the view. */
  onPick: (grid: [number, number], tolerance: number) => void;
  /** Escape: closes the card the page shows, and says whether there was one. */
  onEscape: () => boolean;
  /** The browser could not draw the map after all: its WebGL2 failed, with why. */
  onUnavailable: (reason: string) => void;
  /** The list box, the canvas's one stop, where the page sends the keyboard back when a card closes. */
  keysRef?: RefObject<HTMLDivElement | null>;
  /** The layout drawn, the map's or a slice's: a new one is drawn whole, its camera fitted, as the app's `setSlice` frames it. */
  layoutKey?: string;
  /** Whether the regions' names are drawn: not on a slice, where a region's centre is no place. */
  names?: boolean;
  /** The slice's scale, drawn over its points. */
  slice?: SliceScale;
  /** Whether a drag draws a lasso instead of moving the map. */
  lassoing?: boolean;
  /** A lasso drawn: its path in the grid's own coordinates, three points or more. */
  onLasso?: (path: [number, number][]) => void;
  /** Where the page reads the view on screen, its camera and its drawing buffer's height, for the figure it exports. */
  viewRef?: RefObject<{ camera: MapCamera; pixelHeight: number } | null>;
}) {
  const helpId = useId();
  const prefix = useId();
  const frame = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const renderer = useRef<SemanticMapRenderer | null>(null);
  const size = useRef<ViewSize>({ width: 0, height: 0 });
  const latest = useRef<MapCamera>(fitCamera(gridExtent));
  const scheduled = useRef<number | null>(null);
  const sized = useRef(false);
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const press = useRef<{ x: number; y: number; moved: boolean } | null>(null);
  const drawnLens = useRef({ slots, palette });
  const drawnFlags = useRef(flags);
  const [camera, setCamera] = useState<MapCamera>(() => fitCamera(gridExtent));
  const [viewSize, setViewSize] = useState<ViewSize>({ width: 0, height: 0 });
  const [status, setStatus] = useState(() => zoomWords(fitCamera(gridExtent), gridExtent, words.zoom));
  const [settled, setSettled] = useState<SemanticMapView | undefined>(undefined);
  const [active, setActive] = useState<number | undefined>(undefined);
  const [keysFocused, setKeysFocused] = useState(false);
  // The lasso being drawn, in the view's CSS pixels, closed as it is drawn; empty when none is.
  const [lassoPath, setLassoPath] = useState<(readonly [number, number])[]>([]);
  // The stroke under way, with the layout it began on: one the layout or the setting has changed under is let go.
  const drawing = useRef<{ layout: string; points: (readonly [number, number])[] } | null>(null);

  // A new layout, the map's or a slice's, is fitted whole, and its names are asked for again, as the app frames the map
  // or the slice it has laid out (`frameAll(extent:)`); a lasso half drawn on the last one is let go.
  const [layoutSeen, setLayoutSeen] = useState(layoutKey);
  if (layoutKey !== layoutSeen) {
    setLayoutSeen(layoutKey);
    setCamera(fitCamera(gridExtent));
    setSettled(undefined);
    setLassoPath([]);
  }
  // Lasso off drops a stroke under way.
  const [lassoSeen, setLassoSeen] = useState(lassoing);
  if (lassoing !== lassoSeen) {
    setLassoSeen(lassoing);
    setLassoPath([]);
  }

  // The view drawn now, once the drawing buffer has the frame's size: never at the canvas's first 300 by 150.
  const drawNow = useEffectEvent(() => {
    const drawn = renderer.current;
    const view = frame.current;
    if (!drawn || !view || !sized.current) return;
    drawn.draw(latest.current);
    view.dataset.view = viewKey(latest.current, gridExtent);
    if (viewRef) viewRef.current = { camera: latest.current, pixelHeight: canvas.current?.height ?? 0 };
  });
  // One frame for however many changes come before the next animation frame.
  const requestDraw = useEffectEvent(() => {
    if (scheduled.current !== null) return;
    scheduled.current = requestAnimationFrame(() => {
      scheduled.current = null;
      drawNow();
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
        const made = new SemanticMapRenderer(element, drawnLens.current.palette);
        made.setPoints(points);
        made.setLens(drawnLens.current.slots, drawnLens.current.palette);
        made.setScope(drawnFlags.current);
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
    // A new size clears the canvas, so the view is drawn again at once, before the browser paints the cleared one. A
    // frame wider than the GPU allows is drawn smaller in both sides alike, keeping its aspect.
    const fit = () => {
      const drawn = renderer.current;
      if (!drawn || pixels.width < 1 || pixels.height < 1) return;
      const shrink = Math.min(1, drawn.maximumSide / Math.max(pixels.width, pixels.height));
      element.width = Math.max(1, Math.round(pixels.width * shrink));
      element.height = Math.max(1, Math.round(pixels.height * shrink));
      sized.current = true;
      drawNow();
    };
    const observer = new ResizeObserver(([entry]) => {
      if (!entry) return;
      const { width, height } = entry.contentRect;
      size.current = { width, height };
      setViewSize((previous) => (previous.width === width && previous.height === height ? previous : { width, height }));
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
    // A lost context is let go and made again when the browser gives it back, with the lens and the scope it drew.
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
      sized.current = false;
      renderer.current?.dispose();
      renderer.current = null;
    };
  }, [points]);

  // A new lens, or a new scope, rewrites a byte a point and draws again; the coordinates stay as they are.
  useEffect(() => {
    drawnLens.current = { slots, palette };
    renderer.current?.setLens(slots, palette);
    requestDraw();
  }, [slots, palette]);
  useEffect(() => {
    drawnFlags.current = flags;
    renderer.current?.setScope(flags);
    requestDraw();
  }, [flags]);

  // Each change of the view is drawn, and said once it settles; its names are asked for once it rests.
  useEffect(() => {
    latest.current = camera;
    requestDraw();
    const timer = window.setTimeout(() => setStatus(zoomWords(camera, gridExtent, words.zoom)), statusDelay);
    return () => window.clearTimeout(timer);
  }, [camera, gridExtent]);
  useEffect(() => {
    if (!names || viewSize.width <= 0 || viewSize.height <= 0) return;
    const timer = window.setTimeout(
      () => setSettled({ x: camera.centre[0], y: camera.centre[1], halfExtent: camera.halfExtent, width: viewSize.width, height: viewSize.height }),
      labelDelay,
    );
    return () => window.clearTimeout(timer);
  }, [camera, viewSize, names]);

  // The page's reveal or focus brings the camera to it, once a serial: the view adjusted as the page draws, not after.
  const [focusSeen, setFocusSeen] = useState<number | undefined>(undefined);
  if (focus && focus.serial !== focusSeen) {
    setFocusSeen(focus.serial);
    setCamera(clampCamera(focus.camera, gridExtent));
  }

  // The names for the view at rest: the kit's layout, for this camera, size and scope, the last view's meanwhile.
  const labels = useQuery({
    ...semanticMapLabelsQuery(settled ?? { x: 0, y: 0, halfExtent: 1, width: 1, height: 1 }, scope),
    enabled: names && settled !== undefined,
  });
  const shown = names ? labels.data : undefined;

  // Where each name is drawn now: as laid out, or carried with the map from the view it was laid out for.
  const laidOutHere =
    shown !== undefined &&
    shown.view.halfExtent === camera.halfExtent &&
    shown.view.x === camera.centre[0] &&
    shown.view.y === camera.centre[1] &&
    shown.view.width === viewSize.width &&
    shown.view.height === viewSize.height;
  const drawnLabels = useMemo(() => {
    if (!shown) return [];
    if (laidOutHere) return shown.labels;
    const laidOut: MapView = {
      camera: { centre: [shown.view.x, shown.view.y], halfExtent: shown.view.halfExtent },
      size: { width: shown.view.width, height: shown.view.height },
    };
    const now: MapView = { camera, size: viewSize };
    return shown.labels.map((label) => {
      const [x, y] = carried(label, laidOut, now);
      return { ...label, x, y };
    });
  }, [shown, laidOutHere, camera, viewSize]);

  // The keyboard's region, kept while the list holds it.
  const activeIndex = Math.max(
    0,
    regions.findIndex((region) => region.id === active),
  );
  const activeRegion = keysFocused ? regions[activeIndex] : undefined;
  const ringedLabel = activeRegion ? drawnLabels.find((label) => label.id === activeRegion.id) : undefined;
  // A region's centre is a place on the map's plane alone, so a slice rings none.
  const ringedCentre = names && activeRegion && !ringedLabel ? centres.get(activeRegion.id) : undefined;

  // The wheel zooms about the pointer, so the page must not scroll under it: a listener that is not passive.
  useEffect(() => {
    const view = frame.current;
    if (!view) return;
    const wheel = (event: WheelEvent) => {
      const factor = wheelZoom(event.deltaY, event.deltaMode);
      // A sideways scroll zooms nothing, and goes on to the page.
      if (factor === 1) return;
      event.preventDefault();
      const bounds = view.getBoundingClientRect();
      const at = { x: event.clientX - bounds.left, y: event.clientY - bounds.top };
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
    if (event.shiftKey && event.key.startsWith('Arrow')) {
      const direction = ({ ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' } as const)[event.key as 'ArrowLeft'];
      if (!direction) return;
      next = (previous) => steppedCamera(previous, direction, view, gridExtent);
    } else {
      switch (event.key) {
        case 'ArrowDown':
        case 'ArrowUp':
        case 'Home':
        case 'End': {
          event.preventDefault();
          if (regions.length === 0) return;
          const to =
            event.key === 'Home' ? 0
            : event.key === 'End' ? regions.length - 1
            : event.key === 'ArrowDown' ? Math.min(activeIndex + 1, regions.length - 1)
            : Math.max(activeIndex - 1, 0);
          setActive(regions[to]?.id);
          return;
        }
        case 'Enter':
        case ' ': {
          event.preventDefault();
          const region = regions[activeIndex];
          if (region) {
            setActive(region.id);
            onRegion(region.id);
          }
          return;
        }
        case 'Escape':
          if (onEscape()) event.preventDefault();
          return;
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
          next = () => fitCamera(gridExtent);
          break;
        default:
          return;
      }
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
    // A Mac's Control-click opens a context menu, which keeps the release: it moves nothing.
    if (event.pointerType === 'mouse' && (event.button !== 0 || event.ctrlKey)) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    press.current = pointers.current.size === 1 ? { x: event.clientX, y: event.clientY, moved: false } : null;
    // With Lasso on, one pointer draws; a second lets the stroke go and pinches.
    if (lassoing && pointers.current.size === 1) {
      const at = within(event);
      drawing.current = { layout: layoutKey, points: [[at.x, at.y]] };
      setLassoPath(drawing.current.points);
    } else {
      drawing.current = null;
      setLassoPath([]);
    }
  }

  function onPointerMove(event: PointerEvent<HTMLDivElement>) {
    const held = pointers.current;
    const last = held.get(event.pointerId);
    if (!last) return;
    // A mouse with no button down was released where the page could not hear it: its drag is over.
    if (event.pointerType === 'mouse' && event.buttons === 0) {
      held.delete(event.pointerId);
      return;
    }
    const started = press.current;
    if (started && Math.hypot(event.clientX - started.x, event.clientY - started.y) > clickSlop) started.moved = true;
    const view = size.current;
    if (held.size === 1 && drawing.current) {
      held.set(event.pointerId, { x: event.clientX, y: event.clientY });
      if (!lassoing || drawing.current.layout !== layoutKey) {
        drawing.current = null;
        setLassoPath([]);
        return;
      }
      const at = within(event);
      const next = extendedLasso(drawing.current.points, [at.x, at.y]);
      if (next.length !== drawing.current.points.length) {
        drawing.current = { layout: layoutKey, points: next };
        setLassoPath(next);
      }
      return;
    }
    if (held.size === 1) {
      const dx = event.clientX - last.x;
      const dy = event.clientY - last.y;
      held.set(event.pointerId, { x: event.clientX, y: event.clientY });
      if (dx !== 0 || dy !== 0) setCamera((previous) => panned(previous, dx, dy, view, gridExtent));
      return;
    }
    // Two fingers: the zoom is the change in their distance, about the point between them.
    if (started) started.moved = true;
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
    const stroke = drawing.current;
    drawing.current = null;
    if (!stroke) return;
    setLassoPath([]);
    // A press that did not move is a click, which picks; a stroke closes on its first point, as the app's does; and one
    // begun on another layout, or before Lasso was turned off, is let go.
    if (event.type !== 'pointerup' || press.current?.moved !== true || stroke.points.length < 3) return;
    if (!lassoing || stroke.layout !== layoutKey) return;
    const view = size.current;
    onLasso?.(stroke.points.map(([x, y]) => gridPoint(latest.current, view, x, y)));
  }

  // A press that did not move: a click on a drawn name opens its region, and anywhere else picks the point nearest it.
  function onClick(event: MouseEvent<HTMLDivElement>) {
    const started = press.current;
    press.current = null;
    if (!started || started.moved || event.button !== 0) return;
    const at = within(event);
    const label = labelAt(drawnLabels, at.x, at.y);
    if (label) {
      setActive(label.id);
      onRegion(label.id);
      return;
    }
    const view = size.current;
    onPick(gridPoint(latest.current, view, at.x, at.y), pickTolerance(latest.current, view));
  }

  function onDoubleClick(event: MouseEvent<HTMLDivElement>) {
    const at = within(event);
    const view = size.current;
    setCamera((previous) => zoomed(previous, doubleClickZoom, gridExtent, gridPoint(previous, view, at.x, at.y)));
  }

  const markerAt = marker && viewSize.width > 0 ? viewPoint(camera, viewSize, marker) : undefined;
  const centreAt = ringedCentre && viewSize.width > 0 ? viewPoint(camera, viewSize, ringedCentre) : undefined;

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
        data-lens={lens}
        data-scope={scopeKey}
        data-labels={drawnLabels.length}
        data-names={!names ? 'none' : shown ? (laidOutHere ? 'laid-out' : 'carried') : undefined}
        data-layout={layoutKey}
        data-lassoing={lassoing ? 'true' : undefined}
        data-marker={marker ? `${marker[0]} ${marker[1]}` : undefined}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerEnd}
        onPointerCancel={onPointerEnd}
        onLostPointerCapture={onPointerEnd}
        onClick={onClick}
        onDoubleClick={onDoubleClick}
      >
        <canvas ref={canvas} className="semantic-map-canvas" aria-hidden="true" />
        <div className="semantic-map-names" aria-hidden="true">
          {drawnLabels.map((label) => (
            <span
              key={label.id}
              className={label.id === ringedLabel?.id ? 'semantic-map-name is-active' : 'semantic-map-name'}
              data-region={label.id}
              style={{ left: `${label.x}px`, top: `${label.y}px` }}
            >
              {label.text}
            </span>
          ))}
          {centreAt && <span className="semantic-map-ring" style={{ left: `${centreAt[0]}px`, top: `${centreAt[1]}px` }} />}
          {markerAt && <span className="semantic-map-marker" style={{ left: `${markerAt[0]}px`, top: `${markerAt[1]}px` }} />}
          {slice && viewSize.width > 0 && <SliceOverlay slice={slice} camera={camera} size={viewSize} gridExtent={gridExtent} />}
        </div>
        {lassoPath.length > 1 && (
          // Closed while drawn, as the app draws it, since what it holds is decided against the closed shape.
          <svg className="semantic-map-lasso" aria-hidden="true" width={viewSize.width} height={viewSize.height}>
            <polygon points={lassoPath.map(([x, y]) => `${x},${y}`).join(' ')} />
          </svg>
        )}
        <div
          ref={keysRef}
          role="listbox"
          tabIndex={0}
          className="semantic-map-keys"
          aria-label={words.map}
          aria-describedby={helpId}
          aria-activedescendant={regions.length > 0 ? `${prefix}-${activeIndex}` : undefined}
          onKeyDown={onKeyDown}
          onFocus={() => {
            setKeysFocused(true);
            if (active === undefined && regions[0]) setActive(regions[0].id);
          }}
          onBlur={() => setKeysFocused(false)}
        >
          {regions.map((region, at) => (
            <div
              key={region.id}
              role="option"
              id={`${prefix}-${at}`}
              aria-selected={selectedRegion === region.id}
              className="semantic-map-option"
            >
              {region.accessibilityLabel}, {region.accessibilityValue}
            </div>
          ))}
        </div>
      </div>
      <p id={helpId} className="semantic-map-help">
        {words.mapHelp}
      </p>
    </div>
  );
}

/**
 * The slice's scale over its points (`sliceScaleOverlay`): each year the server names at its row on the slice's grid,
 * through the camera the points are drawn through, at the left edge while it is in view; the poles at the two ends of
 * the axis they define; and the undated volumes' row, when anything is in it.
 */
function SliceOverlay({ slice, camera, size, gridExtent }: { slice: SliceScale; camera: MapCamera; size: { width: number; height: number }; gridExtent: number }) {
  const inView = (y: number) => y > 8 && y < size.height - 8;
  const gutter = slice.undatedCount > 0 && slice.gutterY !== undefined ? viewPoint(camera, size, [-gridExtent, slice.gutterY])[1] : undefined;
  return (
    <>
      {slice.ticks.map((tick) => {
        const y = viewPoint(camera, size, [-gridExtent, tick.y])[1];
        return inView(y) ? (
          <span key={tick.year} className="semantic-slice-tick" style={{ left: '24px', top: `${y}px` }}>
            {tick.year}
          </span>
        ) : null;
      })}
      <span className="semantic-slice-pole" style={{ left: '56px', top: `${size.height - 14}px` }}>
        {words.axis.low(slice.from)}
      </span>
      <span className="semantic-slice-pole" style={{ left: `${size.width - 56}px`, top: `${size.height - 14}px` }}>
        {words.axis.high(slice.to)}
      </span>
      {gutter !== undefined && inView(gutter) && (
        <span className="semantic-slice-gutter" style={{ left: '44px', top: `${gutter}px` }}>
          {words.axis.gutter(slice.undatedCount)}
        </span>
      )}
    </>
  );
}
