// The app's routes (SPEC, Shell and navigation): /browse, /search and /doc/{volumeId}/{documentId}
// in phase 1, /settings, whose first pane, Tags, came with S14c and whose Data came with S15d,
// /research, which opens All Notes until S19b's Research page, /lookup, Citation Lookup, from
// S19a, Browse's Working Corpora and My Scopes from S17e, and from S17f Project Home, the History
// screen and Settings' Projects, Research Sessions and Reading, and from S18d the Collections tab and a
// collection's editor, under the path the server serves the app at. Query strings have the API's form semantics, so
// a search's URL reads as its request does.
import { createRootRoute, createRoute, createRouter, redirect } from '@tanstack/react-router';
import { basePath } from './api/base';
import { formDecode, formEncode, type FormValue } from './api/form';
import { CatalogueScreen, type CatalogueSearch, validateCatalogueSearch } from './browse/CatalogueScreen';
import { CorporaScreen, CorpusScreen } from './browse/CorporaScreen';
import { CollectionEditorScreen } from './collections/CollectionEditorScreen';
import { CollectionsScreen } from './collections/CollectionsScreen';
import { ScopeEditorScreen, ScopeScreen, ScopesScreen } from './browse/ScopesScreen';
import { LookupScreen } from './lookup/LookupScreen';
import { SectionScreen } from './browse/SectionScreen';
import { VolumeScreen } from './browse/VolumeScreen';
import { ReaderScreen } from './reader/ReaderScreen';
import { AllNotesScreen, type NotesSearch, validateNotesSearch } from './research/AllNotesScreen';
import { HistoryScreen } from './research/HistoryScreen';
import { ProjectHomeScreen } from './research/ProjectHomeScreen';
import { validateSearch } from './search/searchState';
import { SearchScreen } from './search/SearchScreen';
import { DataSettingsScreen } from './settings/DataSettings';
import { ProjectsSettingsScreen } from './settings/ProjectsSettings';
import { ReadingSettingsScreen } from './settings/ReadingSettings';
import { SessionLogScreen, SessionsSettingsScreen } from './settings/SessionsSettings';
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

// Browse's Working Corpora and My Scopes (S17e), whose fixed paths a volume's id never is.
const corporaRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/corpora',
  component: CorporaScreen,
});

const corpusRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/corpora/$corpusId',
  component: CorpusScreen,
});

const scopesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/scopes',
  component: ScopesScreen,
});

const scopeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/scopes/$scopeId',
  component: ScopeScreen,
});

const scopeEditorRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/scopes/$scopeId/edit',
  component: ScopeEditorScreen,
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

// The History screen (S17f), which the app's Research tab pushes.
const researchHistoryRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/research/history',
  component: HistoryScreen,
});

// Project Home (S17f), which the app opens in a window of its own.
const projectHomeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/projects/$projectId',
  component: ProjectHomeScreen,
});

// The Collections tab (S18d), between Research and Settings, as the app's tabs order them, and a
// collection's editor, which the tab pushes.
const collectionsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/collections',
  component: CollectionsScreen,
});

const collectionRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/collections/$collectionId',
  component: CollectionEditorScreen,
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

// From S17f: Projects, Research Sessions with its Session Log, and Reading.
const settingsProjectsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/projects',
  component: ProjectsSettingsScreen,
});

const settingsSessionsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/sessions',
  component: SessionsSettingsScreen,
});

const settingsSessionLogRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/sessions/log',
  component: SessionLogScreen,
});

const settingsReadingRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/reading',
  component: ReadingSettingsScreen,
});

export const routeTree = rootRoute.addChildren([
  indexRoute,
  browseRoute,
  corporaRoute,
  corpusRoute,
  scopesRoute,
  scopeRoute,
  scopeEditorRoute,
  volumeRoute,
  sectionRoute,
  searchRoute,
  documentRoute,
  lookupRoute,
  researchRoute,
  researchNotesRoute,
  researchHistoryRoute,
  projectHomeRoute,
  collectionsRoute,
  collectionRoute,
  settingsRoute,
  settingsTagsRoute,
  settingsDataRoute,
  settingsProjectsRoute,
  settingsSessionsRoute,
  settingsSessionLogRoute,
  settingsReadingRoute,
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
