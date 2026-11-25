// Search Within These Results and the fallback in the browser app (S27e): a keyword list held and ranked by a question,
// under the row that names it in Search by's place, with Swap and its way back; a Meaning list held and searched for
// words, whose empty layer offers the whole library and the way back; no ranking offered where the server does not
// search by meaning; a layer recorded in the trail with its list, the list's anchor set aside and given back; a layer
// saved as a working corpus with its list; and the Semantic matches (experimental) under a keyword search that found
// nothing.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { MeaningSearchResult, ServerStatus } from '../api/meaning';
import type { HeldListSummary, LayeredSearchResult, MeaningFallback } from '../api/searchWithin';
import type { SearchItem, SearchResultList } from '../api/types';
import { sent } from '../test/notes';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';
import { checklistStore } from './checklist';
import { resetHeldLists } from './heldLists';
import { resetSearchHistory } from './searchHistory';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  checklistStore.reset();
  resetSearchHistory();
  resetHeldLists();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };

function status(searchByMeaning: boolean): ServerStatus {
  return {
    version: 'test',
    semantic: {
      vectors: true,
      generation: '89481b18',
      shardsHeld: 553,
      shardsPublished: 553,
      map: true,
      encoder: searchByMeaning,
      relatedDocuments: true,
      searchByMeaning,
    },
  };
}

function item(documentId: string, displayTitle: string, fields: Partial<SearchItem> = {}): SearchItem {
  return {
    volumeId: 'frus1961-63v06',
    documentId,
    header: displayTitle,
    displayTitle,
    documentLabel: documentId,
    headerRepeatsNumber: false,
    snippet: 'the <b>treaties</b>',
    bm25Score: -1,
    isEditorialNote: false,
    isFrontMatter: false,
    subjectTagIds: [],
    userTagIds: [],
    ...fields,
  };
}

function list(items: SearchItem[]): SearchResultList {
  return { total: items.length, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, coverage, items };
}

const keywordRows = [item('d1', 'Telegram From the Embassy'), item('d2', 'Memorandum of Conversation')];

const disclosure = {
  unscoredCandidates: 0,
  unscoredVolumes: 0,
  downloadingVolumes: 0,
  filtersApplied: false,
  filteredOut: 0,
  beyondUncheckedByFilters: false,
  withoutVector: 1,
  notIndexedHere: 0,
  rankedWithin: 2,
  rankedCount: 1,
};

function held(fields: Partial<HeldListSummary> = {}): HeldListSummary {
  return {
    direction: 'rankByMeaning',
    kind: 'keywords',
    query: 'treaties',
    rows: 2,
    members: 2,
    hiddenByChecklist: 0,
    notDownloaded: 0,
    wasCut: false,
    ranksWholeMatch: false,
    setDescription: '2 results for “treaties”',
    rowDescription: 'Within 2 results for “treaties”',
    accessibilityLabel: 'Searching within 2 results for “treaties”',
    backTitle: 'Back to the 2 Results',
    captureLabel: '“treaties”',
    startTitle: 'Rank These Results by a Question',
    fieldPrompt: 'A question to rank these results by…',
    signaturePart: 'base=keywords:2:treaties',
    memberDigest: 'abc',
    ...fields,
  };
}

const ranked: LayeredSearchResult = {
  ...list([
    item('d2', 'Memorandum of Conversation', { semanticScore: 0.61, chip: 'Semantic match · 61%', bm25Score: -0.61 }),
    item('d1', 'Telegram From the Embassy'),
  ]),
  layer: {
    direction: 'rankByMeaning',
    query: 'the Soviet note on Berlin',
    route: { kind: 'rankedByMeaning', unranked: 1 },
    header: '2 results · 1 ranked · 1 not ranked',
    filtersNarrowed: false,
    unrankedTail: { firstKey: 'frus1961-63v06/d1', count: 1, line: '1 result not ranked by meaning' },
    strip: [
      'Meaning search (experimental): ranked by what your question means, inside the 2 documents you are searching within — your exact words may not appear. Front matter and chapter headings are not reachable this way.',
    ],
    disclosure,
    swap: {
      direction: 'wordsInMatches',
      listQuery: 'the Soviet note on Berlin',
      layerQuery: 'treaties',
      help: 'Ask “the Soviet note on Berlin” first, then find “treaties” among its closest matches',
    },
    renderedExpression: 'route=semantic; model=embeddinggemma-2-Q8_0; ranked=2; base=keywords:2:treaties',
    signature: 'route=semantic;engine=on-device;docs=2/abc;base=keywords:2:treaties',
    base: held(),
  },
};

const server = (answers: Record<string, unknown>) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/search/inspect': { inspection: undefined },
    '/api/v1/search': list(keywordRows),
    '/api/v1/status': status(true),
    '/api/v1/search/held': held(),
    '/api/v1/search/within': ranked,
    ...answers,
  });

const calls = (fetch: ReturnType<typeof stubServer>, method: string, path: string) =>
  fetch.mock.calls.filter(([url, init]) => (init?.method ?? 'GET') === method && String(url).split('?')[0] === path);

const query = (url: unknown) => new URL(String(url), 'http://localhost').searchParams;

describe('search within these results', () => {
  it('holds a keyword list and ranks it by a question, under the row that names it, and leaves it', async () => {
    const fetch = server({});
    const { router } = renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    const hold = screen.getByRole('button', { name: 'Rank These Results by a Question' });
    expect(hold.getAttribute('title')).toBe('Rank these results by a question. Every result stays listed, the closest first.');
    await userEvent.click(hold);
    // The list held: its row in Search by's place, the field empty and asking for a question, the list's rows still shown.
    const row = await screen.findByRole('region', { name: 'Searching within 2 results for “treaties”' });
    expect(within(row).getByText('Within 2 results for “treaties”')).toBeTruthy();
    expect(screen.queryByRole('group', { name: 'Search by' })).toBeNull();
    const box = screen.getByRole('searchbox', { name: 'Search the documents' });
    expect(box.getAttribute('placeholder')).toBe('A question to rank these results by…');
    await waitFor(() => expect(document.activeElement).toBe(box));
    expect(router.state.location.search).toMatchObject({ within: 'keywords=treaties', by: 'meaning' });
    expect(screen.getByRole('link', { name: 'Telegram From the Embassy' })).toBeTruthy();
    expect(calls(fetch, 'GET', '/api/v1/search/within')).toHaveLength(0);
    expect(await screen.findByText('Searching within 2 results for “treaties”', { selector: '.visually-hidden' })).toBeTruthy();

    // A question ranks it: the layer's header, its strip, the chip, and the line over the row it could not rank.
    await userEvent.type(box, 'the Soviet note on Berlin{Enter}');
    await screen.findByText('2 results · 1 ranked · 1 not ranked', { exact: false });
    const asked = query(calls(fetch, 'GET', '/api/v1/search/within')[0]![0]);
    expect(asked.get('keywords')).toBe('the Soviet note on Berlin');
    expect(asked.get('within')).toBe('keywords=treaties&members=abc');
    expect(screen.getByRole('region', { name: 'About this Meaning search' }).textContent).toContain('inside the 2 documents you are searching within');
    const results = within(screen.getByRole('list', { name: 'Results' }));
    expect(results.getByText('Semantic match · 61%')).toBeTruthy();
    expect(results.getByText('1 result not ranked by meaning')).toBeTruthy();
    const swap = within(row).getByRole('button', { name: 'Swap the two searches' });
    expect(swap.getAttribute('title')).toBe('Ask “the Soviet note on Berlin” first, then find “treaties” among its closest matches');

    // Leaving it shows the list again, as it was.
    await userEvent.click(within(row).getByRole('button', { name: 'Stop searching within these results' }));
    await waitFor(() => expect(router.state.location.search.within).toBeUndefined());
    expect(router.state.location.search).toMatchObject({ keywords: 'treaties' });
    expect(router.state.location.search.by).toBeUndefined();
    expect(await screen.findByRole('group', { name: 'Search by' })).toBeTruthy();
    expect(screen.getByText('Stopped searching within these results', { selector: '.visually-hidden' })).toBeTruthy();
  });

  it('holds a Meaning list and finds words in it; a layer that finds nothing offers the whole library and the way back', async () => {
    const meaningList: MeaningSearchResult = {
      ...list([item('d1', 'Telegram From the Embassy', { semanticScore: 0.64, chip: 'Semantic match · 64%' })]),
      retainedLimit: 100,
      meaning: {
        question: 'Berlin',
        strip: ['Meaning search (experimental)'],
        emptyStatement: '',
        disclosure,
        beyondLibrary: [],
        missingShards: [],
        renderedExpression: 'route=semantic; model=m; top=100',
        signature: 'route=semantic;engine=on-device',
      },
    };
    const empty: LayeredSearchResult = {
      ...list([]),
      layer: {
        direction: 'wordsInMatches',
        query: 'zeppelin',
        route: { kind: 'wordsInMatches', base: 1 },
        header: 'Your closest match does not contain these words',
        filtersNarrowed: false,
        empty: {
          statement: 'Your closest match does not contain these words',
          searchLibraryTitle: 'Search the Whole Library for These Words',
          backTitle: 'Back to the Closest Match',
        },
        signature: 'mode=and;base=meaning:1:Berlin',
        base: held({
          direction: 'wordsInMatches',
          kind: 'meaning',
          query: 'Berlin',
          rows: 1,
          members: 1,
          setDescription: 'the closest match to “Berlin”',
          rowDescription: 'Within the closest match to “Berlin”',
          accessibilityLabel: 'Searching within the closest match to “Berlin”',
          backTitle: 'Back to the Closest Match',
          startTitle: 'Find Words in These Matches',
          fieldPrompt: 'Words to find in these matches…',
          signaturePart: 'base=meaning:1:Berlin',
        }),
      },
    };
    const fetch = server({
      '/api/v1/search/meaning': meaningList,
      '/api/v1/search/held': empty.layer.base,
      '/api/v1/search/within': empty,
    });
    const { router } = renderAt('/search?keywords=Berlin&by=meaning');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    const hold = screen.getByRole('button', { name: 'Find Words in These Matches' });
    expect(hold.getAttribute('title')).toBe(
      'Find words in these closest matches. They keep their order, and only those that contain your words stay listed.',
    );
    await userEvent.click(hold);
    await screen.findByRole('region', { name: 'Searching within the closest match to “Berlin”' });
    expect(router.state.location.search).toMatchObject({ within: 'keywords=Berlin&by=meaning' });
    expect(router.state.location.search.by).toBeUndefined();
    const box = screen.getByRole('searchbox', { name: 'Search the documents' });
    expect(box.getAttribute('placeholder')).toBe('Words to find in these matches…');
    await userEvent.type(box, 'zeppelin{Enter}');
    expect(await screen.findByRole('heading', { name: 'Your closest match does not contain these words' })).toBeTruthy();
    // Neither the keyword zero-state nor the fallback inside a held list.
    expect(screen.queryByRole('region', { name: 'Semantic matches (experimental)' })).toBeNull();
    expect(screen.getByRole('button', { name: 'Back to the Closest Match' })).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Search the Whole Library for These Words' }));
    await waitFor(() => expect(router.state.location.search.within).toBeUndefined());
    expect(router.state.location.search).toMatchObject({ keywords: 'zeppelin' });
    expect(router.state.location.search.by).toBeUndefined();
    await waitFor(() => expect(calls(fetch, 'GET', '/api/v1/search').length).toBeGreaterThan(0));
  });

  it('offers no ranking where the server does not search by meaning', async () => {
    server({ '/api/v1/status': status(false) });
    renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    expect(screen.queryByRole('button', { name: 'Rank These Results by a Question' })).toBeNull();
  });

  it('records a layer with its list, the list’s anchor set aside and given back, and saves a layer with its list', async () => {
    const bodies: unknown[] = [];
    const fetch = server({
      '/api/v1/me': me,
      '/api/v1/me/tags': { items: [] },
      'POST /api/v1/me/history/searches': (_: URL, init?: RequestInit) => {
        const body = sent(init).body as { search: string };
        bodies.push(body);
        return { outcome: 'inserted', anchor: { entryId: `R${bodies.length}`, queryText: body.search } };
      },
      'POST /api/v1/me/working-corpora/capture': {
        documentCount: 2,
        sourceQuery: 'the Soviet note on Berlin',
        narrowing: [],
        indexedVolumeCount: 3,
        sourceDescription: 'Search results for “treaties”, ranked by a question',
        wasTruncated: false,
        totalMatchCount: 2,
      },
    });
    const { router } = renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await waitFor(() => expect(bodies).toHaveLength(1));
    expect(bodies[0]).toEqual({ search: 'keywords=treaties' });
    await userEvent.click(screen.getByRole('button', { name: 'Rank These Results by a Question' }));
    const box = await screen.findByRole('searchbox', { name: 'Search the documents' });
    expect((screen.getByRole('button', { name: 'Save this search' }) as HTMLButtonElement).disabled).toBe(true);
    await userEvent.type(box, 'the Soviet note on Berlin{Enter}');
    await screen.findByText('2 results · 1 ranked · 1 not ranked', { exact: false });
    await waitFor(() => expect(bodies).toHaveLength(2));
    // The layer's own row, with no anchor: the list's was set aside.
    expect(bodies[1]).toEqual({ search: 'keywords=the+Soviet+note+on+Berlin', mode: 'meaning', within: 'keywords=treaties&members=abc' });

    await userEvent.click(screen.getByRole('button', { name: 'Save as Working Corpus…' }));
    const dialog = await screen.findByRole('dialog', { name: 'Save Working Corpus' });
    await waitFor(() => expect(calls(fetch, 'POST', '/api/v1/me/working-corpora/capture')).toHaveLength(1));
    expect(sent(calls(fetch, 'POST', '/api/v1/me/working-corpora/capture')[0]![1]).body).toEqual({
      search: 'keywords=the+Soviet+note+on+Berlin',
      reviewed: [],
      mode: 'meaning',
      within: 'keywords=treaties&members=abc',
    });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Cancel' }));

    // Left, the list's rows come back from what the screen holds, and its run is not recorded again.
    await userEvent.click(screen.getByRole('button', { name: 'Stop searching within these results' }));
    await waitFor(() => expect(router.state.location.search.within).toBeUndefined());
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(bodies).toHaveLength(2);
    // Its anchor came back: the same words under another filter refresh the list's own row.
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Document type' }), 'documentsOnly');
    await waitFor(() => expect(bodies).toHaveLength(3));
    expect(bodies[2]).toEqual({ search: 'keywords=treaties&documentType=documentsOnly', anchor: { entryId: 'R1', queryText: 'keywords=treaties' } });
  });

  it('gives the list’s anchor back when Back leaves it, and sets it aside only once the list’s own record has answered', async () => {
    const bodies: unknown[] = [];
    let answerFirst: () => void = () => {};
    const first = new Promise<void>((resolve) => {
      answerFirst = resolve;
    });
    server({
      '/api/v1/me': me,
      '/api/v1/me/tags': { items: [] },
      'POST /api/v1/me/history/searches': async (_: URL, init?: RequestInit) => {
        const body = sent(init).body as { search: string };
        bodies.push(body);
        const number = bodies.length;
        // The list's own record answers only after the list is held.
        if (number === 1) await first;
        return { outcome: 'inserted', anchor: { entryId: `R${number}`, queryText: body.search } };
      },
    });
    const { router } = renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await waitFor(() => expect(bodies).toHaveLength(1));
    await userEvent.click(screen.getByRole('button', { name: 'Rank These Results by a Question' }));
    await userEvent.type(await screen.findByRole('searchbox', { name: 'Search the documents' }), 'the Soviet note on Berlin{Enter}');
    await screen.findByText('2 results · 1 ranked · 1 not ranked', { exact: false });
    answerFirst();
    await waitFor(() => expect(bodies).toHaveLength(2));
    // The layer's row has none: the list's anchor was set aside with it once its record answered.
    expect(bodies[1]).toEqual({ search: 'keywords=the+Soviet+note+on+Berlin', mode: 'meaning', within: 'keywords=treaties&members=abc' });
    // Back twice: to the list held with its field empty, then out of it.
    router.history.back();
    await waitFor(() => expect(router.state.location.search.keywords).toBeUndefined());
    router.history.back();
    await waitFor(() => expect(router.state.location.search.within).toBeUndefined());
    await screen.findByRole('group', { name: 'Search by' });
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(bodies).toHaveLength(2);
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Document type' }), 'documentsOnly');
    await waitFor(() => expect(bodies).toHaveLength(3));
    expect(bodies[2]).toEqual({ search: 'keywords=treaties&documentType=documentsOnly', anchor: { entryId: 'R1', queryText: 'keywords=treaties' } });
  });

  it('lets go of a list the server built again with other documents', async () => {
    const changed = { status: 409, code: 'HELD_LIST_CHANGED', detail: 'The list you were searching within holds other documents now, since its search was run again; search it again to hold it.' };
    server({
      '/api/v1/search/within': new ProblemAnswer(changed.status, changed.code, changed.detail),
    });
    const { router } = renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await userEvent.click(screen.getByRole('button', { name: 'Rank These Results by a Question' }));
    await userEvent.type(await screen.findByRole('searchbox', { name: 'Search the documents' }), 'the Soviet note on Berlin{Enter}');
    await waitFor(() => expect(router.state.location.search.within).toBeUndefined());
    expect(router.state.location.search).toMatchObject({ keywords: 'treaties' });
    expect(screen.getByText(changed.detail, { selector: '.visually-hidden' })).toBeTruthy();
  });

  it('recalls a saved search through the list’s own engine, letting go of the list', async () => {
    server({
      '/api/v1/me': me,
      '/api/v1/me/tags': { items: [] },
      'POST /api/v1/me/history/searches': { outcome: 'inserted', anchor: { entryId: 'R1', queryText: 'q' } },
      '/api/v1/me/saved-searches': {
        items: [{ id: 'S1', name: 'Berlin wall', queryText: 'Berlin wall', search: { keywords: ['Berlin wall'] }, notRecalled: [] }],
      },
    });
    const { router } = renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await userEvent.click(screen.getByRole('button', { name: 'Rank These Results by a Question' }));
    await screen.findByRole('searchbox', { name: 'Search the documents' });
    expect(router.state.location.search).toMatchObject({ by: 'meaning' });
    await userEvent.click(screen.getByRole('button', { name: 'Saved searches' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved Searches' });
    // The row's own button recalls it; its Rename and Delete follow it.
    await userEvent.click((await within(dialog).findAllByRole('button', { name: /Berlin wall/ }))[0]!);
    await waitFor(() => expect(router.state.location.search).toMatchObject({ keywords: 'Berlin wall' }));
    expect(router.state.location.search.within).toBeUndefined();
    expect(router.state.location.search.by).toBeUndefined();
  });

  it('swaps the list and the layer: the layer’s words become a list of their own, and the list’s run inside it', async () => {
    const bodies: unknown[] = [];
    server({
      '/api/v1/me': me,
      '/api/v1/me/tags': { items: [] },
      'POST /api/v1/me/history/searches': (_: URL, init?: RequestInit) => {
        bodies.push(sent(init).body);
        return { outcome: 'inserted', anchor: { entryId: `R${bodies.length}`, queryText: 'q' } };
      },
    });
    const { router } = renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await userEvent.click(screen.getByRole('button', { name: 'Rank These Results by a Question' }));
    await userEvent.type(await screen.findByRole('searchbox', { name: 'Search the documents' }), 'the Soviet note on Berlin{Enter}');
    await screen.findByText('2 results · 1 ranked · 1 not ranked', { exact: false });
    await userEvent.click(screen.getByRole('button', { name: 'Swap the two searches' }));
    await waitFor(() => expect(router.state.location.search).toMatchObject({ keywords: 'treaties' }));
    expect(router.state.location.search).toMatchObject({ within: 'keywords=the+Soviet+note+on+Berlin&by=meaning' });
    expect(router.state.location.search.by).toBeUndefined();
    // The new list's own search is recorded as a search of its own, with no anchor.
    await waitFor(() => expect(bodies).toContainEqual({ search: 'keywords=the+Soviet+note+on+Berlin', mode: 'meaning' }));
  });

  it('lists the Semantic matches (experimental) under a keyword search that found nothing', async () => {
    const fallback: MeaningFallback = {
      question: 'zeppelin',
      caption: 'Ranked by meaning, not keywords, across the whole series — your exact words may not appear. Your filters are not applied here.',
      hits: [
        {
          volumeId: 'frus1961-63v06',
          documentId: 'd1',
          score: 0.4,
          chip: 'Semantic match · 40%',
          opens: true,
          displayTitle: 'Telegram From the Embassy',
          documentLabel: 'Doc 1',
          isEditorialNote: false,
          volumeTitle: 'Foreign Relations, 1961–1963, Volume VI',
        },
        {
          volumeId: 'frus1955-57v01',
          documentId: 'd7',
          score: 0.38,
          chip: 'Semantic match · 38%',
          opens: false,
          isEditorialNote: false,
          volumeTitle: 'Foreign Relations, 1955–1957, Volume I',
        },
      ],
      unscoredCandidates: 0,
      unscoredVolumes: 0,
      missingShards: [],
    };
    const fetch = server({ '/api/v1/search': list([]), '/api/v1/search/fallback': fallback });
    renderAt('/search?keywords=zeppelin&dateRangeEarliest=1962-01-01');
    const section = await screen.findByRole('region', { name: 'Semantic matches (experimental)' });
    expect(await within(section).findByText(fallback.caption)).toBeTruthy();
    expect(within(section).getByRole('link', { name: 'Telegram From the Embassy' })).toBeTruthy();
    expect(within(section).getByRole('link', { name: 'Document d7 in Foreign Relations, 1955–1957, Volume I' })).toBeTruthy();
    expect(within(section).getByText('Semantic match · 38%')).toBeTruthy();
    expect(query(calls(fetch, 'GET', '/api/v1/search/fallback')[0]![0]).get('dateRangeEarliest')).toBe('1962-01-01');
  });

  it('offers no fallback where the server does not search by meaning', async () => {
    const fetch = server({ '/api/v1/status': status(false), '/api/v1/search': list([]) });
    renderAt('/search?keywords=zeppelin');
    await waitFor(() => expect(calls(fetch, 'GET', '/api/v1/search').length).toBeGreaterThan(0));
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(calls(fetch, 'GET', '/api/v1/search/fallback')).toHaveLength(0);
    expect(screen.queryByRole('region', { name: 'Semantic matches (experimental)' })).toBeNull();
  });
});
