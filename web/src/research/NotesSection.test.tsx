import { act, cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail, NoteSummary } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { berlin, documentPaths, me, note, noteSummary, renderWithClient, sent } from '../test/notes';
import { coverage, ready, renderAt, stubServer } from '../test/renderRoute';
import { NotesSection } from './NotesSection';

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

/** The reader with its rail's answers: the document's notes as given, and nothing else of the user's. */
function reader(answers: Record<string, unknown>) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
    '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    '/api/v1/me': me,
    '/api/v1/me/tags': { total: 1, items: [berlin] },
    '/api/v1/me/projects': { total: 0, items: [] },
    '/api/v1/me/notes': { total: 0, items: [] },
    '/api/v1/me/volumes/frus1961-63v06/documents/d1/tags': { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    '/api/v1/me/volumes/frus1961-63v06/documents/d1/highlights': { volumeId: 'frus1961-63v06', documentId: 'd1', renderingVersion: 'v1', items: [] },
    [documentPaths.summaries]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [documentPaths.notes]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    ...answers,
  });
}

const documentNotes = (items: NoteSummary[]) => ({ volumeId: 'frus1961-63v06', documentId: 'd1', items });
const ago = (seconds: number) => new Date(Date.now() - seconds * 1000).toISOString();

beforeEach(() => {
  resetPreferences();
  window.localStorage.clear();
  // The plain editor, so the rail's tests need not load the formatting one.
  window.localStorage.setItem('frus.notes.editor.richText', 'false');
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('the Research rail’s sections', () => {
  it('are Summary, Notes, Highlights and Tags, in that order, Summary and Notes open until they are closed, as the app’s', async () => {
    reader({});
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    const headers = () => within(rail).getAllByRole('heading', { level: 3 }).map((heading) => within(heading).getByRole('button'));
    expect(headers().map((button) => [button.textContent?.replace(/[▾▸]/, ''), button.getAttribute('aria-expanded')])).toEqual([
      ['Summary', 'true'],
      ['Notes', 'true'],
      ['Highlights', 'false'],
      ['Tags', 'false'],
    ]);
    await userEvent.click(headers()[1]!);
    expect(window.localStorage.getItem('frus.research.notes')).toBe('closed');
    await userEvent.click(headers()[0]!);
    expect(window.localStorage.getItem('frus.research.summary')).toBe('closed');
    expect(within(rail).queryByRole('button', { name: 'Add Note' })).toBeNull();
  });
});

describe('the rail’s Notes', () => {
  it('lists the document’s notes as the server orders them, the last changed first: each one’s text, or Empty note, and the time since it changed', async () => {
    reader({
      [documentPaths.notes]: documentNotes([
        noteSummary({ id: 'A', bodyText: 'Kennedy’s reply\nreads warmly.', lastModified: ago(2 * 3600 + 23 * 60 + 5) }),
        noteSummary({ id: 'B', bodyText: '', lastModified: ago(3 * 86_400) }),
        noteSummary({ id: 'C', bodyText: '   ', lastModified: null }),
      ]),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    expect(await within(rail).findByRole('button', { name: 'Notes, 3 notes' })).toBeTruthy();
    const rows = within(rail.querySelector('#research-notes') as HTMLElement).getAllByRole('listitem');
    expect(rows.map((row) => [row.querySelector('.note-row-text')?.textContent, row.querySelector('time')?.textContent])).toEqual([
      ['Kennedy’s reply\nreads warmly.', '2 hours, 23 minutes'],
      ['Empty note', '3 days'],
      // Not trimmed, as the app's row is not; and a note with no time reads as changed now.
      ['   ', '0 seconds'],
    ]);
    expect(rows[1]?.querySelector('.note-row-text')?.className).toContain('empty');
    // The rail deletes nothing.
    expect(within(rail).queryByRole('button', { name: /Delete/ })).toBeNull();
    expect(within(rail).getByRole('button', { name: 'Add Note' })).toBeTruthy();
  });

  it('opens a note from its row in the editor, and saves it; focus goes back to its row', async () => {
    let items = [noteSummary({ id: 'A', bodyText: 'Old text' })];
    const fetch = reader({
      [documentPaths.notes]: () => documentNotes(items),
      '/api/v1/me/notes/A': note({ id: 'A', bodyText: 'Old text' }),
      'PUT /api/v1/me/notes/A': (_: URL, init?: RequestInit) => {
        items = [noteSummary({ id: 'A', bodyText: sent(init).body.bodyText })];
        return note({ id: 'A', bodyText: sent(init).body.bodyText });
      },
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    await userEvent.click(await within(rail).findByRole('button', { name: /^Old text/ }));
    const editor = await screen.findByRole('dialog', { name: 'Edit Note' });
    const body = await within(editor).findByRole('textbox', { name: 'Research note body' });
    await userEvent.clear(body);
    await userEvent.type(body, 'New text');
    await userEvent.click(within(editor).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(await within(rail).findByRole('button', { name: /^New text/ })).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(within(rail).getByRole('button', { name: /^New text/ })));
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'PUT').map(([, init]) => sent(init).body)).toEqual([
      { bodyText: 'New text', runs: null, userTagIds: [], projectIds: [], selectedSummaryIds: [] },
    ]);
  });

  it('makes a new note on the document from Add Note, and Escape in the editor leaves the rail open', async () => {
    const fetch = reader({ [`POST ${documentPaths.notes}`]: note({ id: 'N' }) });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    const add = await within(rail).findByRole('button', { name: 'Add Note' });
    await userEvent.click(add);
    let editor = await screen.findByRole('dialog', { name: 'New Research Note' });
    await userEvent.keyboard('{Escape}');
    expect(screen.getByRole('complementary', { name: 'Research' })).toBeTruthy();
    fireEvent(editor, new Event('cancel', { cancelable: true }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(add));

    await userEvent.click(add);
    editor = await screen.findByRole('dialog', { name: 'New Research Note' });
    await userEvent.type(within(editor).getByRole('textbox', { name: 'Research note body' }), 'A thought');
    await userEvent.click(within(editor).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'POST').map(([url, init]) => [String(url), sent(init).body])).toEqual([
      [documentPaths.notes, { bodyText: 'A thought', runs: null, userTagIds: [], projectIds: [], selectedSummaryIds: [] }],
    ]);
    // The lists are read again.
    await waitFor(() => expect(fetch.mock.calls.filter(([url, init]) => !init?.method && String(url) === documentPaths.notes).length).toBeGreaterThan(1));
  });

  it('gives focus back to Add Note, never Add Note to Highlight, when an editor for a new note closes', async () => {
    reader({});
    const onPendingUsed = vi.fn();
    renderWithClient(
      <NotesSection
        volumeId="frus1961-63v06"
        documentId="d1"
        notes={[]}
        error={null}
        pendingHighlightId="H0000000-0000-4000-8000-000000000000"
        onPendingUsed={onPendingUsed}
        toggle={{ current: null }}
      />,
    );
    const add = screen.getByRole('button', { name: 'Add Note' });
    const toHighlight = screen.getByRole('button', { name: 'Add Note to Highlight' });
    for (const opener of [add, toHighlight]) {
      await userEvent.click(opener);
      const editor = await screen.findByRole('dialog', { name: 'New Research Note' });
      await userEvent.click(within(editor).getByRole('button', { name: 'Discard' }));
      await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
      // The highlight is still pending here, its parent not having let it go: Enter again links nothing.
      await waitFor(() => expect(document.activeElement).toBe(add));
    }
    expect(onPendingUsed).toHaveBeenCalledTimes(1);
  });

  it('closes the note editor and Write a Summary when the reader moves to another document, so neither writes to it', async () => {
    const d2Paths = '/api/v1/me/volumes/frus1961-63v06/documents/d2';
    const fetch = reader({
      '/api/v1/volumes/frus1961-63v06/documents/d2': { ...d1, document: { ...d1.document, documentId: 'd2', header: '2. Memo', displayTitle: '2. Memo' } },
      '/api/v1/volumes/frus1961-63v06/documents/d2/html': {},
      [`${d2Paths}/notes`]: { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      [`${d2Paths}/summaries`]: { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      [`${d2Paths}/tags`]: { volumeId: 'frus1961-63v06', documentId: 'd2', items: [] },
      [`${d2Paths}/highlights`]: { volumeId: 'frus1961-63v06', documentId: 'd2', renderingVersion: 'v1', items: [] },
    });
    const { router } = renderAt('/doc/frus1961-63v06/d1?rail=research');
    const go = (documentId: string) =>
      act(() => router.navigate({ to: '/doc/$volumeId/$documentId', params: { volumeId: 'frus1961-63v06', documentId }, search: { rail: 'research' } }));
    let rail = await screen.findByRole('complementary', { name: 'Research' });
    await userEvent.click(await within(rail).findByRole('button', { name: 'Add Note' }));
    await userEvent.type(within(await screen.findByRole('dialog', { name: 'New Research Note' })).getByRole('textbox', { name: 'Research note body' }), 'On d1');
    // Back or Forward, which a modal dialog does not hold.
    await go('d2');
    await screen.findByRole('heading', { level: 1, name: '2. Memo' });
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());

    rail = screen.getByRole('complementary', { name: 'Research' });
    await userEvent.click(await within(rail).findByRole('button', { name: 'Write a Summary' }));
    await userEvent.type(within(await screen.findByRole('dialog', { name: 'Write a Summary' })).getByRole('textbox'), 'On d2');
    await go('d1');
    await screen.findByRole('heading', { level: 1, name: '1. Telegram From the Embassy in the Soviet Union' });
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'POST')).toBe(false);
  });

  it('is not offered, nor any note read, on a server that keeps no user data', async () => {
    const fetch = reader({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByRole('button', { name: 'Cite' });
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url) === '/api/v1/me')).toBe(true));
    expect(screen.queryByRole('complementary', { name: 'Research' })).toBeNull();
    expect(fetch.mock.calls.some(([url]) => /notes|summaries/.test(String(url)))).toBe(false);
  });
});
