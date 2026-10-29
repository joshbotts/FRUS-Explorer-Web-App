// What S18f brings to the Collections tab and the editor, against a stubbed server: Import Collection…,
// which sends the file chosen as it is and opens the collection it makes; Create Static Snapshot on a
// smart collection's row, which opens the snapshot; a refusal of either under the app's alert's title;
// Collection settings' Smart Collection rows, Link to Saved Search… with its picker and Unlink; Summary
// only listed but not offered, with the app's reason, where no summary is stored; and the inspector's
// headnote card, with who wrote it, Edit and Save, and New Note…, which a partial selection takes.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CollectionDetail, CollectionEntry, CollectionListItem, EntryInspector } from '../api/collections';
import { sent } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const berlinId = 'C0110000-0000-4000-8000-000000000001';
const smartId = 'C0110000-0000-4000-8000-000000000002';
const madeId = 'C0110000-0000-4000-8000-000000000003';
const searchId = 'S0000000-0000-4000-8000-000000000001';
const project = { id: 'P0000000-0000-4000-8000-000000000001', name: 'Cold War' };
const base = '/api/v1/me/collections';

function listed(fields: Partial<CollectionListItem> & Pick<CollectionListItem, 'id' | 'name'>): CollectionListItem {
  return { listName: fields.name || 'Untitled Collection', documentCount: 0, isSmart: false, projectIds: [], ...fields };
}

function entry(fields: Partial<CollectionEntry> & Pick<CollectionEntry, 'id' | 'kind'>): CollectionEntry {
  return {
    sortOrder: 0,
    level: 1,
    depth: 0,
    documentId: '',
    volumeId: '',
    formattingKept: false,
    selectedNoteIds: [],
    selectedHighlightIds: [],
    canIndent: false,
    canOutdent: false,
    leftOut: false,
    isDuplicate: false,
    ...fields,
  };
}

const telegram = entry({
  id: 'E1',
  kind: 'document',
  volumeId: 'frus1961-63v06',
  documentId: 'd1',
  header: '1. Telegram From the Embassy in the Soviet Union',
  noteCount: 1,
});

function detail(fields: Partial<CollectionDetail> = {}): CollectionDetail {
  return {
    id: berlinId,
    name: 'Berlin',
    listName: 'Berlin',
    introductionFormattingKept: false,
    includeColophon: false,
    includeProjectProvenance: false,
    includeMethodAppendix: false,
    projectIds: [],
    takesHandAddedEntries: true,
    defaultBodyDepth: 'full',
    includeFootnotes: true,
    includeSourceNote: false,
    tocStyle: 'citation',
    applyHighlights: false,
    includeNotes: true,
    includeWordCloud: false,
    defaultIncludeHeadnote: false,
    summariesAvailable: false,
    bodyDepths: ['full', 'index'],
    presets: [],
    prompts: [],
    documentCount: 1,
    volumesNotHeld: [],
    entries: [telegram],
    ...fields,
  };
}

function inspector(fields: Partial<EntryInspector> = {}): EntryInspector {
  return {
    entryId: 'E1',
    kind: 'document',
    documentId: 'd1',
    volumeId: 'frus1961-63v06',
    header: telegram.header,
    volumeTitle: 'Kennedy-Khrushchev Exchanges',
    derivedTitle: 'Document 1',
    notes: [{ id: 'N1', preview: 'The first note', included: true }],
    highlights: [],
    tags: [],
    resolved: { bodyDepth: 'full', highlights: false, notes: true, sourceNote: false, footnotes: true, related: false, headnote: false },
    excerpts: [],
    summaryOnlyOffered: false,
    ...fields,
  };
}

const saved = { id: searchId, name: 'Berlin wall', queryText: 'wall', search: {}, notRecalled: [] };

const server = (answers: Record<string, unknown> = {}) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/projects': { items: [project], activeProjectId: project.id },
    '/api/v1/me/preferences': {},
    [`${base}/${berlinId}/excerpt-check`]: { hasFailures: false, verified: 0 },
    [`${base}/${berlinId}/results`]: { total: 0, items: [] },
    ...answers,
  });

beforeEach(() => {
  vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }));
  vi.spyOn(HTMLIFrameElement.prototype, 'contentWindow', 'get').mockReturnValue({ location: { replace() {} } } as unknown as Window);
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('the Collections tab’s files and snapshots', () => {
  it('imports the file chosen as it is, and opens the collection it makes', async () => {
    const fetch = server({
      [base]: { total: 1, items: [listed({ id: berlinId, name: 'Berlin' })] },
      [`POST ${base}/import`]: detail({ id: madeId, name: 'Shared', listName: 'Shared' }),
      [`${base}/${madeId}`]: detail({ id: madeId, name: 'Shared', listName: 'Shared' }),
      [`${base}/${madeId}/excerpt-check`]: { hasFailures: false, verified: 0 },
    });
    const { router } = renderAt('/collections');
    const button = await screen.findByRole('button', { name: 'Import Collection…' });
    const input = document.querySelector<HTMLInputElement>('input[type="file"]')!;
    expect(input.accept).toBe('.fruscollection,application/json');
    const chosen = vi.spyOn(input, 'click').mockImplementation(() => {});
    await userEvent.click(button);
    expect(chosen).toHaveBeenCalled();
    const file = new File(['{"format": "fruscollection"}'], 'Shared.fruscollection', { type: '' });
    fireEvent.change(input, { target: { files: [file] } });
    await waitFor(() => expect(router.state.location.pathname).toBe(`/collections/${madeId}`));
    const imported = fetch.mock.calls.find(([url]) => String(url).endsWith('/import'));
    expect(imported?.[1]?.method).toBe('POST');
    expect((imported?.[1]?.headers as Record<string, string>)['Content-Type']).toBe('application/json');
    expect(imported?.[1]?.body).toBe(file);
  });

  it('snapshots a smart collection from its row, opens the snapshot, and says why one was refused', async () => {
    const items = [listed({ id: berlinId, name: 'Berlin' }), listed({ id: smartId, name: 'Wall', isSmart: true })];
    server({
      [base]: { total: 2, items },
      [`POST ${base}/${smartId}/snapshot`]: detail({ id: madeId, name: 'Wall (Snapshot)', listName: 'Wall (Snapshot)' }),
      [`${base}/${madeId}`]: detail({ id: madeId, name: 'Wall (Snapshot)', listName: 'Wall (Snapshot)' }),
      [`${base}/${madeId}/excerpt-check`]: { hasFailures: false, verified: 0 },
    });
    const { router } = renderAt('/collections');
    const rows = within(await screen.findByRole('list', { name: 'Collections' })).getAllByRole('listitem');
    expect(within(rows[0]!).queryByRole('button', { name: /Create Static Snapshot/ })).toBeNull();
    await userEvent.click(within(rows[1]!).getByRole('button', { name: 'Create Static Snapshot: Wall' }));
    await waitFor(() => expect(router.state.location.pathname).toBe(`/collections/${madeId}`));
    cleanup();

    server({
      [base]: { total: 1, items: [listed({ id: smartId, name: 'Wall', isSmart: true })] },
      [`POST ${base}/${smartId}/snapshot`]: new ProblemAnswer(
        409,
        'SAVED_SEARCH_MISSING',
        'The linked saved search could not be found. It may have been deleted.',
      ),
    });
    renderAt('/collections');
    await userEvent.click(await screen.findByRole('button', { name: 'Create Static Snapshot: Wall' }));
    expect((await screen.findByRole('alert')).textContent).toBe(
      'Couldn’t Create Snapshot: The linked saved search could not be found. It may have been deleted.',
    );
  });
});

describe('a smart collection’s link to its saved search', () => {
  it('links a collection to a saved search from Collection settings, and unlinks it', async () => {
    const fetch = server({
      [`${base}/${berlinId}`]: detail(),
      '/api/v1/me/saved-searches': { total: 1, items: [saved] },
      [`PATCH ${base}/${berlinId}`]: (_url: URL, init?: RequestInit) =>
        (sent(init).body as { savedSearchId: string | null }).savedSearchId
          ? detail({ savedSearchId: searchId, savedSearchName: 'Berlin wall', takesHandAddedEntries: false })
          : detail(),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Collection settings' }));
    const settings = screen.getByRole('dialog', { name: 'Collection settings' });
    const smart = within(settings).getByRole('region', { name: 'Smart Collection' });
    await userEvent.click(within(smart).getByRole('button', { name: 'Link to Saved Search…' }));
    const picker = screen.getByRole('dialog', { name: 'Link to Saved Search' });
    await userEvent.click(within(picker).getByRole('button', { name: /Berlin wall/ }));
    expect(await within(smart).findByText('Berlin wall')).toBeTruthy();
    expect(within(smart).getByText('Documents are resolved from this saved search at export time. Static entries are ignored.')).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(within(smart).getByRole('button', { name: 'Unlink' })));
    await userEvent.click(within(smart).getByRole('button', { name: 'Unlink' }));
    await waitFor(() => expect(document.activeElement).toBe(within(smart).getByRole('button', { name: 'Link to Saved Search…' })));
    const patches = fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => sent(init).body);
    expect(patches).toEqual([{ savedSearchId: searchId }, { savedSearchId: null }]);
  });

  it('dims Link to Saved Search… with the app’s line when none is saved, and says when the linked one is gone', async () => {
    server({ [`${base}/${berlinId}`]: detail(), '/api/v1/me/saved-searches': { total: 0, items: [] } });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Collection settings' }));
    let smart = within(screen.getByRole('dialog', { name: 'Collection settings' })).getByRole('region', { name: 'Smart Collection' });
    expect(await within(smart).findByText('Save a search from the Search tab to enable smart collections.')).toBeTruthy();
    expect(within(smart).getByRole('button', { name: 'Link to Saved Search…' }).getAttribute('aria-disabled')).toBe('true');
    cleanup();

    server({
      [`${base}/${berlinId}`]: detail({ savedSearchId: searchId, takesHandAddedEntries: false }),
      '/api/v1/me/saved-searches': { total: 0, items: [] },
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Collection settings' }));
    smart = within(screen.getByRole('dialog', { name: 'Collection settings' })).getByRole('region', { name: 'Smart Collection' });
    expect(within(smart).getByText('Saved search not found')).toBeTruthy();
    expect(
      within(smart).getByText(
        'The linked saved search could not be found. It may have been deleted. Unlink it to add to this collection by hand.',
      ),
    ).toBeTruthy();
  });
});

describe('a smart collection’s entries from before its link', () => {
  it('lists them apart, dimmed, and removes them once asked, focus going to Contents', async () => {
    const earlier = [
      entry({ ...telegram, leftOut: true }),
      entry({ id: 'E2', kind: 'heading', text: '  ', leftOut: true }),
      entry({ id: 'E3', kind: 'excerpt', volumeId: 'frus1961-63v06', documentId: 'd2', text: 'Allow me.', leftOut: true }),
    ];
    const chronology = entry({ id: 'E4', kind: 'generated', generatedBlockType: 'chronology' });
    const fetch = server({
      [`${base}/${berlinId}`]: detail({ savedSearchId: searchId, takesHandAddedEntries: false, entries: [...earlier, chronology] }),
      [`POST ${base}/${berlinId}/entries-from-before-link/remove`]: detail({
        savedSearchId: searchId,
        takesHandAddedEntries: false,
        entries: [chronology],
      }),
    });
    renderAt(`/collections/${berlinId}`);
    const group = await screen.findByRole('region', { name: 'Not part of the smart collection: added before it was linked to its saved search.' });
    const rows = within(within(group).getByRole('list', { name: 'Entries added before the link' })).getAllByRole('listitem');
    expect(rows.map((row) => row.textContent)).toEqual([
      '1. Telegram From the Embassy in the Soviet Uniond1 · frus1961-63v06',
      'Untitled section',
      'Allow me.d2 · frus1961-63v06',
    ]);
    await userEvent.click(within(group).getByRole('button', { name: 'Remove These Entries' }));
    const question = screen.getByRole('alertdialog', { name: 'Remove These Entries?' });
    expect(within(question).getByText('Removes the 3 entries added before this collection was linked to its saved search.')).toBeTruthy();
    await userEvent.click(within(question).getByRole('button', { name: 'Remove These Entries' }));
    await waitFor(() => expect(screen.queryByRole('region', { name: /Not part of the smart collection/ })).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('heading', { name: 'Contents' })));
    expect(fetch.mock.calls.filter(([url]) => String(url).endsWith('/entries-from-before-link/remove'))).toHaveLength(1);
  });
});

describe('Summary only where no summary is stored', () => {
  it('is listed, not offered, with the app’s reason, for the collection and for a document', async () => {
    server({ [`${base}/${berlinId}`]: detail(), [`${base}/${berlinId}/entries/E1/inspector`]: inspector() });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Collection settings' }));
    const settings = screen.getByRole('dialog', { name: 'Collection settings' });
    const depth = within(settings).getByRole('combobox', { name: 'Body depth' });
    const summaryOnly = within(depth).getByRole('option', { name: 'Summary only' }) as HTMLOptionElement;
    expect(summaryOnly.disabled).toBe(true);
    expect([...(depth as HTMLSelectElement).options].map((option) => option.value)).toEqual(['full', 'summaryOnly', 'index']);
    const reason = document.getElementById(depth.getAttribute('aria-describedby')!)!;
    expect(reason.textContent).toBe(
      'Summary only is not offered: none of this collection’s documents has a summary stored. Summaries are generated on demand for documents that don’t already have one for this prompt. Requires Apple Intelligence.',
    );
    await userEvent.click(within(settings).getByRole('button', { name: 'Done' }));

    await userEvent.click(await screen.findByRole('button', { name: 'Configure: 1. Telegram From the Embassy in the Soviet Union' }));
    const sheet = screen.getByRole('dialog', { name: 'Berlin' });
    const own = await within(sheet).findByRole('combobox', { name: 'Body depth' });
    expect((within(own).getByRole('option', { name: 'Summary only' }) as HTMLOptionElement).disabled).toBe(true);
    expect(within(sheet).getByText(/this document has no summary stored\. Summaries are generated on demand/)).toBeTruthy();
  });
});

describe('the inspector’s headnote card and New Note…', () => {
  it('shows the headnote with who wrote it, and saves the text written over it', async () => {
    let saved = false;
    const fetch = server({
      [`${base}/${berlinId}`]: detail({ entries: [{ ...telegram, includeHeadnote: true }] }),
      [`${base}/${berlinId}/entries/E1/inspector`]: () =>
        inspector({
          headnote: saved
            ? { summaryId: 'D2', text: 'Khrushchev answers at once.', authorship: 'aiEdited', isDraft: true }
            : { summaryId: 'S1', text: 'Khrushchev answers.', authorship: 'aiGenerated', isDraft: false },
        }),
      [`PUT ${base}/${berlinId}/entries/E1/headnote`]: () => {
        saved = true;
        return detail({ entries: [{ ...telegram, includeHeadnote: true, headnoteSummaryId: 'D2' }] });
      },
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Configure: 1. Telegram From the Embassy in the Soviet Union' }));
    const sheet = screen.getByRole('dialog', { name: 'Berlin' });
    expect(await within(sheet).findByText('Key takeaway · headnote')).toBeTruthy();
    expect(within(sheet).getByText('AI draft')).toBeTruthy();
    expect(within(sheet).getByText('Khrushchev answers.')).toBeTruthy();
    await userEvent.click(within(sheet).getByRole('button', { name: 'Edit' }));
    const field = within(sheet).getByRole('textbox', { name: 'Headnote text' });
    await waitFor(() => expect(document.activeElement).toBe(field));
    await userEvent.clear(field);
    expect(within(sheet).getByRole('button', { name: 'Save' }).getAttribute('aria-disabled')).toBe('true');
    await userEvent.type(field, 'Khrushchev answers at once.');
    await userEvent.click(within(sheet).getByRole('button', { name: 'Save' }));
    expect(await within(sheet).findByText('AI · edited')).toBeTruthy();
    expect(within(sheet).getByText('Khrushchev answers at once.')).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(within(sheet).getByRole('button', { name: 'Edit' })));
    expect(sent(fetch.mock.calls.find(([, init]) => init?.method === 'PUT')?.[1]).body).toEqual({ text: 'Khrushchev answers at once.' });
  });

  it('says there is no headnote yet, and hides the card while the headnote is off', async () => {
    server({ [`${base}/${berlinId}`]: detail({ entries: [{ ...telegram, includeHeadnote: true }] }), [`${base}/${berlinId}/entries/E1/inspector`]: inspector() });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Configure: 1. Telegram From the Embassy in the Soviet Union' }));
    const sheet = screen.getByRole('dialog', { name: 'Berlin' });
    expect(await within(sheet).findByText('No headnote yet. Edit to write a key takeaway, or generate a document summary to seed one.')).toBeTruthy();
    expect(within(sheet).queryByText('Yours')).toBeNull();
    cleanup();

    server({ [`${base}/${berlinId}`]: detail(), [`${base}/${berlinId}/entries/E1/inspector`]: inspector() });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Configure: 1. Telegram From the Embassy in the Soviet Union' }));
    expect(await within(screen.getByRole('dialog', { name: 'Berlin' })).findByText('Your Annotations')).toBeTruthy();
    expect(screen.queryByText('Key takeaway · headnote')).toBeNull();
  });

  it('makes a note on the document from New Note…, in the project worked in, which a partial selection takes', async () => {
    const fetch = server({
      [`${base}/${berlinId}`]: detail({ entries: [{ ...telegram, selectedNoteIds: ['N1'] }] }),
      [`${base}/${berlinId}/entries/E1/inspector`]: inspector(),
      [`POST /api/v1/me/volumes/frus1961-63v06/documents/d1/notes`]: {
        id: 'N2',
        volumeId: 'frus1961-63v06',
        documentId: 'd1',
        bodyText: 'Read with the second letter.',
        userTagIds: [],
        projectIds: [project.id],
        selectedSummaryIds: [],
        linkedHighlightIds: [],
      },
      [`PATCH ${base}/${berlinId}/entries/E1`]: detail({ entries: [{ ...telegram, selectedNoteIds: ['N1', 'N2'] }] }),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Configure: 1. Telegram From the Embassy in the Soviet Union' }));
    const sheet = screen.getByRole('dialog', { name: 'Berlin' });
    const open = await within(sheet).findByRole('button', { name: 'New Note…' });
    await userEvent.click(open);
    const note = screen.getByRole('dialog', { name: 'New Research Note' });
    expect(within(note).getByRole('button', { name: 'Save Note' }).getAttribute('aria-disabled')).toBe('true');
    await userEvent.type(within(note).getByRole('textbox', { name: 'Note text' }), '  Read with the second letter.  ');
    await userEvent.click(within(note).getByRole('button', { name: 'Save Note' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'New Research Note' })).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(open));
    const made = fetch.mock.calls.find(([url, init]) => String(url).endsWith('/notes') && init?.method === 'POST');
    expect(sent(made?.[1]).body).toMatchObject({ bodyText: 'Read with the second letter.', projectIds: [project.id] });
    await waitFor(() =>
      expect(sent(fetch.mock.calls.find(([, init]) => init?.method === 'PATCH')?.[1]).body).toEqual({ note: { id: 'N2', included: true } }),
    );
  });
});
