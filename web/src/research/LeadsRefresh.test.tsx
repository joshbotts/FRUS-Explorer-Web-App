// Suggested Next's Refresh (PLAN's S23d): the server finds a project's leads again, as a job, with this
// browser's tuning for a project with none of its own; Project Home says it finds them, and reads its
// leads again until they are found; a Refresh the server refuses, or a computation that failed, says why.
import { cleanup, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ProjectHome } from '../api/research';
import type { ProjectList } from '../api/types';
import { me, sent } from '../test/notes';
import { preferences } from '../test/research';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

beforeEach(() => localStorage.clear());

const grain = 'A0000000-0000-4000-8000-000000000001';
const projects: ProjectList = { total: 1, items: [{ id: grain, name: 'Grain', tally: '1 note' }], activeProjectId: grain };

const home: ProjectHome = {
  project: { id: grain, name: 'Grain' },
  isActive: true,
  counts: { collections: 1, notes: 1, documentsVisited: 0, searches: 0 },
  coverage: [],
  hasTags: false,
  focusTags: [],
  leads: [{ id: 'L1', volumeId: 'frus1961-63v06', documentId: 'd2', title: 'Lead two', isNew: true, relatedCount: 2, isEditorialNote: false }],
  recentVisits: [],
  recentNotes: [],
  recentSearches: [],
  isEmpty: false,
};

const base = { '/readyz': ready, '/api/v1/me': me, '/api/v1/me/projects': projects, '/api/v1/me/preferences': preferences };

describe('Suggested Next’s Refresh', () => {
  it('asks the server to find the leads, with this browser’s tuning, says it finds them, and shows them once found', async () => {
    localStorage.setItem('frus.related.weights', 'sharedPersons:0.2');
    let reads = 0;
    let asked = false;
    const fetch = stubServer({
      ...base,
      [`/api/v1/me/projects/${grain}/home`]: () => {
        if (!asked) return home;
        reads += 1;
        // Found on the third read after the Refresh: the job waits, runs, then has ended.
        return reads < 3
          ? { ...home, leadsRefresh: { state: reads === 1 ? 'queued' : 'running' } }
          : {
              ...home,
              leads: [{ id: 'L9', volumeId: 'frus1961-63v06', documentId: 'd9', title: 'A new lead', isNew: true, relatedCount: 1, isEditorialNote: false }],
              leadsRefresh: { state: 'succeeded', finishedAt: '2026-11-11T12:00:00.000Z' },
            };
      },
      [`POST /api/v1/me/projects/${grain}/leads/refresh`]: () => {
        asked = true;
        return { state: 'queued' };
      },
    });
    const user = userEvent.setup();
    renderAt(`/projects/${grain}`);
    const refresh = await screen.findByRole('button', { name: 'Refresh' });
    await user.click(refresh);
    const post = fetch.mock.calls.find(([url, init]) => String(url).endsWith('/leads/refresh') && init?.method === 'POST');
    expect(sent(post?.[1]).body).toEqual({ weights: 'sharedPersons:0.2' });
    expect(await screen.findByText('Finding leads…')).toBeTruthy();
    // Refresh stays where it was, and keeps the focus, while the leads are found.
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Refresh' }));
    expect(screen.getByRole('button', { name: 'Refresh' }).getAttribute('aria-disabled')).toBe('true');
    expect(await screen.findByRole('link', { name: 'A new lead' }, { timeout: 8000 })).toBeTruthy();
    await waitFor(() => expect(screen.queryByText('Finding leads…')).toBeNull());
    expect(screen.getByRole('button', { name: 'Refresh' }).getAttribute('aria-disabled')).toBe('false');
  }, 15_000);

  it('sends no tuning when this browser keeps none, and says why the server refused', async () => {
    const fetch = stubServer({
      ...base,
      [`/api/v1/me/projects/${grain}/home`]: home,
      [`POST /api/v1/me/projects/${grain}/leads/refresh`]: new ProblemAnswer(
        503,
        'INDEX_NOT_READY',
        'No index is served, so Suggested Next cannot be computed: its leads are kept as they are.',
      ),
    });
    const user = userEvent.setup();
    renderAt(`/projects/${grain}`);
    await user.click(await screen.findByRole('button', { name: 'Refresh' }));
    expect((await screen.findByRole('alert')).textContent).toMatch(/No index is served/);
    const post = fetch.mock.calls.find(([url, init]) => String(url).endsWith('/leads/refresh') && init?.method === 'POST');
    expect(sent(post?.[1]).body).toEqual({});
  });

  it('says why the last computation failed', async () => {
    stubServer({
      ...base,
      [`/api/v1/me/projects/${grain}/home`]: { ...home, leadsRefresh: { state: 'failed', error: 'No index is served, so the project’s leads were kept as they were.' } },
    });
    renderAt(`/projects/${grain}`);
    expect((await screen.findByRole('alert')).textContent).toBe(
      'Suggested Next could not be refreshed: No index is served, so the project’s leads were kept as they were.',
    );
  });
});
