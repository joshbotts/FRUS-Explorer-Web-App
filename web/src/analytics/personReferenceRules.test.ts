import { describe, expect, it } from 'vitest';
import type { NetworkAnswer } from '../api/personAnalytics';
import { chartPalette } from './analyticsRules';
import {
  edgeStyle,
  heatOpacity,
  networkLayout,
  nodeRadius,
  personColor,
  runPhysics,
  validateCrossReferenceSearch,
  validatePeopleSearch,
} from './personReferenceRules';

function network(partners: { id: number; shared: number }[], edges: [number, number, number][] = []): NetworkAnswer {
  const focus = { rollupId: 1, name: 'Kennedy, John F.', label: 'Kennedy, John F.', sharedWithFocus: 0, isFocus: true };
  return {
    focus,
    state: partners.length > 0 ? 'graph' : 'empty',
    nodes: [focus, ...partners.map((p) => ({ rollupId: p.id, name: `P${p.id}`, label: `P${p.id}`, sharedWithFocus: p.shared, isFocus: false }))],
    edges: edges.map(([a, b, shared]) => ({ a, b, sharedDocuments: shared, isSpoke: a === 1 || b === 1 })),
    totalPartnerCount: partners.length,
    capApplied: false,
    footer: '',
  };
}

describe('the addresses', () => {
  it('keeps the first five people compared, once each, and drops what does not fit', () => {
    expect(validatePeopleSearch({ people: ['3', '3', 'x', '9', '4', '5', '6', '7', '8'], mode: 'network', decade: 'on', values: 'percentOfDocuments', focus: '12', from: '1960' }))
      .toEqual(expect.objectContaining({ people: [3, 9, 4, 5, 6], mode: 'network', decade: 'on', values: 'percentOfDocuments', focus: 12, from: 1960 }));
    expect(validatePeopleSearch({ people: 'abc', mode: 'grid', values: 'raw', from: '60' })).toEqual(
      expect.objectContaining({ people: undefined, mode: undefined, values: undefined, from: undefined }),
    );
    expect(validateCrossReferenceSearch({ outDegree: 'on', volumes: ['frus1961-63v06', ''], to: '1963' })).toEqual(
      expect.objectContaining({ outDegree: 'on', volumes: ['frus1961-63v06'], to: 1963 }),
    );
  });
});

describe('the comparison and the heat matrix', () => {
  it('colours each person by their place in the comparison, as the chips do', () => {
    const people = [{ rollupId: 9 }, { rollupId: 4 }];
    expect(personColor(people, 9)).toBe(chartPalette[0]);
    expect(personColor(people, 4)).toBe(chartPalette[1]);
  });

  it('shades a cell from 15% to 95% of the accent by its share of the largest count, and none for no references', () => {
    expect(heatOpacity(0, 10)).toBe(0);
    expect(heatOpacity(10, 10)).toBeCloseTo(0.95);
    expect(heatOpacity(5, 10)).toBeCloseTo(0.55);
    expect(heatOpacity(3, 0)).toBe(0);
  });
});

describe('the co-mention network', () => {
  it('pins the focus at the centre and keeps the partners 48 points inside the canvas', () => {
    const answer = network(
      [{ id: 2, shared: 9 }, { id: 3, shared: 4 }, { id: 4, shared: 1 }, { id: 5, shared: 6 }],
      [[1, 2, 9], [1, 3, 4], [1, 4, 1], [1, 5, 6], [2, 3, 2]],
    );
    const size = { width: 700, height: 520 };
    const places = networkLayout(answer, size, false);
    expect(places.get(1)).toEqual({ x: 350, y: 260 });
    for (const id of [2, 3, 4, 5]) {
      const place = places.get(id);
      expect(place && place.x >= 48 && place.x <= 652 && place.y >= 48 && place.y <= 472).toBe(true);
    }
    // The same layout each time, as the app's physics is deterministic.
    expect(networkLayout(answer, size, false)).toEqual(places);
    // Reduce Motion settles at once, in one run of three hundred iterations.
    expect(networkLayout(answer, size, true)).toEqual(
      runPhysics([1, 2, 3, 4, 5], 1, answer.edges, new Map([
        [1, { x: 350, y: 260 }],
        ...[2, 3, 4, 5].map((id, i) => [id, { x: 350 + 182 * Math.cos((2 * Math.PI * i) / 4), y: 260 + 182 * Math.sin((2 * Math.PI * i) / 4) }] as const),
      ]), size, 300),
    );
  });

  it('sizes the discs and the edges as the app draws them', () => {
    const answer = network([{ id: 2, shared: 10 }, { id: 3, shared: 5 }], [[1, 2, 10], [2, 3, 5]]);
    expect(nodeRadius(answer, 1)).toBe(26);
    expect(nodeRadius(answer, 2)).toBe(22);
    expect(nodeRadius(answer, 3)).toBe(17);
    expect(nodeRadius(answer, 3, 3)).toBe(20);
    expect(edgeStyle(answer, 10)).toEqual({ width: 4, opacity: 0.7 });
    expect(edgeStyle(answer, 5)).toEqual({ width: 2.25, opacity: 0.45 });
  });
});
