import { describe, expect, it } from 'vitest';
import { formDecode, formEncode } from './form';
import { parseSearch, stringifySearch } from '../router';

describe('formEncode', () => {
  it('writes spaces as + and a plus as %2B, as the server reads them', () => {
    expect(formEncode({ keywords: 'NEAR(khrushchev kennedy, +5)' }).toString()).toBe(
      'keywords=NEAR%28khrushchev+kennedy%2C+%2B5%29',
    );
  });

  it('percent-encodes UTF-8 and keeps the text exactly as typed', () => {
    expect(formEncode({ keywords: '«khrushchev» ½' }).toString()).toBe('keywords=%C2%ABkhrushchev%C2%BB+%C2%BD');
    expect(formEncode({ keywords: '   ' }).toString()).toBe('keywords=+++');
  });

  it('repeats a list, writes the empty list as one empty value, and leaves out what is undefined', () => {
    expect(formEncode({ volumeIds: ['a', 'b'], yearKeys: [], phrase: undefined, limit: 20, includeNotes: false }).toString()).toBe(
      'volumeIds=a&volumeIds=b&yearKeys=&limit=20&includeNotes=false',
    );
    expect(formEncode({ volumeIds: ['', 'a', ''] }).toString()).toBe('volumeIds=a');
  });
});

describe('formDecode and the router', () => {
  it('reads repeated names as lists', () => {
    expect(formDecode('volumeIds=a&keywords=x+y&volumeIds=b')).toEqual(
      new Map([
        ['volumeIds', ['a', 'b']],
        ['keywords', ['x y']],
      ]),
    );
  });

  it('round-trips a search through the URL', () => {
    const search = { keywords: 'cold war', volumeIds: ['frus1961-63v06', 'frus1894Nicaragua'], offset: 20 };
    const query = stringifySearch(search);
    expect(query).toBe('?keywords=cold+war&volumeIds=frus1961-63v06&volumeIds=frus1894Nicaragua&offset=20');
    expect(parseSearch(query.slice(1))).toEqual({ keywords: 'cold war', volumeIds: ['frus1961-63v06', 'frus1894Nicaragua'], offset: '20' });
    expect(stringifySearch({})).toBe('');
  });
});
