// The few lines of the app's collection views that the browser app mirrors (PLAN: "mirrored with a
// parity test that reads the app's source at the pin"). FRUSParityTests' CollectionParityTests reads
// this file and the app's source and holds each to the other: the Collections list's project scope
// (`Collection.visibleCollections`, `hiddenCollectionCount`); the rows Contents lists
// (`CollectionOutline.contentsRows`, over the kit's section ranges the server sends) and their
// indentation; Move Up and Move Down in visible-row coordinates (`moveVisibleRowUp`,
// `canMoveVisibleRowDown`, `moveVisibleRowDown`, `movedBlockEnd`); a document row's status chips
// (`entryStatusChips`); the pickers' body depths (`bodyDepthOptions`); and the Add to Collection
// picker's rows, order and search (`CollectionPickerRow`, `CollectionPickerOrder.held`, the kit's
// `listNameMatches`). The outline itself, each entry's depth and each heading's section, is the
// kit's, which the server sends.
import type { CollectionDetail, CollectionEntry, CollectionListItem } from '../api/collections';

/** `Collection.managerDefaultShowAllCollections`: the list opens on every project's collections. */
export const managerDefaultShowAllCollections = true;

/**
 * `Collection.visibleCollections(_:activeProjectId:showAll:)`: every collection when the scope is
 * lifted or no project is worked in, else those filed under the project.
 */
export function visibleCollections(all: readonly CollectionListItem[], activeProjectId: string | null, showAll: boolean): CollectionListItem[] {
  if (!activeProjectId || showAll) return [...all];
  return all.filter((collection) => collection.projectIds.some((id) => id.toUpperCase() === activeProjectId.toUpperCase()));
}

/** `hiddenCollectionCount`: the collections not filed under the project worked in. */
export function hiddenCollectionCount(all: readonly CollectionListItem[], activeProjectId: string | null): number {
  if (!activeProjectId) return 0;
  return all.filter((collection) => !collection.projectIds.some((id) => id.toUpperCase() === activeProjectId.toUpperCase())).length;
}

/** One row Contents lists: the entry's place in the collection, and the depth it is drawn at. */
export interface ContentsRow {
  index: number;
  depth: number;
  entry: CollectionEntry;
}

/**
 * `CollectionOutline.contentsRows(in:collapsedHeadingIds:savedSearchId:)`: for a collection with no
 * saved search, every row a collapsed heading does not hide (`visibleIndices`, a collapsed heading
 * hiding the rest of its section); for a smart collection, only the entries it keeps, each flush and
 * none hidden.
 */
export function contentsRows(collection: Pick<CollectionDetail, 'entries' | 'savedSearchId'>, collapsed: ReadonlySet<string>): ContentsRow[] {
  const entries = collection.entries;
  if (collection.savedSearchId) {
    return entries.flatMap((entry, index) => (entry.leftOut ? [] : [{ index, depth: 0, entry }]));
  }
  const hidden = new Set<number>();
  entries.forEach((entry, index) => {
    if (entry.kind !== 'heading' || !collapsed.has(entry.id)) return;
    for (let i = index + 1; i < (entry.sectionEnd ?? index + 1); i += 1) hidden.add(i);
  });
  return entries.flatMap((entry, index) => (hidden.has(index) ? [] : [{ index, depth: entry.depth, entry }]));
}

/** `outlineIndent(for:)` in steps: a heading by its depth above level 1, any other row by its heading's depth. */
export function outlineSteps(row: ContentsRow): number {
  return row.entry.kind === 'heading' ? Math.max(0, row.depth - 1) : row.depth;
}

/** `movedBlockEnd(of:)`: the end of what a move carries, a heading's whole section, any other row itself. */
export function movedBlockEnd(entries: readonly CollectionEntry[], index: number): number {
  const entry = entries[index];
  if (!entry) return entries.length;
  return entry.kind === 'heading' ? (entry.sectionEnd ?? index + 1) : index + 1;
}

/** A move in full-outline positions: the row's place, and the offset it is dropped at. */
export interface OutlineMove {
  from: number;
  to: number;
}

/** `moveVisibleRows(_:to:visible:)`'s mapping from visible rows to the outline. */
function visibleMove(rows: readonly ContentsRow[], pos: number, newOffset: number, count: number): OutlineMove | null {
  const row = rows[pos];
  if (!row) return null;
  return { from: row.index, to: newOffset >= rows.length ? count : rows[newOffset]!.index };
}

/** `moveVisibleRowUp(_:rows:)`: before the visible row above, a collapsed section above hopped whole. */
export function moveUp(rows: readonly ContentsRow[], pos: number, count: number): OutlineMove | null {
  return pos > 0 ? visibleMove(rows, pos, pos - 1, count) : null;
}

/** `canMoveVisibleRowDown(_:rows:)`: a listed row past the block the move carries. */
export function canMoveDown(rows: readonly ContentsRow[], entries: readonly CollectionEntry[], pos: number): boolean {
  const row = rows[pos];
  if (!row) return false;
  const blockEnd = movedBlockEnd(entries, row.index);
  return rows.slice(pos + 1).some((later) => later.index >= blockEnd);
}

/** `moveVisibleRowDown(_:rows:)`: after the first visible row past the block it carries. */
export function moveDown(rows: readonly ContentsRow[], entries: readonly CollectionEntry[], pos: number): OutlineMove | null {
  const row = rows[pos];
  if (!row) return null;
  const blockEnd = movedBlockEnd(entries, row.index);
  const nextPos = rows.findIndex((later) => later.index >= blockEnd);
  return nextPos < 0 ? null : visibleMove(rows, pos, nextPos + 1, entries.length);
}

/** The server's move for an outline move: the entry, and the one it goes before, none for the end. */
export function moveRequest(entries: readonly CollectionEntry[], move: OutlineMove): { entryId: string; before: string | null } {
  return { entryId: entries[move.from]!.id, before: entries[move.to]?.id ?? null };
}

/** A document row's chips, each a word `copy.collections.chips` names. */
export type EntryChip =
  | { kind: 'bodyDepth'; depth: string }
  | { kind: 'notesOff' }
  | { kind: 'notes'; count: number }
  | { kind: 'highlightsOff' }
  | { kind: 'headnote' }
  | { kind: 'seeAlso' };

/** `collectionEntryHeadnoteIsResolvedOn(_:)`: the entry's own headnote, else the collection's default. */
export function headnoteResolvedOn(entry: CollectionEntry, collection: Pick<CollectionDetail, 'defaultIncludeHeadnote'>): boolean {
  return entry.includeHeadnote ?? collection.defaultIncludeHeadnote;
}

/**
 * `entryStatusChips(entry:availableNoteCount:)`: the body depth an entry sets; Notes off, or its notes'
 * count, the selection's, else the legacy note's one, else all the document's; Highlights off; the
 * headnote when it resolves on; and See also.
 */
export function entryChips(entry: CollectionEntry, collection: Pick<CollectionDetail, 'defaultIncludeHeadnote'>): EntryChip[] {
  const chips: EntryChip[] = [];
  if (entry.bodyDepthOverride && ['full', 'summaryOnly', 'index'].includes(entry.bodyDepthOverride)) {
    chips.push({ kind: 'bodyDepth', depth: entry.bodyDepthOverride });
  }
  if (entry.includeNotesOverride === false) {
    chips.push({ kind: 'notesOff' });
  } else {
    const count = entry.selectedNoteIds.length > 0 ? entry.selectedNoteIds.length : entry.researchNoteId ? 1 : (entry.noteCount ?? 0);
    if (count > 0) chips.push({ kind: 'notes', count });
  }
  if (entry.applyHighlightsOverride === false) chips.push({ kind: 'highlightsOff' });
  if (headnoteResolvedOn(entry, collection)) chips.push({ kind: 'headnote' });
  if (entry.includeRelatedDocuments === true) chips.push({ kind: 'seeAlso' });
  return chips;
}

/**
 * `bodyDepthOptions` and the rows' `depthOptions`: the depths offered, and the one set even when it is
 * not, so a collection from a Mac with summaries still shows its choice.
 */
export function bodyDepthOptions(offered: readonly string[], current: string | undefined): string[] {
  return current && !offered.includes(current) ? [...offered, current] : [...offered];
}

/** `CollectionPickerRow`: whether a collection takes the document or excerpt: a smart one takes none. */
export function pickerTakesEntries(collection: Pick<CollectionListItem, 'isSmart'>): boolean {
  return !collection.isSmart;
}

/**
 * `CollectionPickerOrder.held(_:id:listed:)`: the collections in the order the picker opened with,
 * any made since ahead of them.
 */
export function heldOrder<T extends { id: string }>(items: readonly T[], listed: readonly string[] | null): T[] {
  if (!listed) return [...items];
  const place = new Map<string, number>();
  listed.forEach((id, at) => {
    if (!place.has(id)) place.set(id, at);
  });
  const known: { at: number; item: T }[] = [];
  const made: T[] = [];
  for (const item of items) {
    const at = place.get(item.id);
    if (at === undefined) made.push(item);
    else known.push({ at, item });
  }
  return [...made, ...known.sort((a, b) => a.at - b.at).map((entry) => entry.item)];
}

/** The kit's `CollectionEditorNaming.listNameMatches(savedName:searchText:)`: the row's name holds the text, case aside. */
export function listNameMatches(listName: string, searchText: string): boolean {
  return listName.toLocaleLowerCase('en-US').includes(searchText.toLocaleLowerCase('en-US'));
}

/** `CollectionDocumentDiscovery.documentKey`: `volumeId/documentId`. */
export function documentKey(volumeId: string, documentId: string): string {
  return `${volumeId}/${documentId}`;
}
