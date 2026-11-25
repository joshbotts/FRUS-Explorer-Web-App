// The semantic map's rules (PLAN's S28b, S28c): the colours a key's swatch and the legend give, and the camera: the
// app's scale, the shader's projection and its inverse, the zoom about a point that stays put, the pan by pointer and by
// keyboard, the limits and the zoom in words; since S28c a pick's tolerance from the view, a click on a drawn name, a
// name carried with the map, a camera from the server and the address; since S28e a lasso's stroke, a point's place in
// a points answer and a slice's poles in the address.
import { describe, expect, it } from 'vitest';
import {
  cameraFrom,
  cameraScale,
  carried,
  clampCamera,
  extendedLasso,
  fitCamera,
  gridPoint,
  isFitted,
  labelAt,
  lassoStep,
  magnification,
  onGround,
  panned,
  pickTolerance,
  pointAt,
  steppedCamera,
  swatchColour,
  validateSemanticSearch,
  viewPoint,
  wheelZoom,
  zoomed,
  zoomStep,
  zoomWords,
} from './semanticMapRules';

const extent = 30_000;
const size = { width: 900, height: 600 };
const words = { whole: 'whole', zoomedIn: (t: string) => `in ${t}`, zoomedOut: (t: string) => `out ${t}`, moved: 'moved' };

function close(actual: readonly number[], expected: readonly number[], digits = 6) {
  expect(actual.length).toBe(expected.length);
  actual.forEach((value, index) => expect(value).toBeCloseTo(expected[index] ?? NaN, digits));
}

describe('the colours', () => {
  it('gives a swatch its slot’s colour, opaque, as the app’s key does, and none for a slot the palette has not', () => {
    const palette = [[0.35, 0.37, 0.42, 0.3], [0.35, 0.78, 0.52, 0.8], [1.2, -0.1, 0.5, 1]] as const;
    expect(swatchColour(palette, 0)).toBe('rgb(89, 94, 107)');
    expect(swatchColour(palette, 1)).toBe('rgb(89, 199, 133)');
    expect(swatchColour(palette, 2)).toBe('rgb(255, 0, 128)');
    expect(swatchColour(palette, 3)).toBeUndefined();
  });

  it('composites a colour over the map’s ground', () => {
    expect(onGround([0.35, 0.37, 0.42, 0.3])).toBe('rgb(37, 41, 48)');
    expect(onGround([1, 1, 1, 1])).toBe('rgb(255, 255, 255)');
  });
});

describe('the camera', () => {
  it('fits the whole grid, and widens the longer side by the view’s aspect, as the app’s does', () => {
    const fitted = fitCamera(extent);
    expect(fitted).toEqual({ centre: [0, 0], halfExtent: extent });
    expect(cameraScale(fitted, 1.5)).toEqual([45_000, 30_000]);
    expect(cameraScale(fitted, 0.5)).toEqual([30_000, 60_000]);
    expect(cameraScale(fitted, 0)).toEqual([30_000, 30_000]);
    expect(isFitted(fitted, extent) && magnification(fitted, extent) === 1).toBe(true);
  });

  it('projects as the shader does, y up, and the view’s points back onto the grid', () => {
    const camera = { centre: [1_000, -2_000] as const, halfExtent: 10_000 };
    close(viewPoint(camera, size, [1_000, -2_000]), [450, 300]);
    close(viewPoint(camera, size, [1_000 + 15_000, -2_000 + 10_000]), [900, 0]);
    close(viewPoint(camera, size, [1_000 - 15_000, -2_000 - 10_000]), [0, 600]);
    for (const [x, y] of [[0, 0], [123, 456], [900, 600]] as const) close(viewPoint(camera, size, gridPoint(camera, size, x, y)), [x, y]);
  });

  it('zooms by the Mac’s step about the centre, and about a point that stays where it is', () => {
    const fitted = fitCamera(extent);
    expect(zoomed(fitted, zoomStep, extent).halfExtent).toBeCloseTo(extent / 1.4);
    expect(zoomed(zoomed(fitted, zoomStep, extent), 1 / zoomStep, extent).halfExtent).toBeCloseTo(extent);
    const about = gridPoint(fitted, size, 700, 150);
    const nearer = zoomed(fitted, 3, extent, about);
    close(viewPoint(nearer, size, about), [700, 150], 4);
    expect(magnification(nearer, extent)).toBeCloseTo(3);
  });

  it('keeps the zoom and the centre within reach of the map', () => {
    expect(zoomed(fitCamera(extent), 10_000, extent).halfExtent).toBe(extent / 512);
    expect(zoomed(fitCamera(extent), 1 / 100, extent).halfExtent).toBe(extent * 4);
    expect(clampCamera({ centre: [1e9, -1e9], halfExtent: extent }, extent).centre).toEqual([45_000, -45_000]);
  });

  it('follows a drag, and moves an eighth of the view for an arrow key', () => {
    const fitted = fitCamera(extent);
    // A drag of 45 pixels to the right moves the map with it: the view looks 45/450 of its half-width further left.
    close(panned(fitted, 45, -30, size, extent).centre, [-4_500, -3_000]);
    close(steppedCamera(fitted, 'right', size, extent).centre, [11_250, 0]);
    close(steppedCamera(fitted, 'up', size, extent).centre, [0, 7_500]);
    close(steppedCamera(steppedCamera(fitted, 'left', size, extent), 'right', size, extent).centre, [0, 0]);
    close(steppedCamera(fitted, 'down', size, extent).centre, [0, -7_500]);
  });

  it('says the zoom in words', () => {
    const fitted = fitCamera(extent);
    expect(zoomWords(fitted, extent, words)).toBe('whole');
    expect(zoomWords(zoomed(zoomed(fitted, zoomStep, extent), 1 / zoomStep, extent), extent, words)).toBe('whole');
    expect(zoomWords(zoomed(fitted, zoomStep, extent), extent, words)).toBe('in 1.4');
    expect(zoomWords(zoomed(fitted, 1 / zoomStep, extent), extent, words)).toBe('out 1.4');
    expect(zoomWords(zoomed(fitted, 27.3, extent), extent, words)).toBe('in 27');
    expect(zoomWords(steppedCamera(fitted, 'left', size, extent), extent, words)).toBe('moved');
  });

  it('zooms in for a wheel turned away from the reader, and out for one turned towards them', () => {
    expect(wheelZoom(-100, 0)).toBeGreaterThan(1);
    expect(wheelZoom(100, 0)).toBeLessThan(1);
    expect(wheelZoom(-3, 1)).toBeCloseTo(wheelZoom(-48, 0));
    expect(wheelZoom(0, 0)).toBe(1);
  });
});

describe('picks and names', () => {
  it('gives a pick the app’s tolerance: 22 pixels in grid units, by the larger of the two axes’', () => {
    const fitted = fitCamera(extent);
    // A view of 900 by 600 at the whole map: 45,000 by 30,000 grid units a half, 100 units a pixel either way.
    expect(pickTolerance(fitted, size)).toBeCloseTo(2_200);
    // Zoomed in ten times, a tenth of it.
    expect(pickTolerance(zoomed(fitted, 10, extent), size)).toBeCloseTo(220);
    // A tall view widens the height's scale, and the tolerance follows the larger.
    expect(pickTolerance(fitted, { width: 300, height: 600 })).toBeCloseTo((22 * 2 * 60_000) / 600);
    expect(pickTolerance(fitted, { width: 0, height: 600 })).toBe(0);
  });

  it('finds the drawn name a click lands on: the first within 22 pixels of its middle, in the layout’s order', () => {
    const labels = [
      { id: 3, x: 100, y: 100 },
      { id: 7, x: 110, y: 100 },
      { id: 9, x: 400, y: 300 },
    ];
    expect(labelAt(labels, 105, 100)?.id).toBe(3);
    expect(labelAt(labels, 131, 100)?.id).toBe(7);
    expect(labelAt(labels, 400, 322)?.id).toBe(9);
    expect(labelAt(labels, 400, 323)).toBeUndefined();
    expect(labelAt([], 0, 0)).toBeUndefined();
  });

  it('carries a name with the map from the view it was laid out for', () => {
    const from = { camera: fitCamera(extent), size };
    const to = { camera: zoomed(panned(fitCamera(extent), 90, 0, size, extent), 2, extent), size };
    const grid = gridPoint(from.camera, size, 300, 200);
    close(carried({ x: 300, y: 200 }, from, to), viewPoint(to.camera, size, grid));
    close(carried({ x: 300, y: 200 }, from, from), [300, 200]);
  });

  it('takes a reveal’s camera from the server, kept within the limits', () => {
    expect(cameraFrom({ x: 1_000, y: -2_000, halfExtent: 900 }, extent)).toEqual({ centre: [1_000, -2_000], halfExtent: 900 });
    expect(cameraFrom({ x: 1e9, y: 0, halfExtent: 1 }, extent)).toEqual({ centre: [45_000, 0], halfExtent: extent / 512 });
  });
});

describe('the address', () => {
  it('keeps the request’s fields and drops what does not fit', () => {
    expect(validateSemanticSearch({})).toEqual({});
    expect(
      validateSemanticSearch({ lens: 'era', document: 'frus1961-63v06/d1', region: '12', layout: '89481b18:2026-10-15:314616', administration: 'nixon' }),
    ).toEqual({ lens: 'era', document: 'frus1961-63v06/d1', region: 12, layout: '89481b18:2026-10-15:314616', administration: 'nixon' });
    expect(validateSemanticSearch({ volumes: ['a', '', 'b'], scopeLabel: 'Mine' })).toEqual({ volumes: ['a', 'b'], scopeLabel: 'Mine' });
    for (const region of ['012', '-1', '1.5', 'x', '123456', '']) expect(validateSemanticSearch({ region })).toEqual({});
    expect(validateSemanticSearch({ region: 0 })).toEqual({ region: 0 });
  });

  it('carries a slice’s two poles, both or neither (S28e)', () => {
    expect(validateSemanticSearch({ from: 'frus1961-63v06', to: 'frus1969-76ve09p1' })).toEqual({ from: 'frus1961-63v06', to: 'frus1969-76ve09p1' });
    expect(validateSemanticSearch({ from: 'frus1961-63v06' })).toEqual({});
    expect(validateSemanticSearch({ to: 'frus1969-76ve09p1', lens: 'era' })).toEqual({ lens: 'era' });
    expect(validateSemanticSearch({ from: '', to: 'frus1969-76ve09p1' })).toEqual({});
  });
});

describe('the map’s tools (S28e)', () => {
  it('thins a lasso’s stroke as the app does, taking a point only four pixels or more from the last on an axis', () => {
    let path: (readonly [number, number])[] = [[10, 10]];
    path = extendedLasso(path, [13, 13]);
    expect(path).toEqual([[10, 10]]);
    path = extendedLasso(path, [14, 11]);
    expect(path).toEqual([[10, 10], [14, 11]]);
    path = extendedLasso(path, [14, 7]);
    expect(path).toEqual([[10, 10], [14, 11], [14, 7]]);
    expect(extendedLasso([], [1, 2])).toEqual([[1, 2]]);
    expect(lassoStep).toBe(4);
  });

  it('reads a point’s place from a points answer, six bytes a point', () => {
    const bytes = new ArrayBuffer(12);
    const view = new DataView(bytes);
    view.setInt16(0, -19_710, true);
    view.setInt16(2, -219, true);
    view.setUint16(4, 115, true);
    view.setInt16(6, 30_000, true);
    view.setInt16(8, -30_000, true);
    view.setUint16(10, 0xffff, true);
    expect(pointAt(bytes, 0)).toEqual([-19_710, -219]);
    expect(pointAt(bytes, 1)).toEqual([30_000, -30_000]);
    expect(pointAt(bytes, 2)).toBeUndefined();
    expect(pointAt(bytes, -1)).toBeUndefined();
    expect(pointAt(bytes, 0.5)).toBeUndefined();
  });
});
