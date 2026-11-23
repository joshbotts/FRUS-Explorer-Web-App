import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { CloudSample } from '../api/cloud';
import type { Preferences } from '../api/research';
import { me } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';
import { preferences } from '../test/research';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  window.localStorage.clear();
});

const sample: CloudSample = {
  kept: ['negotiation', 'ambassador', 'settlement', 'negotiations', 'sovereignty'].map((term, index) => ({ term, count: 84 - index * 10 })),
  sampleSize: 23,
  summary: 'Keeps 5 of 23 terms in this sample',
  provenance: 'A stand-in sample: this server counts no clouds of its own for the sample to come from.',
};

/** A server that keeps the reader's preferences as the routes do: the criteria by a change, the hidden words by their routes. */
function keeping(initial: Preferences = preferences) {
  let held = initial;
  const fetch = stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/preferences': () => held,
    'PATCH /api/v1/me/preferences': (_url: URL, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body)) as { wordCloud: Partial<Preferences['wordCloud']> };
      held = { ...held, wordCloud: { ...held.wordCloud, ...body.wordCloud } };
      return held;
    },
    'POST /api/v1/me/preferences/hidden-words': (_url: URL, init?: RequestInit) => {
      const { word, lens } = JSON.parse(String(init?.body)) as { word: string; lens?: string };
      const lowered = word.trim().toLowerCase();
      held = lens
        ? { ...held, wordCloud: { ...held.wordCloud, lensStopwords: { ...held.wordCloud.lensStopwords, [lens]: [...(held.wordCloud.lensStopwords[lens] ?? []), lowered].sort() } } }
        : { ...held, wordCloud: { ...held.wordCloud, globalStopwords: [...held.wordCloud.globalStopwords, lowered].sort() } };
      return held;
    },
    'DELETE /api/v1/me/preferences/hidden-words': (url: URL) => {
      const word = url.searchParams.get('word')!;
      held = { ...held, wordCloud: { ...held.wordCloud, globalStopwords: held.wordCloud.globalStopwords.filter((each) => each !== word) } };
      return held;
    },
    '/api/v1/me/preferences/word-cloud-sample': sample,
  });
  return { fetch, held: () => held };
}

describe('Settings ▸ Word Cloud', () => {
  it('is a pane under Tools with the app’s sections, in its words, its sample sized by rank', async () => {
    keeping();
    renderAt('/settings/word-cloud');
    expect(await screen.findByRole('heading', { level: 1, name: 'Word Cloud' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Word Cloud' }).getAttribute('aria-current')).toBe('page');
    expect(await screen.findByRole('heading', { level: 2, name: 'Sample' })).toBeTruthy();
    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'Sample',
      'Filtering',
      'Thresholds',
      'Appearance',
      'Hidden Words',
    ]);
    const kept = await screen.findByLabelText('Sample of kept terms: negotiation, ambassador, settlement, negotiations, sovereignty');
    expect(Array.from(kept.querySelectorAll('span')).map((span) => span.style.fontSize)).toEqual(['20px', '17.75px', '15.5px', '13.25px', '11px']);
    expect(screen.getByText('Keeps 5 of 23 terms in this sample')).toBeTruthy();
    expect((screen.getByRole('checkbox', { name: 'Hide common diplomatic words' }) as HTMLInputElement).checked).toBe(true);
    expect((screen.getByRole('spinbutton', { name: 'Minimum word length' }) as HTMLInputElement).value).toBe('3');
    expect(screen.getByText('No custom words yet.')).toBeTruthy();
  });

  it('sets each criterion as it changes, and a threshold only within its range', async () => {
    const { fetch, held } = keeping();
    const user = userEvent.setup();
    renderAt('/settings/word-cloud');
    await user.click(await screen.findByRole('checkbox', { name: 'Merge plural and singular forms' }));
    await waitFor(() => expect(held().wordCloud.foldPlurals).toBe(false));
    const length = screen.getByRole('spinbutton', { name: 'Minimum word length' });
    await user.clear(length);
    await user.type(length, '9');
    await user.type(length, '{Backspace}5');
    await waitFor(() => expect(held().wordCloud.minLength).toBe(5));
    const patches = fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => JSON.parse(String(init?.body)));
    expect(patches).toEqual([{ wordCloud: { foldPlurals: false } }, { wordCloud: { minLength: 5 } }]);
    await user.tab();
    expect((length as HTMLInputElement).value).toBe('5');
  });

  it('hides and shows words in the list Applies to names, every cloud’s or a lens’s', async () => {
    const { fetch, held } = keeping();
    const user = userEvent.setup();
    renderAt('/settings/word-cloud');
    const field = await screen.findByRole('textbox', { name: 'Add a word…' });
    expect((screen.getByRole('button', { name: 'Add hidden word' }) as HTMLButtonElement).disabled).toBe(true);
    await user.type(field, 'Telegram{Enter}');
    await waitFor(() => expect(held().wordCloud.globalStopwords).toEqual(['telegram']));
    expect(await screen.findByRole('button', { name: 'Remove telegram' })).toBeTruthy();
    expect((field as HTMLInputElement).value).toBe('');
    const appliesTo = screen.getByRole('combobox', { name: 'Applies to' }) as HTMLSelectElement;
    expect(Array.from(appliesTo.options).map((option) => option.textContent)).toEqual([
      'Every cloud',
      'All terms',
      'People',
      'Places',
      'Organizations',
      'Topics (nouns)',
      'Actions (verbs)',
      'Descriptors (adjectives)',
      'Concepts',
      'Sentiment',
    ]);
    await user.selectOptions(appliesTo, 'topics');
    expect(screen.getByText(/Words hidden only when the selected lens is active/)).toBeTruthy();
    await user.type(field, 'meeting');
    await user.click(screen.getByRole('button', { name: 'Add hidden word' }));
    await waitFor(() => expect(held().wordCloud.lensStopwords).toEqual({ topics: ['meeting'] }));
    expect(fetch.mock.calls.filter(([url]) => new URL(url, 'http://localhost').pathname === '/api/v1/me/preferences/word-cloud-sample')
      .some(([url]) => new URL(url, 'http://localhost').searchParams.get('lens') === 'topics')).toBe(true);
    await user.selectOptions(appliesTo, '');
    await user.click(screen.getByRole('button', { name: 'Remove telegram' }));
    await waitFor(() => expect(held().wordCloud.globalStopwords).toEqual([]));
    expect(document.activeElement).toBe(field);
    const removed = fetch.mock.calls.find(([, init]) => init?.method === 'DELETE');
    expect(new URL(String(removed?.[0]), 'http://localhost').search).toBe('?word=telegram');
  });

  it('keeps the typeface and density in this browser, and offers them alone on a server that keeps no settings', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    const user = userEvent.setup();
    renderAt('/settings/word-cloud');
    expect(await screen.findByText('This server keeps no reader’s settings, so its word clouds are drawn at the app’s own settings.')).toBeTruthy();
    expect(screen.queryByRole('heading', { name: 'Filtering' })).toBeNull();
    const appearance = screen.getByRole('region', { name: 'Appearance' });
    await user.selectOptions(within(appearance).getByRole('combobox', { name: 'Font' }), 'monospaced');
    await user.selectOptions(within(appearance).getByRole('combobox', { name: 'Density' }), 'airy');
    expect(window.localStorage.getItem('frus.wordcloud.fontDesign')).toBe('monospaced');
    expect(window.localStorage.getItem('frus.wordcloud.density')).toBe('airy');
  });
});
