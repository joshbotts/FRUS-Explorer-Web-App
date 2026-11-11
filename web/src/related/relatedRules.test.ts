// Related Documents' rules in the browser (PLAN's S23d): a row's title, the empty list's sentence, the
// overflow line and a tuning as the app stores one.
import { describe, expect, it } from 'vitest';
import type { RelatedAxis } from '../api/related';
import { decodedWeights, emptyDetail, encodedWeights, overflowLine, rowTitle, weightText } from './relatedRules';

const axes: RelatedAxis[] = [
  { id: 'archivalProvenance', name: 'Archival provenance', weight: 1, defaultWeight: 1, available: true },
  { id: 'crossReference', name: 'Cross-references', weight: 1, defaultWeight: 1, available: true },
  { id: 'dateProximity', name: 'Close in date', weight: 0.5, defaultWeight: 0.5, available: true },
  { id: 'subseries', name: 'Corpus proximity', weight: 0.3, defaultWeight: 0.3, available: true },
  { id: 'sharedPersons', name: 'Shared people', weight: 0.7, defaultWeight: 0.7, available: true },
];

describe('Related Documents’ rules', () => {
  it('titles a row by its head, or its id for none, as the app’s row does', () => {
    expect(rowTitle({ header: 'Telegram From the Embassy', documentId: 'd4' })).toBe('Telegram From the Embassy');
    expect(rowTitle({ header: '', documentId: 'd4' })).toBe('d4');
  });

  it('says what an empty list means for its scope', () => {
    expect(emptyDetail('all')).toMatch(/^No indexed documents share/);
    expect(emptyDetail('volume')).toMatch(/switch to All volumes/);
    expect(emptyDetail('subseries')).toMatch(/switch to All volumes/);
  });

  it('counts what scored past the rows shown, and says nothing when the list holds it all', () => {
    expect(overflowLine(42, 30)).toBe('12 more related — raise a weight or narrow the scope to refine.');
    expect(overflowLine(30, 30)).toBeUndefined();
  });

  it('writes a tuning as its departures from the defaults, sorted by the axis, and the defaults as nothing', () => {
    const at = (changes: Record<string, number>) => Object.fromEntries(axes.map((axis) => [axis.id, changes[axis.id] ?? axis.weight]));
    expect(encodedWeights(at({}), axes)).toBe('');
    // A whole number is written as Swift writes a Double, with `.0`, as the app stores it.
    expect(encodedWeights(at({ subseries: 0.8, dateProximity: 0 }), axes)).toBe('dateProximity:0.0,subseries:0.8');
    // An axis the tuning does not name keeps the weight the list was ranked with.
    expect(encodedWeights({ sharedPersons: 0.2 }, axes)).toBe('sharedPersons:0.2');
  });

  it('reads a tuning of the stored form back, each axis it leaves out at its default', () => {
    expect(decodedWeights('', axes)).toEqual({ archivalProvenance: 1, crossReference: 1, dateProximity: 0.5, subseries: 0.3, sharedPersons: 0.7 });
    expect(decodedWeights('dateProximity:0.0,subseries:0.8,unknown:1,sharedPersons:x', axes)).toEqual({
      archivalProvenance: 1,
      crossReference: 1,
      dateProximity: 0,
      subseries: 0.8,
      sharedPersons: 0.7,
    });
  });

  it('shows a weight to one decimal place, as the app’s row does', () => {
    expect(weightText(0.5)).toBe('0.5');
    expect(weightText(1)).toBe('1.0');
    expect(weightText(0)).toBe('0.0');
  });
});
