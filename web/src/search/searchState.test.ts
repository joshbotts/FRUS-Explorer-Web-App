import { describe, expect, it } from 'vitest';
import { clampOffset, pageCount, retainedLimit, searchFields, validateSearch } from './searchState';

describe('validateSearch', () => {
  it('keeps what fits and drops the rest', () => {
    expect(
      validateSearch({
        keywords: 'treaty',
        documentType: 'editorialNotesOnly',
        dateRangeEarliest: '1962-10-01',
        dateRangeLatest: '1962',
        includeFrontMatter: 'false',
        volumeIds: ['frus1961-63v06', ''],
        limit: '50',
        offset: '120',
        unknown: 'x',
      }),
    ).toEqual({
      keywords: 'treaty',
      documentType: 'editorialNotesOnly',
      dateRangeEarliest: '1962-10-01',
      includeFrontMatter: false,
      volumeIds: ['frus1961-63v06'],
      limit: 50,
      offset: 100,
    });
  });

  it('leaves out the defaults and keeps an empty search box', () => {
    expect(validateSearch({ keywords: '', documentType: 'all', limit: '20', offset: '0', includeFrontMatter: 'true' })).toEqual({
      keywords: '',
    });
    expect(validateSearch({ volumeIds: 'frus1894Nicaragua', limit: '7' })).toEqual({ volumeIds: ['frus1894Nicaragua'] });
  });
});

describe('paging', () => {
  it('keeps offsets on a page boundary within the 7,500 results a search keeps', () => {
    expect(clampOffset(45, 20)).toBe(40);
    expect(clampOffset(-5, 20)).toBe(0);
    expect(clampOffset(Number.NaN, 20)).toBe(0);
    expect(clampOffset(10_000, 100)).toBe(retainedLimit - 100);
  });

  it('counts pages within the retained results', () => {
    expect(pageCount(0, 20)).toBe(1);
    expect(pageCount(41, 20)).toBe(3);
    expect(pageCount(100_000, 100)).toBe(75);
  });
});

describe('searchFields', () => {
  it('gives the API every field, with the page and without an empty volume list', () => {
    expect(searchFields({ keywords: 'x', volumeIds: [] })).toEqual({
      keywords: 'x',
      documentType: undefined,
      dateRangeEarliest: undefined,
      dateRangeLatest: undefined,
      includeFrontMatter: undefined,
      volumeIds: undefined,
      limit: 20,
      offset: 0,
    });
  });
});
