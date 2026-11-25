// The search trail's recording (PLAN's S17f): each search the screen runs is recorded on the server,
// as the Mac's window records each run it completes (`MacSearchViewModel.recordSearchHistory`), with
// the anchor of the row the screen last wrote, so that a run of the same words, under other filters or
// another order, refreshes that row rather than adding one (`SearchHistoryWriter`). The records go one
// after another, each with the anchor the one before it answered, as the Mac's writer moves its anchor
// at once. The anchor and the run recorded last are kept for the tab's session, a reload included, as
// the Mac's window keeps them while it is open, so that a return to a search's results from a
// document, another page of them or a reload records nothing again. A record the server could not take
// is tried again the next time its run is shown. Since S27d a run is of an engine too: the same words searched
// by meaning are another run, which refreshes the row the screen last wrote, as the Mac's writer does.
import type { QueryClient } from '@tanstack/react-query';
import { formEncode } from '../api/form';
import { recordSearch, type SearchAnchor } from '../api/research';
import { heldList, keepAnchor } from './heldLists';
import { filterFields, type SearchState } from './searchState';

/** Where the tab keeps them. */
const storageKey = 'frus.search.trail';

interface Kept {
  anchor?: SearchAnchor;
  lastRecorded?: string;
}

function stored(): Kept {
  try {
    return (JSON.parse(window.sessionStorage.getItem(storageKey) ?? 'null') as Kept | null) ?? {};
  } catch {
    return {};
  }
}

let kept: Kept = stored();
let queue: Promise<void> = Promise.resolve();

function keep(next: Kept): void {
  kept = next;
  try {
    window.sessionStorage.setItem(storageKey, JSON.stringify(next));
  } catch {
    // Storage that refuses keeps them for this page alone.
  }
}

/** The fields a run is of: the search's and its order, never its page. */
function runQuery(state: SearchState): string {
  return formEncode({ ...filterFields(state), sort: state.sort }).toString();
}

/** The run's key: its search, its engine, and a layer's held list (S27e). */
function runKey(state: SearchState, engine: 'keywords' | 'meaning', within?: string): string {
  const search = runQuery(state);
  if (within !== undefined) return `${search} within ${within}`;
  return engine === 'meaning' ? `${search} meaning` : search;
}

/**
 * Records the run of `state` the screen has just shown, through `engine`, unless it was the run recorded last; with
 * `within`, a layer inside the list it names (S27e).
 */
export function recordSearchRun(client: QueryClient, state: SearchState, engine: 'keywords' | 'meaning' = 'keywords', within?: string): void {
  const search = runQuery(state);
  const run = runKey(state, engine, within);
  if (run === kept.lastRecorded) return;
  keep({ ...kept, lastRecorded: run });
  queue = queue.then(async () => {
    try {
      const recorded = await recordSearch(client, search, kept.anchor, engine, within);
      if (recorded.anchor) keep({ ...kept, anchor: recorded.anchor });
    } catch {
      // The trail's loss alone, for now: the search itself stands, and showing it again tries again.
      if (kept.lastRecorded === run) keep({ ...kept, lastRecorded: undefined });
    }
  });
}

// Search Within These Results (S27e) moves the anchor as the app's view model moves it (rule 5): holding a list sets the
// anchor its own search left aside with it, so that no layer refreshes the list's row, each layer writing rows of its own;
// leaving gives it back. Each move waits its turn behind the records sent before it, so that a record still unanswered as
// a list is held or left writes its anchor where it belongs.

/** Sets the anchor aside with the list `within` names, as the list is held. */
export function holdAnchor(within: string): void {
  queue = queue.then(() => {
    keepAnchor(within, kept.anchor);
    keep({ ...kept, anchor: undefined });
  });
}

/**
 * Gives back the anchor the list `within` names kept, as the list is left, however it is: its rows come back from what
 * the screen holds, as the app's are put back from memory, so its own run counts as the run recorded last at once.
 */
export function releaseAnchor(within: string): void {
  const { base } = heldList(within);
  keep({ ...kept, lastRecorded: runKey(base, base.by === 'meaning' ? 'meaning' : 'keywords') });
  queue = queue.then(() => keep({ ...kept, anchor: heldList(within).anchor }));
}

/** Drops the anchor, from one held list to another, a swap's or Back's: the next list's layers write rows of their own. */
export function dropAnchor(): void {
  queue = queue.then(() => keep({ ...kept, anchor: undefined }));
}

/**
 * Records a swap's new list as a search of its own, with no anchor, and keeps the anchor it left with the list `within`
 * names, which the list gives back when it is left.
 */
export function recordListRun(client: QueryClient, state: SearchState, engine: 'keywords' | 'meaning', within: string): void {
  const search = runQuery(state);
  keep({ ...kept, lastRecorded: runKey(state, engine) });
  queue = queue.then(async () => {
    try {
      keepAnchor(within, (await recordSearch(client, search, undefined, engine)).anchor);
    } catch {
      // The trail's loss alone, as for any record.
    }
  });
}

/** Forgets the anchor and the run recorded last, and waits for no record sent before, for tests. */
export function resetSearchHistory(): void {
  queue = Promise.resolve();
  keep({});
}
