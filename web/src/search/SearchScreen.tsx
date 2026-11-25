// Search (SPEC, Search): the query box with the app's query language, the filters, the Query
// Inspector's strip, and a page of results in the order chosen, with the exact count and what it
// was counted over, beside the facet panel when it is open, or the results in the reading chosen
// in their place: the timeline or the concordance. A result is named as the Mac's search
// window names it, with the document's label beside its volume unless the title already opens with
// its number. A facet's narrowing shows as a filter token, and a search that found nothing names
// the term responsible, as the Mac's do. On a server that keeps user data (S17d), Search in chooses
// the documents, the user's notes and their summaries, as the Mac's chips do; My Tags filters by the
// user's tags, counted over the results, and shows as a token; and a row carries its document's tags.
// Since S17e a search is saved and recalled, as the Mac's bookmark buttons do; it runs inside a working
// corpus, named over the results, and its rows are saved as one; a volume scope fills the volume filter;
// and Checklist Mode hides the results reviewed, kept in the browser's memory for the session. Since S27d
// a search runs by Keywords or by Meaning, as the Mac's Search by picker chooses, where the server searches
// by meaning: a search by meaning lists the closest matches the kit's Meaning engine ranked, each with its
// chip, under the app's strip in place of the Query Inspector's, and those in volumes this server does not
// serve apart under them; its rows are paged, ordered, checklisted and saved as a working corpus, and the
// trail records it, as a keyword search's are, and the readings and facets, which read a keyword match, wait
// for Keywords. Since S27e the list on screen is held and searched within, as the app's Search Within These Results
// holds one: words found in a Meaning list, or a keyword list or a browse ranked by a question, each the kit's on the
// server, under the row that names the list, with its Swap and its way back; and under a keyword search that found
// nothing, the app's Semantic matches (experimental), the nearest by meaning across the whole series.
import { useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type FormEvent, type ReactNode, type RefObject, useEffect, useEffectEvent, useId, useMemo, useRef, useState } from 'react';
import { ApiError } from '../api/client';
import { concordanceQuery, inspectQuery, searchQuery, timelineQuery, volumesQuery } from '../api/endpoints';
import { meaningQuery, type MeaningSearchResult, serverStatusQuery } from '../api/meaning';
import { heldQuery, type LayerDirection, layerQuery, type LayeredSearchResult, type LayerSummary } from '../api/searchWithin';
import type { ConcordanceOrder, DocumentType, SearchResultList, SortOrder, UserTag, Volume } from '../api/types';
import { recordRun, type SavedSearch } from '../api/searchSets';
import { meQuery, searchTagsQuery, tagsQuery } from '../api/userData';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';
import { anchorFor, type ChecklistAnchor, checklistStore, hiddenKeys, isSameSearch, reviewedKey, useChecklist } from './checklist';
import { ChecklistStrip } from './ChecklistStrip';
import { SavedSearchesDialog, SaveSearchDialog } from './SavedSearches';
import { CorpusBanner, CorpusFilter, SaveCorpusDialog, ScopeFilter } from './WorkingCorpora';
import { FacetPanel, useFacetPanelState } from './FacetPanel';
import { MeaningBeyond, MeaningEmpty, MeaningStrip, SearchBy, type SearchMode } from './MeaningSearch';
import { inspectorFields, QueryInspectorStrip, ZeroResult } from './QueryInspector';
import { ConcordanceReading, ReadingPicker, TimelineReading, type TimelineMode } from './Readings';
import {
  defaultLimit,
  documentTypes,
  filterFields,
  isPaged,
  isPartialEvidence,
  pageCount,
  pageSizes,
  type Reading,
  recalledSearch,
  retainedLimit,
  scopeChange,
  scopes,
  searches,
  searchesAnywhere,
  searchFields,
  type SearchState,
} from './searchState';
import { rowChipLimit, tagChips, tagFilterLabel } from './tagRules';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { applyOrder } from '../research/listOrder';
import { useListOrder, useLoggingEnabled } from '../settings/syncedPreferences';
import { dropAnchor, holdAnchor, recordListRun, recordSearchRun, releaseAnchor } from './searchHistory';
import { heldList, holdList, keepMembers, withinField, withinKey } from './heldLists';
import { HeldListRow, LayerEmpty, MeaningFallback } from './SearchWithin';
import { Snippet } from './Snippet';

const route = getRouteApi('/search');

export function SearchScreen() {
  const state = route.useSearch();
  const navigate = route.useNavigate();
  // A list held (S27e), which the address names by its search, and that search, as the screen showed it. While one is
  // held its own rows show until the field has words, then the layer's.
  const within = state.within;
  const held = within !== undefined ? heldList(within) : undefined;
  // Its answers are kept by its name and its hidden rows, and asked for with the digest of its members once known.
  const heldKey = withinKey(within);
  const heldField = () => withinField(within);
  const fieldEmpty = (state.keywords ?? '').trim() === '';
  const listState: SearchState | undefined =
    held && fieldEmpty ? { ...held.base, sort: state.sort, offset: state.offset, limit: state.limit } : undefined;
  const layered = held !== undefined && !fieldEmpty;
  // Checklist Mode's reviewed results leave the pages, once the checklist is this search's: another
  // search's marks hide nothing while it settles on this one, as the Mac settles it as a search runs.
  // While a list is held, the checklist is its search's, whose marks last through every layer and the way back.
  const checklist = useChecklist();
  const checklistState = held?.base ?? state;
  const anchor = anchorFor(checklistState);
  const anchorKey = JSON.stringify(anchor);
  const settled = checklist.on && checklist.anchor !== undefined && isSameSearch(checklist.anchor, anchor);
  const reviewed = useMemo(() => (settled ? [...hiddenKeys(checklist)].sort() : []), [settled, checklist]);
  const settle = useEffectEvent(() => checklistStore.settle(checklistState));
  useEffect(() => settle(), [anchorKey]);
  // Search by meaning, where the server says it searches by meaning (S27d). A link that asks for Meaning waits for
  // the server's word, and on a server that does not, whose admin has turned its encoder off, searches by keywords,
  // the one engine offered there.
  const status = useQuery(serverStatusQuery);
  const offersMeaning = status.data?.semantic?.searchByMeaning === true;
  // A held Meaning list's own rows wait for the server's word too, and never run through the keyword engine.
  const listByMeaning = listState?.by === 'meaning';
  const modeSettled = (state.by !== 'meaning' && !listByMeaning) || status.data !== undefined || status.isError;
  const byMeaning = state.by === 'meaning' && offersMeaning;
  // While a list is held the field runs the other engine inside it: words in a Meaning list, a question over a keyword
  // list or a browse (S27e).
  const direction: LayerDirection | undefined = held ? (held.base.by === 'meaning' ? 'wordsInMatches' : 'rankByMeaning') : undefined;
  const engine: SearchMode = direction ? (direction === 'wordsInMatches' ? 'keywords' : 'meaning') : byMeaning ? 'meaning' : 'keywords';
  // The search whose rows are on screen when no layer is: the one asked for, or the held list's own, through its engine.
  const rowsState = listState ?? state;
  const rowsByMeaning = listState ? listByMeaning && offersMeaning : !held && byMeaning;
  // A search by meaning asks a question: with no words it asks nothing, and shows nothing, as the Mac's lists none.
  const asksMeaning = rowsByMeaning && (rowsState.keywords ?? '').trim() !== '' && !layered;
  const keywordQuery = searchQuery(rowsState, reviewed);
  const keywordResults = useQuery({
    ...keywordQuery,
    enabled: keywordQuery.enabled && modeSettled && !rowsByMeaning && !listByMeaning && !layered,
  });
  const meaningResults = useQuery(meaningQuery(rowsState, reviewed, asksMeaning));
  const layerResults = useQuery(layerQuery(state, heldKey, heldField, reviewed, layered && (engine === 'keywords' || offersMeaning)));
  const heldSummary = useQuery(heldQuery(heldKey, heldField));
  const results: UseQueryResult<SearchResultList, unknown> = layered ? layerResults : rowsByMeaning ? meaningResults : keywordResults;
  const layer = layered ? (results.data as LayeredSearchResult | undefined)?.layer : undefined;
  // The held list as the server says it last: a layer's own account of it, or its row's.
  const heldRow = layer?.base ?? heldSummary.data;
  // The digest of its members names it from then on, so that a list the server builds again otherwise is refused.
  const memberDigest = heldRow?.memberDigest;
  useEffect(() => {
    if (within !== undefined && memberDigest !== undefined) keepMembers(within, memberDigest);
  }, [within, memberDigest]);
  // The search whose rows are on screen, and the engine that found them: until the next search's arrive, the last
  // one's stay, and a mark made of them would be kept under the next and hide its documents, so marks wait for them,
  // as the Mac's `canMarkReviewed` makes them wait (#1683). Each engine keeps its own last rows, so rows the other
  // engine found for this search say nothing of those shown (S27d).
  // A held list's own rows and a layer's are lists of their own too (S27e).
  const rowsEngine = held ? `${layered ? 'layer' : 'list'} ${within}` : engine;
  const [rowsAnchor, setRowsAnchor] = useState<{ anchor: ChecklistAnchor; engine: string } | null>(null);
  if (
    results.data &&
    !results.isPlaceholderData &&
    (rowsAnchor === null || rowsAnchor.engine !== rowsEngine || JSON.stringify(rowsAnchor.anchor) !== anchorKey)
  ) {
    setRowsAnchor({ anchor, engine: rowsEngine });
  }
  const canMark =
    settled &&
    checklist.anchor !== undefined &&
    rowsAnchor !== null &&
    rowsAnchor.engine === rowsEngine &&
    isSameSearch(checklist.anchor, rowsAnchor.anchor);
  const volumes = useQuery(volumesQuery);
  const queryClient = useQueryClient();
  // The user's tags, for the filter, its token and the rows' chips, on a server that keeps user data.
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const tags = useQuery({ ...tagsQuery, enabled: keepsUserData });
  const userTags = keepsUserData ? tags.data?.items : undefined;
  const logging = useLoggingEnabled();
  // The trail's anchor follows the held list, however the address comes to name one or no longer to, by the row's own
  // controls, Back and Forward, a recall or a hand-off (the app's rule 5): holding one sets the anchor aside with it,
  // leaving gives it back, and from one list to another it is dropped. Before the record below, which reads it.
  const previousWithin = useRef(within);
  useEffect(() => {
    const before = previousWithin.current;
    previousWithin.current = within;
    if (before === within) return;
    if (before === undefined && within !== undefined) holdAnchor(within);
    else if (before !== undefined && within === undefined) releaseAnchor(before);
    else dropAnchor();
  }, [within]);
  // Each run the screen shows goes into the trail (S17f), as the Mac's window records each it completes, by the
  // engine it ran through (S27d), and a layer inside the list it ran within (S27e). A held list's own rows shown again
  // are no run: the app puts them back from memory.
  const record = useEffectEvent(() => recordSearchRun(queryClient, state, engine, layered ? withinField(within) : undefined));
  const shownRun =
    results.data && !results.isPlaceholderData && (!held || layered) ? JSON.stringify({ ...searchFields(state), engine, within }) : undefined;
  useEffect(() => {
    if (keepsUserData && shownRun !== undefined) record();
  }, [keepsUserData, shownRun]);

  /** A new search, or a changed filter, starts at the first page. */
  function update(changes: Partial<SearchState>) {
    void navigate({ search: (previous: SearchState) => ({ ...previous, ...changes, offset: undefined }) });
  }

  // What a facet narrowed from, so the count can say it while the panel is open, as the Mac's does:
  // the figure exists only at the moment of the click, and belongs to the search the click made.
  const panelOpen = state.panel === 'facets';
  const signature = JSON.stringify(filterFields(state));
  const [narrowed, setNarrowed] = useState<{ signature: string; from: number } | null>(null);
  // The panel's sections keep their sort and page size while it is closed, as the Mac's do.
  const facetPanel = useFacetPanelState(state);
  // While the search shown is still the last one's, its count describes that one.
  const shown = results.isPlaceholderData ? undefined : results.data;

  function search(keywords: string) {
    // The same search again leaves the URL as it is, so it asks the server again itself: after a
    // refusal or a server fault, or once an index is ready. So does the account of a search that
    // found nothing.
    if (keywords === state.keywords && state.offset === undefined && layered) {
      void queryClient.refetchQueries({ queryKey: layerQuery(state, heldKey, heldField, reviewed, true).queryKey, exact: true });
    } else if (keywords === state.keywords && state.offset === undefined && byMeaning) {
      void queryClient.refetchQueries({ queryKey: meaningQuery(state, reviewed, true).queryKey, exact: true });
    } else if (keywords === state.keywords && state.offset === undefined) {
      void queryClient.refetchQueries({ queryKey: searchQuery(state, reviewed).queryKey, exact: true });
      void queryClient.refetchQueries({
        queryKey: inspectQuery(inspectorFields(state, keywords), { emptyConjuncts: true }).queryKey,
        exact: true,
      });
      // And the reading shown, which may have failed where the list did.
      if (state.reading === 'timeline') {
        void queryClient.refetchQueries({ queryKey: timelineQuery(state, state.timelineMode === 'list', reviewed).queryKey, exact: true });
      }
      if (state.reading === 'concordance') {
        void queryClient.refetchQueries({ queryKey: concordanceQuery(state, reviewed).queryKey, exact: true });
      }
    } else {
      update({ keywords });
    }
  }

  function narrowTo(next: SearchState) {
    if (results.data) setNarrowed({ signature: JSON.stringify(filterFields(next)), from: results.data.total });
    void navigate({ search: next });
  }

  /**
   * Runs the standing search through the other engine, as the Mac's picker does, from its first page: the readings and
   * the facet panel, which read a keyword match, close on the change, as the Mac's do.
   */
  function setMode(mode: SearchMode) {
    // A search under way through the engine left is abandoned, so the server stops it: its query stays observed,
    // only disabled, so it would otherwise run on.
    void queryClient.cancelQueries({ queryKey: [byMeaning ? 'meaning' : 'search'] });
    void navigate({
      search: (previous: SearchState) => ({
        ...previous,
        by: mode === 'meaning' ? 'meaning' : undefined,
        reading: undefined,
        timelineMode: undefined,
        panel: undefined,
        offset: undefined,
      }),
    });
  }

  // Search Within These Results (S27e). What a screen reader hears as a list is held, left or swapped, and the search
  // box, which takes the focus as a list is held, as the app's field takes the keyboard, and again as the row's or the
  // empty state's control it was on goes, on leaving the list, swapping it or searching the whole library.
  const [layerAnnouncement, setLayerAnnouncement] = useState('');
  const [announcesHold, setAnnouncesHold] = useState(false);
  if (announcesHold && heldSummary.data) {
    setLayerAnnouncement(heldSummary.data.accessibilityLabel);
    setAnnouncesHold(false);
  }
  const [boxFocus, setBoxFocus] = useState(0);

  /**
   * Holds the list on screen and turns the field to the other engine, as the app's command does: the rows stay, the field
   * empties and asks for words or a question, the row that names the list takes Search by's place, and nothing is searched
   * until the reader types. The trail's anchor is set aside with the list, and a ranking is read closest first.
   */
  function holdTheList(direction: LayerDirection) {
    const base: SearchState = { ...state, panel: undefined, reading: undefined, timelineMode: undefined, offset: undefined };
    const name = holdList(base, reviewed);
    setLayerAnnouncement('');
    setAnnouncesHold(true);
    setBoxFocus((count) => count + 1);
    void navigate({
      search: {
        ...base,
        keywords: undefined,
        within: name,
        by: direction === 'rankByMeaning' ? 'meaning' : undefined,
        sort: direction === 'rankByMeaning' ? undefined : base.sort,
      },
    });
  }

  /**
   * The list's own search, as leaving it shows it, as the Mac's window leaves a list: its words, its engine and its order,
   * under the filters in force, which, where one was chosen inside the list, run its search again.
   */
  function listSearch(list: SearchState): SearchState {
    return { ...state, keywords: list.keywords, by: list.by, sort: list.sort, within: undefined, offset: undefined };
  }

  /** Leaves the held list: its search's rows come back, with its order and its engine, and the trail's anchor with them. */
  function leaveTheList() {
    if (!held) return;
    setLayerAnnouncement(copy.searchLayer.left);
    setBoxFocus((count) => count + 1);
    void navigate({ search: listSearch(held.base) });
  }

  /**
   * Swaps the held list and the search inside it, as the app's Swap does: the layer's words or question become a list of
   * their own, through their engine, under the filters and the corpus in force, which is held, and the list's own words or
   * question run inside it. The new list's search is a search of its own in the trail, and its checklist starts over.
   */
  function swapTheLayer(swap: NonNullable<LayerSummary['swap']>) {
    if (!held) return;
    const listEngine: SearchMode = swap.direction === 'rankByMeaning' ? 'keywords' : 'meaning';
    const base: SearchState = {
      ...state,
      within: undefined,
      keywords: swap.listQuery,
      by: listEngine === 'meaning' ? 'meaning' : undefined,
      sort: held.base.sort,
      offset: undefined,
    };
    const name = holdList(base, [], undefined, true);
    if (keepsUserData) recordListRun(queryClient, base, listEngine, name);
    setLayerAnnouncement(swap.help);
    setBoxFocus((count) => count + 1);
    void navigate({
      search: {
        ...base,
        within: name,
        keywords: swap.layerQuery,
        by: swap.direction === 'rankByMeaning' ? 'meaning' : undefined,
        sort: swap.direction === 'rankByMeaning' ? undefined : base.sort,
      },
    });
  }

  // A swap's new list that found nothing holds nothing, as the app's swap ends with nothing to hold: its own search shows.
  const emptySwap = held?.fromSwap === true && heldSummary.data !== undefined && heldSummary.data.rows === 0;
  const endTheSwap = useEffectEvent(() => {
    if (held) void navigate({ search: listSearch(held.base), replace: true });
  });
  useEffect(() => {
    if (emptySwap) endTheSwap();
  }, [emptySwap]);

  // A list the server refuses to hold is let go of, as the Mac's window lets go of one whose index was rebuilt: one built
  // again with other members (`HELD_LIST_CHANGED`), or one a link names that cannot be held here, a Meaning list with the
  // encoder off, another user's corpus.
  const heldError = heldSummary.error instanceof ApiError ? heldSummary.error : undefined;
  const layerError = layerResults.error instanceof ApiError ? layerResults.error : undefined;
  const refusal =
    held && heldError && heldError.status >= 400 && heldError.status < 500
      ? heldError
      : held && layerError?.code === 'HELD_LIST_CHANGED'
        ? layerError
        : undefined;
  // What a screen reader hears of it is said as the refusal arrives, and the list is let go of after the render.
  const [refusalSaid, setRefusalSaid] = useState<ApiError | undefined>(undefined);
  if (refusal && refusal !== refusalSaid) {
    setRefusalSaid(refusal);
    setLayerAnnouncement(refusal.code === 'HELD_LIST_CHANGED' ? refusal.message : copy.searchLayer.left);
  }
  const letGo = useEffectEvent(() => {
    if (held) void navigate({ search: listSearch(held.base), replace: true });
  });
  useEffect(() => {
    if (refusal) letGo();
  }, [refusal]);

  /** Words found nowhere in a Meaning list searched for across the whole library: the list is let go, the words stay. */
  function searchTheLibrary() {
    if (!held) return;
    setBoxFocus((count) => count + 1);
    void navigate({ search: { ...state, within: undefined, by: undefined, offset: undefined } });
  }

  /** Opens or closes the panel in place of the history entry, so Back leaves the search. */
  function setPanel(open: boolean) {
    void navigate({ search: (previous: SearchState) => ({ ...previous, panel: open ? 'facets' : undefined }), replace: true });
  }

  /**
   * Shows the results in another reading, in place of the history entry, as the panel opens. A
   * timeline opens on its chart, as the Mac's opens each time it is shown; choosing the reading
   * already shown changes nothing, as on the Mac's picker.
   */
  function setReading(reading: Reading) {
    void navigate({
      search: (previous: SearchState) =>
        (previous.reading ?? 'list') === reading
          ? previous
          : { ...previous, reading: reading === 'list' ? undefined : reading, timelineMode: undefined },
      replace: true,
    });
  }

  /** Shows the timeline's chart or its list, in place of the history entry. */
  function setTimelineMode(mode: TimelineMode) {
    void navigate({ search: (previous: SearchState) => ({ ...previous, timelineMode: mode === 'list' ? 'list' : undefined }), replace: true });
  }

  /**
   * Orders the concordance's lines, in place of the history entry. The order outlasts its pages,
   * another search and another reading, as the Mac's window keeps its Align by.
   */
  function setAlign(order: ConcordanceOrder) {
    void navigate({ search: (previous: SearchState) => ({ ...previous, align: order === 'leftContext' ? undefined : order }), replace: true });
  }

  // The sheets the search opens, each closed back to the control that opened it.
  const [sheet, setSheet] = useState<'saveSearch' | 'savedSearches' | 'saveCorpus' | null>(null);
  const opener = useRef<HTMLElement | null>(null);
  function open(which: 'saveSearch' | 'savedSearches' | 'saveCorpus', from: HTMLElement) {
    opener.current = from;
    setSheet(which);
  }
  function closed() {
    setSheet(null);
    opener.current?.focus();
  }

  /**
   * A saved search recalled: its search, inside the corpus applied now, and its run stamped from its
   * own count, which the server takes, as the Mac stamps a recall.
   */
  function recall(saved: SavedSearch) {
    // A recall lets go of a held list, as the app's hand-off does, and runs through the list's own engine, the one the
    // reader last chose, never the field's inside the list.
    void navigate({ search: recalledSearch(saved.search, held ? { ...state, by: held.base.by } : state) });
    recordRun(queryClient, saved.id).catch(() => {
      // A stamp that fails leaves the badge where it was, as a count that fails does on the Mac.
    });
  }

  // What Undo brought back, said once the page it changed has loaded: how many fewer results are hidden,
  // where the count before it was known, else the rows of the mark no opening hides.
  const [announcement, setAnnouncement] = useState('');
  const [undone, setUndone] = useState<{ before?: number; rows: number } | null>(null);
  if (undone !== null && shown && !results.isFetching) {
    const restored = undone.before !== undefined ? Math.max(0, undone.before - (shown.hidden ?? 0)) : undone.rows;
    setAnnouncement(copy.checklist.undone(restored));
    setUndone(null);
  }

  // A mark that leaves the page past the last shown, as on the last page, goes back to the first, as the
  // Mac's checklist resets its page (`clampCurrentPage`).
  const pastTheEnd = shown !== undefined && shown.hidden !== undefined && shown.items.length === 0 && (state.offset ?? 0) > 0;
  const toFirstPage = useEffectEvent(() => {
    void navigate({ search: (previous: SearchState) => ({ ...previous, offset: undefined }), replace: true });
  });
  useEffect(() => {
    if (pastTheEnd) toFirstPage();
  }, [pastTheEnd]);

  // Kept from render to render, so the readings' long lists render again only when they change.
  const titles = useMemo(
    () => new Map((volumes.data?.items ?? []).map((volume: Volume) => [volume.volumeId, volume.title])),
    [volumes.data],
  );
  useDocumentTitle(state.keywords ? `${copy.search.title}: ${state.keywords}` : copy.search.title);

  return (
    <section className="screen search">
      <h1 tabIndex={-1}>{copy.search.title}</h1>
      <SearchEntry
        state={state}
        titles={titles}
        keepsUserData={keepsUserData}
        userTags={userTags}
        update={update}
        onSearch={search}
        engine={offersMeaning || held ? engine : undefined}
        onEngine={setMode}
        counting={
          layered
            ? { state, engine, within: withinField(within) }
            : { state: rowsState, engine: rowsByMeaning ? 'meaning' : 'keywords' }
        }
        boxFocus={boxFocus}
        held={
          held && direction
            ? {
                row: (
                  <HeldListRow
                    summary={heldRow}
                    swap={layer?.swap}
                    canSwap={!results.isFetching}
                    onSwap={() => layer?.swap && swapTheLayer(layer.swap)}
                    onLeave={leaveTheList}
                  />
                ),
                prompt: heldRow?.fieldPrompt ?? copy.searchLayer.prompt[direction],
              }
            : undefined
        }
        aids={
          keepsUserData && (
            <>
              <button
                type="button"
                // A search within a held list is not saved, as the app's is not: Save as Working Corpus keeps its results.
                title={held ? copy.searchLayer.saveSearchUnavailable : copy.savedSearches.saveHelp}
                disabled={(state.keywords ?? '').trim() === '' || held !== undefined}
                onClick={(event) => open('saveSearch', event.currentTarget)}
              >
                <span aria-hidden="true">☆ </span>
                {copy.savedSearches.save}
              </button>
              <button type="button" title={copy.savedSearches.openHelp} onClick={(event) => open('savedSearches', event.currentTarget)}>
                <span aria-hidden="true">★ </span>
                {copy.savedSearches.open}
              </button>
            </>
          )
        }
      />
      {keepsUserData && <CorpusBanner state={state} onLeave={() => update({ workingCorpusId: undefined })} />}
      {/* Mounted with the held list, so that what it says as the list is held, swapped or left is heard. */}
      {(held !== undefined || layerAnnouncement !== '') && (
        <p className="visually-hidden" role="status">
          {layerAnnouncement}
        </p>
      )}
      {state.keywords !== undefined && !held && !byMeaning && !searchesAnywhere(state) && (
        // As the Mac's window says it, rather than search nowhere.
        <p className="error" role="alert">
          {copy.search.emptyScope}
        </p>
      )}
      {(held !== undefined || (state.keywords !== undefined && (byMeaning ? asksMeaning : searchesAnywhere(state)))) && (
        <div className={panelOpen && !byMeaning && !held ? 'search-body with-facets' : 'search-body'}>
          <Results
            state={listState ?? state}
            titles={titles}
            userTags={userTags}
            results={results}
            byMeaning={rowsByMeaning && !layered}
            layer={layer}
            held={held !== undefined}
            offersFallback={offersMeaning && !held}
            onSearchLibrary={searchTheLibrary}
            onBack={leaveTheList}
            reviewed={reviewed}
            checklist={
              checklist.on
                ? {
                    announcement,
                    canMark,
                    canUndo: settled && [...checklist.marks.lastBulkBatch].some((key) => !checklist.readSinceEnabled.has(key)),
                    markOne: (key) => {
                      if (canMark) checklistStore.mark(key);
                    },
                    markPage: (keys) => {
                      if (!canMark) return;
                      setAnnouncement(copy.checklist.marked(checklistStore.markPage(keys)));
                    },
                    undo: () => {
                      const before = shown?.hidden;
                      setUndone({ before, rows: checklistStore.undo() });
                    },
                    // While the trail records nothing, an opened result stays, and the strip says so (S17f).
                    loggingNotice: logging ? undefined : copy.checklist.loggingOff,
                  }
                : undefined
            }
            actions={
              <>
                {/* Search Within These Results, titled by what it will do, as the app's command is: words found in a
                    Meaning list, or a keyword list or a browse ranked by a question, which needs the Meaning engine. */}
                {!held && shown && shown.total - (shown.hidden ?? 0) > 0 && (engine === 'meaning' || offersMeaning) && (
                  <button
                    type="button"
                    // Not while a search runs, whose rows are not yet the ones on screen.
                    disabled={results.isFetching}
                    title={
                      engine === 'keywords' && shown.total >= retainedLimit
                        ? copy.searchLayer.help.rankWholeMatch(retainedLimit)
                        : copy.searchLayer.help[engine === 'meaning' ? 'wordsInMatches' : 'rankByMeaning']
                    }
                    onClick={() => holdTheList(engine === 'meaning' ? 'wordsInMatches' : 'rankByMeaning')}
                  >
                    {copy.searchLayer.start[engine === 'meaning' ? 'wordsInMatches' : 'rankByMeaning']}
                  </button>
                )}
                {keepsUserData && (
                  <button
                    type="button"
                    title={copy.corpora.saveHelp}
                    disabled={!shown || shown.items.length === 0}
                    onClick={(event) => open('saveCorpus', event.currentTarget)}
                  >
                    {copy.corpora.save}
                  </button>
                )}
                <button
                  type="button"
                  aria-pressed={checklist.on}
                  title={checklist.on ? copy.checklist.offHelp : copy.checklist.onHelp}
                  aria-label={copy.checklist.toggleName}
                  onClick={() => {
                    setAnnouncement('');
                    checklistStore.setOn(!checklist.on, checklistState);
                  }}
                >
                  <span aria-hidden="true">☑ </span>
                  {copy.checklist.toggle}
                </button>
              </>
            }
            // Said only when the narrowing made the match smaller, as the Mac says it.
            narrowedFrom={
              panelOpen && shown && narrowed?.signature === signature && narrowed.from > shown.total ? narrowed.from : undefined
            }
            onReading={setReading}
            onTimelineMode={setTimelineMode}
            onAlign={setAlign}
            facets={
              // The facets count a keyword match, so they wait for Keywords, and for no list held.
              !byMeaning &&
              !held && (
                <button
                  type="button"
                  className="facets-toggle"
                  title={panelOpen ? copy.facets.hideHelp : copy.facets.toggleHelp}
                  aria-expanded={panelOpen}
                  aria-controls={panelOpen ? 'facet-panel' : undefined}
                  // Nothing to break down while nothing matches; an open panel can always be closed.
                  disabled={!panelOpen && !(results.data && results.data.total > 0)}
                  onClick={() => setPanel(!panelOpen)}
                >
                  {copy.facets.toggle}
                </button>
              )
            }
          />
          {panelOpen && !byMeaning && !held && <FacetPanel state={state} total={shown?.total} panel={facetPanel} onSearch={narrowTo} />}
        </div>
      )}
      {sheet === 'saveSearch' && <SaveSearchDialog state={state} onClose={closed} />}
      {sheet === 'savedSearches' && <SavedSearchesDialog onRecall={recall} onClose={closed} />}
      {sheet === 'saveCorpus' &&
        (layered ? (
          <SaveCorpusDialog state={state} reviewed={reviewed} engine={engine} within={withinField(within)} onClose={closed} />
        ) : (
          <SaveCorpusDialog state={rowsState} reviewed={reviewed} engine={rowsByMeaning ? 'meaning' : 'keywords'} onClose={closed} />
        ))}
    </section>
  );
}

/**
 * The search box, the filters and the Query Inspector's strip, which follows the box's text as it is
 * typed, before the search is made. The text is held here rather than by the screen, so a keystroke
 * renders these and not the results or the facet panel.
 */
function SearchEntry({
  state,
  titles,
  keepsUserData,
  userTags,
  update,
  onSearch,
  engine,
  onEngine,
  counting,
  boxFocus,
  held,
  aids,
}: {
  state: SearchState;
  titles: Map<string, string>;
  keepsUserData: boolean;
  /** The user's tags, while the server keeps user data and has given them. */
  userTags: UserTag[] | undefined;
  update: (changes: Partial<SearchState>) => void;
  onSearch: (keywords: string) => void;
  /** The engine the search runs through, where the server searches by meaning and offers the choice (S27d). */
  engine?: SearchMode;
  onEngine: (mode: SearchMode) => void;
  /** The rows My Tags counts over: the search's, a held list's own, or a layer's inside it (S27e). */
  counting: TagCounting;
  /** Changed to give the search box the focus, as holding a list does. */
  boxFocus: number;
  /** While a list is held (S27e): the row that names it, in Search by's place, and the field's prompt. */
  held?: { row: ReactNode; prompt: string };
  /** The controls beside the search box's aids: Save this search and Saved searches. */
  aids?: ReactNode;
}) {
  // A filter's token removes itself, so focus goes to the search box rather than nowhere.
  const searchBox = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (boxFocus > 0) searchBox.current?.focus();
  }, [boxFocus]);
  // Going to another search shows its text; the box is not remounted for it, so a search made from
  // it keeps its focus.
  const [text, setText] = useState(state.keywords ?? '');
  const [shownKeywords, setShownKeywords] = useState(state.keywords ?? '');
  if ((state.keywords ?? '') !== shownKeywords) {
    setShownKeywords(state.keywords ?? '');
    setText(state.keywords ?? '');
  }
  // Whether the strip shows its term detail, kept from search to search, as the Mac's window keeps it.
  const [inspectorExpanded, setInspectorExpanded] = useState(false);
  const byMeaning = engine === 'meaning';
  return (
    <>
      {/* While a list is held, the row that names it takes Search by's place: the field runs the other engine inside it. */}
      {held ? held.row : engine && <SearchBy mode={engine} onChange={onEngine} />}
      <SearchForm
        inputRef={searchBox}
        text={text}
        onTextChange={setText}
        onSubmit={onSearch}
        aids={aids}
        byMeaning={byMeaning}
        placeholder={held ? held.prompt : byMeaning ? copy.meaningSearch.placeholder : undefined}
      />
      <Filters
        state={state}
        titles={titles}
        keepsUserData={keepsUserData}
        userTags={userTags}
        update={update}
        onCleared={() => searchBox.current?.focus()}
        byMeaning={byMeaning}
        counting={counting}
      />
      {/* A search by meaning compiles no expression: its strip, with the results, takes the inspector's place. */}
      {!byMeaning && (
        <QueryInspectorStrip fields={inspectorFields(state, text)} expanded={inspectorExpanded} onExpandedChange={setInspectorExpanded} />
      )}
    </>
  );
}

function SearchForm({
  inputRef,
  text,
  onTextChange,
  onSubmit,
  aids,
  byMeaning,
  placeholder,
}: {
  inputRef: RefObject<HTMLInputElement | null>;
  /** The box's text, which the search entry holds. */
  text: string;
  onTextChange: (text: string) => void;
  onSubmit: (keywords: string) => void;
  aids?: ReactNode;
  /** Whether the search runs by meaning, whose tip says the syntax is the keywords'. */
  byMeaning: boolean;
  /** What the box asks for: a question in Meaning mode, and inside a held list words or a question for it. */
  placeholder?: string;
}) {
  const inputId = useId();

  function submit(event: FormEvent) {
    event.preventDefault();
    onSubmit(text);
  }

  return (
    <form role="search" onSubmit={submit} className="search-form">
      <label htmlFor={inputId}>{copy.search.label}</label>
      <div className="search-row">
        <input
          ref={inputRef}
          id={inputId}
          type="search"
          value={text}
          onChange={(event) => onTextChange(event.target.value)}
          placeholder={placeholder}
          spellCheck={false}
          autoCapitalize="off"
          autoComplete="off"
        />
        <button type="submit">{copy.search.submit}</button>
      </div>
      <div className="search-aids">
        <details className="syntax">
          <summary>{copy.search.syntax}</summary>
          <p>{byMeaning ? copy.meaningSearch.tip : copy.search.syntaxBody}</p>
        </details>
        {/* The other way to find a document, as the Mac's Search window offers it beside its Tips. */}
        <Link to="/lookup" className="find-by-citation" title={copy.lookup.findByCitationHelp}>
          {copy.lookup.findByCitation}
        </Link>
        {aids && <span className="saved-search-buttons">{aids}</span>}
      </div>
    </form>
  );
}

function Filters({
  state,
  titles,
  keepsUserData,
  userTags,
  update,
  onCleared,
  byMeaning,
  counting,
}: {
  state: SearchState;
  titles: Map<string, string>;
  keepsUserData: boolean;
  userTags: UserTag[] | undefined;
  update: (changes: Partial<SearchState>) => void;
  /** Called when a chip or a token has cleared its filter, and so removed itself. */
  onCleared: () => void;
  /** Whether the search runs by meaning, which reads none of Search in's places. */
  byMeaning: boolean;
  /** The rows My Tags counts over. */
  counting: TagCounting;
}) {
  // Search in has notes and summaries to choose only where the server keeps them; a scope a link
  // turned off is shown anywhere, so that it can be turned on again. A search by meaning reads none of
  // them, so the Mac's window offers none there, and neither does this.
  const showsSearchIn = !byMeaning && (keepsUserData || !scopes.every((scope) => searches(state, scope)));
  return (
    <fieldset className="filters">
      <legend>{copy.search.filters}</legend>
      {showsSearchIn && <SearchIn state={state} update={update} />}
      <label>
        {copy.search.documentType}{' '}
        <select
          value={state.documentType ?? 'all'}
          onChange={(event) => {
            const value = event.target.value as DocumentType;
            update({ documentType: value === 'all' ? undefined : value });
          }}
        >
          {documentTypes.map((type) => (
            <option key={type} value={type}>
              {copy.search.documentTypes[type]}
            </option>
          ))}
        </select>
      </label>
      <label>
        {copy.search.dateFrom}{' '}
        <input
          type="date"
          value={state.dateRangeEarliest ?? ''}
          onChange={(event) => update({ dateRangeEarliest: event.target.value || undefined })}
        />
      </label>
      <label>
        {copy.search.dateTo}{' '}
        <input
          type="date"
          value={state.dateRangeLatest ?? ''}
          onChange={(event) => update({ dateRangeLatest: event.target.value || undefined })}
        />
      </label>
      {(state.dateRangeEarliest || state.dateRangeLatest) && <p className="note">{copy.search.dateNote}</p>}
      <label>
        <input
          type="checkbox"
          checked={state.includeFrontMatter !== false}
          onChange={(event) => update({ includeFrontMatter: event.target.checked ? undefined : false })}
        />{' '}
        {copy.search.frontMatter}
      </label>
      {state.volumeIds && state.volumeIds.length > 0 && (
        <div className="chips" role="group" aria-label={copy.search.volumes}>
          {state.volumeIds.map((volumeId) => {
            const title = titles.get(volumeId) ?? volumeId;
            return (
              <button
                key={volumeId}
                type="button"
                className="chip"
                aria-label={copy.search.removeVolume(title)}
                onClick={() => {
                  const remaining = state.volumeIds?.filter((other) => other !== volumeId) ?? [];
                  update({ volumeIds: remaining.length > 0 ? remaining : undefined });
                  onCleared();
                }}
              >
                {title} ×
              </button>
            );
          })}
        </div>
      )}
      {userTags !== undefined && userTags.length > 0 && <MyTags state={state} tags={userTags} update={update} counting={counting} />}
      {keepsUserData && <ScopeFilter update={update} />}
      {keepsUserData && <CorpusFilter state={state} update={update} />}
      {(state.yearKeys ||
        state.personRollupId ||
        state.userTagIds ||
        state.subjectBucket ||
        state.subjectBucketKey ||
        state.phrase ||
        state.prefixWildcard ||
        state.excludedTerms) && (
        <div className="chips" role="group" aria-label={copy.search.narrowedBy}>
          {state.yearKeys && (
            <FilterToken
              field={copy.search.filterFields.years}
              value={copy.search.years(state.yearKeys)}
              onClear={() => {
                update({ yearKeys: undefined });
                onCleared();
              }}
            />
          )}
          {state.personRollupId && (
            <FilterToken
              field={copy.search.filterFields.person}
              value={state.personLabel ?? `#${state.personRollupId}`}
              onClear={() => {
                update({ personRollupId: undefined, personLabel: undefined });
                onCleared();
              }}
            />
          )}
          {state.userTagIds && (
            <FilterToken
              field={copy.search.filterFields.tags}
              value={tagFilterLabel(state.userTagIds, userTags)}
              onClear={() => {
                update({ userTagIds: undefined });
                onCleared();
              }}
            />
          )}
          {(state.subjectBucket || state.subjectBucketKey) && (
            <FilterToken
              field={copy.search.filterFields.subject}
              value={state.subjectLabel ?? state.subjectBucketKey ?? `#${state.subjectBucket}`}
              onClear={() => {
                update({ subjectBucket: undefined, subjectBucketKey: undefined, subjectLabel: undefined });
                onCleared();
              }}
            />
          )}
          {/* A recalled saved search's phrase, prefix and excluded terms, which the Mac's Advanced fields set. */}
          {state.phrase && (
            <FilterToken
              field={copy.search.filterFields.phrase}
              value={`“${state.phrase}”`}
              onClear={() => {
                update({ phrase: undefined });
                onCleared();
              }}
            />
          )}
          {state.prefixWildcard && (
            <FilterToken
              field={copy.search.filterFields.prefix}
              value={`${state.prefixWildcard}*`}
              onClear={() => {
                update({ prefixWildcard: undefined });
                onCleared();
              }}
            />
          )}
          {state.excludedTerms && (
            <FilterToken
              field={copy.search.filterFields.excluding}
              value={state.excludedTerms.join(', ')}
              onClear={() => {
                update({ excludedTerms: undefined });
                onCleared();
              }}
            />
          )}
        </div>
      )}
    </fieldset>
  );
}

/**
 * Search in, as the Mac's window offers it above its filters: Documents, Notes and Summaries, each a
 * chip that turns its place on or off, its state in its glyph as well as its colour (`ScopeChip`).
 */
function SearchIn({ state, update }: { state: SearchState; update: (changes: Partial<SearchState>) => void }) {
  const labelId = useId();
  return (
    <div className="search-in" role="group" aria-labelledby={labelId}>
      <span id={labelId}>{copy.search.searchIn}</span>
      {scopes.map((scope) => {
        const on = searches(state, scope);
        return (
          <button
            key={scope}
            type="button"
            className="scope-chip"
            aria-pressed={on}
            title={copy.search.scopeHelp[scope]}
            onClick={() => update(scopeChange(scope, !on))}
          >
            <span className="scope-glyph" aria-hidden="true">
              {on ? '✓' : '○'}
            </span>
            {copy.search.scopes[scope]}
          </button>
        );
      })}
    </div>
  );
}

/**
 * My Tags, as the Mac's filter lists them: a switch for each of the user's tags, every one switched
 * on a document must carry, and beside each how many of the results carry it, counted once the list
 * is opened, as the Mac counts them when its filter opens, never before.
 */
/**
 * The rows My Tags counts over: a search's, through its engine, as the Mac counts a Meaning list's keys (S27d), or a
 * layer's inside the list it ran within (S27e).
 */
interface TagCounting {
  state: SearchState;
  engine: SearchMode;
  within?: string;
}

function MyTags({
  state,
  tags: byName,
  update,
  counting,
}: {
  state: SearchState;
  tags: UserTag[];
  update: (changes: Partial<SearchState>) => void;
  counting: TagCounting;
}) {
  // In the reader's own order (S17f), as the app's My Tags filter lists them.
  const { tagOrder } = useListOrder();
  const tags = applyOrder(byName, tagOrder, (tag) => tag.id);
  const [open, setOpen] = useState(false);
  const asked = counting.state;
  const counted =
    open &&
    asked.keywords !== undefined &&
    (counting.engine === 'meaning' || counting.within !== undefined ? (asked.keywords ?? '').trim() !== '' : searchesAnywhere(asked));
  const counts = useQuery(searchTagsQuery(asked, counted, counting.engine, counting.within));
  const shown = counted && counts.data !== undefined && !counts.isError ? counts.data : undefined;
  const chosen = new Set(state.userTagIds ?? []);
  function toggle(id: string, on: boolean) {
    const next = on ? [...chosen, id] : [...chosen].filter((other) => other !== id);
    update({ userTagIds: next.length > 0 ? next : undefined });
  }
  return (
    <details className="my-tags" open={open} onToggle={(event) => setOpen(event.currentTarget.open)}>
      <summary>
        {copy.search.myTags} <span className="count">{copy.search.myTagsSummary(chosen.size)}</span>
      </summary>
      <ul>
        {tags.map((tag) => {
          const count = shown?.items.find((item) => item.id === tag.id)?.count;
          return (
            <li key={tag.id}>
              <label>
                <input
                  type="checkbox"
                  checked={chosen.has(tag.id)}
                  aria-label={count === undefined ? tag.name : copy.search.myTagCount(tag.name, count)}
                  onChange={(event) => toggle(tag.id, event.target.checked)}
                />{' '}
                {tag.name}
              </label>
              {count !== undefined && (
                <span className="count" aria-hidden="true">
                  {count.toLocaleString('en-US')}
                </span>
              )}
            </li>
          );
        })}
      </ul>
      {shown && <p className="caption">{copy.search.myTagsCountFooter}</p>}
    </details>
  );
}

/** A filter a facet set, by its field and value, as the Mac's token shows it; a click clears it. */
function FilterToken({ field, value, onClear }: { field: string; value: string; onClear: () => void }) {
  return (
    <button type="button" className="chip" aria-label={`${field} ${value}, ${copy.search.clearThisFilter}`} onClick={onClear}>
      <span className="chip-field">{field}</span> {value} <span aria-hidden="true">×</span>
    </button>
  );
}

/** What the results need of Checklist Mode while it is on. */
interface ChecklistControls {
  announcement: string;
  /** Whether a mark can be made of the rows on screen: they are the search the checklist is anchored to. */
  canMark: boolean;
  canUndo: boolean;
  markOne: (key: string) => void;
  markPage: (keys: string[]) => void;
  undo: () => void;
  /** The Mac's line while Log Research Sessions is off (`ChecklistLoggingNotice`). */
  loggingNotice?: string;
}

function Results({
  state,
  titles,
  userTags,
  results,
  byMeaning,
  layer,
  held,
  offersFallback,
  onSearchLibrary,
  onBack,
  narrowedFrom,
  onReading,
  onTimelineMode,
  onAlign,
  facets,
  actions,
  checklist,
  reviewed,
}: {
  state: SearchState;
  titles: Map<string, string>;
  userTags: UserTag[] | undefined;
  results: UseQueryResult<SearchResultList, unknown>;
  /** Whether the rows are a search by meaning's, a `MeaningSearchResult` with the run's account (S27d). */
  byMeaning: boolean;
  /** A layer's account, when the rows are a layer's inside a held list (S27e). */
  layer: LayerSummary | undefined;
  /** Whether a list is held, inside which the readings, which read a keyword match, wait. */
  held: boolean;
  /** Whether a keyword search that found nothing offers the nearest by meaning, as the app's fallback does (S27e). */
  offersFallback: boolean;
  /** A layer that found nothing: its words searched across the whole library, or the way back to the list. */
  onSearchLibrary: () => void;
  onBack: () => void;
  /** The count the last facet narrowed from, while the panel shows it. */
  narrowedFrom: number | undefined;
  onReading: (reading: Reading) => void;
  onTimelineMode: (mode: TimelineMode) => void;
  onAlign: (order: ConcordanceOrder) => void;
  /** The control that opens the facet panel. */
  facets: ReactNode;
  /** Save as Working Corpus… and Checklist, beside the readings. */
  actions: ReactNode;
  /** Checklist Mode's controls, while it is on. */
  checklist: ChecklistControls | undefined;
  /** The results it hides, which the readings leave out too. */
  reviewed: readonly string[];
}) {
  // The last page stays on screen while the next loads, so the pager keeps its focus and the
  // count stays one live region.
  const list = results.data;
  const failed = results.isError && !results.isFetching;
  const error = results.error;
  const first = list && list.items.length > 0 ? list.offset + 1 : 0;
  const last = list ? list.offset + list.items.length : 0;
  // A search by meaning's account of its run, and its rows read as a list alone: the readings read a keyword match.
  const meaning = byMeaning ? (list as MeaningSearchResult | undefined)?.meaning : undefined;
  const reading: Reading = byMeaning || held ? 'list' : (state.reading ?? 'list');
  // A row marked reviewed leaves the list once the page has loaded again, and its button with it: the
  // focus goes to the Mark Reviewed of the row that takes its place, or past the last to Mark Page Reviewed.
  const listElement = useRef<HTMLOListElement>(null);
  const focusAfterMark = useRef<number | null>(null);
  useEffect(() => {
    const index = focusAfterMark.current;
    if (index === null || results.isFetching || results.isPlaceholderData) return;
    focusAfterMark.current = null;
    const buttons = listElement.current?.querySelectorAll<HTMLButtonElement>('button.mark-reviewed') ?? [];
    (buttons[index] ?? document.querySelector<HTMLButtonElement>('.checklist-strip button[data-mark-page]'))?.focus();
  }, [list, results.isFetching, results.isPlaceholderData]);
  const hidden = list?.hidden ?? 0;
  // What the pages reach: the results kept, less those Checklist Mode hides.
  const shownTotal = list ? Math.max(0, Math.min(list.total, retainedLimit) - hidden) : 0;
  return (
    <section className="results" aria-labelledby="results-heading" aria-busy={results.isFetching}>
      <h2 id="results-heading" className="visually-hidden">
        {copy.search.results}
      </h2>
      {meaning && !failed && <MeaningStrip strip={meaning.strip} />}
      {/* A ranking's account, in the Meaning strip's sentences, of the list it ranked (S27e). */}
      {layer?.strip && !failed && <MeaningStrip strip={layer.strip} />}
      <div className="results-header">
        <p className="count" role="status">
          {failed ? '' : list ? (
            <>
              {/* A search by meaning's list is the shape of its answer, the closest matches, not a count of a match;
                  one that listed no row says the heading over its matches beyond the library, where it found some, as
                  the app's finished search says it (A11Y-2). */}
              {/* A layer's header is the app's sentence for it: what its words or question kept of the list (S27e). */}
              {layer
                ? layer.header
                : meaning
                  ? list.total === 0
                    ? (meaning.beyondHeader ?? copy.meaningSearch.noResults)
                    : copy.meaningSearch.closest(Math.max(0, list.total - hidden))
                  : copy.search.count(list.total, list.countBasis)}
              {narrowedFrom !== undefined && <> · {copy.search.narrowedFrom(narrowedFrom)}</>}
              {list.items.length > 0 && <> · {copy.search.showing(first, last)}</>} ·{' '}
              {copy.search.coverage(list.coverage.indexedVolumes, list.coverage.manifestVolumes)}
            </>
          ) : (
            copy.search.searching
          )}
        </p>
        {list && !failed && <SortOrders state={state} list={list} />}
        {/* Each reading reads what a search found, so the picker waits for a match, as the Mac's does, and for
            Keywords, as the readings read a keyword match. */}
        {list && !failed && !byMeaning && !held && <ReadingPicker reading={reading} disabled={list.total === 0} onChange={onReading} />}
        {actions}
        {facets}
      </div>
      {checklist && (
        <ChecklistStrip
          hiddenCount={hidden}
          // Both act on a page: the timeline has none.
          pageRowCount={list && !failed && isPaged(reading) && checklist.canMark ? list.items.length : 0}
          canUndo={isPaged(reading) && checklist.canUndo}
          announcement={checklist.announcement}
          onMarkPage={() => checklist.markPage((list?.items ?? []).map((item) => reviewedKey(item.volumeId, item.documentId)))}
          onUndo={checklist.undo}
          loggingNotice={checklist.loggingNotice}
        />
      )}
      {list && !failed && !layer && isPartialEvidence(list.total) && (
        // As the Mac's window says it on every page: an order, a page or a reading of what a search
        // keeps is of its most relevant 7,500, not of the whole match.
        <div className="over-cap">
          <p>
            <span className="over-cap-mark" aria-hidden="true">
              ⚠{' '}
            </span>
            {copy.search.overCap(Math.min(list.total, retainedLimit), list.total)}
          </p>
          <p className="caption">{copy.search.overCapGuidance}</p>
        </div>
      )}
      {failed && (
        <p className="error" role="alert">
          {error instanceof ApiError
            ? error.code === 'INDEX_NOT_READY'
              ? copy.search.notReady(error.problem?.detail ?? '')
              : error.message
            : String(error)}
        </p>
      )}
      {list && !failed && (
        <>
          {checklist && list.total > 0 && hidden > 0 && shownTotal === 0 ? (
            // Checklist Mode has hidden every result, as the Mac's window says.
            <div className="empty">
              <h3>{copy.checklist.allReviewedTitle}</h3>
              <p>{copy.checklist.allReviewedDetail}</p>
            </div>
          ) : list.items.length === 0 && list.total === 0 ? (
            // A search that found nothing says so in any reading, as the Mac's window does; a search by meaning in its
            // own words, never blaming a term (S27d); a layer what it looked in, with its ways on (S27e).
            results.isPlaceholderData ? null : layer?.empty ? (
              <LayerEmpty empty={layer.empty} onSearchLibrary={onSearchLibrary} onBack={onBack} />
            ) : meaning ? (
              <MeaningEmpty meaning={meaning} />
            ) : (state.keywords ?? '').trim() !== '' ? (
              // Only once the search shown is this one, as the Mac's window waits for its search; under the account of
              // the terms that found nothing, the nearest by meaning, as the app's fallback offers them (S27e).
              <>
                <ZeroResult state={state} />
                {offersFallback && <MeaningFallback state={state} />}
              </>
            ) : (
              <p>{copy.search.none}</p>
            )
          ) : reading === 'timeline' ? (
            <TimelineReading
              state={state}
              titles={titles}
              mode={state.timelineMode ?? 'chart'}
              onMode={onTimelineMode}
              reviewed={reviewed}
              total={list.total}
            />
          ) : list.items.length === 0 ? (
            <p>{copy.search.pastEnd}</p>
          ) : reading === 'concordance' ? (
            <ConcordanceReading state={state} total={list.total} order={state.align ?? 'leftContext'} onOrder={onAlign} reviewed={reviewed} />
          ) : (
            <ol ref={listElement} className="result-list" aria-label={copy.search.results} start={first}>
              {list.items.map((item, index) => (
                <li key={`${item.volumeId}/${item.documentId}`} className="result">
                  {/* A ranking's rows it could not rank follow the ranked ones, under the line that counts them (S27e). */}
                  {layer?.unrankedTail?.firstKey === `${item.volumeId}/${item.documentId}` && (
                    <p className="unranked-line">{layer.unrankedTail.line}</p>
                  )}
                  <h3>
                    <Link to="/doc/$volumeId/$documentId" params={{ volumeId: item.volumeId, documentId: item.documentId }}>
                      {item.displayTitle}
                    </Link>
                  </h3>
                  <p className="meta">
                    {titles.get(item.volumeId) ?? item.volumeId}
                    {!item.headerRepeatsNumber && <> · {item.documentLabel}</>}
                    {/* Its dateline, or for a row that prints none the day or span the index dates
                        it by, as the Mac's window draws `dateline ?? drawnDate`. */}
                    {(item.dateline ?? item.drawnDate) && <> · {item.dateline ?? item.drawnDate}</>}
                    {item.isEditorialNote && <Badge>{copy.search.editorialNote}</Badge>}
                    {item.isFrontMatter && <Badge>{copy.search.frontMatterBadge}</Badge>}
                  </p>
                  <p className="snippet">
                    <Snippet text={item.snippet} />
                  </p>
                  {/* A row ranked by meaning says its score, the kit's chip (S27d). */}
                  {item.chip && <p className="semantic-chip">{item.chip}</p>}
                  <RowTags tagIds={item.userTagIds} tags={userTags} />
                  {checklist && (
                    // Hides the result without opening it, as the Mac's row menu offers while the mode is on.
                    <button
                      type="button"
                      className="mark-reviewed"
                      aria-label={`${copy.checklist.markReviewed}: ${item.displayTitle}`}
                      // Not while another search's rows are on screen: the mark would be kept under the next.
                      disabled={!checklist.canMark}
                      onClick={() => {
                        focusAfterMark.current = index;
                        checklist.markOne(reviewedKey(item.volumeId, item.documentId));
                      }}
                    >
                      {copy.checklist.markReviewed}
                    </button>
                  )}
                </li>
              ))}
            </ol>
          )}
          {/* The timeline covers every result the search keeps, so it has no page to turn. */}
          {isPaged(reading) && <Pager state={state} list={list} shownTotal={shownTotal} />}
          {/* A search by meaning's hits in volumes this server does not serve, apart under the rows (S27d). */}
          {meaning && !results.isPlaceholderData && <MeaningBeyond meaning={meaning} />}
        </>
      )}
    </section>
  );
}

/** A row's tags, as the Mac's row draws its first three ◆ chips, for the ids the user's tags name. */
function RowTags({ tagIds, tags }: { tagIds: string[]; tags: UserTag[] | undefined }) {
  const chips = tags ? tagChips(tagIds, tags).slice(0, rowChipLimit) : [];
  if (chips.length === 0) return null;
  return (
    <ul className="row-tags" aria-label={copy.search.rowTags}>
      {chips.map((tag) => (
        <li key={tag.id}>
          <span aria-hidden="true">◆ </span>
          {tag.name}
        </li>
      ))}
    </ul>
  );
}

/**
 * The orders the results can be read in, as the Mac's sort bar offers them, by the kit's labels: a
 * click starts the order at its first page. The pressed order is the reader's choice, which the
 * page on screen follows once it has loaded.
 */
function SortOrders({ state, list }: { state: SearchState; list: SearchResultList }) {
  const navigate = route.useNavigate();
  const labelId = useId();
  const chosen: SortOrder = state.sort ?? 'relevance';
  return (
    <div className="sort-orders" role="group" aria-labelledby={labelId}>
      <span id={labelId}>{copy.search.sort}</span>
      {list.sortChoices.map((choice) => (
        <button
          key={choice.value}
          type="button"
          aria-pressed={choice.value === chosen}
          title={copy.search.sortHelp[choice.value]}
          onClick={() => {
            const sort = choice.value === 'dateAscending' || choice.value === 'dateDescending' ? choice.value : undefined;
            void navigate({ search: (previous: SearchState) => ({ ...previous, sort, offset: undefined }) });
          }}
        >
          {choice.title}
        </button>
      ))}
    </div>
  );
}

function Pager({ state, list, shownTotal }: { state: SearchState; list: SearchResultList; shownTotal: number }) {
  const navigate = route.useNavigate();
  const limit = state.limit ?? defaultLimit;
  // Over what the pages reach, which Checklist Mode makes fewer than the results kept.
  const pages = pageCount(list.hidden !== undefined ? shownTotal : list.total, limit);
  // An offset past the last result, from an edited URL or a changed index, counts as past the
  // last page, and Previous goes to the last page.
  const page = Math.floor(list.offset / limit) + 1;
  const go = (offset: number) =>
    void navigate({ search: (previous: SearchState) => ({ ...previous, offset: offset > 0 ? offset : undefined }) });
  return (
    <nav className="pager" aria-label={copy.search.pages}>
      <button type="button" disabled={page <= 1} onClick={() => go(Math.min(list.offset - limit, (pages - 1) * limit))}>
        {copy.search.previous}
      </button>
      <span aria-current="page">{page <= pages ? copy.search.page(page, pages) : copy.search.pageCount(pages)}</span>
      <button type="button" disabled={page >= pages} onClick={() => go(list.offset + limit)}>
        {copy.search.next}
      </button>
      <label>
        {copy.search.pageSize}{' '}
        <select
          value={limit}
          onChange={(event) => {
            const next = Number(event.target.value);
            void navigate({
              search: (previous: SearchState) => ({ ...previous, limit: next === defaultLimit ? undefined : next, offset: undefined }),
            });
          }}
        >
          {pageSizes.map((size) => (
            <option key={size} value={size}>
              {size}
            </option>
          ))}
        </select>
      </label>
    </nav>
  );
}
