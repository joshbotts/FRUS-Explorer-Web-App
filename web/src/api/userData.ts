// The user's own data, under /api/v1/me (PLAN's S14c): who the server takes the browser to be, with
// the token every change carries, the user's tags, theirs and a document's, a document's highlights
// (S15c), the user's research notes, a document's summaries and the user's projects (S15d), the
// import of a Mac JSON export (S16c), the export and what it carries (S16d), and the user's tags
// counted over a search (S17d). A change that the server refuses for its token, as after a restart,
// asks for a new one and is sent once more. A change to the user's notes, summaries or tags changes
// what their searches find, so every search the browser holds is asked again.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { ApiError, getFile, getJSON, sendFile, sendJSON } from './client';
import { formEncode } from './form';
import { filterFields, type SearchState } from '../search/searchState';
import type {
  DocumentHighlights,
  DocumentNotes,
  DocumentSummaries,
  DocumentTags,
  ExportContents,
  Highlight,
  HighlightColor,
  ImportStatus,
  Me,
  Note,
  NoteList,
  NoteRun,
  NoteSummary,
  ProjectList,
  SearchTagCounts,
  Summary,
  TagList,
  UserTag,
} from './types';

const segment = encodeURIComponent;

export const meQuery = queryOptions({
  queryKey: ['me'],
  queryFn: ({ signal }) => getJSON<Me>('/api/v1/me', undefined, signal),
  staleTime: Infinity,
  retry: false,
});

export const tagsQuery = queryOptions({
  queryKey: ['tags'],
  queryFn: ({ signal }) => getJSON<TagList>('/api/v1/me/tags', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

function documentTagsPath(volumeId: string, documentId: string): string {
  return `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/tags`;
}

export function documentTagsQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentTags', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentTags>(documentTagsPath(volumeId, documentId), undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/**
 * The user's tags, each counted over the search's results, as the Mac's My Tags toggles count them
 * when the filter is opened, never before. Another search's counts never stand in while the next
 * load, as the Mac's toggles show none while they count.
 */
export function searchTagsQuery(state: SearchState, enabled: boolean) {
  const search = filterFields(state);
  return queryOptions<SearchTagCounts, unknown, SearchTagCounts, unknown[]>({
    queryKey: ['searchTags', search],
    queryFn: ({ signal }) => getJSON<SearchTagCounts>('/api/v1/me/search/tags', formEncode(search), signal),
    enabled,
    staleTime: 5 * 60_000,
    retry: false,
  });
}

/**
 * After a change to what the user's searches read, their notes, summaries, tags and a document's,
 * every search the browser holds is read again: its results, readings, facets and inspector counts,
 * and the tags' counts.
 */
export function searchesChanged(client: QueryClient) {
  for (const key of ['search', 'timeline', 'concordance', 'facets', 'inspect', 'searchTags']) {
    void client.invalidateQueries({ queryKey: [key] });
  }
}

/** Sends a change with the user's token, and once more with a new one if the server no longer knows it. */
export async function change<T>(client: QueryClient, method: 'POST' | 'PUT' | 'PATCH' | 'DELETE', path: string, body?: unknown) {
  const me = await client.ensureQueryData(meQuery);
  try {
    return await sendJSON<T>(method, path, me.csrfToken, body);
  } catch (error) {
    if (!(error instanceof ApiError && error.code === 'CSRF_TOKEN_INVALID')) throw error;
    const fresh = await client.fetchQuery({ ...meQuery, staleTime: 0 });
    return await sendJSON<T>(method, path, fresh.csrfToken, body);
  }
}

/**
 * After a change to a tag itself, every list of tags may name it: the user's and each document's;
 * and a deleted or merged tag's id leaves, or moves in, every note that carried it.
 */
function tagsChanged(client: QueryClient) {
  void client.invalidateQueries({ queryKey: ['tags'] });
  void client.invalidateQueries({ queryKey: ['documentTags'] });
  for (const key of ['notes', 'documentNotes', 'note']) void client.invalidateQueries({ queryKey: [key] });
  // Project Home names its focus tags, and shows them once the reader has a tag (S17f).
  void client.invalidateQueries({ queryKey: ['projectHome'] });
  searchesChanged(client);
}

export async function createTag(client: QueryClient, name: string): Promise<UserTag> {
  const tag = (await change<UserTag>(client, 'POST', '/api/v1/me/tags', { name }))!;
  void client.invalidateQueries({ queryKey: ['tags'] });
  void client.invalidateQueries({ queryKey: ['searchTags'] });
  void client.invalidateQueries({ queryKey: ['projectHome'] });
  return tag;
}

export async function renameTag(client: QueryClient, id: string, name: string): Promise<UserTag> {
  const tag = (await change<UserTag>(client, 'PATCH', `/api/v1/me/tags/${segment(id)}`, { name }))!;
  tagsChanged(client);
  return tag;
}

/** Deletes a tag, and with it its assignments and its id in every note and project. */
export async function deleteTag(client: QueryClient, id: string): Promise<void> {
  await change(client, 'DELETE', `/api/v1/me/tags/${segment(id)}`);
  tagsChanged(client);
}

/** Merges a tag into another, which takes its documents, notes and projects; answers the other. */
export async function mergeTag(client: QueryClient, id: string, into: string): Promise<UserTag> {
  const tag = (await change<UserTag>(client, 'POST', `/api/v1/me/tags/${segment(id)}/merge`, { into }))!;
  tagsChanged(client);
  return tag;
}

/** The tag picker's Done: the document carries exactly these tags. */
export async function setDocumentTags(client: QueryClient, volumeId: string, documentId: string, tagIds: string[]) {
  const tags = (await change<DocumentTags>(client, 'PUT', documentTagsPath(volumeId, documentId), { tagIds }))!;
  client.setQueryData(documentTagsQuery(volumeId, documentId).queryKey, tags);
  searchesChanged(client);
  return tags;
}

/** The Research rail's ×: one tag off the document. */
export async function removeDocumentTag(client: QueryClient, volumeId: string, documentId: string, tagId: string) {
  const tags = (await change<DocumentTags>(client, 'DELETE', `${documentTagsPath(volumeId, documentId)}/${segment(tagId)}`))!;
  client.setQueryData(documentTagsQuery(volumeId, documentId).queryKey, tags);
  searchesChanged(client);
  return tags;
}

function documentHighlightsPath(volumeId: string, documentId: string): string {
  return `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/highlights`;
}

/** A document's highlights, in the order the reader draws them, each stale or not by the kit's rule. */
export function documentHighlightsQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentHighlights', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentHighlights>(documentHighlightsPath(volumeId, documentId), undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/** After a change to one of a document's highlights, its list is read again: the server says what is stale. */
function highlightsChanged(client: QueryClient, volumeId: string, documentId: string) {
  // A highlight is a document annotated, which Project Home's coverage counts (S17f).
  void client.invalidateQueries({ queryKey: ['projectHome'] });
  return client.invalidateQueries({ queryKey: documentHighlightsQuery(volumeId, documentId).queryKey });
}

/**
 * A colour chosen over a selection: a highlight over its offsets in the page whose rendering version
 * the request names. The server takes its text and version from the page's model, as the app's
 * reader does.
 */
export async function createHighlight(
  client: QueryClient,
  volumeId: string,
  documentId: string,
  highlight: { startOffset: number; endOffset: number; colorTag: HighlightColor; renderingVersion: string },
): Promise<Highlight> {
  const made = (await change<Highlight>(client, 'POST', documentHighlightsPath(volumeId, documentId), highlight))!;
  await highlightsChanged(client, volumeId, documentId);
  return made;
}

/** Whether the server has no such highlight: removed elsewhere, in another tab or browser. */
const gone = (error: unknown) => error instanceof ApiError && error.code === 'HIGHLIGHT_NOT_FOUND';

/** Another colour for a highlight, keeping its text, offsets and version. */
export async function recolorHighlight(client: QueryClient, highlight: Highlight, colorTag: HighlightColor): Promise<Highlight> {
  try {
    const recoloured = (await change<Highlight>(client, 'PATCH', `/api/v1/me/highlights/${segment(highlight.id)}`, { colorTag }))!;
    await highlightsChanged(client, highlight.volumeId, highlight.documentId);
    return recoloured;
  } catch (error) {
    // One removed elsewhere leaves the list, and the refusal is said.
    if (gone(error)) await highlightsChanged(client, highlight.volumeId, highlight.documentId);
    throw error;
  }
}

/** Removes a highlight, as the app's Remove Highlight does; one already removed elsewhere is removed. */
export async function deleteHighlight(client: QueryClient, highlight: Highlight): Promise<void> {
  try {
    await change(client, 'DELETE', `/api/v1/me/highlights/${segment(highlight.id)}`);
  } catch (error) {
    if (!gone(error)) throw error;
  }
  await highlightsChanged(client, highlight.volumeId, highlight.documentId);
}

function documentNotesPath(volumeId: string, documentId: string): string {
  return `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/notes`;
}

/** Every note of the user's, the last changed first: All Notes' rows, and the count Settings ▸ Data exports. */
export const notesQuery = queryOptions({
  queryKey: ['notes'],
  queryFn: ({ signal }) => getJSON<NoteList>('/api/v1/me/notes', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

/** A document's notes, the last changed first, as the app's rail lists them. */
export function documentNotesQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentNotes', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentNotes>(documentNotesPath(volumeId, documentId), undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/** One note with its formatting, read afresh each time the editor opens it. */
export function noteQuery(id: string) {
  return queryOptions({
    queryKey: ['note', id],
    queryFn: ({ signal }) => getJSON<Note>(`/api/v1/me/notes/${segment(id)}`, undefined, signal),
    staleTime: 0,
    retry: false,
  });
}

/** The ZIP of every note as the app's Markdown files, a path at the server's root. */
export const notesExportPath = '/api/v1/me/notes/export';

/** What a new note is made with; `linkedHighlightId` is the highlight it is the note of, the app's link. */
export interface NewNote {
  bodyText: string;
  runs: NoteRun[] | null;
  userTagIds: string[];
  projectIds: string[];
  selectedSummaryIds: string[];
  linkedHighlightId?: string;
}

/**
 * What a save sends: the lists always, and the body only when it was edited, its runs null for a
 * plain edit; with neither, the stored text and formatting are kept as they are.
 */
export interface NoteChanges {
  bodyText?: string;
  runs?: NoteRun[] | null;
  userTagIds: string[];
  projectIds: string[];
  selectedSummaryIds: string[];
}

/** Whether the server has no such note: deleted elsewhere, in another tab or browser. */
export const noteGone = (error: unknown) => error instanceof ApiError && error.code === 'NOTE_NOT_FOUND';

/**
 * After a change to one of a document's notes, its list and the user's are read again, both before
 * the change is done, so a screen that moves focus after it finds the rows as they now are.
 */
async function notesChanged(client: QueryClient, volumeId: string, documentId: string) {
  searchesChanged(client);
  // Project Home counts and lists the notes filed under it, and a project's tally counts them (S17f):
  // the tally is read again where it is next shown, not at each save of a note's words.
  void client.invalidateQueries({ queryKey: ['projectHome'] });
  void client.invalidateQueries({ queryKey: ['projects'], refetchType: 'none' });
  await Promise.all([
    client.invalidateQueries({ queryKey: notesQuery.queryKey }),
    client.invalidateQueries({ queryKey: documentNotesQuery(volumeId, documentId).queryKey }),
  ]);
}

/** A new note on a document; a highlight it names takes it as its note, as the app's link does. */
export async function createNote(client: QueryClient, volumeId: string, documentId: string, note: NewNote): Promise<Note> {
  const made = (await change<Note>(client, 'POST', documentNotesPath(volumeId, documentId), note))!;
  client.setQueryData(noteQuery(made.id).queryKey, made);
  if (note.linkedHighlightId) void client.invalidateQueries({ queryKey: documentHighlightsQuery(volumeId, documentId).queryKey });
  await notesChanged(client, volumeId, documentId);
  return made;
}

/** A note saved again; one deleted elsewhere leaves the lists, and the refusal is said. */
export async function updateNote(client: QueryClient, note: Pick<NoteSummary, 'id' | 'volumeId' | 'documentId'>, changes: NoteChanges): Promise<Note> {
  try {
    const saved = (await change<Note>(client, 'PUT', `/api/v1/me/notes/${segment(note.id)}`, changes))!;
    client.setQueryData(noteQuery(saved.id).queryKey, saved);
    await notesChanged(client, note.volumeId, note.documentId);
    return saved;
  } catch (error) {
    if (noteGone(error)) {
      client.removeQueries({ queryKey: noteQuery(note.id).queryKey });
      await notesChanged(client, note.volumeId, note.documentId);
    }
    throw error;
  }
}

/** Deletes a note, as the app's editor and All Notes do; one already deleted elsewhere is deleted. */
export async function deleteNote(client: QueryClient, note: Pick<NoteSummary, 'id' | 'volumeId' | 'documentId'>): Promise<void> {
  try {
    await change(client, 'DELETE', `/api/v1/me/notes/${segment(note.id)}`);
  } catch (error) {
    if (!noteGone(error)) throw error;
  }
  client.removeQueries({ queryKey: noteQuery(note.id).queryKey });
  await notesChanged(client, note.volumeId, note.documentId);
}

function documentSummariesPath(volumeId: string, documentId: string): string {
  return `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/summaries`;
}

/** A document's summaries, drafts left out, the newest first by the app's order. */
export function documentSummariesQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentSummaries', volumeId, documentId],
    queryFn: ({ signal }) => getJSON<DocumentSummaries>(documentSummariesPath(volumeId, documentId), undefined, signal),
    staleTime: 60_000,
    retry: false,
  });
}

/** Whether the server has no such summary: deleted elsewhere. */
const summaryGone = (error: unknown) => error instanceof ApiError && error.code === 'SUMMARY_NOT_FOUND';

function summariesChanged(client: QueryClient, volumeId: string, documentId: string) {
  searchesChanged(client);
  return client.invalidateQueries({ queryKey: documentSummariesQuery(volumeId, documentId).queryKey });
}

/** A summary the researcher writes of a document, the web's own: the app writes none by hand. */
export async function createSummary(client: QueryClient, volumeId: string, documentId: string, responseText: string): Promise<Summary> {
  const made = (await change<Summary>(client, 'POST', documentSummariesPath(volumeId, documentId), { responseText }))!;
  await summariesChanged(client, volumeId, documentId);
  return made;
}

/** The researcher's own summary, its whole text replaced. */
export async function updateSummary(client: QueryClient, summary: Summary, responseText: string): Promise<Summary> {
  try {
    const saved = (await change<Summary>(client, 'PUT', `/api/v1/me/summaries/${segment(summary.id)}`, { responseText }))!;
    await summariesChanged(client, summary.volumeId, summary.documentId);
    return saved;
  } catch (error) {
    if (summaryGone(error)) await summariesChanged(client, summary.volumeId, summary.documentId);
    throw error;
  }
}

/** Deletes the researcher's own summary; one already deleted elsewhere is deleted. */
export async function deleteSummary(client: QueryClient, summary: Summary): Promise<void> {
  try {
    await change(client, 'DELETE', `/api/v1/me/summaries/${segment(summary.id)}`);
  } catch (error) {
    if (!summaryGone(error)) throw error;
  }
  await summariesChanged(client, summary.volumeId, summary.documentId);
}

/** What an export of the user's carries of each type, for Settings ▸ Data's Contents (S16d). */
export const exportContentsQuery = queryOptions({
  queryKey: ['exportContents'],
  queryFn: ({ signal }) => getJSON<ExportContents>('/api/v1/me/export/contents', undefined, signal),
  staleTime: 0,
  retry: false,
});

/**
 * Export as JSON's address: every summary with the app's switch on, and from S17f the project the
 * user works in, which its header names, as the Mac's names its active project.
 */
export function exportPath(includeGeneratedSummaries: boolean, projectId?: string): string {
  const query = new URLSearchParams();
  if (includeGeneratedSummaries) query.set('includeGeneratedSummaries', 'true');
  if (projectId) query.set('projectId', projectId);
  const fields = query.toString();
  return '/api/v1/me/export' + (fields ? `?${fields}` : '');
}

/**
 * Export as JSON: the user's research as the Mac's export, the kit's envelope with the web's one key
 * more, under the name the server gives it, the app's export sheet's.
 */
export function fetchExport(includeGeneratedSummaries: boolean, projectId?: string): Promise<{ blob: Blob; name: string }> {
  return getFile(exportPath(includeGeneratedSummaries, projectId), 'frus-research-export.json');
}

/** The user's projects, by name, for the note editor's Projects and All Notes' filter, and since S17f the one they work in. */
export const projectsQuery = queryOptions({
  queryKey: ['projects'],
  queryFn: ({ signal }) => getJSON<ProjectList>('/api/v1/me/projects', undefined, signal),
  staleTime: 60_000,
  retry: false,
});

/**
 * Sends a Mac JSON export to be imported, as it is, with the user's token, and once more with a new
 * one if the server no longer knows it. Answers the import's status: queued, or already running.
 */
export async function startImport(client: QueryClient, file: Blob): Promise<ImportStatus> {
  const me = await client.ensureQueryData(meQuery);
  try {
    return await sendFile<ImportStatus>('/api/v1/me/import', me.csrfToken, file, 'application/json');
  } catch (error) {
    if (!(error instanceof ApiError && error.code === 'CSRF_TOKEN_INVALID')) throw error;
    const fresh = await client.fetchQuery({ ...meQuery, staleTime: 0 });
    return await sendFile<ImportStatus>('/api/v1/me/import', fresh.csrfToken, file, 'application/json');
  }
}

/** How often an import still under way is asked after, in milliseconds. */
export const importPollInterval = 500;

/** An import's status, asked after until its job has finished, or until the server cannot say. */
export function importStatusQuery(id: string) {
  return queryOptions({
    queryKey: ['import', id],
    queryFn: ({ signal }) => getJSON<ImportStatus>(`/api/v1/me/import/${segment(id)}`, undefined, signal),
    staleTime: 0,
    retry: false,
    refetchInterval: (query) => {
      if (query.state.status === 'error') return false;
      const state = query.state.data?.state;
      return state === 'succeeded' || state === 'failed' ? false : importPollInterval;
    },
  });
}

/** After an import, every list of the user's may hold what it brought, the saved searches, corpora and scopes among them (S17e). */
export function researchImported(client: QueryClient) {
  for (const key of ['tags', 'documentTags', 'notes', 'documentNotes', 'note', 'documentSummaries', 'documentHighlights', 'projects', 'exportContents']) {
    void client.invalidateQueries({ queryKey: [key] });
  }
  for (const key of ['savedSearches', 'workingCorpora', 'workingCorpus', 'volumeScopes', 'volumeScope']) void client.invalidateQueries({ queryKey: [key] });
  // And the project worked in, Project Home, the trail and the synced preferences (S17f).
  for (const key of ['projectHome', 'history', 'sessionLog', 'preferences']) void client.invalidateQueries({ queryKey: [key] });
  searchesChanged(client);
}
