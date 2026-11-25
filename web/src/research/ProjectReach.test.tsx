// Project Home's Beyond your library (PLAN's S26d), over a stubbed server: under Suggested Next, the volumes the project
// reaches that the server does not serve, read with this browser's tuning, each opening its page in Browse with its
// documents and how many of the project's reached it; nothing while the reach found no volume, or could not be read.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ProjectReach } from '../api/reach';
import type { ProjectHome } from '../api/research';
import type { ProjectList } from '../api/types';
import { me } from '../test/notes';
import { preferences } from '../test/research';
import { type Answer, ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

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
  counts: { collections: 0, notes: 1, documentsVisited: 0, searches: 0 },
  coverage: [],
  hasTags: false,
  focusTags: [],
  leads: [{ id: 'L1', volumeId: 'frus1961-63v06', documentId: 'd2', title: 'Lead two', isNew: true, relatedCount: 1, isEditorialNote: false }],
  recentVisits: [],
  recentNotes: [],
  recentSearches: [],
  isEmpty: false,
};
const base = { '/readyz': ready, '/api/v1/me': me, '/api/v1/me/projects': projects, '/api/v1/me/preferences': preferences };
const path = `/api/v1/me/projects/${grain}/reach`;

describe('Project Home’s Beyond your library', () => {
  it('lists the volumes the project reaches under Suggested Next, read with this browser’s tuning', async () => {
    localStorage.setItem('frus.related.weights', 'semanticSimilarity:0.9');
    const reach: ProjectReach = {
      volumes: [
        { volumeId: 'frus1961-63v05', title: 'Foreign Relations,\n  1961–1963, Volume V, Soviet Union', documentCount: 31, reachingSeeds: 1 },
        { volumeId: 'frus1961-63v15', title: 'Berlin Crisis, 1962–1963', documentCount: 1, reachingSeeds: 1 },
      ],
      documentCount: 32,
      seedsProbed: 1,
    };
    const fetch = stubServer({ ...base, [`/api/v1/me/projects/${grain}/home`]: home, [path]: reach });
    renderAt(`/projects/${grain}`);
    const heading = await screen.findByRole('heading', { level: 2, name: 'Beyond your library' });
    const section = heading.closest('section')!;
    // Under Suggested Next, as the app places it.
    const suggested = screen.getByRole('heading', { level: 2, name: 'Suggested Next' });
    expect(suggested.compareDocumentPosition(heading) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(
      within(section).getByText(
        "32 documents in volumes this server does not serve read as close to one of this project's 1 document as that document's nearest neighbours on this server.",
      ),
    ).toBeTruthy();
    const soviet = within(section).getByRole('link', { name: 'Foreign Relations, 1961–1963, Volume V, Soviet Union' });
    expect(soviet.getAttribute('href')).toBe('/browse/frus1961-63v05');
    expect(soviet.closest('li')!.textContent).toContain('31 documents · reached from 1 of yours');
    expect(within(section).getByRole('link', { name: 'Berlin Crisis, 1962–1963' }).closest('li')!.textContent).toContain(
      '1 document · reached from 1 of yours',
    );
    expect(fetch.mock.calls.some(([url]) => String(url).endsWith(`${path}?weights=semanticSimilarity%3A0.9`))).toBe(true);
  });

  it.each<[string, Answer]>([
    ['the reach found no volume', { volumes: [], documentCount: 0, seedsProbed: 0 }],
    ['the reach could not be read', new ProblemAnswer(503, 'SEMANTIC_UNAVAILABLE', 'This server’s semantic vectors are refused.')],
  ])('shows nothing where %s', async (_case, answer) => {
    const fetch = stubServer({ ...base, [`/api/v1/me/projects/${grain}/home`]: home, [path]: answer });
    renderAt(`/projects/${grain}`);
    await screen.findByRole('heading', { level: 2, name: 'Suggested Next' });
    // The reach was asked for, and its answer had time to be drawn, before the page is read.
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes(path))).toBe(true));
    await new Promise((settled) => setTimeout(settled, 100));
    expect(screen.queryByRole('heading', { name: 'Beyond your library' })).toBeNull();
    expect(screen.queryByRole('alert')).toBeNull();
  });
});
