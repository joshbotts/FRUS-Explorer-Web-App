// Collections (PLAN's S18d), under /api/v1/me/collections: the user's collections, one with its entries
// as the editor shows it, and every change the editor makes, each answered with the collection as it
// then stands, which takes the place of the one held. The Collections list, the Add to Collection
// picker and the Research rail's Collections section are read again after a change, and after an
// import, which can bring collections (`researchImported`). Since S18e, a collection's live preview,
// a page of the server's for the editor's frame, its exports, which the history keeps, and the
// quotation check its export sheet runs. Since S18f, a `.fruscollection` file both ways, a smart
// collection's link to a saved search and its results, Create Static Snapshot, and the headnote card.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { servedPath } from './base';
import { ApiError, getJSON, sendFile, sendForFile } from './client';
import type { NoteRun } from './types';
import { change, meQuery } from './userData';

const segment = encodeURIComponent;

/** A collection in the Collections list and the Add to Collection picker. */
export interface CollectionListItem {
  id: string;
  name: string;
  /** What a row prints: the name trimmed, or Untitled Collection. */
  listName: string;
  /** Its document entries. */
  documentCount: number;
  /** Linked to a saved search: its row says Smart collection where another counts its documents. */
  isSmart: boolean;
  projectIds: string[];
  createdAt?: string;
  lastModified?: string;
}

export interface CollectionList {
  total: number;
  items: CollectionListItem[];
}

/** The kinds of entry, as the kit reads them: `unrecognized` for one a newer build wrote. */
export type CollectionEntryKind = 'document' | 'heading' | 'prose' | 'excerpt' | 'generated' | 'unrecognized';

/** The five apparatus blocks, in the kit's order (`CollectionGeneratedBlockType.allCases`). */
export const generatedBlockTypes = ['bibliography', 'chronology', 'archivalSources', 'personsIndex', 'thematicIndex'] as const;
export type GeneratedBlockType = (typeof generatedBlockTypes)[number];

/** The body depths, in the kit's order (`CollectionBodyDepth.allCases`). */
export const bodyDepths = ['full', 'summaryOnly', 'index'] as const;
export type BodyDepth = (typeof bodyDepths)[number];

/** The four presets, in the kit's order (`CollectionPreset.allCases`). */
export type PresetId = 'teachingReader' | 'briefingPacket' | 'sourceDossier' | 'scholarlyEdition';

/** The contents list's two styles (`CollectionToCStyle.allCases`). */
export const tocStyles = ['citation', 'headerAndDateline'] as const;
export type TocStyle = (typeof tocStyles)[number];

/** One entry, as stored, with what its row shows and the outline's facts for it. */
export interface CollectionEntry {
  id: string;
  kind: CollectionEntryKind;
  sortOrder: number;
  level: number;
  /** The outline's depth: a heading's resolved level, any other entry its heading's, 0 before any. */
  depth: number;
  documentId: string;
  volumeId: string;
  text?: string;
  /** A note block's formatting; absent for none, or for RTF kept until it is edited (`formattingKept`). */
  runs?: NoteRun[];
  formattingKept: boolean;
  titleOverride?: string;
  bodyDepthOverride?: string;
  applyHighlightsOverride?: boolean;
  includeNotesOverride?: boolean;
  includeSourceNoteOverride?: boolean;
  includeFootnotesOverride?: boolean;
  summaryPromptIdOverride?: string;
  includeRelatedDocuments?: boolean;
  includeHeadnote?: boolean;
  headnoteSummaryId?: string;
  researchNoteId?: string;
  selectedNoteIds: string[];
  selectedHighlightIds: string[];
  excerptStart?: number;
  excerptEnd?: number;
  excerptRenderingVersion?: string;
  excerptColorTag?: string;
  generatedBlockType?: string;
  /** A heading's section: the position after its last entry. */
  sectionEnd?: number;
  canIndent: boolean;
  canOutdent: boolean;
  /** A smart collection leaves it out of everything it produces. */
  leftOut: boolean;
  /** Another document entry holds the same document. */
  isDuplicate: boolean;
  header?: string;
  volumeTitle?: string;
  dateISO?: string;
  /** For a document: how many notes its document has. */
  noteCount?: number;
}

/** One collection, as its editor shows it. */
export interface CollectionDetail {
  id: string;
  name: string;
  listName: string;
  note?: string;
  subtitle?: string;
  authorLine?: string;
  introductionText?: string;
  introductionRuns?: NoteRun[];
  introductionFormattingKept: boolean;
  includeColophon: boolean;
  includeProjectProvenance: boolean;
  includeMethodAppendix: boolean;
  projectIds: string[];
  savedSearchId?: string;
  /** The linked saved search's name; absent for none, or for one the user no longer has. */
  savedSearchName?: string;
  takesHandAddedEntries: boolean;
  defaultBodyDepth: string;
  includeFootnotes: boolean;
  includeSourceNote: boolean;
  tocStyle: string;
  applyHighlights: boolean;
  includeNotes: boolean;
  includeWordCloud: boolean;
  defaultIncludeHeadnote: boolean;
  summaryPromptId?: string;
  /** Whether a document of it has a stored summary: only then are Summary only and Briefing packet offered. */
  summariesAvailable: boolean;
  /** The body depths a picker offers. */
  bodyDepths: string[];
  /** The presets offered, with whether each is the collection's composition. */
  presets: { id: PresetId; active: boolean }[];
  /** The user's summary prompts, by name. */
  prompts: { id: string; name: string }[];
  documentCount: number;
  /** The volumes of its documents the server's folder lacks, which the preview shows as citations (S18e). */
  volumesNotHeld: string[];
  entries: CollectionEntry[];
  createdAt?: string;
  lastModified?: string;
}

/** A collection after a change that added entries, with the ids it added. */
export interface CollectionEdit {
  collection: CollectionDetail;
  entryIds: string[];
}

/** What the inspector shows of a document entry, or of a heading's section defaults. */
export interface EntryInspector {
  entryId: string;
  kind: 'document' | 'heading';
  sectionTitle?: string;
  documentId: string;
  volumeId: string;
  header?: string;
  volumeTitle?: string;
  derivedTitle?: string;
  notes: { id: string; preview: string; included: boolean }[];
  highlights: { id: string; colorTag: string; text?: string; included: boolean }[];
  tags: string[];
  summary?: { text: string; promptName?: string };
  resolved?: {
    bodyDepth: string;
    highlights: boolean;
    notes: boolean;
    sourceNote: boolean;
    footnotes: boolean;
    related: boolean;
    summaryPromptId?: string;
    headnote: boolean;
  };
  excerpts: { id: string; text: string }[];
  sourceNote?: string;
  /** For a document: whether it has a summary stored, without which Summary only is not offered. */
  summaryOnlyOffered?: boolean;
  /** For a document: the summary its headnote card shows, with who wrote it. */
  headnote?: { summaryId: string; text: string; authorship: string; isDraft: boolean };
}

/** The collections that hold a document among their documents. */
export interface DocumentCollections {
  volumeId: string;
  documentId: string;
  items: { id: string; listName: string }[];
}

/** A collection's own fields as the editor sends a change to them. */
export interface CollectionChanges {
  name?: string;
  note?: string;
  subtitle?: string;
  authorLine?: string;
  introductionText?: string;
  introductionRuns?: NoteRun[] | null;
  includeColophon?: boolean;
  includeProjectProvenance?: boolean;
  includeMethodAppendix?: boolean;
  defaultBodyDepth?: string;
  includeFootnotes?: boolean;
  includeSourceNote?: boolean;
  tocStyle?: string;
  applyHighlights?: boolean;
  includeNotes?: boolean;
  includeWordCloud?: boolean;
  defaultIncludeHeadnote?: boolean;
  summaryPromptId?: string | null;
  /** Link to Saved Search…'s pick, or null for Unlink. */
  savedSearchId?: string | null;
}

/** An entry's fields as its row and the inspector send a change to them; null is Default. */
export interface EntryChanges {
  text?: string;
  runs?: NoteRun[] | null;
  titleOverride?: string;
  bodyDepthOverride?: string | null;
  applyHighlightsOverride?: boolean | null;
  includeNotesOverride?: boolean | null;
  includeSourceNoteOverride?: boolean | null;
  includeFootnotesOverride?: boolean | null;
  summaryPromptIdOverride?: string | null;
  includeRelatedDocuments?: boolean | null;
  includeHeadnote?: boolean | null;
  highlight?: { id: string; included: boolean };
  note?: { id: string; included: boolean };
}

export interface DocumentRef {
  volumeId: string;
  documentId: string;
}

const base = '/api/v1/me/collections';

/** A collection's id as the cache and the queues hold it, in the Mac's uppercase, whatever case an address gives it. */
const keyOf = (id: string) => id.toUpperCase();

/** The user's collections, the most recently changed first. */
export const collectionsQuery = queryOptions({
  queryKey: ['collections'],
  queryFn: ({ signal }) => getJSON<CollectionList>(base, undefined, signal),
  staleTime: 30_000,
  retry: false,
});

/** One collection, as the editor shows it. */
export function collectionQuery(id: string) {
  return queryOptions({
    queryKey: ['collection', keyOf(id)],
    queryFn: ({ signal }) => getJSON<CollectionDetail>(`${base}/${segment(id)}`, undefined, signal),
    staleTime: 30_000,
    retry: false,
  });
}

/** The inspector of one entry, read afresh each time it opens. */
export function entryInspectorQuery(collectionId: string, entryId: string) {
  return queryOptions({
    queryKey: ['collectionInspector', keyOf(collectionId), keyOf(entryId)],
    queryFn: ({ signal }) =>
      getJSON<EntryInspector>(`${base}/${segment(collectionId)}/entries/${segment(entryId)}/inspector`, undefined, signal),
    staleTime: 0,
    retry: false,
  });
}

/** The collections that hold a document, for the Research rail. */
export function documentCollectionsQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['documentCollections', volumeId, documentId],
    queryFn: ({ signal }) =>
      getJSON<DocumentCollections>(
        `/api/v1/me/volumes/${segment(volumeId)}/documents/${segment(documentId)}/collections`,
        undefined,
        signal,
      ),
    staleTime: 30_000,
    retry: false,
  });
}

/** Whether the server has no such collection: deleted elsewhere. */
export const collectionGone = (error: unknown) => error instanceof ApiError && error.code === 'COLLECTION_NOT_FOUND';

/** The formats a collection exports to here, the app's `ExportFormat` raw values, in its grid's order. */
export const exportFormats = ['html', 'docx', 'bibtex', 'zoteroJSON', 'fruscollection'] as const;
export type ExportFormat = (typeof exportFormats)[number];

/** A smart collection's results, which the preview's bar counts. */
export interface SmartResults {
  total: number;
  items: DocumentRef[];
}

/** A smart collection's results, run again each time the preview is built. */
export function smartResultsQuery(id: string) {
  return queryOptions({
    queryKey: ['collectionResults', keyOf(id)],
    queryFn: async ({ signal }) => {
      await whenAnswered(id);
      return getJSON<SmartResults>(`${base}/${segment(id)}/results`, undefined, signal);
    },
    staleTime: 0,
    retry: false,
  });
}

/** `CollectionPreviewView.initialDocumentCap`: the documents the preview shows until Render All. */
export const previewDocumentCap = 20;

/** What the export sheet's check of a collection's quotations says. */
export interface ExcerptCheck {
  /** The sentence above Export, or none when there is nothing to say. */
  summary?: string;
  /** A quotation was not found in the document it names. */
  hasFailures: boolean;
  verified: number;
}

/** The browser's time zone, which an export's dates are read in, as the app reads them in the device's. */
export function browserTimeZone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    // A browser that names no zone gets UTC's dates, as the method appendix does.
    return 'UTC';
  }
}

/**
 * The address of a collection's live preview, the server's page for the editor's frame: the first 20
 * documents, or all of them after Render All. The frame is sent to it again after each change.
 */
export function previewURL(id: string, renderAll: boolean): string {
  const query = new URLSearchParams({ renderAll: String(renderAll), timeZone: browserTimeZone() });
  return `${servedPath(`${base}/${segment(id)}/preview`)}?${query.toString()}`;
}

/** The quotation check, run each time the export sheet opens, as the app's sheet runs its own, over the collection the server holds once the changes sent are answered. */
export function excerptCheckQuery(id: string) {
  return queryOptions({
    queryKey: ['collectionExcerptCheck', keyOf(id)],
    queryFn: async ({ signal }) => {
      await whenAnswered(id);
      return getJSON<ExcerptCheck>(`${base}/${segment(id)}/excerpt-check`, undefined, signal);
    },
    staleTime: 0,
    gcTime: 0,
    retry: false,
  });
}

/**
 * Exports a collection as the sheet's chosen format, once the changes sent to it are answered: the
 * file the server's exporter writes, with the name it gives, which the history then lists.
 */
export async function exportCollection(
  client: QueryClient,
  id: string,
  format: ExportFormat,
  includeNotes = false,
): Promise<{ blob: Blob; name: string }> {
  await whenAnswered(id);
  // Only the native file carries notes, and only when the sheet's switch says so.
  const body = format === 'fruscollection' ? { format, timeZone: browserTimeZone(), includeNotes } : { format, timeZone: browserTimeZone() };
  const path = `${base}/${segment(id)}/export`;
  const me = await client.ensureQueryData(meQuery);
  let file: { blob: Blob; name: string };
  try {
    file = await sendForFile(path, me.csrfToken, body, 'Untitled Collection');
  } catch (error) {
    if (!(error instanceof ApiError && error.code === 'CSRF_TOKEN_INVALID')) throw error;
    const fresh = await client.fetchQuery({ ...meQuery, staleTime: 0 });
    file = await sendForFile(path, fresh.csrfToken, body, 'Untitled Collection');
  }
  void client.invalidateQueries({ queryKey: ['history'] });
  return file;
}

/**
 * After a change to a collection: the one held takes the answer's place, and the lists that name
 * collections are read again where they are next shown: the list, the rail's memberships, Project
 * Home's tally of what a project files.
 */
function collectionChanged(client: QueryClient, detail?: CollectionDetail) {
  if (detail) client.setQueryData(collectionQuery(detail.id).queryKey, shown(detail.id, detail));
  void client.invalidateQueries({ queryKey: ['collections'] });
  void client.invalidateQueries({ queryKey: ['documentCollections'] });
  void client.invalidateQueries({ queryKey: ['collectionInspector'] });
  void client.invalidateQueries({ queryKey: ['collectionResults'] });
  void client.invalidateQueries({ queryKey: ['projectHome'] });
  void client.invalidateQueries({ queryKey: ['projects'], refetchType: 'none' });
}

/**
 * Each collection's changes, one at a time: a change is sent once the one before it is answered, so
 * the answers come in the order the changes were made, and the newest stands, as the editor's live
 * saves one after another leave the model.
 */
const queues = new Map<string, Promise<unknown>>();

function inTurn<T>(id: string, send: () => Promise<T>): Promise<T> {
  const key = keyOf(id);
  const before = queues.get(key) ?? Promise.resolve();
  const next = before.then(send, send);
  const settled = next.then(
    () => undefined,
    () => undefined,
  );
  queues.set(key, settled);
  void settled.then(() => {
    if (queues.get(key) === settled) queues.delete(key);
  });
  return next;
}

/** Once every change sent to the collection so far is answered, so that what the server holds is what was shown. */
export function whenAnswered(id: string): Promise<void> {
  return queues.get(keyOf(id))?.then(() => undefined) ?? Promise.resolve();
}

/**
 * The changes sent and not yet answered, for each collection, each shown at once over the copy held,
 * so that a switch or a choice shows what was chosen, and a second press reads it, until the server's
 * answer stands; an answer to an earlier change is shown with the later ones over it.
 */
const unanswered = new Map<string, ((detail: CollectionDetail) => CollectionDetail)[]>();

/** `detail` with the collection's unanswered changes over it. */
function shown(id: string, detail: CollectionDetail): CollectionDetail {
  return (unanswered.get(keyOf(id)) ?? []).reduce((held, patch) => patch(held), detail);
}

/** Sends a collection's change, its answer taking the held one's place; one deleted elsewhere leaves. */
async function send<T extends CollectionDetail | CollectionEdit>(
  client: QueryClient,
  id: string,
  method: 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  path: string,
  body?: unknown,
  settle?: () => void,
): Promise<T> {
  try {
    const answer = (await change<T>(client, method, path, body))!;
    settle?.();
    collectionChanged(client, 'collection' in answer ? answer.collection : answer);
    return answer;
  } catch (error) {
    settle?.();
    if (collectionGone(error)) {
      client.removeQueries({ queryKey: collectionQuery(id).queryKey });
      collectionChanged(client);
    }
    throw error;
  }
}

/** A collection's change, sent in its turn. */
function changed<T extends CollectionDetail | CollectionEdit>(
  client: QueryClient,
  id: string,
  method: 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  path: string,
  body?: unknown,
): Promise<T> {
  return inTurn(id, () => send<T>(client, id, method, path, body));
}

/**
 * A change shown at once, `patch` over the copy held until its answer comes; a refusal reads the
 * collection again, as the server holds it.
 */
function showing(
  client: QueryClient,
  id: string,
  patch: (detail: CollectionDetail) => CollectionDetail,
  method: 'POST' | 'PATCH',
  path: string,
  body: unknown,
): Promise<CollectionDetail> {
  const key = keyOf(id);
  unanswered.set(key, [...(unanswered.get(key) ?? []), patch]);
  const query = collectionQuery(id).queryKey;
  const held = client.getQueryData<CollectionDetail>(query);
  if (held) client.setQueryData(query, patch(held));
  const settle = () => {
    const rest = (unanswered.get(key) ?? []).filter((pending) => pending !== patch);
    if (rest.length > 0) unanswered.set(key, rest);
    else unanswered.delete(key);
  };
  return inTurn(id, () => send<CollectionDetail>(client, id, method, path, body, settle)).catch((error: unknown) => {
    void client.invalidateQueries({ queryKey: query });
    throw error;
  });
}

/** The fields of a collection's own a switch or a choice sets, which a change shows at once. */
const shownCollectionFields = [
  'includeColophon',
  'includeProjectProvenance',
  'includeMethodAppendix',
  'defaultBodyDepth',
  'includeFootnotes',
  'includeSourceNote',
  'tocStyle',
  'applyHighlights',
  'includeNotes',
  'includeWordCloud',
  'defaultIncludeHeadnote',
  'summaryPromptId',
] as const;

/** An entry's overrides, which a change shows at once; null is Default, which the entry holds as none. */
const shownEntryFields = [
  'bodyDepthOverride',
  'applyHighlightsOverride',
  'includeNotesOverride',
  'includeSourceNoteOverride',
  'includeFootnotesOverride',
  'summaryPromptIdOverride',
  'includeRelatedDocuments',
  'includeHeadnote',
] as const;

/** The Mac's New Collection: a name, in the project the user works in. */
export async function createCollection(client: QueryClient, name: string): Promise<CollectionDetail> {
  const made = (await change<CollectionDetail>(client, 'POST', base, { name }))!;
  collectionChanged(client, made);
  return made;
}

export function updateCollection(client: QueryClient, id: string, changes: CollectionChanges): Promise<CollectionDetail> {
  const patch = (detail: CollectionDetail): CollectionDetail => {
    const next: Record<string, unknown> = { ...detail };
    for (const field of shownCollectionFields) {
      if (field in changes) next[field] = changes[field] ?? undefined;
    }
    return next as unknown as CollectionDetail;
  };
  return showing(client, id, patch, 'PATCH', `${base}/${segment(id)}`, changes);
}

/** Deletes a collection, its entries and their headnote drafts; one deleted elsewhere is deleted. */
export async function deleteCollection(client: QueryClient, id: string): Promise<void> {
  try {
    await change(client, 'DELETE', `${base}/${segment(id)}`);
  } catch (error) {
    if (!collectionGone(error)) throw error;
  }
  client.removeQueries({ queryKey: collectionQuery(id).queryKey });
  collectionChanged(client);
}

export async function duplicateCollection(client: QueryClient, id: string): Promise<CollectionDetail> {
  const made = (await change<CollectionDetail>(client, 'POST', `${base}/${segment(id)}/duplicate`))!;
  collectionChanged(client, made);
  return made;
}

/** Import Collection…: a `.fruscollection` file as it is, which becomes a new collection, with any notes it carries. */
export async function importCollectionFile(client: QueryClient, file: Blob): Promise<CollectionDetail> {
  const path = `${base}/import`;
  const me = await client.ensureQueryData(meQuery);
  let made: CollectionDetail;
  try {
    made = await sendFile<CollectionDetail>(path, me.csrfToken, file, 'application/json');
  } catch (error) {
    if (!(error instanceof ApiError && error.code === 'CSRF_TOKEN_INVALID')) throw error;
    const fresh = await client.fetchQuery({ ...meQuery, staleTime: 0 });
    made = await sendFile<CollectionDetail>(path, fresh.csrfToken, file, 'application/json');
  }
  collectionChanged(client, made);
  // The notes it brought are the reader's now, on their documents.
  for (const key of ['notes', 'documentNotes', 'note']) void client.invalidateQueries({ queryKey: [key] });
  return made;
}

/** Create Static Snapshot: the smart collection's results now, as a new collection of their documents. */
export async function snapshotCollection(client: QueryClient, id: string): Promise<CollectionDetail> {
  const made = (await change<CollectionDetail>(client, 'POST', `${base}/${segment(id)}/snapshot`))!;
  collectionChanged(client, made);
  return made;
}

/** Link to Saved Search…'s pick, or null for Unlink, which changes what the collection takes. */
export function linkSavedSearch(client: QueryClient, id: string, savedSearchId: string | null): Promise<CollectionDetail> {
  return changed(client, id, 'PATCH', `${base}/${segment(id)}`, { savedSearchId });
}

export function applyPreset(client: QueryClient, id: string, preset: PresetId): Promise<CollectionDetail> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/preset`, { preset });
}

/** Add Documents: each at the end, in the order chosen, one the collection holds added again. */
export function addDocuments(client: QueryClient, id: string, documents: DocumentRef[]): Promise<CollectionEdit> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/documents`, { documents });
}

/** The Add to Collection picker's add of one document; whether the collection took it, or held it already. */
export async function addDocumentToCollection(
  client: QueryClient,
  id: string,
  document: DocumentRef,
): Promise<{ added: boolean; collection: CollectionListItem }> {
  const answer = (await inTurn(id, () =>
    change<{ added: boolean; collection: CollectionListItem }>(client, 'POST', `${base}/${segment(id)}/document`, document),
  ))!;
  void client.invalidateQueries({ queryKey: collectionQuery(id).queryKey });
  collectionChanged(client);
  return answer;
}

/** Add Section Heading, Add Note Block, or an apparatus block. */
export function addBlock(
  client: QueryClient,
  id: string,
  block: { kind: 'heading' | 'prose' } | { generatedBlockType: GeneratedBlockType },
): Promise<CollectionEdit> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/blocks`, block);
}

/** A selection's excerpt, frozen from the page the frame holds, or highlights' excerpts. */
export function addExcerpts(
  client: QueryClient,
  id: string,
  excerpt:
    | { volumeId: string; documentId: string; startOffset: number; endOffset: number; renderingVersion: string }
    | { highlightIds: string[] },
): Promise<CollectionEdit> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/excerpts`, excerpt);
}

/**
 * A row moved before another, or to the end, a heading with its section: worked out by `request` from
 * the collection as it stands once the changes before it are answered, so a move pressed again before
 * the last one's answer moves the row on from where that one left it. Nothing is sent where the row
 * can move no further.
 */
export function moveEntryBy(
  client: QueryClient,
  id: string,
  request: (detail: CollectionDetail) => { entryId: string; before: string | null } | null,
): Promise<CollectionDetail | undefined> {
  return inTurn(id, async () => {
    const held = client.getQueryData<CollectionDetail>(collectionQuery(id).queryKey);
    const asked = held ? request(held) : null;
    return asked ? send<CollectionDetail>(client, id, 'POST', `${base}/${segment(id)}/move`, asked) : undefined;
  });
}

export function sortByDate(client: QueryClient, id: string, scope: 'wholeCollection' | 'withinSections'): Promise<CollectionDetail> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/sort`, { scope });
}

export function updateEntry(client: QueryClient, id: string, entryId: string, changes: EntryChanges): Promise<CollectionDetail> {
  const patch = (detail: CollectionDetail): CollectionDetail => ({
    ...detail,
    entries: detail.entries.map((entry) => {
      if (keyOf(entry.id) !== keyOf(entryId)) return entry;
      const next: Record<string, unknown> = { ...entry };
      for (const field of shownEntryFields) {
        if (field in changes) next[field] = changes[field] ?? undefined;
      }
      return next as unknown as CollectionEntry;
    }),
  });
  // The inspector's inclusions, shown at once in its rows until it is read again.
  const inclusion = changes.note ?? changes.highlight;
  if (inclusion) {
    const rows = changes.note ? 'notes' : 'highlights';
    client.setQueryData<EntryInspector>(entryInspectorQuery(id, entryId).queryKey, (held) =>
      held
        ? { ...held, [rows]: held[rows].map((row) => (keyOf(row.id) === keyOf(inclusion.id) ? { ...row, included: inclusion.included } : row)) }
        : held,
    );
  }
  return showing(client, id, patch, 'PATCH', `${base}/${segment(id)}/entries/${segment(entryId)}`, changes);
}

/** A smart collection's Remove These Entries: those added before its link, which it leaves out. */
export function removeEntriesFromBeforeLink(client: QueryClient, id: string): Promise<CollectionDetail> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/entries-from-before-link/remove`);
}

/** The headnote card's Save: the researcher's text, a draft of the entry's own. */
export function saveHeadnote(client: QueryClient, id: string, entryId: string, text: string): Promise<CollectionDetail> {
  return changed(client, id, 'PUT', `${base}/${segment(id)}/entries/${segment(entryId)}/headnote`, { text });
}

/** A row's delete: the one entry, a heading alone. */
export function deleteEntry(client: QueryClient, id: string, entryId: string): Promise<CollectionDetail> {
  return changed(client, id, 'DELETE', `${base}/${segment(id)}/entries/${segment(entryId)}`);
}

export function deleteSection(client: QueryClient, id: string, entryId: string): Promise<CollectionDetail> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/entries/${segment(entryId)}/delete-section`);
}

export function indentSection(client: QueryClient, id: string, entryId: string, indent: boolean): Promise<CollectionDetail> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/entries/${segment(entryId)}/${indent ? 'indent' : 'outdent'}`);
}
