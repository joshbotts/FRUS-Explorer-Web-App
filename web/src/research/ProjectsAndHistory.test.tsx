// Project Home, the History screen, the project picker and the trail's recording (PLAN's S17f), each
// as the app's view shows it, over a stubbed server.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { HistoryPage, ProjectHome } from '../api/research';
import type { ProjectList } from '../api/types';
import { resetSearchHistory } from '../search/searchHistory';
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
    await user.selectOptions(screen.getByRole('combobox', { name: 'Project' }), grain);
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes(`scope=${grain}`))).toBe(true));
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
});
