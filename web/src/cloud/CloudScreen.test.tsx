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
  { id: 'allTerms', label: 'All terms', shortLabel: 'All terms', colorsBySentiment: false, available: true },
  { id: 'people', label: 'People', shortLabel: 'People', colorsBySentiment: false, available: false },
  { id: 'places', label: 'Places', shortLabel: 'Places', colorsBySentiment: false, available: false },
  { id: 'organizations', label: 'Organizations', shortLabel: 'Organizations', colorsBySentiment: false, available: false },
  { id: 'topics', label: 'Topics (nouns)', shortLabel: 'Topics', colorsBySentiment: false, available: true },
  { id: 'actions', label: 'Actions (verbs)', shortLabel: 'Actions', colorsBySentiment: false, available: true },
  { id: 'descriptors', label: 'Descriptors (adjectives)', shortLabel: 'Descriptors', colorsBySentiment: false, available: true },
  { id: 'concepts', label: 'Concepts', shortLabel: 'Concepts', colorsBySentiment: false, available: true },
  { id: 'sentiment', label: 'Sentiment', shortLabel: 'Sentiment', colorsBySentiment: true, available: true },
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
  subjects: [{ label: 'Economics', subcategories: ['Trade', 'Aid'] }],
  dateRange: { from: '1975-12-31', to: '1976-12-31' },
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
    scope: {
      signature: scope,
      title: scope === 'corpus' ? 'Entire Corpus' : scope === 'vol:frus1961-63v06' || scope.startsWith('doc:') ? 'Foreign Relations, 1961–1963, Volume VI' : scope.slice(4),
    },
    lens,
    chip: lens.shortLabel,
    source: 'family',
    state: 'terms',
    countLine: '5 terms',
    terms,
    listed: 50,
    removed: 45,
    analyzeWithin: scope.startsWith('vol:') ? { label: 'Analyze within this volume', volumeIds: [scope.slice(4)], scopeLabel: 'Volume VI' } : undefined,
    // Under Distinctive (S29f), the server's ranking of the words, less those the request hides.
    distinctive: url.searchParams.get('measure') === 'keyness' ? ranking(lens.id, url.searchParams.getAll('hidden')) : undefined,
  };
}

/** A ranking as the server gives it: three words of the lens, less `hidden`, the last unpriced. */
function ranking(lens: string, hidden: string[] = []): NonNullable<CloudAnswer['distinctive']> {
  const scores = [
    { term: `khrushchev-${lens}`, scopeCount: 412, referenceCount: 9_310, logLikelihood: 3806.44, logRatio: 8.32, fold: 319.5, unpriced: false },
    { term: `berlin-${lens}`, scopeCount: 1787, referenceCount: 61_002, logLikelihood: 3244.07, logRatio: 2.58, fold: 5.98, unpriced: false },
    { term: `zorin-${lens}`, scopeCount: 9, referenceCount: 0, logLikelihood: 51.2, logRatio: 10.1, fold: 1097.6, unpriced: true },
  ].filter((score) => !hidden.includes(score.term.toLowerCase()));
  return {
    state: 'ranked',
    scores,
    layout: scores.map((score) => ({ term: score.term, count: Math.round(score.logLikelihood * 100) })),
    countLine: `${scores.length} terms from 393 documents`,
    caveat: 'Ranked over every word occurring at least 3 times here. Words occurring fewer than 114 times corpus-wide are unpriced and score as if new.',
    candidateCount: 900,
    rankedAmongTopFrequent: false,
    minimumScopeCount: 3,
    referenceCutoffCount: 114,
    wordForm: 'dictionary',
  };
}

const recordId = '5E17F000-0000-4000-8000-0000000000A1';

function server(answers: Record<string, unknown> = {}, user: Me = me, held: Preferences = preferences) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/me': user,
    '/api/v1/me/preferences': held,
    '/api/v1/cloud/context': context,
    '/api/v1/cloud': cloud,
    '/api/v1/me/collections': { total: 1, items: [{ id: recordId, name: 'Talks', listName: 'Talks', documentCount: 2 }] },
    '/api/v1/me/tags': { total: 1, items: [{ id: recordId, name: 'Canal' }] },
    '/api/v1/me/saved-searches': { total: 1, items: [{ id: recordId, name: 'Treaties', queryText: 'treaty', search: {} }] },
    '/api/v1/me/volume-scopes': { total: 1, items: [{ id: recordId, name: '', volumeIds: ['frus1961-63v06'] }] },
    ...answers,
  });
}

describe('the Word Cloud', () => {
  it('opens on the corpus under the lens bar’s first lens, with the cloud drawn and its list, the chip and what the settings took out', async () => {
    server();
    renderAt('/cloud');
    expect(await screen.findByRole('heading', { level: 1, name: 'Word Cloud' })).toBeTruthy();
    const lensBar = await screen.findByRole('group', { name: 'Show' });
    expect(within(lensBar).getAllByRole('radio').map((radio) => (radio as HTMLInputElement).labels?.[0]?.textContent)).toEqual(lenses.map((each) => each.label));
    expect((within(lensBar).getByRole('radio', { name: 'All terms' }) as HTMLInputElement).checked).toBe(true);
    expect(await screen.findByRole('heading', { level: 2, name: 'Entire Corpus' })).toBeTruthy();
    expect(screen.getByText('5 terms')).toBeTruthy();
    expect(screen.getByText('All terms', { selector: '.cloud-chip' })).toBeTruthy();
    expect(screen.getByText('Your settings took 45 words out of this list of 50.')).toBeTruthy();
    const table = screen.getByRole('table', { name: 'Terms by count' });
    expect(within(table).getAllByRole('row').slice(1).map((row) => within(row).getAllByRole('cell').map((cell) => cell.textContent))).toEqual([
      ['1', 'government-allTerms', '900', 'More'],
      ['2', 'meeting-allTerms', '800', 'More'],
      ['3', 'question-allTerms', '700', 'More'],
      ['4', 'policy-allTerms', '600', 'More'],
      ['5', 'agreement-allTerms', '500', 'More'],
    ]);
    expect(screen.getByText('These clouds were counted by this server’s own tagger.')).toBeTruthy();
    const scope = screen.getByRole('combobox', { name: 'Scope' }) as HTMLSelectElement;
    expect(scope.value).toBe('corpus');
    await waitFor(() =>
      expect(Array.from(scope.querySelectorAll('optgroup')).map((group) => group.label)).toEqual([
        'Subseries', 'Volume: 1961-63', 'Volume: 1969-76', 'Collection', 'Tag', 'Saved Search', 'My Volume Scopes', 'By Subject: Economics', 'Date Range',
      ]),
    );
    const id = '5E17F000-0000-4000-8000-0000000000A1';
    expect(Array.from(scope.options).map((option) => option.value)).toEqual(expect.arrayContaining([
      `col:${id}`, `tag:${id}`, `search:${id}`, `scope:${id}`, 'subject:Economics\u001fTrade', 'subject:Economics\u001fAid', 'daterange',
    ]));
    expect(Array.from(scope.options).find((option) => option.value === `scope:${id}`)?.textContent).toBe('Untitled');
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
    expect(asked.map((url) => url.search)).toEqual(['?scope=corpus&lens=allTerms', '?scope=corpus&lens=sentiment', '?scope=vol%3Afrus1961-63v06&lens=sentiment']);
  });

  it('sizes the cloud by Distinctive, the server’s ranking with its caveat and each word’s keyness, and keeps the measure in this browser', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/cloud');
    const measure = await screen.findByRole('group', { name: 'Size words by' });
    await screen.findByRole('table', { name: 'Terms by count' });
    await user.click(within(measure).getByRole('radio', { name: 'Distinctive' }));
    const table = await screen.findByRole('table', { name: 'Terms by distinctiveness' });
    expect(within(table).getAllByRole('columnheader').map((header) => header.textContent)).toEqual(['Rank', 'Term', 'Keyness', 'Actions']);
    const cells = (row: HTMLElement, selector: string) => row.querySelector(selector)?.textContent;
    expect(
      within(table)
        .getAllByRole('row')
        .slice(1)
        .map((row) => [cells(row, '.cloud-rank'), cells(row, '.link-button'), cells(row, '.cloud-keyness-caption'), cells(row, '.cloud-count')]),
    ).toEqual([
      ['1', 'khrushchev-allTerms', '320× more often here · 412 here · 9,310 corpus-wide', '3,806.4'],
      ['2', 'berlin-allTerms', '6.0× more often here · 1,787 here · 61,002 corpus-wide', '3,244.1'],
      ['3', 'zorin-allTerms', '1,098× more often here · 9 here · fewer than 114 corpus-wide (unpriced)', '51.2'],
    ]);
    // A word is read with the app's reading of its row.
    const word = within(table).getByRole('button', { name: 'khrushchev-allTerms' });
    expect(document.getElementById(word.getAttribute('aria-describedby')!)?.textContent).toBe(
      'keyness 3,806.4; 320× more often here; 412 here · 9,310 corpus-wide',
    );
    // The header counts the words ranked, and the caveat sits under the measure.
    expect(screen.getByText('3 terms from 393 documents')).toBeTruthy();
    expect(screen.getByText(/^Ranked over every word occurring at least 3 times here\./)).toBeTruthy();
    const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).filter((url) => url.pathname === '/api/v1/cloud');
    expect(asked.at(-1)?.search).toBe('?scope=corpus&lens=allTerms&measure=keyness');
    expect(window.localStorage.getItem('frus.wordcloud.measure')).toBe('keyness');

    await user.click(within(measure).getByRole('radio', { name: 'Frequency' }));
    expect(await screen.findByRole('table', { name: 'Terms by count' })).toBeTruthy();
    expect(screen.queryByText(/^Ranked over every word/)).toBeNull();
  });

  it('asks Distinctive again without a word hidden from this cloud alone, as the app ranks the words it shows', async () => {
    window.localStorage.setItem('frus.wordcloud.measure', 'keyness');
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/cloud');
    const table = await screen.findByRole('table', { name: 'Terms by distinctiveness' });
    await user.click(within(table).getByRole('button', { name: 'More for berlin-allTerms' }));
    await user.click(await screen.findByRole('menuitem', { name: 'Hide in this word cloud' }));
    await waitFor(() => expect(within(table).queryByRole('button', { name: 'berlin-allTerms' })).toBeNull());
    await waitFor(() => {
      const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).filter((url) => url.pathname === '/api/v1/cloud');
      expect(asked.at(-1)?.searchParams.getAll('hidden')).toEqual(['berlin-allterms']);
    });
    expect(await screen.findByText('2 terms from 393 documents')).toBeTruthy();
  });

  it('says why a scope has no ranking, in the server’s words', async () => {
    window.localStorage.setItem('frus.wordcloud.measure', 'keyness');
    server({
      '/api/v1/cloud': (url: URL) => ({
        ...cloud(url),
        distinctive: {
          state: 'unavailable',
          reason: 'configurationMismatch',
          message: { title: 'No Distinctiveness Ranking', detail: 'Your settings count words differently from the bundled corpus reference, so the two can’t be compared: plural folding differs.' },
          mismatches: ['foldPlurals'],
          scores: [],
          layout: [],
        },
      }),
    });
    renderAt('/cloud');
    expect(await screen.findByRole('heading', { name: 'No Distinctiveness Ranking' })).toBeTruthy();
    expect(screen.getByText(/so the two can’t be compared: plural folding differs\./)).toBeTruthy();
    expect(screen.queryByRole('table')).toBeNull();
  });

  it('shows a document’s own cloud from the rail, counted live, with the way back (S29e)', async () => {
    const fetch = server({
      '/api/v1/cloud': (url: URL) => ({ ...cloud(url), source: 'live', countLine: '5 terms from 1 document', documentCount: 1,
        account: 'This cloud was counted from its scope’s 1 document by this server’s own tagger.' }),
    });
    renderAt('/cloud?scope=doc%3Afrus1961-63v06%2Fd5');
    expect((await screen.findByRole('link', { name: 'Back to the document' })).getAttribute('href')).toBe('/doc/frus1961-63v06/d5');
    expect(await screen.findByRole('heading', { level: 2, name: 'Foreign Relations, 1961–1963, Volume VI' })).toBeTruthy();
    expect(screen.getByText('5 terms from 1 document')).toBeTruthy();
    expect(screen.getByText('This cloud was counted from its scope’s 1 document by this server’s own tagger.')).toBeTruthy();
    expect(screen.queryByText('These clouds were counted by this server’s own tagger.')).toBeNull();
    const scope = screen.getByRole('combobox', { name: 'Scope' }) as HTMLSelectElement;
    expect(scope.value).toBe('doc:frus1961-63v06/d5');
    expect(scope.selectedOptions[0]?.textContent).toBe('Document d5');
    const asked = fetch.mock.calls.map(([url]) => new URL(url, 'http://localhost')).find((url) => url.pathname === '/api/v1/cloud');
    expect(asked?.searchParams.get('scope')).toBe('doc:frus1961-63v06/d5');
  });

  it('follows a count’s job until it ends, its bar and line saying how far it has come, then draws the cloud kept', async () => {
    let finished = false;
    let polls = 0;
    const fetch = server({
      '/api/v1/cloud': (url: URL) =>
        finished
          ? { ...cloud(url), source: 'live', countLine: '5 terms from 400 documents', documentCount: 400, account: 'Counted from 400 documents.' }
          : { ...cloud(url), source: 'live', state: 'counting', terms: [], countLine: undefined,
              message: { title: 'Building word cloud…', detail: 'This server is counting every indexed document as a job.' },
              job: { id: 'J1', state: 'queued' } },
      '/api/v1/cloud/jobs/J1': () => {
        polls += 1;
        if (polls === 1) return { id: 'J1', state: 'running', fraction: 0.5, progress: 'Counted the words of 200 of 400 documents' };
        finished = true;
        return { id: 'J1', state: 'succeeded', fraction: 1, progress: 'Counted 5 terms from 400 documents' };
      },
    });
    renderAt('/cloud');
    expect(await screen.findByRole('heading', { level: 2, name: 'Building word cloud…' })).toBeTruthy();
    expect(screen.getByText('This server is counting every indexed document as a job.')).toBeTruthy();
    expect(await screen.findByText('Counted the words of 200 of 400 documents (50% counted)')).toBeTruthy();
    expect((screen.getByRole('progressbar', { name: 'Counting this scope’s words' }) as HTMLProgressElement).value).toBe(0.5);
    expect(await screen.findByRole('button', { name: 'government-allTerms' }, { timeout: 4000 })).toBeTruthy();
    expect(screen.getByText('5 terms from 400 documents')).toBeTruthy();
    expect(screen.getByText('Counted from 400 documents.')).toBeTruthy();
    expect(fetch.mock.calls.filter(([url]) => new URL(url, 'http://localhost').pathname === '/api/v1/cloud')).toHaveLength(2);
  });

  it('says why a job ended without its cloud, and counts again after a stop', async () => {
    let asked = 0;
    server({
      '/api/v1/cloud': (url: URL) => {
        asked += 1;
        return { ...cloud(url), source: 'live', state: 'counting', terms: [], message: { title: 'Building word cloud…', detail: 'Counting.' },
          job: { id: `J${asked}`, state: 'queued' } };
      },
      '/api/v1/cloud/jobs/J1': { id: 'J1', state: 'cancelled', progress: 'Counted the words of 200 of 400 documents' },
      '/api/v1/cloud/jobs/J2': { id: 'J2', state: 'failed', error: 'It stopped at an error, which the server’s log gives.' },
    });
    const user = userEvent.setup();
    renderAt('/cloud');
    expect(await screen.findByText('The count was stopped before it finished.')).toBeTruthy();
    await user.click(screen.getByRole('button', { name: 'Count Again' }));
    expect(await screen.findByText('It stopped at an error, which the server’s log gives.')).toBeTruthy();
    expect(screen.getByRole('heading', { level: 2, name: 'Couldn’t Build Word Cloud' })).toBeTruthy();
    // A failed job is asked again too, the keyboard going to the page's heading as the button goes.
    await user.click(screen.getByRole('button', { name: 'Count Again' }));
    expect(document.activeElement).toBe(screen.getByRole('heading', { level: 1, name: 'Word Cloud' }));
    await waitFor(() => expect(asked).toBe(3));
  });

  it('says why the server’s tagger draws no entity lens, and draws a range’s days with its way to Chronology', async () => {
    server({
      '/api/v1/cloud': (url: URL) =>
        url.searchParams.get('lens') === 'people'
          ? { ...cloud(url), source: 'live', state: 'lensUnavailable', terms: [], countLine: undefined,
              message: { title: 'Lens Unavailable on This Server', detail: 'This server’s tagger does not recognize names.' } }
          : cloud(url),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/cloud?scope=daterange%3A1962-10-01..1962-10-31&lens=people');
    expect(await screen.findByRole('heading', { level: 2, name: 'Lens Unavailable on This Server' })).toBeTruthy();
    expect(screen.getByText('This server’s tagger does not recognize names.')).toBeTruthy();
    const scope = screen.getByRole('combobox', { name: 'Scope' }) as HTMLSelectElement;
    expect(scope.value).toBe('daterange');
    expect((screen.getByLabelText('Range start') as HTMLInputElement).value).toBe('1962-10-01');
    expect((screen.getByLabelText('Range end') as HTMLInputElement).value).toBe('1962-10-31');
    expect(screen.getByRole('link', { name: 'View in Chronology' }).getAttribute('href')).toBe('/chronology?from=1962-10-01&to=1962-10-31');
    // A day typed is applied by Show, not as it is typed.
    const start = screen.getByLabelText('Range start') as HTMLInputElement;
    await user.clear(start);
    await user.type(start, '1962-10-15');
    expect(router.state.location.search).toMatchObject({ scope: 'daterange:1962-10-01..1962-10-31' });
    await user.click(screen.getByRole('button', { name: 'Show' }));
    expect(router.state.location.search).toMatchObject({ scope: 'daterange:1962-10-15..1962-10-31' });
    await user.selectOptions(scope, 'corpus');
    expect(router.state.location.search).toMatchObject({ scope: 'corpus' });
    await user.selectOptions(scope, 'daterange');
    expect(router.state.location.search).toMatchObject({ scope: 'daterange:1975-12-31..1976-12-31' });
  });

  it('hides a word from this cloud alone, gives the keyboard to the next word, and brings it back on asking', async () => {
    const fetch = server();
    const user = userEvent.setup();
    renderAt('/cloud');
    await user.click(await screen.findByRole('button', { name: 'More for meeting-allTerms' }));
    await user.click(screen.getByRole('menuitem', { name: 'Hide in this word cloud' }));
    expect(screen.queryByRole('button', { name: 'meeting-allTerms' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'question-allTerms' }));
    expect(screen.getByText('meeting-allTerms hidden from this word cloud')).toBeTruthy();
    expect(screen.getByText('4 terms')).toBeTruthy();
    await user.click(screen.getByRole('button', { name: 'Show 1 hidden words' }));
    expect(screen.getByRole('button', { name: 'meeting-allTerms' })).toBeTruthy();
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
    await user.click(await screen.findByRole('button', { name: 'More for government-allTerms' }));
    await user.click(screen.getByRole('menuitem', { name: 'Hide this word in this lens' }));
    const posted = fetch.mock.calls.find(([, init]) => init?.method === 'POST');
    expect(JSON.parse(String(posted?.[1]?.body))).toEqual({ word: 'government-allTerms', lens: 'allTerms' });
    expect(screen.queryByRole('button', { name: 'government-allTerms' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'meeting-allTerms' }));
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
    expect(await screen.findByRole('button', { name: 'More for government-allTerms' })).toBeTruthy();
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
