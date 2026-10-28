// Projects, the history and the synced preferences (PLAN's S17f), under /api/v1/me: the project the
// user works in, Project Home and its leads, the research trail with its Session Log and method
// appendix, and the Mac's synced settings. A change asks again what it can change, and an import,
// which can bring any of it, asks again for all of it (`researchImported`).
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import type { Project } from './types';
import { change } from './userData';

const segment = encodeURIComponent;

/** The project the user works in; absent for Global Context. */
export interface ActiveProject {
  projectId?: string;
}

/** Project Home's account of a project, as the app's view shows it. */
export interface ProjectHome {
  project: Project;
  isActive: boolean;
  counts: { collections: number; notes: number; documentsVisited: number; searches: number };
  coverage: {
    corpusId: string;
    corpusName: string;
    engagedCount: number;
    totalCount: number;
    untouched: string;
    description: string;
    truncationLine?: string;
    truncationWarns: boolean;
  }[];
  hasTags: boolean;
  focusTags: { id: string; name: string }[];
  leads: ProjectLead[];
  recentVisits: { volumeId: string; documentId: string; title: string }[];
  recentNotes: { id: string; volumeId: string; documentId: string }[];
  recentSearches: { id: string; queryText: string; resultCount: number }[];
  isEmpty: boolean;
}

/** One of Suggested Next's leads, the Mac's. */
export interface ProjectLead {
  id: string;
  volumeId: string;
  documentId: string;
  title: string;
  isNew: boolean;
  relatedCount: number;
  isEditorialNote: boolean;
}

/** One recorded visit. */
export interface DocumentVisit {
  id: string;
  volumeId: string;
  documentId: string;
  displayTitle?: string;
  /** The row's first line: the document's title, else `volumeId · documentId`. */
  title: string;
  /** `volumeId · documentId` under a title; absent when the title is that pair. */
  caption?: string;
  accessedAt?: string;
  projectId?: string;
}

/** One recorded search, with its count and scope in the method appendix's words. */
export interface SearchRun {
  id: string;
  queryText: string;
  resultCount: number;
  executedAt?: string;
  projectId?: string;
  count: string;
  countBasis: string;
  scope: string;
  workingCorpusId?: string;
}

/** One recorded export. */
export interface ExportRecord {
  id: string;
  format: string;
  formatName: string;
  documentCount: number;
  collectionName?: string;
  title: string;
  exportedAt?: string;
  projectId?: string;
}

/** One page of the trail for a project's scope. */
export interface HistoryPage {
  scope: string;
  limit: number;
  documents: DocumentVisit[];
  searches: SearchRun[];
  exports: ExportRecord[];
  totalDocuments: number;
  totalSearches: number;
  totalExports: number;
  projects: { id: string; name: string }[];
  loggingEnabled: boolean;
}

/** The scope a page of the trail reads: every row, those under no project, or one project's. */
export type HistoryScope = 'all' | 'unfiled' | string;

/** One session's activity, as the Session Log draws it. */
export interface SessionActivity {
  id: string;
  kind: 'documentOpen' | 'search' | 'export';
  timestamp: string;
  projectId?: string;
  volumeId?: string;
  documentId?: string;
  displayTitle?: string;
  query?: string;
  resultCount?: number;
  format?: string;
  formatName?: string;
  documentCount?: number;
  collectionName?: string;
}

/** The Session Log and the Research Sessions pane's summary. */
export interface SessionLog {
  sessions: {
    id: string;
    startedAt: string;
    endedAt: string;
    duration: number;
    activityCount: number;
    isOngoing: boolean;
    activities: SessionActivity[];
  }[];
  loadedActivities: number;
  totalActivities: number;
  pageLimit: number;
  hasMore: boolean;
  summary: { sessionCount: number; isSessionCountExact: boolean; eventCount: number; lastSessionStart?: string };
}

/** The row a search screen last wrote, which its next run of the same query refreshes. */
export interface SearchAnchor {
  entryId: string;
  queryText: string;
}

export interface RecordedSearchRun {
  outcome: 'inserted' | 'refreshed' | 'suppressed' | 'skipped';
  anchor?: SearchAnchor;
  search?: SearchRun;
}

/** The user's synced preferences, the Mac's `SyncedPreferences`. */
export interface Preferences {
  /** `historyAtState`, `chicago` or `turabian`, or empty for none chosen. */
  citationStyle: string;
  /** `read`, `research` or `rememberLast`, or empty for none chosen, which is Remember Last. */
  defaultDocumentMode: string;
  researchLoggingEnabled: boolean;
  tagOrder: string[];
  projectOrder: string[];
  wordCloud: {
    minLength: number;
    minCount: number;
    foldPlurals: boolean;
    filterMarkings: boolean;
    excludeBoilerplate: boolean;
    globalStopwords: string[];
    lensStopwordsJSON: string;
  };
  createdAt?: string;
  updatedAt?: string;
}

/** What a change to the preferences may set. */
export type PreferenceChange = Partial<
  Pick<Preferences, 'citationStyle' | 'defaultDocumentMode' | 'researchLoggingEnabled' | 'tagOrder' | 'projectOrder'>
>;

/** The rows a page of the trail holds at first, and how many Show More adds (`HistoryPaneSnapshot`). */
export const historyPageLimit = 500;
export const historyPageIncrement = 500;
/** The activities the Session Log loads at first, and how many Show More adds (`SessionLogSnapshot`). */
export const sessionLogLimit = 1000;
export const sessionLogIncrement = 1000;

export function projectHomeQuery(projectId: string) {
  return queryOptions({
    queryKey: ['projectHome', projectId],
    queryFn: ({ signal }) => getJSON<ProjectHome>(`/api/v1/me/projects/${segment(projectId)}/home`, undefined, signal),
    staleTime: 30_000,
    retry: false,
  });
}

export function historyQuery(scope: HistoryScope, limit: number) {
  return queryOptions({
    queryKey: ['history', scope, limit],
    queryFn: ({ signal }) =>
      getJSON<HistoryPage>('/api/v1/me/history', new URLSearchParams({ scope, limit: String(limit) }), signal),
    staleTime: 0,
    retry: false,
    placeholderData: (previous) => previous,
  });
}

export function sessionLogQuery(limit: number) {
  return queryOptions({
    queryKey: ['sessionLog', limit],
    queryFn: ({ signal }) => getJSON<SessionLog>('/api/v1/me/history/sessions', new URLSearchParams({ limit: String(limit) }), signal),
    staleTime: 0,
    retry: false,
    placeholderData: (previous) => previous,
  });
}

export const preferencesQuery = queryOptions({
  queryKey: ['preferences'],
  queryFn: ({ signal }) => getJSON<Preferences>('/api/v1/me/preferences', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

/** After a project changes, every list of them and every account of one, and what a note names of them. */
function projectsChanged(client: QueryClient) {
  for (const key of ['projects', 'projectHome', 'history', 'notes', 'note', 'documentNotes', 'exportContents']) {
    void client.invalidateQueries({ queryKey: [key] });
  }
}

/** After the trail changes, what reads it: the history, the Session Log, Project Home and the counts. */
export function trailChanged(client: QueryClient) {
  for (const key of ['history', 'sessionLog', 'projectHome', 'exportContents']) void client.invalidateQueries({ queryKey: [key] });
}

/** New Project…: made, and the project the user works in. */
export async function createProject(client: QueryClient, name: string, researchQuestion?: string): Promise<Project> {
  const project = (await change<Project>(client, 'POST', '/api/v1/me/projects', { name, researchQuestion }))!;
  projectsChanged(client);
  return project;
}

/** The editor's Save, Project Home's question, or the focus tags. */
export async function updateProject(
  client: QueryClient,
  id: string,
  fields: { name?: string; researchQuestion?: string; defaultUserTagIds?: string[] },
): Promise<Project> {
  const project = (await change<Project>(client, 'PATCH', `/api/v1/me/projects/${segment(id)}`, fields))!;
  projectsChanged(client);
  return project;
}

export async function deleteProject(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', `/api/v1/me/projects/${segment(id)}`);
  projectsChanged(client);
}

/** Merge into…: answers the project that takes what was filed under this one. */
export async function mergeProject(client: QueryClient, id: string, into: string): Promise<Project> {
  const project = (await change<Project>(client, 'POST', `/api/v1/me/projects/${segment(id)}/merge`, { into }))!;
  projectsChanged(client);
  return project;
}

/** The project picker: a project to work in, or none, Global Context. */
export async function setActiveProject(client: QueryClient, projectId: string | null): Promise<ActiveProject> {
  const active = (await change<ActiveProject>(client, 'PUT', '/api/v1/me/active-project', { projectId }))!;
  for (const key of ['projects', 'projectHome']) void client.invalidateQueries({ queryKey: [key] });
  return active;
}

/** Suggested Next's ×. */
export async function dismissLead(client: QueryClient, projectId: string, leadId: string): Promise<void> {
  await change(client, 'POST', `/api/v1/me/projects/${segment(projectId)}/leads/${segment(leadId)}/dismiss`);
  void client.invalidateQueries({ queryKey: ['projectHome', projectId] });
}

/** A document the reader opened, which the trail records while Log Research Sessions is on. */
export async function recordVisit(client: QueryClient, volumeId: string, documentId: string): Promise<void> {
  await change(client, 'POST', '/api/v1/me/history/documents', { volumeId, documentId });
  trailChanged(client);
}

/** A search the screen ran, recorded as the Mac's search window records one, with its anchor. */
export async function recordSearch(client: QueryClient, search: string, anchor?: SearchAnchor): Promise<RecordedSearchRun> {
  const run = (await change<RecordedSearchRun>(client, 'POST', '/api/v1/me/history/searches', { search, anchor }))!;
  if (run.outcome === 'inserted' || run.outcome === 'refreshed') trailChanged(client);
  return run;
}

/** A history row's Delete. */
export async function deleteHistoryEntry(client: QueryClient, kind: 'documents' | 'searches' | 'exports', id: string): Promise<void> {
  await change(client, 'DELETE', `/api/v1/me/history/${kind}/${segment(id)}`);
  trailChanged(client);
}

/** Delete Recorded Sessions…: every visit, search and export. */
export async function deleteTrail(client: QueryClient): Promise<{ visits: number; searches: number; exports: number }> {
  const deleted = (await change<{ visits: number; searches: number; exports: number }>(client, 'DELETE', '/api/v1/me/history'))!;
  trailChanged(client);
  return deleted;
}

export async function updatePreferences(client: QueryClient, changed: PreferenceChange): Promise<Preferences> {
  const preferences = (await change<Preferences>(client, 'PATCH', '/api/v1/me/preferences', changed))!;
  client.setQueryData(preferencesQuery.queryKey, preferences);
  if (changed.researchLoggingEnabled !== undefined) trailChanged(client);
  return preferences;
}

/** The method appendix's address, in `format`, its dates in this browser's time zone. */
export function appendixPath(format: 'markdown' | 'csv'): string {
  let timeZone = 'UTC';
  try {
    timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    // A browser that names no zone gets UTC's dates.
  }
  return `/api/v1/me/history/appendix?${new URLSearchParams({ format, timeZone }).toString()}`;
}
