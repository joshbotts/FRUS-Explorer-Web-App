// Collections (PLAN's S18d), under /api/v1/me/collections: the user's collections, one with its entries
// as the editor shows it, and every change the editor makes, each answered with the collection as it
// then stands, which takes the place of the one held. The Collections list, the Add to Collection
// picker and the Research rail's Collections section are read again after a change, and after an
// import, which can bring collections (`researchImported`).
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { ApiError, getJSON } from './client';
import type { NoteRun } from './types';
import { change } from './userData';

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
    queryKey: ['collection', id],
    queryFn: ({ signal }) => getJSON<CollectionDetail>(`${base}/${segment(id)}`, undefined, signal),
    staleTime: 30_000,
    retry: false,
  });
}

/** The inspector of one entry, read afresh each time it opens. */
export function entryInspectorQuery(collectionId: string, entryId: string) {
  return queryOptions({
    queryKey: ['collectionInspector', collectionId, entryId],
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

/**
 * After a change to a collection: the one held takes the answer's place, and the lists that name
 * collections are read again where they are next shown: the list, the rail's memberships, Project
 * Home's tally of what a project files.
 */
function collectionChanged(client: QueryClient, detail?: CollectionDetail) {
  if (detail) client.setQueryData(collectionQuery(detail.id).queryKey, detail);
  void client.invalidateQueries({ queryKey: ['collections'] });
  void client.invalidateQueries({ queryKey: ['documentCollections'] });
  void client.invalidateQueries({ queryKey: ['collectionInspector'] });
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
  const before = queues.get(id) ?? Promise.resolve();
  const next = before.then(send, send);
  const settled = next.then(
    () => undefined,
    () => undefined,
  );
  queues.set(id, settled);
  void settled.then(() => {
    if (queues.get(id) === settled) queues.delete(id);
  });
  return next;
}

/** A collection's change, its answer taking the held one's place; one deleted elsewhere leaves. */
function changed<T extends CollectionDetail | CollectionEdit>(
  client: QueryClient,
  id: string,
  method: 'POST' | 'PATCH' | 'DELETE',
  path: string,
  body?: unknown,
): Promise<T> {
  return inTurn(id, async () => {
    try {
      const answer = (await change<T>(client, method, path, body))!;
      collectionChanged(client, 'collection' in answer ? answer.collection : answer);
      return answer;
    } catch (error) {
      if (collectionGone(error)) {
        client.removeQueries({ queryKey: collectionQuery(id).queryKey });
        collectionChanged(client);
      }
      throw error;
    }
  });
}

/** The Mac's New Collection: a name, in the project the user works in. */
export async function createCollection(client: QueryClient, name: string): Promise<CollectionDetail> {
  const made = (await change<CollectionDetail>(client, 'POST', base, { name }))!;
  collectionChanged(client, made);
  return made;
}

export function updateCollection(client: QueryClient, id: string, changes: CollectionChanges): Promise<CollectionDetail> {
  return changed(client, id, 'PATCH', `${base}/${segment(id)}`, changes);
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

/** A row moved before another, or to the end; a heading takes its section. */
export function moveEntry(client: QueryClient, id: string, entryId: string, before: string | null): Promise<CollectionDetail> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/move`, { entryId, before });
}

export function sortByDate(client: QueryClient, id: string, scope: 'wholeCollection' | 'withinSections'): Promise<CollectionDetail> {
  return changed(client, id, 'POST', `${base}/${segment(id)}/sort`, { scope });
}

export function updateEntry(client: QueryClient, id: string, entryId: string, changes: EntryChanges): Promise<CollectionDetail> {
  return changed(client, id, 'PATCH', `${base}/${segment(id)}/entries/${segment(entryId)}`, changes);
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
