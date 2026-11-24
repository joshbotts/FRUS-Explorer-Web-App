import { act, cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { CloudAnswer, CloudContext } from '../api/cloud';
import type { Preferences } from '../api/research';
import type { Me } from '../api/types';
import { me } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';
import { preferences } from '../test/research';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  window.localStorage.clear();
});

const lenses = [
  { id: 'topics', label: 'Topics (nouns)', shortLabel: 'Topics', colorsBySentiment: false },
  { id: 'actions', label: 'Actions (verbs)', shortLabel: 'Actions', colorsBySentiment: false },
  { id: 'concepts', label: 'Concepts', shortLabel: 'Concepts', colorsBySentiment: false },
  { id: 'sentiment', label: 'Sentiment', shortLabel: 'Sentiment', colorsBySentiment: true },
];

const context: CloudContext = {
  lenses,
  measures: [
    { id: 'frequency', label: 'Frequency' },
    { id: 'keyness', label: 'Distinctive' },
  ],
  corpus: 'Entire Corpus',
  subseries: [
    { id: '1961-63', volumes: [{ id: 'frus1961-63v06', title: 'Foreign Relations, 1961–1963,\n      Volume VI' }] },
    { id: '1969-76', volumes: [{ id: 'frus1969-76ve09p1', title: 'Documents on North Africa' }] },
  ],
  made: {
    generated: '2026-11-24',
    volumeCount: 553,
    documentCount: 314616,
    topTermsPerList: 50,
    family: 'FRUSLanguage 1+fa42bd87.56708897',
    line: 'These clouds were counted by this server’s own tagger.',
  },
};

/** A cloud of the scope and lens the request names, its words those of the lens. */
function cloud(url: URL): CloudAnswer {
  const scope = url.searchParams.get('scope') ?? 'corpus';
  const lens = lenses.find((each) => each.id === url.searchParams.get('lens')) ?? lenses[0]!;
  const terms = ['government', 'meeting', 'question', 'policy', 'agreement'].map((term, index) => ({
    term: `${term}-${lens.id}`,
    count: 900 - index * 100,
    polarity: lens.colorsBySentiment ? (index % 2 === 0 ? 1 : -1) : undefined,
  }));
  return {
    scope: { signature: scope, title: scope === 'corpus' ? 'Entire Corpus' : scope === 'vol:frus1961-63v06' ? 'Foreign Relations, 1961–1963, Volume VI' : scope.slice(4) },
    lens,
    chip: lens.shortLabel,
    state: 'terms',
    countLine: '5 terms',
    terms,
    listed: 50,
    removed: 45,
    analyzeWithin: scope.startsWith('vol:') ? { label: 'Analyze within this volume', volumeIds: [scope.slice(4)], scopeLabel: 'Volume VI' } : undefined,
  };
}

function server(answers: Record<string, unknown> = {}, user: Me = me, held: Preferences = preferences) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/me': user,
    '/api/v1/me/preferences': held,
    '/api/v1/cloud/context': context,
    '/api/v1/cloud': cloud,
    ...answers,
  });
}

describe('the Word Cloud', () => {
  it('opens on the corpus under the lens bar’s first lens, with the cloud drawn and its list, the chip and what the settings took out', async () => {
    server();
    renderAt('/cloud');
    expect(await screen.findByRole('heading', { level: 1, name: 'Word Cloud' })).toBeTruthy();
    const lensBar = await screen.findByRole('group', { name: 'Show' });
    expect(within(lensBar).getAllByRole('radio').map((radio) => (radio as HTMLInputElement).labels?.[0]?.textContent)).toEqual([
      'Topics (nouns)',
      'Actions (verbs)',
      'Concepts',
      'Sentiment',
    ]);
    expect((within(lensBar).getByRole('radio', { name: 'Topics (nouns)' }) as HTMLInputElement).checked).toBe(true);
    expect(await screen.findByRole('heading', { level: 2, name: 'Entire Corpus' })).toBeTruthy();
    expect(screen.getByText('5 terms')).toBeTruthy();
    expect(screen.getByText('Topics', { selector: '.cloud-chip' })).toBeTruthy();
    expect(screen.getByText('Your settings took 45 words out of this list of 50.')).toBeTruthy();
    const table = screen.getByRole('table', { name: 'Terms by count' });
    expect(within(table).getAllByRole('row').slice(1).map((row) => within(row).getAllByRole('cell').map((cell) => cell.textContent))).toEqual([
      ['1', 'government-topics', '900', 'More'],
      ['2', 'meeting-topics', '800', 'More'],
      ['3', 'question-topics', '700', 'More'],
      ['4', 'policy-topics', '600', 'More'],
      ['5', 'agreement-topics', '500', 'More'],
    ]);
    expect(screen.getByText('These clouds were counted by this server’s own tagger.')).toBeTruthy();
    const scope = screen.getByRole('combobox', { name: 'Scope' }) as HTMLSelectElement;
    expect(scope.value).toBe('corpus');
    expect(Array.from(scope.querySelectorAll('optgroup')).map((group) => group.label)).toEqual(['Subseries', 'Volume: 1961-63', 'Volume: 1969-76']);
    expect(Array.from(scope.options).map((option) => option.textContent)).toContain('Foreign Relations, 1961–1963, Volume VI');
  });

  it('asks again for the lens and the scope chosen, each in the address', async () => {
    const fetch = server();
    const user = userEvent.setup();
    const { router } = renderAt('/cloud');
    const lensBar = await screen.findByRole('group', { name: 'Show' });
    await user.click(within(lensBar).getByRole('radio', { name: 'Sentiment' }));
    expect(router.state.location.search).toMatchObject({ lens: 'sentiment' });
    expect(await screen.findByRole('button', { name: 'government-sentiment' })).toBeTruthy();
    expect(screen.getByRole('columnheader', { name: 'Polarity' })).toBeTruthy();
    expect(screen.getByText('Positive', { selector: '.cloud-legend span' })).toBeTruthy();
    await user.selectOptions(screen.getByRole('combobox', { name: 'Scope' }), 'vol:frus1961-63v06');
    expect(router.state.location.search).toMatchObject({ scope: 'vol:frus1961-63v06', lens: 'sentiment' });
    expect(await screen.findByRole('heading', { level: 2, name: 'Foreign Relations, 1961–1963, Volume VI' })).toBeTruthy();
    const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).filter((url) => url.pathname === '/api/v1/cloud');
    expect(asked.map((url) => url.search)).toEqual(['?scope=corpus&lens=topics', '?scope=corpus&lens=sentiment', '?scope=vol%3Afrus1961-63v06&lens=sentiment']);
  });

  it('refuses Distinctive with its reason, and keeps the measure in this browser', async () => {
    server();
    const user = userEvent.setup();
    renderAt('/cloud');
    const measure = await screen.findByRole('group', { name: 'Size words by' });
    await user.click(within(measure).getByRole('radio', { name: 'Distinctive' }));
    expect(screen.getByRole('heading', { name: 'No Distinctiveness Ranking' })).toBeTruthy();
    expect(screen.getByText(/This server cannot count a scope’s words itself yet/)).toBeTruthy();
    expect(screen.queryByRole('table', { name: 'Terms by count' })).toBeNull();
    expect(window.localStorage.getItem('frus.wordcloud.measure')).toBe('keyness');
    await user.click(within(measure).getByRole('radio', { name: 'Frequency' }));
    expect(await screen.findByRole('table', { name: 'Terms by count' })).toBeTruthy();
  });

  it('shows a document’s volume’s cloud from the rail, saying why, with the way back', async () => {
    const fetch = server();
    renderAt('/cloud?scope=doc%3Afrus1961-63v06%2Fd5');
    expect(await screen.findByText(/A document’s own word cloud is counted from its text/)).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Back to the document' }).getAttribute('href')).toBe('/doc/frus1961-63v06/d5');
    expect(await screen.findByRole('heading', { level: 2, name: 'Foreign Relations, 1961–1963, Volume VI' })).toBeTruthy();
    const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/cloud');
    expect(asked?.searchParams.get('scope')).toBe('vol:frus1961-63v06');
  });

  it('hides a word from this cloud alone, gives the keyboard to the next word, and brings it back on asking', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/cloud');
    await user.click(await screen.findByRole('button', { name: 'More for meeting-topics' }));
    await user.click(screen.getByRole('menuitem', { name: 'Hide in this word cloud' }));
    expect(screen.queryByRole('button', { name: 'meeting-topics' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'question-topics' }));
    expect(screen.getByText('meeting-topics hidden from this word cloud')).toBeTruthy();
    expect(screen.getByText('4 terms')).toBeTruthy();
    await user.click(screen.getByRole('button', { name: 'Show 1 hidden words' }));
    expect(screen.getByRole('button', { name: 'meeting-topics' })).toBeTruthy();
    expect(document.activeElement).toBe(screen.getByRole('heading', { level: 3, name: 'Terms by count' }));
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'POST')).toBe(false);
  });

  it('hides a word in this lens through the reader’s settings, which the cloud is then asked under', async () => {
    let held: Preferences = preferences;
    const fetch = server({
      '/api/v1/me/preferences': () => held,
      'POST /api/v1/me/preferences/hidden-words': (_url: URL, init?: RequestInit) => {
        const body = JSON.parse(String(init?.body)) as { word: string; lens?: string };
        held = { ...held, wordCloud: { ...held.wordCloud, lensStopwords: { [body.lens!]: [body.word] } } };
        return held;
      },
    });
    const user = userEvent.setup();
    renderAt('/cloud');
    await user.click(await screen.findByRole('button', { name: 'More for government-topics' }));
    await user.click(screen.getByRole('menuitem', { name: 'Hide this word in this lens' }));
    const posted = fetch.mock.calls.find(([, init]) => init?.method === 'POST');
    expect(JSON.parse(String(posted?.[1]?.body))).toEqual({ word: 'government-topics', lens: 'topics' });
    expect(screen.queryByRole('button', { name: 'government-topics' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'meeting-topics' }));
    await waitFor(() =>
      expect(fetch.mock.calls.filter(([url]) => new URL(url, 'http://localhost').pathname === '/api/v1/cloud').length).toBe(2),
    );
  });

  it('asks the cloud again under a criterion only once the server has kept it, the box showing it at once', async () => {
    let held: Preferences = preferences;
    const answers: (() => void)[] = [];
    const fetch = server({
      '/api/v1/me/preferences': () => held,
      'PATCH /api/v1/me/preferences': (_url: URL, init?: RequestInit) => {
        const body = JSON.parse(String(init?.body)) as { wordCloud: Partial<Preferences['wordCloud']> };
        held = { ...held, wordCloud: { ...held.wordCloud, ...body.wordCloud } };
        const kept = held;
        return new Promise<Preferences>((resolve) => answers.push(() => resolve(kept)));
      },
    });
    const clouds = () => fetch.mock.calls.filter(([url]) => new URL(url, 'http://localhost').pathname === '/api/v1/cloud').length;
    const user = userEvent.setup();
    renderAt('/cloud');
    expect(await screen.findByRole('button', { name: 'More for government-topics' })).toBeTruthy();
    const box = screen.getByRole('checkbox', { name: 'Hide common diplomatic words' }) as HTMLInputElement;
    expect(box.checked).toBe(true);
    expect(clouds()).toBe(1);
    await user.click(box);
    expect(box.checked).toBe(false);
    await waitFor(() => expect(answers).toHaveLength(1));
    expect(clouds()).toBe(1);
    await act(async () => answers[0]!());
    await waitFor(() => expect(clouds()).toBe(2));
    expect(box.checked).toBe(false);
  });

  it('draws the state a lens gives before asking whether it can be ranked by distinctiveness', async () => {
    server({
      '/api/v1/cloud': (url: URL) => ({ ...cloud(url), state: 'insufficientSignal', terms: [], message: { title: 'Not Enough Signal', detail: 'Too few concepts.' } }),
    });
    window.localStorage.setItem('frus.wordcloud.measure', 'keyness');
    renderAt('/cloud');
    expect(await screen.findByRole('heading', { name: 'Not Enough Signal' })).toBeTruthy();
    expect(screen.queryByRole('heading', { name: 'No Distinctiveness Ranking' })).toBeNull();
  });

  it('offers no list of the reader’s on a server that keeps none, and draws the states the server gives', async () => {
    server({
      '/api/v1/cloud': (url: URL) => ({ ...cloud(url), state: 'noTerms', terms: [], message: { title: 'Nothing Found for This Lens', detail: 'None of their nouns passed.' } }),
    }, { ...me, userData: false });
    renderAt('/cloud');
    expect(await screen.findByRole('heading', { name: 'Nothing Found for This Lens' })).toBeTruthy();
    expect(screen.getByText('None of their nouns passed.')).toBeTruthy();
    expect(screen.queryByRole('checkbox', { name: 'Hide common diplomatic words' })).toBeNull();
    expect(screen.queryByRole('link', { name: 'Word Cloud Settings' })).toBeNull();
  });
});
