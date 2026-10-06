import { describe, expect, it } from 'vitest';
import { readerMessage } from './readerMessages';

const frame = {} as Window;
const other = {} as Window;
const link = { source: 'frus-reader', kind: 'link', detail: { href: 'frusexplorer://doc/d2' } };

describe('readerMessage', () => {
  it('takes a link from the app’s own frame, whose sandboxed origin is "null"', () => {
    expect(readerMessage({ data: link, origin: 'null', source: frame }, frame)).toEqual({ kind: 'link', href: 'frusexplorer://doc/d2' });
  });

  it('ignores another window, another origin, another shape and another kind of link', () => {
    expect(readerMessage({ data: link, origin: 'null', source: other }, frame)).toBeNull();
    expect(readerMessage({ data: link, origin: 'https://example.com', source: frame }, frame)).toBeNull();
    expect(readerMessage({ data: 'frus-reader', origin: 'null', source: frame }, frame)).toBeNull();
    expect(readerMessage({ data: { ...link, source: 'other' }, origin: 'null', source: frame }, frame)).toBeNull();
    expect(
      readerMessage({ data: { ...link, detail: { href: 'javascript:alert(1)' } }, origin: 'null', source: frame }, frame),
    ).toBeNull();
    expect(readerMessage({ data: link, origin: 'null', source: frame }, null)).toBeNull();
  });

  it('passes the reader scripts’ selection messages on', () => {
    expect(
      readerMessage({ data: { source: 'frus-reader', kind: 'selectionChanged', detail: { start: 1 } }, origin: 'null', source: frame }, frame),
    ).toEqual({ kind: 'selectionChanged', detail: { start: 1 } });
  });
});
