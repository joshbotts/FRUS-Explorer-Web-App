// The search trail's recording (PLAN's S17f): each search the screen runs is recorded on the server,
// as the Mac's window records each run it completes (`MacSearchViewModel.recordSearchHistory`), with
// the anchor of the row the screen last wrote, so that a run of the same words, under other filters or
// another order, refreshes that row rather than adding one (`SearchHistoryWriter`). The anchor and the
// run recorded last are kept for the tab's session, as the Mac's window keeps them while it is open, so
// that a return to a search's results from a document, or another page of them, records nothing again.
import type { QueryClient } from '@tanstack/react-query';
import { formEncode } from '../api/form';
import { recordSearch, type SearchAnchor } from '../api/research';
import { filterFields, type SearchState } from './searchState';

let anchor: SearchAnchor | undefined;
let lastRecorded: string | undefined;

/** The fields a run is of: the search's and its order, never its page. */
function runQuery(state: SearchState): string {
  return formEncode({ ...filterFields(state), sort: state.sort }).toString();
}

/** Records the run of `state` the screen has just shown, unless it was the run recorded last. */
export function recordSearchRun(client: QueryClient, state: SearchState): void {
  const search = runQuery(state);
  if (search === lastRecorded) return;
  lastRecorded = search;
  void recordSearch(client, search, anchor)
    .then((run) => {
      if (run.anchor) anchor = run.anchor;
    })
    .catch(() => {
      // A run the server could not record is the trail's loss alone: the search itself stands.
    });
}

/** Forgets the anchor and the run recorded last, for tests. */
export function resetSearchHistory(): void {
  anchor = undefined;
  lastRecorded = undefined;
}
