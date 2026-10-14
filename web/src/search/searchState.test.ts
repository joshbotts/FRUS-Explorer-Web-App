import { describe, expect, it } from 'vitest';
import {
  applySearchChange,
  clampOffset,
  filterFields,
  isPartialEvidence,
  pageCount,
  retainedLimit,
  searchFields,
  validateSearch,
} from './searchState';

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

describe('the facets’ fields', () => {
  it('keeps an empty year list, which matches nothing, apart from none, and drops what is no year', () => {
    expect(validateSearch({ yearKeys: '' }).yearKeys).toEqual([]);
    expect(validateSearch({ yearKeys: [''] }).yearKeys).toEqual([]);
    expect(validateSearch({ yearKeys: ['1960', '1894'] }).yearKeys).toEqual(['1960', '1894']);
    expect(validateSearch({ yearKeys: ['1960', 'x'] }).yearKeys).toEqual(['1960']);
    expect(validateSearch({ yearKeys: 'x' }).yearKeys).toBeUndefined();
    expect(validateSearch({}).yearKeys).toBeUndefined();
    expect(filterFields({ keywords: 'x', yearKeys: [] }).yearKeys).toEqual([]);
  });

  it('keeps a person’s rollup and name, and a subject’s name only beside its subject', () => {
    expect(validateSearch({ personRollupId: '12', personLabel: 'Khrushchev' })).toMatchObject({ personRollupId: '12', personLabel: 'Khrushchev' });
    expect(validateSearch({ personRollupId: 'x', personLabel: 'Khrushchev' })).toMatchObject({ personRollupId: undefined, personLabel: undefined });
    expect(validateSearch({ subjectBucketKey: 'Germany/Berlin', subjectLabel: 'Berlin' }).subjectLabel).toBe('Berlin');
    expect(validateSearch({ subjectLabel: 'Berlin' }).subjectLabel).toBeUndefined();
    expect(validateSearch({ panel: 'facets' }).panel).toBe('facets');
    expect(validateSearch({ panel: 'other' }).panel).toBeUndefined();
    // The app's own two fields never reach the API.
    const fields = searchFields({ keywords: 'x', subjectBucket: '40', subjectLabel: 'Berlin', panel: 'facets' });
    expect(fields.subjectBucket).toBe('40');
    expect('subjectLabel' in fields || 'panel' in fields).toBe(false);
  });

  it('makes a change from the server to the search: each field set, or left out for null, from the first page', () => {
    const state = { keywords: 'treaty', volumeIds: ['frus1961-63v06'], limit: 50, offset: 100, panel: 'facets' as const };
    expect(applySearchChange(state, { volumeIds: null, personRollupId: ['1'], personLabel: ['Khrushchev'] })).toEqual({
      keywords: 'treaty',
      personRollupId: '1',
      personLabel: 'Khrushchev',
      limit: 50,
      panel: 'facets',
    });
    expect(applySearchChange(state, { yearKeys: [''] }).yearKeys).toEqual([]);
    expect(applySearchChange({ keywords: 'x', includeFrontMatter: false }, { documentType: ['editorialNotesOnly'] })).toMatchObject({
      includeFrontMatter: false,
      documentType: 'editorialNotesOnly',
    });
    // A subject's name goes with its subject.
    const subject = { keywords: 'x', subjectBucket: '40', subjectBucketKey: 'Germany/Berlin', subjectLabel: 'Berlin' };
    expect(applySearchChange(subject, { personRollupId: ['1'] }).subjectLabel).toBe('Berlin');
    expect(applySearchChange(subject, { subjectBucket: null, subjectBucketKey: null }).subjectLabel).toBeUndefined();
  });
});

describe('the order', () => {
  it('keeps an order of the date, leaves relevance out as the default, and sends the order with the page', () => {
    expect(validateSearch({ sort: 'dateAscending' }).sort).toBe('dateAscending');
    expect(validateSearch({ sort: 'dateDescending' }).sort).toBe('dateDescending');
    expect(validateSearch({ sort: 'relevance' }).sort).toBeUndefined();
    expect(validateSearch({ sort: 'date' }).sort).toBeUndefined();
    expect(searchFields({ keywords: 'x', sort: 'dateDescending', offset: 40 })).toMatchObject({ sort: 'dateDescending', offset: 40 });
    // What a search matches does not depend on its order, so the facets' fields leave it out.
    expect('sort' in filterFields({ keywords: 'x', sort: 'dateDescending' })).toBe(false);
    // A narrowing keeps the order, as the Mac's window keeps it from search to search.
    expect(applySearchChange({ keywords: 'x', sort: 'dateAscending', offset: 40 }, { personRollupId: ['1'] })).toMatchObject({
      sort: 'dateAscending',
      offset: undefined,
    });
  });

  it('takes what the app keeps of a match of 7,500 or more to be part of it', () => {
    expect(isPartialEvidence(7_499)).toBe(false);
    expect(isPartialEvidence(7_500)).toBe(true);
    expect(isPartialEvidence(195_519)).toBe(true);
  });
});
