import { describe, expect, it } from 'vitest';
import { matchesFilter, validateCatalogueSearch } from './CatalogueScreen';

const v06 = { volumeId: 'frus1961-63v06', title: 'Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges' };

describe('the catalogue', () => {
  it('matches a title or a volume id, ignoring case and the ends of the text', () => {
    expect(matchesFilter(v06, 'kennedy-khrushchev')).toBe(true);
    expect(matchesFilter(v06, ' FRUS1961-63V06 ')).toBe(true);
    expect(matchesFilter(v06, '')).toBe(true);
    expect(matchesFilter(v06, 'Nicaragua')).toBe(false);
  });

  it('returns every field of its search, dropping what does not fit', () => {
    expect(validateCatalogueSearch({ q: 'Kennedy', subseries: '1961-63', indexed: 'true', other: 'x' })).toEqual({
      q: 'Kennedy',
      subseries: '1961-63',
      indexed: true,
    });
    const empty = validateCatalogueSearch({ q: '', subseries: '', indexed: 'yes' });
    expect(Object.keys(empty).sort()).toEqual(['indexed', 'q', 'subseries']);
    expect(Object.values(empty)).toEqual([undefined, undefined, undefined]);
  });
});
