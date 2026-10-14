import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SearchFacetSection, SearchItem, SearchResultList } from '../api/types';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function item(documentId: string, header: string): SearchItem {
  return {
    volumeId: 'frus1961-63v06',
    documentId,
    header,
    displayTitle: header,
    documentLabel: `Doc ${documentId.slice(1)}`,
    headerRepeatsNumber: false,
    snippet: 'the <b>treaties</b>',
    bm25Score: -1,
    isEditorialNote: false,
    isFrontMatter: false,
    subjectTagIds: [],
    userTagIds: [],
  };
}

function results(total: number): SearchResultList {
  const items = [item('d1', 'Telegram'), item('d2', 'Memorandum'), item('d3', 'Letter')].slice(0, total);
  return { total, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, coverage, items };
}

const pageSizeChoices = [
  { value: 'top5', title: 'Top 5' },
  { value: 'top10', title: 'Top 10' },
  { value: 'top25', title: 'Top 25' },
  { value: 'all', title: 'Show all' },
];

function section(
  fields: Partial<SearchFacetSection> & Pick<SearchFacetSection, 'section' | 'selection' | 'rows'>,
): SearchFacetSection {
  return {
    matchCount: 3,
    page: { matchingCount: fields.rows.length, totalCount: fields.rows.length, pageIndex: 0, pageCount: 1, firstRowNumber: 1 },
    display: { sort: 'count', pageSize: 'all', page: 0, filter: '' },
    sortChoices: [],
    pageSizeChoices,
    coverage,
    ...fields,
  };
}

const years = section({
  section: 'years',
  selection: 'staged',
  rows: [
    { key: '1960', label: '1960', count: 2 },
    { key: '1894', label: '1894', count: 1 },
  ],
  undatedCount: 4,
  display: { sort: 'labelDescending', pageSize: 'all', page: 0, filter: '' },
  sortChoices: [
    { value: 'count', title: 'Most documents' },
    { value: 'labelAscending', title: 'Oldest first' },
    { value: 'labelDescending', title: 'Newest first' },
  ],
});

const people = section({
  section: 'people',
  selection: 'immediate',
  rows: [
    {
      key: '1',
      label: 'Khrushchev, Nikita Sergeyevich',
      count: 2,
      narrowing: { personRollupId: ['1'], personLabel: ['Khrushchev, Nikita Sergeyevich'] },
    },
  ],
});

const subjects = section({
  section: 'subjects',
  selection: 'immediate',
  rows: [{ key: '40', label: 'Berlin', count: 2, narrowing: { subjectBucket: ['40'], subjectBucketKey: ['Germany/Berlin'] } }],
  subjectCoverage: 2,
  subjectsPrepared: true,
});

const documentTypes = section({
  section: 'documentType',
  selection: 'immediate',
  rows: [{ key: '0', label: '0', count: 3, narrowing: { documentType: ['documentsOnly'] } }],
});

/** A server whose search counts 1 once narrowed, and whose sections are those above. */
function server(answers: Record<string, unknown> = {}) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/search': (url: URL) =>
      results(['yearKeys', 'personRollupId', 'subjectBucket'].some((name) => url.searchParams.has(name)) ? 1 : 3),
    '/api/v1/search/facets': (url: URL) =>
      ({ years, people, subjects, documentType: documentTypes })[url.searchParams.get('section') ?? ''] ??
      section({ section: 'volumes', selection: 'staged', rows: [] }),
    '/api/v1/search/facets/selection': { section: 'years', keys: ['1894'], change: { yearKeys: ['1894'] }, coverage },
    ...answers,
  });
}

/** The search the route holds, checked, as the screen reads it. */
const searchOf = (router: ReturnType<typeof renderAt>['router']) => (router.state.matches.at(-1)?.search ?? {}) as Record<string, unknown>;

const facetRequests = (fetch: ReturnType<typeof server>) =>
  fetch.mock.calls.map(([url]) => String(url)).filter((url) => url.includes('/api/v1/search/facets'));

describe('the facet panel', () => {
  it('opens beside the results from its toggle, and computes nothing until a section is opened', async () => {
    const fetch = server();
    const { router } = renderAt('/search?keywords=negotiating+OR+canal');
    const toggle = await screen.findByRole('button', { name: 'Facets' });
    await waitFor(() => expect(toggle.hasAttribute('disabled')).toBe(false));
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    await userEvent.click(toggle);
    await waitFor(() => expect(searchOf(router)).toMatchObject({ panel: 'facets' }));
    const panel = screen.getByRole('complementary', { name: 'Result-set facets' });
    expect(panel.textContent).toContain('Describing all 3 matches');
    expect(within(panel).getAllByRole('button').map((button) => button.textContent)).toEqual([
      '▸ Years',
      '▸ Volumes',
      '▸ People',
      '▸ Document type',
      '▸ Archival provenance',
      '▸ Subjects',
    ]);
    expect(facetRequests(fetch)).toEqual([]);
  });

  it('stages years to include and exclude, and applies them as the server resolves them', async () => {
    const fetch = server();
    const { router } = renderAt('/search?keywords=negotiating+OR+canal&panel=facets');
    const panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'Years' }));
    await userEvent.click(await within(panel).findByRole('button', { name: '1894 1, Not selected' }));
    expect(within(panel).getByRole('button', { name: '1894 1, Included' })).toBeTruthy();
    expect(panel.textContent).toContain('1 included');
    // Clear drops the staged rows and the strip with them, so focus goes back to the section.
    await userEvent.click(within(panel).getByRole('button', { name: 'Clear' }));
    expect(panel.textContent).not.toContain('1 included');
    expect(document.activeElement).toBe(within(panel).getByRole('button', { name: 'Years' }));
    await userEvent.click(within(panel).getByRole('button', { name: '1894 1, Not selected' }));
    // Twice: included, then excluded.
    await userEvent.click(within(panel).getByRole('button', { name: '1960 2, Not selected' }));
    await userEvent.click(within(panel).getByRole('button', { name: '1960 2, Included' }));
    expect(within(panel).getByRole('button', { name: '1960 2, Excluded' })).toBeTruthy();
    expect(panel.textContent).toContain('1 included · 1 excluded');
    expect(panel.textContent).toContain('4 matched documents carry no date and appear in no year above.');

    await userEvent.click(within(panel).getByRole('button', { name: 'Apply' }));
    await waitFor(() => expect(searchOf(router)).toMatchObject({ yearKeys: ['1894'], panel: 'facets' }));
    const selection = facetRequests(fetch).find((url) => url.includes('/facets/selection'));
    expect(selection).toMatch(/[?&]section=years(&|$)/);
    expect(selection).toMatch(/[?&]include=1894(&|$)/);
    expect(selection).toMatch(/[?&]exclude=1960(&|$)/);
    // The filter shows as a token, and the count says what it narrowed from.
    expect(await screen.findByRole('button', { name: 'Years 1894, clear this filter' })).toBeTruthy();
    await waitFor(() => expect(screen.getByText(/narrowed from 3/)).toBeTruthy());
    // A new search clears the staged rows; the section is computed again.
    await waitFor(() => expect(within(panel).queryByText('1 included · 1 excluded')).toBeNull());
  });

  it('narrows to a person on a click, as the server says the row narrows, and the token clears it', async () => {
    server();
    const { router } = renderAt('/search?keywords=negotiating+OR+canal&panel=facets');
    const panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'People' }));
    await userEvent.click(await within(panel).findByRole('button', { name: 'Khrushchev, Nikita Sergeyevich 2' }));
    await waitFor(() =>
      expect(searchOf(router)).toMatchObject({ personRollupId: '1', personLabel: 'Khrushchev, Nikita Sergeyevich' }),
    );
    // Focus is back on the section, whose rows are counted again for the narrowed search.
    expect(document.activeElement).toBe(within(panel).getByRole('button', { name: 'People' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Person Khrushchev, Nikita Sergeyevich, clear this filter' }));
    await waitFor(() => expect(searchOf(router).personRollupId).toBeUndefined());
    expect(searchOf(router).personLabel).toBeUndefined();
    // The token went with its filter, so focus is on the search box.
    expect(document.activeElement).toBe(screen.getByRole('searchbox', { name: 'Search the documents' }));
  });

  it('keeps a subject’s name from its row, and names a document type as the Mac does', async () => {
    server();
    const { router } = renderAt('/search?keywords=negotiating+OR+canal&panel=facets');
    const panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'Document type' }));
    await userEvent.click(await within(panel).findByRole('button', { name: 'Documents 3' }));
    await waitFor(() => expect(searchOf(router).documentType).toBe('documentsOnly'));
    // The match is no smaller, so the count does not say it narrowed, as the Mac's does not.
    await waitFor(() => expect(document.body.textContent).toContain('3 documents match'));
    expect(document.body.textContent).not.toContain('narrowed from');
    await userEvent.click(within(panel).getByRole('button', { name: 'Subjects' }));
    expect(panel.textContent).toContain('Subjects detected for 2 of 3 matches.');
    await userEvent.click(await within(panel).findByRole('button', { name: 'Berlin 2' }));
    await waitFor(() =>
      expect(searchOf(router)).toMatchObject({ subjectBucket: '40', subjectBucketKey: 'Germany/Berlin', subjectLabel: 'Berlin' }),
    );
    expect(await screen.findByRole('button', { name: 'Subject Berlin, clear this filter' })).toBeTruthy();
  });

  it('asks the server for a section’s next sort and page, and says when a breakdown fails', async () => {
    const pages = section({
      ...people,
      rows: people.rows,
      page: { matchingCount: 30, totalCount: 30, pageIndex: 0, pageCount: 2, firstRowNumber: 1 },
      display: { sort: 'count', pageSize: 'top25', page: 0, filter: '' },
      sortChoices: [
        { value: 'count', title: 'Most documents' },
        { value: 'labelAscending', title: 'A–Z' },
      ],
    });
    const fetch = server({
      '/api/v1/search/facets': (url: URL) =>
        url.searchParams.get('section') === 'people' ? pages : new ProblemAnswer(400, 'INVALID_PARAMETER', 'The breakdown failed.'),
    });
    renderAt('/search?keywords=negotiating+OR+canal&panel=facets');
    const panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'People' }));
    expect(await within(panel).findByText('Showing 1–1 of 30')).toBeTruthy();
    await userEvent.selectOptions(within(panel).getByRole('combobox', { name: 'Sort order' }), 'labelAscending');
    await waitFor(() => expect(facetRequests(fetch).some((url) => /[?&]facetSort=labelAscending(&|$)/.test(url))).toBe(true));
    await userEvent.click(within(panel).getByRole('button', { name: 'Next page' }));
    await waitFor(() => expect(facetRequests(fetch).some((url) => /[?&]facetPage=1(&|$)/.test(url))).toBe(true));

    await userEvent.click(within(panel).getByRole('button', { name: 'Volumes' }));
    expect((await within(panel).findByRole('alert')).textContent).toContain('This breakdown could not be computed.');
  });

  it('counts a section again when its rows have changed since they were counted', async () => {
    let refused = false;
    const fetch = server({
      '/api/v1/search/facets/selection': () => {
        refused = true;
        return new ProblemAnswer(409, 'SECTION_CHANGED', '1894 is not a row of years for this search.');
      },
    });
    const { router } = renderAt('/search?keywords=negotiating+OR+canal&panel=facets');
    const panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'Years' }));
    await userEvent.click(await within(panel).findByRole('button', { name: '1894 1, Not selected' }));
    const before = facetRequests(fetch).filter((url) => url.includes('section=years') && !url.includes('/selection')).length;
    await userEvent.click(within(panel).getByRole('button', { name: 'Apply' }));
    expect((await within(panel).findByRole('alert')).textContent).toContain('counted again');
    expect(refused).toBe(true);
    // The search is as it was, the choice is dropped, and the section is asked for again.
    expect(searchOf(router).yearKeys).toBeUndefined();
    expect(within(panel).getByRole('button', { name: '1894 1, Not selected' })).toBeTruthy();
    await waitFor(() =>
      expect(facetRequests(fetch).filter((url) => url.includes('section=years') && !url.includes('/selection')).length).toBe(before + 1),
    );
  });

  it('says there is nothing to break down for a query with nothing left to search', async () => {
    server({
      '/api/v1/search/facets': new ProblemAnswer(400, 'EMPTY_QUERY', 'Nothing is left to search.'),
    });
    renderAt('/search?keywords=negotiating+OR+canal&panel=facets');
    const panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'Years' }));
    expect(await within(panel).findByText('Nothing to break down here.')).toBeTruthy();
  });

  it('says how much the three largest volumes hold only of a match the app keeps whole, as the Mac says it', async () => {
    let matchCount = 3;
    server({
      '/api/v1/search': () => results(3),
      '/api/v1/search/facets': () =>
        section({ section: 'volumes', selection: 'staged', rows: [{ key: 'frus1961-63v06', label: 'Volume VI', count: 2 }], topVolumeShare: 0.6, matchCount }),
    });
    renderAt('/search?keywords=treaty&panel=facets');
    let panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'Volumes' }));
    await waitFor(() => expect(panel.textContent).toContain('The top three hold 60% of the match.'));
    cleanup();

    // A match of 7,500 or more is more than the app keeps, and the figure is not given of it.
    matchCount = 7_500;
    renderAt('/search?keywords=treaty&panel=facets');
    panel = await screen.findByRole('complementary', { name: 'Result-set facets' });
    await userEvent.click(within(panel).getByRole('button', { name: 'Volumes' }));
    await within(panel).findByRole('button', { name: /^Volume VI 2/ });
    expect(panel.textContent).not.toContain('The top three hold');
  });
});
