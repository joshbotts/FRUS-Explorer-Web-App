// Related Documents (PLAN's S23d), as the app's list shows it, over a stubbed server: the scope, the
// weights kept for the next list, the rows with their chips, the lines under them, and the list's states.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { RelatedDocuments } from '../api/related';
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
  { id: 'sharedSubjects', name: 'Shared topics', weight: 0.5, defaultWeight: 0.5, available: true },
  { id: 'semanticSimilarity', name: 'Semantically similar (experimental)', weight: 0.5, defaultWeight: 0.5, available: false },
  { id: 'lexicalSimilarity', name: 'Similar wording (experimental)', weight: 0, defaultWeight: 0, available: false },
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
    ...fields,
  };
}

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
    // A row with no head is titled by its id.
    expect(screen.getByRole('link', { name: 'd9' })).toBeTruthy();
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
    // The axes this server does not rank by are set aside, and say so; the cross-references it ranks by
    // since S23c's pin move are not.
    const meaning = screen.getByRole('slider', { name: 'Semantically similar (experimental)' }) as HTMLInputElement;
    expect(meaning.disabled).toBe(true);
    expect(meaning.getAttribute('aria-describedby')).toBeTruthy();
    expect(screen.getByText('This server does not rank by meaning yet.')).toBeTruthy();
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
});
