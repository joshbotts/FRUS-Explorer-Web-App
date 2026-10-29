// A collection's live preview and its export sheet (S18e), against a stubbed server: the frame sent to
// the server's page, the first 20 documents until Render All, again a second after a change, the bars
// for the cap and the volumes the server lacks, and a smart collection's results counted (S18f); the
// sheet's sentence, grid and quotation check, Export {Format} saving the server's file under its name,
// the native file with its notes switch, which a smart collection's grid drops (S18f), a refusal in
// the app's words, and focus back on Export… when it closes.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CollectionDetail, CollectionEntry } from '../api/collections';
import { sent } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { compositionSentence } from './exportRules';

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const berlinId = 'C0110000-0000-4000-8000-000000000001';
const path = `/api/v1/me/collections/${berlinId}`;

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

const documents = (count: number) =>
  Array.from({ length: count }, (_, at) => entry({ id: `E${at + 1}`, kind: 'document', volumeId: 'frus1961-63v06', documentId: `d${at + 1}` }));

function detail(fields: Partial<CollectionDetail> = {}): CollectionDetail {
  const entries = fields.entries ?? documents(2);
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
    documentCount: entries.filter((each) => each.kind === 'document').length,
    volumesNotHeld: [],
    ...fields,
    entries,
  };
}

function server(answers: Record<string, unknown>) {
  return stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/projects': { items: [] }, '/api/v1/me/preferences': {}, ...answers });
}

/** Where the preview's frame has been sent, each address in turn, in its own place in the history. */
let navigations: string[] = [];

/** The address the frame was last sent to, read as the server reads it. */
function frameAddress(): URL {
  return new URL(navigations.at(-1) ?? '', 'http://localhost');
}

const pause = (milliseconds: number) => new Promise((resolve) => setTimeout(resolve, milliseconds));

beforeEach(() => {
  vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }));
  navigations = [];
  vi.spyOn(HTMLIFrameElement.prototype, 'contentWindow', 'get').mockReturnValue({
    location: { replace: (address: string) => navigations.push(address) },
  } as unknown as Window);
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe('the sheet’s sentence of what an export carries', () => {
  it('is the app’s: the default depth, then what the composition turns on, joined as US English joins them', () => {
    expect(compositionSentence(detail({ includeNotes: false, includeFootnotes: false }))).toBe('Exports the full text of each document.');
    expect(compositionSentence(detail())).toBe('Exports the full text of each document, with your notes and footnotes.');
    expect(
      compositionSentence(
        detail({ defaultBodyDepth: 'summaryOnly', defaultIncludeHeadnote: true, includeSourceNote: true, applyHighlights: true, includeWordCloud: true }),
      ),
    ).toBe('Exports an AI summary of each document, with headnotes, your notes, footnotes, source notes, highlights, and a word-cloud overview.');
    expect(compositionSentence(detail({ defaultBodyDepth: 'index', includeNotes: false }))).toBe('Exports a citation-only index, with footnotes.');
  });
});

describe('the live preview', () => {
  it('sends its frame to the server’s page, the first 20 documents until Render All, and names the volumes the server lacks', async () => {
    server({ [path]: detail({ entries: documents(22), volumesNotHeld: ['frus1961-63v05'] }) });
    renderAt(`/collections/${berlinId}`);
    await waitFor(() => expect(frameAddress().pathname).toBe(`${path}/preview`));
    expect(frameAddress().searchParams.get('renderAll')).toBe('false');
    expect(frameAddress().searchParams.get('timeZone')).toBeTruthy();
    const frame = screen.getByTitle('Preview of the collection’s HTML export');
    expect(frame.getAttribute('sandbox')).toBe('allow-scripts allow-popups allow-popups-to-escape-sandbox');
    expect(screen.getByText('Showing first 20 of 22 documents')).toBeTruthy();
    expect(screen.getByText('1 volume not downloaded')).toBeTruthy();
    expect(screen.getByText('Preview of the HTML export — PDF and Word pagination will differ')).toBeTruthy();

    // Render All, at once, for as long as the editor is open; its bar goes, and focus with it to the
    // preview, which says what it shows.
    const renderAll = screen.getByRole('button', { name: 'Render All' });
    renderAll.focus();
    await userEvent.keyboard('{Enter}');
    await waitFor(() => expect(frameAddress().searchParams.get('renderAll')).toBe('true'));
    expect(screen.queryByText('Showing first 20 of 22 documents')).toBeNull();
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('region', { name: 'Preview' })));
    expect(screen.getByText('Showing all 22 documents')).toBeTruthy();
    expect(navigations).toHaveLength(2);
  });

  it('builds the page again a second after a change is answered, and once, never while the change waits', async () => {
    let answer: (value: unknown) => void = () => {};
    const fetch = server({
      [path]: detail(),
      // The server's answer, held until the test gives it, a stamp unlike the change shown at once.
      [`PATCH ${path}`]: () => new Promise((resolve) => (answer = resolve)),
    });
    renderAt(`/collections/${berlinId}`);
    await waitFor(() => expect(navigations).toHaveLength(1));
    expect(frameAddress().pathname).toBe(`${path}/preview`);
    await userEvent.click(screen.getByRole('button', { name: 'Collection settings' }));
    await userEvent.click(within(screen.getByRole('dialog', { name: 'Collection settings' })).getByRole('switch', { name: 'Include colophon' }));
    await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(true));
    await pause(1_300);
    expect(navigations, 'not while the change waits for its answer').toHaveLength(1);
    answer(detail({ includeColophon: true, lastModified: '2026-10-29T12:00:00.000Z' }));
    await waitFor(() => expect(navigations).toHaveLength(2), { timeout: 2_500 });
    await pause(1_300);
    expect(navigations, 'once').toHaveLength(2);
  });

  it('previews a smart collection’s results, and counts them in the bar as the app counts those it fetched', async () => {
    const results = Array.from({ length: 25 }, (_, at) => ({ volumeId: 'frus1961-63v06', documentId: `d${at + 1}` }));
    server({
      // A volume named, which the preview does not count for a smart collection, as the app counts none.
      [path]: detail({
        savedSearchId: 'S0000000-0000-4000-8000-000000000001',
        takesHandAddedEntries: false,
        entries: [],
        volumesNotHeld: ['frus1961-63v05'],
      }),
      [`${path}/results`]: { total: results.length, items: results },
    });
    renderAt(`/collections/${berlinId}`);
    await waitFor(() => expect(frameAddress().pathname).toBe(`${path}/preview`));
    expect(await screen.findByText('Showing first 20 of 25 documents')).toBeTruthy();
    expect(screen.queryByText(/not downloaded/)).toBeNull();
    await userEvent.click(screen.getByRole('button', { name: 'Render All' }));
    await waitFor(() => expect(frameAddress().searchParams.get('renderAll')).toBe('true'));
    expect(screen.getByText('Showing all 25 documents')).toBeTruthy();
  });
});

describe('the export sheet', () => {
  it('saves the server’s file for the format chosen, under the name it gives, and says so', async () => {
    const saved: { name: string; type: string }[] = [];
    URL.createObjectURL = vi.fn((file: Blob) => {
      saved.push({ name: '', type: file.type });
      return 'blob:export';
    });
    URL.revokeObjectURL = vi.fn();
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      saved[saved.length - 1]!.name = this.download;
    });
    const fetch = server({
      [path]: detail({ includeWordCloud: true }),
      [`${path}/excerpt-check`]: { summary: 'One quotation was not found in the document it cites.', hasFailures: true, verified: 0 },
      [`POST ${path}/export`]: () =>
        new Response('PK', {
          headers: {
            'content-type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'content-disposition': `attachment; filename="Caf_.docx"; filename*=UTF-8''Caf%C3%A9.docx`,
          },
        }),
    });
    renderAt(`/collections/${berlinId}`);
    const open = await screen.findByRole('button', { name: 'Export…' });
    await userEvent.click(open);
    const sheet = screen.getByRole('dialog', { name: 'Export collection' });
    expect(within(sheet).getByText('Exports the full text of each document, with your notes, footnotes, and a word-cloud overview.')).toBeTruthy();
    expect(within(sheet).getByText('An export from this server draws no word cloud: the app draws it with a renderer of its own.')).toBeTruthy();
    expect(within(sheet).getAllByRole('radio').map((radio) => radio.closest('label')?.textContent)).toEqual([
      'HTMLWeb page',
      'WordEditable .docx',
      'BibTeXReference manager',
      'RISZotero / EndNote',
      '.fruscollectionEditable copy for a colleague',
    ]);
    expect(within(sheet).queryByRole('switch', { name: 'Include my research notes' })).toBeNull();
    const check = await within(sheet).findByText('One quotation was not found in the document it cites.');
    expect(check.closest('p')?.className).toBe('excerpt-check warning');

    await userEvent.click(within(sheet).getByRole('radio', { name: /Word/ }));
    await userEvent.click(within(sheet).getByRole('button', { name: 'Export Word' }));
    await waitFor(() => expect(within(sheet).getByText('Export Complete: Café.docx')).toBeTruthy());
    const exported = fetch.mock.calls.find(([url, init]) => String(url).endsWith('/export') && init?.method === 'POST');
    expect(sent(exported?.[1]).body).toMatchObject({ format: 'docx' });
    expect(sent(exported?.[1]).token).toBe('t');
    expect(saved).toEqual([{ name: 'Café.docx', type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }]);

    await userEvent.click(within(sheet).getByRole('button', { name: 'Close' }));
    await waitFor(() => expect(document.activeElement).toBe(open));
    click.mockRestore();
  });

  it('writes the native file, with the reader’s notes only when they are included, and drops it for a smart collection', async () => {
    URL.createObjectURL = vi.fn(() => 'blob:export');
    URL.revokeObjectURL = vi.fn();
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
    const fetch = server({
      [path]: detail(),
      [`${path}/excerpt-check`]: { hasFailures: false, verified: 0 },
      [`POST ${path}/export`]: () =>
        new Response('{}', { headers: { 'content-type': 'application/json', 'content-disposition': 'attachment; filename="Berlin.fruscollection"' } }),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Export…' }));
    let sheet = screen.getByRole('dialog', { name: 'Export collection' });
    await userEvent.click(within(sheet).getByRole('radio', { name: /fruscollection/ }));
    const notes = within(sheet).getByRole('switch', { name: 'Include my research notes' }) as HTMLInputElement;
    expect(notes.checked).toBe(false);
    expect(within(sheet).getByText(/Shares an editable copy of this collection/).id).toBe(notes.getAttribute('aria-describedby'));
    await userEvent.click(within(sheet).getByRole('button', { name: 'Export .fruscollection' }));
    await waitFor(() => expect(within(sheet).getByText('Export Complete: Berlin.fruscollection')).toBeTruthy());
    await userEvent.click(notes);
    await userEvent.click(within(sheet).getByRole('button', { name: 'Export .fruscollection' }));
    await waitFor(() => expect(fetch.mock.calls.filter(([url]) => String(url).endsWith('/export'))).toHaveLength(2));
    const bodies = fetch.mock.calls.filter(([url]) => String(url).endsWith('/export')).map(([, init]) => sent(init).body);
    expect(bodies.map((body) => [(body as { format: string }).format, (body as { includeNotes?: boolean }).includeNotes])).toEqual([
      ['fruscollection', false],
      ['fruscollection', true],
    ]);
    cleanup();

    // A smart collection's grid has no native file, and its Export is offered with no entry, as its results are its documents.
    server({
      [path]: detail({ savedSearchId: 'S0000000-0000-4000-8000-000000000001', takesHandAddedEntries: false, entries: [] }),
      [`${path}/results`]: { total: 0, items: [] },
      [`${path}/excerpt-check`]: { hasFailures: false, verified: 0 },
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Export…' }));
    sheet = screen.getByRole('dialog', { name: 'Export collection' });
    expect(within(sheet).getAllByRole('radio')).toHaveLength(4);
    expect(within(sheet).queryByRole('radio', { name: /fruscollection/ })).toBeNull();
    expect(within(sheet).getByRole('button', { name: 'Export HTML' }).getAttribute('aria-disabled')).toBe('false');
    click.mockRestore();
  });

  it('says why the server refused an export, and offers none for a collection with nothing in it', async () => {
    server({
      [path]: detail(),
      [`${path}/excerpt-check`]: { hasFailures: false, verified: 0 },
      [`POST ${path}/export`]: new ProblemAnswer(409, 'EXPORT_NOT_RENDERED', 'The export could not be rendered.'),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Export…' }));
    const sheet = screen.getByRole('dialog', { name: 'Export collection' });
    await userEvent.click(within(sheet).getByRole('button', { name: 'Export HTML' }));
    expect((await within(sheet).findByRole('alert')).textContent).toBe('The export could not be rendered.');
    cleanup();

    server({ [path]: detail({ entries: [] }), [`${path}/excerpt-check`]: { hasFailures: false, verified: 0 } });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Export…' }));
    expect(within(screen.getByRole('dialog', { name: 'Export collection' })).getByRole('button', { name: 'Export HTML' }).getAttribute('aria-disabled')).toBe(
      'true',
    );
  });
});
