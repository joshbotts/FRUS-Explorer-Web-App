import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CitationBatch, CitationBatchRow, CitationFields, CitationLookupForm, CitationLookupMatch } from '../api/types';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { lookupState, resetLookupState, restoreLookupState, setText } from './lookupState';

const v06 = {
  volumeId: 'frus1961-63v06',
  filename: 'frus1961-63v06.xml',
  subseries: '1961-63',
  title: 'Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges',
  dateRange: { earliest: '1961-01-01', latest: '1963-12-31' },
  publicationDate: '1996',
  status: 'published' as const,
  editors: ['Charles S. Sampson'],
  sizeBytes: 1,
  tags: [],
};
const v05 = { ...v06, volumeId: 'frus1961-63v05', filename: 'frus1961-63v05.xml', title: 'Foreign Relations of the United States, 1961–1963, Volume V, Soviet Union' };

function match(overrides: Partial<CitationLookupMatch>): CitationLookupMatch {
  return {
    documentId: 'd1',
    volumeId: 'frus1961-63v06',
    rank: 1,
    matchStrategy: 'exactDocumentNumber',
    confidenceLabel: 'Exact match',
    correctionNote: null,
    requiresDownload: false,
    awaitingIndex: false,
    volumeManifestEntry: null,
    sharedPageTotal: null,
    volumeIsBestGuess: false,
    isBestGuess: false,
    bestGuessExplanation: null,
    sharedPageDocuments: null,
    ...overrides,
  };
}

const exact = match({});
const toDownload = match({ documentId: '', volumeId: 'frus1961-63v05', rank: 2, matchStrategy: 'manifestOnly', confidenceLabel: 'Volume identified — download to find the specific document', requiresDownload: true, volumeManifestEntry: v05 });
const guess = match({
  documentId: 'd2',
  rank: 3,
  matchStrategy: 'bestGuess',
  confidenceLabel: 'Best guess — this volume does not match the cited part 2',
  correctionNote: 'This result comes from a volume the citation does not name, so it may not be the document cited. Check the citation before relying on it.',
  isBestGuess: true,
  bestGuessExplanation: 'this volume does not match the cited part 2',
});

const empty: CitationFields = { subseries: '', volumeNumber: '', partNumber: '', documentNumber: '', pageNumber: '' };

/** The form fields a request posts. */
function sent(init?: RequestInit): URLSearchParams {
  return init?.body instanceof URLSearchParams ? init.body : new URLSearchParams();
}

/** A stand-in for the kit's form, enough for the screen: a citation of Volume VI's document 1, or nothing. */
function form(params: URLSearchParams): CitationLookupForm {
  const mode = (params.get('mode') ?? 'paste') as CitationLookupForm['mode'];
  const text = params.get('text') ?? '';
  const derived = mode === 'paste' && text.includes('vol. VI') ? { ...empty, subseries: '1961-63', volumeNumber: 'VI', documentNumber: text.includes('doc. 1') ? '1' : '' } : empty;
  const fields = { ...derived };
  for (const name of Object.keys(empty) as (keyof CitationFields)[]) {
    const given = params.get(name);
    if (given !== null) fields[name] = given;
  }
  const actionable = mode === 'batch' ? text.trim() !== '' : /^\d+$/.test(fields.documentNumber.trim()) || /^\d+$/.test(fields.pageNumber.trim()) || fields.volumeNumber.trim() !== '';
  return { mode, ...fields, actionable };
}

function row(overrides: Partial<CitationBatchRow>): CitationBatchRow {
  return { index: 1, marker: '1', text: 'FRUS, 1961–1963, vol. VI, doc. 1.', outcome: 'resolved', count: null, reason: null, triageOrder: 4, loneCandidateLabel: null, matches: [exact], ...overrides };
}

const batch: CitationBatch = {
  summary: '5 citations · 1 resolved · 2 ambiguous · 1 best guess · 1 unresolved',
  items: [
    row({}),
    row({ index: 2, marker: '2', text: 'FRUS, 1961–1963, vol. V, doc. 84.', outcome: 'ambiguous', count: 1, triageOrder: 3, loneCandidateLabel: toDownload.confidenceLabel, matches: [toDownload] }),
    row({ index: 3, marker: null, text: 'Ibid., doc. 2.', outcome: 'ambiguous', count: 2, triageOrder: 3, matches: [toDownload, exact] }),
    row({ index: 4, marker: '4', text: 'Memorandum, no citation.', outcome: 'missing', triageOrder: 1, matches: [] }),
    row({ index: 5, marker: '5', text: 'FRUS, 1961–1963, vol. VI, pt. 2, doc. 1.', outcome: 'bestGuess', triageOrder: 2, loneCandidateLabel: guess.confidenceLabel, matches: [guess] }),
  ],
};

function server(answers: Record<string, unknown> = {}) {
  return stubServer({
    '/readyz': ready,
    'POST /api/v1/citation-lookup/fields': (_url: URL, init?: RequestInit) => form(sent(init)),
    'POST /api/v1/citation-lookup': () => [exact, toDownload, guess],
    'POST /api/v1/citation-lookup/batch': () => batch,
    ...answers,
  });
}

/** The fields of each request posted to `path`, in order. */
function asked(fetch: ReturnType<typeof stubServer>, path: string): URLSearchParams[] {
  return fetch.mock.calls.filter(([input]) => new URL(input, 'http://localhost').pathname === path).map(([, init]) => sent(init));
}

const lookUp = () => screen.getByRole('button', { name: /Look Up|Looking up/ });
const field = (name: string) => screen.getByRole('textbox', { name });
const mode = (name: string) => screen.getByRole('radio', { name });

beforeEach(() => resetLookupState());
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('Citation Lookup', () => {
  it('opens from Search’s Find by Citation, with the app’s title, modes and Paste Citation’s fields', async () => {
    server({ '/api/v1/search': { total: 0, items: [] } });
    const user = userEvent.setup();
    const { router } = renderAt('/search');
    const find = await screen.findByRole('link', { name: 'Find by Citation' });
    expect(find.getAttribute('title')).toBe('Resolve a pasted or manually entered FRUS citation to a specific document');
    await user.click(find);
    expect(await screen.findByRole('heading', { level: 1, name: 'Citation Lookup' })).toBeTruthy();
    expect(router.state.location.pathname).toBe('/lookup');
    expect(document.title).toBe('Citation Lookup – FRUS Explorer Light');
    const modes = screen.getByRole('group', { name: 'Input mode' });
    expect(within(modes).getAllByRole('radio').map((radio) => radio.parentElement?.textContent)).toEqual(['Paste Citation', 'Structured Entry', 'Batch']);
    expect((mode('Paste Citation') as HTMLInputElement).checked).toBe(true);
    expect(field('Citation Text').getAttribute('placeholder')).toBe('Paste a FRUS citation…');
    const fields = screen.getByRole('group', { name: 'Parsed Fields' });
    expect(within(fields).getAllByRole('textbox').map((input) => input.closest('label')?.querySelector('span')?.textContent)).toEqual([
      'Subseries',
      'Volume',
      'Part',
      'Document no.',
      'Page',
    ]);
    expect(within(fields).getAllByRole('textbox').map((input) => input.getAttribute('placeholder'))).toEqual(['e.g. 1969-76', 'e.g. I or 1', 'e.g. 1 or I', 'e.g. 15', 'e.g. 47']);
    expect(fields.textContent).toContain('Provide at least a document number, page number, or volume to search.');
    expect(lookUp().getAttribute('title')).toBe('Resolve the citation to matching FRUS documents');
  });

  it('fills the Parsed Fields from each paste alone, keeps the reader’s edit until the next paste, and asks with the text and the edits', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await screen.findByRole('heading', { level: 1, name: 'Citation Lookup' });
    expect(lookUp().getAttribute('aria-disabled')).toBe('true');

    await user.click(field('Citation Text'));
    await user.paste('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect((field('Document no.') as HTMLInputElement).value).toBe('1'));
    expect((field('Subseries') as HTMLInputElement).value).toBe('1961-63');
    expect((field('Volume') as HTMLInputElement).value).toBe('VI');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));

    // The reader edits the number; the paste's other fields stay, and the request carries the edit alone.
    await user.clear(field('Document no.'));
    await user.type(field('Document no.'), '2');
    await user.click(lookUp());
    await screen.findByRole('heading', { level: 2, name: 'Results (3 found)' });
    const lookup = asked(fetch, '/api/v1/citation-lookup').at(-1);
    expect(lookup && Object.fromEntries(lookup)).toEqual({ mode: 'paste', text: 'FRUS, 1961–1963, vol. VI, doc. 1', documentNumber: '2' });

    // A new paste derives every field again, the edit gone with the old text.
    await user.clear(field('Citation Text'));
    await user.paste('FRUS, 1961–1963, vol. VI');
    await waitFor(() => expect((field('Document no.') as HTMLInputElement).value).toBe(''));
    expect(lookupState().edits).toEqual({});
    // Clearing the box clears them all.
    await user.clear(field('Citation Text'));
    await waitFor(() => expect((field('Volume') as HTMLInputElement).value).toBe(''));
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('true'));
  });

  it('shows each result as the app’s row: the kit’s label in its strategy’s colour and symbol, the document or the volume, the note, and what it offers', async () => {
    server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('textbox', { name: 'Citation Text' }));
    await user.paste('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.click(lookUp());

    const list = await screen.findByRole('list', { name: 'Results (3 found)' });
    const rows = within(list).getAllByRole('listitem');
    expect(rows.map((item) => item.querySelector('.confidence')?.textContent)).toEqual([exact.confidenceLabel, toDownload.confidenceLabel, guess.confidenceLabel]);
    expect(rows.map((item) => item.querySelector('.confidence')?.className)).toEqual(['confidence tone-green', 'confidence tone-secondary', 'confidence tone-orange']);
    expect(rows.map((item) => item.querySelector('svg')?.getAttribute('data-symbol'))).toEqual(['checkmark.seal.fill', 'doc.circle', 'lightbulb']);
    expect(rows.map((item) => within(item).getByRole('heading', { level: 3 }).textContent)).toEqual(['d1', v05.title, 'd2']);
    expect(rows.map((item) => item.querySelector('.meta')?.textContent)).toEqual(['frus1961-63v06', 'frus1961-63v05', 'frus1961-63v06']);
    const [documentRow, volumeRow, guessRow] = rows as [HTMLElement, HTMLElement, HTMLElement];
    expect(guessRow.querySelector('.match-note')?.textContent).toBe(guess.correctionNote);

    const view = within(documentRow).getByRole('link', { name: 'View Document, d1, frus1961-63v06' });
    expect(view.getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    expect(view.getAttribute('title')).toBe('Open this document');
    // A volume this server does not hold opens its page in Browse, where the app offers Download Volume.
    const volume = within(volumeRow).getByRole('link', { name: 'View Volume, frus1961-63v05' });
    expect(volume.getAttribute('href')).toBe('/browse/frus1961-63v05');
    expect(within(volumeRow).queryByRole('link', { name: /View Document/ })).toBeNull();
    expect(screen.getByRole('status').textContent).toBe('3 matches found');
  });

  it('says No Matches Found, and a Lookup Error with the server’s words', async () => {
    let answer: unknown = [];
    server({ 'POST /api/v1/citation-lookup': () => answer });
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('radio', { name: 'Structured Entry' }));
    await user.type(field('Volume'), 'VI');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.click(lookUp());
    expect(await screen.findByRole('heading', { level: 2, name: 'No Matches Found' })).toBeTruthy();
    expect(screen.getByText('No FRUS documents matched the provided citation. Check the subseries and volume, then try again.')).toBeTruthy();
    expect(screen.getByRole('status').textContent).toBe('No Matches Found');

    answer = new ProblemAnswer(503, 'INDEX_NOT_READY', 'A new index is being installed; ask again in a moment.');
    await user.click(lookUp());
    const alert = await screen.findByRole('alert');
    expect(within(alert).getByRole('heading', { level: 2 }).textContent).toBe('Lookup Error');
    expect(alert.textContent).toContain('A new index is being installed; ask again in a moment.');
  });

  it('runs Structured Entry’s five fields as typed, and Look Up waits until the kit says there is something to go on', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('radio', { name: 'Structured Entry' }));
    expect(screen.queryByRole('textbox', { name: 'Citation Text' })).toBeNull();
    await user.type(field('Document no.'), 'abc');
    await user.click(lookUp());
    await waitFor(() => expect(asked(fetch, '/api/v1/citation-lookup/fields').at(-1)?.get('documentNumber')).toBe('abc'));
    expect(asked(fetch, '/api/v1/citation-lookup')).toEqual([]);

    await user.type(field('Page'), '47');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.type(field('Subseries'), '1961-63{Enter}');
    await screen.findByRole('heading', { level: 2, name: 'Results (3 found)' });
    const lookup = asked(fetch, '/api/v1/citation-lookup').at(-1);
    expect(lookup && Object.fromEntries(lookup)).toEqual({
      mode: 'structured',
      subseries: '1961-63',
      volumeNumber: '',
      partNumber: '',
      documentNumber: 'abc',
      pageNumber: '47',
    });
  });

  it('keeps what the reader typed in Structured Entry on the way back to Paste Citation, and derives again once Batch has changed the text', async () => {
    server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('textbox', { name: 'Citation Text' }));
    await user.paste('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect((field('Document no.') as HTMLInputElement).value).toBe('1'));
    await user.click(mode('Structured Entry'));
    await user.type(field('Page'), '3');
    await user.click(mode('Paste Citation'));
    expect((field('Page') as HTMLInputElement).value).toBe('3');
    expect((field('Citation Text') as HTMLTextAreaElement).value).toBe('FRUS, 1961–1963, vol. VI, doc. 1');

    // Batch edits the same text, and shows no Parsed Fields.
    await user.click(mode('Batch'));
    expect(screen.queryByRole('group', { name: 'Parsed Fields' })).toBeNull();
    const block = field('Footnotes');
    expect((block as HTMLTextAreaElement).value).toBe('FRUS, 1961–1963, vol. VI, doc. 1');
    expect(screen.getByText(/Paste a chapter’s footnotes\./).id).toBe(block.getAttribute('aria-describedby'));
    await user.clear(block);
    await user.type(block, 'FRUS, 1961–1963, vol. VI');
    await user.click(mode('Paste Citation'));
    await waitFor(() => expect((field('Document no.') as HTMLInputElement).value).toBe(''));
    expect((field('Page') as HTMLInputElement).value).toBe('');
  });

  it('runs Return in the citation’s text, and begins a line with it in Batch’s footnotes', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('textbox', { name: 'Citation Text' }));
    await user.paste('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.keyboard('{Enter}');
    await screen.findByRole('heading', { level: 2, name: 'Results (3 found)' });
    expect((field('Citation Text') as HTMLTextAreaElement).value).toBe('FRUS, 1961–1963, vol. VI, doc. 1');

    await user.click(mode('Batch'));
    await user.click(field('Footnotes'));
    await user.keyboard('{End}{Enter}2. Ibid.');
    expect((field('Footnotes') as HTMLTextAreaElement).value).toBe('FRUS, 1961–1963, vol. VI, doc. 1\n2. Ibid.');
    expect(asked(fetch, '/api/v1/citation-lookup/batch')).toEqual([]);
  });

  it('triages a block in Batch: the kit’s summary, the rows worst first or as pasted, each in the app’s words, and a resolved row that opens its document', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('radio', { name: 'Batch' }));
    await user.click(field('Footnotes'));
    await user.paste('1. FRUS, 1961–1963, vol. VI, doc. 1.\n2. FRUS, 1961–1963, vol. V, doc. 84.');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.click(lookUp());

    const table = await screen.findByRole('list', { name: batch.summary });
    expect(asked(fetch, '/api/v1/citation-lookup/batch')[0]?.get('text')).toBe('1. FRUS, 1961–1963, vol. VI, doc. 1.\n2. FRUS, 1961–1963, vol. V, doc. 84.');
    const shown = () =>
      within(screen.getByRole('list', { name: batch.summary }))
        .getAllByRole('listitem')
        .map((item) => [item.querySelector('.batch-marker')?.textContent, item.querySelector('.batch-outcome')?.textContent]);
    // Needs work first, as the app opens the table: unresolved, best guesses, ambiguous, resolved.
    expect(shown()).toEqual([
      ['4', 'No match'],
      ['5', guess.confidenceLabel],
      ['2', toDownload.confidenceLabel],
      ['3', '2 possible documents'],
      ['1', 'Resolved — frus1961-63v06 d1'],
    ]);
    const toggle = screen.getByRole('button', { name: 'Needs work first' });
    expect(toggle.getAttribute('aria-pressed')).toBe('true');
    await user.click(toggle);
    expect(toggle.getAttribute('aria-pressed')).toBe('false');
    expect(shown().map(([marker]) => marker)).toEqual(['1', '2', '3', '4', '5']);
    expect([...table.querySelectorAll('.batch-outcome')].map((outcome) => outcome.className)).toEqual([
      'batch-outcome tone-green',
      'batch-outcome tone-orange',
      'batch-outcome tone-orange',
      'batch-outcome tone-secondary',
      'batch-outcome tone-orange',
    ]);
    // The rows whose one answer names a document open it; the others say what they found.
    expect(within(table).getByRole('link', { name: 'FRUS, 1961–1963, vol. VI, doc. 1.' }).getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    expect(within(table).queryByRole('link', { name: 'Memorandum, no citation.' })).toBeNull();
    expect(screen.getByRole('status').textContent).toBe(batch.summary);
  });

  it('says Nothing to Triage when the block holds no citation, and a failed row’s reason in red', async () => {
    let answer: CitationBatch = { summary: '0 citations · 0 resolved · 0 ambiguous · 0 best guesses · 0 unresolved', items: [] };
    server({ 'POST /api/v1/citation-lookup/batch': () => answer });
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('radio', { name: 'Batch' }));
    await user.type(field('Footnotes'), 'x');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.click(lookUp());
    expect(await screen.findByRole('heading', { level: 2, name: 'Nothing to Triage' })).toBeTruthy();
    expect(screen.getByText('No citations were found in that text.')).toBeTruthy();

    answer = { summary: '1 citation · 0 resolved · 0 ambiguous · 0 best guesses · 1 unresolved', items: [row({ outcome: 'failed', reason: 'The index could not be read.', triageOrder: 0, matches: [] })] };
    await user.type(field('Footnotes'), 'y');
    await user.click(lookUp());
    const failed = await screen.findByText('The index could not be read.');
    expect(failed.parentElement?.className).toBe('batch-outcome tone-red');
    expect(failed.parentElement?.querySelector('svg')?.getAttribute('data-symbol')).toBe('exclamationmark.triangle.fill');
  });

  it('keeps the form and its results through a visit to a document and back, and through a reload of the tab', async () => {
    const fetch = server({ '/api/v1/volumes/frus1961-63v06/documents/d1': new ProblemAnswer(404, 'DOCUMENT_NOT_FOUND', 'Not here.') });
    const user = userEvent.setup();
    const { router, unmount } = renderAt('/lookup');
    await user.click(await screen.findByRole('textbox', { name: 'Citation Text' }));
    await user.paste('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.click(lookUp());
    await user.click(await screen.findByRole('link', { name: 'View Document, d1, frus1961-63v06' }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/doc/frus1961-63v06/d1'));
    router.history.back();
    expect(await screen.findByRole('heading', { level: 2, name: 'Results (3 found)' })).toBeTruthy();
    expect((field('Citation Text') as HTMLTextAreaElement).value).toBe('FRUS, 1961–1963, vol. VI, doc. 1');
    expect(asked(fetch, '/api/v1/citation-lookup')).toHaveLength(1);

    // A new page in the same tab, as after a reload, starts with nothing and reads the form back
    // from the session.
    unmount();
    resetLookupState({ keepingSession: true });
    expect(lookupState().text).toBe('');
    restoreLookupState();
    expect(lookupState().text).toBe('FRUS, 1961–1963, vol. VI, doc. 1');
    renderAt('/lookup');
    expect(await screen.findByRole('heading', { level: 2, name: 'Results (3 found)' })).toBeTruthy();
    expect((field('Citation Text') as HTMLTextAreaElement).value).toBe('FRUS, 1961–1963, vol. VI, doc. 1');
  });

  it('empties the Parsed Fields at a new paste until the kit has read it, so a field typed meanwhile starts from nothing', async () => {
    let release: () => void = () => undefined;
    const held = new Promise<void>((resolve) => (release = resolve));
    server({
      'POST /api/v1/citation-lookup/fields': async (_url: URL, init?: RequestInit) => {
        const asked = sent(init);
        // The second citation's fields wait, as a slow answer would.
        if (asked.get('text')?.includes('vol. V,')) await held;
        return form(asked);
      },
    });
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('textbox', { name: 'Citation Text' }));
    await user.paste('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect((field('Document no.') as HTMLInputElement).value).toBe('1'));
    await user.clear(field('Citation Text'));
    await user.paste('FRUS, 1961–1963, vol. V, p. 47');
    expect((field('Document no.') as HTMLInputElement).value).toBe('');
    expect((field('Volume') as HTMLInputElement).value).toBe('');
    await user.type(field('Document no.'), '5');
    expect((field('Document no.') as HTMLInputElement).value).toBe('5');
    release();
    // What the reader typed stands over what the kit then reads.
    await waitFor(() => expect(lookupState().derivedFrom).toBe('FRUS, 1961–1963, vol. V, p. 47'));
    expect((field('Document no.') as HTMLInputElement).value).toBe('5');
  });

  it('keeps the fields of a text changed and changed back before it settled', async () => {
    server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('textbox', { name: 'Citation Text' }));
    await user.paste('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect((field('Document no.') as HTMLInputElement).value).toBe('1'));
    // A character typed and taken back at once, quicker than the form waits to ask.
    setText('FRUS, 1961–1963, vol. VI, doc. 12');
    setText('FRUS, 1961–1963, vol. VI, doc. 1');
    await waitFor(() => expect((field('Document no.') as HTMLInputElement).value).toBe('1'));
    expect((field('Volume') as HTMLInputElement).value).toBe('VI');
  });

  it('asks the server again at every Look Up, an earlier citation’s too, as the app asks its matcher', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('textbox', { name: 'Citation Text' }));
    for (const text of ['FRUS, 1961–1963, vol. VI, doc. 1', 'FRUS, 1961–1963, vol. VI', 'FRUS, 1961–1963, vol. VI, doc. 1']) {
      await user.clear(field('Citation Text'));
      await user.paste(text);
      await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
      await user.click(lookUp());
      await screen.findByRole('heading', { level: 2, name: 'Results (3 found)' });
    }
    await waitFor(() => expect(asked(fetch, '/api/v1/citation-lookup').map((fields) => fields.get('text'))).toEqual([
      'FRUS, 1961–1963, vol. VI, doc. 1',
      'FRUS, 1961–1963, vol. VI',
      'FRUS, 1961–1963, vol. VI, doc. 1',
    ]));
  });

  it('says an error once, in its alert, and nothing in the status line', async () => {
    server({ 'POST /api/v1/citation-lookup': new ProblemAnswer(503, 'INDEX_NOT_READY', 'A new index is being installed; ask again in a moment.') });
    const user = userEvent.setup();
    renderAt('/lookup');
    await user.click(await screen.findByRole('radio', { name: 'Structured Entry' }));
    await user.type(field('Page'), '1');
    await waitFor(() => expect(lookUp().getAttribute('aria-disabled')).toBe('false'));
    await user.click(lookUp());
    expect((await screen.findByRole('alert')).textContent).toContain('A new index is being installed');
    expect(screen.getByRole('status').textContent).toBe('');
  });

  it('asks the gate again for what the form holds when Look Up comes before the last answer', async () => {
    const fetch = server();
    renderAt('/lookup');
    await screen.findByRole('heading', { level: 1, name: 'Citation Lookup' });
    fireEvent.click(mode('Structured Entry'));
    fireEvent.change(field('Page'), { target: { value: '12' } });
    // At once, before the form's own question has gone.
    fireEvent.click(lookUp());
    await screen.findByRole('heading', { level: 2, name: 'Results (3 found)' });
    expect(asked(fetch, '/api/v1/citation-lookup').at(-1)?.get('pageNumber')).toBe('12');
  });
});
