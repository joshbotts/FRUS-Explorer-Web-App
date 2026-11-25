// Search by meaning in the browser app (S27d): Search by, Keywords or Meaning, where the server says it searches by
// meaning, opening on Keywords and kept in the address; Keywords alone where it does not; the Meaning mode's strip in
// place of the Query Inspector's, the count of the closest matches, a row's chip and the hits beyond the library, with
// no download to offer; the empty state in the kit's sentence; and a run recorded in the trail and saved as a corpus as
// a search by meaning's.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { MeaningSearchResult, ServerStatus } from '../api/meaning';
import type { SearchItem, SearchResultList } from '../api/types';
import { sent } from '../test/notes';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';
import { checklistStore } from './checklist';
import { resetSearchHistory } from './searchHistory';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  checklistStore.reset();
  resetSearchHistory();
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
    snippet: 'the treaties',
    bm25Score: -1,
    isEditorialNote: false,
    isFrontMatter: false,
    subjectTagIds: [],
    userTagIds: [],
    ...fields,
  };
}

const keywordList: SearchResultList = {
  total: 1,
  countBasis: 'exact',
  limit: 20,
  offset: 0,
  retainedLimit: 7500,
  sort: 'relevance',
  sortChoices,
  coverage,
  items: [item('d9', 'A keyword row')],
};

const disclosure = {
  unscoredCandidates: 0,
  unscoredVolumes: 0,
  downloadingVolumes: 0,
  filtersApplied: false,
  filteredOut: 0,
  beyondUncheckedByFilters: false,
  withoutVector: 0,
  notIndexedHere: 0,
};

const opening =
  'Meaning search (experimental): ranked by what your question means, across the whole series — your exact words may not appear. Front matter and chapter headings are not reachable this way.';

function meaningList(items: SearchItem[], fields: Partial<MeaningSearchResult['meaning']> = {}): MeaningSearchResult {
  return {
    total: items.length,
    countBasis: 'exact',
    limit: 20,
    offset: 0,
    retainedLimit: 100,
    sort: 'relevance',
    sortChoices,
    coverage,
    items,
    meaning: {
      question: 'the Soviet note on Berlin',
      strip: [opening],
      emptyStatement: 'Nothing in the scorable corpus reads close to this search.',
      disclosure,
      beyondLibrary: [],
      missingShards: [],
      renderedExpression: 'route=semantic; model=embeddinggemma-2-Q8_0; top=100',
      signature: 'route=semantic;engine=on-device',
      ...fields,
    },
  };
}

const rows = [
  item('d1', 'Telegram From the Embassy', { semanticScore: 0.6449, chip: 'Semantic match · 64%' }),
  item('d2', 'Memorandum of Conversation', { semanticScore: 0.61, chip: 'Semantic match · 61%' }),
];

const server = (answers: Record<string, unknown>) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/search/inspect': { inspection: undefined },
    '/api/v1/search': keywordList,
    ...answers,
  });

const calls = (fetch: ReturnType<typeof stubServer>, method: string, path: string) =>
  fetch.mock.calls.filter(([url, init]) => (init?.method ?? 'GET') === method && String(url).split('?')[0] === path);

describe('search by meaning', () => {
  it('offers Search by where the server searches by meaning, opening on Keywords', async () => {
    const fetch = server({ '/api/v1/status': status(true) });
    renderAt('/search?keywords=treaties');
    const group = await screen.findByRole('group', { name: 'Search by' });
    expect((within(group).getByRole('radio', { name: 'Keywords' }) as HTMLInputElement).checked).toBe(true);
    expect((within(group).getByRole('radio', { name: 'Meaning' }) as HTMLInputElement).checked).toBe(false);
    await screen.findByRole('link', { name: 'A keyword row' });
    expect(calls(fetch, 'GET', '/api/v1/search/meaning')).toHaveLength(0);
  });

  it('offers Keywords alone where the server does not search by meaning, and searches a link that asks for Meaning by keywords', async () => {
    const fetch = server({ '/api/v1/status': status(false) });
    renderAt('/search?keywords=treaties&by=meaning');
    await screen.findByRole('link', { name: 'A keyword row' });
    expect(screen.queryByRole('group', { name: 'Search by' })).toBeNull();
    expect(calls(fetch, 'GET', '/api/v1/search/meaning')).toHaveLength(0);
  });

  it('runs the search by meaning once Meaning is chosen, in the address, with the strip, the closest matches, each row’s chip and the hits beyond the library', async () => {
    const fetch = server({
      '/api/v1/status': status(true),
      '/api/v1/search/meaning': meaningList(rows, {
        strip: [opening, 'Your filters removed 3 matches.'],
        beyondLibrary: [
          { volumeId: 'frus1958-60v10p1', documentId: 'd44', volumeTitle: 'Eastern Europe Region', score: 0.58, chip: 'Semantic match · 58%' },
        ],
        beyondHeader: 'In volumes this server does not serve (1)',
      }),
    });
    const { router } = renderAt('/search?keywords=the%20Soviet%20note%20on%20Berlin');
    const group = await screen.findByRole('group', { name: 'Search by' });
    await userEvent.click(within(group).getByRole('radio', { name: 'Meaning' }));
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    expect(router.state.location.search).toMatchObject({ keywords: 'the Soviet note on Berlin', by: 'meaning' });
    expect(calls(fetch, 'GET', '/api/v1/search/meaning')[0]![0]).toBe('/api/v1/search/meaning?keywords=the+Soviet+note+on+Berlin&limit=20&offset=0');
    expect(screen.getByRole('status').textContent).toContain('2 closest matches');
    expect(screen.getByRole('region', { name: 'About this Meaning search' }).textContent).toContain(`${opening} Your filters removed 3 matches.`);
    const results = within(screen.getByRole('list', { name: 'Results' })).getAllByRole('listitem');
    expect(results.map((row) => row.querySelector('.semantic-chip')?.textContent)).toEqual(['Semantic match · 64%', 'Semantic match · 61%']);
    // The hits beyond the library, apart, each opening its volume's page in Browse, with no download to offer.
    const beyond = screen.getByRole('region', { name: 'In volumes this server does not serve (1)' });
    const link = within(beyond).getByRole('link', { name: 'Document d44 in Eastern Europe Region' });
    expect(link.getAttribute('href')).toBe('/browse/frus1958-60v10p1');
    expect(within(beyond).getByText('Volume not on this server — its documents are shown without titles.')).toBeTruthy();
    expect(within(beyond).getByText('Semantic match · 58%')).toBeTruthy();
    expect(screen.queryByRole('button', { name: /Download/ })).toBeNull();
    // The keyword surfaces wait for Keywords: the inspector, the readings, the facets and Search in.
    expect(document.querySelector('.query-inspector')).toBeNull();
    expect(screen.queryByRole('radiogroup', { name: 'Reading' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Facets' })).toBeNull();
    expect(screen.getByRole('searchbox').getAttribute('placeholder')).toBe('A question in your own words…');
  });

  it('says No semantic matches yet in the kit’s sentence for a run that listed nothing', async () => {
    server({
      '/api/v1/status': status(true),
      '/api/v1/search/meaning': meaningList([], {
        emptyStatement:
          'Match files for 3 volumes are required. This server does not hold them.',
        disclosure: { ...disclosure, unscoredCandidates: 12, unscoredVolumes: 3 },
      }),
    });
    renderAt('/search?keywords=Berlin&by=meaning');
    expect(await screen.findByRole('heading', { name: 'No semantic matches yet' })).toBeTruthy();
    expect(screen.getByText('Match files for 3 volumes are required. This server does not hold them.')).toBeTruthy();
  });

  it('says the heading over the hits beyond the library where a run listed no row, as the app’s finished search says it', async () => {
    server({
      '/api/v1/status': status(true),
      '/api/v1/search/meaning': meaningList([], {
        beyondLibrary: [
          { volumeId: 'frus1958-60v10p1', documentId: 'd44', volumeTitle: 'Eastern Europe Region', score: 0.58, chip: 'Semantic match · 58%' },
        ],
        beyondHeader: 'In volumes this server does not serve (1)',
      }),
    });
    renderAt('/search?keywords=Berlin&by=meaning');
    await screen.findByRole('link', { name: 'Document d44 in Eastern Europe Region' });
    expect(screen.getByRole('status').textContent).toContain('In volumes this server does not serve (1)');
    expect(screen.queryByRole('heading', { name: 'No semantic matches yet' })).toBeNull();
  });

  it('asks nothing for a question of no words, and says nothing, as the Mac lists none', async () => {
    const fetch = server({ '/api/v1/status': status(true), '/api/v1/search/meaning': meaningList(rows) });
    renderAt('/search?keywords=%20&by=meaning');
    await screen.findByRole('group', { name: 'Search by' });
    await waitFor(() => expect(calls(fetch, 'GET', '/api/v1/status')).toHaveLength(1));
    expect(calls(fetch, 'GET', '/api/v1/search/meaning')).toHaveLength(0);
    expect(screen.queryByRole('alert')).toBeNull();
    expect(screen.queryByRole('list', { name: 'Results' })).toBeNull();
  });

  it('abandons a search by meaning under way when Keywords is chosen, so the server stops it', async () => {
    const fetch = server({
      '/api/v1/status': status(true),
      '/api/v1/search/meaning': () => new Promise(() => {}),
    });
    renderAt('/search?keywords=Berlin&by=meaning');
    await waitFor(() => expect(calls(fetch, 'GET', '/api/v1/search/meaning')).toHaveLength(1));
    const signal = (calls(fetch, 'GET', '/api/v1/search/meaning')[0] as unknown as [string, RequestInit | undefined])[1]?.signal;
    expect(signal?.aborted).toBe(false);
    await userEvent.click(within(screen.getByRole('group', { name: 'Search by' })).getByRole('radio', { name: 'Keywords' }));
    await waitFor(() => expect(signal?.aborted).toBe(true));
    await screen.findByRole('link', { name: 'A keyword row' });
  });

  it('never shows another question’s closest matches while a search by meaning loads, so no mark can fall on them', async () => {
    server({
      '/api/v1/status': status(true),
      // Berlin's run answers; Cuba's is still under way.
      '/api/v1/search/meaning': (url: URL) => (url.searchParams.get('keywords') === 'Berlin' ? meaningList(rows) : new Promise(() => {})),
    });
    const { router } = renderAt('/search?keywords=Berlin&by=meaning');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    // Another question by keywords, then by meaning: Berlin's rows must not stand in for Cuba's.
    await router.navigate({ to: '/search', search: { keywords: 'Cuba' } });
    await screen.findByRole('link', { name: 'A keyword row' });
    await router.navigate({ to: '/search', search: { keywords: 'Cuba', by: 'meaning' } });
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe('Searching…'));
    expect(screen.queryByRole('link', { name: 'Telegram From the Embassy' })).toBeNull();
    expect(screen.queryByRole('region', { name: 'About this Meaning search' })).toBeNull();
  });

  it('counts My Tags over the rows a search by meaning listed', async () => {
    const tag = { id: 'T1', name: 'Berlin', createdAt: '2026-10-24T00:00:00.000Z' };
    const fetch = server({
      '/api/v1/status': status(true),
      '/api/v1/me': me,
      '/api/v1/me/tags': { total: 1, items: [tag] },
      '/api/v1/me/saved-searches': { total: 0, items: [] },
      '/api/v1/me/working-corpora': { total: 0, items: [] },
      '/api/v1/me/volume-scopes': { total: 0, items: [] },
      '/api/v1/search/meaning': meaningList(rows),
      '/api/v1/me/search/tags': { items: [{ id: 'T1', name: 'Berlin', count: 1 }], coverage },
      'POST /api/v1/me/history/searches': { outcome: 'suppressed' },
    });
    renderAt('/search?keywords=Berlin&by=meaning');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await userEvent.click(screen.getByText('My Tags'));
    await screen.findByRole('checkbox', { name: 'Berlin: 1 documents in your current results' });
    expect(calls(fetch, 'GET', '/api/v1/me/search/tags')[0]![0]).toBe('/api/v1/me/search/tags?keywords=Berlin&mode=meaning');
  });

  it('says the server’s refusal of a question too long for the model', async () => {
    server({
      '/api/v1/status': status(true),
      '/api/v1/search/meaning': new ProblemAnswer(422, 'QUERY_TOO_LONG', 'This search is too long for the model. Try a shorter phrasing.'),
    });
    renderAt('/search?keywords=Berlin&by=meaning');
    expect((await screen.findByRole('alert')).textContent).toBe('This search is too long for the model. Try a shorter phrasing.');
  });

  it('records a run in the trail as a search by meaning’s, and saves its list as a working corpus as one', async () => {
    const bodies: unknown[] = [];
    const fetch = server({
      '/api/v1/status': status(true),
      '/api/v1/me': me,
      '/api/v1/me/tags': { total: 0, items: [] },
      '/api/v1/me/saved-searches': { total: 0, items: [] },
      '/api/v1/me/working-corpora': { total: 0, items: [] },
      '/api/v1/me/volume-scopes': { total: 0, items: [] },
      '/api/v1/search/meaning': meaningList(rows),
      'POST /api/v1/me/history/searches': (_: URL, init?: RequestInit) => {
        bodies.push(sent(init).body);
        return { outcome: 'inserted', anchor: { entryId: 'R1', queryText: 'Berlin' } };
      },
      'POST /api/v1/me/working-corpora/capture': {
        documentCount: 2,
        sourceQuery: 'Berlin',
        narrowing: [],
        indexedVolumeCount: 3,
        truncationWarning:
          'These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.',
        sourceDescription: 'Meaning search — the 2 closest matches',
        wasTruncated: true,
      },
      'POST /api/v1/me/working-corpora': { id: 'C1', name: 'Closest', documentCount: 2, isMeaningCapture: true, truncationWarns: false },
    });
    renderAt('/search?keywords=Berlin&by=meaning');
    await screen.findByRole('link', { name: 'Telegram From the Embassy' });
    await waitFor(() => expect(bodies).toHaveLength(1));
    expect(bodies[0]).toEqual({ search: 'keywords=Berlin', mode: 'meaning' });
    const open = screen.getByRole('button', { name: 'Save as Working Corpus…' });
    await userEvent.click(open);
    const dialog = await screen.findByRole('dialog', { name: 'Save Working Corpus' });
    expect(await within(dialog).findByText(/closest matches a Meaning search found/)).toBeTruthy();
    expect(sent(calls(fetch, 'POST', '/api/v1/me/working-corpora/capture')[0]![1]).body).toEqual({
      search: 'keywords=Berlin',
      reviewed: [],
      mode: 'meaning',
    });
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'Name' }), 'Closest');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(sent(calls(fetch, 'POST', '/api/v1/me/working-corpora')[0]![1]).body).toEqual({
      name: 'Closest',
      search: 'keywords=Berlin',
      reviewed: [],
      mode: 'meaning',
    });
  });
});
