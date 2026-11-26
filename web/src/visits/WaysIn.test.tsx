// The ways into a plan (PLAN's S30d) that a picker or the editor opens from other screens: Archival Neighbors' add of the
// documents shown, with the source alone; a collection authority's record's add of its citing documents, fetched whole,
// with the record's name for a plan made from them; each offered only on a server that keeps user data; and Project
// Home's Plan a Visit, offered while the project engages a document or has a plan, which opens the plan in its editor.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ProjectHome } from '../api/research';
import { collection, neighbours } from '../sources/sourcesFixtures';
import { sent } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const planId = '5E30D000-0000-4000-8000-000000000002';
const plans = { total: 1, items: [{ id: planId, name: 'Berlin', displayName: 'Berlin', documentCount: 3, indexedDocumentCount: 3 }] };

describe('Archival Neighbors’ add', () => {
  it('opens the picker over the documents shown, the source alone', async () => {
    const stub = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/archival-neighbors': neighbours,
      '/api/v1/me/visits': plans,
      [`POST /api/v1/me/visits/${planId}/documents`]: { id: planId },
    });
    renderAt('/archival-neighbors?volumeId=frus1961-63v06&documentId=d3');
    const add = await screen.findByRole('button', { name: 'Add the 3 shown to an Archives Visit…' });
    await userEvent.click(add);
    const picker = await screen.findByRole('dialog', { name: 'Add to Archives Visit' });
    expect(within(picker).getByText('Adding 3 documents: archival sources — the 3 neighbors shown')).toBeTruthy();
    await userEvent.click(await within(picker).findByRole('button', { name: /Berlin/ }));
    await waitFor(() => expect(stub.mock.calls.some(([url]) => String(url).endsWith(`/visits/${planId}/documents`))).toBe(true));
    const added = stub.mock.calls.find(([url]) => String(url).endsWith(`/visits/${planId}/documents`));
    expect(sent(added?.[1]).body).toEqual({
      documents: neighbours.documents.map((document) => ({ volumeId: document.volumeId, documentId: document.documentId })),
      includeSource: true,
      includeExternalRefs: false,
    });
  });

  it('is not offered on a server that keeps no user data', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false }, '/api/v1/archival-neighbors': neighbours });
    renderAt('/archival-neighbors?volumeId=frus1961-63v06&documentId=d3');
    await screen.findByText(neighbours.basis!);
    expect(screen.queryByRole('button', { name: /to an Archives Visit/ })).toBeNull();
  });
});

describe('a record’s add of its citing documents', () => {
  it('fetches every citing document, then opens the picker with the record’s name, the source alone', async () => {
    const citing = [
      { volumeId: 'frus1961-63v06', documentId: 'd6' },
      { volumeId: 'frus1961-63v06', documentId: 'd10' },
    ];
    const stub = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/archival-collection': collection,
      '/api/v1/archival-collection/documents': { name: collection.name, totalCount: 2, documents: citing },
      '/api/v1/me/visits': { total: 0, items: [] },
      'POST /api/v1/me/visits': { id: planId },
    });
    renderAt(`/archival-collection?id=${encodeURIComponent(collection.id)}`);
    await userEvent.click(await screen.findByRole('button', { name: `Add the ${collection.documentCount} citing documents to an Archives Visit…` }));
    const picker = await screen.findByRole('dialog', { name: 'Add to Archives Visit' });
    expect(within(picker).getByText(`Adding 2 documents: archival sources — the documents citing “${collection.name}”`)).toBeTruthy();
    await userEvent.click(within(picker).getByRole('button', { name: 'New Archives Visit' }));
    await waitFor(() => expect(stub.mock.calls.some(([url, init]) => String(url).endsWith('/api/v1/me/visits') && init?.method === 'POST')).toBe(true));
    const made = stub.mock.calls.find(([url, init]) => String(url).endsWith('/api/v1/me/visits') && init?.method === 'POST');
    expect(sent(made?.[1]).body).toEqual({ name: collection.name, documents: citing, includeSource: true, includeExternalRefs: false });
  });

  it('says where the fetch’s ceiling cut the set', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/archival-collection': collection,
      '/api/v1/archival-collection/documents': { name: 'Central Files', totalCount: 20_001, documents: [{ volumeId: 'frus1961-63v06', documentId: 'd4' }] },
      '/api/v1/me/visits': { total: 0, items: [] },
    });
    renderAt(`/archival-collection?id=${encodeURIComponent(collection.id)}`);
    await userEvent.click(await screen.findByRole('button', { name: /citing documents to an Archives Visit…/ }));
    const picker = await screen.findByRole('dialog', { name: 'Add to Archives Visit' });
    expect(within(picker).getByText('Adding 1 document: archival sources — the first 1 of 20001 documents citing “Central Files”')).toBeTruthy();
  });
});

describe('Project Home’s Plan a Visit', () => {
  const project = 'A0000000-0000-4000-8000-000000000009';
  const home: ProjectHome = {
    project: { id: project, name: 'Berlin crisis' },
    isActive: true,
    counts: { collections: 0, notes: 2, documentsVisited: 0, searches: 0 },
    coverage: [],
    hasTags: false,
    focusTags: [],
    leads: [],
    recentVisits: [],
    recentNotes: [],
    recentSearches: [],
    isEmpty: false,
  };
  const answers = {
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/projects': { total: 1, items: [{ id: project, name: 'Berlin crisis', tally: '2 notes' }], activeProjectId: project },
    '/api/v1/me/preferences': {},
    [`/api/v1/me/projects/${project}/home`]: home,
  };

  it('is offered with neither engaged documents nor a plan no more than the app’s', async () => {
    stubServer({ ...answers, [`/api/v1/me/projects/${project}/visit`]: { planId: null, engagedDocuments: 0 } });
    renderAt(`/projects/${project}`);
    const button = (await screen.findByRole('button', { name: 'Plan a Visit' })) as HTMLButtonElement;
    await waitFor(() => expect(button.disabled).toBe(true));
  });

  it('makes or opens the project’s plan and opens it in its editor', async () => {
    const stub = stubServer({
      ...answers,
      [`/api/v1/me/projects/${project}/visit`]: { planId: null, engagedDocuments: 2 },
      [`POST /api/v1/me/projects/${project}/visit`]: { created: true, plan: { id: planId, name: 'Berlin crisis', displayName: 'Berlin crisis' } },
      [`/api/v1/me/visits/${planId}`]: {
        id: planId,
        name: 'Berlin crisis',
        displayName: 'Berlin crisis',
        projectIds: [project],
        deliverables: { includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: false },
        tiers: [],
        documentCount: 2,
        indexedDocumentCount: 2,
        served: true,
        sections: [],
        storedTargets: [],
        documents: [],
      },
    });
    const { router } = renderAt(`/projects/${project}`);
    const button = (await screen.findByRole('button', { name: 'Plan a Visit' })) as HTMLButtonElement;
    await waitFor(() => expect(button.disabled).toBe(false));
    await userEvent.click(button);
    await waitFor(() => expect(router.state.location.pathname).toBe(`/visits/${planId}`));
    expect(stub.mock.calls.some(([url, init]) => String(url).endsWith(`/projects/${project}/visit`) && init?.method === 'POST')).toBe(true);
  });
});
