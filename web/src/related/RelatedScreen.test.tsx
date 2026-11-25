// Related Documents (PLAN's S23d), as the app's list shows it, over a stubbed server: the scope, the
// weights kept for the next list, the rows with their chips, the lines under them, and the list's states; since
// S26d the experimental axes' captions, a semantic row's verdicts, Beyond your library and the missing vectors' line.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { RelatedDocuments, SemanticVerdict } from '../api/related';
import { me, sent } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

beforeEach(() => localStorage.clear());

const path = '/api/v1/volumes/frus1961-63v06/documents/d1/related';
const anchor = '/api/v1/volumes/frus1961-63v06/documents/d1';

const axes: RelatedDocuments['axes'] = [
  { id: 'archivalProvenance', name: 'Archival provenance', weight: 1, defaultWeight: 1, available: true },
  { id: 'crossReference', name: 'Cross-references', weight: 1, defaultWeight: 1, available: true },
  { id: 'dateProximity', name: 'Close in date', weight: 0.5, defaultWeight: 0.5, available: true },
  { id: 'subseries', name: 'Corpus proximity', weight: 0.3, defaultWeight: 0.3, available: true },
  { id: 'sharedPersons', name: 'Shared people', weight: 0.7, defaultWeight: 0.7, available: true },
  { id: 'sharedSubjects', name: 'Shared subjects', weight: 0.5, defaultWeight: 0.5, available: true },
  { id: 'semanticSimilarity', name: 'Semantically similar (experimental)', weight: 0.5, defaultWeight: 0.5, available: true },
  { id: 'lexicalSimilarity', name: 'Similar wording (experimental)', weight: 0, defaultWeight: 0, available: true },
];

function answer(fields: Partial<RelatedDocuments> = {}): RelatedDocuments {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    scope: 'all',
    scopes: ['volume', 'subseries', 'all'],
    weights: '',
    axes,
    rows: [
      {
        volumeId: 'frus1961-63v06',
        documentId: 'd2',
        header: 'Memorandum From the President',
        dateline: 'Washington, January 2, 1961',
        isEditorialNote: false,
        score: 1.8,
        snippet: 'The President met the Secretary.',
        chips: [
          { axis: 'subseries', name: 'Corpus proximity', text: '100%' },
          { axis: 'dateProximity', name: 'Close in date', text: '100%' },
        ],
      },
      { volumeId: 'frus1961-63v06', documentId: 'd9', header: '', isEditorialNote: false, score: 0.4, chips: [] },
    ],
    totalBeforeLimit: 5,
    poolCut: 'Ranked from the first 120 of 1,063 documents that share this anchor’s archival container. The rest were not scored. Narrow the scope to reach them.',
    missingShards: [],
    ...fields,
  };
}

/** A row the semantic axis scored, with the kit's chip. */
const semanticRow: RelatedDocuments['rows'][number] = {
  volumeId: 'frus1961-63v06',
  documentId: 'd4',
  header: 'Letter From Chairman Khrushchev',
  isEditorialNote: false,
  score: 0.9,
  chips: [{ axis: 'semanticSimilarity', name: 'Semantically similar (experimental)', text: 'shares: Semantic match · 71%' }],
  semanticScore: 0.71,
};

const beyond: NonNullable<RelatedDocuments['beyondLibrary']> = {
  caption: '94 documents in 19 volumes you have not downloaded read as close to this one as the matches ranked above.',
  documentCount: 94,
  volumeCount: 19,
  isCapped: false,
  documents: [
    { volumeId: 'frus1961-63v05', documentId: 'd12', volumeTitle: 'Foreign Relations,\n   1961–1963, Volume V', score: 0.66, chip: 'Semantic match · 66%', served: false },
  ],
  volumes: [{ volumeId: 'frus1961-63v15', title: 'Berlin Crisis, 1962–1963', count: 14, countText: '14 matching documents' }],
  moreVolumes: 'and 18 more volumes',
};

const document = {
  document: { volumeId: 'frus1961-63v06', documentId: 'd1', displayTitle: 'Telegram to Moscow', inIndex: true },
  canonicalURL: 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1',
  teiAvailable: true,
};

describe('Related Documents', () => {
  it('shows each row with its place, its opening text and its chips, and the lines for more and for a cut pool', async () => {
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer() });
    renderAt('/related/frus1961-63v06/d1');
    expect(await screen.findByRole('heading', { level: 1, name: 'Related Documents' })).toBeTruthy();
    expect(await screen.findByRole('link', { name: 'Back to Telegram to Moscow' })).toBeTruthy();
    const first = await screen.findByRole('link', { name: 'Memorandum From the President' });
    const row = first.closest('li')!;
    expect(within(row).getByText('The President met the Secretary.')).toBeTruthy();
    expect(row.textContent).toContain('Washington, January 2, 1961');
    // Each chip says its axis to a screen reader, then its words.
    const chips = within(row).getByRole('list', { name: 'Why related' });
    expect(within(chips).getAllByRole('listitem').map((chip) => chip.textContent)).toEqual(['Corpus proximity 100%', 'Close in date 100%']);
    // The row's link is described by its chips, strongest first, so that the keyboard reaching it reads why (S29g).
    const described = first.getAttribute('aria-describedby')!.split(' ').map((id) => globalThis.document.getElementById(id)?.textContent);
    expect(described).toEqual(['Corpus proximity 100%', 'Close in date 100%']);
    // A row with no head is titled by its id, and one with no chip has no description.
    expect(screen.getByRole('link', { name: 'd9' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'd9' }).getAttribute('aria-describedby')).toBeNull();
    expect(screen.getByText('3 more related — raise a weight or narrow the scope to refine.')).toBeTruthy();
    expect(screen.getByText(/^Ranked from the first 120 of 1,063/)).toBeTruthy();
  });

  it('ranks the scope chosen, with the scopes the server offers', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      [anchor]: document,
      [path]: (url: URL) => answer({ scope: (url.searchParams.get('scope') ?? 'all') as RelatedDocuments['scope'], scopes: ['volume', 'all'] }),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Memorandum From the President' });
    expect(screen.queryByRole('radio', { name: 'This subseries' })).toBeNull();
    await user.click(screen.getByRole('radio', { name: 'This volume' }));
    await waitFor(() => expect(router.state.location.search).toEqual({ scope: 'volume' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes('scope=volume'))).toBe(true));
    expect((screen.getByRole('radio', { name: 'This volume' }) as HTMLInputElement).checked).toBe(true);
  });

  it('re-ranks once a slider settles, keeps the tuning for the next list, and Reset forgets it', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      [anchor]: document,
      [path]: (url: URL) => {
        const weights = url.searchParams.get('weights') ?? '';
        return answer({ weights, axes: axes.map((axis) => (axis.id === 'subseries' && weights ? { ...axis, weight: 0.8 } : axis)) });
      },
    });
    renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Memorandum From the President' });
    expect((screen.getByRole('button', { name: 'Reset to app defaults' }) as HTMLButtonElement).disabled).toBe(true);
    // Every axis ranks since S26d; the two experimental ones say what they are, as their weights stand.
    const meaning = screen.getByRole('slider', { name: 'Semantically similar (experimental)' }) as HTMLInputElement;
    expect(meaning.disabled).toBe(false);
    expect(globalThis.document.getElementById(meaning.getAttribute('aria-describedby')!)?.textContent).toMatch(/^Matches carry a “Semantic match” score/);
    const wording = screen.getByRole('slider', { name: 'Similar wording (experimental)' }) as HTMLInputElement;
    expect(wording.disabled).toBe(false);
    expect(globalThis.document.getElementById(wording.getAttribute('aria-describedby')!)?.textContent).toMatch(/^Off\. Raise it to also match documents that reuse/);
    const crossReferences = screen.getByRole('slider', { name: 'Cross-references' }) as HTMLInputElement;
    expect(crossReferences.disabled).toBe(false);
    expect(crossReferences.getAttribute('aria-describedby')).toBeNull();

    const slider = screen.getByRole('slider', { name: 'Corpus proximity' });
    fireEvent.change(slider, { target: { value: '0.8' } });
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes('weights=subseries%3A0.8'))).toBe(true));
    expect(localStorage.getItem('frus.related.weights')).toBe('subseries:0.8');
    // The slider kept its place, and its value, through the new ranking.
    await waitFor(() => expect((screen.getByRole('slider', { name: 'Corpus proximity' }) as HTMLInputElement).value).toBe('0.8'));

    fireEvent.click(screen.getByRole('button', { name: 'Reset to app defaults' }));
    await waitFor(() => expect(localStorage.getItem('frus.related.weights')).toBeNull());
    await waitFor(() => expect((screen.getByRole('slider', { name: 'Corpus proximity' }) as HTMLInputElement).value).toBe('0.3'));
  });

  it('shows the scope and the weight asked for at once, while the server ranks, and Reset cancels a slider moved before it', async () => {
    // The answers to anything but the opening list never come.
    stubServer({
      '/readyz': ready,
      [anchor]: document,
      [path]: (url: URL) => (url.search === '?scope=all' ? answer() : new Promise(() => {})),
    });
    const user = userEvent.setup();
    renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Memorandum From the President' });
    await user.click(screen.getByRole('radio', { name: 'This volume' }));
    await waitFor(() => expect((screen.getByRole('radio', { name: 'This volume' }) as HTMLInputElement).checked).toBe(true));
    expect(screen.getByRole('status').textContent).toBe('Ranking the related documents…');
    // The list on show stays, busy, with its rows.
    expect(screen.getByRole('link', { name: 'Memorandum From the President' })).toBeTruthy();

    const slider = screen.getByRole('slider', { name: 'Shared people' });
    fireEvent.change(slider, { target: { value: '0.2' } });
    await waitFor(() => expect(localStorage.getItem('frus.related.weights')).toBe('sharedPersons:0.2'));
    // Shown as asked for, not as the list on show was ranked.
    expect((screen.getByRole('slider', { name: 'Shared people' }) as HTMLInputElement).value).toBe('0.2');
    fireEvent.change(screen.getByRole('slider', { name: 'Close in date' }), { target: { value: '0.9' } });
    const reset = screen.getByRole('button', { name: 'Reset to app defaults' });
    reset.focus();
    await user.click(reset);
    // Reset cancels the slider moved before it, and hands the focus to the weights' heading.
    await new Promise((settled) => setTimeout(settled, 700));
    expect(localStorage.getItem('frus.related.weights')).toBeNull();
    expect((screen.getByRole('slider', { name: 'Close in date' }) as HTMLInputElement).value).toBe('0.5');
    // Where the focus goes after Reset, a <summary>, which jsdom does not focus, the browser suite holds.
  });

  it('ranks a step once it settles, though a list asked for before it comes while it rests', async () => {
    // This volume's list is held until a slider has stepped, as a list ranked for a scope chosen just before may
    // come under load. It comes with axes of its own, and the step still settles into the address (S23d's
    // second follow-up: a list that came while a step rested cancelled the step's ranking).
    let deliver = () => {};
    const held = new Promise<void>((resolve) => {
      deliver = resolve;
    });
    const fetch = stubServer({
      '/readyz': ready,
      [anchor]: document,
      [path]: (url: URL) => {
        const scope = (url.searchParams.get('scope') ?? 'all') as RelatedDocuments['scope'];
        const weights = url.searchParams.get('weights') ?? '';
        const list = answer({ scope, weights });
        return scope === 'volume' && weights === '' ? held.then(() => list) : list;
      },
    });
    const user = userEvent.setup();
    const { router } = renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Memorandum From the President' });
    await user.click(screen.getByRole('radio', { name: 'This volume' }));
    await waitFor(() => expect(router.state.location.search).toEqual({ scope: 'volume' }));
    // A step by the keyboard, which rests before the list is ranked with it; then This volume's list comes.
    fireEvent.change(screen.getByRole('slider', { name: 'Shared people' }), { target: { value: '0.2' } });
    deliver();
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe(''));
    expect(router.state.location.search).toEqual({ scope: 'volume' });
    // The step settles, and the list is ranked with it.
    await waitFor(() => expect(router.state.location.search).toEqual({ scope: 'volume', weights: 'sharedPersons:0.2' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes('scope=volume&weights=sharedPersons%3A0.2'))).toBe(true));
    expect(localStorage.getItem('frus.related.weights')).toBe('sharedPersons:0.2');
    expect((screen.getByRole('slider', { name: 'Shared people' }) as HTMLInputElement).value).toBe('0.2');
  });

  it('keeps a step not yet ranked for the next list when the page goes', async () => {
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer() });
    const { unmount } = renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Memorandum From the President' });
    fireEvent.change(screen.getByRole('slider', { name: 'Shared people' }), { target: { value: '0.2' } });
    unmount();
    expect(localStorage.getItem('frus.related.weights')).toBe('sharedPersons:0.2');
  });

  it('opens with the tuning this browser keeps', async () => {
    localStorage.setItem('frus.related.weights', 'sharedPersons:0.2');
    const fetch = stubServer({ '/readyz': ready, [anchor]: document, [path]: answer({ weights: 'sharedPersons:0.2' }) });
    renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Memorandum From the President' });
    expect(fetch.mock.calls.some(([url]) => String(url).includes('weights=sharedPersons%3A0.2'))).toBe(true);
    expect((screen.getByRole('button', { name: 'Reset to app defaults' }) as HTMLButtonElement).disabled).toBe(false);
  });

  it('says what an empty list means for its scope, and that the index is being prepared', async () => {
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer({ rows: [], totalBeforeLimit: 0, poolCut: undefined, scope: 'volume' }) });
    renderAt('/related/frus1961-63v06/d1?scope=volume');
    expect(await screen.findByRole('heading', { level: 2, name: 'No Related Documents' })).toBeTruthy();
    expect(screen.getByText(/switch to All volumes to search the whole index/)).toBeTruthy();
    cleanup();

    stubServer({ '/readyz': ready, [anchor]: document, [path]: new ProblemAnswer(503, 'INDEX_NOT_READY', 'Waiting for an export.') });
    renderAt('/related/frus1961-63v06/d1');
    expect(await screen.findByText('Preparing your index…')).toBeTruthy();
  });
  it('sets the semantic axis aside, saying why, on a server whose vectors are refused', async () => {
    const refused = axes.map((axis) => (axis.id === 'semanticSimilarity' ? { ...axis, available: false } : axis));
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer({ axes: refused }) });
    renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Memorandum From the President' });
    expect((screen.getByRole('slider', { name: 'Semantically similar (experimental)' }) as HTMLInputElement).disabled).toBe(true);
    expect(screen.getByText('This server’s semantic vectors are unavailable, so it does not rank by meaning.')).toBeTruthy();
  });

  it('gives a row the semantic axis scored the app’s two verdicts, which it then says, and no other row', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      [anchor]: document,
      [path]: answer({ rows: [semanticRow, ...answer().rows] }),
      'POST /api/v1/me/semantic-feedback': (_url: URL, init?: RequestInit) => ({ ...JSON.parse(String(init?.body)), recordedAt: '2026-11-24T00:00:00.000Z' }),
    });
    const user = userEvent.setup();
    renderAt('/related/frus1961-63v06/d1');
    const row = (await screen.findByRole('link', { name: 'Letter From Chairman Khrushchev' })).closest('li')!;
    expect(within(row).getByRole('list', { name: 'Why related' }).textContent).toContain('shares: Semantic match · 71%');
    const menu = within(row).getByRole('button', { name: 'Semantic match feedback: Letter From Chairman Khrushchev' });
    expect(menu.textContent).toBe('Feedback');
    // Only a row the semantic axis scored carries the menu.
    const other = screen.getByRole('link', { name: 'Memorandum From the President' }).closest('li')!;
    expect(within(other).queryByRole('button', { name: /Semantic match feedback/ })).toBeNull();

    menu.focus();
    await user.keyboard('{ArrowDown}');
    const helpful = screen.getByRole('menuitem', { name: 'Semantic match: helpful' });
    expect(globalThis.document.activeElement).toBe(helpful);
    expect(screen.getByRole('menuitem', { name: 'Semantic match: not useful' })).toBeTruthy();
    await user.keyboard('{Enter}');
    await waitFor(() => expect(within(row).getByText('Marked helpful')).toBeTruthy());
    expect(globalThis.document.activeElement).toBe(menu);
    const posted = fetch.mock.calls.filter(([url, init]) => String(url).endsWith('/api/v1/me/semantic-feedback') && init?.method === 'POST');
    expect(posted).toHaveLength(1);
    expect(sent(posted[0]![1])).toEqual({
      body: { anchor: 'frus1961-63v06/d1', neighbour: 'frus1961-63v06/d4', verdict: 'helpful' },
      token: 'token-1',
    });
    // The verdict describes the menu's button; it is said politely, outside the list, which is busy while it is ranked.
    expect(globalThis.document.getElementById(menu.getAttribute('aria-describedby')!)?.textContent).toBe('Marked helpful');
    const spoken = screen.getByText('Marked helpful: Letter From Chairman Khrushchev');
    const region = spoken.closest('[aria-live]')!;
    expect(region.getAttribute('aria-live')).toBe('polite');
    expect(region.closest('[aria-busy]')).toBeNull();
    // The same verdict given again is said again: its words are a new node of the region.
    await user.click(menu);
    await user.click(screen.getByRole('menuitem', { name: 'Semantic match: helpful' }));
    await waitFor(() => expect(region.firstElementChild).not.toBe(spoken));
    expect(region.textContent).toBe('Marked helpful: Letter From Chairman Khrushchev');
  });

  it('offers no verdict on a server that keeps no user data', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false }, [anchor]: document, [path]: answer({ rows: [semanticRow] }) });
    renderAt('/related/frus1961-63v06/d1');
    const row = (await screen.findByRole('link', { name: 'Letter From Chairman Khrushchev' })).closest('li')!;
    expect(within(row).getByRole('list', { name: 'Why related' }).textContent).toContain('Semantic match · 71%');
    expect(within(row).queryByRole('button', { name: /Semantic match feedback/ })).toBeNull();
  });

  it('asks again for a list that was coming when a verdict was kept, which was ranked without it', async () => {
    let kept: SemanticVerdict | undefined;
    let release = () => {};
    const held = new Promise<void>((resolve) => {
      release = resolve;
    });
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      [anchor]: document,
      [path]: async (url: URL) => {
        const scope = (url.searchParams.get('scope') ?? 'all') as RelatedDocuments['scope'];
        // Ranked as the request came: before the verdict was kept, without it.
        const list = answer({ scope, rows: [kept ? { ...semanticRow, verdict: kept } : semanticRow] });
        if (scope === 'volume' && !kept) await held;
        return list;
      },
      'POST /api/v1/me/semantic-feedback': (_url: URL, init?: RequestInit) => {
        kept = JSON.parse(String(init?.body)).verdict;
        return { ...JSON.parse(String(init?.body)), recordedAt: '2026-11-24T00:00:00.000Z' };
      },
    });
    const user = userEvent.setup();
    renderAt('/related/frus1961-63v06/d1');
    await screen.findByRole('link', { name: 'Letter From Chairman Khrushchev' });
    // This volume's list is asked for, and held; the list on show stays, busy, and its row is marked meanwhile.
    await user.click(screen.getByRole('radio', { name: 'This volume' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes('scope=volume'))).toBe(true));
    const row = () => screen.getByRole('link', { name: 'Letter From Chairman Khrushchev' }).closest('li')!;
    await user.click(within(row()).getByRole('button', { name: /Semantic match feedback/ }));
    await user.click(screen.getByRole('menuitem', { name: 'Semantic match: helpful' }));
    // This volume's list is asked for again, after the verdict, and comes with it.
    await waitFor(() => expect(fetch.mock.calls.filter(([url]) => String(url).includes('scope=volume'))).toHaveLength(2));
    await waitFor(() => expect(globalThis.document.querySelector('[aria-busy="true"]')).toBeNull());
    await waitFor(() => expect(within(row()).getByText('Marked helpful')).toBeTruthy());
    // The list ranked before the verdict comes at last, and changes nothing.
    release();
    await new Promise((settled) => setTimeout(settled, 50));
    expect(within(row()).getByText('Marked helpful')).toBeTruthy();
  });

  it('says a verdict the server gave a row, and why one was not recorded', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      [anchor]: document,
      [path]: answer({ rows: [{ ...semanticRow, verdict: 'notHelpful' }] }),
      'POST /api/v1/me/semantic-feedback': new ProblemAnswer(422, 'NOT_A_SEMANTIC_MATCH', 'The semantic axis gives frus1961-63v06/d4 no score.'),
    });
    const user = userEvent.setup();
    renderAt('/related/frus1961-63v06/d1');
    const row = (await screen.findByRole('link', { name: 'Letter From Chairman Khrushchev' })).closest('li')!;
    expect(within(row).getByText('Marked not useful')).toBeTruthy();
    const menu = within(row).getByRole('button', { name: /Semantic match feedback/ });
    expect(globalThis.document.getElementById(menu.getAttribute('aria-describedby')!)?.textContent).toBe('Marked not useful');
    await user.click(menu);
    await user.click(screen.getByRole('menuitem', { name: 'Semantic match: helpful' }));
    expect((await screen.findByRole('alert')).textContent).toBe('The verdict was not recorded: The semantic axis gives frus1961-63v06/d4 no score.');
    expect(within(row).getByText('Marked not useful')).toBeTruthy();
  });

  it('shows Beyond your library after the rows, each volume opening its page in Browse, and the missing vectors’ line', async () => {
    const served = { volumeId: 'frus1894Nicaragua', documentId: 'd3', volumeTitle: 'Nicaragua', score: 0.61, chip: 'Semantic match · 61%', served: true };
    stubServer({
      '/readyz': ready,
      [anchor]: document,
      [path]: answer({ beyondLibrary: { ...beyond, documents: [...beyond.documents, served] }, missingShards: ['frus1894Nicaragua'] }),
    });
    renderAt('/related/frus1961-63v06/d1');
    const section = (await screen.findByRole('heading', { level: 2, name: 'Beyond your library' })).closest('section')!;
    expect(within(section).getByText(beyond.caption)).toBeTruthy();
    const named = within(section).getByRole('link', { name: 'Document d12 in Foreign Relations, 1961–1963, Volume V' });
    expect(named.getAttribute('href')).toBe('/browse/frus1961-63v05');
    const document12 = named.closest('li')!;
    expect(document12.textContent).toContain('Volume not on this server — its documents are shown without titles.');
    expect(document12.textContent).toContain('Semantic match · 66%');
    // A document of a volume this server serves, as a scoped list's leads may name, opens itself.
    const readable = within(section).getByRole('link', { name: 'Document d3 in Nicaragua' });
    expect(readable.getAttribute('href')).toBe('/doc/frus1894Nicaragua/d3');
    expect(readable.closest('li')!.textContent).not.toContain('not on this server');
    expect(readable.closest('li')!.textContent).toContain('Semantic match · 61%');
    const volume = within(section).getByRole('link', { name: 'Berlin Crisis, 1962–1963' });
    expect(volume.getAttribute('href')).toBe('/browse/frus1961-63v15');
    expect(volume.closest('li')!.textContent).toContain('14 matching documents');
    expect(within(section).getByText('and 18 more volumes')).toBeTruthy();
    expect(
      screen.getByText('One volume this server serves is missing its semantic vectors, so its documents were not matched by meaning.'),
    ).toBeTruthy();
  });

  it('says the empty list’s sentence above Beyond your library, where no document of this library is related', async () => {
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer({ rows: [], totalBeforeLimit: 0, poolCut: undefined, beyondLibrary: beyond }) });
    renderAt('/related/frus1961-63v06/d1');
    expect(await screen.findByRole('heading', { level: 2, name: 'Beyond your library' })).toBeTruthy();
    expect(screen.queryByRole('heading', { name: 'No Related Documents' })).toBeNull();
    expect(screen.getByText(/^No indexed documents share this document’s archival provenance/)).toBeTruthy();
  });
});
