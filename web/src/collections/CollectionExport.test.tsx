// A collection's live preview and its export sheet (S18e), against a stubbed server: the frame sent to
// the server's page, the first 20 documents until Render All, again a second after a change, the bars
// for the cap and the volumes the server lacks, and a smart collection's sentence; the sheet's sentence,
// grid and quotation check, Export {Format} saving the server's file under its name, a refusal in the
// app's words, and focus back on Export… when it closes.
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

/** The preview frame's address, read as the server reads it. */
function frameAddress(): URL {
  const frame = screen.getByTitle('Preview of the collection’s HTML export') as HTMLIFrameElement;
  return new URL(frame.getAttribute('src') ?? '', 'http://localhost');
}

beforeEach(() => {
  vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }));
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
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

    // Render All, at once, for as long as the editor is open.
    await userEvent.click(screen.getByRole('button', { name: 'Render All' }));
    await waitFor(() => expect(frameAddress().searchParams.get('renderAll')).toBe('true'));
    expect(screen.queryByText('Showing first 20 of 22 documents')).toBeNull();
  });

  it('builds the page again a second after the collection changes, once its changes are answered', async () => {
    const fetch = server({
      [path]: detail(),
      [`PATCH ${path}`]: detail({ includeColophon: true }),
    });
    renderAt(`/collections/${berlinId}`);
    await waitFor(() => expect(frameAddress().pathname).toBe(`${path}/preview`));
    const sets: string[] = [];
    const set = vi.spyOn(HTMLIFrameElement.prototype, 'src', 'set').mockImplementation((value: string) => {
      sets.push(value);
    });
    await userEvent.click(screen.getByRole('button', { name: 'Collection settings' }));
    await userEvent.click(within(screen.getByRole('dialog', { name: 'Collection settings' })).getByRole('switch', { name: 'Include colophon' }));
    await waitFor(() => expect(fetch.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(true));
    expect(sets).toEqual([]);
    await waitFor(() => expect(sets).toHaveLength(1), { timeout: 2500 });
    expect(new URL(sets[0]!, 'http://localhost').pathname).toBe(`${path}/preview`);
    set.mockRestore();
  });

  it('says a smart collection has no preview here, and loads none', async () => {
    server({ [path]: detail({ savedSearchId: 'S0000000-0000-4000-8000-000000000001', takesHandAddedEntries: false }) });
    renderAt(`/collections/${berlinId}`);
    expect(
      await screen.findByText(
        'A smart collection’s documents come from its saved search, which this server does not resolve yet, so it has no preview here.',
      ),
    ).toBeTruthy();
    expect(screen.queryByTitle('Preview of the collection’s HTML export')).toBeNull();
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
    ]);
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
