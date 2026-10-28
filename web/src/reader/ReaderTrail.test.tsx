// The reader's part in the trail and the synced preferences (PLAN's S17f): each arrival at a document
// is recorded once, and leaves Checklist Mode's list only while Log Research Sessions is on; and a
// document a link opens with no rail named opens as Open Documents In says.
import { cleanup, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail } from '../api/types';
import { checklistStore, reviewedKey } from '../search/checklist';
import { resetPreferences } from '../settings/preferences';
import { me } from '../test/notes';
import { preferences } from '../test/research';
import { coverage, ready, renderAt, stubServer } from '../test/renderRoute';

const detail = (documentId: string): DocumentDetail => ({
  document: {
    documentId,
    volumeId: 'frus1961-63v06',
    documentNumber: documentId.slice(1),
    header: `Document ${documentId}`,
    displayTitle: `Document ${documentId}`,
    isEditorialNote: false,
    inIndex: true,
  },
  canonicalURL: `https://history.state.gov/historicaldocuments/frus1961-63v06/${documentId}`,
  teiAvailable: true,
});

function server(fields: Partial<typeof preferences>, visits: string[]) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/preferences': { ...preferences, ...fields },
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/volumes/frus1961-63v06/documents/d1': detail('d1'),
    '/api/v1/volumes/frus1961-63v06/documents/d2': detail('d2'),
    '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    '/api/v1/volumes/frus1961-63v06/documents/d2/html': {},
    'POST /api/v1/me/history/documents': (_: URL, init?: RequestInit) => {
      visits.push(JSON.parse(String(init?.body)).documentId);
      return { outcome: 'inserted' };
    },
  });
}

beforeEach(() => {
  resetPreferences();
  window.localStorage.clear();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  checklistStore.setOn(false, {});
});

describe('the reader and the trail', () => {
  it('records each arrival at a document once, and leaves Checklist Mode’s list only while logging is on', async () => {
    const visits: string[] = [];
    server({}, visits);
    checklistStore.setOn(true, { keywords: 'treaties' });
    const { router } = renderAt('/doc/frus1961-63v06/d1');
    await waitFor(() => expect(visits).toEqual(['d1']));
    expect(checklistStore.get().readSinceEnabled.has(reviewedKey('frus1961-63v06', 'd1'))).toBe(true);
    // Another rail is the same arrival; another document a new one.
    await router.navigate({ to: '/doc/$volumeId/$documentId', params: { volumeId: 'frus1961-63v06', documentId: 'd1' }, search: { rail: 'cite' } });
    await router.navigate({ to: '/doc/$volumeId/$documentId', params: { volumeId: 'frus1961-63v06', documentId: 'd2' } });
    await waitFor(() => expect(visits).toEqual(['d1', 'd2']));
    cleanup();

    const unlogged: string[] = [];
    server({ researchLoggingEnabled: false }, unlogged);
    checklistStore.setOn(false, {});
    checklistStore.setOn(true, { keywords: 'treaties' });
    renderAt('/doc/frus1961-63v06/d1');
    await waitFor(() => expect(unlogged).toEqual(['d1']), { timeout: 2000 });
    expect(checklistStore.get().readSinceEnabled.size).toBe(0);
  });

  it('opens a document a link names no rail for with the Research rail in Research mode, as last left in Remember Last', async () => {
    server({ defaultDocumentMode: 'research' }, []);
    const { router } = renderAt('/doc/frus1961-63v06/d1');
    await waitFor(() => expect(router.state.location.search).toMatchObject({ rail: 'research' }));
    cleanup();

    server({ defaultDocumentMode: 'read' }, []);
    const read = renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByRole('group', { name: 'Document' });
    // A rail the link names wins.
    expect(read.router.state.location.search).toMatchObject({ rail: 'research' });
    cleanup();

    window.localStorage.setItem('frus.document.researchPanel.visible', 'true');
    server({}, []);
    const remembered = renderAt('/doc/frus1961-63v06/d2');
    await waitFor(() => expect(remembered.router.state.location.search).toMatchObject({ rail: 'research' }));
  });

  it('asks for Cite’s citation in the style this browser last chose while the user’s preferences are read', async () => {
    window.localStorage.setItem('frus.citationStyle', 'chicago');
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/preferences': () => new Promise(() => {}),
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/volumes/frus1961-63v06/documents/d1': detail('d1'),
      '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    });
    renderAt('/doc/frus1961-63v06/d1?rail=cite');
    // Once the server is known to keep user data, which is when the preferences are asked for, and a moment more.
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).endsWith('/api/v1/me/preferences'))).toBe(true));
    await new Promise((resolve) => setTimeout(resolve, 50));
    const asked = fetch.mock.calls.map(([url]) => String(url)).filter((url) => url.includes('/citation'));
    expect(asked.length).toBeGreaterThan(0);
    expect(asked.every((url) => url.includes('style=chicago'))).toBe(true);
  });
});
