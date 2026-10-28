import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SearchItem, SearchResultList } from '../api/types';
import { coverage, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function item(fields: Partial<SearchItem>): SearchItem {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    header: '',
    displayTitle: '',
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

describe('SearchScreen', () => {
  it('names each result as the server says the Mac’s search window names it, and withholds a label its title repeats', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search': {
        total: 2,
        countBasis: 'exact',
        limit: 20,
        offset: 0,
        retainedLimit: 7500,
        sort: 'relevance',
        sortChoices,
        coverage,
        items: [
          item({
            documentNumber: '1',
            header: '1. Telegram From the Embassy Source: Department of State, Central Files',
            displayTitle: '1. Telegram From the Embassy',
            headerRepeatsNumber: true,
          }),
          item({ documentId: 'd2', header: 'Memorandum of Conversation', displayTitle: 'Memorandum of Conversation', documentLabel: 'Doc 2' }),
        ],
      },
    });
    renderAt('/search?keywords=treaties');
    const rows = within(await screen.findByRole('list', { name: 'Results' })).getAllByRole('listitem');
    expect(rows.map((row) => within(row).getByRole('link').textContent)).toEqual(['1. Telegram From the Embassy', 'Memorandum of Conversation']);
    expect(rows[0]?.querySelector('.meta')?.textContent).toBe('frus1961-63v06');
    expect(rows[1]?.querySelector('.meta')?.textContent).toBe('frus1961-63v06 · Doc 2');
  });

  it('draws a row’s dateline, or for a row that prints none the day or span the index dates it by, as the Mac’s window does', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search': {
        total: 3,
        countBasis: 'exact',
        limit: 20,
        offset: 0,
        retainedLimit: 7500,
        sort: 'relevance',
        sortChoices,
        coverage,
        items: [
          item({ displayTitle: 'Telegram', dateline: 'Moscow, November 9, 1960.', dateISO: '1960-11-09', dateISOMax: '1960-11-09', datePrecision: 'day', drawnDate: 'November 9, 1960' }),
          // A section's row, dated by the documents it holds.
          item({
            documentId: 'ch2',
            displayTitle: 'Founding conference',
            documentLabel: 'Unnumbered (ch2)',
            dateISO: '1945-08-21',
            dateISOMax: '1946-01-22',
            datePrecision: 'day',
            drawnDate: 'August 21, 1945 – January 22, 1946',
          }),
          item({ documentId: 'd3', displayTitle: 'Undated', documentLabel: 'Doc 3' }),
        ],
      },
    });
    renderAt('/search?keywords=treaties');
    const rows = within(await screen.findByRole('list', { name: 'Results' })).getAllByRole('listitem');
    expect(rows.map((row) => row.querySelector('.meta')?.textContent)).toEqual([
      'frus1961-63v06 · Doc 1 · Moscow, November 9, 1960.',
      'frus1961-63v06 · Unnumbered (ch2) · August 21, 1945 – January 22, 1946',
      'frus1961-63v06 · Doc 3',
    ]);
  });

  it('abandons a search it replaces, so the server stops that search', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search/inspect': { inspection: undefined },
      // The first search is still under way when the second replaces it.
      '/api/v1/search': (url: URL) =>
        url.searchParams.get('keywords') === 'government'
          ? new Promise(() => {})
          : { total: 0, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, coverage, items: [] },
    });
    const { router } = renderAt('/search?keywords=government');
    const first = () => fetch.mock.calls.find(([url]) => String(url).startsWith('/api/v1/search?keywords=government'));
    await waitFor(() => expect(first()).toBeDefined());
    const signal = (first() as unknown as [string, RequestInit | undefined] | undefined)?.[1]?.signal;
    expect(signal?.aborted).toBe(false);
    await router.navigate({ to: '/search', search: { keywords: 'treaty' } });
    await waitFor(() => expect(signal?.aborted).toBe(true));
  });

  it('offers the three orders by the kit’s labels, and reads the results from the first page in the order pressed', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search/inspect': { inspection: undefined },
      '/api/v1/search': (url: URL): SearchResultList => ({
        total: 45,
        countBasis: 'exact',
        limit: 20,
        offset: Number(url.searchParams.get('offset')),
        retainedLimit: 7500,
        sort: (url.searchParams.get('sort') ?? 'relevance') as SearchResultList['sort'],
        sortChoices,
        coverage,
        items: [item({ documentId: 'd1', displayTitle: 'Telegram' })],
      }),
    });
    const { router } = renderAt('/search?keywords=treaty&offset=20');
    const orders = await screen.findByRole('group', { name: 'Sort' });
    const buttons = within(orders).getAllByRole('button');
    expect(buttons.map((button) => [button.textContent, button.getAttribute('aria-pressed'), button.title])).toEqual([
      ['Relevance', 'true', 'Sort results by BM25 relevance — best matches first'],
      ['Date ↑', 'false', 'Sort by document date, oldest first. Undated documents go to the end.'],
      ['Date ↓', 'false', 'Sort by document date, most recent first. Undated documents go to the end.'],
    ]);
    await userEvent.click(within(orders).getByRole('button', { name: 'Date ↑' }));
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ keywords: 'treaty', sort: 'dateAscending', offset: undefined }));
    expect(within(orders).getByRole('button', { name: 'Date ↑' }).getAttribute('aria-pressed')).toBe('true');
    await waitFor(() =>
      expect(fetch.mock.calls.map(([url]) => String(url))).toContain('/api/v1/search?keywords=treaty&sort=dateAscending&limit=20&offset=0'),
    );
    // Relevance is the default, which the address leaves out.
    await userEvent.click(within(orders).getByRole('button', { name: 'Relevance' }));
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ sort: undefined }));
  });

  it('says above the results, as the Mac’s window does, when the search keeps only part of its match', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search/inspect': { inspection: undefined },
      '/api/v1/search': (url: URL): SearchResultList => ({
        total: url.searchParams.get('keywords') === 'government' ? 20_000 : 7_499,
        countBasis: 'exact',
        limit: 20,
        offset: 0,
        retainedLimit: 7500,
        sort: 'relevance',
        sortChoices,
        coverage,
        items: [item({ documentId: 'd1', displayTitle: 'Telegram' })],
      }),
    });
    renderAt('/search?keywords=government&sort=dateAscending');
    expect(await screen.findByText('Showing 7,500 of 20,000 matches')).toBeTruthy();
    expect(screen.getByText('Narrow your search with a date range, volume filter, or more specific terms to load every match.')).toBeTruthy();
    cleanup();
    renderAt('/search?keywords=treaty');
    await screen.findByRole('link', { name: 'Telegram' });
    expect(screen.queryByText(/^Showing /)).toBeNull();
  });
});

describe('the researcher’s own writing in a search', () => {
  const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
  const berlin = { id: '5E17D000-0000-4000-8000-00000000000A', name: 'Berlin' };
  const cuba = { id: '5E17D000-0000-4000-8000-00000000000B', name: 'Cuba' };
  const laos = { id: '5E17D000-0000-4000-8000-00000000000C', name: 'Laos' };
  const wall = { id: '5E17D000-0000-4000-8000-00000000000D', name: 'Wall' };
  const list = (items: SearchItem[]): SearchResultList => ({
    total: items.length,
    countBasis: 'exact',
    limit: 20,
    offset: 0,
    retainedLimit: 7500,
    sort: 'relevance',
    sortChoices,
    coverage,
    items,
  });
  const server = (answers: Record<string, unknown> = {}) =>
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search/inspect': { inspection: undefined },
      '/api/v1/me': me,
      '/api/v1/me/tags': { total: 0, items: [] },
      '/api/v1/search': list([item({ displayTitle: 'Telegram' })]),
      ...answers,
    });
  const urls = (fetch: ReturnType<typeof stubServer>) => fetch.mock.calls.map(([url]) => String(url));

  it('offers Search in as the Mac’s chips, each turning its place off and on again', async () => {
    const fetch = server();
    const { router } = renderAt('/search?keywords=treaties');
    const group = await screen.findByRole('group', { name: 'Search in' });
    expect(within(group).getAllByRole('button').map((chip) => [chip.textContent, chip.getAttribute('aria-pressed'), chip.title])).toEqual([
      ['✓Documents', 'true', 'Search the full text of FRUS documents (header, dateline, source note, body)'],
      ['✓Notes', 'true', 'Search the body text of your research notes'],
      ['✓Summaries', 'true', 'Search the text of generated AI summaries and your own'],
    ]);
    await userEvent.click(within(group).getByRole('button', { name: 'Notes' }));
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ keywords: 'treaties', includeNotes: false }));
    expect(within(group).getByRole('button', { name: 'Notes' }).textContent).toBe('○Notes');
    await waitFor(() => expect(urls(fetch)).toContain('/api/v1/search?keywords=treaties&includeNotes=false&limit=20&offset=0'));
    await userEvent.click(within(group).getByRole('button', { name: 'Notes' }));
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ includeNotes: undefined }));
  });

  it('says, as the Mac’s window does, that a search with all of Search in off has nowhere to search, and asks for none', async () => {
    const fetch = server();
    renderAt('/search?keywords=treaties&includeDocumentText=false&includeNotes=false&includeSummaries=false');
    expect((await screen.findByRole('alert')).textContent).toBe('Enable at least one of Documents, Notes, or Summaries to search.');
    expect(urls(fetch).some((url) => url.startsWith('/api/v1/search?'))).toBe(false);
  });

  it('leaves Search in out where the server keeps no user data, unless a link turned a place off', async () => {
    server({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/search?keywords=treaties');
    await screen.findByRole('link', { name: 'Telegram' });
    expect(screen.queryByRole('group', { name: 'Search in' })).toBeNull();
    cleanup();
    renderAt('/search?keywords=treaties&includeNotes=false');
    expect(await screen.findByRole('group', { name: 'Search in' })).toBeTruthy();
  });

  it('lists My Tags, counts them once opened, filters by those switched on, and shows the filter as a token that clears it', async () => {
    const fetch = server({
      '/api/v1/me/tags': { total: 2, items: [berlin, cuba] },
      '/api/v1/me/search/tags': { items: [{ ...berlin, count: 1 }, { ...cuba, count: 0 }], coverage },
    });
    const { router } = renderAt('/search?keywords=treaties');
    const summary = await screen.findByText('My Tags');
    expect(summary.closest('summary')?.textContent).toBe('My Tags Any');
    expect(urls(fetch).some((url) => url.startsWith('/api/v1/me/search/tags'))).toBe(false);
    await userEvent.click(summary);
    const berlinSwitch = await screen.findByRole('checkbox', { name: 'Berlin: 1 documents in your current results' });
    expect(screen.getByRole('checkbox', { name: 'Cuba: 0 documents in your current results' })).toBeTruthy();
    expect(screen.getByText('Counts are documents in your current results carrying that tag.')).toBeTruthy();
    expect(urls(fetch)).toContain('/api/v1/me/search/tags?keywords=treaties');
    await userEvent.click(berlinSwitch);
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ userTagIds: [berlin.id], offset: undefined }));
    await waitFor(() => expect(urls(fetch)).toContain(`/api/v1/search?keywords=treaties&userTagIds=${berlin.id}&limit=20&offset=0`));
    expect(summary.closest('summary')?.textContent).toBe('My Tags 1 selected');
    const token = screen.getByRole('button', { name: 'Tags Berlin, clear this filter' });
    await userEvent.click(token);
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ userTagIds: undefined }));
    expect(document.activeElement).toBe(screen.getByRole('searchbox'));
  });

  it('names a filter of several tags, or of one the list does not name, by how many, as the Mac’s token does', async () => {
    server({ '/api/v1/me/tags': { total: 2, items: [berlin, cuba] } });
    renderAt(`/search?keywords=treaties&userTagIds=${berlin.id}&userTagIds=${cuba.id}`);
    expect(await screen.findByRole('button', { name: 'Tags 2 tags, clear this filter' })).toBeTruthy();
  });

  it('draws a row’s tags, the first three the user’s tags name, as the Mac’s ◆ chips', async () => {
    server({
      '/api/v1/me/tags': { total: 4, items: [berlin, cuba, laos, wall] },
      '/api/v1/search': list([
        item({ displayTitle: 'Telegram', userTagIds: [cuba.id, '5E17D000-0000-4000-8000-0000000000FF', berlin.id, wall.id, laos.id] }),
        item({ documentId: 'd2', displayTitle: 'Memorandum', userTagIds: [] }),
      ]),
    });
    renderAt('/search?keywords=treaties');
    const chips = within(await screen.findByRole('list', { name: 'Your tags' })).getAllByRole('listitem');
    expect(chips.map((chip) => chip.textContent)).toEqual(['◆ Cuba', '◆ Berlin', '◆ Wall']);
    expect(screen.getAllByRole('list', { name: 'Your tags' })).toHaveLength(1);
  });
});
