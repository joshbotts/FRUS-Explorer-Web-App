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
