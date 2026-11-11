// Add Documents' Citations and Tags (S25d), against a stubbed server: the app's four tabs in its order; a paste
// resolved, with its count of lines resolved and to review, the lines that resolved chosen at once and a line to
// review left to the reader, with its note as its row's description, a line that named no document said, a line
// the reader unchose left unchosen by the next Resolve, the paste kept across tabs, and a refusal said; and a tag's
// documents chosen as it opens, focus handed into and back out of it, and the app's words for no tags, a tag with
// no documents and nothing to resolve.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { CitationLines, DiscoveryTags, TagDocuments } from '../api/addDocuments';
import type { CollectionDetail, CollectionEntry } from '../api/collections';
import { renderWithClient, sent } from '../test/notes';
import { ProblemAnswer, stubServer } from '../test/renderRoute';
import { AddDocuments } from './AddDocuments';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader'], userData: true, csrfToken: 't' };
const id = 'C0110000-0000-4000-8000-000000000001';
const cubaId = '7A600000-0000-4000-8000-000000000001';
const idleId = '7A600000-0000-4000-8000-000000000002';
const citationsPath = '/api/v1/me/add-documents/citations';
const tagsPath = '/api/v1/me/add-documents/tags';
const documentsPath = `/api/v1/me/collections/${id}/documents`;

function detail(entries: CollectionEntry[] = []): CollectionDetail {
  return {
    id,
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
    documentCount: entries.length,
    volumesNotHeld: [],
    entries,
  };
}

/** The collection holds frus1961-63v06's d1 already. */
const holdingD1 = detail([
  {
    id: 'E1',
    kind: 'document',
    sortOrder: 0,
    level: 1,
    depth: 0,
    documentId: 'd1',
    volumeId: 'frus1961-63v06',
    formattingKept: false,
    selectedNoteIds: [],
    selectedHighlightIds: [],
    canIndent: false,
    canOutdent: false,
    leftOut: false,
    isDuplicate: false,
  },
]);

const guessNote = 'Exact match — the citation doesn’t identify a volume, so this match is a guess';
const unparseable = 'Couldn’t read this line as a FRUS citation or document link';
const resolvedLines: CitationLines = {
  total: 4,
  items: [
    {
      line: 'FRUS, 1961–1963, vol. VI, doc. 1',
      outcome: 'resolved',
      volumeId: 'frus1961-63v06',
      documentId: 'd1',
      header: '1. Telegram From the Embassy in the Soviet Union',
      volumeTitle: 'Kennedy-Khrushchev Exchanges',
    },
    {
      line: 'Document 2',
      outcome: 'ambiguous',
      volumeId: 'frus1961-63v06',
      documentId: 'd2',
      note: guessNote,
      header: '2. Memorandum of Conversation',
      volumeTitle: 'Kennedy-Khrushchev Exchanges',
    },
    { line: 'https://history.state.gov/historicaldocuments/frus1964-68v30/d12', outcome: 'resolved', volumeId: 'frus1964-68v30', documentId: 'd12', volumeTitle: 'China' },
    { line: 'a grocery list', outcome: 'unresolved', reason: unparseable },
  ],
};

const tags: DiscoveryTags = {
  total: 2,
  items: [
    { id: cubaId, name: 'Cuba', count: 3 },
    { id: idleId, name: 'Idle', count: 0 },
  ],
};
const cuba: TagDocuments = {
  id: cubaId,
  name: 'Cuba',
  total: 3,
  items: [
    { volumeId: 'frus1894Nicaragua', documentId: 'd1', header: 'No. 1. Mr. Baker to Mr. Gresham', volumeTitle: 'Nicaragua' },
    { volumeId: 'frus1961-63v06', documentId: 'd1', header: '1. Telegram From the Embassy in the Soviet Union', volumeTitle: 'Kennedy-Khrushchev Exchanges' },
    { volumeId: 'frus1964-68v30', documentId: 'd12', volumeTitle: 'China' },
  ],
};

function server(answers: Record<string, unknown> = {}) {
  return stubServer({
    '/api/v1/me': me,
    [`POST ${citationsPath}`]: resolvedLines,
    [tagsPath]: tags,
    [`${tagsPath}/${cubaId}`]: cuba,
    [`${tagsPath}/${idleId}`]: { id: idleId, name: 'Idle', total: 0, items: [] },
    [`POST ${documentsPath}`]: { collection: detail(), entryIds: [] },
    ...answers,
  });
}

const sheet = () => screen.getByRole('dialog', { name: 'Add Documents' });
const checkbox = (name: string) => within(sheet()).getByRole('checkbox', { name }) as HTMLInputElement;

async function openCitations() {
  await userEvent.click(within(sheet()).getByRole('button', { name: 'Citations' }));
  return within(sheet()).getByRole('textbox', { name: 'Paste citations or history.state.gov links, one per line…' }) as HTMLTextAreaElement;
}

async function resolvePaste(text: string) {
  const field = await openCitations();
  await userEvent.click(field);
  await userEvent.paste(text);
  await userEvent.click(within(sheet()).getByRole('button', { name: 'Resolve' }));
  await within(sheet()).findByRole('list', { name: 'Citations' });
}

describe("Add Documents' tabs", () => {
  it("are the app's four, in its order", () => {
    server();
    renderWithClient(<AddDocuments detail={detail()} onClose={() => {}} />);
    const group = within(sheet()).getByRole('group', { name: 'Find documents' });
    expect(within(group).getAllByRole('button').map((button) => button.textContent)).toEqual(['Search', 'Browse', 'Citations', 'Tags']);
  });
});

describe('the Citations tab', () => {
  it('resolves a paste, chooses what resolved at once and leaves a line to review to the reader', async () => {
    const fetch = server();
    const closed = vi.fn();
    renderWithClient(<AddDocuments detail={holdingD1} onClose={closed} />);
    const field = await openCitations();
    expect(within(sheet()).getByText(/Each line is resolved against the FRUS manifest and this server’s index/)).toBeTruthy();
    await userEvent.click(field);
    await userEvent.paste('FRUS, 1961–1963, vol. VI, doc. 1\nDocument 2');
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Resolve' }));
    const rows = within(await within(sheet()).findByRole('list', { name: 'Citations' })).getAllByRole('listitem');
    const posted = fetch.mock.calls.filter(([url]) => String(url).endsWith(citationsPath)).map(([, init]) => sent(init));
    expect(posted).toEqual([{ body: { text: 'FRUS, 1961–1963, vol. VI, doc. 1\nDocument 2' }, token: 't' }]);

    expect(within(sheet()).getByRole('status').textContent).toBe('2 of 4 resolved · 1 to review');
    expect(rows).toHaveLength(4);
    expect(checkbox('1. Telegram From the Embassy in the Soviet Union').checked).toBe(true);
    expect(checkbox('2. Memorandum of Conversation').checked).toBe(false);
    expect(checkbox('d12').checked).toBe(true);
    // Each row as the app's: its caption, the line pasted, and the resolver's note, a warning on a line to review,
    // which describes its checkbox; In collection on a document the collection holds.
    expect(rows[0]!.textContent).toContain('d1 · Kennedy-Khrushchev Exchanges · In collection');
    expect(rows[0]!.textContent).toContain('FRUS, 1961–1963, vol. VI, doc. 1');
    expect(rows[2]!.textContent).toContain('China');
    const ambiguous = checkbox('2. Memorandum of Conversation');
    const described = (ambiguous.getAttribute('aria-describedby') ?? '').split(' ').map((part) => document.getElementById(part)?.textContent);
    expect(described).toEqual(['Document 2', guessNote]);
    expect(within(rows[1]!).getByText(guessNote).className).toBe('pick-note warning');
    expect(rows[3]!.textContent).toBe(`a grocery listNo match — ${unparseable}`);
    expect(within(rows[3]!).queryByRole('checkbox')).toBeNull();

    // The line to review, chosen by the reader, joins the choices after those chosen at once.
    await userEvent.click(ambiguous);
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Add 3 Document(s)' }));
    await waitFor(() => expect(closed).toHaveBeenCalledWith(3));
    const added = fetch.mock.calls.filter(([url]) => String(url).endsWith('/documents')).map(([, init]) => sent(init).body);
    expect(added).toEqual([
      {
        documents: [
          { volumeId: 'frus1961-63v06', documentId: 'd1' },
          { volumeId: 'frus1964-68v30', documentId: 'd12' },
          { volumeId: 'frus1961-63v06', documentId: 'd2' },
        ],
      },
    ]);
  });

  it('leaves a document the reader unchose unchosen when the paste is resolved again', async () => {
    const fetch = server();
    renderWithClient(<AddDocuments detail={detail()} onClose={() => {}} />);
    await resolvePaste('FRUS, 1961–1963, vol. VI, doc. 1');
    await userEvent.click(checkbox('1. Telegram From the Embassy in the Soviet Union'));
    expect(within(sheet()).getByRole('button', { name: 'Add 1 Document(s)' })).toBeTruthy();
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Resolve' }));
    // The second answer, once it has come: the line before it says Resolving….
    await waitFor(() => expect(fetch.mock.calls.filter(([url]) => String(url).endsWith(citationsPath))).toHaveLength(2));
    await waitFor(() => expect(within(sheet()).getByRole('status').textContent).toBe('2 of 4 resolved · 1 to review'));
    expect(checkbox('1. Telegram From the Embassy in the Soviet Union').checked).toBe(false);
    expect(checkbox('d12').checked).toBe(true);
    expect(within(sheet()).getByRole('button', { name: 'Add 1 Document(s)' })).toBeTruthy();
    // Chosen again by hand, it is the reader's again: the next Resolve keeps it.
    await userEvent.click(checkbox('1. Telegram From the Embassy in the Soviet Union'));
    expect(within(sheet()).getByRole('button', { name: 'Add 2 Document(s)' })).toBeTruthy();
  });

  it('keeps the paste and its lines while the sheet is open, across its tabs', async () => {
    server();
    renderWithClient(<AddDocuments detail={detail()} onClose={() => {}} />);
    await resolvePaste('FRUS, 1961–1963, vol. VI, doc. 1');
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Search' }));
    expect(within(sheet()).queryByRole('list', { name: 'Citations' })).toBeNull();
    const field = await openCitations();
    expect(field.value).toBe('FRUS, 1961–1963, vol. VI, doc. 1');
    expect(within(within(sheet()).getByRole('list', { name: 'Citations' })).getAllByRole('listitem')).toHaveLength(4);
    expect(within(sheet()).getByRole('button', { name: 'Add 2 Document(s)' })).toBeTruthy();
  });

  it('waits for a line to resolve, says when there is none, and says why the server refused one', async () => {
    const fetch = server({
      [`POST ${citationsPath}`]: (_url: URL, init?: RequestInit) =>
        sent(init).body.text === 'none'
          ? { total: 0, items: [] }
          : new ProblemAnswer(400, 'TOO_MANY_CITATIONS', 'Add Documents resolves at most 500 lines at a time, and this text holds 501. Paste it in parts.'),
    });
    renderWithClient(<AddDocuments detail={detail()} onClose={() => {}} />);
    const field = await openCitations();
    const resolve = within(sheet()).getByRole('button', { name: 'Resolve' });
    expect(resolve.getAttribute('aria-disabled')).toBe('true');
    await userEvent.click(field);
    await userEvent.paste(' \n\t ');
    expect(resolve.getAttribute('aria-disabled')).toBe('true');
    await userEvent.click(resolve);
    expect(fetch.mock.calls.some(([url]) => String(url).endsWith(citationsPath))).toBe(false);

    await userEvent.clear(field);
    await userEvent.paste('none');
    await userEvent.click(resolve);
    await waitFor(() => expect(within(sheet()).getByRole('status').textContent).toBe('Nothing to resolve — paste at least one line.'));

    await userEvent.clear(field);
    await userEvent.paste('too many');
    await userEvent.click(resolve);
    expect((await within(sheet()).findByRole('alert')).textContent).toContain('Add Documents resolves at most 500 lines at a time');
    expect(within(sheet()).queryByRole('list', { name: 'Citations' })).toBeNull();
  });
});

describe('the Tags tab', () => {
  it("lists each tag with its count, and chooses a tag's documents as it opens", async () => {
    const fetch = server();
    renderWithClient(<AddDocuments detail={detail()} onClose={() => {}} />);
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Tags' }));
    const list = await within(sheet()).findByRole('list', { name: 'Tags' });
    expect(within(list).getAllByRole('button').map((button) => button.textContent)).toEqual(['Cuba 3', 'Idle 0']);

    const opener = within(list).getByRole('button', { name: 'Cuba 3' });
    await userEvent.click(opener);
    const gathered = await within(sheet()).findByRole('list', { name: 'Cuba' });
    // The tab's button and the drill-in's Tags share the app's word: the drill-in's, the later, takes the focus.
    const back = () => within(sheet()).getAllByRole('button', { name: 'Tags' }).at(-1)!;
    await waitFor(() => expect(document.activeElement).toBe(back()));
    expect(within(gathered).getAllByRole('checkbox').map((box) => [box.getAttribute('aria-describedby'), (box as HTMLInputElement).checked])).toEqual([
      [null, true],
      [null, true],
      [null, true],
    ]);
    expect(
      within(gathered)
        .getAllByRole('listitem')
        .map((row) => [row.querySelector('.pick-title')?.textContent, row.querySelector('.meta')?.textContent]),
    ).toEqual([
      ['No. 1. Mr. Baker to Mr. Gresham', 'd1 · Nicaragua'],
      ['1. Telegram From the Embassy in the Soviet Union', 'd1 · Kennedy-Khrushchev Exchanges'],
      ['d12', 'China'],
    ]);
    expect(within(sheet()).getByRole('button', { name: 'Add 3 Document(s)' })).toBeTruthy();

    // Unchosen, a document stays so when the tag is opened again.
    await userEvent.click(checkbox('d12'));
    await userEvent.click(back());
    await waitFor(() => expect(document.activeElement?.textContent).toBe('Cuba 3'));
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Cuba 3' }));
    await within(sheet()).findByRole('list', { name: 'Cuba' });
    expect(within(sheet()).getByRole('button', { name: 'Add 2 Document(s)' })).toBeTruthy();
    expect(checkbox('d12').checked).toBe(false);
    expect(fetch.mock.calls.some(([url]) => String(url).endsWith(`${tagsPath}/${cubaId}`))).toBe(true);
  });

  it("says the app's words for no tags, and for a tag with no documents", async () => {
    server({ [tagsPath]: { total: 0, items: [] } });
    const first = renderWithClient(<AddDocuments detail={detail()} onClose={() => {}} />);
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Tags' }));
    expect(await within(sheet()).findByText('No user tags yet. Tag documents or research notes to gather them here.')).toBeTruthy();
    first.unmount();

    server();
    renderWithClient(<AddDocuments detail={detail()} onClose={() => {}} />);
    await userEvent.click(within(sheet()).getByRole('button', { name: 'Tags' }));
    await userEvent.click(await within(sheet()).findByRole('button', { name: 'Idle 0' }));
    expect(await within(sheet()).findByText('No documents carry this tag.')).toBeTruthy();
    expect(within(sheet()).getByRole('heading', { name: 'Idle' })).toBeTruthy();
  });
});
