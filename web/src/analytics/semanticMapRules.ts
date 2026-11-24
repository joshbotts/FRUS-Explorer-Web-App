// The semantic map's rules (PLAN's S28b), pure. The palette, a region's slot in it and the ground it is drawn on are the
// app's (`SemanticMapColouring`, `SemanticMapRenderer`), mirrored until S28a moves them into the kit and held to the
// app's lines by SemanticMapMirrorParityTests; so are the camera (`SemanticMapCamera`), the zoom step of the Mac's ⌘+ and
// ⌘− and its fit (`frameAll`). The pan by keyboard, the zoom about the pointer, the limits and the words for the zoom
// are the web's own.

export type Rgba = readonly [number, number, number, number];

/** How many palette slots the renderer holds (`SemanticMapColouring.paletteSize`). */
export const paletteSize = 16;

/** The region a point between regions names (`SemanticMapArtifacts.unclustered`). */
export const betweenRegions = 0xffff;

/** A colour from hue, saturation and brightness, each 0 to 1, as the app makes its palette (`SemanticMapColouring.hsb`). */
export function hsb(hue: number, saturation: number, brightness: number, alpha: number): Rgba {
  const sector = (hue - Math.floor(hue)) * 6;
  const fraction = sector - Math.floor(sector);
  const p = brightness * (1 - saturation);
  const q = brightness * (1 - saturation * fraction);
  const t = brightness * (1 - saturation * (1 - fraction));
  switch (Math.trunc(sector) % 6) {
    case 0: return [brightness, t, p, alpha];
    case 1: return [q, brightness, p, alpha];
    case 2: return [p, brightness, t, alpha];
    case 3: return [p, q, brightness, alpha];
    case 4: return [t, p, brightness, alpha];
    default: return [brightness, p, q, alpha];
  }
}

/**
 * The Regions lens's palette (`SemanticMapColouring.palette(for: .cluster)`): slot 0 for the documents between regions,
 * dim, so that the regions read as figure and the space between them as ground; then an even sweep of hues, which the
 * regions cycle through, so that colour separates neighbouring regions rather than naming them.
 */
export const regionPalette: readonly Rgba[] = [
  [0.35, 0.37, 0.42, 0.3],
  ...Array.from({ length: paletteSize - 1 }, (_, slot) => {
    const index = slot + 1;
    const hue = (index - 1) / (paletteSize - 1);
    return hsb(hue, 0.55, 0.95, 0.72);
  }),
];

/** A point's slot under the Regions lens (`SemanticMapColouring.indices(for: .cluster)`). */
export function regionSlot(region: number): number {
  return region === betweenRegions ? 0 : 1 + (region % (paletteSize - 1));
}

/** The map's ground (`SemanticMapRenderer.backgroundClearColor`), the same in either appearance, as the app's map is. */
export const background: Rgba = [0.06, 0.07, 0.09, 1];

/** A point's size, in the canvas's own pixels (`SemanticMapRenderer.pointSize`). */
export const pointSize = 2;

/** A colour as CSS gives it, alpha composited over the map's ground. */
export function onGround(colour: Rgba): string {
  const channel = (index: 0 | 1 | 2) => Math.round(255 * (colour[index] * colour[3] + background[index] * (1 - colour[3])));
  return `rgb(${channel(0)}, ${channel(1)}, ${channel(2)})`;
}

// ─── The camera ─────────────────────────────────────────────────────────────

/** Where the map is looked at (`SemanticMapCamera`): the grid point at the view's centre, and half the grid's height shown. */
export interface MapCamera {
  readonly centre: readonly [number, number];
  readonly halfExtent: number;
}

/** A view's size, in CSS pixels. */
export interface ViewSize {
  readonly width: number;
  readonly height: number;
}

/** The whole map in view (`SemanticMapRenderer.frameAll(extent:)`, ⌘0's Fit the Map). */
export function fitCamera(gridExtent: number): MapCamera {
  return { centre: [0, 0], halfExtent: gridExtent };
}

/**
 * Grid units per half view in each axis (`SemanticMapCamera.scale(aspect:)`): the aspect widens the longer axis, so a
 * resize disturbs nothing and a zoom distorts nothing.
 */
export function cameraScale(camera: MapCamera, aspect: number): [number, number] {
  const safeAspect = Number.isFinite(aspect) && aspect > 0 ? aspect : 1;
  return safeAspect >= 1 ? [camera.halfExtent * safeAspect, camera.halfExtent] : [camera.halfExtent, camera.halfExtent / safeAspect];
}

/** The zoom of the Mac's Zoom In and Zoom Out (⌘+, ⌘−). */
export const zoomStep = 1.4;
/** The zoom of a double click (the Mac's map view). */
export const doubleClickZoom = 1.6;
/** How far an arrow key moves the view: an eighth of its width or height. The web's own. */
export const panFraction = 1 / 8;
/** How far in and out the view may go: 512 times in, 4 times out, beyond which the map is a few points or a speck. */
export const zoomLimits = { closest: 512, farthest: 0.25 };

function aspectOf(size: ViewSize): number {
  return size.height > 0 ? size.width / size.height : 1;
}

/** Keeps the camera's zoom within the limits and its centre within reach of the map. */
export function clampCamera(camera: MapCamera, gridExtent: number): MapCamera {
  const halfExtent = Math.min(gridExtent / zoomLimits.farthest, Math.max(gridExtent / zoomLimits.closest, camera.halfExtent));
  const reach = 1.5 * gridExtent;
  const clamp = (value: number) => Math.min(reach, Math.max(-reach, value));
  return { centre: [clamp(camera.centre[0]), clamp(camera.centre[1])], halfExtent };
}

/** The grid point under a point of the view, in CSS pixels from its top left: the shader's projection inverted. */
export function gridPoint(camera: MapCamera, size: ViewSize, x: number, y: number): [number, number] {
  const [scaleX, scaleY] = cameraScale(camera, aspectOf(size));
  const clipX = size.width > 0 ? (2 * x) / size.width - 1 : 0;
  const clipY = size.height > 0 ? 1 - (2 * y) / size.height : 0;
  return [camera.centre[0] + clipX * scaleX, camera.centre[1] + clipY * scaleY];
}

/** Where a grid point falls in the view, in CSS pixels from its top left (`SemanticMapLabelLayout.project`). */
export function viewPoint(camera: MapCamera, size: ViewSize, grid: readonly [number, number]): [number, number] {
  const [scaleX, scaleY] = cameraScale(camera, aspectOf(size));
  const clipX = (grid[0] - camera.centre[0]) / scaleX;
  const clipY = (grid[1] - camera.centre[1]) / scaleY;
  return [((clipX + 1) / 2) * size.width, ((1 - clipY) / 2) * size.height];
}

/** The camera magnified by `factor`, about the view's centre, or about a grid point that stays where it is. */
export function zoomed(camera: MapCamera, factor: number, gridExtent: number, about?: readonly [number, number]): MapCamera {
  if (!Number.isFinite(factor) || factor <= 0) return camera;
  const next = clampCamera({ centre: camera.centre, halfExtent: camera.halfExtent / factor }, gridExtent);
  if (!about) return next;
  const applied = camera.halfExtent / next.halfExtent;
  return clampCamera(
    {
      centre: [about[0] + (camera.centre[0] - about[0]) / applied, about[1] + (camera.centre[1] - about[1]) / applied],
      halfExtent: next.halfExtent,
    },
    gridExtent,
  );
}

/** The camera moved by a drag of `dx`, `dy` CSS pixels (`SemanticMapRenderer.pan(by:)`): the map follows the pointer. */
export function panned(camera: MapCamera, dx: number, dy: number, size: ViewSize, gridExtent: number): MapCamera {
  const [scaleX, scaleY] = cameraScale(camera, aspectOf(size));
  const halfWidth = Math.max(1, size.width / 2);
  const halfHeight = Math.max(1, size.height / 2);
  return clampCamera(
    { centre: [camera.centre[0] - (dx / halfWidth) * scaleX, camera.centre[1] + (dy / halfHeight) * scaleY], halfExtent: camera.halfExtent },
    gridExtent,
  );
}

export type PanDirection = 'left' | 'right' | 'up' | 'down';

/** The camera moved by an arrow key: the view looks an eighth of its width or height further that way. */
export function steppedCamera(camera: MapCamera, direction: PanDirection, size: ViewSize, gridExtent: number): MapCamera {
  const [scaleX, scaleY] = cameraScale(camera, aspectOf(size));
  const x = direction === 'left' ? -1 : direction === 'right' ? 1 : 0;
  const y = direction === 'down' ? -1 : direction === 'up' ? 1 : 0;
  return clampCamera(
    { centre: [camera.centre[0] + x * 2 * panFraction * scaleX, camera.centre[1] + y * 2 * panFraction * scaleY], halfExtent: camera.halfExtent },
    gridExtent,
  );
}

/** How many times the camera magnifies the whole map. */
export function magnification(camera: MapCamera, gridExtent: number): number {
  return gridExtent / camera.halfExtent;
}

/** Whether the camera shows the map as its fit does, a zoom in and out again included. */
export function isFitted(camera: MapCamera, gridExtent: number): boolean {
  const near = (value: number, to: number) => Math.abs(value - to) <= 1e-9 * gridExtent;
  return near(camera.halfExtent, gridExtent) && near(camera.centre[0], 0) && near(camera.centre[1], 0);
}

/** The zoom in words, for the status a screen reader hears after a change: the whole map, or how many times in or out. */
export function zoomWords(
  camera: MapCamera,
  gridExtent: number,
  words: { whole: string; zoomedIn: (times: string) => string; zoomedOut: (times: string) => string; moved: string },
): string {
  if (isFitted(camera, gridExtent)) return words.whole;
  const times = magnification(camera, gridExtent);
  const shown = (value: number) => value.toLocaleString('en-US', { maximumFractionDigits: value < 10 ? 1 : 0 });
  if (times > 1.0001) return words.zoomedIn(shown(times));
  if (times < 0.9999) return words.zoomedOut(shown(1 / times));
  return words.moved;
}

/** The wheel's zoom for a wheel event's vertical delta: a notch of a mouse's wheel about 1.2 times, a trackpad's swipe smoothly. */
export function wheelZoom(deltaY: number, deltaMode: number): number {
  const pixels = deltaMode === 1 ? deltaY * 16 : deltaMode === 2 ? deltaY * 400 : deltaY;
  return Math.exp(-pixels * 0.002);
}
