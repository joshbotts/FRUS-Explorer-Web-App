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

/** Records the run of `state` the screen has just shown, through `engine`, unless it was the run recorded last. */
export function recordSearchRun(client: QueryClient, state: SearchState, engine: 'keywords' | 'meaning' = 'keywords'): void {
  const search = runQuery(state);
  const run = engine === 'meaning' ? `${search} meaning` : search;
  if (run === kept.lastRecorded) return;
  keep({ ...kept, lastRecorded: run });
  queue = queue.then(async () => {
    try {
      const recorded = await recordSearch(client, search, kept.anchor, engine);
      if (recorded.anchor) keep({ ...kept, anchor: recorded.anchor });
    } catch {
      // The trail's loss alone, for now: the search itself stands, and showing it again tries again.
      if (kept.lastRecorded === run) keep({ ...kept, lastRecorded: undefined });
    }
  });
}

/** Forgets the anchor and the run recorded last, and waits for no record sent before, for tests. */
export function resetSearchHistory(): void {
  queue = Promise.resolve();
  keep({});
}
