// The semantic map's rules (PLAN's S28b): the app's palette and a region's slot in it, the colours it gives, and the
// camera: the app's scale, the shader's projection and its inverse, the zoom about a point that stays put, the pan by
// pointer and by keyboard, the limits and the zoom in words.
import { describe, expect, it } from 'vitest';
import {
  cameraScale,
  clampCamera,
  fitCamera,
  gridPoint,
  hsb,
  isFitted,
  magnification,
  onGround,
  panned,
  regionPalette,
  regionSlot,
  steppedCamera,
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

describe('the palette', () => {
  it('is the app’s: a dim slot for the points between regions, then fifteen hues in an even sweep', () => {
    expect(regionPalette).toHaveLength(16);
    close(regionPalette[0] ?? [], [0.35, 0.37, 0.42, 0.3]);
    // Hue 0, saturation 0.55 and brightness 0.95: red, with green and blue at 0.95 × 0.45.
    close(regionPalette[1] ?? [], [0.95, 0.4275, 0.4275, 0.72]);
    // Hue 5/15, a third of the way round: green.
    close(regionPalette[6] ?? [], [0.4275, 0.95, 0.4275, 0.72]);
    // Hue 10/15: blue.
    close(regionPalette[11] ?? [], [0.4275, 0.4275, 0.95, 0.72]);
    for (const colour of regionPalette.slice(1)) expect(colour[3]).toBe(0.72);
  });

  it('builds its colours as the app’s hsb does, in each of its six sectors', () => {
    close(hsb(0.1, 1, 1, 1), [1, 0.6, 0, 1]);
    close(hsb(0.25, 1, 1, 1), [0.5, 1, 0, 1]);
    close(hsb(0.45, 1, 1, 1), [0, 1, 0.7, 1]);
    close(hsb(0.6, 1, 1, 1), [0, 0.4, 1, 1]);
    close(hsb(0.75, 1, 1, 1), [0.5, 0, 1, 1]);
    close(hsb(0.9, 1, 1, 1), [1, 0, 0.6, 1]);
    close(hsb(1.25, 0.5, 0.8, 0.3), hsb(0.25, 0.5, 0.8, 0.3));
  });

  it('gives a region its slot by its id, cycled through the fifteen, and the points between regions slot 0', () => {
    expect(regionSlot(0xffff)).toBe(0);
    expect([0, 1, 13, 14, 15, 29, 30, 139].map(regionSlot)).toEqual([1, 2, 14, 15, 1, 15, 1, 5]);
  });

  it('gives the legend’s swatch the colour a point between regions has on the map', () => {
    expect(onGround(regionPalette[0] ?? [0, 0, 0, 0])).toBe('rgb(37, 41, 48)');
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
