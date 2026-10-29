import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ResearchDocument, ResearchDocumentList, ResearchPage } from '../api/researchPage';
import { resetPreferences } from '../settings/preferences';
import { me } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

const berlin = 'B0000000-0000-4000-8000-000000000000';
const briefing = 'D0000000-0000-4000-8000-000000000000';

const page: ResearchPage = {
  allAnnotated: 1204,
  hasNotes: 2,
  notes: 3,
  collections: [{ id: briefing, name: 'Briefing book', count: 1 }],
  tags: [{ id: berlin, name: 'Berlin', count: 2 }],
  highlightColors: [
    { color: 'yellow', count: 2 },
    { color: 'pink', count: 1 },
  ],
};

const kennedy: ResearchDocument = {
  volumeId: 'frus1961-63v06',
  documentId: 'd1',
  title: '1. Telegram From the Embassy in the Soviet Union',
  volumeTitle: 'Kennedy-Khrushchev Exchanges',
  annotatedAt: '2026-10-24T10:00:00.000Z',
  latestNote: 'Kennedy writes warmly.',
  noteCount: 2,
  summaryCount: 1,
  isInVisitPlan: true,
  highlights: [
    { id: 'H1', color: 'yellow', selectedText: 'Allow me to congratulate you' },
    { id: 'H2', color: 'pink', selectedText: '' },
    { id: 'H3', color: 'yellow', selectedText: 'on the occasion of your election' },
  ],
  highlightCount: 5,
  tags: [{ id: berlin, name: 'Berlin' }],
  collections: [{ id: briefing, name: 'Briefing book' }],
};

const bare: ResearchDocument = {
  volumeId: 'frus1969-76v01',
  documentId: 'd42',
  title: 'd42',
  volumeTitle: 'frus1969-76v01',
  noteCount: 0,
  summaryCount: 0,
  isInVisitPlan: false,
  highlights: [],
  highlightCount: 0,
  tags: [],
  collections: [],
};

/** The server: the page, and each category's documents by its key. */
function server(lists: Record<string, Partial<ResearchDocumentList>> = {}) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/research': page,
    '/api/v1/me/research/documents': (url: URL) => {
      const group = url.searchParams.get('group') ?? '';
      const list = lists[group] ?? { items: [] };
      return { group, total: list.items?.length ?? 0, items: [], ...list };
    },
  });
}

/** The groups the server was asked for, in order. */
const asked = (fetch: ReturnType<typeof stubServer>) =>
  fetch.mock.calls
    .map(([input]) => new URL(String(input), 'http://localhost'))
    .filter((url) => url.pathname === '/api/v1/me/research/documents')
    .map((url) => url.searchParams.get('group'));

beforeEach(() => {
  resetPreferences();
  // The rows' times since are read against this moment; nothing else waits on a clock.
  vi.useFakeTimers({ toFake: ['Date'], now: new Date('2026-10-24T12:23:00.000Z') });
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('the Research page', () => {
  it('is the header’s Research: the app’s categories, with their counts, beside All Research Documents’ rows', async () => {
    server({ allAnnotated: { items: [kennedy, bare] } });
    renderAt('/research');
    expect(await screen.findByRole('heading', { level: 1, name: 'Research' })).toBeTruthy();
    expect(document.title).toBe('Research – FRUS Explorer Light');
    const main = screen.getByRole('navigation', { name: 'Main' });
    expect(within(main).getByRole('link', { name: 'Research' }).getAttribute('aria-current')).toBe('page');

    const categories = screen.getByRole('navigation', { name: 'Categories' });
    await within(categories).findByRole('link', { name: /^All Research Documents/ });
    const rows = within(categories)
      .getAllByRole('listitem')
      .map((item) => item.textContent);
    expect(rows).toEqual([
      'All Research Documents, 1,204',
      'Contains Notes, 2',
      'All Notes, 3',
      `Changed by an update${'Documents an update changed after you annotated them wait for a review of their new text, which this server does not offer yet, so none is listed here.'}`,
      'History, Documents opened and searches run',
      'Briefing book, 1',
      'Berlin, 2',
      'Yellow, 2',
      'Pink, 1',
    ]);
    expect(within(categories).getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'By Collection',
      'By Tag',
      'By Highlight',
    ]);
    // All Research Documents is shown until another is chosen, as the Mac's opens.
    expect(within(categories).getByRole('link', { name: /^All Research Documents/ }).getAttribute('aria-current')).toBe('page');
    expect(within(categories).getByRole('link', { name: /^All Notes/ }).getAttribute('href')).toBe('/research/notes');
    expect(within(categories).getByRole('link', { name: /^History/ }).getAttribute('href')).toBe('/research/history');
    expect(within(categories).getByRole('link', { name: /^Berlin/ }).getAttribute('href')).toBe(`/research?group=tag.${berlin}`);

    // The rows, as the app's draws them.
    const list = await screen.findByRole('region', { name: 'All Research Documents' });
    await within(list).findByRole('link', { name: kennedy.title });
    const [first, second] = [...list.querySelectorAll<HTMLElement>('li.research-document')];
    expect(within(first!).getByRole('link', { name: kennedy.title }).getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    expect(first!.querySelector('.research-document-volume')?.textContent).toBe('Kennedy-Khrushchev Exchanges2 hours, 23 minutes');
    expect(first!.querySelector('.research-document-counts')?.textContent).toBe('1 summariesIn a visit plan');
    expect([...first!.querySelectorAll('.research-highlight')].map((item) => item.textContent)).toEqual([
      'Yellow highlight: Allow me to congratulate you',
      'Pink highlight: Highlighted passage',
      'Yellow highlight: on the occasion of your election',
    ]);
    expect(first!.querySelector('.research-highlight.hl-pink em')?.textContent).toBe('Highlighted passage');
    expect(first!.querySelector('.research-more')?.textContent).toBe('and 2 more');
    expect(first!.querySelector('.research-note')?.textContent).toBe('Kennedy writes warmly.');
    expect(first!.querySelector('.research-footer')?.textContent).toBe('◆ Tag: Berlin2 notesCollection: Briefing book');
    // A document only collected or tagged has no date, counts, highlights, note or footer.
    expect(within(second!).getByRole('link', { name: 'd42' })).toBeTruthy();
    expect(second!.querySelector('.research-document-volume')?.textContent).toBe('frus1969-76v01');
    for (const part of ['.research-document-counts', '.research-highlights', '.research-more', '.research-note', '.research-footer']) {
      expect(second!.querySelector(part), part).toBeNull();
    }
  });

  it('chooses a category: the address names it, its list is asked for, and its title takes focus', async () => {
    const fetch = server({ allAnnotated: { items: [kennedy, bare] }, [`tag.${berlin}`]: { name: 'Berlin', items: [kennedy] } });
    const { router } = renderAt('/research');
    const categories = await screen.findByRole('navigation', { name: 'Categories' });
    await userEvent.click(await within(categories).findByRole('link', { name: /^Berlin/ }));
    await waitFor(() => expect(router.state.location.search).toEqual({ group: `tag.${berlin}` }));
    const heading = await screen.findByRole('heading', { level: 2, name: 'Berlin' });
    await waitFor(() => expect(document.activeElement).toBe(heading));
    expect(within(categories).getByRole('link', { name: /^Berlin/ }).getAttribute('aria-current')).toBe('page');
    expect(within(categories).getByRole('link', { name: /^All Research Documents/ }).getAttribute('aria-current')).toBeNull();
    await screen.findByRole('link', { name: kennedy.title });
    expect(asked(fetch)).toEqual(['allAnnotated', `tag.${berlin}`]);

    // The one shown, chosen again, sends focus to its title at once.
    within(categories).getByRole('link', { name: /^Pink/ }).focus();
    await userEvent.click(within(categories).getByRole('link', { name: /^Berlin/ }));
    expect(document.activeElement).toBe(heading);
  });

  it('leaves the way back unmarked beside a list, and follows no click the browser sends elsewhere', async () => {
    server({ [`tag.${berlin}`]: { name: 'Berlin', items: [kennedy] } });
    const { router } = renderAt(`/research?group=tag.${berlin}`);
    const back = await screen.findByRole('link', { name: 'Categories' });
    expect(back.getAttribute('href')).toBe('/research');
    expect(back.getAttribute('aria-current'), 'the way back is no current page').toBeNull();
    const categories = screen.getByRole('navigation', { name: 'Categories' });
    const shownTag = await within(categories).findByRole('link', { name: /^Berlin/ });
    expect(shownTag.getAttribute('aria-current')).toBe('page');

    // A click with a modifier is the browser's, for a new tab or window: focus stays where the click
    // put it, on the one shown as on another, and nothing waits to move it once the address changes.
    // Every element has a box here, as in a browser, where jsdom lays out none.
    vi.spyOn(Element.prototype, 'getClientRects').mockReturnValue([new DOMRect(0, 0, 10, 10)] as unknown as DOMRectList);
    const user = userEvent.setup();
    await user.keyboard('{Control>}');
    await user.click(shownTag);
    expect(document.activeElement).toBe(shownTag);
    const pink = within(categories).getByRole('link', { name: /^Pink/ });
    await user.click(pink);
    await user.keyboard('{/Control}');
    expect(document.activeElement).toBe(pink);
    expect(router.state.location.search).toEqual({ group: `tag.${berlin}` });
    await router.navigate({ to: '/research', search: { group: 'hasNotes' } });
    await screen.findByRole('heading', { level: 2, name: 'Contains Notes' });
    expect(document.activeElement, 'Back or Forward leaves focus that still shows').toBe(pink);
  });

  it('marks no category in the narrow window’s stack until one is chosen, as the iPhone’s list', async () => {
    vi.stubGlobal(
      'matchMedia',
      vi.fn((query: string) => ({ matches: query === '(max-width: 899.98px)', addEventListener: () => {}, removeEventListener: () => {} })),
    );
    server({ allAnnotated: { items: [kennedy] } });
    renderAt('/research');
    const categories = await screen.findByRole('navigation', { name: 'Categories' });
    const all = await within(categories).findByRole('link', { name: /^All Research Documents/ });
    expect(all.getAttribute('aria-current')).toBeNull();
    expect(within(categories).queryAllByRole('link').filter((link) => link.getAttribute('aria-current'))).toEqual([]);
  });

  it('titles a list it could not read, of a tag the categories do not name, as the app titles one it cannot find', async () => {
    const gone = 'E0000000-0000-4000-8000-000000000000';
    server({ [`tag.${gone}`]: { items: [] } });
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/research': page,
      '/api/v1/me/research/documents': new ProblemAnswer(500, 'STORE_DAMAGED', 'Your research could not be read.'),
    });
    renderAt(`/research?group=tag.${gone}`);
    expect(await screen.findByRole('alert')).toBeTruthy();
    expect(screen.getByRole('heading', { level: 2, name: 'Tag' })).toBeTruthy();
  });

  it('titles each list as the app does, and says what a list of none would hold', async () => {
    server({ [`collection.${briefing}`]: { name: 'Briefing book' } });
    renderAt('/research?group=highlightColor.pink');
    expect(await screen.findByRole('heading', { level: 2, name: 'Pink Highlights' })).toBeTruthy();
    const empty = await screen.findByText('No Documents');
    expect(empty.closest('p')?.textContent).toBe('No Documents No documents have highlights in this color.');
    cleanup();

    // A tag the user has none of is Tag, as the app's title says it.
    server();
    renderAt('/research?group=tag.E0000000-0000-4000-8000-000000000000');
    expect(await screen.findByRole('heading', { level: 2, name: 'Tag' })).toBeTruthy();
    expect((await screen.findByText('No Documents')).closest('p')?.textContent).toBe(
      'No Documents No documents have notes or tags matching this tag.',
    );
    cleanup();

    server({ hasNotes: { items: [] } });
    renderAt('/research?group=hasNotes');
    expect(await screen.findByRole('heading', { level: 2, name: 'Contains Notes' })).toBeTruthy();
    expect((await screen.findByText('No Documents')).closest('p')?.textContent).toBe(
      'No Documents Notes you write on a document will appear here. A document you have only tagged, highlighted, or collected appears under All Research Documents instead.',
    );
  });

  it('says that Changed by an update waits for a review this server does not offer, and asks for no list', async () => {
    const fetch = server();
    renderAt('/research?group=updated');
    expect(await screen.findByRole('heading', { level: 2, name: 'Changed by an update' })).toBeTruthy();
    const list = screen.getByRole('region', { name: 'Changed by an update' });
    expect(within(list).getByText(/^Documents an update changed after you annotated them wait/)).toBeTruthy();
    await screen.findByRole('link', { name: /^All Research Documents/ });
    expect(asked(fetch)).toEqual([]);
    // Its row in the categories is a line, not a link.
    expect(screen.queryByRole('link', { name: /^Changed by an update/ })).toBeNull();
  });

  it('lists nothing on a server that keeps no user data, and says so', async () => {
    const fetch = stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    renderAt('/research');
    expect(await screen.findByText('This server keeps no tags or other research data of yours: it is read-only.')).toBeTruthy();
    expect(screen.queryByRole('navigation', { name: 'Categories' })).toBeNull();
    expect(fetch.mock.calls.some(([input]) => String(input).includes('/api/v1/me/research'))).toBe(false);
  });

  it('is first among Research’s screens above All Notes and History', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/notes': { total: 0, items: [] },
      '/api/v1/me/tags': { total: 0, items: [] },
      '/api/v1/me/projects': { total: 0, items: [] },
    });
    renderAt('/research/notes');
    const nav = await screen.findByRole('navigation', { name: 'Research' });
    expect(within(nav).getAllByRole('link').map((link) => [link.textContent, link.getAttribute('href'), link.getAttribute('aria-current')])).toEqual([
      ['Research', '/research', null],
      ['All Notes', '/research/notes', 'page'],
      ['History', '/research/history', null],
    ]);
  });
});
