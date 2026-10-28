// Checklist Mode (PLAN's S17e), kept in the browser's memory for the session, as the Mac keeps it for
// its launch, never stored: while it is on, the results the reader has reviewed leave the list, the
// pages and the timeline. A result is reviewed when it is marked, one at a time or a page at a stroke,
// or opened since the mode came on. The marks belong to the search they were made in, and a new search
// starts the checklist again; a narrowing of the same search keeps them.
//
// The rules are the app's, mirrored, as a search's state is the browser's: the marks and the last bulk
// mark's undo (`ReviewedMarks`), what "the same search" is (`ChecklistAnchor`, with the history writer's
// quotation marks, `FTS5InlineQueryParser.normalizingQuotationMarks`); the strip's words, `ChecklistCopy`'s,
// are in copy.ts. SearchSetParityTests holds both to the app's source.
import { useSyncExternalStore } from 'react';
import type { SearchState } from './searchState';

/** A result's key in the checklist, as a working corpus keys a document: `volumeId/documentId`. */
export function reviewedKey(volumeId: string, documentId: string): string {
  return `${volumeId}/${documentId}`;
}

/** Every result marked reviewed, and the last bulk mark apart, which Undo takes back (`ReviewedMarks`). */
export interface ReviewedMarks {
  readonly keys: ReadonlySet<string>;
  readonly lastBulkBatch: ReadonlySet<string>;
}

export const noMarks: ReviewedMarks = { keys: new Set(), lastBulkBatch: new Set() };

/** Marks one result by hand: Undo never takes a hand mark back, so it leaves the last batch. */
export function mark(marks: ReviewedMarks, key: string): ReviewedMarks {
  const keys = new Set(marks.keys).add(key);
  const lastBulkBatch = new Set(marks.lastBulkBatch);
  lastBulkBatch.delete(key);
  return { keys, lastBulkBatch };
}

/**
 * Marks several results at once and remembers those it newly hid. A key marked already is left as it
 * was and is not of the batch; a bulk mark that hides nothing new changes nothing, and the batch before
 * it stays the one Undo restores.
 */
export function markBulk(marks: ReviewedMarks, newKeys: Iterable<string>): { marks: ReviewedMarks; fresh: Set<string> } {
  const fresh = new Set([...newKeys].filter((key) => !marks.keys.has(key)));
  if (fresh.size === 0) return { marks, fresh };
  return { marks: { keys: new Set([...marks.keys, ...fresh]), lastBulkBatch: fresh }, fresh };
}

/** Takes back the last bulk mark, and only that. */
export function undoLastBulk(marks: ReviewedMarks): ReviewedMarks {
  return { keys: new Set([...marks.keys].filter((key) => !marks.lastBulkBatch.has(key))), lastBulkBatch: new Set() };
}

/**
 * How many of the loaded results Undo would bring back to the list: those the last bulk mark hides
 * and nothing else does. A re-run may load fewer of the page than were marked, and a result of the
 * batch opened since is hidden on that account too.
 */
export function undoableCount(marks: ReviewedMarks, loadedKeys: Iterable<string>, otherwiseHidden: ReadonlySet<string>): number {
  if (marks.lastBulkBatch.size === 0) return 0;
  let count = 0;
  for (const key of loadedKeys) if (marks.lastBulkBatch.has(key) && !otherwiseHidden.has(key)) count += 1;
  return count;
}

const typographicDoubleQuotationMarks = new Set(['“', '”', '„', '‟', '＂', '«', '»']);

/** The query grammar's reading of the quotation marks: every typographic double one as U+0022. */
export function normalizingQuotationMarks(text: string): string {
  return [...text].map((character) => (typographicDoubleQuotationMarks.has(character) ? '"' : character)).join('');
}

/** What a search with no words browses: the person and the subject area it names. */
export interface BrowseSubject {
  personRollupId?: string;
  subjectBucket?: string;
}

/** The search a checklist's marks belong to (`ChecklistAnchor`). */
export interface ChecklistAnchor {
  /** The submitted words, trimmed. */
  query: string;
  /** The phrase, prefix and excluded terms, which are words the search matched on too. */
  structuredTerms: string[];
  /** What the search browsed, when it ran with no words at all. */
  browse?: BrowseSubject;
}

function hasText(value: string | undefined): boolean {
  return (value ?? '').trim() !== '';
}

/** The anchor of a search, as `ChecklistAnchor.init(query:parameters:)` makes it. */
export function anchorFor(state: SearchState): ChecklistAnchor {
  const query = (state.keywords ?? '').trim();
  const structuredTerms = [state.phrase ?? '', state.prefixWildcard ?? '', ...(state.excludedTerms ?? [])];
  const textTerms = query !== '' || hasText(state.phrase) || hasText(state.prefixWildcard) || (state.excludedTerms ?? []).length > 0;
  const filterOnly = state.personRollupId !== undefined || state.subjectBucket !== undefined || state.subjectBucketKey !== undefined;
  if (!filterOnly || textTerms) return { query, structuredTerms };
  return {
    query,
    structuredTerms,
    browse: { personRollupId: state.personRollupId, subjectBucket: state.subjectBucketKey ?? state.subjectBucket },
  };
}

/** Whether everything `mine` browsed is still what `next` is of: one it did not name is a narrowing. */
function isStillBrowsed(mine: BrowseSubject, next: BrowseSubject): boolean {
  if (mine.personRollupId !== undefined && mine.personRollupId !== next.personRollupId) return false;
  if (mine.subjectBucket !== undefined && mine.subjectBucket !== next.subjectBucket) return false;
  return true;
}

/** Whether a run is the search `anchor` was made for, so that its marks stand. */
export function isSameSearch(anchor: ChecklistAnchor, next: ChecklistAnchor): boolean {
  if (normalizingQuotationMarks(anchor.query) !== normalizingQuotationMarks(next.query)) return false;
  if (anchor.structuredTerms.length !== next.structuredTerms.length) return false;
  if (anchor.structuredTerms.some((term, index) => term !== next.structuredTerms[index])) return false;
  if (!anchor.browse && !next.browse) return true;
  if (anchor.browse && next.browse) return isStillBrowsed(anchor.browse, next.browse);
  return false;
}

/** The checklist, while it is on: the search it is anchored to, the documents opened since, and the marks. */
export interface Checklist {
  on: boolean;
  anchor?: ChecklistAnchor;
  readSinceEnabled: ReadonlySet<string>;
  marks: ReviewedMarks;
}

const off: Checklist = { on: false, readSinceEnabled: new Set(), marks: noMarks };

/** The results the checklist hides while it is on: those opened since it came on, and those marked. */
export function hiddenKeys(checklist: Checklist): Set<string> {
  return checklist.on ? new Set([...checklist.readSinceEnabled, ...checklist.marks.keys]) : new Set();
}

let current: Checklist = off;
const listeners = new Set<() => void>();

function set(next: Checklist) {
  current = next;
  for (const listener of listeners) listener();
}

/** The checklist as it stands, which a test may set. */
export const checklistStore = {
  get: () => current,
  subscribe(listener: () => void) {
    listeners.add(listener);
    return () => listeners.delete(listener);
  },
  /** Turns it on, anchored to `state`'s search and with no marks, or off, forgetting every mark. */
  setOn(on: boolean, state: SearchState) {
    set(on ? { on: true, anchor: anchorFor(state), readSinceEnabled: new Set(), marks: noMarks } : off);
  },
  /** Settles it against a search about to run: the same search keeps its marks, another starts it again. */
  settle(state: SearchState) {
    if (!current.on) return;
    const next = anchorFor(state);
    if (current.anchor && isSameSearch(current.anchor, next)) return;
    set({ on: true, anchor: next, readSinceEnabled: new Set(), marks: noMarks });
  },
  /** Marks one result reviewed. */
  mark(key: string) {
    if (!current.on) return;
    set({ ...current, marks: mark(current.marks, key) });
  },
  /** Mark Page Reviewed: answers how many rows left the list, less those an opening hid already. */
  markPage(keys: readonly string[]): number {
    if (!current.on) return 0;
    const { marks, fresh } = markBulk(current.marks, keys);
    if (marks !== current.marks) set({ ...current, marks });
    return [...fresh].filter((key) => !current.readSinceEnabled.has(key)).length;
  },
  /**
   * Undo: takes back the last Mark Page Reviewed, and answers how many of its rows an opening does not
   * hide. Which of them the search's results still hold the server says, in the count it hides after.
   */
  undo(): number {
    const restored = undoableCount(current.marks, current.marks.lastBulkBatch, current.readSinceEnabled);
    set({ ...current, marks: undoLastBulk(current.marks) });
    return restored;
  },
  /** A document the reader opened, which hides it while the mode is on, as the Mac's reading history does. */
  opened(key: string) {
    if (!current.on || current.readSinceEnabled.has(key)) return;
    set({ ...current, readSinceEnabled: new Set(current.readSinceEnabled).add(key) });
  },
  reset() {
    set(off);
  },
};

export function useChecklist(): Checklist {
  return useSyncExternalStore(checklistStore.subscribe, checklistStore.get, checklistStore.get);
}
