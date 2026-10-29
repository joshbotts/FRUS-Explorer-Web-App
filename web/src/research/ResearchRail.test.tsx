import { act, cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail, DocumentHighlights, DocumentTags, Highlight, Me, UserTag } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { coverage, ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

const d1: DocumentDetail = {
  document: {
    documentId: 'd1',
    volumeId: 'frus1961-63v06',
    documentNumber: '1',
    header: '1. Telegram From the Embassy in the Soviet Union',
    displayTitle: '1. Telegram From the Embassy in the Soviet Union',
    isEditorialNote: false,
    inIndex: true,
  },
  canonicalURL: 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1',
  teiAvailable: true,
};

export const me: Me = {
  userId: 'owner',
  displayName: 'Owner',
  auth: 'none',
  roles: ['reader', 'curator', 'admin'],
  userData: true,
  csrfToken: 'token-1',
};

const berlin: UserTag = { id: 'B0000000-0000-4000-8000-000000000000', name: 'Berlin' };
const revisit: UserTag = { id: 'R0000000-0000-4000-8000-000000000000', name: 'Revisit' };
const tagsPath = '/api/v1/me/volumes/frus1961-63v06/documents/d1/tags';

function documentTags(items: UserTag[]): DocumentTags {
  return { volumeId: 'frus1961-63v06', documentId: 'd1', items };
}

const notesPath = '/api/v1/me/volumes/frus1961-63v06/documents/d1/notes';
const summariesPath = '/api/v1/me/volumes/frus1961-63v06/documents/d1/summaries';

/** The reader's answers, with the user's and the document's tags as given, and no notes or summaries unless given. */
function reader(answers: Record<string, unknown>) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
    '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    '/api/v1/me': me,
    [notesPath]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [summariesPath]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    ...answers,
  });
}

/** What a change sent: its body as JSON, and its token. */
function sent(init?: RequestInit) {
  const headers = init?.headers as Record<string, string>;
  return { body: init?.body ? JSON.parse(String(init.body)) : undefined, token: headers['X-CSRF-Token'], type: headers['Content-Type'] };
}

beforeEach(() => {
  resetPreferences();
  window.localStorage.clear();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('the Research rail', () => {
  it('opens from its toggle, with its Tags section closed until it is opened, and then as it was left', async () => {
    reader({ [tagsPath]: documentTags([berlin]) });
    renderAt('/doc/frus1961-63v06/d1');
    const toggle = await screen.findByRole('button', { name: 'Research' });
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    await userEvent.click(toggle);
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    expect(within(rail).getByRole('heading', { name: 'Research' })).toBe(document.activeElement);
    // The section's badge counts the document's tags, as the app's does, before it is opened.
    const section = await within(rail).findByRole('button', { name: 'Tags, 1 tag' });
    expect(section.getAttribute('aria-expanded')).toBe('false');
    expect(within(rail).queryByRole('button', { name: 'Remove Berlin' })).toBeNull();
    await userEvent.click(section);
    expect(section.getAttribute('aria-expanded')).toBe('true');
    expect(within(rail).getByRole('button', { name: 'Remove Berlin' })).toBeTruthy();
    expect(window.localStorage.getItem('frus.research.tags')).toBe('open');

    await userEvent.click(within(rail).getByRole('button', { name: 'Close' }));
    expect(screen.queryByRole('complementary', { name: 'Research' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Research' }));
  });

  it('is not offered by a server that keeps no user data', async () => {
    reader({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByRole('button', { name: 'Cite' });
    await waitFor(() => expect(screen.queryByRole('complementary', { name: 'Research' })).toBeNull());
    expect(screen.queryByRole('button', { name: 'Research' })).toBeNull();
  });

  it('takes a tag off the document with its ×, as the app’s chip does', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    const fetch = reader({
      [tagsPath]: documentTags([berlin, revisit]),
      [`DELETE ${tagsPath}/${berlin.id}`]: documentTags([revisit]),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const remove = await screen.findByRole('button', { name: 'Remove Berlin' });
    await userEvent.click(remove);
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Remove Berlin' })).toBeNull());
    expect(screen.getByRole('button', { name: 'Remove Revisit' })).toBeTruthy();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Add Tag' }));
    const call = fetch.mock.calls.find(([, init]) => init?.method === 'DELETE');
    expect(sent(call?.[1]).token).toBe('token-1');
  });

  it('tags the document in the picker: a new tag is made, switched on and listed first, and Done gives the document the tags switched on', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    const primary: UserTag = { id: 'P0000000-0000-4000-8000-000000000000', name: 'Primary source' };
    let all = [berlin, revisit];
    const fetch = reader({
      [tagsPath]: documentTags([berlin]),
      '/api/v1/me/tags': () => ({ total: all.length, items: all }),
      'POST /api/v1/me/tags': (_: URL, init?: RequestInit) => {
        expect(sent(init)).toEqual({ body: { name: 'Primary source' }, token: 'token-1', type: 'application/json' });
        all = [berlin, primary, revisit];
        return primary;
      },
      [`PUT ${tagsPath}`]: (_: URL, init?: RequestInit) => documentTags(all.filter((tag) => sent(init).body.tagIds.includes(tag.id))),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Add Tag' }));
    const picker = await screen.findByRole('dialog', { name: 'Tags — Doc 1' });
    const field = within(picker).getByRole('textbox', { name: 'New tag name' });
    expect(document.activeElement).toBe(field);
    expect(within(picker).getByRole('button', { name: 'Add' })).toHaveProperty('disabled', true);
    await within(picker).findByRole('checkbox', { name: 'Berlin' });
    expect(within(picker).getByRole('checkbox', { name: 'Berlin' })).toHaveProperty('checked', true);
    expect(within(picker).getByRole('checkbox', { name: 'Revisit' })).toHaveProperty('checked', false);

    await userEvent.type(field, '  Primary source {Enter}');
    const made = await within(picker).findByRole('checkbox', { name: /^Primary source\b/ });
    expect(made).toHaveProperty('checked', true);
    expect(made.closest('label')?.querySelector('.badge')?.textContent).toBe(', New');
    await waitFor(() => expect(document.activeElement).toBe(made));
    expect(within(picker).getAllByRole('checkbox').map((box) => box.closest('label')?.textContent?.trim())).toEqual([
      'Primary source, New',
      'Berlin',
      'Revisit',
    ]);
    expect(within(picker).getByRole('status').textContent).toBe('Tag Primary source created and selected');

    await userEvent.click(within(picker).getByRole('checkbox', { name: 'Berlin' }));
    await userEvent.click(within(picker).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    const put = fetch.mock.calls.find(([, init]) => init?.method === 'PUT');
    expect(sent(put?.[1]).body).toEqual({ tagIds: [primary.id] });
    expect(await screen.findByRole('button', { name: 'Remove Primary source' })).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Remove Berlin' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Add Tag' }));
  });

  it('deletes the tags made in the picker when it is cancelled, as the app’s Cancel does', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    const made: UserTag = { id: 'N0000000-0000-4000-8000-000000000000', name: 'Draft' };
    const fetch = reader({
      [tagsPath]: documentTags([]),
      '/api/v1/me/tags': { total: 0, items: [] },
      'POST /api/v1/me/tags': made,
      [`DELETE /api/v1/me/tags/${made.id}`]: null,
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Add Tag' }));
    const picker = await screen.findByRole('dialog');
    expect(within(picker).getByText('No user tags yet. Type a name above to create one.')).toBeTruthy();
    await userEvent.type(within(picker).getByRole('textbox', { name: 'New tag name' }), 'Draft');
    await userEvent.click(within(picker).getByRole('button', { name: 'Add' }));
    await within(picker).findByRole('checkbox', { name: /^Draft\b/ });
    await userEvent.click(within(picker).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.some(([url, init]) => init?.method === 'DELETE' && String(url).endsWith(`/api/v1/me/tags/${made.id}`))).toBe(true);
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'PUT')).toBe(false);
  });

  it('keeps the document’s tags while the list of tags is read, and waits for it before Done', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    let release: (list: unknown) => void = () => {};
    const fetch = reader({
      [tagsPath]: documentTags([berlin]),
      '/api/v1/me/tags': () => new Promise((resolve) => (release = resolve)),
      [`PUT ${tagsPath}`]: (_: URL, init?: RequestInit) => documentTags(sent(init).body.tagIds.includes(berlin.id) ? [berlin] : []),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Add Tag' }));
    const picker = await screen.findByRole('dialog');
    // The document's own tag is listed, switched on, before the list arrives; Done waits for it.
    expect(within(picker).getByRole('checkbox', { name: 'Berlin' })).toHaveProperty('checked', true);
    expect(within(picker).getByRole('button', { name: 'Done' })).toHaveProperty('disabled', true);
    release({ total: 2, items: [berlin, revisit] });
    await within(picker).findByRole('checkbox', { name: 'Revisit' });
    await waitFor(() => expect(within(picker).getByRole('button', { name: 'Done' })).toHaveProperty('disabled', false));
    await userEvent.click(within(picker).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(sent(fetch.mock.calls.find(([, init]) => init?.method === 'PUT')?.[1]).body).toEqual({ tagIds: [berlin.id] });
  });

  it('deletes a tag still being made when the picker is cancelled', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    const made: UserTag = { id: 'L0000000-0000-4000-8000-000000000000', name: 'Late' };
    let release: (tag: unknown) => void = () => {};
    const fetch = reader({
      [tagsPath]: documentTags([]),
      '/api/v1/me/tags': { total: 0, items: [] },
      'POST /api/v1/me/tags': () => new Promise((resolve) => (release = resolve)),
      [`DELETE /api/v1/me/tags/${made.id}`]: null,
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Add Tag' }));
    const picker = await screen.findByRole('dialog');
    await userEvent.type(within(picker).getByRole('textbox', { name: 'New tag name' }), 'Late{Enter}');
    await userEvent.click(within(picker).getByRole('button', { name: 'Cancel' }));
    expect(screen.getByRole('dialog')).toBeTruthy();
    release(made);
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.some(([url, init]) => init?.method === 'DELETE' && String(url).endsWith(`/api/v1/me/tags/${made.id}`))).toBe(true);
  });

  it('asks for a new token and sends the change once more when the server no longer knows the one it has', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    let tokens = 0;
    const fetch = reader({
      '/api/v1/me': () => ({ ...me, csrfToken: `token-${++tokens}` }),
      [tagsPath]: documentTags([berlin]),
      [`DELETE ${tagsPath}/${berlin.id}`]: (_: URL, init?: RequestInit) =>
        sent(init).token === 'token-2' ? documentTags([]) : new ProblemAnswer(403, 'CSRF_TOKEN_INVALID', 'No longer current.'),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Remove Berlin' }));
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Remove Berlin' })).toBeNull());
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'DELETE').map(([, init]) => sent(init).token)).toEqual(['token-1', 'token-2']);
    expect(screen.queryByRole('alert')).toBeNull();
  });
});

const highlightsPath = '/api/v1/me/volumes/frus1961-63v06/documents/d1/highlights';

function highlight(fields: Partial<Highlight> & Pick<Highlight, 'id'>): Highlight {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    startOffset: 12,
    endOffset: 40,
    colorTag: 'yellow',
    selectedText: 'Allow me to say',
    renderingVersion: 'v1',
    createdAt: '2026-10-20T09:00:00Z',
    ...fields,
  };
}

function documentHighlights(items: Highlight[]): DocumentHighlights {
  return { volumeId: 'frus1961-63v06', documentId: 'd1', renderingVersion: 'v1', items };
}

/** The row of the highlight whose words are `text`, or Highlighted passage. */
const row = (text: string) => screen.getByText(text).closest('li')!;
const removeIn = (text: string) => within(row(text)).getByRole('button', { name: 'Remove…' });

describe('the Research rail’s Highlights', () => {
  it('is a section above Tags, closed until it is opened, with the document’s count, and then as it was left', async () => {
    reader({
      [highlightsPath]: documentHighlights([highlight({ id: 'A' }), highlight({ id: 'B', startOffset: 50, selectedText: 'the Embassy' })]),
      [tagsPath]: documentTags([berlin]),
    });
    renderAt('/doc/frus1961-63v06/d1');
    await userEvent.click(await screen.findByRole('button', { name: 'Research' }));
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    const section = await within(rail).findByRole('button', { name: 'Highlights, 2 highlights' });
    await within(rail).findByRole('button', { name: 'Tags, 1 tag' });
    expect(within(rail).getAllByRole('button', { expanded: false }).map((button) => button.getAttribute('aria-label'))).toEqual([
      'Highlights, 2 highlights',
      'Tags, 1 tag',
    ]);
    expect(within(rail).queryByRole('button', { name: 'Remove…' })).toBeNull();
    await userEvent.click(section);
    expect(section.getAttribute('aria-expanded')).toBe('true');
    expect(section.getAttribute('aria-controls')).toBe('research-highlights');
    expect(within(rail).getAllByRole('button', { name: 'Remove…' })).toHaveLength(2);
    expect(window.localStorage.getItem('frus.research.highlights')).toBe('open');

    // Closed and opened again, the rail keeps the section open.
    await userEvent.click(within(rail).getByRole('button', { name: 'Close' }));
    await userEvent.click(screen.getByRole('button', { name: 'Research' }));
    const again = await screen.findByRole('complementary', { name: 'Research' });
    expect(within(again).getByRole('button', { name: 'Highlights, 2 highlights' }).getAttribute('aria-expanded')).toBe('true');
    await userEvent.click(within(again).getByRole('button', { name: 'Highlights, 2 highlights' }));
    expect(window.localStorage.getItem('frus.research.highlights')).toBe('closed');
  });

  it('counts one highlight as one, and names the section alone when there are none', async () => {
    reader({ [highlightsPath]: documentHighlights([highlight({ id: 'A' })]) });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    expect(await screen.findByRole('button', { name: 'Highlights, 1 highlight' })).toBeTruthy();
    cleanup();
    resetPreferences();
    reader({ [highlightsPath]: documentHighlights([]) });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    await waitFor(() => expect(within(rail).getByRole('button', { name: 'Highlights' }).hasAttribute('aria-label')).toBe(false));
    expect(within(rail).getByRole('button', { name: 'Highlights' }).querySelector('.badge')).toBeNull();
  });

  it('says why the highlights could not be read', async () => {
    window.localStorage.setItem('frus.research.highlights', 'open');
    reader({ [highlightsPath]: new ProblemAnswer(503, 'USER_DATA_UNAVAILABLE', 'The research data could not be read.') });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    expect((await within(rail).findByRole('alert')).textContent).toBe('The research data could not be read.');
  });

  it('lists the rows as the app’s review sheet does, with their words or Highlighted passage, the stale lines, and the line for one the page could not draw', async () => {
    window.localStorage.setItem('frus.research.highlights', 'open');
    // In the server's order, the order the page draws them in.
    const items = [
      highlight({ id: 'C', startOffset: 50, endOffset: 61, selectedText: 'the Embassy', isStale: true }),
      highlight({ id: 'A', startOffset: 12, createdAt: '2026-10-21T09:00:00Z' }),
      highlight({ id: 'B', startOffset: 12, createdAt: '2026-10-19T09:00:00Z', selectedText: '', isStale: true }),
      highlight({ id: 'D', startOffset: 70, endOffset: 80, selectedText: 'in Moscow' }),
    ];
    reader({ [highlightsPath]: documentHighlights(items) });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    await within(rail).findAllByRole('listitem');
    const rows = () =>
      within(rail)
        .getAllByRole('listitem')
        .map((item) => [...item.querySelectorAll('p')].map((line) => line.textContent));
    expect(rows()).toEqual([
      [
        'Highlighted passage',
        'Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye.',
      ],
      ['Allow me to say'],
      ['the Embassy', 'Made against an earlier version of the text — its position may have moved.'],
      ['in Moscow'],
    ]);
    expect(row('Highlighted passage').querySelector('.highlight-text em')?.textContent).toBe('Highlighted passage');

    // The page reports that it could not draw the fourth it was sent.
    const frame = screen.getByTitle('Document text: 1. Telegram From the Embassy in the Soviet Union') as HTMLIFrameElement;
    const post = vi.spyOn(frame.contentWindow!, 'postMessage');
    fireEvent.load(frame);
    await waitFor(() => expect(post).toHaveBeenCalled());
    act(() => {
      const data = { source: 'frus-reader', kind: 'highlightsRendered', detail: { drawn: 3, skipped: [3] } };
      window.dispatchEvent(new MessageEvent('message', { data, origin: 'null', source: frame.contentWindow }));
    });
    expect(rows()[3]).toEqual(['in Moscow', 'This highlight could not be drawn in the text.']);
    expect(rows().slice(0, 3).flat()).not.toContain('This highlight could not be drawn in the text.');
  });

  it('changes a highlight’s colour from its Color group, which shows the colour it has and is held while the change is sent', async () => {
    window.localStorage.setItem('frus.research.highlights', 'open');
    let items = [highlight({ id: 'A' })];
    let release: () => void = () => {};
    const fetch = reader({
      [highlightsPath]: () => documentHighlights(items),
      'PATCH /api/v1/me/highlights/A': (_: URL, init?: RequestInit) => {
        const colorTag = sent(init).body.colorTag as string;
        if (colorTag === 'blue') return new ProblemAnswer(404, 'NOT_FOUND', 'No highlight A.');
        return new Promise((resolve) => {
          release = () => {
            items = [{ ...items[0]!, colorTag }];
            resolve(items[0]);
          };
        });
      },
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByText('Allow me to say');
    const colors = within(row('Allow me to say')).getByRole('group', { name: 'Color' });
    const pressed = () => within(colors).getAllByRole('button').filter((button) => button.getAttribute('aria-pressed') === 'true').map((button) => button.textContent);
    expect(within(colors).getAllByRole('button').map((button) => button.textContent)).toEqual(['Yellow', 'Green', 'Blue', 'Pink']);
    expect(pressed()).toEqual(['Yellow']);

    // Its own colour again sends nothing.
    await userEvent.click(within(colors).getByRole('button', { name: 'Yellow' }));
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(false);

    await userEvent.click(within(colors).getByRole('button', { name: 'Green' }));
    // Held, but focusable still, so the button pressed by keyboard keeps its focus.
    await waitFor(() => expect(within(colors).getAllByRole('button').every((button) => button.getAttribute('aria-disabled') === 'true')).toBe(true));
    expect(within(colors).getAllByRole('button').some((button) => (button as HTMLButtonElement).disabled)).toBe(false);
    release();
    await waitFor(() => expect(pressed()).toEqual(['Green']));
    expect(within(colors).getAllByRole('button').some((button) => button.getAttribute('aria-disabled') === 'true')).toBe(false);
    const patches = fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH');
    expect(patches.map(([url, init]) => [String(url), sent(init)])).toEqual([
      ['/api/v1/me/highlights/A', { body: { colorTag: 'green' }, token: 'token-1', type: 'application/json' }],
    ]);

    // A refusal is said, and the colour stays.
    await userEvent.click(within(colors).getByRole('button', { name: 'Blue' }));
    expect((await screen.findByRole('alert')).textContent).toBe('No highlight A.');
    expect(pressed()).toEqual(['Green']);
  });

  it('changes another row’s colour while one row’s change is still being sent', async () => {
    window.localStorage.setItem('frus.research.highlights', 'open');
    const fetch = reader({
      [highlightsPath]: documentHighlights([highlight({ id: 'A' }), highlight({ id: 'B', startOffset: 50, endOffset: 64, selectedText: 'the Embassy' })]),
      'PATCH /api/v1/me/highlights/A': () => new Promise(() => {}),
      'PATCH /api/v1/me/highlights/B': (_: URL, init?: RequestInit) => highlight({ id: 'B', colorTag: sent(init).body.colorTag as string }),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByText('Allow me to say');
    await userEvent.click(within(row('Allow me to say')).getByRole('button', { name: 'Green' }));
    const second = within(row('the Embassy')).getByRole('button', { name: 'Pink' });
    expect(second.getAttribute('aria-disabled')).toBe('false');
    await userEvent.click(second);
    await waitFor(() =>
      expect(fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([url]) => String(url))).toEqual([
        '/api/v1/me/highlights/A',
        '/api/v1/me/highlights/B',
      ]),
    );
  });

  it('asks before it removes a highlight from Remove…, Cancel first, and focus goes to the next row’s Remove…, else the one before, else the section', async () => {
    window.localStorage.setItem('frus.research.highlights', 'open');
    let items = [
      highlight({ id: 'A', startOffset: 12, selectedText: 'Allow me' }),
      highlight({ id: 'B', startOffset: 30, selectedText: 'to say' }),
      highlight({ id: 'C', startOffset: 50, selectedText: 'the Embassy' }),
    ];
    const removal = (id: string) => () => {
      items = items.filter((item) => item.id !== id);
      return null;
    };
    const fetch = reader({
      [highlightsPath]: () => documentHighlights(items),
      'DELETE /api/v1/me/highlights/A': removal('A'),
      'DELETE /api/v1/me/highlights/B': removal('B'),
      'DELETE /api/v1/me/highlights/C': removal('C'),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByText('to say');

    async function remove(text: string) {
      await userEvent.click(removeIn(text));
      const question = await screen.findByRole('alertdialog', { name: 'Remove Highlight' });
      expect(within(question).getByText('This highlight will be permanently removed.')).toBeTruthy();
      expect(document.activeElement).toBe(within(question).getByRole('button', { name: 'Cancel' }));
      await userEvent.click(within(question).getByRole('button', { name: 'Remove' }));
      await waitFor(() => expect(screen.queryByText(text)).toBeNull());
      expect(screen.queryByRole('alertdialog')).toBeNull();
    }

    // The middle one: focus goes to the row that took its place.
    await remove('to say');
    await waitFor(() => expect(document.activeElement).toBe(removeIn('the Embassy')));
    // The last one: focus goes to the row before it.
    await remove('the Embassy');
    await waitFor(() => expect(document.activeElement).toBe(removeIn('Allow me')));
    // The only one: focus goes to the section's disclosure.
    await remove('Allow me');
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Highlights' })));
    expect(screen.queryByRole('list')).toBeNull();
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'DELETE').map(([url, init]) => [String(url), sent(init).token])).toEqual([
      ['/api/v1/me/highlights/B', 'token-1'],
      ['/api/v1/me/highlights/C', 'token-1'],
      ['/api/v1/me/highlights/A', 'token-1'],
    ]);
  });

  it('passes over the removed row’s own Remove… when a frame comes before the rows are drawn again', async () => {
    window.localStorage.setItem('frus.research.highlights', 'open');
    let items = [highlight({ id: 'A', startOffset: 12, selectedText: 'Allow me' }), highlight({ id: 'B', startOffset: 30, selectedText: 'to say' })];
    reader({
      [highlightsPath]: () => documentHighlights(items),
      'DELETE /api/v1/me/highlights/A': () => {
        items = items.filter((item) => item.id !== 'A');
        return null;
      },
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByText('Allow me');
    await userEvent.click(removeIn('Allow me'));
    const question = await screen.findByRole('alertdialog', { name: 'Remove Highlight' });
    // The next frame before React draws the rows again, as a browser's can come.
    vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback) => {
      queueMicrotask(() => callback(0));
      return 0;
    });
    await userEvent.click(within(question).getByRole('button', { name: 'Remove' }));
    await waitFor(() => expect(screen.queryByText('Allow me')).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(removeIn('to say')));
  });

  it('cancels the question by Cancel or by Escape, which leaves the rail open, and focus goes back to the Remove… that asked', async () => {
    window.localStorage.setItem('frus.research.highlights', 'open');
    const fetch = reader({
      [highlightsPath]: documentHighlights([
        highlight({ id: 'A', startOffset: 12, selectedText: 'Allow me' }),
        highlight({ id: 'B', startOffset: 30, selectedText: 'to say' }),
      ]),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByText('to say');

    await userEvent.click(removeIn('to say'));
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Cancel' }));
    expect(screen.queryByRole('alertdialog')).toBeNull();
    await waitFor(() => expect(document.activeElement).toBe(removeIn('to say')));

    await userEvent.click(removeIn('to say'));
    const question = await screen.findByRole('alertdialog', { name: 'Remove Highlight' });
    // The keydown goes no further than the dialog: the rail, which closes on Escape, stays.
    await userEvent.keyboard('{Escape}');
    expect(screen.getByRole('complementary', { name: 'Research' })).toBeTruthy();
    // Escape, as the browser then sends it to the dialog on top.
    fireEvent(question, new Event('cancel', { cancelable: true }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(screen.getByRole('complementary', { name: 'Research' })).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(removeIn('to say')));
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(false);

    // Escape outside a question still closes the rail.
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByRole('complementary', { name: 'Research' })).toBeNull();
  });
});
