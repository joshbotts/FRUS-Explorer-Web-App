// The path the server serves the app under (SPEC, FRUS_PUBLIC_URL): `/`, or one such as
// `/frus-explorer/`. The build names its files by relative paths, and the server writes the path
// into the page's <base>, so one build serves at the root or under a path; the router, the API's
// requests and the reader's frame take it from there.

/** The path of the page's `<base href>`, ending in a slash, or `/` when the page has none, as in unit tests. */
export function basePathOf(page: Document): string {
  if (!page.querySelector('base[href]')) return '/';
  return new URL('./', page.baseURI).pathname;
}

export const basePath = typeof document === 'undefined' ? '/' : basePathOf(document);

/** `path`, a path at the server's root such as `/api/v1/volumes`, under the base path. */
export function servedPath(path: string, base: string = basePath): string {
  return base + path.replace(/^\/+/, '');
}
