import { act, cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail, DocumentHighlights, Highlight, Me, ReaderLinkTarget, Volume } from '../api/types';
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

beforeEach(() => {
  resetPreferences();
  window.localStorage.removeItem('frus.readingWidth');
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('ReaderScreen', () => {
  it('offers the app’s Reading Width beside Text Size, Standard at first, and loads the page at the width chosen', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
      // The page itself, which the reader checks before the frame loads it.
      '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    });
    renderAt('/doc/frus1961-63v06/d1');
    const toolbar = await screen.findByRole('group', { name: 'Document' });
    const controls = within(toolbar).getAllByRole('combobox');
    expect(controls.map((control) => control.closest('label')?.firstChild?.textContent?.trim())).toEqual(['Text Size', 'Reading Width']);
    const width = within(toolbar).getByRole('combobox', { name: 'Reading Width' }) as HTMLSelectElement;
    expect([...width.options].map((option) => [option.value, option.textContent])).toEqual([
      ['narrow', 'Narrow'],
      ['standard', 'Standard'],
      ['wide', 'Wide'],
    ]);
    expect(width.value).toBe('standard');
    const frame = () => screen.getByTitle('Document text: 1. Telegram From the Embassy in the Soviet Union');
    await waitFor(() => expect(frame().getAttribute('src')).toContain('readingWidth=standard'));

    await userEvent.selectOptions(width, 'wide');
    await waitFor(() => expect(frame().getAttribute('src')).toContain('readingWidth=wide'));
    expect(frame().getAttribute('src')).toContain('textSize=medium');
    // The choice outlasts the page, as Text Size does.
    expect(window.localStorage.getItem('frus.readingWidth')).toBe('wide');
  });

  it('opens the volume a page link names in Browse, where the kit’s PageLink sends it, and the visit names the page', async () => {
    const v14: Volume = {
      volumeId: 'frus1961-63v14',
      filename: 'frus1961-63v14.xml',
      subseries: '1961-63',
      title: 'Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962',
      dateRange: {},
      status: 'published',
      editors: [],
      sizeBytes: 1,
      tags: [],
      indexed: false,
      indexedDocuments: 0,
      teiAvailable: false,
    };
    // A page the bundled page map names no document on, of a volume this server does not hold.
    const href = 'frusexplorer://doc/frus1961-63v14%23pg_859/frus1961-63v14';
    const link: ReaderLinkTarget = {
      kind: 'page',
      href,
      target: 'frus1961-63v14#pg_859',
      page: 859,
      pageVolumeId: 'frus1961-63v14',
      volumeId: 'frus1961-63v14',
      wholeVolumeLink: 'browse',
      volume: { title: v14.title, teiAvailable: false, indexed: false },
      url: 'https://history.state.gov/historicaldocuments/frus1961-63v14',
    };
    const v15: Volume = { ...v14, volumeId: 'frus1961-63v15', title: 'Volume XV', teiAvailable: true };
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
      '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
      '/api/v1/volumes/frus1961-63v06/documents/d1/link': link,
      '/api/v1/volumes/frus1961-63v14': v14,
      '/api/v1/volumes/frus1961-63v15': v15,
    });
    const { router } = renderAt('/doc/frus1961-63v06/d1');
    const frame = (await screen.findByTitle('Document text: 1. Telegram From the Embassy in the Soviet Union')) as HTMLIFrameElement;
    // The page's host script posts the link, from the frame's window.
    const posted = { source: 'frus-reader', kind: 'link', detail: { href } };
    window.dispatchEvent(new MessageEvent('message', { data: posted, origin: 'null', source: frame.contentWindow }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/browse/frus1961-63v14'));
    expect(await screen.findByText('You followed a link to page 859 of this volume, which isn’t on this server.')).toBeTruthy();

    // A visit by any other route names no page.
    await router.navigate({ to: '/browse/$volumeId', params: { volumeId: 'frus1961-63v14' } });
    await screen.findByText('Its TEI isn’t on this server, so its documents can’t be read here.');
    expect(screen.queryByText(/You followed a link/)).toBeNull();

    // A volume whose TEI is here, unindexed, is opened for the same reason, which the line gives.
    await router.navigate({ to: '/browse/$volumeId', params: { volumeId: 'frus1961-63v15' }, state: { followedPage: 539 } });
    expect(await screen.findByText('You followed a link to page 539 of this volume, which this server hasn’t indexed.')).toBeTruthy();
  });
});

const me: Me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 'token-1' };
const highlightsPath = '/api/v1/me/volumes/frus1961-63v06/documents/d1/highlights';
const frameTitle = 'Document text: 1. Telegram From the Embassy in the Soviet Union';
const rect = { x: 200, y: 100, w: 100, h: 20 };

function highlight(fields: Partial<Highlight> & Pick<Highlight, 'id'>): Highlight {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    startOffset: 12,
    endOffset: 40,
    colorTag: 'green',
    selectedText: 'Allow me to say',
    renderingVersion: 'list-v1',
    createdAt: '2026-10-20T09:00:00Z',
    ...fields,
  };
}

/** The server's list of the document's highlights, which a test changes as the server would. */
function documentHighlights(items: Highlight[]): DocumentHighlights {
  return { volumeId: 'frus1961-63v06', documentId: 'd1', renderingVersion: 'list-v1', items };
}

/**
 * The reader's answers on a server that keeps user data; with `pageVersion`, the page check answers
 * with it as the kit's rendering version, in X-FRUS-Rendering-Version, as the server's page does.
 */
function highlighting(answers: Record<string, unknown>, pageVersion?: () => string) {
  const fetch = stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
    '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    '/api/v1/me': me,
    ...answers,
  });
  const answer = fetch.getMockImplementation()!;
  fetch.mockImplementation(async (input: string, init?: RequestInit) => {
    const response = await answer(input, init);
    if (pageVersion && new URL(input, 'http://localhost').pathname.endsWith('/html')) response.headers.set('X-FRUS-Rendering-Version', pageVersion());
    return response;
  });
  return fetch;
}

/** What a change sent: its body as JSON, and its token. */
function sent(init?: RequestInit) {
  const headers = init?.headers as Record<string, string>;
  return { body: init?.body ? JSON.parse(String(init.body)) : undefined, token: headers['X-CSRF-Token'] };
}

/** The frame, loaded, with what the app posts to its window recorded from before it loaded. */
async function loadedFrame() {
  const frame = (await screen.findByTitle(frameTitle)) as HTMLIFrameElement;
  const post = vi.spyOn(frame.contentWindow!, 'postMessage');
  fireEvent.load(frame);
  return { frame, post, posted: () => post.mock.calls.map(([message]) => message as Record<string, unknown>) };
}

/** A message from the page's host script, posted from the frame's window. */
function fromFrame(frame: HTMLIFrameElement, kind: string, detail: unknown = {}) {
  act(() => {
    window.dispatchEvent(new MessageEvent('message', { data: { source: 'frus-reader', kind, detail }, origin: 'null', source: frame.contentWindow }));
  });
}

const pause = (ms: number) => act(() => new Promise<void>((resolve) => setTimeout(resolve, ms)));

const creates = (fetch: ReturnType<typeof stubServer>) =>
  fetch.mock.calls.filter(([url, init]) => init?.method === 'POST' && String(url).endsWith(highlightsPath)).map(([, init]) => sent(init));

const highlightsSent = (posted: () => Record<string, unknown>[]) => posted().filter((message) => message.kind === 'highlights');

const bar = () => screen.queryByRole('toolbar', { name: 'Selection' });

describe('the reader’s highlights', () => {
  it('draws the document’s highlights in the frame once its page has loaded, each stale or not as the server says', async () => {
    const fetch = highlighting({
      [highlightsPath]: documentHighlights([
        highlight({ id: 'L', startOffset: 12, endOffset: 40, colorTag: 'green' }),
        highlight({ id: 'S', startOffset: 50, endOffset: 64, colorTag: 'yellow', isStale: true }),
      ]),
    });
    renderAt('/doc/frus1961-63v06/d1');
    const frame = (await screen.findByTitle(frameTitle)) as HTMLIFrameElement;
    const post = vi.spyOn(frame.contentWindow!, 'postMessage');
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).endsWith(highlightsPath))).toBe(true));
    await pause(20);
    // Not before the page has loaded: its scripts would not be there to draw them.
    expect(post).not.toHaveBeenCalled();
    fireEvent.load(frame);
    expect(post).toHaveBeenCalledWith(
      {
        source: 'frus-app',
        kind: 'highlights',
        highlights: [
          { startOffset: 12, endOffset: 40, color: 'green', isStale: false },
          { startOffset: 50, endOffset: 64, color: 'yellow', isStale: true },
        ],
      },
      '*',
    );
  });

  // A second load of the same page, as Reload Frame gives, is drawn on too.
  it('draws them again each time the same page loads again', async () => {
    highlighting({ [highlightsPath]: documentHighlights([highlight({ id: 'L' })]) });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fireEvent.load(frame);
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(2), { timeout: 200 });
  });

  // Back at a page's address before the other page came, the new frame is drawn into once its page
  // has loaded, not before.
  it('draws them in a page loaded again after the text size changes back before the other page came', async () => {
    highlighting({
      [highlightsPath]: documentHighlights([highlight({ id: 'L' })]),
      '/api/v1/volumes/frus1961-63v06/documents/d1/html': (url: URL) => (url.searchParams.get('textSize') === 'large' ? new Promise(() => {}) : {}),
    });
    renderAt('/doc/frus1961-63v06/d1');
    const { posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    const size = screen.getByRole('combobox', { name: 'Text Size' });
    await userEvent.selectOptions(size, 'large');
    await waitFor(() => expect(screen.queryByTitle(frameTitle)).toBeNull());
    await userEvent.selectOptions(size, 'medium');
    const again = await loadedFrame();
    await waitFor(() => expect(highlightsSent(again.posted)).toHaveLength(1), { timeout: 200 });
  });

  it('asks for no highlights, and offers no bar, on a server that keeps no user data', async () => {
    const fetch = highlighting({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => url === '/api/v1/me')).toBe(true));
    await pause(20);
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    fromFrame(frame, 'highlightShortcut', { start: 12, end: 40, rect });
    await pause(20);
    expect(bar()).toBeNull();
    expect(posted()).toEqual([]);
    expect(fetch.mock.calls.some(([url]) => String(url).includes('/highlights'))).toBe(false);
  });

  it('asks before it removes a tapped highlight, Cancel first, and removes the one the kit’s listener took', async () => {
    let items = [
      highlight({ id: 'S', isStale: true }),
      highlight({ id: 'P', colorTag: 'pink' }),
      highlight({ id: 'L' }),
      highlight({ id: 'T' }),
    ];
    const fetch = highlighting({
      [highlightsPath]: () => documentHighlights(items),
      'DELETE /api/v1/me/highlights/L': () => {
        items = items.filter((item) => item.id !== 'L');
        return null;
      },
    });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));

    // A tap the frame's highlights do not account for asks nothing.
    fromFrame(frame, 'highlightTapped', { startOffset: 12, endOffset: 40, color: 'blue' });
    await pause(20);
    expect(screen.queryByRole('alertdialog')).toBeNull();

    fromFrame(frame, 'highlightTapped', { startOffset: 12, endOffset: 40, color: 'green' });
    const question = await screen.findByRole('alertdialog', { name: 'Remove Highlight' });
    expect(within(question).getByText('This highlight will be permanently removed.').id).toBe(question.getAttribute('aria-describedby'));
    expect(document.activeElement).toBe(within(question).getByRole('button', { name: 'Cancel' }));
    await userEvent.click(within(question).getByRole('button', { name: 'Cancel' }));
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(false);

    fromFrame(frame, 'highlightTapped', { startOffset: 12, endOffset: 40, color: 'green' });
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Remove' }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    const deletes = fetch.mock.calls.filter(([, init]) => init?.method === 'DELETE');
    expect(deletes.map(([url]) => String(url))).toEqual(['/api/v1/me/highlights/L']);
    expect(sent(deletes[0]?.[1]).token).toBe('token-1');
    // The list is read again and drawn without it; focus goes back to the text.
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(2));
    expect((highlightsSent(posted)[1]?.highlights as { color: string }[]).map((drawn) => drawn.color)).toEqual(['green', 'pink', 'green']);
    await waitFor(() => expect(document.activeElement).toBe(frame));
  });

  it('makes a yellow highlight at once from ⇧⌘H in the frame, in the page’s rendering version, and collapses the selection', async () => {
    let items: Highlight[] = [];
    const fetch = highlighting(
      {
        [highlightsPath]: () => documentHighlights(items),
        [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) => {
          const made = highlight({ id: 'N', ...sent(init).body, renderingVersion: 'page-v2' });
          items = [made];
          return made;
        },
      },
      () => 'page-v2',
    );
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'highlightShortcut', { start: 12, end: 40, rect });
    await waitFor(() => expect(posted()).toContainEqual({ source: 'frus-app', kind: 'collapseSelection' }));
    expect(creates(fetch)).toEqual([
      { body: { startOffset: 12, endOffset: 40, colorTag: 'yellow', renderingVersion: 'page-v2' }, token: 'token-1' },
    ]);
    // The new highlight is drawn, and focus is in the text.
    await waitFor(() => expect(highlightsSent(posted).at(-1)?.highlights).toEqual([{ startOffset: 12, endOffset: 40, color: 'yellow', isStale: false }]));
    await waitFor(() => expect(document.activeElement).toBe(frame));
    expect(bar()).toBeNull();
  });

  it('shows the bar for a selection in the text, which makes the colour chosen in the list’s version when the page names none, and then lets the selection go', async () => {
    const fetch = highlighting({
      [highlightsPath]: documentHighlights([]),
      [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) => highlight({ id: 'N', ...sent(init).body }),
    });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    // No bar for a selection whose rectangle the bridge could not measure.
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say' });
    expect(bar()).toBeNull();
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    expect(bar()).not.toBeNull();
    // Shown by the pointer, it leaves focus where it was.
    expect(bar()?.contains(document.activeElement)).toBe(false);
    await userEvent.click(screen.getByRole('button', { name: 'Highlight Pink' }));
    await waitFor(() => expect(posted()).toContainEqual({ source: 'frus-app', kind: 'collapseSelection' }));
    expect(creates(fetch)).toEqual([{ body: { startOffset: 12, endOffset: 40, colorTag: 'pink', renderingVersion: 'list-v1' }, token: 'token-1' }]);
    expect(bar()).toBeNull();
    // The selection's offsets are gone with it: ⇧⌘H around the frame makes nothing more.
    await userEvent.keyboard('{Meta>}{Shift>}h{/Shift}{/Meta}');
    await pause(20);
    expect(creates(fetch)).toHaveLength(1);
  });

  it('offers Note alone for a footnote’s selection, and keeps a bar through a clear shorter than 200 ms', async () => {
    const fetch = highlighting({
      [highlightsPath]: documentHighlights([]),
      [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) => highlight({ id: 'N', ...sent(init).body }),
    });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    const selectInText = () => fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    const clear = () => fromFrame(frame, 'selectionChanged', { start: -1, end: -1, text: '' });

    selectInText();
    expect(bar()).not.toBeNull();
    // A footnote's selection lets the one in the text go at once: its bar offers Note alone.
    fromFrame(frame, 'selectionChanged', { start: -1, end: -1, text: 'a note', rect });
    expect(within(bar()!).getAllByRole('button').map((button) => button.textContent)).toEqual(['Note']);
    // One with no rectangle to place a bar by shows none.
    fromFrame(frame, 'selectionChanged', { start: -1, end: -1, text: 'a note' });
    expect(bar()).toBeNull();
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await pause(20);
    expect(creates(fetch)).toEqual([]);

    // A clear followed by a new selection in the text within 200 ms keeps the bar.
    selectInText();
    clear();
    await pause(50);
    expect(bar()).not.toBeNull();
    fromFrame(frame, 'selectionChanged', { start: 14, end: 30, text: 'low me to', rect });
    await pause(250);
    expect(bar()).not.toBeNull();

    // A clear that lasts lets the selection go, and the shortcut then makes nothing.
    clear();
    await pause(250);
    expect(bar()).toBeNull();
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await pause(20);
    expect(creates(fetch)).toEqual([]);

    // Within the 200 ms the selection is still held, and the shortcut makes its highlight.
    selectInText();
    clear();
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await waitFor(() => expect(creates(fetch)).toHaveLength(1));
    expect(creates(fetch)[0]?.body).toEqual({ startOffset: 12, endOffset: 40, colorTag: 'yellow', renderingVersion: 'list-v1' });
  });

  it('opens the bar from Alt+F10 in the frame with its first dot focused, and puts it away on Escape or a scroll in the frame', async () => {
    highlighting({ [highlightsPath]: documentHighlights([]) });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'selectionBarShortcut', { start: 12, end: 40, rect });
    expect(bar()).not.toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Highlight Yellow' }));
    // Escape in the bar puts it away and goes back to the text.
    await userEvent.keyboard('{Escape}');
    expect(bar()).toBeNull();
    await waitFor(() => expect(document.activeElement).toBe(frame));

    fromFrame(frame, 'selectionBarShortcut', { start: 12, end: 40, rect });
    expect(bar()).not.toBeNull();
    fromFrame(frame, 'selectionEscape');
    expect(bar()).toBeNull();
    fromFrame(frame, 'selectionBarShortcut', { start: 12, end: 40, rect });
    fromFrame(frame, 'selectionScrolled');
    expect(bar()).toBeNull();
  });

  // Only the keyboard's request moves focus into the bar: a later selection's bar leaves it in the text.
  it('leaves focus in the text when a later selection shows the bar, after Alt+F10 has been used once', async () => {
    highlighting({ [highlightsPath]: documentHighlights([]) });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'selectionBarShortcut', { start: 12, end: 40, rect });
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Highlight Yellow' }));
    await userEvent.keyboard('{Escape}');
    await waitFor(() => expect(document.activeElement).toBe(frame));
    fromFrame(frame, 'selectionChanged', { start: 50, end: 64, text: 'the Embassy', rect });
    expect(bar()).not.toBeNull();
    expect(document.activeElement).toBe(frame);
  });

  it('acts on the shortcuts pressed around the frame over the selection it holds, but not in a field', async () => {
    const fetch = highlighting({
      [highlightsPath]: documentHighlights([]),
      [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) => highlight({ id: 'N', ...sent(init).body }),
    });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    // With nothing selected, Alt+F10 shows nothing.
    await userEvent.keyboard('{Alt>}{F10}{/Alt}');
    expect(bar()).toBeNull();

    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    // In a field the keys are the field's.
    act(() => screen.getByRole('combobox', { name: 'Text Size' }).focus());
    expect(bar()).toBeNull();
    await userEvent.keyboard('{Alt>}{F10}{/Alt}');
    expect(bar()).toBeNull();
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await pause(20);
    expect(creates(fetch)).toEqual([]);

    act(() => screen.getByRole('button', { name: 'Cite' }).focus());
    await userEvent.keyboard('{Alt>}{F10}{/Alt}');
    // The frame is asked where the selection is now, and answers as for the key pressed in it.
    expect(posted()).toContainEqual({ source: 'frus-app', kind: 'selectionBarRequest' });
    fromFrame(frame, 'selectionBarShortcut', { start: 12, end: 40, rect });
    expect(bar()).not.toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Highlight Yellow' }));
    act(() => screen.getByRole('button', { name: 'Cite' }).focus());
    // Focus elsewhere in the app puts the bar away, and keeps the selection.
    expect(bar()).toBeNull();
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await waitFor(() => expect(creates(fetch)).toHaveLength(1));
    expect(creates(fetch)[0]?.body).toEqual({ startOffset: 12, endOffset: 40, colorTag: 'yellow', renderingVersion: 'list-v1' });
  });

  it('says why a highlight could not be made in the reader’s notice, without collapsing the selection', async () => {
    const changed =
      "renderingVersion: the document's text has changed since the page was loaded, from page-v2 to page-v3. Load it again and select once more.";
    const refusals = [new ProblemAnswer(409, 'DOCUMENT_CHANGED', changed), new ProblemAnswer(400, 'INVALID_FIELD', 'endOffset: the document’s text has 30 characters, so a highlight ends at 30 at most, not 40.')];
    const fetch = highlighting(
      {
        [highlightsPath]: documentHighlights([]),
        [`POST ${highlightsPath}`]: () => refusals.shift(),
      },
      () => 'page-v2',
    );
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    const pageChecks = () => fetch.mock.calls.filter(([url]) => new URL(String(url), 'http://localhost').pathname.endsWith('/html')).length;
    expect(pageChecks()).toBe(1);
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    await userEvent.click(screen.getByRole('button', { name: 'Highlight Blue' }));
    const notice = await screen.findByText(changed);
    expect(notice.getAttribute('role')).toBe('status');
    expect(notice.className).toBe('notice');
    expect(posted()).not.toContainEqual({ source: 'frus-app', kind: 'collapseSelection' });
    // Nothing is asked again and nothing loads again: the page keeps its version until it is loaded
    // again, as the server's sentence asks.
    await pause(20);
    expect(pageChecks()).toBe(1);
    expect(screen.getByTitle(frameTitle)).toBe(frame);

    // Any other refusal is said too.
    fromFrame(frame, 'highlightShortcut', { start: 12, end: 40, rect });
    expect(await screen.findByText(/^endOffset: the document’s text has 30 characters/)).toBe(notice);
    await pause(20);
    expect(pageChecks()).toBe(1);
    expect(creates(fetch).map((made) => made.body.colorTag)).toEqual(['blue', 'yellow']);
    expect(posted()).not.toContainEqual({ source: 'frus-app', kind: 'collapseSelection' });
  });

  // After DOCUMENT_CHANGED the selection made in the old text is let go, and the page keeps its old
  // version, so the old text's offsets are never filed under the new one.
  it('makes no highlight in the new version of the text from a selection made in the old one', async () => {
    let version = 'page-v2';
    const fetch = highlighting(
      {
        [highlightsPath]: documentHighlights([]),
        [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) =>
          sent(init).body.renderingVersion === version
            ? highlight({ id: 'N', ...sent(init).body })
            : new ProblemAnswer(409, 'DOCUMENT_CHANGED', 'The document’s text has changed since the page was loaded.'),
      },
      () => version,
    );
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    // The document's TEI changes on the server after the page was loaded.
    version = 'page-v3';
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await screen.findByText('The document’s text has changed since the page was loaded.');
    await pause(20);
    expect(screen.getByTitle(frameTitle)).toBe(frame);
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await pause(50);
    expect(creates(fetch).map((made) => made.body.renderingVersion)).toEqual(['page-v2']);
  });

  it('holds Cancel and Escape while a removal is sent, and takes one removed elsewhere as removed', async () => {
    let items = [highlight({ id: 'L' })];
    let release: () => void = () => {};
    highlighting({
      [highlightsPath]: () => documentHighlights(items),
      // Removed in another tab: the server has none to remove.
      'DELETE /api/v1/me/highlights/L': () =>
        new Promise((resolve) => {
          release = () => {
            items = [];
            resolve(new ProblemAnswer(404, 'HIGHLIGHT_NOT_FOUND', 'You have no highlight with the id L.'));
          };
        }),
    });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'highlightTapped', { startOffset: 12, endOffset: 40, color: 'green' });
    const question = await screen.findByRole('alertdialog', { name: 'Remove Highlight' });
    const remove = within(question).getByRole('button', { name: 'Remove' });
    await userEvent.click(remove);
    // The pressed button keeps its focus, and Cancel and Escape wait for the removal.
    expect(remove.getAttribute('aria-disabled')).toBe('true');
    expect(document.activeElement).toBe(remove);
    await userEvent.click(within(question).getByRole('button', { name: 'Cancel' }));
    fireEvent(question, new Event('cancel', { cancelable: true }));
    expect(screen.getByRole('alertdialog', { name: 'Remove Highlight' })).toBe(question);
    release();
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(screen.queryByRole('alert')).toBeNull();
    await waitFor(() => expect(highlightsSent(posted).at(-1)?.highlights).toEqual([]));
  });

  it('gives focus back to the text when a colour from the bar could not be made', async () => {
    highlighting({
      [highlightsPath]: documentHighlights([]),
      [`POST ${highlightsPath}`]: new ProblemAnswer(503, 'SERVER_AWAY', 'The server is not answering.'),
    });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'selectionBarShortcut', { start: 12, end: 40, rect });
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Highlight Yellow' }));
    await userEvent.keyboard('{Enter}');
    await screen.findByText('The server is not answering.');
    await waitFor(() => expect(document.activeElement).toBe(frame));
  });

  it('asks the frame where the selection is for Alt+F10 around it once the frame has scrolled', async () => {
    highlighting({ [highlightsPath]: documentHighlights([]) });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    expect(bar()).not.toBeNull();
    fromFrame(frame, 'selectionScrolled');
    expect(bar()).toBeNull();
    act(() => screen.getByRole('button', { name: 'Cite' }).focus());
    await userEvent.keyboard('{Alt>}{F10}{/Alt}');
    // No bar at the old place: the frame is asked, and its answer places it.
    expect(bar()).toBeNull();
    expect(posted()).toContainEqual({ source: 'frus-app', kind: 'selectionBarRequest' });
    fromFrame(frame, 'selectionBarShortcut', { start: 12, end: 40, rect: { ...rect, y: 300 } });
    expect(bar()).not.toBeNull();
  });

  it('cancels the question a tap asks on Escape, and leaves the rail open', async () => {
    highlighting({ [highlightsPath]: documentHighlights([highlight({ id: 'L' })]) });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'highlightTapped', { startOffset: 12, endOffset: 40, color: 'green' });
    const question = await screen.findByRole('alertdialog', { name: 'Remove Highlight' });
    await userEvent.keyboard('{Escape}');
    // Escape, as the browser then sends it to the dialog on top.
    fireEvent(question, new Event('cancel', { cancelable: true }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(screen.getByRole('complementary', { name: 'Research' })).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(frame));
  });
});

const notesPath = '/api/v1/me/volumes/frus1961-63v06/documents/d1/notes';

/** The reader's answers with the note editor's lists: no tags, projects, summaries or notes. */
function noting(answers: Record<string, unknown>) {
  // The plain editor, so these tests need not load the formatting one.
  window.localStorage.setItem('frus.notes.editor.richText', 'false');
  return highlighting({
    '/api/v1/me/tags': { total: 0, items: [] },
    '/api/v1/me/projects': { total: 0, items: [] },
    '/api/v1/me/notes': { total: 0, items: [] },
    '/api/v1/me/volumes/frus1961-63v06/documents/d1/tags': { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    '/api/v1/me/volumes/frus1961-63v06/documents/d1/summaries': { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [notesPath]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [highlightsPath]: documentHighlights([]),
    ...answers,
  });
}

const madeNote = {
  id: 'N0000000-0000-4000-8000-000000000000',
  volumeId: 'frus1961-63v06',
  documentId: 'd1',
  bodyText: '',
  projectIds: [],
  userTagIds: [],
  selectedSummaryIds: [],
  linkedHighlightIds: [],
  createdAt: null,
  lastModified: null,
  runs: null,
  formattingKept: false,
};

const noteCreates = (fetch: ReturnType<typeof stubServer>) =>
  fetch.mock.calls.filter(([url, init]) => init?.method === 'POST' && String(url).endsWith(notesPath)).map(([, init]) => sent(init).body);

describe('the reader’s notes', () => {
  it('opens a new note on the document from the bar’s Note, for a selection in the text or a footnote’s, and lets the selection go', async () => {
    const fetch = noting({ [`POST ${notesPath}`]: madeNote });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    const buttons = within(bar()!).getAllByRole('button');
    expect(buttons.map((button) => button.getAttribute('aria-label') ?? button.textContent)).toEqual([
      'Highlight Yellow',
      'Highlight Green',
      'Highlight Blue',
      'Highlight Pink',
      'Note',
    ]);
    await userEvent.click(within(bar()!).getByRole('button', { name: 'Note' }));
    const editor = await screen.findByRole('dialog', { name: 'New Research Note' });
    expect(bar()).toBeNull();
    expect(posted()).toContainEqual({ source: 'frus-app', kind: 'collapseSelection' });
    // The selection is gone: ⇧⌘H makes nothing, behind the editor or after it.
    await userEvent.type(within(editor).getByRole('textbox', { name: 'Research note body' }), 'About the telegram');
    await userEvent.click(within(editor).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(frame));
    // A note on the document: no quote of the selection, and no highlight named.
    expect(noteCreates(fetch)).toEqual([{ bodyText: 'About the telegram', runs: null, userTagIds: [], projectIds: [], selectedSummaryIds: [] }]);
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await pause(20);
    expect(creates(fetch)).toEqual([]);

    // A footnote's selection offers Note alone, which opens the same editor.
    fromFrame(frame, 'selectionChanged', { start: -1, end: -1, text: 'a note', rect });
    await userEvent.click(within(bar()!).getByRole('button', { name: 'Note' }));
    expect(await screen.findByRole('dialog', { name: 'New Research Note' })).toBeTruthy();
  });

  it('leaves the reader’s shortcuts alone while the note editor is open over it', async () => {
    const fetch = noting({ [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) => highlight({ id: 'N', ...sent(init).body }) });
    renderAt('/doc/frus1961-63v06/d1');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say', rect });
    await userEvent.click(within(bar()!).getByRole('button', { name: 'Note' }));
    const editor = await screen.findByRole('dialog', { name: 'New Research Note' });
    // A selection the frame still reported, as it might, with focus on the editor's Save.
    fromFrame(frame, 'selectionChanged', { start: 12, end: 40, text: 'Allow me to say' });
    act(() => within(editor).getByRole('button', { name: 'Save' }).focus());
    await userEvent.keyboard('{Control>}{Shift>}H{/Shift}{/Control}');
    await userEvent.keyboard('{Alt>}{F10}{/Alt}');
    await pause(20);
    expect(creates(fetch)).toEqual([]);
    expect(posted()).not.toContainEqual({ source: 'frus-app', kind: 'selectionBarRequest' });
  });

  it('offers Add Note to Highlight in the rail after a highlight is made, until it is chosen, and the note links it', async () => {
    let items: Highlight[] = [];
    const fetch = noting({
      [highlightsPath]: () => documentHighlights(items),
      [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) => {
        const made = highlight({ id: 'H0000000-0000-4000-8000-000000000000', ...sent(init).body });
        items = [made];
        return made;
      },
      [`POST ${notesPath}`]: madeNote,
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    const rail = screen.getByRole('complementary', { name: 'Research' });
    await within(rail).findByRole('button', { name: 'Add Note' });
    expect(within(rail).queryByRole('button', { name: 'Add Note to Highlight' })).toBeNull();
    fromFrame(frame, 'highlightShortcut', { start: 12, end: 40, rect });
    const toHighlight = await within(rail).findByRole('button', { name: 'Add Note to Highlight' });
    // Above Add Note, as the app's.
    const actions = within(rail.querySelector('.note-actions') as HTMLElement).getAllByRole('button');
    expect(actions.map((button) => button.textContent?.replace('+ ', ''))).toEqual(['Add Note to Highlight', 'Add Note']);
    await userEvent.click(toHighlight);
    const editor = await screen.findByRole('dialog', { name: 'New Research Note' });
    // Chosen, it is pending no more, saved or not, as the app's.
    expect(within(rail).queryByRole('button', { name: 'Add Note to Highlight' })).toBeNull();
    await userEvent.click(within(editor).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(noteCreates(fetch)).toHaveLength(1));
    expect(noteCreates(fetch)[0]).toEqual({
      bodyText: '',
      runs: null,
      userTagIds: [],
      projectIds: [],
      selectedSummaryIds: [],
      linkedHighlightId: 'H0000000-0000-4000-8000-000000000000',
    });
  });

  it('lets a pending highlight go on another document, and keeps it through another text size', async () => {
    noting({
      [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) => highlight({ id: 'H1', ...sent(init).body }),
      '/api/v1/volumes/frus1961-63v06/documents/d2': { ...d1, document: { ...d1.document, documentId: 'd2', header: '2. Memo', displayTitle: '2. Memo' } },
      '/api/v1/volumes/frus1961-63v06/documents/d2/html': {},
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/highlights': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/notes': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/summaries': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/tags': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
    });
    const { router } = renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { frame } = await loadedFrame();
    fromFrame(frame, 'highlightShortcut', { start: 12, end: 40, rect });
    const rail = screen.getByRole('complementary', { name: 'Research' });
    await within(rail).findByRole('button', { name: 'Add Note to Highlight' });
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Text Size' }), 'large');
    await loadedFrame();
    expect(within(screen.getByRole('complementary', { name: 'Research' })).getByRole('button', { name: 'Add Note to Highlight' })).toBeTruthy();
    await router.navigate({ to: '/doc/$volumeId/$documentId', params: { volumeId: 'frus1961-63v06', documentId: 'd2' }, search: { rail: 'research' } });
    await screen.findByRole('heading', { level: 1, name: '2. Memo' });
    await within(screen.getByRole('complementary', { name: 'Research' })).findByRole('button', { name: 'Add Note' });
    expect(screen.queryByRole('button', { name: 'Add Note to Highlight' })).toBeNull();
  });

  it('never offers on another document a highlight whose request came back after the move to it', async () => {
    let answer: () => void = () => {};
    const fetch = noting({
      [`POST ${highlightsPath}`]: (_: URL, init?: RequestInit) =>
        new Promise((resolve) => (answer = () => resolve(highlight({ id: 'H0000000-0000-4000-8000-000000000000', ...sent(init).body })))),
      '/api/v1/volumes/frus1961-63v06/documents/d2': { ...d1, document: { ...d1.document, documentId: 'd2', header: '2. Memo', displayTitle: '2. Memo' } },
      '/api/v1/volumes/frus1961-63v06/documents/d2/html': {},
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/highlights': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/notes': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/summaries': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      '/api/v1/me/volumes/frus1961-63v06/documents/d2/tags': { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
    });
    const { router } = renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { frame, posted } = await loadedFrame();
    await waitFor(() => expect(highlightsSent(posted)).toHaveLength(1));
    fromFrame(frame, 'highlightShortcut', { start: 12, end: 40, rect });
    await waitFor(() => expect(creates(fetch)).toHaveLength(1));
    await router.navigate({ to: '/doc/$volumeId/$documentId', params: { volumeId: 'frus1961-63v06', documentId: 'd2' }, search: { rail: 'research' } });
    await screen.findByRole('heading', { level: 1, name: '2. Memo' });
    await act(async () => answer());
    await pause(20);
    const rail = screen.getByRole('complementary', { name: 'Research' });
    await within(rail).findByRole('button', { name: 'Add Note' });
    expect(within(rail).queryByRole('button', { name: 'Add Note to Highlight' })).toBeNull();
  });
});
