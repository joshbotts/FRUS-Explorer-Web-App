import { describe, expect, it } from 'vitest';
import { basePath, basePathOf, servedPath } from './base';

/** A page with a `<base>` at `href`, or none. A page made here has no address, so `href` is absolute. */
function page(href?: string): Document {
  const made = document.implementation.createHTMLDocument('FRUS Explorer Light');
  if (href !== undefined) {
    const base = made.createElement('base');
    base.setAttribute('href', href);
    made.head.append(base);
  }
  return made;
}

describe('the base path', () => {
  it('is the path of the <base> the server writes, and the root without one', () => {
    expect(basePathOf(page())).toBe('/');
    expect(basePathOf(page('http://localhost:8080/'))).toBe('/');
    expect(basePathOf(page('https://example.org/frus-explorer/'))).toBe('/frus-explorer/');
    expect(basePathOf(page('https://example.org/a/b/'))).toBe('/a/b/');
    // The unit tests' own page has none.
    expect(basePath).toBe('/');
  });

  it('puts a path at the server’s root under it', () => {
    expect(servedPath('/api/v1/volumes')).toBe('/api/v1/volumes');
    expect(servedPath('/readyz', '/')).toBe('/readyz');
    expect(servedPath('/api/v1/volumes/frus1961-63v06/documents/d1/html', '/frus-explorer/')).toBe(
      '/frus-explorer/api/v1/volumes/frus1961-63v06/documents/d1/html',
    );
    expect(servedPath('/readyz', '/frus-explorer/')).toBe('/frus-explorer/readyz');
  });
});
