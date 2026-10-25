import { act, cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { NoteSummary } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { berlin, me, note, noteSummary, revisit, sent } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

const project = { id: 'P0000000-0000-4000-8000-000000000000', name: 'Berlin Crisis' };

const rows: NoteSummary[] = [
  noteSummary({
    id: 'A',
    bodyText: `\n  ${'Kennedy writes of the Berlin question at length, and the Chairman answers him in kind, point by point'}\nSecond line`,
    projectIds: [project.id],
    userTagIds: [revisit.id, berlin.id],
    lastModified: '2026-10-24T12:00:00.000Z',
  }),
  noteSummary({ id: 'B', bodyText: '', volumeId: 'frus1969-76v01', documentId: 'd42', lastModified: '2026-10-20T12:00:00.000Z' }),
  noteSummary({ id: 'C', bodyText: 'Only a gone project', projectIds: ['GONE0000-0000-4000-8000-000000000000'], userTagIds: [berlin.id], lastModified: null }),
];

function server(answers: Record<string, unknown> = {}, notes: NoteSummary[] = rows) {
  const state = { notes };
  const fetch = stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/notes': () => ({ total: state.notes.length, items: state.notes }),
    '/api/v1/me/tags': { total: 2, items: [berlin, revisit] },
    '/api/v1/me/projects': { total: 1, items: [project] },
    ...answers,
  });
  return { fetch, state };
}

const pause = (ms: number) => act(() => new Promise<void>((resolve) => setTimeout(resolve, ms)));

/** The rows shown, each its title, detail and date. */
const shown = () =>
  within(screen.getByRole('list', { name: 'All Notes' }))
    .getAllByRole('listitem')
    .map((item) => [...item.querySelectorAll('.all-notes-row > span')].map((part) => part.textContent));

beforeEach(() => {
  resetPreferences();
  window.localStorage.clear();
  window.localStorage.setItem('frus.notes.editor.richText', 'false');
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('All Notes', () => {
  it('is Research’s destination, linked from the header between Search and Settings, and lists every note as the app’s rows', async () => {
    server();
    const { router } = renderAt('/research');
    expect(await screen.findByRole('heading', { level: 1, name: 'All Notes' })).toBeTruthy();
    expect(router.state.location.pathname).toBe('/research/notes');
    const nav = screen.getByRole('navigation', { name: 'Main' });
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual(['Browse', 'Search', 'Research', 'Settings']);
    expect(within(nav).getByRole('link', { name: 'Research' }).getAttribute('aria-current')).toBe('page');
    await screen.findByRole('list', { name: 'All Notes' });
    expect(shown()).toEqual([
      [
        `${'Kennedy writes of the Berlin question at length, and the Chairman answers him in kind, poi'.slice(0, 90)}…`,
        'frus1961-63v06 / d1 · Berlin Crisis · Revisit · Berlin',
        'Oct 24, 2026',
      ],
      ['Empty note', 'frus1969-76v01 / d42', 'Oct 20, 2026'],
      // A project gone has no name to show, and a note with no time no date.
      ['Only a gone project', 'frus1961-63v06 / d1 · Berlin'],
    ]);
    expect(screen.getByRole('status').textContent).toBe('3 notes');
    expect(document.title).toBe('All Notes – FRUS Explorer Light');
  });

  it('filters by project, where Not in a project is a note with none, by tag, and by text, and counts what it shows of all', async () => {
    server();
    const { router } = renderAt('/research/notes');
    await screen.findByRole('list', { name: 'All Notes' });
    const projectFilter = screen.getByRole('combobox', { name: 'Project' }) as HTMLSelectElement;
    expect([...projectFilter.options].map((option) => option.textContent)).toEqual(['All projects', 'Not in a project', 'Berlin Crisis']);
    const tagFilter = screen.getByRole('combobox', { name: 'Tag' }) as HTMLSelectElement;
    expect([...tagFilter.options].map((option) => option.textContent)).toEqual(['All tags', 'Berlin', 'Revisit']);

    await userEvent.selectOptions(projectFilter, 'unfiled');
    expect(shown().map((row) => row[1])).toEqual(['frus1969-76v01 / d42']);
    expect(screen.getByRole('status').textContent).toBe('Showing 1 of 3 notes');
    await waitFor(() => expect(router.state.location.search).toMatchObject({ project: 'unfiled' }));
    await userEvent.selectOptions(projectFilter, project.id);
    expect(shown()).toHaveLength(1);
    await userEvent.selectOptions(projectFilter, '');

    await userEvent.selectOptions(tagFilter, berlin.id);
    expect(shown().map((row) => row[0])).toEqual([expect.stringMatching(/^Kennedy/), 'Only a gone project']);
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search notes…' }), '  GONE ');
    expect(shown().map((row) => row[0])).toEqual(['Only a gone project']);
    await waitFor(() => expect(router.state.location.search).toMatchObject({ tag: berlin.id, q: '  GONE ' }));

    await userEvent.selectOptions(tagFilter, revisit.id);
    expect(screen.queryByRole('list', { name: 'All Notes' })).toBeNull();
    expect(screen.getByRole('heading', { level: 2, name: 'No Notes' })).toBeTruthy();
    expect(screen.getByText('No notes match the selected filters.')).toBeTruthy();
    expect(screen.getByRole('status').textContent).toBe('Showing 0 of 3 notes');
  });

  it('reads a filter the URL names in another case as its list’s, and one the list does not hold as none, as its select shows', async () => {
    server();
    renderAt(`/research/notes?tag=${berlin.id.toLowerCase()}&project=${project.id.toLowerCase()}`);
    await screen.findByRole('list', { name: 'All Notes' });
    await waitFor(() => expect((screen.getByRole('combobox', { name: 'Tag' }) as HTMLSelectElement).value).toBe(berlin.id));
    expect((screen.getByRole('combobox', { name: 'Project' }) as HTMLSelectElement).value).toBe(project.id);
    expect(shown().map((row) => row[0])).toEqual([expect.stringMatching(/^Kennedy/)]);
    expect(screen.getByRole('status').textContent).toBe('Showing 1 of 3 notes');
    cleanup();
    server();
    renderAt('/research/notes?project=UNFILED');
    await waitFor(() => expect((screen.getByRole('combobox', { name: 'Project' }) as HTMLSelectElement).value).toBe('unfiled'));
    expect(shown().map((row) => row[1])).toEqual(['frus1969-76v01 / d42']);
    cleanup();

    // A tag deleted since, and a project gone: the selects say All, and so do the rows.
    server();
    renderAt('/research/notes?tag=D0000000-0000-4000-8000-000000000000&project=GONE0000-0000-4000-8000-000000000000');
    await screen.findByRole('list', { name: 'All Notes' });
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe('3 notes'));
    expect(shown()).toHaveLength(3);
    expect((screen.getByRole('combobox', { name: 'Tag' }) as HTMLSelectElement).value).toBe('');
    expect((screen.getByRole('combobox', { name: 'Project' }) as HTMLSelectElement).value).toBe('');
  });

  it('says there are no notes yet in the app’s words', async () => {
    server({}, []);
    renderAt('/research/notes');
    expect(await screen.findByText('No notes yet. Notes you write from a document appear here.')).toBeTruthy();
    expect(screen.getByRole('status').textContent).toBe('0 notes');
  });

  it('asks before Delete… deletes a note, Cancel first, and focus goes to the next row’s Delete…', async () => {
    const { fetch, state } = server({
      'DELETE /api/v1/me/notes/A': () => {
        state.notes = state.notes.filter((row) => row.id !== 'A');
        return null;
      },
    });
    renderAt('/research/notes');
    await screen.findByRole('list', { name: 'All Notes' });
    const deletes = () => screen.getAllByRole('button', { name: 'Delete…' });
    expect(deletes()[0]?.getAttribute('aria-describedby')).toBe(screen.getAllByRole('listitem')[0]?.querySelector('.all-notes-title')?.id);
    await userEvent.click(deletes()[0]!);
    let question = await screen.findByRole('alertdialog', { name: 'Delete Note?' });
    expect(within(question).getByText('This note will be permanently deleted.')).toBeTruthy();
    expect(document.activeElement).toBe(within(question).getByRole('button', { name: 'Cancel' }));
    fireEvent(question, new Event('cancel', { cancelable: true }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(deletes()[0]));
    await userEvent.click(deletes()[0]!);
    question = await screen.findByRole('alertdialog', { name: 'Delete Note?' });
    await userEvent.click(within(question).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(shown()).toHaveLength(2));
    await waitFor(() => expect(document.activeElement).toBe(deletes()[0]));
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'DELETE').map(([url, init]) => [String(url), sent(init).token])).toEqual([
      ['/api/v1/me/notes/A', 'token-1'],
    ]);
  });

  it('sends focus past the deleted row though the list takes a while to be read again, and to the heading after the last', async () => {
    let slow = false;
    const { state } = server({
      // Read again more slowly than a frame, as a server across a network is.
      '/api/v1/me/notes': () => {
        const answer = { total: state.notes.length, items: state.notes };
        return slow ? new Promise((resolve) => setTimeout(() => resolve(answer), 50)) : answer;
      },
      'DELETE /api/v1/me/notes/A': () => {
        state.notes = state.notes.filter((row) => row.id !== 'A');
        slow = true;
        return null;
      },
      'DELETE /api/v1/me/notes/B': () => {
        state.notes = state.notes.filter((row) => row.id !== 'B');
        return null;
      },
    });
    renderAt('/research/notes');
    await screen.findByRole('list', { name: 'All Notes' });
    const deleteOf = (id: string) => document.querySelector<HTMLButtonElement>(`button.delete-note[data-id="${id}"]`);
    await userEvent.click(deleteOf('A')!);
    await userEvent.click(within(await screen.findByRole('alertdialog', { name: 'Delete Note?' })).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(deleteOf('B')));
    expect(shown()).toHaveLength(2);
    await pause(60);
    expect(document.activeElement).toBe(deleteOf('B'));

    state.notes = [state.notes[0]!];
    cleanup();
    renderAt('/research/notes');
    await screen.findByRole('list', { name: 'All Notes' });
    await userEvent.click(deleteOf('B')!);
    await userEvent.click(within(await screen.findByRole('alertdialog', { name: 'Delete Note?' })).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('heading', { level: 1, name: 'All Notes' })));
    expect(screen.getByText('No notes yet. Notes you write from a document appear here.')).toBeTruthy();
  });

  it('opens a row’s note in the editor, as the app’s sheet', async () => {
    const { fetch } = server({
      '/api/v1/me/notes/B': note({ id: 'B', bodyText: '', volumeId: 'frus1969-76v01', documentId: 'd42' }),
      '/api/v1/me/volumes/frus1969-76v01/documents/d42/summaries': new ProblemAnswer(404, 'VOLUME_NOT_FOUND', 'No such volume.'),
      'PUT /api/v1/me/notes/B': note({ id: 'B' }),
    });
    renderAt('/research/notes');
    await screen.findByRole('list', { name: 'All Notes' });
    await userEvent.click(screen.getByRole('button', { name: /^Empty note/ }));
    const editor = await screen.findByRole('dialog', { name: 'Edit Note' });
    await userEvent.type(await within(editor).findByRole('textbox', { name: 'Research note body' }), 'Now written');
    await userEvent.click(within(editor).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'PUT').map(([url]) => String(url))).toEqual(['/api/v1/me/notes/B']);
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('button', { name: /^Empty note/ })));
  });

  it('says that a server keeping no user data keeps no notes, and asks it for none', async () => {
    const { fetch } = server({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/research/notes');
    expect(await screen.findByText('This server keeps no tags or other research data of yours: it is read-only.')).toBeTruthy();
    expect(fetch.mock.calls.some(([url]) => String(url) !== '/api/v1/me' && String(url).startsWith('/api/v1/me'))).toBe(false);
    // The header keeps its Research link, as it keeps Settings.
    expect(screen.getByRole('link', { name: 'Research' })).toBeTruthy();
  });
});
