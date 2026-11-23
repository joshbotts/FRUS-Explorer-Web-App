// The app's routes (SPEC, Shell and navigation): /browse, /search and /doc/{volumeId}/{documentId}
// in phase 1, /settings, whose first pane, Tags, came with S14c and whose Data came with S15d,
// /research, which opened All Notes until S19b's Research page, /lookup, Citation Lookup, from
// S19a, Browse's Working Corpora and My Scopes from S17e, and from S17f Project Home, the History
// screen and Settings' Projects, Research Sessions and Reading, and from S18d the Collections tab and a
// collection's editor, under the path the server serves the app at. Query strings have the API's form semantics, so
// a search's URL reads as its request does. Its imports, its routes and its tree are grouped by area, under
// a line each, as copy.ts's blocks are (PLAN's S20a): a new page's lines go beside their area's kin, never at
// the end.
import { createRootRoute, createRoute, createRouter, redirect } from '@tanstack/react-router';
import { basePath } from './api/base';
import { formDecode, formEncode, type FormValue } from './api/form';
// ─── The shell ──────────────────────────────────────────────────────────────
import { AppShell } from './shell/AppShell';
import { NotFound } from './shell/NotFound';
// ─── Browse and search ──────────────────────────────────────────────────────
import {
  type AnnotationSearch,
  AnnotationDrillScreen,
  AnnotationEraScreen,
  AnnotationLayerScreen,
  AnnotationsAxisScreen,
  validateAnnotationSearch,
} from './browse/AnnotationsScreen';
import { CatalogueScreen, type CatalogueSearch, validateCatalogueSearch } from './browse/CatalogueScreen';
import { CorporaScreen, CorpusScreen } from './browse/CorporaScreen';
import { PeopleScreen } from './people/PeopleScreen';
import { ScopeEditorScreen, ScopeScreen, ScopesScreen } from './browse/ScopesScreen';
import { SectionScreen } from './browse/SectionScreen';
import { VolumeScreen } from './browse/VolumeScreen';
import { validateSearch } from './search/searchState';
import { SearchScreen } from './search/SearchScreen';
// ─── The reader ─────────────────────────────────────────────────────────────
import { ReaderScreen } from './reader/ReaderScreen';
import { GraphScreen, type GraphSearch } from './graph/GraphScreen';
import { SourcesScreen } from './sources/SourcesScreen';
import { NeighboursScreen, type NeighboursSearch } from './sources/NeighboursScreen';
import { CollectionScreen, type CollectionSearch, collectionLists } from './sources/CollectionScreen';
import { RelatedScreen, type RelatedSearch } from './related/RelatedScreen';
// ─── Research ───────────────────────────────────────────────────────────────
import { AllNotesScreen, type NotesSearch, validateNotesSearch } from './research/AllNotesScreen';
import { HistoryScreen } from './research/HistoryScreen';
import { ProjectHomeScreen } from './research/ProjectHomeScreen';
import { ResearchScreen, type ResearchSearch, validateResearchSearch } from './research/ResearchScreen';
// ─── Collections ────────────────────────────────────────────────────────────
import { CollectionEditorScreen } from './collections/CollectionEditorScreen';
import { CollectionsScreen } from './collections/CollectionsScreen';
// ─── Tools ──────────────────────────────────────────────────────────────────
import { CloudScreen } from './cloud/CloudScreen';
import { type CloudSearch, validateCloudSearch } from './cloud/cloudRules';
import { type ChronologySearch, type CorpusSearch, validateChronologySearch, validateCorpusSearch } from './analytics/analyticsRules';
import { AboutSeriesScreen } from './analytics/AboutSeriesScreen';
import { ArchivalAnalyticsScreen } from './analytics/ArchivalAnalyticsScreen';
import { type ArchivalSearch, type SeriesSearch, validateArchivalSearch, validateSeriesSearch } from './analytics/archivalRules';
import { CrossReferenceAnalyticsScreen } from './analytics/CrossReferenceAnalyticsScreen';
import { PersonAnalyticsScreen } from './analytics/PersonAnalyticsScreen';
import { type CrossReferenceSearch, type PeopleSearch, validateCrossReferenceSearch, validatePeopleSearch } from './analytics/personReferenceRules';
import { ChronologyScreen } from './analytics/ChronologyScreen';
import { CorpusAnalyticsScreen } from './analytics/CorpusAnalyticsScreen';
import { LookupScreen } from './lookup/LookupScreen';
// ─── Settings ───────────────────────────────────────────────────────────────
import { DataSettingsScreen } from './settings/DataSettings';
import { KeysSettingsScreen } from './settings/KeysSettings';
import { ProjectsSettingsScreen } from './settings/ProjectsSettings';
import { ReadingSettingsScreen } from './settings/ReadingSettings';
import { SessionLogScreen, SessionsSettingsScreen } from './settings/SessionsSettings';
import { TagsSettingsScreen } from './settings/TagsSettings';
import { WordCloudSettingsScreen } from './settings/WordCloudSettings';
// ─── Admin ──────────────────────────────────────────────────────────────────
import { AdminKeysScreen } from './admin/KeysPane';
import { BackupsScreen } from './admin/BackupsPane';
import { CorrectionsScreen } from './admin/CorrectionsPane';
import { JobsScreen } from './admin/JobsPane';
import { LibraryScreen } from './admin/LibraryPane';
import { StatusScreen } from './admin/StatusPane';
import { UsersScreen } from './admin/UsersPane';

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

// ─── The shell ──────────────────────────────────────────────────────────────
const rootRoute = createRootRoute({ component: AppShell, notFoundComponent: NotFound });

const indexRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  // Browse comes first, as it is the app's first tab.
  beforeLoad: () => {
    throw redirect({ to: '/browse' });
  },
});

// ─── Browse and search ──────────────────────────────────────────────────────
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

// Browse's Editors’ Annotations (FRUS-Explorer#1861): the axis, a layer's page, its lists, and a cell's.
const annotationsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/annotations',
  component: AnnotationsAxisScreen,
});

const annotationLayerRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/annotations/$layer',
  validateSearch: (raw: Record<string, unknown>): AnnotationSearch => validateAnnotationSearch(raw),
  component: AnnotationLayerScreen,
});

const annotationDrillRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/annotations/$layer/$drill',
  validateSearch: (raw: Record<string, unknown>): AnnotationSearch => validateAnnotationSearch(raw),
  component: AnnotationDrillScreen,
});

const annotationEraRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/browse/annotations/$layer/era/$era',
  component: AnnotationEraScreen,
});

// The People screen (S21g), the app's cross-volume index of people, one of Browse's axes.
const peopleRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/people',
  component: PeopleScreen,
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

// ─── The reader ─────────────────────────────────────────────────────────────
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

// Related Documents (S23d), which the reader's Related opens, with its scope and its tuning in the address.
const relatedRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/related/$volumeId/$documentId',
  validateSearch: (raw: Record<string, unknown>): RelatedSearch => ({
    scope: raw.scope === 'volume' || raw.scope === 'subseries' || raw.scope === 'all' ? raw.scope : undefined,
    weights: typeof raw.weights === 'string' ? raw.weights : undefined,
  }),
  component: RelatedScreen,
});

/** A list of keys from the address: one value, several, or none. */
function keyList(raw: unknown, prefix: RegExp): string[] | undefined {
  const values = (Array.isArray(raw) ? raw : [raw]).filter((value): value is string => typeof value === 'string' && prefix.test(value));
  return values.length > 0 ? values : undefined;
}

/** A finite number from the address, or from a navigation, which gives one as it is; or none. */
function finite(raw: unknown): number | undefined {
  const value = typeof raw === 'number' ? raw : typeof raw === 'string' && raw.trim() !== '' ? Number(raw) : Number.NaN;
  return Number.isFinite(value) ? value : undefined;
}

// Source Explorer (S22d), which the reader's Sources opens.
const sourcesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/sources/$volumeId/$documentId',
  component: SourcesScreen,
});

/** A string from the address, trimmed, or none. */
function text(raw: unknown): string | undefined {
  const value = typeof raw === 'number' ? String(raw) : typeof raw === 'string' ? raw.trim() : '';
  return value === '' ? undefined : value;
}

// An archival source's neighbours (S22d): a document's, a Sources row's, a collection's or a class's, with the scope in the address.
const neighboursRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/archival-neighbors',
  validateSearch: (raw: Record<string, unknown>): NeighboursSearch => {
    const year = finite(raw.year);
    const names = (Array.isArray(raw.aliasName) ? raw.aliasName : [raw.aliasName]).map(text).filter((name): name is string => !!name);
    return {
      volumeId: text(raw.volumeId),
      documentId: text(raw.documentId),
      year: year !== undefined && Number.isInteger(year) ? year : undefined,
      collection: text(raw.collection),
      lotFile: text(raw.lotFile),
      recordGroup: text(raw.recordGroup),
      series: text(raw.series),
      repository: text(raw.repository),
      decimalClass: text(raw.decimalClass),
      jobNumber: text(raw.jobNumber),
      aliasLot: text(raw.aliasLot),
      aliasName: names.length > 0 ? names : undefined,
      aliasCollection: text(raw.aliasCollection),
      anchor: text(raw.anchor),
      scope: raw.scope === 'volume' || raw.scope === 'subseries' || raw.scope === 'all' ? raw.scope : undefined,
    };
  },
  component: NeighboursScreen,
});

// An archival collection's record (S22d), by its id in the collection authority.
const collectionRecordRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/archival-collection',
  validateSearch: (raw: Record<string, unknown>): CollectionSearch => {
    const all = collectionLists.filter((list) => (Array.isArray(raw.all) ? raw.all : [raw.all]).includes(list));
    return { id: text(raw.id) ?? '', all: all.length > 0 ? all : undefined };
  },
  component: CollectionScreen,
});

// The cross-reference graph (S23e), which the reader's Graph opens, with its degree, layout and expanded clusters in the address.
const graphRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/graph/$volumeId/$documentId',
  validateSearch: (raw: Record<string, unknown>): GraphSearch => {
    const hops = finite(raw.degree);
    const degree = hops === 1 || hops === 2 || hops === 3 ? hops : undefined;
    const from = finite(raw.from);
    const to = finite(raw.to);
    const windowed = from !== undefined && to !== undefined && from < to;
    return {
      degree,
      layout: raw.layout === 'timeline' || raw.layout === 'network' ? raw.layout : undefined,
      expand: keyList(raw.expand, /^cluster\/(inbound|outbound)\/./),
      dates: keyList(raw.dates, /^datecluster\/./),
      from: windowed ? from : undefined,
      to: windowed ? to : undefined,
    };
  },
  component: GraphScreen,
});

// ─── Research ───────────────────────────────────────────────────────────────
// The Research page (S19b), the app's Research tab, with the category it shows in the address.
const researchRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/research',
  validateSearch: (raw: Record<string, unknown>): ResearchSearch => validateResearchSearch(raw),
  component: ResearchScreen,
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

// ─── Collections ────────────────────────────────────────────────────────────
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

// ─── Tools ──────────────────────────────────────────────────────────────────
// The Word Cloud (S24i), which the app opens from its Analytics menu on the corpus and from the reader's rail on a
// document, with its scope and lens in the address.
const cloudRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/cloud',
  validateSearch: (raw: Record<string, unknown>): CloudSearch => validateCloudSearch(raw),
  component: CloudScreen,
});

// Archival Analytics (S24h), which the app opens from its Analytics menu, and About the Series, its Research Guide's four
// dashboards, each with its state in the address.
const archivalAnalyticsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/analytics/archives',
  validateSearch: (raw: Record<string, unknown>): ArchivalSearch => validateArchivalSearch(raw),
  component: ArchivalAnalyticsScreen,
});

const aboutSeriesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/about',
  validateSearch: (raw: Record<string, unknown>): SeriesSearch => validateSeriesSearch(raw),
  component: AboutSeriesScreen,
});

// Person and Cross-Reference Analytics (S24g), which the app opens from its Analytics menu, each with its state in the address.
const personAnalyticsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/analytics/people',
  validateSearch: (raw: Record<string, unknown>): PeopleSearch => validatePeopleSearch(raw),
  component: PersonAnalyticsScreen,
});

const crossReferenceAnalyticsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/analytics/cross-references',
  validateSearch: (raw: Record<string, unknown>): CrossReferenceSearch => validateCrossReferenceSearch(raw),
  component: CrossReferenceAnalyticsScreen,
});

// Corpus Analytics and Chronology (S24f), which the app opens from its Analytics menu, each with its state in the address.
const corpusAnalyticsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/analytics/corpus',
  validateSearch: (raw: Record<string, unknown>): CorpusSearch => validateCorpusSearch(raw),
  component: CorpusAnalyticsScreen,
});

const chronologyRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/chronology',
  validateSearch: (raw: Record<string, unknown>): ChronologySearch => validateChronologySearch(raw),
  component: ChronologyScreen,
});

// Citation Lookup, which the app opens in a window of its own from Search's Find by Citation. Its form
// is kept for the tab's session rather than in the address, since a block of footnotes outgrows one.
const lookupRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/lookup',
  component: LookupScreen,
});

// ─── Settings ───────────────────────────────────────────────────────────────
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

// From S20c: Keys, the user's stored NARA Catalog and Zotero keys.
const settingsKeysRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/keys',
  component: KeysSettingsScreen,
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

// From S24i: Word Cloud, the reader's criteria, hidden words and appearance.
const settingsWordCloudRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/settings/word-cloud',
  component: WordCloudSettingsScreen,
});

// ─── Admin ──────────────────────────────────────────────────────────────────
// From S20d: administration, for an admin, opening at Status, its first pane.
const adminRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin',
  beforeLoad: () => {
    throw redirect({ to: '/admin/status' });
  },
});

const adminStatusRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin/status',
  component: StatusScreen,
});

const adminJobsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin/jobs',
  component: JobsScreen,
});

// From S21c: the library, a Standalone server's volumes and their downloads.
const adminLibraryRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin/library',
  component: LibraryScreen,
});

// From S21g: the log of the corrections curators made.
const adminCorrectionsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin/corrections',
  component: CorrectionsScreen,
});

const adminUsersRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin/users',
  component: UsersScreen,
});

const adminBackupsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin/backups',
  component: BackupsScreen,
});

const adminKeysRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin/keys',
  component: AdminKeysScreen,
});

export const routeTree = rootRoute.addChildren([
  // ─── The shell ────────────────────────────────────────────────────────────
  indexRoute,
  // ─── Browse and search ────────────────────────────────────────────────────
  browseRoute,
  corporaRoute,
  corpusRoute,
  scopesRoute,
  scopeRoute,
  scopeEditorRoute,
  annotationsRoute,
  annotationLayerRoute,
  annotationDrillRoute,
  annotationEraRoute,
  peopleRoute,
  volumeRoute,
  sectionRoute,
  searchRoute,
  // ─── The reader ───────────────────────────────────────────────────────────
  documentRoute,
  sourcesRoute,
  neighboursRoute,
  collectionRecordRoute,
  graphRoute,
  relatedRoute,
  // ─── Research ─────────────────────────────────────────────────────────────
  researchRoute,
  researchNotesRoute,
  researchHistoryRoute,
  projectHomeRoute,
  // ─── Collections ──────────────────────────────────────────────────────────
  collectionsRoute,
  collectionRoute,
  // ─── Tools ────────────────────────────────────────────────────────────────
  cloudRoute,
  archivalAnalyticsRoute,
  aboutSeriesRoute,
  personAnalyticsRoute,
  crossReferenceAnalyticsRoute,
  corpusAnalyticsRoute,
  chronologyRoute,
  lookupRoute,
  // ─── Settings ─────────────────────────────────────────────────────────────
  settingsRoute,
  settingsTagsRoute,
  settingsDataRoute,
  settingsKeysRoute,
  settingsProjectsRoute,
  settingsSessionsRoute,
  settingsSessionLogRoute,
  settingsReadingRoute,
  settingsWordCloudRoute,
  // ─── Admin ────────────────────────────────────────────────────────────────
  adminRoute,
  adminStatusRoute,
  adminJobsRoute,
  adminLibraryRoute,
  adminCorrectionsRoute,
  adminUsersRoute,
  adminBackupsRoute,
  adminKeysRoute,
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
