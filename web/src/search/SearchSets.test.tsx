import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SavedSearch, VolumeScope, WorkingCorpus } from '../api/searchSets';
import type { SearchItem, SearchResultList } from '../api/types';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';
import { sent } from '../test/notes';
import { checklistStore } from './checklist';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  checklistStore.reset();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const talksId = '0C6B1D0E-5E2B-4E40-9A43-8E1A5D1E2F01';
const elsewhereId = '0C6B1D0E-5E2B-4E40-9A43-8E1A5D1E2F02';

function item(documentId: string, displayTitle: string): SearchItem {
  return {
    volumeId: 'frus1961-63v06',
    documentId,
    header: displayTitle,
    displayTitle,
    documentLabel: documentId,
    headerRepeatsNumber: false,
    snippet: 'the <b>treaties</b>',
    bm25Score: -1,
    isEditorialNote: false,
    isFrontMatter: false,
    subjectTagIds: [],
    userTagIds: [],
  };
}

function list(items: SearchItem[], fields: Partial<SearchResultList> = {}): SearchResultList {
  return { total: items.length, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, coverage, items, ...fields };
}

function saved(fields: Partial<SavedSearch> & Pick<SavedSearch, 'id' | 'name'>): SavedSearch {
  return { queryText: '', search: {}, notRecalled: [], ...fields };
}

function corpus(fields: Partial<WorkingCorpus> & Pick<WorkingCorpus, 'id' | 'name'>): WorkingCorpus {
  return {
    documentCount: 2,
    isMeaningCapture: false,
    truncationWarns: false,
    coverage: { indexedCount: 2, totalCount: 2, missingVolumeIds: [], isComplete: true },
    ...fields,
  };
}

function scope(fields: Partial<VolumeScope> & Pick<VolumeScope, 'id' | 'name'>): VolumeScope {
  return { volumeIds: [], cataloguedCount: 0, ...fields };
}

const server = (answers: Record<string, unknown> = {}) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/search/inspect': { inspection: undefined },
    '/api/v1/me': me,
    '/api/v1/me/tags': { total: 0, items: [] },
    '/api/v1/me/saved-searches': { total: 0, items: [] },
    '/api/v1/me/working-corpora': { total: 0, items: [] },
    '/api/v1/me/volume-scopes': { total: 0, items: [] },
    '/api/v1/search': list([item('d1', 'Telegram'), item('d2', 'Memorandum')]),
    ...answers,
  });

const calls = (fetch: ReturnType<typeof stubServer>, method: string, path: string) =>
  fetch.mock.calls.filter(([url, init]) => (init?.method ?? 'GET') === method && String(url).split('?')[0] === path);

describe('saved searches in Search', () => {
  it('saves the search under the name the sheet offers, its words, trimmed, and keeps Save off while the name is empty', async () => {
    const fetch = server({ 'POST /api/v1/me/saved-searches': saved({ id: 'S1', name: 'treaties' }) });
    renderAt('/search?keywords=%20treaties%20&volumeIds=frus1961-63v06');
    const save = await screen.findByRole('button', { name: 'Save this search' });
    expect(save.title).toBe('Save this search so you can quickly run it again');
    await userEvent.click(save);
    const dialog = await screen.findByRole('dialog', { name: 'Save Search' });
    const name = within(dialog).getByRole('textbox', { name: 'Name' });
    expect((name as HTMLInputElement).value).toBe('treaties');
    expect(within(dialog).getByText('Query').closest('p')?.textContent).toBe('Query  treaties ');
    await userEvent.clear(name);
    await userEvent.type(name, '   ');
    expect((within(dialog).getByRole('button', { name: 'Save' }) as HTMLButtonElement).disabled).toBe(true);
    await userEvent.type(name, 'Treaty talks ');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    const [, init] = calls(fetch, 'POST', '/api/v1/me/saved-searches')[0]!;
    expect(sent(init).body).toEqual({ name: 'Treaty talks', search: 'keywords=+treaties+&volumeIds=frus1961-63v06' });
    expect(document.activeElement).toBe(save);
  });

  it('turns Save this search off for a search with no words, as the Mac’s button is', async () => {
    server();
    renderAt('/search?keywords=%20');
    expect(((await screen.findByRole('button', { name: 'Save this search' })) as HTMLButtonElement).disabled).toBe(true);
  });

  it('lists the saved searches, says what each run has gained, and recalls one inside the corpus applied, stamping its run', async () => {
    const fetch = server({
      '/api/v1/me/saved-searches': {
        total: 3,
        items: [
          saved({ id: 'S1', name: 'Treaties', queryText: 'treaties', search: { keywords: ['treaties'], includeNotes: ['false'] }, lastRunAt: '2026-10-24T00:00:00Z' }),
          saved({ id: 'S2', name: 'Canal', queryText: 'canal', lastRunAt: '2026-10-24T00:00:00Z', notRecalled: ['booleanMode', 'subjectRef'] }),
          saved({ id: 'S3', name: 'Never run' }),
        ],
      },
      'POST /api/v1/me/saved-searches/S1/freshness': { newResults: 1234, savedSearch: saved({ id: 'S1', name: 'Treaties' }) },
      'POST /api/v1/me/saved-searches/S2/freshness': { savedSearch: saved({ id: 'S2', name: 'Canal' }) },
      'POST /api/v1/me/saved-searches/S1/run': saved({ id: 'S1', name: 'Treaties' }),
    });
    const { router } = renderAt(`/search?keywords=canal&workingCorpusId=${talksId}&sort=dateAscending&offset=20`);
    await userEvent.click(await screen.findByRole('button', { name: 'Saved searches' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved Searches' });
    const rows = within(within(dialog).getByRole('list', { name: 'Saved Searches' })).getAllByRole('listitem');
    await waitFor(() => expect(within(rows[0]!).getByText('+1,234 since last run')).toBeTruthy());
    expect(within(rows[0]!).getByText('NEW')).toBeTruthy();
    expect(within(rows[1]!).queryByText('NEW')).toBeNull();
    expect(within(rows[1]!).getByText('Runs here without what only the Mac’s search sets: any of the words, a topic.')).toBeTruthy();
    // A search never run is counted by nothing.
    expect(calls(fetch, 'POST', '/api/v1/me/saved-searches/S3/freshness')).toHaveLength(0);

    await userEvent.click(within(rows[0]!).getByRole('button', { name: /^Treaties/ }));
    await waitFor(() =>
      expect(router.state.matches.at(-1)?.search).toMatchObject({
        keywords: 'treaties',
        includeNotes: false,
        workingCorpusId: talksId,
        sort: 'dateAscending',
        offset: undefined,
      }),
    );
    await waitFor(() => expect(calls(fetch, 'POST', '/api/v1/me/saved-searches/S1/run')).toHaveLength(1));
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('renames a saved search as given, and deletes one, from its row', async () => {
    let items = [saved({ id: 'S1', name: 'Treaties', queryText: 'treaties' })];
    const fetch = server({
      '/api/v1/me/saved-searches': () => ({ total: items.length, items }),
      'PATCH /api/v1/me/saved-searches/S1': (_url: URL, init?: RequestInit) => {
        items = [{ ...items[0]!, name: sent(init).body.name }];
        return items[0];
      },
      'DELETE /api/v1/me/saved-searches/S1': () => {
        items = [];
        return null;
      },
    });
    renderAt('/search?keywords=x');
    await userEvent.click(await screen.findByRole('button', { name: 'Saved searches' }));
    const dialog = await screen.findByRole('dialog', { name: 'Saved Searches' });
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Rename Treaties' }));
    const field = within(dialog).getByRole('textbox', { name: 'Rename' });
    expect(document.activeElement).toBe(field);
    await userEvent.clear(field);
    await userEvent.type(field, ' Talks {Enter}');
    // The name as given, which an accessible name reads without the spaces around it.
    await waitFor(() => expect(within(dialog).getByRole('button', { name: /^Talks/ })).toBeTruthy());
    expect(sent(calls(fetch, 'PATCH', '/api/v1/me/saved-searches/S1')[0]![1]).body).toEqual({ name: ' Talks ' });
    expect(document.activeElement).toBe(within(dialog).getByRole('button', { name: 'Rename Talks' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete Talks' }));
    expect(await within(dialog).findByText('No Saved Searches')).toBeTruthy();
    expect(within(dialog).getByText('Use Save this search in Search to save a search for quick access later.')).toBeTruthy();
    expect(document.activeElement).toBe(within(dialog).getByRole('heading', { name: 'Saved Searches' }));
  });
});

describe('working corpora and volume scopes in Search', () => {
  it('captures the rows the search shows in the Save Working Corpus sheet, saying what they are, as the server counts them', async () => {
    const fetch = server({
      '/api/v1/me/working-corpora': { total: 1, items: [corpus({ id: talksId, name: 'Talks' })] },
      'POST /api/v1/me/working-corpora/capture': {
        documentCount: 7500,
        sourceQuery: 'treaties',
        narrowing: ['years 1960'],
        indexedVolumeCount: 3,
        truncationWarning: 'These 7,500 documents are the highest-scoring of 9,000 matching documents. Counts taken inside this corpus are counts inside that subset.',
        sourceDescription: 'Search results (years 1960) — the highest-scoring 7,500 of 9,000 matches',
        wasTruncated: true,
        totalMatchCount: 9000,
      },
      'POST /api/v1/me/working-corpora': corpus({ id: elsewhereId, name: 'Treaties' }),
    });
    renderAt('/search?keywords=treaties&yearKeys=1960');
    const open = await screen.findByRole('button', { name: 'Save as Working Corpus…' });
    await waitFor(() => expect((open as HTMLButtonElement).disabled).toBe(false));
    await userEvent.click(open);
    const dialog = await screen.findByRole('dialog', { name: 'Save Working Corpus' });
    await within(dialog).findByText('7,500');
    expect([...dialog.querySelectorAll('dt')].map((term) => [term.textContent, term.nextElementSibling?.textContent])).toEqual([
      ['Documents', '7,500'],
      ['From', 'treaties'],
      ['Narrowed by', 'years 1960'],
      ['Volumes indexed now', '3'],
    ]);
    expect(within(dialog).getByText(/highest-scoring of 9,000 matching documents/)).toBeTruthy();
    const save = within(dialog).getByRole('button', { name: 'Save' }) as HTMLButtonElement;
    expect(save.disabled).toBe(true);
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'Name' }), 'Talks');
    expect(within(dialog).getByText('You already have a corpus with this name. Both will be kept.')).toBeTruthy();
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'Name' }), ' 1960 ');
    await userEvent.click(save);
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(sent(calls(fetch, 'POST', '/api/v1/me/working-corpora')[0]![1]).body).toEqual({
      name: 'Talks 1960',
      search: 'keywords=treaties&yearKeys=1960',
      reviewed: [],
    });
  });

  it('applies a corpus as the search’s gate, names it over the results, leaves it, and refuses one this server holds none of', async () => {
    const fetch = server({
      '/api/v1/me/working-corpora': {
        total: 2,
        items: [
          corpus({ id: talksId, name: 'Talks', sourceDescription: 'Search results', coverage: { indexedCount: 1, totalCount: 2, missingVolumeIds: ['x'], isComplete: false } }),
          corpus({ id: elsewhereId, name: 'Elsewhere', coverage: { indexedCount: 0, totalCount: 3, missingVolumeIds: ['x'], isComplete: false } }),
        ],
      },
    });
    const { router } = renderAt('/search?keywords=treaties');
    const summary = await screen.findByText('My Working Corpora');
    expect(summary.closest('summary')?.textContent).toBe('My Working Corpora Any');
    await userEvent.click(summary);
    const elsewhere = screen.getByRole('button', { name: /^Elsewhere/ });
    await userEvent.click(elsewhere);
    expect(screen.getByRole('alert').textContent).toBe('⚠ None of “Elsewhere” is indexed on this server.');
    expect(router.state.matches.at(-1)?.search).not.toHaveProperty('workingCorpusId', elsewhereId);
    const talks = screen.getByRole('button', { name: /^Talks/ });
    expect(talks.textContent).toContain('1 of 2 documents indexed on this server');
    await userEvent.click(talks);
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ workingCorpusId: talksId }));
    await waitFor(() => expect(fetch.mock.calls.map(([url]) => String(url))).toContain(`/api/v1/search?keywords=treaties&workingCorpusId=${talksId}&limit=20&offset=0`));
    const banner = screen.getByRole('group', { name: 'My Working Corpora' });
    expect(banner.textContent).toContain('Inside “Talks”');
    expect(summary.closest('summary')?.textContent).toBe('My Working Corpora Inside “Talks” · Search results');
    await userEvent.click(within(banner).getByRole('button', { name: 'Leave this working corpus' }));
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ workingCorpusId: undefined }));
  });

  it('fills the volume filter with a scope’s indexed members, and refuses one this server indexes none of', async () => {
    server({
      '/api/v1/me/volume-scopes': {
        total: 2,
        items: [
          scope({ id: 'A', name: 'Cuba', volumeIds: ['frus1961-63v10', 'frus1961-63v11', 'frus1964-68v32'], indexedVolumeIds: ['frus1961-63v10', 'frus1961-63v11'], indexedResolution: 'resolved', cataloguedCount: 3 }),
          scope({ id: 'B', name: '', volumeIds: ['frus1964-68v32'], indexedResolution: 'noIndexedMembers', cataloguedCount: 1 }),
        ],
      },
    });
    const { router } = renderAt('/search?keywords=treaties');
    const summary = await screen.findByText('My Volume Scopes');
    expect(summary.closest('summary')?.textContent).toBe('My Volume Scopes 2 selected');
    await userEvent.click(summary);
    const untitled = screen.getByRole('button', { name: /^Untitled Scope/ });
    expect(untitled.textContent).toContain('No indexed volumes');
    await userEvent.click(untitled);
    expect(screen.getByRole('alert').textContent).toBe('⚠ No volumes of “Untitled Scope” are indexed on this server.');
    const cuba = screen.getByRole('button', { name: /^Cuba/ });
    expect(cuba.textContent).toContain('2 of 3 volumes indexed');
    expect(cuba.title).toBe('Fills the volume picker with this scope’s indexed volumes');
    await userEvent.click(cuba);
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ volumeIds: ['frus1961-63v10', 'frus1961-63v11'] }));
  });

  it('refuses a search inside a corpus the user no longer has, in the results’ place, and its banner leaves it', async () => {
    server({ '/api/v1/search': new ProblemAnswer(404, 'CORPUS_NOT_FOUND', 'You have no working corpus with the id X.') });
    const { router } = renderAt(`/search?keywords=treaties&workingCorpusId=${talksId}`);
    expect((await screen.findByRole('alert')).textContent).toBe('You have no working corpus with the id X.');
    const banner = screen.getByRole('group', { name: 'My Working Corpora' });
    expect(banner.textContent).toContain('Inside a working corpus');
    await userEvent.click(within(banner).getByRole('button', { name: 'Leave this working corpus' }));
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ workingCorpusId: undefined }));
  });
});

describe('Checklist Mode', () => {
  it('hides a result marked reviewed, a page at a stroke, and brings the page back with Undo, as the server pages what it leaves', async () => {
    const fetch = server({
      'POST /api/v1/search': (_url: URL, init?: RequestInit) => {
        const reviewed = new URLSearchParams(String(init?.body)).getAll('reviewed');
        const all = [item('d1', 'Telegram'), item('d2', 'Memorandum'), item('d3', 'Letter')];
        const shown = all.filter((row) => !reviewed.includes(`${row.volumeId}/${row.documentId}`));
        return list(shown, { total: 3, hidden: all.length - shown.length });
      },
      '/api/v1/search': list([item('d1', 'Telegram'), item('d2', 'Memorandum'), item('d3', 'Letter')]),
    });
    renderAt('/search?keywords=treaties');
    const toggle = await screen.findByRole('button', { name: 'Checklist Mode' });
    expect(toggle.getAttribute('aria-pressed')).toBe('false');
    expect(toggle.title).toBe('Checklist review mode — hide results as you review them');
    expect(screen.queryByRole('button', { name: /^Mark Reviewed/ })).toBeNull();
    await userEvent.click(toggle);
    const strip = screen.getByRole('group', { name: 'Checklist Mode' });
    expect(strip.textContent).toContain('Nothing hidden');
    expect((within(strip).getByRole('button', { name: 'Undo' }) as HTMLButtonElement).disabled).toBe(true);

    await userEvent.click(screen.getByRole('button', { name: 'Mark Reviewed: Telegram' }));
    await waitFor(() => expect(strip.textContent).toContain('1 reviewed hidden'));
    const [, posted] = calls(fetch, 'POST', '/api/v1/search').at(-1)!;
    expect(String(posted?.body)).toBe('keywords=treaties&limit=20&offset=0&reviewed=frus1961-63v06%2Fd1');
    expect(screen.queryByRole('link', { name: 'Telegram' })).toBeNull();

    await userEvent.click(within(strip).getByRole('button', { name: 'Mark Page Reviewed' }));
    await waitFor(() => expect(strip.textContent).toContain('3 reviewed hidden'));
    expect(within(strip).getByRole('status').textContent).toBe('2 results marked reviewed');
    expect(await screen.findByText('All Results Reviewed')).toBeTruthy();
    expect(screen.getByText('You’ve reviewed every result. Turn off Checklist Mode to see them again.')).toBeTruthy();
    await userEvent.click(within(strip).getByRole('button', { name: 'Undo' }));
    await waitFor(() => expect(within(strip).getByRole('status').textContent).toBe('2 results are back in the list'));
    expect(strip.textContent).toContain('1 reviewed hidden');
    expect(await screen.findByRole('link', { name: 'Memorandum' })).toBeTruthy();

    // Off forgets every mark, and the search is read as before.
    await userEvent.click(toggle);
    expect(screen.queryByRole('group', { name: 'Checklist Mode' })).toBeNull();
    expect(await screen.findByRole('link', { name: 'Telegram' })).toBeTruthy();
  });

  it('makes no mark of the last search’s rows while the next search’s are coming, as the Mac waits for them', async () => {
    server({
      '/api/v1/search': (url: URL) =>
        url.searchParams.get('keywords') === 'canal' ? new Promise(() => {}) : list([item('d1', 'Telegram'), item('d2', 'Memorandum')]),
    });
    const { router } = renderAt('/search?keywords=treaties');
    await userEvent.click(await screen.findByRole('button', { name: 'Checklist Mode' }));
    const mark = await screen.findByRole('button', { name: 'Mark Reviewed: Telegram' });
    expect((mark as HTMLButtonElement).disabled).toBe(false);
    await router.navigate({ to: '/search', search: { keywords: 'canal' } });
    // The last search's rows stay on screen, and nothing can be marked of them.
    await waitFor(() => expect((screen.getByRole('button', { name: 'Mark Reviewed: Telegram' }) as HTMLButtonElement).disabled).toBe(true));
    const strip = screen.getByRole('group', { name: 'Checklist Mode' });
    expect((within(strip).getByRole('button', { name: 'Mark Page Reviewed' }) as HTMLButtonElement).disabled).toBe(true);
    await userEvent.click(screen.getByRole('button', { name: 'Mark Reviewed: Telegram' }));
    expect(checklistStore.get().marks.keys.size).toBe(0);
  });

  it('says what Undo brought back by its mark when the list the mark changed had not yet loaded', async () => {
    server({
      // The page after Mark Page Reviewed never comes.
      'POST /api/v1/search': () => new Promise(() => {}),
      '/api/v1/search': list([item('d1', 'Telegram'), item('d2', 'Memorandum')]),
    });
    renderAt('/search?keywords=treaties');
    await userEvent.click(await screen.findByRole('button', { name: 'Checklist Mode' }));
    const strip = screen.getByRole('group', { name: 'Checklist Mode' });
    await userEvent.click(within(strip).getByRole('button', { name: 'Mark Page Reviewed' }));
    expect(within(strip).getByRole('status').textContent).toBe('2 results marked reviewed');
    await userEvent.click(within(strip).getByRole('button', { name: 'Undo' }));
    await waitFor(() => expect(within(strip).getByRole('status').textContent).toBe('2 results are back in the list'));
    expect(await screen.findByRole('link', { name: 'Telegram' })).toBeTruthy();
  });

  it('goes back to the first page when its marks leave the page past the last, as the Mac’s checklist resets its page', async () => {
    const rows = Array.from({ length: 12 }, (_, index) => item(`d${index + 1}`, `Document ${index + 1}`));
    server({
      'POST /api/v1/search': (_url: URL, init?: RequestInit) => {
        const fields = new URLSearchParams(String(init?.body));
        const reviewed = fields.getAll('reviewed');
        const offset = Number(fields.get('offset'));
        const left = rows.filter((row) => !reviewed.includes(`${row.volumeId}/${row.documentId}`));
        return list(left.slice(offset, offset + 10), { total: 12, hidden: rows.length - left.length, limit: 10, offset });
      },
      '/api/v1/search': list(rows.slice(10), { total: 12, limit: 10, offset: 10 }),
    });
    const { router } = renderAt('/search?keywords=treaties&limit=10&offset=10');
    await userEvent.click(await screen.findByRole('button', { name: 'Checklist Mode' }));
    await screen.findByRole('link', { name: 'Document 11' });
    const strip = screen.getByRole('group', { name: 'Checklist Mode' });
    await userEvent.click(within(strip).getByRole('button', { name: 'Mark Page Reviewed' }));
    await waitFor(() => expect(router.state.matches.at(-1)?.search).toMatchObject({ keywords: 'treaties', limit: 10, offset: undefined }));
    expect(await screen.findByRole('link', { name: 'Document 1' })).toBeTruthy();
  });

  it('starts again for another search, and keeps its marks through a narrowing of the same one', async () => {
    server({
      'POST /api/v1/search': (_url: URL, init?: RequestInit) =>
        list([item('d2', 'Memorandum')], { total: 2, hidden: new URLSearchParams(String(init?.body)).getAll('reviewed').length }),
    });
    const { router } = renderAt('/search?keywords=treaties');
    await userEvent.click(await screen.findByRole('button', { name: 'Checklist Mode' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Mark Reviewed: Telegram' }));
    const strip = screen.getByRole('group', { name: 'Checklist Mode' });
    await waitFor(() => expect(strip.textContent).toContain('1 reviewed hidden'));
    await router.navigate({ to: '/search', search: { keywords: 'treaties', yearKeys: ['1960'] } });
    await waitFor(() => expect(strip.textContent).toContain('1 reviewed hidden'));
    await router.navigate({ to: '/search', search: { keywords: 'canal' } });
    await waitFor(() => expect(screen.getByRole('group', { name: 'Checklist Mode' }).textContent).toContain('Nothing hidden'));
  });
});
