// The app's routes (SPEC, Shell and navigation): /browse, /search and /doc/{volumeId}/{documentId}
// in phase 1, /settings, whose first pane, Tags, came with S14c and whose Data came with S15d,
// /research, which opens All Notes until S19b's Research page, and /lookup, Citation Lookup, from
// S19a, under the path the server serves the app at. Query strings have the API's form semantics, so
// a search's URL reads as its request does.
import { createRootRoute, createRoute, createRouter, redirect } from '@tanstack/react-router';
import { basePath } from './api/base';
import { formDecode, formEncode, type FormValue } from './api/form';
import { CatalogueScreen, type CatalogueSearch, validateCatalogueSearch } from './browse/CatalogueScreen';
import { LookupScreen } from './lookup/LookupScreen';
import { SectionScreen } from './browse/SectionScreen';
import { VolumeScreen } from './browse/VolumeScreen';
import { ReaderScreen } from './reader/ReaderScreen';
import { AllNotesScreen, type NotesSearch, validateNotesSearch } from './research/AllNotesScreen';
import { validateSearch } from './search/searchState';
import { SearchScreen } from './search/SearchScreen';
import { DataSettingsScreen } from './settings/DataSettings';
import { TagsSettingsScreen } from './settings/TagsSettings';
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
  /** The rail beside the text: `cite` opens Cite, and `research` the Research rail. */
  rail?: 'cite' | 'research';
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
    rail: raw.rail === 'cite' || raw.rail === 'research' ? raw.rail : undefined,
    note: typeof raw.note === 'string' && noteId.test(raw.note) ? raw.note : undefined,
  }),
  component: ReaderScreen,
});

// Citation Lookup, which the app opens in a window of its own from Search's Find by Citation. Its form
// is kept for the tab's session rather than in the address, since a block of footnotes outgrows one.
const lookupRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/lookup',
  component: LookupScreen,
});

// Research opens at All Notes until S19b's Research page, as the app's sidebar lists it there.
const researchRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/research',
  beforeLoad: () => {
    throw redirect({ to: '/research/notes' });
  },
});

const researchNotesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/research/notes',
  validateSearch: (raw: Record<string, unknown>): NotesSearch => validateNotesSearch(raw),
  component: AllNotesScreen,
});

// Settings opens at its first pane, Tags.
const settingsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings',
  beforeLoad: () => {
    throw redirect({ to: '/settings/tags' });
  },
});

const settingsTagsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/tags',
  component: TagsSettingsScreen,
});

const settingsDataRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/data',
  component: DataSettingsScreen,
});

export const routeTree = rootRoute.addChildren([
  indexRoute,
  browseRoute,
  volumeRoute,
  sectionRoute,
  searchRoute,
  documentRoute,
  lookupRoute,
  researchRoute,
  researchNotesRoute,
  settingsRoute,
  settingsTagsRoute,
  settingsDataRoute,
]);

export function makeRouter(basepath: string = basePath) {
  return createRouter({ routeTree, basepath, parseSearch, stringifySearch, scrollRestoration: true });
}

export const router = makeRouter();

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}

// What a navigation keeps in its history entry beside the URL. The router's HistoryState is
// @tanstack/history's, which it re-exports.
declare module '@tanstack/history' {
  interface HistoryState {
    /**
     * The page a page link was to, when it opened the volume's page in Browse (the kit's
     * PageLink.volume), which that visit to the page names, as the app keeps FollowedPageLink.
     */
    followedPage?: number;
  }
}
