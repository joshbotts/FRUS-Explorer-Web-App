import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { VolumeScope, WorkingCorpus, WorkingCorpusDetail } from '../api/searchSets';
import type { Volume } from '../api/types';
import { coverage, ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { sent } from '../test/notes';
import { corpusCaption } from './CorporaScreen';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const talksId = '0C6B1D0E-5E2B-4E40-9A43-8E1A5D1E2F01';
const scopeId = '7F1C2A3B-4D5E-4F60-8A71-9B2C3D4E5F02';

function volume(volumeId: string, title: string): Volume {
  return { volumeId, title, subseries: '1961–1963', status: 'published', editors: [], indexed: true, teiAvailable: true } as unknown as Volume;
}

const volumes = [volume('frus1961-63v06', 'Kennedy-Khrushchev Exchanges'), volume('frus1961-63v10', 'Cuba, 1961–1962'), volume('frus1894Nicaragua', 'Nicaragua')];

function corpus(fields: Partial<WorkingCorpus> & Pick<WorkingCorpus, 'id' | 'name'>): WorkingCorpus {
  return { documentCount: 2, isMeaningCapture: false, truncationWarns: false, ...fields };
}

function scope(fields: Partial<VolumeScope> & Pick<VolumeScope, 'id' | 'name'>): VolumeScope {
  return { volumeIds: [], cataloguedCount: 0, ...fields };
}

const server = (answers: Record<string, unknown> = {}) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/volumes': { total: volumes.length, limit: 1000, offset: 0, items: volumes, coverage },
    '/api/v1/me/working-corpora': { total: 0, items: [] },
    '/api/v1/me/volume-scopes': { total: 0, items: [] },
    ...answers,
  });

describe('Browse’s axes', () => {
  it('names All Volumes, Working Corpora and My Scopes on a server that keeps user data, and only All Volumes elsewhere', async () => {
    server();
    renderAt('/browse');
    const axes = await screen.findByRole('navigation', { name: 'Browse by' });
    expect(within(axes).getAllByRole('link').map((link) => [link.textContent, link.getAttribute('aria-current')])).toEqual([
      ['All Volumes', 'page'],
      ['Working Corpora', null],
      ['My Scopes', null],
    ]);
    cleanup();
    server({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/browse');
    await screen.findByRole('link', { name: 'Nicaragua' });
    expect(screen.queryByRole('navigation', { name: 'Browse by' })).toBeNull();
  });
});

describe('Browse’s Working Corpora', () => {
  it('lists the corpora with the Mac’s caption and the kit’s line for a capture cut short, or says there are none', async () => {
    server({
      '/api/v1/me/working-corpora': {
        total: 2,
        items: [
          corpus({ id: talksId, name: 'Talks', sourceDescription: 'Search results (years 1960)', capturedAt: '2026-10-24T12:00:00Z' }),
          corpus({
            id: 'X',
            name: '',
            documentCount: 7500,
            sourceQuery: '"long telegram"',
            quotableSourceQuery: 'long telegram',
            truncationLine: 'Saved 7500 of 9,000 matches',
            truncationWarns: true,
          }),
        ],
      },
    });
    renderAt('/browse/corpora');
    const rows = within(await screen.findByRole('list', { name: 'Working Corpora' })).getAllByRole('listitem');
    expect(within(rows[0]!).getByRole('link', { name: 'Talks, 2 documents' }).title).toBe('Browse this corpus’s documents, grouped by volume');
    expect(rows[0]!.querySelector('.meta')?.textContent).toBe('2 documents · Search results (years 1960) · Oct 24, 2026');
    expect(within(rows[1]!).getByRole('link').textContent).toBe('Untitled Corpus');
    expect(rows[1]!.querySelectorAll('.meta')[0]?.textContent).toBe('7,500 documents · captured from “long telegram”');
    expect(rows[1]!.querySelector('.meta.warning')?.textContent).toBe('Saved 7500 of 9,000 matches');
    cleanup();
    server();
    renderAt('/browse/corpora');
    expect(await screen.findByText('No Working Corpora')).toBeTruthy();
  });

  it('names where a corpus came from by its provenance, or else by its words as the kit quotes them', () => {
    expect(corpusCaption(corpus({ id: 'A', name: 'A', documentCount: 1, sourceQuery: 'x', quotableSourceQuery: 'x' }))).toBe('1 documents · captured from “x”');
    expect(corpusCaption(corpus({ id: 'A', name: 'A', sourceQuery: 'x', sourceDescription: 'Search results' }))).toBe('2 documents · Search results');
  });

  it('opens a corpus by volume, with its coverage once at the top, the documents of a volume the server lacks named, and deletes it', async () => {
    const detail: WorkingCorpusDetail = {
      corpus: corpus({ id: talksId, name: 'Talks', documentCount: 3, coverage: { indexedCount: 2, totalCount: 3, missingVolumeIds: ['frus1969-76v01'], isComplete: false } }),
      sections: [
        {
          volumeId: 'frus1961-63v06',
          title: 'Kennedy-Khrushchev Exchanges',
          indexed: true,
          documents: [
            { volumeId: 'frus1961-63v06', documentId: 'd1', displayTitle: '1. Telegram', dateISO: '1960-11-09' },
            { volumeId: 'frus1961-63v06', documentId: 'd2', displayTitle: '2. Memorandum' },
          ],
        },
        { volumeId: 'frus1969-76v01', indexed: false, documents: [{ volumeId: 'frus1969-76v01', documentId: 'd5' }] },
      ],
      coverage,
    };
    const fetch = server({ [`/api/v1/me/working-corpora/${talksId}`]: detail, [`DELETE /api/v1/me/working-corpora/${talksId}`]: null });
    const { router } = renderAt(`/browse/corpora/${talksId}`);
    expect(await screen.findByRole('heading', { level: 1, name: 'Talks' })).toBeTruthy();
    expect(screen.getByText('2 of 3 documents indexed on this server').className).toBe('count warning');
    const sections = screen.getAllByRole('region');
    expect(sections.map((section) => section.querySelector('h2')?.textContent)).toEqual(['Kennedy-Khrushchev Exchanges', 'frus1969-76v01']);
    expect(within(sections[0]!).getByRole('link', { name: '1. Telegram' }).getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    expect(within(sections[1]!).queryByRole('link')).toBeNull();
    expect(sections[1]!.textContent).toContain('frus1969-76v01 · d5Not indexed on this server');

    await userEvent.click(screen.getByRole('button', { name: 'Delete Corpus' }));
    const confirm = await screen.findByRole('alertdialog', { name: 'Delete Working Corpus?' });
    expect(document.activeElement).toBe(within(confirm).getByRole('button', { name: 'Cancel' }));
    await userEvent.click(within(confirm).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/browse/corpora'));
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(true);
  });

  it('says a corpus is unavailable once it is gone', async () => {
    server({ [`/api/v1/me/working-corpora/${talksId}`]: new ProblemAnswer(404, 'CORPUS_NOT_FOUND', 'gone') });
    renderAt(`/browse/corpora/${talksId}`);
    expect(await screen.findByRole('heading', { level: 1, name: 'Corpus Unavailable' })).toBeTruthy();
    expect(screen.getByText('This corpus no longer exists — it may have been deleted.')).toBeTruthy();
  });
});

describe('Browse’s My Scopes', () => {
  it('lists the scopes, most recently edited first, and New Scope makes an empty one and opens its editor', async () => {
    const fetch = server({
      '/api/v1/me/volume-scopes': {
        total: 2,
        items: [
          scope({ id: scopeId, name: 'Cuba', volumeIds: ['frus1961-63v10', 'frus-gone'], lastModified: '2026-10-24T12:00:00Z', cataloguedCount: 1 }),
          scope({ id: 'B', name: '' }),
        ],
      },
      'POST /api/v1/me/volume-scopes': scope({ id: 'NEW', name: '' }),
    });
    const { router } = renderAt('/browse/scopes');
    const rows = within(await screen.findByRole('list', { name: 'My Scopes' })).getAllByRole('listitem');
    expect(within(rows[0]!).getByRole('link', { name: 'Cuba, 2 volumes' })).toBeTruthy();
    expect(within(rows[0]!).getByRole('link', { name: 'Edit Cuba' }).title).toBe('Rename this scope or change its volumes');
    expect(rows[0]!.querySelector('.meta')?.textContent).toBe('2 volumes · edited Oct 24, 2026');
    expect(rows[1]!.querySelector('.meta')?.textContent).toBe('No volumes yet');
    expect(within(rows[1]!).getAllByRole('link')[0]?.textContent).toBe('Untitled Scope');
    await userEvent.click(screen.getByRole('button', { name: 'New Scope' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/browse/scopes/NEW/edit'));
    expect(sent(fetch.mock.calls.find(([, init]) => init?.method === 'POST')![1]).body).toEqual({});
  });

  it('opens a scope’s volumes the catalogue lists, and counts those it does not', async () => {
    server({
      '/api/v1/me/volume-scopes': { total: 1, items: [scope({ id: scopeId, name: 'Cuba', volumeIds: ['frus-gone', 'frus1961-63v10'], cataloguedCount: 1 })] },
    });
    renderAt(`/browse/scopes/${scopeId}`);
    expect(await screen.findByText(/1 volumes in this scope, by volume number\./)).toBeTruthy();
    expect(screen.getByText(/Entries referencing volumes outside this server’s catalogue: 1\./)).toBeTruthy();
    expect(within(screen.getByRole('list', { name: 'Cuba' })).getAllByRole('link').map((link) => link.textContent)).toEqual(['Cuba, 1961–1962']);
  });

  it('edits a scope’s name as typed, removes a volume, adds volumes from the catalogue as one sorted set, and deletes it', async () => {
    let current = scope({ id: scopeId, name: 'Cuba', volumeIds: ['frus-gone', 'frus1961-63v10'] });
    const edits: unknown[] = [];
    server({
      '/api/v1/me/volume-scopes': () => ({ total: 1, items: [current] }),
      [`PATCH /api/v1/me/volume-scopes/${scopeId}`]: (_url: URL, init?: RequestInit) => {
        const body = sent(init).body;
        edits.push(body);
        current = { ...current, ...body };
        return current;
      },
      [`DELETE /api/v1/me/volume-scopes/${scopeId}`]: null,
    });
    const { router } = renderAt(`/browse/scopes/${scopeId}/edit`);
    const name = await screen.findByRole('textbox', { name: 'Name' });
    expect((name as HTMLInputElement).value).toBe('Cuba');
    await userEvent.type(name, ' crisis{Enter}');
    await waitFor(() => expect(edits).toContainEqual({ name: 'Cuba crisis' }));
    expect(screen.getByText('Not in this server’s catalogue')).toBeTruthy();
    expect(screen.getByRole('heading', { name: 'Volumes (2)' })).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Remove frus-gone from this scope' }));
    await waitFor(() => expect(edits).toContainEqual({ volumeIds: ['frus1961-63v10'] }));

    const add = await screen.findByRole('button', { name: 'Add Volumes…' });
    await userEvent.click(add);
    const picker = await screen.findByRole('dialog', { name: 'Add Volumes' });
    expect((within(picker).getByRole('checkbox', { name: /Cuba, 1961–1962/ }) as HTMLInputElement).checked).toBe(true);
    await userEvent.type(within(picker).getByRole('searchbox'), 'v06');
    expect(within(picker).getAllByRole('checkbox')).toHaveLength(1);
    await userEvent.click(within(picker).getByRole('checkbox', { name: /Kennedy-Khrushchev/ }));
    await userEvent.click(within(picker).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(edits).toContainEqual({ volumeIds: ['frus1961-63v06', 'frus1961-63v10'] }));
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Add Volumes…' })));

    await userEvent.click(screen.getByRole('button', { name: 'Delete Scope' }));
    await userEvent.click(within(await screen.findByRole('alertdialog', { name: 'Delete Scope?' })).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/browse/scopes'));
  });
});
