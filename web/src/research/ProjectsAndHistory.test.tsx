// Project Home, the History screen, the project picker and the trail's recording (PLAN's S17f), each
// as the app's view shows it, over a stubbed server.
import { QueryClient } from '@tanstack/react-query';
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { HistoryPage, ProjectHome } from '../api/research';
import type { ProjectList } from '../api/types';
import { createNote, createTag } from '../api/userData';
import { resetSearchHistory } from '../search/searchHistory';
import type { SearchState } from '../search/searchState';
import { me, sent } from '../test/notes';
import { preferences } from '../test/research';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

beforeEach(() => resetSearchHistory());

const grain = 'A0000000-0000-4000-8000-000000000001';
const berlin = 'A0000000-0000-4000-8000-000000000002';

const projects: ProjectList = {
  total: 2,
  items: [
    { id: berlin, name: 'Berlin', researchQuestion: 'How did the wall go up?', tally: 'Nothing filed yet' },
    { id: grain, name: 'Grain', tally: '1 note' },
  ],
  activeProjectId: berlin,
};

const home: ProjectHome = {
  project: { id: grain, name: 'Grain', researchQuestion: 'Why wheat?', defaultDateRangeStart: '1969-06-01T12:00:00.000Z' },
  isActive: true,
  counts: { collections: 0, notes: 1, documentsVisited: 2, searches: 3 },
  coverage: [
    { corpusId: 'C1', corpusName: 'Treaties', engagedCount: 1, totalCount: 2, untouched: '1 not yet opened', description: 'Treaties: 1 of 2', truncationWarns: false },
  ],
  hasTags: true,
  focusTags: [{ id: 'T1', name: 'Wheat' }],
  leads: [
    { id: 'L1', volumeId: 'frus1961-63v06', documentId: 'd2', title: 'Lead two', isNew: true, relatedCount: 2, isEditorialNote: true },
    { id: 'L2', volumeId: 'frus1961-63v06', documentId: 'd1', title: 'frus1961-63v06/d1', isNew: false, relatedCount: 1, isEditorialNote: false },
  ],
  recentVisits: [{ volumeId: 'frus1961-63v06', documentId: 'd1', title: 'A telegram' }],
  recentNotes: [{ id: 'N1', volumeId: 'frus1961-63v06', documentId: 'd2' }],
  recentSearches: [{ id: 'S1', queryText: 'treaties', resultCount: 1204 }],
  isEmpty: false,
};

function page(fields: Partial<HistoryPage> = {}): HistoryPage {
  return {
    scope: 'all',
    limit: 500,
    documents: [
      { id: 'V1', volumeId: 'frus1961-63v06', documentId: 'd1', title: 'A telegram', caption: 'frus1961-63v06 · d1', accessedAt: '2026-10-24T00:00:00.000Z' },
      { id: 'V2', volumeId: 'frus1961-63v06', documentId: 'd2', title: 'frus1961-63v06 · d2' },
    ],
    searches: [{ id: 'S1', queryText: '“cold war”', resultCount: 1204, count: '1,204', countBasis: 'exact', scope: 'whole corpus' }],
    exports: [{ id: 'E1', format: 'pdf', formatName: 'PDF', documentCount: 3, title: 'Grain' }],
    totalDocuments: 2,
    totalSearches: 600,
    totalExports: 1,
    projects: [{ id: grain, name: 'Grain' }],
    loggingEnabled: true,
    ...fields,
  };
}

describe('Project Home', () => {
  it('shows the project’s question, tiles, focus tags, leads and recent activity, as the app’s view does', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/projects': projects, '/api/v1/me/preferences': preferences,
      [`/api/v1/me/projects/${grain}/home`]: home });
    renderAt(`/projects/${grain}`);
    expect(await screen.findByRole('heading', { level: 1, name: 'Grain' })).toBeTruthy();
    expect((screen.getByRole('textbox', { name: 'Research question' }) as HTMLTextAreaElement).value).toBe('Why wheat?');
    expect(screen.getByText('From 1969')).toBeTruthy();
    expect(screen.getByText('Searches Run')).toBeTruthy();
    expect(screen.getByRole('listitem', { name: 'Treaties: Treaties: 1 of 2' }).textContent).toContain('1/2');
    const leads = within(screen.getByRole('region', { name: 'Suggested Next' }));
    expect(leads.getByRole('link', { name: 'Lead two' })).toBeTruthy();
    expect(leads.getByText('NEW')).toBeTruthy();
    expect(leads.getByText('Related to 2 of your documents · Editorial note')).toBeTruthy();
    expect(within(screen.getByRole('region', { name: 'Focus tags' })).getByText('Wheat')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'A telegram' }).getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    expect(screen.getByText('1,204 results')).toBeTruthy();
  });

  it('dismisses a lead, the focus going on to the next, and saves the question as it is typed, trimmed', async () => {
    let dismissed = false;
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/projects': projects,
      '/api/v1/me/preferences': preferences,
      [`/api/v1/me/projects/${grain}/home`]: () => (dismissed ? { ...home, leads: home.leads.slice(1) } : home),
      [`POST /api/v1/me/projects/${grain}/leads/L1/dismiss`]: () => {
        dismissed = true;
        return null;
      },
      [`PATCH /api/v1/me/projects/${grain}`]: (_: URL, init?: RequestInit) => ({ ...home.project, researchQuestion: sent(init).body.researchQuestion }),
    });
    const user = userEvent.setup();
    renderAt(`/projects/${grain}`);
    await user.click(await screen.findByRole('button', { name: 'Dismiss this lead: Lead two' }));
    await waitFor(() => expect(screen.queryByRole('link', { name: 'Lead two' })).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Dismiss this lead: frus1961-63v06/d1' })));

    const question = screen.getByRole('textbox', { name: 'Research question' });
    await user.clear(question);
    await user.type(question, '  Why grain?  ');
    await user.tab();
    await waitFor(() =>
      expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith(`/projects/${grain}`) && sent(init).body?.researchQuestion === 'Why grain?')).toBe(true),
    );
  });

  it('keeps each project’s question its own as the route moves between projects already read', async () => {
    const berlinHome: ProjectHome = { ...home, project: { id: berlin, name: 'Berlin', researchQuestion: 'How did the wall go up?' } };
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/projects': projects, '/api/v1/me/preferences': preferences,
      [`/api/v1/me/projects/${grain}/home`]: home, [`/api/v1/me/projects/${berlin}/home`]: berlinHome });
    const { router } = renderAt(`/projects/${grain}`);
    const question = () => (screen.getByRole('textbox', { name: 'Research question' }) as HTMLTextAreaElement).value;
    expect(await screen.findByRole('heading', { level: 1, name: 'Grain' })).toBeTruthy();
    await router.navigate({ to: '/projects/$projectId', params: { projectId: berlin } });
    expect(await screen.findByRole('heading', { level: 1, name: 'Berlin' })).toBeTruthy();
    await waitFor(() => expect(question()).toBe('How did the wall go up?'));
    // Grain's Home is read already, so it shows at once, with Grain's question and not Berlin's.
    await router.navigate({ to: '/projects/$projectId', params: { projectId: grain } });
    expect(await screen.findByRole('heading', { level: 1, name: 'Grain' })).toBeTruthy();
    expect(question()).toBe('Why wheat?');
  });

  it('sends the question again once the server has refused it', async () => {
    const bodies: unknown[] = [];
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/projects': projects,
      '/api/v1/me/preferences': preferences,
      [`/api/v1/me/projects/${grain}/home`]: home,
      [`PATCH /api/v1/me/projects/${grain}`]: (_: URL, init?: RequestInit) => {
        bodies.push(sent(init).body);
        return bodies.length === 1
          ? new ProblemAnswer(500, 'INTERNAL_ERROR', 'The question was not saved.')
          : { ...home.project, researchQuestion: sent(init).body.researchQuestion };
      },
    });
    const user = userEvent.setup();
    renderAt(`/projects/${grain}`);
    const question = await screen.findByRole('textbox', { name: 'Research question' });
    await user.clear(question);
    await user.type(question, 'Why grain?');
    await user.tab();
    expect(await screen.findByText('The question was not saved.')).toBeTruthy();
    // The same words, left again: not saved, so sent again.
    await user.click(question);
    await user.tab();
    await waitFor(() => expect(bodies).toEqual([{ researchQuestion: 'Why grain?' }, { researchQuestion: 'Why grain?' }]));
  });

  it('says there is no project for one the server holds none of', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, [`/api/v1/me/projects/${grain}/home`]: new ProblemAnswer(404, 'PROJECT_NOT_FOUND', 'You have no project with the id.') });
    renderAt(`/projects/${grain}`);
    expect(await screen.findByRole('heading', { name: 'No Project Selected' })).toBeTruthy();
  });
});

describe('the project picker', () => {
  it('lists Global Context and the projects in the reader’s own order, and chooses one, with "Working on:" over Search', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/projects': projects,
      '/api/v1/me/preferences': { ...preferences, projectOrder: [grain] },
      'PUT /api/v1/me/active-project': (_: URL, init?: RequestInit) => ({ projectId: sent(init).body.projectId ?? undefined }),
      '/api/v1/search': new ProblemAnswer(503, 'NOT_READY', 'No index.'),
    });
    const user = userEvent.setup();
    renderAt('/search');
    const picker = (await screen.findByRole('combobox', { name: 'Switch project context' })) as HTMLSelectElement;
    await waitFor(() => expect([...picker.options].map((option) => option.text)).toEqual(['Global Context', 'Grain', 'Berlin']));
    expect(picker.value).toBe(berlin);
    expect(screen.getByText('How did the wall go up?')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Project Home' }).getAttribute('href')).toBe(`/projects/${berlin}`);
    await user.selectOptions(picker, '');
    await waitFor(() => expect(fetch.mock.calls.some(([url, init]) => String(url).endsWith('/active-project') && sent(init).body.projectId === null)).toBe(true));
  });
});

describe('the project picker’s choice', () => {
  it('shows a project chosen at once, in the picker and its Project Home, before the server answers it', async () => {
    let answer: (given: unknown) => void = () => {};
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/projects': projects,
      '/api/v1/me/preferences': preferences,
      'PUT /api/v1/me/active-project': () => new Promise((resolve) => (answer = resolve)),
      '/api/v1/search': new ProblemAnswer(503, 'NOT_READY', 'No index.'),
    });
    const user = userEvent.setup();
    renderAt('/search');
    const picker = (await screen.findByRole('combobox', { name: 'Switch project context' })) as HTMLSelectElement;
    await waitFor(() => expect(picker.value).toBe(berlin));
    await user.selectOptions(picker, grain);
    expect(picker.value).toBe(grain);
    expect(screen.getByRole('link', { name: 'Project Home' }).getAttribute('href')).toBe(`/projects/${grain}`);
    answer({ projectId: grain });
    await waitFor(() => expect(screen.getByRole('link', { name: 'Project Home' }).getAttribute('href')).toBe(`/projects/${grain}`));
  });
});

describe('the History screen', () => {
  it('shows each section with its count, filters the page loaded, and says when logging is off', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/history': page({ loggingEnabled: false }) });
    const user = userEvent.setup();
    renderAt('/research/history');
    expect(await screen.findByRole('heading', { level: 1, name: 'History' })).toBeTruthy();
    const searches = within(await screen.findByRole('region', { name: 'Searches Executed' }));
    expect(searches.getByText('Showing 1 of 600')).toBeTruthy();
    expect(searches.getByRole('link', { name: '“cold war”' }).getAttribute('href')).toBe('/search?keywords=%E2%80%9Ccold+war%E2%80%9D');
    expect(searches.getByText(/1,204 results/)).toBeTruthy();
    expect(searches.getByRole('button', { name: 'Show More' })).toBeTruthy();
    expect(screen.getByText(/Research logging is off, so new activity is not being recorded/)).toBeTruthy();
    expect(within(screen.getByRole('region', { name: 'Collections Exported' })).getByText('PDF · 3 documents')).toBeTruthy();

    await user.type(screen.getByRole('searchbox', { name: 'Search history' }), '"cold');
    expect(searches.getByRole('link', { name: '“cold war”' })).toBeTruthy();
    const documents = within(screen.getByRole('region', { name: 'Documents Visited' }));
    expect(documents.getByText('No Matches')).toBeTruthy();
  });

  it('deletes a row at once, and asks for the page of the scope chosen', async () => {
    let deleted = false;
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/history': () => (deleted ? page({ documents: page().documents.slice(1), totalDocuments: 1 }) : page()),
      'DELETE /api/v1/me/history/documents/V1': () => {
        deleted = true;
        return null;
      },
    });
    const user = userEvent.setup();
    renderAt('/research/history');
    await user.click(await screen.findByRole('button', { name: 'Delete A telegram' }));
    await waitFor(() => expect(screen.queryByRole('link', { name: 'A telegram' })).toBeNull());
    // The focus goes on to the next row's Delete.
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Delete frus1961-63v06 · d2' })));
    await user.selectOptions(screen.getByRole('combobox', { name: 'Project' }), grain);
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes(`scope=${grain}`))).toBe(true));
  });
});

describe('History’s Show More and its way in', () => {
  it('keeps the focus on Show More as the next rows come', async () => {
    const row = (n: number) => ({ id: `V${n}`, volumeId: 'frus1961-63v06', documentId: `d${n}`, title: `Document ${n}` });
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/history': (url: URL) => {
        const limit = Number(url.searchParams.get('limit'));
        const documents = limit > 500 ? [row(1), row(2), row(3)] : [row(1), row(2)];
        return page({ limit, documents, totalDocuments: 4, searches: [], totalSearches: 0, exports: [], totalExports: 0 });
      },
    });
    const user = userEvent.setup();
    renderAt('/research/history');
    const documents = within(await screen.findByRole('region', { name: 'Documents Visited' }));
    await user.click(documents.getByRole('button', { name: 'Show More' }));
    expect(await documents.findByRole('link', { name: 'Document 3' })).toBeTruthy();
    expect(document.activeElement).toBe(documents.getByRole('button', { name: 'Show More' }));
  });

  it('is reached from All Notes, beside it under Research', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/notes': { total: 0, items: [] },
      '/api/v1/me/projects': projects,
      '/api/v1/me/tags': { total: 0, items: [] },
      '/api/v1/me/preferences': preferences,
    });
    renderAt('/research/notes');
    const nav = within(await screen.findByRole('navigation', { name: 'Research' }));
    expect(nav.getByRole('link', { name: 'History' }).getAttribute('href')).toBe('/research/history');
    expect(nav.getByRole('link', { name: 'All Notes' }).getAttribute('aria-current')).toBe('page');
  });
});

describe('Project Home’s freshness', () => {
  it('is read again after a note, or a tag, changes', async () => {
    stubServer({
      '/api/v1/me': me,
      'POST /api/v1/me/tags': { id: 'T9', name: 'Grain' },
      'POST /api/v1/me/volumes/frus1961-63v06/documents/d1/notes': { id: 'N9', volumeId: 'frus1961-63v06', documentId: 'd1' },
    });
    const client = new QueryClient();
    client.setQueryData(['projectHome', grain], home);
    await createTag(client, 'Grain');
    expect(client.getQueryState(['projectHome', grain])?.isInvalidated).toBe(true);
    client.setQueryData(['projectHome', grain], home);
    client.setQueryData(['projects'], projects);
    await createNote(client, 'frus1961-63v06', 'd1', { bodyText: 'Wheat', runs: null, userTagIds: [], projectIds: [grain], selectedSummaryIds: [] });
    expect(client.getQueryState(['projectHome', grain])?.isInvalidated).toBe(true);
    expect(client.getQueryState(['projects'])?.isInvalidated).toBe(true);
  });
});

describe('the trail’s recording', () => {
  it('records a search the screen shows once, with the anchor the server gives, and not again for its next page', async () => {
    const bodies: unknown[] = [];
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search': { total: 30, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, coverage, items: [] },
      'POST /api/v1/me/history/searches': (_: URL, init?: RequestInit) => {
        bodies.push(sent(init).body);
        return { outcome: 'inserted', anchor: { entryId: 'R1', queryText: 'wheat' } };
      },
    });
    const { router } = renderAt('/search?keywords=wheat');
    await waitFor(() => expect(bodies).toHaveLength(1));
    expect(bodies[0]).toEqual({ search: 'keywords=wheat' });
    await router.navigate({ to: '/search', search: { keywords: 'wheat', offset: 20 } });
    await router.navigate({ to: '/search', search: { keywords: 'wheat', documentType: 'documentsOnly' } });
    await waitFor(() => expect(bodies).toHaveLength(2));
    expect(bodies[1]).toEqual({ search: 'keywords=wheat&documentType=documentsOnly', anchor: { entryId: 'R1', queryText: 'wheat' } });
  });

  it('sends each record once the one before it is answered, with the anchor that answer gave', async () => {
    const bodies: unknown[] = [];
    let answerFirst: (given: unknown) => void = () => {};
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search': { total: 30, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, coverage, items: [] },
      'POST /api/v1/me/history/searches': (_: URL, init?: RequestInit) => {
        bodies.push(sent(init).body);
        if (bodies.length === 1) return new Promise((resolve) => (answerFirst = resolve));
        return { outcome: 'refreshed', anchor: { entryId: 'R1', queryText: 'wheat' } };
      },
    });
    const { router } = renderAt('/search?keywords=wheat');
    await waitFor(() => expect(bodies).toHaveLength(1));
    // A refinement shown while the first record waits for its answer: its record waits too.
    await router.navigate({ to: '/search', search: { keywords: 'wheat', documentType: 'documentsOnly' } });
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes('documentType=documentsOnly'))).toBe(true));
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(bodies).toHaveLength(1);
    answerFirst({ outcome: 'inserted', anchor: { entryId: 'R1', queryText: 'wheat' } });
    await waitFor(() => expect(bodies).toHaveLength(2));
    expect(bodies[1]).toEqual({ search: 'keywords=wheat&documentType=documentsOnly', anchor: { entryId: 'R1', queryText: 'wheat' } });
  });

  it('keeps the anchor and the run recorded last for the tab’s session, so a reload records nothing again', async () => {
    const bodies: unknown[] = [];
    stubServer({
      '/api/v1/me': me,
      'POST /api/v1/me/history/searches': (_: URL, init?: RequestInit) => {
        bodies.push(sent(init).body);
        return { outcome: 'inserted', anchor: { entryId: 'R1', queryText: 'wheat' } };
      },
    });
    const first = await import('../search/searchHistory');
    first.recordSearchRun(new QueryClient(), { keywords: 'wheat' } as SearchState);
    await waitFor(() => expect(bodies).toHaveLength(1));
    await waitFor(() => expect(window.sessionStorage.getItem('frus.search.trail')).toContain('R1'));
    // The page loaded again: the module afresh, the tab's storage as it was.
    vi.resetModules();
    const reloaded = await import('../search/searchHistory');
    reloaded.recordSearchRun(new QueryClient(), { keywords: 'wheat' } as SearchState);
    reloaded.recordSearchRun(new QueryClient(), { keywords: 'wheat', documentType: 'documentsOnly' } as SearchState);
    await waitFor(() => expect(bodies).toHaveLength(2));
    expect(bodies[1]).toEqual({ search: 'keywords=wheat&documentType=documentsOnly', anchor: { entryId: 'R1', queryText: 'wheat' } });
  });
});
