// The Collections tab, a collection's editor and the Add to Collection picker (S18d), against a stubbed
// server: the list's rows, its scope banner, New Collection, Rename, Duplicate and Delete…; the editor's rows
// by kind, the Add menu, a heading's menu and its Delete Section, Move Down, Collection settings'
// presets, and the inspector's inclusions; and the picker's add of a document and of an excerpt.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { CollectionDetail, CollectionEntry, CollectionListItem, EntryInspector } from '../api/collections';
import { sent } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';
import { collectionCaption } from './CollectionsScreen';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const berlinId = 'C0110000-0000-4000-8000-000000000001';
const cubaId = 'C0110000-0000-4000-8000-000000000002';
const project = { id: 'P0000000-0000-4000-8000-000000000001', name: 'Cold War' };

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
    presets: [
      { id: 'teachingReader', active: false },
      { id: 'sourceDossier', active: false },
      { id: 'scholarlyEdition', active: false },
    ],
    prompts: [],
    documentCount: 0,
    volumesNotHeld: [],
    entries: [],
    ...fields,
  };
}

/** Europe › Berlin's telegram, then a note block, an excerpt and a chronology. */
const outline: CollectionEntry[] = [
  entry({ id: 'E1', kind: 'heading', text: 'Europe', depth: 1, sectionEnd: 5, canIndent: false }),
  entry({
    id: 'E2',
    kind: 'document',
    depth: 1,
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    header: '1. Telegram From the Embassy in the Soviet Union',
    volumeTitle: 'Kennedy-Khrushchev Exchanges',
    dateISO: '1960-11-09',
    noteCount: 2,
    bodyDepthOverride: 'index',
  }),
  entry({ id: 'E3', kind: 'prose', depth: 1, text: 'Read these together.' }),
  entry({ id: 'E4', kind: 'excerpt', depth: 1, volumeId: 'frus1961-63v06', documentId: 'd2', text: 'Allow me to congratulate you.', excerptColorTag: 'green', volumeTitle: 'Kennedy-Khrushchev Exchanges' }),
  entry({ id: 'E5', kind: 'generated', depth: 1, generatedBlockType: 'chronology' }),
];

/** The Contents list's rows, its own items and not its rows' chips. */
const contentRows = () => [...screen.getByRole('list', { name: 'Contents' }).children] as HTMLElement[];

const server = (answers: Record<string, unknown> = {}) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/projects': { items: [project] },
    '/api/v1/me/preferences': {},
    ...answers,
  });

describe('the Collections tab', () => {
  it('lists each collection by its name, its count or Smart collection, and its day', async () => {
    const items = [
      listed({ id: berlinId, name: 'Berlin', documentCount: 1, lastModified: '2026-10-24T12:00:00.000Z' }),
      listed({ id: cubaId, name: '', isSmart: true }),
    ];
    server({ '/api/v1/me/collections': { total: 2, items } });
    renderAt('/collections');
    const rows = within(await screen.findByRole('list', { name: 'Collections' })).getAllByRole('listitem');
    expect(within(rows[0]!).getByRole('link').textContent).toBe('Berlin');
    expect(rows[0]!.querySelector('.meta')?.textContent).toBe('1 document · Oct 24, 2026');
    expect(within(rows[1]!).getByRole('link').textContent).toBe('Untitled Collection');
    expect(rows[1]!.querySelector('.meta')?.textContent).toBe('Smart collection');
    expect(collectionCaption(listed({ id: 'x', name: 'x', documentCount: 3 }))).toBe('3 documents');
  });

  it('says there are none, with New Collection', async () => {
    server({ '/api/v1/me/collections': { total: 0, items: [] } });
    renderAt('/collections');
    expect(await screen.findByRole('heading', { name: 'No Collections' })).toBeTruthy();
    expect(screen.getByText('Create a collection to group documents for export.')).toBeTruthy();
  });

  it('scopes the list to the project worked in, from every project’s, and back', async () => {
    const items = [listed({ id: berlinId, name: 'Berlin', projectIds: [project.id] }), listed({ id: cubaId, name: 'Cuba' })];
    server({ '/api/v1/me/collections': { total: 2, items }, '/api/v1/me/projects': { items: [project], activeProjectId: project.id } });
    renderAt('/collections');
    expect(await screen.findByText('Showing collections from every project, including ones outside “Cold War”.')).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Scope to “Cold War”' }));
    expect(screen.getByText('Showing collections for “Cold War” — 1 other collection hidden.')).toBeTruthy();
    expect(within(screen.getByRole('list', { name: 'Collections' })).getAllByRole('link').map((link) => link.textContent)).toEqual(['Berlin']);
    await userEvent.click(screen.getByRole('button', { name: 'Show All' }));
    expect(within(screen.getByRole('list', { name: 'Collections' })).getAllByRole('link')).toHaveLength(2);
  });

  it('makes a collection by the New Collection sheet, its name required, and opens it', async () => {
    const fetch = server({
      '/api/v1/me/collections': { total: 0, items: [] },
      'POST /api/v1/me/collections': detail({ name: 'Grain', listName: 'Grain' }),
      [`/api/v1/me/collections/${berlinId}`]: detail({ name: 'Grain', listName: 'Grain' }),
    });
    const { router } = renderAt('/collections');
    await userEvent.click(await screen.findByRole('button', { name: 'New Collection' }));
    const sheet = screen.getByRole('dialog', { name: 'New Collection' });
    const create = within(sheet).getByRole('button', { name: 'Create' });
    expect(create.getAttribute('aria-disabled')).toBe('true');
    await userEvent.type(within(sheet).getByRole('textbox', { name: 'Name' }), 'Grain');
    await userEvent.click(create);
    await waitFor(() => expect(router.state.location.pathname).toBe(`/collections/${berlinId}`));
    const made = fetch.mock.calls.find(([, init]) => init?.method === 'POST');
    expect(sent(made?.[1]).body).toEqual({ name: 'Grain' });
    expect(await screen.findByRole('heading', { level: 1, name: 'Grain' })).toBeTruthy();
  });

  it('asks before Delete… in the app’s words, naming the collection, and sends focus on to the next row', async () => {
    let items = [listed({ id: berlinId, name: 'Berlin' }), listed({ id: cubaId, name: 'Cuba' })];
    const fetch = server({
      '/api/v1/me/collections': () => ({ total: items.length, items }),
      [`DELETE /api/v1/me/collections/${berlinId}`]: () => {
        items = items.filter((item) => item.id !== berlinId);
        return null;
      },
    });
    renderAt('/collections');
    await userEvent.click(await screen.findByRole('button', { name: 'Delete… Berlin' }));
    const question = screen.getByRole('alertdialog', { name: 'Delete “Berlin”?' });
    expect(question.getAttribute('aria-describedby')).toBeTruthy();
    expect(within(question).getByText(
      'Its section headings, note blocks and headnotes go with it, on your other devices too once they sync. The documents in it, and your notes and highlights on them, stay.',
    )).toBeTruthy();
    expect(within(question).getAllByRole('button').map((button) => button.textContent)).toEqual(['Cancel', 'Delete']);
    await userEvent.click(within(question).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(true));
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Delete… Cuba'));
  });

  /** The server's rename as a stub: the name trimmed, one left empty keeping the old, and the renamed first. */
  function renaming() {
    let items = [listed({ id: berlinId, name: 'Berlin' }), listed({ id: cubaId, name: 'Cuba' })];
    const fetch = server({
      '/api/v1/me/collections': () => ({ total: items.length, items }),
      [`POST /api/v1/me/collections/${cubaId}/rename`]: (_url: URL, init?: RequestInit) => {
        const name = (sent(init).body as { name: string }).name.trim();
        if (name !== '') items = [listed({ id: cubaId, name }), ...items.filter((item) => item.id !== cubaId)];
        return detail({ id: cubaId, name: name || 'Cuba', listName: name || 'Cuba' });
      },
    });
    return fetch;
  }

  it('renames a collection by the app’s Rename Collection alert, the field holding its saved name, and keeps focus on its Rename', async () => {
    const fetch = renaming();
    renderAt('/collections');
    const rows = await screen.findByRole('list', { name: 'Collections' });
    expect(within(within(rows).getAllByRole('listitem')[0]!).getAllByRole('button').map((button) => button.textContent)).toEqual([
      'Rename',
      'Duplicate',
      'Delete…',
    ]);
    await userEvent.click(screen.getByRole('button', { name: 'Rename Cuba' }));
    const alert = screen.getByRole('dialog', { name: 'Rename Collection' });
    const field = within(alert).getByRole('textbox', { name: 'Collection Name' });
    expect(field).toHaveProperty('value', 'Cuba');
    expect(field.getAttribute('placeholder')).toBe('Collection Name');
    await waitFor(() => expect(document.activeElement).toBe(field));
    await userEvent.clear(field);
    await userEvent.type(field, ' Havana {Enter}');
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Rename Collection' })).toBeNull());
    const renamed = fetch.mock.calls.find(([url]) => String(url).endsWith('/rename'));
    expect(sent(renamed?.[1]).body).toEqual({ name: ' Havana ' });
    await waitFor(() => expect(within(rows).getAllByRole('link').map((link) => link.textContent)).toEqual(['Havana', 'Berlin']));
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Rename Havana'));
  });

  it('keeps the old name for a name left empty, Save offered as the app’s alert offers it, and sends nothing for Cancel or the name as it opened', async () => {
    const fetch = renaming();
    renderAt('/collections');
    await userEvent.click(await screen.findByRole('button', { name: 'Rename Cuba' }));
    let alert = screen.getByRole('dialog', { name: 'Rename Collection' });
    await userEvent.type(within(alert).getByRole('textbox', { name: 'Collection Name' }), 'n');
    await userEvent.click(within(alert).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Rename Cuba'));
    // Save on the name as it opened writes nothing, so a rename made elsewhere since the list was read stands.
    await userEvent.click(screen.getByRole('button', { name: 'Rename Cuba' }));
    alert = screen.getByRole('dialog', { name: 'Rename Collection' });
    expect(within(alert).getByRole('textbox', { name: 'Collection Name' })).toHaveProperty('value', 'Cuba');
    await userEvent.click(within(alert).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Rename Collection' })).toBeNull());
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Rename Cuba'));
    expect(fetch.mock.calls.some(([url]) => String(url).endsWith('/rename'))).toBe(false);

    await userEvent.click(screen.getByRole('button', { name: 'Rename Cuba' }));
    alert = screen.getByRole('dialog', { name: 'Rename Collection' });
    expect(within(alert).getByRole('textbox', { name: 'Collection Name' })).toHaveProperty('value', 'Cuba');
    await userEvent.clear(within(alert).getByRole('textbox', { name: 'Collection Name' }));
    const save = within(alert).getByRole('button', { name: 'Save' });
    expect(save.getAttribute('aria-disabled')).toBe('false');
    await userEvent.click(save);
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Rename Collection' })).toBeNull());
    expect(sent(fetch.mock.calls.find(([url]) => String(url).endsWith('/rename'))?.[1]).body).toEqual({ name: '' });
    expect(within(screen.getByRole('list', { name: 'Collections' })).getAllByRole('link').map((link) => link.textContent)).toEqual([
      'Berlin',
      'Cuba',
    ]);
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Rename Cuba'));
  });

  /** A list of Berlin and Cuba whose answer to `change` waits until the test gives it. */
  function answeredLater(change: string) {
    let answer: (value: unknown) => void = () => {};
    const items = [listed({ id: berlinId, name: 'Berlin' }), listed({ id: cubaId, name: 'Cuba' })];
    const fetch = server({
      '/api/v1/me/collections': { total: items.length, items },
      [change]: () =>
        new Promise((resolve) => {
          answer = resolve;
        }),
    });
    const lists = () => fetch.mock.calls.filter(([url]) => String(url).endsWith('/api/v1/me/collections')).length;
    return { answer: (value: unknown) => answer(value), lists };
  }

  it('leaves a dialog opened since alone when a rename is answered after its Cancel', async () => {
    const later = answeredLater(`POST /api/v1/me/collections/${cubaId}/rename`);
    renderAt('/collections');
    await userEvent.click(await screen.findByRole('button', { name: 'Rename Cuba' }));
    const cuba = screen.getByRole('dialog', { name: 'Rename Collection' });
    await userEvent.type(within(cuba).getByRole('textbox', { name: 'Collection Name' }), 'n{Enter}');
    await userEvent.click(within(cuba).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Rename Cuba'));
    await userEvent.click(screen.getByRole('button', { name: 'Rename Berlin' }));
    const berlin = within(screen.getByRole('dialog', { name: 'Rename Collection' })).getByRole('textbox', { name: 'Collection Name' });
    await waitFor(() => expect(document.activeElement).toBe(berlin));
    const read = later.lists();
    later.answer(detail({ id: cubaId, name: 'Cuban', listName: 'Cuban' }));
    // Once the answer has been taken, the list is read again; Berlin's alert stays, its field focused.
    await waitFor(() => expect(later.lists()).toBeGreaterThan(read));
    await new Promise((resolve) => requestAnimationFrame(resolve));
    expect(berlin.isConnected).toBe(true);
    expect(document.activeElement).toBe(berlin);
  });

  it('leaves a question asked since alone when a delete is answered after its Cancel', async () => {
    const later = answeredLater(`DELETE /api/v1/me/collections/${berlinId}`);
    renderAt('/collections');
    await userEvent.click(await screen.findByRole('button', { name: 'Delete… Berlin' }));
    const berlin = screen.getByRole('alertdialog', { name: 'Delete “Berlin”?' });
    await userEvent.click(within(berlin).getByRole('button', { name: 'Delete' }));
    await userEvent.click(within(berlin).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Delete… Berlin'));
    await userEvent.click(screen.getByRole('button', { name: 'Delete… Cuba' }));
    const cuba = screen.getByRole('alertdialog', { name: 'Delete “Cuba”?' });
    await waitFor(() => expect(document.activeElement).toBe(within(cuba).getByRole('button', { name: 'Cancel' })));
    const read = later.lists();
    later.answer(null);
    await waitFor(() => expect(later.lists()).toBeGreaterThan(read));
    await new Promise((resolve) => requestAnimationFrame(resolve));
    expect(cuba.isConnected).toBe(true);
    expect(document.activeElement).toBe(within(cuba).getByRole('button', { name: 'Cancel' }));
  });
});

describe('a collection’s editor', () => {
  it('draws each row as the app’s: a heading, a document with its chips, a note block, an excerpt and a block', async () => {
    server({ [`/api/v1/me/collections/${berlinId}`]: detail({ entries: outline, documentCount: 1 }) });
    renderAt(`/collections/${berlinId}`);
    await screen.findByRole('list', { name: 'Contents' });
    const rows = contentRows();
    expect((within(rows[0]!).getByRole('textbox', { name: 'Section heading' }) as HTMLInputElement).value).toBe('Europe');
    expect(within(rows[1]!).getByText('1. Telegram From the Embassy in the Soviet Union')).toBeTruthy();
    expect(rows[1]!.querySelector('.meta')?.textContent).toBe('d1 · Kennedy-Khrushchev Exchanges · 1960-11-09');
    expect([...rows[1]!.querySelectorAll('.chip')].map((chip) => chip.textContent)).toEqual(['Index', '2 notes']);
    expect(within(rows[2]!).getByText('Read these together.')).toBeTruthy();
    expect(within(rows[3]!).getByRole('group', { name: 'Excerpt from d2: Allow me to congratulate you.' })).toBeTruthy();
    expect(within(rows[4]!).getByText('Chronology')).toBeTruthy();
    expect(within(rows[4]!).getByText('Lists 1 document. Generated from this collection’s documents at export and in the preview.')).toBeTruthy();
    expect(rows.map((row) => row.className.match(/indent-\d/)?.[0])).toEqual(['indent-0', 'indent-1', 'indent-1', 'indent-1', 'indent-1']);
  });

  it('collapses a section, saying how many it hides', async () => {
    server({ [`/api/v1/me/collections/${berlinId}`]: detail({ entries: outline }) });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Collapse section' }));
    expect(contentRows()).toHaveLength(1);
    expect(screen.getByText('4 hidden')).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: 'Expand section' }));
    expect(contentRows()).toHaveLength(5);
  });

  it('adds a section heading from the Add menu and puts focus in its title', async () => {
    const heading = entry({ id: 'E9', kind: 'heading', text: '', depth: 1 });
    const fetch = server({
      [`/api/v1/me/collections/${berlinId}`]: detail(),
      [`POST /api/v1/me/collections/${berlinId}/blocks`]: { collection: detail({ entries: [heading] }), entryIds: ['E9'] },
    });
    renderAt(`/collections/${berlinId}`);
    expect(await screen.findByText('No content yet. Add documents, headings, notes, and apparatus from the toolbar above.')).toBeTruthy();
    await userEvent.click(screen.getByRole('button', { name: /Add documents, a section heading/ }));
    const menu = screen.getByRole('menu');
    expect(within(menu).getByRole('menuitem', { name: 'Add Highlighted Passages…' }).getAttribute('aria-disabled')).toBe('true');
    expect(within(within(menu).getByRole('group', { name: 'Apparatus' })).getAllByRole('menuitem').map((item) => item.textContent)).toEqual([
      'Bibliography',
      'Chronology',
      'Sources & Archives',
      'Persons Index',
      'Thematic Index',
    ]);
    await userEvent.click(within(menu).getByRole('menuitem', { name: 'Add Section Heading' }));
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('textbox', { name: 'Section heading' })));
    expect(sent(fetch.mock.calls.find(([url]) => String(url).endsWith('/blocks'))?.[1]).body).toEqual({ kind: 'heading' });
  });

  it('moves a row down as the app’s Move Down does, a heading taking its section', async () => {
    const two = [
      entry({ id: 'E1', kind: 'heading', text: 'Europe', depth: 1, sectionEnd: 2 }),
      entry({ id: 'E2', kind: 'document', depth: 1, volumeId: 'frus1961-63v06', documentId: 'd1' }),
      entry({ id: 'E3', kind: 'heading', text: 'Asia', depth: 1, sectionEnd: 4 }),
      entry({ id: 'E4', kind: 'document', depth: 1, volumeId: 'frus1961-63v06', documentId: 'd2' }),
    ];
    const fetch = server({
      [`/api/v1/me/collections/${berlinId}`]: detail({ entries: two }),
      [`POST /api/v1/me/collections/${berlinId}/move`]: detail({ entries: two }),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Actions: Europe' }));
    expect(within(screen.getByRole('menu')).queryByRole('menuitem', { name: 'Move Up' })).toBeNull();
    await userEvent.click(within(screen.getByRole('menu')).getByRole('menuitem', { name: 'Move Down' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).endsWith('/move'))).toBe(true));
    expect(sent(fetch.mock.calls.find(([url]) => String(url).endsWith('/move'))?.[1]).body).toEqual({ entryId: 'E1', before: 'E4' });
  });

  it('asks before a heading’s Delete Section, with the app’s count', async () => {
    const fetch = server({
      [`/api/v1/me/collections/${berlinId}`]: detail({ entries: outline }),
      [`POST /api/v1/me/collections/${berlinId}/entries/E1/delete-section`]: detail(),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Actions: Europe' }));
    await userEvent.click(within(screen.getByRole('menu')).getByRole('menuitem', { name: 'Delete Section' }));
    const question = screen.getByRole('alertdialog', { name: 'Delete Section?' });
    expect(within(question).getByText('Deletes this heading and the 4 entries it contains.')).toBeTruthy();
    await userEvent.click(within(question).getByRole('button', { name: 'Delete Section' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).endsWith('/delete-section'))).toBe(true));
  });

  it('saves a heading’s title as it is typed, once the typing stops', async () => {
    const fetch = server({
      [`/api/v1/me/collections/${berlinId}`]: detail({ entries: outline }),
      [`PATCH /api/v1/me/collections/${berlinId}/entries/E1`]: (_url: URL, init?: RequestInit) =>
        detail({ entries: [{ ...outline[0]!, text: sent(init).body.text }, ...outline.slice(1)] }),
    });
    renderAt(`/collections/${berlinId}`);
    const title = await screen.findByRole('textbox', { name: 'Section heading' });
    await userEvent.type(title, ' 1961');
    await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(true), { timeout: 2000 });
    const patches = fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH');
    expect(patches).toHaveLength(1);
    expect(sent(patches[0]![1]).body).toEqual({ text: 'Europe 1961' });
  });

  it('applies a preset from Collection settings, Briefing packet offered only where the server offers it', async () => {
    const fetch = server({
      [`/api/v1/me/collections/${berlinId}`]: detail({ entries: outline }),
      [`POST /api/v1/me/collections/${berlinId}/preset`]: detail({
        entries: outline,
        presets: [
          { id: 'teachingReader', active: true },
          { id: 'sourceDossier', active: false },
          { id: 'scholarlyEdition', active: false },
        ],
      }),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Collection settings' }));
    const settings = screen.getByRole('dialog', { name: 'Collection settings' });
    expect(within(settings).queryByRole('button', { name: /Briefing packet/ })).toBeNull();
    const teaching = within(settings).getByRole('button', { name: /Teaching reader/ });
    expect(teaching.getAttribute('aria-pressed')).toBe('false');
    await userEvent.click(teaching);
    await waitFor(() => expect(within(screen.getByRole('dialog', { name: 'Collection settings' })).getByRole('button', { name: /Teaching reader/ }).getAttribute('aria-pressed')).toBe('true'));
    expect(sent(fetch.mock.calls.find(([url]) => String(url).endsWith('/preset'))?.[1]).body).toEqual({ preset: 'teachingReader' });
    // Highlights in body only for a full body.
    expect((within(settings).getByRole('switch', { name: 'Highlights in body' }) as HTMLInputElement).disabled).toBe(false);
  });

  it('shows a document’s inspector and writes an inclusion as it is changed', async () => {
    const inspector: EntryInspector = {
      entryId: 'E2',
      kind: 'document',
      documentId: 'd1',
      volumeId: 'frus1961-63v06',
      header: '1. Telegram From the Embassy in the Soviet Union',
      volumeTitle: 'Kennedy-Khrushchev Exchanges',
      derivedTitle: 'Foreign Relations of the United States, 1961–1963, Volume VI, Document 1',
      notes: [{ id: 'N1', preview: 'The first note', included: true }],
      highlights: [{ id: 'H1', colorTag: 'yellow', text: 'Allow me', included: true }],
      tags: ['Berlin'],
      resolved: { bodyDepth: 'full', highlights: false, notes: true, sourceNote: false, footnotes: true, related: false, headnote: false },
      excerpts: [],
    };
    const fetch = server({
      [`/api/v1/me/collections/${berlinId}`]: detail({ entries: outline }),
      [`/api/v1/me/collections/${berlinId}/entries/E2/inspector`]: inspector,
      [`PATCH /api/v1/me/collections/${berlinId}/entries/E2`]: detail({ entries: outline }),
      [`POST /api/v1/me/collections/${berlinId}/excerpts`]: { collection: detail({ entries: outline }), entryIds: ['E7'] },
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Configure: 1. Telegram From the Embassy in the Soviet Union' }));
    const sheet = screen.getByRole('dialog', { name: 'Berlin' });
    expect(await within(sheet).findByText('Kennedy-Khrushchev Exchanges')).toBeTruthy();
    expect((within(sheet).getByRole('textbox', { name: 'Title override' }) as HTMLInputElement).placeholder).toBe(inspector.derivedTitle);
    expect(within(sheet).getByText('1 highlight')).toBeTruthy();
    // Body depth set on the entry shows no Default line; Highlights at Default shows what it resolves to.
    expect((within(sheet).getByRole('combobox', { name: 'Body depth' }) as HTMLSelectElement).value).toBe('index');
    expect(within(sheet).getAllByText('Default → Off').length).toBeGreaterThan(0);
    await userEvent.click(within(sheet).getByRole('checkbox', { name: 'Include this research note when notes apply: The first note' }));
    await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(true));
    expect(sent(fetch.mock.calls.find(([, init]) => init?.method === 'PATCH')?.[1]).body).toEqual({ note: { id: 'N1', included: false } });
    await userEvent.click(within(sheet).getByRole('button', { name: 'Insert as Excerpt' }));
    expect(await within(sheet).findByText('Inserted')).toBeTruthy();
    expect(sent(fetch.mock.calls.find(([url]) => String(url).endsWith('/excerpts'))?.[1]).body).toEqual({ highlightIds: ['H1'] });
    await userEvent.click(within(sheet).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(document.activeElement?.getAttribute('aria-label')).toBe('Configure: 1. Telegram From the Embassy in the Soviet Union'));
  });

  it('says a smart collection is one, and takes nothing by hand but its apparatus', async () => {
    server({
      [`/api/v1/me/collections/${berlinId}`]: detail({
        savedSearchId: 'S',
        takesHandAddedEntries: false,
        entries: [{ ...outline[1]!, leftOut: true }, outline[4]!],
      }),
    });
    renderAt(`/collections/${berlinId}`);
    expect(await screen.findByText('Smart collection. Its documents come from its saved search.')).toBeTruthy();
    expect(contentRows()).toHaveLength(1);
    expect(screen.queryByRole('button', { name: 'Add Documents…' })).toBeNull();
    await userEvent.click(screen.getByRole('button', { name: /Add documents, a section heading/ }));
    const menu = screen.getByRole('menu');
    expect(within(menu).getByRole('menuitem', { name: 'Add Section Heading' }).getAttribute('aria-disabled')).toBe('true');
    expect(within(menu).getByRole('menuitem', { name: 'Chronology' }).getAttribute('aria-disabled')).toBeNull();
  });
});
