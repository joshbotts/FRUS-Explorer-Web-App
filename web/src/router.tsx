// The app's routes (SPEC, Shell and navigation): /search and /doc/{volumeId}/{documentId} in phase 1.
// Query strings have the API's form semantics, so a search's URL reads as its request does.
import { createRootRoute, createRoute, createRouter, redirect } from '@tanstack/react-router';
import { formDecode, formEncode, type FormValue } from './api/form';
import { ReaderScreen } from './reader/ReaderScreen';
import { validateSearch } from './search/searchState';
import { SearchScreen } from './search/SearchScreen';
import { AppShell } from './shell/AppShell';
import { NotFound } from './shell/NotFound';

/** A query string's fields: a name given once is a string, a repeated one a list. */
export function parseSearch(query: string): Record<string, unknown> {
  const fields: Record<string, unknown> = {};
  for (const [name, values] of formDecode(query)) fields[name] = values.length === 1 ? values[0] : values;
  return fields;
}

export function stringifySearch(search: Record<string, unknown>): string {
  const fields: Record<string, FormValue> = {};
  for (const [name, value] of Object.entries(search)) {
    if (value === undefined || value === null) continue;
    fields[name] = Array.isArray(value) ? value.map(String) : (String(value) as FormValue);
  }
  const query = formEncode(fields).toString();
  return query ? `?${query}` : '';
}

const rootRoute = createRootRoute({ component: AppShell, notFoundComponent: NotFound });

const indexRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  beforeLoad: () => {
    throw redirect({ to: '/search' });
  },
});

const searchRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/search',
  validateSearch,
  component: SearchScreen,
});

export interface ReaderSearch {
  /** The rail beside the text: `cite` opens Cite. */
  rail?: 'cite';
}

const documentRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/doc/$volumeId/$documentId',
  // The rail is always returned, so a raw value the router keeps cannot stand in for it.
  validateSearch: (raw: Record<string, unknown>): ReaderSearch => ({ rail: raw.rail === 'cite' ? 'cite' : undefined }),
  component: ReaderScreen,
});

export const routeTree = rootRoute.addChildren([indexRoute, searchRoute, documentRoute]);

export function makeRouter() {
  return createRouter({ routeTree, parseSearch, stringifySearch, scrollRestoration: true });
}

export const router = makeRouter();

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}
