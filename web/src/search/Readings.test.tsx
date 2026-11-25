import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ConcordanceLine, SearchCollocates, SearchConcordance, SearchItem, SearchResultList, SearchTimeline } from '../api/types';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';
import { niceStep } from './Readings';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  window.localStorage.clear();
});

function item(fields: Partial<SearchItem>): SearchItem {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    header: 'Telegram',
    displayTitle: 'Telegram',
    documentLabel: 'Doc 1',
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

function list(total: number, items: SearchItem[], fields: Partial<SearchResultList> = {}): SearchResultList {
  return { total, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, items, coverage, ...fields };
}

const threeResults = list(3, [
  item({}),
  item({ documentId: 'd2', header: 'Memorandum', displayTitle: 'Memorandum', documentLabel: 'Doc 2' }),
  item({ volumeId: 'frus1894Nicaragua', displayTitle: 'Mr. Baker to Mr. Gresham' }),
]);

function timeline(fields: Partial<SearchTimeline> = {}): SearchTimeline {
  return {
    retainedLimit: 7500,
    retainedCount: 3,
    sort: 'relevance',
    years: [
      { year: '1894', count: 1 },
      { year: '1960', count: 2 },
    ],
    undatedCount: 0,
    coverage,
    ...fields,
  };
}

function line(fields: Partial<ConcordanceLine>): ConcordanceLine {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    header: 'Telegram',
    displayTitle: 'Telegram',
    dateISO: '1960-11-09',
    left: 'The ambassador was',
    keyword: 'negotiating',
    right: 'treaties with the minister.',
    characterOffset: 19,
    ...fields,
  };
}

function concordance(fields: Partial<SearchConcordance> = {}): SearchConcordance {
  return {
    limit: 20,
    offset: 0,
    retainedLimit: 7500,
    sort: 'relevance',
    documentsOnPage: 2,
    items: [
      line({}),
      line({ documentId: 'd2', header: 'Memorandum', displayTitle: 'Memorandum', dateISO: '1960-11-10', left: '', keyword: 'Negotiating', right: 'began in May', characterOffset: 0 }),
    ],
    orders: { leftContext: [1, 0], rightContext: [1, 0], date: [0, 1], volume: [0, 1] },
    orderChoices: [
      { value: 'leftContext', title: 'Left context' },
      { value: 'rightContext', title: 'Right context' },
      { value: 'date', title: 'Date' },
      { value: 'volume', title: 'Volume' },
    ],
    omittedCount: 0,
    documentsWithLines: 2,
    documentsWithoutLines: 0,
    coverage,
    ...fields,
  };
}

/** A ranking the server gives (S29f): three neighbours, the last rarer corpus-wide than the reference prices. */
function collocates(fields: Partial<SearchCollocates> = {}): SearchCollocates {
  return {
    window: 10,
    windowChoices: [5, 10, 20, 50].map((size) => ({ value: String(size), title: `±${size} words` })),
    orderChoices: [
      { value: 'evidence', title: 'Evidence' },
      { value: 'effect', title: 'Concentration' },
    ],
    state: 'ranked',
    caveat:
      'Words occurring fewer than 114 times corpus-wide are unpriced and score as if new. Measured over every result this search loaded, which is every matching document. 12 matches, in 3 documents that had indexed text.',
    items: [
      { term: 'treaty', nearby: 9, corpusWide: 41_234, logLikelihood: 1234.56, logRatio: 4.2, fold: 18.38, unpriced: false },
      { term: 'ratify', nearby: 4, corpusWide: 2_310, logLikelihood: 87.04, logRatio: 6.1, fold: 68.6, unpriced: false },
      { term: 'zorin', nearby: 3, corpusWide: 0, logLikelihood: 40.31, logRatio: 9.3, fold: 630.4, unpriced: true },
    ],
    orders: { evidence: [0, 1, 2], effect: [1, 0, 2] },
    documentsScanned: 3,
    documentsInScope: 3,
    documentsOffered: 3,
    anchorCount: 12,
    omittedAnchorCount: 0,
    windowTokenCount: 120,
    minimumCount: 3,
    referenceCutoffCount: 114,
    wordForm: 'dictionary',
    wasBounded: false,
    retainedLimit: 7500,
    retainedCount: 3,
    coverage,
    ...fields,
  };
}

const volumes = { total: 0, limit: 1000, offset: 0, items: [], coverage };

describe('the readings', () => {
  it('offer the list, the timeline, the concordance and Collocates, in the Mac’s words, and show the one chosen in the results’ place', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/timeline': timeline(),
      '/api/v1/search/concordance': concordance(),
      '/api/v1/search/collocates': collocates(),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/search?keywords=negotiating');
    const picker = await screen.findByRole('group', { name: 'Reading' });
    expect(within(picker).getAllByRole('button').map((button) => button.textContent)).toEqual(['List', 'Timeline', 'Concordance', 'Collocates']);
    expect(within(picker).getByRole('button', { name: 'List' }).getAttribute('aria-pressed')).toBe('true');
    expect(picker.getAttribute('title')).toBe('How to read these results. The concordance covers this page; the others cover the whole retained set.');
    expect(screen.getByRole('navigation', { name: 'Pages' })).toBeTruthy();

    await user.click(within(picker).getByRole('button', { name: 'Timeline' }));
    expect(router.state.location.search).toMatchObject({ reading: 'timeline' });
    expect(await screen.findByRole('img', { name: 'Documents per year, 1894 to 1960: 3 in 2 years' })).toBeTruthy();
    expect(screen.queryByRole('list', { name: 'Results' })).toBeNull();
    // The timeline covers every result kept, so there is no page to turn.
    expect(screen.queryByRole('navigation', { name: 'Pages' })).toBeNull();
    expect(document.activeElement).toBe(within(picker).getByRole('button', { name: 'Timeline' }));

    await user.click(within(picker).getByRole('button', { name: 'Concordance' }));
    expect(router.state.location.search).toMatchObject({ reading: 'concordance' });
    expect(await screen.findByRole('list', { name: 'Occurrences' })).toBeTruthy();
    expect(screen.getByRole('navigation', { name: 'Pages' })).toBeTruthy();
    const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost'));
    const concordanceURL = asked.find((url) => url.pathname === '/api/v1/search/concordance');
    // The page the list shows, by its fields.
    expect(concordanceURL?.searchParams.get('limit')).toBe('20');
    expect(concordanceURL?.searchParams.get('offset')).toBe('0');

    // From S29f, the Mac's fourth: the words near the matches across every result kept, so no page to turn.
    await user.click(within(picker).getByRole('button', { name: 'Collocates' }));
    expect(router.state.location.search).toMatchObject({ reading: 'collocates' });
    expect(await screen.findByRole('list', { name: 'Words near your matches' })).toBeTruthy();
    expect(screen.queryByRole('navigation', { name: 'Pages' })).toBeNull();
    expect(document.activeElement).toBe(within(picker).getByRole('button', { name: 'Collocates' }));

    await user.click(within(picker).getByRole('button', { name: 'List' }));
    expect(router.state.location.search).not.toHaveProperty('reading');
    expect(await screen.findByRole('list', { name: 'Results' })).toBeTruthy();
  });

  it('wait for a match, and give way to the account of a search that found nothing', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': list(0, []),
      '/api/v1/search/inspect': { inspection: undefined },
    });
    renderAt('/search?keywords=formosa&reading=timeline');
    const picker = await screen.findByRole('group', { name: 'Reading' });
    for (const name of ['List', 'Timeline', 'Concordance', 'Collocates']) expect((within(picker).getByRole('button', { name }) as HTMLButtonElement).disabled).toBe(true);
    expect(await screen.findByRole('heading', { name: 'No Results' })).toBeTruthy();
    expect(screen.queryByRole('img')).toBeNull();
  });
});

describe('the timeline', () => {
  it('draws a column for each year that holds a result, with every count in its table, and the results it left out for want of a date', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/timeline': timeline({ undatedCount: 1 }),
    });
    renderAt('/search?keywords=negotiating&reading=timeline');
    const chart = await screen.findByRole('img', { name: 'Documents per year, 1894 to 1960: 3 in 2 years' });
    expect(chart.querySelectorAll('.chart-column')).toHaveLength(2);
    const table = screen.getByRole('table');
    expect(within(table).getAllByRole('row').map((row) => row.textContent)).toEqual(['YearDocuments', '18941', '19602']);
    expect(screen.getByText('1 document without a reliable date excluded from the timeline.')).toBeTruthy();
    expect(screen.getByRole('group', { name: 'View mode' })).toBeTruthy();
    // Every match is kept, so the shape is the match's: no caption says otherwise.
    expect(screen.queryByText(/not a sample across time/)).toBeNull();
  });

  it('says the shape is the ranking’s when the search keeps only part of its match', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': list(20_000, [item({})]),
      '/api/v1/search/timeline': timeline({ retainedCount: 7500, years: [{ year: '1961', count: 7500 }] }),
    });
    renderAt('/search?keywords=soviet&reading=timeline');
    expect(
      await screen.findByText('These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match’s.'),
    ).toBeTruthy();
    expect(screen.getByRole('img', { name: 'Documents per year: 7,500 in 1961' })).toBeTruthy();
  });

  it('lists each year’s documents in the order the results are in, from its List mode', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/timeline': (url: URL) =>
        url.searchParams.get('documents') === 'true'
          ? timeline({
              sort: 'dateDescending',
              years: [
                { year: '1894', count: 1, documents: [{ volumeId: 'frus1894Nicaragua', documentId: 'd1', displayTitle: 'Mr. Baker to Mr. Gresham', documentLabel: 'Doc 1', headerRepeatsNumber: false }] },
                {
                  year: '1960',
                  count: 2,
                  documents: [
                    { volumeId: 'frus1961-63v06', documentId: 'd2', displayTitle: 'Memorandum', documentLabel: 'Doc 2', headerRepeatsNumber: false },
                    { volumeId: 'frus1961-63v06', documentId: 'd1', displayTitle: 'Telegram', documentLabel: 'Doc 1', headerRepeatsNumber: false },
                  ],
                },
              ],
            })
          : timeline(),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/search?keywords=negotiating&reading=timeline&sort=dateDescending');
    await screen.findByRole('img');
    await user.click(within(screen.getByRole('group', { name: 'View mode' })).getByRole('button', { name: 'List' }));
    expect(router.state.location.search).toMatchObject({ reading: 'timeline', timelineMode: 'list' });
    const year = (await screen.findByRole('heading', { name: '1960' })).parentElement;
    expect(within(year as HTMLElement).getAllByRole('link').map((link) => link.textContent)).toEqual(['Memorandum', 'Telegram']);
    expect(screen.getByRole('heading', { name: '1894' })).toBeTruthy();
    const listed = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.searchParams.get('documents') === 'true');
    expect(listed?.searchParams.get('sort')).toBe('dateDescending');
    expect(screen.queryByRole('img')).toBeNull();

    // Another reading, then the timeline again: it opens on its chart, as the Mac's does.
    const picker = screen.getByRole('group', { name: 'Reading' });
    await user.click(within(picker).getByRole('button', { name: 'List' }));
    await user.click(within(picker).getByRole('button', { name: 'Timeline' }));
    expect(await screen.findByRole('img')).toBeTruthy();
    expect(router.state.location.search).not.toHaveProperty('timelineMode');
  });

  it('says so when none of the results carries a date', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/timeline': timeline({ years: [], undatedCount: 3 }),
    });
    renderAt('/search?keywords=negotiating&reading=timeline');
    expect(await screen.findByRole('heading', { name: 'No Dated Documents' })).toBeTruthy();
    expect(screen.getByText('None of these documents have machine-readable dates.')).toBeTruthy();
    // The Mac's view of none dated stands alone: no modes, and no note of the undated beneath it.
    expect(screen.queryByText(/without a reliable date/)).toBeNull();
    expect(screen.queryByRole('group', { name: 'View mode' })).toBeNull();
  });

  it('labels its axis by whole years, two adjacent years among them', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/timeline': timeline({ years: [{ year: '1961', count: 3 }, { year: '1962', count: 4 }], retainedCount: 7 }),
    });
    renderAt('/search?keywords=berlin&reading=timeline');
    const chart = await screen.findByRole('img', { name: 'Documents per year, 1961 to 1962: 7 in 2 years' });
    const years = [...chart.querySelectorAll('text')].map((text) => text.textContent ?? '').filter((label) => /^\d{4}/.test(label));
    expect(years).toEqual(['1961', '1962']);
  });

  it('keeps its list when Timeline, already shown, is chosen again, as the Mac’s picker does', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/timeline': timeline(),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/search?keywords=negotiating&reading=timeline&timelineMode=list');
    await screen.findByRole('group', { name: 'View mode' });
    await user.click(within(screen.getByRole('group', { name: 'Reading' })).getByRole('button', { name: 'Timeline' }));
    expect(router.state.location.search).toMatchObject({ reading: 'timeline', timelineMode: 'list' });
  });

  it('never stands another search’s years in for the next search’s', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      // The second search's timeline is still being counted.
      '/api/v1/search/timeline': (url: URL) => (url.searchParams.get('keywords') === 'canal' ? new Promise(() => {}) : timeline()),
    });
    const user = userEvent.setup();
    renderAt('/search?keywords=negotiating&reading=timeline');
    await screen.findByRole('img');
    const box = screen.getByRole('searchbox', { name: 'Search the documents' });
    await user.clear(box);
    await user.type(box, 'canal{Enter}');
    expect(await screen.findByText('Loading timeline…')).toBeTruthy();
    expect(screen.queryByRole('img')).toBeNull();
  });

  it('steps its axes by 1, 2 or 5 times a power of ten', () => {
    expect(niceStep(2, 4)).toBe(0.5);
    expect(niceStep(66, 2)).toBe(50);
    expect(niceStep(7500, 4)).toBe(2000);
    expect(niceStep(2, 2)).toBe(1);
  });
});

describe('the concordance', () => {
  it('lines up each occurrence between its contexts, and changes its order without asking again', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': list(2, [item({}), item({ documentId: 'd2' })]),
      '/api/v1/search/concordance': concordance(),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/search?keywords=negotiating&reading=concordance');
    const lines = await screen.findByRole('list', { name: 'Occurrences' });
    const links = () => within(lines).getAllByRole('link');
    // By the left context, the Mac's first order: the line with nothing before its term comes first.
    expect(links().map((link) => link.querySelector('.kwic-keyword')?.textContent)).toEqual(['Negotiating', 'negotiating']);
    // Read aloud as a sentence, then its document and date, as the Mac's VoiceOver label reads it.
    expect(links()[1]?.getAttribute('aria-label')).toBe('The ambassador was negotiating treaties with the minister.. Telegram · 1960-11-09');
    expect(links()[0]?.getAttribute('aria-label')).toBe('Negotiating began in May. Memorandum · 1960-11-10');
    expect(links()[1]?.getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    expect(screen.getByText('2 occurrences')).toBeTruthy();
    const align = screen.getByRole('group', { name: 'Align by' });
    expect(within(align).getByRole('button', { name: 'Left context' }).getAttribute('aria-pressed')).toBe('true');

    const asked = fetch.mock.calls.length;
    await user.click(within(align).getByRole('button', { name: 'Date' }));
    await waitFor(() => expect(links().map((link) => link.querySelector('.kwic-keyword')?.textContent)).toEqual(['negotiating', 'Negotiating']));
    // Kept in the address, so Back to the search from a document it opened shows it so.
    expect(router.state.location.search).toMatchObject({ align: 'date' });
    expect(within(align).getByRole('button', { name: 'Date' }).getAttribute('aria-pressed')).toBe('true');
    expect(fetch.mock.calls.length).toBe(asked);
  });

  it('names the documents it read when the search has more than one page, and what it could not show', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': list(45, [item({})]),
      '/api/v1/search/concordance': concordance({ omittedCount: 1, linesPerDocumentLimit: 200, documentsWithoutLines: 3, documentsWithLines: 17, documentsOnPage: 20 }),
    });
    renderAt('/search?keywords=negotiating&reading=concordance');
    expect(await screen.findByText('2 occurrences in the 20 documents on this page')).toBeTruthy();
    expect(screen.getByText('1 further occurrence isn’t shown — each document contributes at most 200 lines.')).toBeTruthy();
    expect(screen.getByText('3 matching documents contributed no line — their match isn’t a whole word this view can center on.')).toBeTruthy();
  });

  it('says so when no occurrence could be aligned', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': list(2, [item({})]),
      '/api/v1/search/concordance': concordance({
        items: [],
        orders: { leftContext: [], rightContext: [], date: [], volume: [] },
        documentsWithLines: 0,
        documentsWithoutLines: 2,
      }),
    });
    renderAt('/search?keywords=%3Dnegotiating&reading=concordance');
    expect(await screen.findByRole('heading', { name: 'No Aligned Occurrences' })).toBeTruthy();
    expect(screen.getByText('0 occurrences')).toBeTruthy();
    expect(screen.getByText('2 matching documents contributed no line — their match isn’t a whole word this view can center on.')).toBeTruthy();
    // The Mac's header stays over its view of none aligned.
    expect(screen.getByRole('group', { name: 'Align by' })).toBeTruthy();
    expect(screen.queryByRole('list', { name: 'Occurrences' })).toBeNull();
  });

  it('is asked again when the same search is made again, after it failed', async () => {
    let asked = 0;
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': list(2, [item({}), item({ documentId: 'd2' })]),
      '/api/v1/search/inspect': { inspection: undefined },
      '/api/v1/search/concordance': () => (++asked === 1 ? new ProblemAnswer(503, 'INDEX_NOT_READY', 'A new index is being installed.') : concordance()),
    });
    const user = userEvent.setup();
    renderAt('/search?keywords=negotiating&reading=concordance');
    expect((await screen.findByRole('alert')).textContent).toContain('The server has no index to search yet.');
    await user.click(screen.getByRole('button', { name: 'Search' }));
    expect(await screen.findByRole('list', { name: 'Occurrences' })).toBeTruthy();
    expect(asked).toBe(2);
  });
});

describe('Collocates', () => {
  it('lists the words near the matches as the server ranks them, each with its multiple and two counts, and opens a word’s search', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/collocates': collocates(),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/search?keywords=negotiating&reading=collocates&offset=0');
    const words = await screen.findByRole('list', { name: 'Words near your matches' });
    const rows = within(words).getAllByRole('listitem');
    expect(rows.map((row) => row.textContent)).toEqual([
      '1treaty18× more often here · 9 nearby · 41,234 corpus-wide1,234.6',
      '2ratify69× more often here · 4 nearby · 2,310 corpus-wide87.0',
      '3zorin630× more often here · 3 nearby · fewer than 114 corpus-wide (unpriced)40.3',
    ]);
    // The word is a link whose description is its row's numbers, read with it.
    const treaty = within(words).getByRole('link', { name: 'treaty' });
    expect(treaty.getAttribute('href')).toBe('/search?keywords=treaty');
    expect(document.getElementById(treaty.getAttribute('aria-describedby')!)?.textContent).toBe('18× more often here · 9 nearby · 41,234 corpus-wide');
    // What the scan saw, in the server's words, the Mac's.
    expect(screen.getByText(/Measured over every result this search loaded, which is every matching document\. 12 matches, in 3 documents/)).toBeTruthy();
    const within10 = within(screen.getByRole('group', { name: 'Within' })).getByRole('button', { name: '±10 words' });
    expect(within10.getAttribute('aria-pressed')).toBe('true');
    expect(within(screen.getByRole('group', { name: 'Rank by' })).getByRole('button', { name: 'Evidence' }).getAttribute('aria-pressed')).toBe('true');
    // The search's fields and the window, never its page: the scan reads every result the search keeps.
    const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/search/collocates');
    expect(asked?.searchParams.get('keywords')).toBe('negotiating');
    expect(asked?.searchParams.get('window')).toBe('10');
    expect(asked?.searchParams.has('limit')).toBe(false);
    expect(asked?.searchParams.has('offset')).toBe(false);

    await user.click(treaty);
    await waitFor(() => expect(router.state.location.search).toEqual({ keywords: 'treaty' }));
  });

  it('ranks by Concentration without asking again, asks again within another window, and keeps both in this browser', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/collocates': (url: URL) =>
        url.searchParams.get('window') === '20' ? collocates({ window: 20, items: [collocates().items[0]!], orders: { evidence: [0], effect: [0] } }) : collocates(),
    });
    const user = userEvent.setup();
    renderAt('/search?keywords=negotiating&reading=collocates');
    const words = await screen.findByRole('list', { name: 'Words near your matches' });
    const asked = () => fetch.mock.calls.filter(([url]) => new URL(url, 'http://localhost').pathname === '/api/v1/search/collocates').length;
    expect(asked()).toBe(1);
    await user.click(within(screen.getByRole('group', { name: 'Rank by' })).getByRole('button', { name: 'Concentration' }));
    // Priced words first, by their multiple; the unpriced last, whose multiple is an upper bound.
    expect(within(words).getAllByRole('link').map((link) => link.textContent)).toEqual(['ratify', 'treaty', 'zorin']);
    expect(within(words).getAllByRole('listitem').map((row) => row.querySelector('.collocates-value')?.textContent)).toEqual(['69×', '18×', '630×']);
    expect(asked()).toBe(1);
    expect(window.localStorage.getItem('frus.search.collocation.order')).toBe('effect');

    await user.click(within(screen.getByRole('group', { name: 'Within' })).getByRole('button', { name: '±20 words' }));
    await waitFor(() => expect(within(screen.getByRole('list', { name: 'Words near your matches' })).getAllByRole('link').map((link) => link.textContent)).toEqual(['treaty']));
    expect(asked()).toBe(2);
    expect(window.localStorage.getItem('frus.search.collocation.window')).toBe('20');
  });

  it('opens on the window and order this browser kept', async () => {
    window.localStorage.setItem('frus.search.collocation.window', '50');
    window.localStorage.setItem('frus.search.collocation.order', 'effect');
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/collocates': collocates({ window: 50 }),
    });
    renderAt('/search?keywords=negotiating&reading=collocates');
    await screen.findByRole('list', { name: 'Words near your matches' });
    expect(within(screen.getByRole('group', { name: 'Within' })).getByRole('button', { name: '±50 words' }).getAttribute('aria-pressed')).toBe('true');
    expect(within(screen.getByRole('group', { name: 'Rank by' })).getByRole('button', { name: 'Concentration' }).getAttribute('aria-pressed')).toBe('true');
    const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/search/collocates');
    expect(asked?.searchParams.get('window')).toBe('50');
  });

  it('says why there are none, in the server’s words, with the row a count of printed forms opens with', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/collocates': collocates({
        state: 'unavailable',
        reason: 'noNeighboursAboveFloor',
        message: { title: 'No Collocates', detail: 'No word appears at least 3 times near your matches.' },
        printedFormsNote: 'Compared as printed: this server’s tagger does not reduce words to their dictionary forms.',
        caveat: undefined,
        items: [],
        orders: {},
      }),
    });
    renderAt('/search?keywords=negotiating&reading=collocates');
    expect(await screen.findByRole('heading', { name: 'No Collocates' })).toBeTruthy();
    expect(screen.getByText('No word appears at least 3 times near your matches.')).toBeTruthy();
    expect(screen.getByText(/^Compared as printed:/)).toBeTruthy();
    expect(screen.queryByRole('list', { name: 'Words near your matches' })).toBeNull();
    // The Mac's controls stay over its account of none.
    expect(screen.getByRole('group', { name: 'Within' })).toBeTruthy();
  });

  it('is asked again when the same search is made again, after it failed', async () => {
    let asked = 0;
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/inspect': { inspection: undefined },
      '/api/v1/search/collocates': () => (++asked === 1 ? new ProblemAnswer(503, 'INDEX_NOT_READY', 'A new index is being installed.') : collocates()),
    });
    const user = userEvent.setup();
    renderAt('/search?keywords=negotiating&reading=collocates');
    expect((await screen.findByRole('alert')).textContent).toContain('The server has no index to search yet.');
    await user.click(screen.getByRole('button', { name: 'Search' }));
    expect(await screen.findByRole('list', { name: 'Words near your matches' })).toBeTruthy();
    expect(asked).toBe(2);
  });
});
