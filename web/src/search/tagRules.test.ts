import { describe, expect, it } from 'vitest';
import { caseFolded, rowChipLimit, tagChips, tagFilterLabel } from './tagRules';

const berlin = { id: '5E17D000-0000-4000-8000-00000000000A', name: 'Berlin' };
const cuba = { id: '5e17d000-0000-4000-8000-00000000000b', name: 'Cuba' };
const laos = { id: 'LAOS', name: 'Laos' };

describe('tagChips', () => {
  it('gives a chip for each id the user’s tags name, in the row’s order, each once, whatever the case of an id', () => {
    expect(tagChips([laos.id, caseFolded(cuba.id), 'ABSENT', berlin.id, 'laos'], [berlin, cuba, laos])).toEqual([laos, cuba, berlin]);
    expect(tagChips(['ABSENT'], [berlin])).toEqual([]);
    expect(rowChipLimit).toBe(3);
  });

  it('folds ASCII letters alone, as the kit reads an id', () => {
    expect(caseFolded('5e17d-éa')).toBe('5E17D-éA');
  });
});

describe('tagFilterLabel', () => {
  it('names one tag, says 1 tag while the list does not name it, and counts several, as the Mac’s token does', () => {
    expect(tagFilterLabel([caseFolded(cuba.id)], [berlin, cuba])).toBe('Cuba');
    expect(tagFilterLabel([berlin.id], undefined)).toBe('1 tag');
    expect(tagFilterLabel([berlin.id, cuba.id], [berlin, cuba])).toBe('2 tags');
    expect(tagFilterLabel(Array.from({ length: 1200 }, (_, n) => String(n)), [])).toBe('1,200 tags');
  });
});
