// The app's routes (SPEC, Shell and navigation): /browse, /search and /doc/{volumeId}/{documentId}
// in phase 1. Query strings have the API's form semantics, so a search's URL reads as its request does.
import { createRootRoute, createRoute, createRouter, redirect } from '@tanstack/react-router';
import { formDecode, formEncode, type FormValue } from './api/form';
import { CatalogueScreen, type CatalogueSearch, validateCatalogueSearch } from './browse/CatalogueScreen';
import { SectionScreen } from './browse/SectionScreen';
import { VolumeScreen } from './browse/VolumeScreen';
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
  // Browse comes first, as it is the app's first tab.
  beforeLoad: () => {
    throw redirect({ to: '/browse' });
  },
});

const browseRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse',
  validateSearch: (raw: Record<string, unknown>): CatalogueSearch => validateCatalogueSearch(raw),
  component: CatalogueScreen,
});

const volumeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/$volumeId',
  component: VolumeScreen,
});

const sectionRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/$volumeId/$sectionId',
  component: SectionScreen,
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
  /** The id of a note's entry in the page's list of footnotes, which the frame scrolls to. */
  note?: string;
}

/** An id as the kit's serializer writes a note's entry: `fnote-` and the note's key. */
const noteId = /^fnote-[A-Za-z0-9_.:-]+$/;

const documentRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/doc/$volumeId/$documentId',
  // Every field is always returned, so a raw value the router keeps cannot stand in for it.
  validateSearch: (raw: Record<string, unknown>): ReaderSearch => ({
    rail: raw.rail === 'cite' ? 'cite' : undefined,
    note: typeof raw.note === 'string' && noteId.test(raw.note) ? raw.note : undefined,
  }),
  component: ReaderScreen,
});

export const routeTree = rootRoute.addChildren([indexRoute, browseRoute, volumeRoute, sectionRoute, searchRoute, documentRoute]);

export function makeRouter() {
  return createRouter({ routeTree, parseSearch, stringifySearch, scrollRestoration: true });
}

export const router = makeRouter();

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}
