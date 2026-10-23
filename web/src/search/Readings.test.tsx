import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ConcordanceLine, SearchConcordance, SearchItem, SearchResultList, SearchTimeline } from '../api/types';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';
import { niceStep } from './Readings';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
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

const volumes = { total: 0, limit: 1000, offset: 0, items: [], coverage };

describe('the readings', () => {
  it('offer the list, the timeline and the concordance, in the Mac’s words, and show the one chosen in the results’ place', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': volumes,
      '/api/v1/search': threeResults,
      '/api/v1/search/timeline': timeline(),
      '/api/v1/search/concordance': concordance(),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/search?keywords=negotiating');
    const picker = await screen.findByRole('group', { name: 'Reading' });
    expect(within(picker).getAllByRole('button').map((button) => button.textContent)).toEqual(['List', 'Timeline', 'Concordance']);
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
    for (const button of within(picker).getAllByRole('button')) expect((button as HTMLButtonElement).disabled).toBe(true);
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
