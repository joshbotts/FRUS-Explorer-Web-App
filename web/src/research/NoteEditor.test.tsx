import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { NoteRun, UserTag } from '../api/types';
import { noteQuery } from '../api/userData';
import { resetPreferences } from '../settings/preferences';
import { berlin, documentPaths, me, note, renderWithClient, revisit, sent, summary } from '../test/notes';
import { ProblemAnswer, stubServer } from '../test/renderRoute';
import { NoteEditor } from './NoteEditor';

// The formatting editor stands in here: its own tests drive Tiptap. This one shows the text it was
// given, reports a formatted edit, and adds a summary as the real one's handle does; while `loading`
// is unsettled, it is still being loaded.
const fake = vi.hoisted(() => ({ fail: false, unreadable: false, loading: null as Promise<void> | null }));
vi.mock('../editor/RichTextEditor', async () => {
  const React = await import('react');
  type Props = {
    runs: NoteRun[] | null;
    text: string;
    label: string;
    onChange: (runs: NoteRun[]) => void;
    onDiscard: () => void;
    onUnreadable: () => void;
    ref?: React.Ref<{ insertSummary: (text: string) => void; focus: () => void }>;
  };
  const plain = { bold: false, italic: false, underline: false };
  function FakeEditor(props: Props) {
    if (fake.fail) throw new Error('The chunk could not be loaded.');
    if (fake.loading) React.use(fake.loading);
    const [runs, setRuns] = React.useState<NoteRun[]>(props.runs ?? (props.text ? [{ text: props.text, ...plain }] : []));
    const { onUnreadable } = props;
    React.useEffect(() => {
      if (fake.unreadable) onUnreadable();
    }, [onUnreadable]);
    const change = (next: NoteRun[]) => {
      setRuns(next);
      props.onChange(next);
    };
    React.useImperativeHandle(props.ref, () => ({
      insertSummary: (text: string) => change([...runs, { text: runs.length > 0 ? `\n\n${text}` : text, ...plain }]),
      focus: () => {},
    }));
    return React.createElement(
      'div',
      { 'data-testid': 'formatted' },
      React.createElement('p', { 'aria-label': props.label }, runs.map((run) => run.text).join('')),
      React.createElement('button', { type: 'button', onClick: () => change([{ text: 'Bold', ...plain, bold: true }, { text: ' words', ...plain }]) }, 'Format'),
      React.createElement('button', { type: 'button', onClick: () => props.onDiscard() }, 'Escape in the text'),
    );
  }
  return { default: FakeEditor };
});

const noteId = 'N0000000-0000-4000-8000-000000000000';
const notePath = `/api/v1/me/notes/${noteId}`;

beforeEach(() => {
  resetPreferences();
  window.localStorage.clear();
  fake.fail = false;
  fake.unreadable = false;
  fake.loading = null;
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

/** The server's answers for the editor, with the user's tags as the test changes them. */
function server(answers: Record<string, unknown> = {}, tags: UserTag[] = [berlin, revisit]) {
  return stubServer({
    '/api/v1/me': me,
    '/api/v1/me/tags': () => ({ total: tags.length, items: tags }),
    '/api/v1/me/projects': { total: 0, items: [] },
    [documentPaths.summaries]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [documentPaths.notes]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    '/api/v1/me/notes': { total: 0, items: [] },
    ...answers,
  });
}

const changes = (fetch: ReturnType<typeof stubServer>, method: string) =>
  fetch.mock.calls.filter(([, init]) => init?.method === method).map(([url, init]) => [String(url), sent(init).body]);

function editNote(onClose = vi.fn()) {
  renderWithClient(<NoteEditor volumeId="frus1961-63v06" documentId="d1" note={{ id: noteId, volumeId: 'frus1961-63v06', documentId: 'd1' }} onClose={onClose} />);
  return onClose;
}

function newNote(onClose = vi.fn(), linkedHighlightId?: string) {
  renderWithClient(<NoteEditor volumeId="frus1961-63v06" documentId="d1" linkedHighlightId={linkedHighlightId} onClose={onClose} />);
  return onClose;
}

const plainMode = () => window.localStorage.setItem('frus.notes.editor.richText', 'false');

describe('the note editor', () => {
  it('is the app’s sheet: New Research Note, the Note section and its Formatting switch, Tags, Projects, Discard and Save', async () => {
    server();
    newNote();
    const dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    expect(within(dialog).getByRole('heading', { level: 3, name: 'Note' })).toBeTruthy();
    const formatting = within(dialog).getByRole('switch', { name: 'Formatting' });
    expect(formatting).toHaveProperty('checked', true);
    expect(within(dialog).getByRole('group', { name: 'Tags' })).toBeTruthy();
    expect(await within(dialog).findByRole('checkbox', { name: 'Berlin' })).toBeTruthy();
    expect(within(dialog).getByRole('group', { name: 'Projects' })).toBeTruthy();
    expect(await within(dialog).findByText('No projects yet.')).toBeTruthy();
    // No summaries, no section; a new note has no Delete.
    expect(within(dialog).queryByRole('heading', { name: 'Generated Summaries' })).toBeNull();
    expect(within(dialog).queryByRole('button', { name: 'Delete' })).toBeNull();
    expect(within(dialog).getAllByRole('button').slice(-2).map((button) => button.textContent)).toEqual(['Discard', 'Save']);
    expect(await within(dialog).findByTestId('formatted')).toBeTruthy();
  });

  it('saves a new note typed with formatting off as plain text, on no project, with the tags ticked', async () => {
    plainMode();
    const fetch = server({ [`POST ${documentPaths.notes}`]: note({ id: noteId }) });
    const onClose = newNote();
    const dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    const body = within(dialog).getByRole('textbox', { name: 'Research note body' });
    expect(document.activeElement).toBe(body);
    await userEvent.type(body, 'First line{Enter}Second');
    await userEvent.click(await within(dialog).findByRole('checkbox', { name: 'Revisit' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledWith('saved'));
    expect(changes(fetch, 'POST')).toEqual([
      [documentPaths.notes, { bodyText: 'First line\nSecond', runs: null, userTagIds: [revisit.id], projectIds: [], selectedSummaryIds: [] }],
    ]);
  });

  it('saves a new note written with formatting as runs, and one never written as empty plain text', async () => {
    let fetch = server({ [`POST ${documentPaths.notes}`]: note({ id: noteId }) });
    let onClose = newNote(vi.fn(), 'H0000000-0000-4000-8000-000000000000');
    let dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Format' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledWith('saved'));
    expect(changes(fetch, 'POST')[0]?.[1]).toEqual({
      bodyText: 'Bold words',
      runs: [
        { text: 'Bold', bold: true, italic: false, underline: false },
        { text: ' words', bold: false, italic: false, underline: false },
      ],
      userTagIds: [],
      projectIds: [],
      selectedSummaryIds: [],
      linkedHighlightId: 'H0000000-0000-4000-8000-000000000000',
    });
    cleanup();
    fetch = server({ [`POST ${documentPaths.notes}`]: note({ id: noteId }) });
    onClose = newNote();
    dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    await within(dialog).findByTestId('formatted');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledWith('saved'));
    expect(changes(fetch, 'POST')[0]?.[1]).toMatchObject({ bodyText: '', runs: null });
  });

  it('saves an edit to the tags alone without the text, so the store keeps the text and its formatting byte for byte', async () => {
    const runs: NoteRun[] = [{ text: 'Formatted', bold: true, italic: false, underline: false }];
    const fetch = server({
      [notePath]: note({ id: noteId, bodyText: 'Formatted', runs, userTagIds: [berlin.id] }),
      [`PUT ${notePath}`]: note({ id: noteId }),
    });
    const onClose = editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(document.activeElement).toBe(within(dialog).getByRole('heading', { level: 2, name: 'Edit Note' }));
    expect((await within(dialog).findByLabelText('Research note body')).textContent).toBe('Formatted');
    // The Formatting switch changes nothing by itself.
    await userEvent.click(within(dialog).getByRole('switch', { name: 'Formatting' }));
    expect(window.localStorage.getItem('frus.notes.editor.richText')).toBe('false');
    expect((within(dialog).getByRole('textbox', { name: 'Research note body' }) as HTMLTextAreaElement).value).toBe('Formatted');
    await userEvent.click(await within(dialog).findByRole('checkbox', { name: 'Revisit' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledWith('saved'));
    expect(changes(fetch, 'PUT')).toEqual([[notePath, { userTagIds: [berlin.id, revisit.id], projectIds: [], selectedSummaryIds: [] }]]);
  });

  it('sends the text as plain, its runs null, once it is typed with formatting off, as the app’s setPlainBody drops the formatting', async () => {
    plainMode();
    const fetch = server({
      [notePath]: note({ id: noteId, bodyText: 'Formatted', runs: [{ text: 'Formatted', bold: true, italic: false, underline: false }] }),
      [`PUT ${notePath}`]: note({ id: noteId }),
    });
    const onClose = editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await userEvent.type(await within(dialog).findByRole('textbox', { name: 'Research note body' }), ' again');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledWith('saved'));
    expect(changes(fetch, 'PUT')[0]?.[1]).toEqual({ bodyText: 'Formatted again', runs: null, userTagIds: [], projectIds: [], selectedSummaryIds: [] });
  });

  it('sends the runs of an edit made with formatting on', async () => {
    const fetch = server({ [notePath]: note({ id: noteId, bodyText: 'Plain' }), [`PUT ${notePath}`]: note({ id: noteId }) });
    const onClose = editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Format' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledWith('saved'));
    expect(changes(fetch, 'PUT')[0]?.[1]).toMatchObject({ bodyText: 'Bold words', runs: [{ text: 'Bold', bold: true }, { text: ' words', bold: false }] });
  });

  it('keeps ids its lists do not show, a tag gone or a project only the Mac’s data names, as the note has them', async () => {
    const fetch = server({
      [notePath]: note({ id: noteId, userTagIds: ['GONE0000-0000-4000-8000-000000000000', berlin.id], projectIds: ['P0000000-0000-4000-8000-000000000000'] }),
      [`PUT ${notePath}`]: note({ id: noteId }),
    });
    editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await userEvent.click(await within(dialog).findByRole('checkbox', { name: 'Berlin' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(changes(fetch, 'PUT')).toHaveLength(1));
    expect(changes(fetch, 'PUT')[0]?.[1]).toMatchObject({
      userTagIds: ['GONE0000-0000-4000-8000-000000000000'],
      projectIds: ['P0000000-0000-4000-8000-000000000000'],
    });
  });

  it('makes a tag at once from its field, ticked, which Discard keeps, as the app’s does', async () => {
    plainMode();
    const made: UserTag = { id: 'M0000000-0000-4000-8000-000000000000', name: 'Primary source' };
    const tags = [berlin];
    const fetch = server(
      {
        'POST /api/v1/me/tags': () => {
          tags.push(made);
          return made;
        },
      },
      tags,
    );
    const onClose = newNote();
    const dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    const field = within(dialog).getByRole('textbox', { name: 'New tag name' });
    const add = within(dialog).getByRole('button', { name: 'Add' });
    expect(add.getAttribute('aria-disabled')).toBe('true');
    // Empty, Add makes nothing.
    await userEvent.click(add);
    await userEvent.type(field, '  Primary source {Enter}');
    expect(await within(dialog).findByRole('checkbox', { name: 'Primary source' })).toHaveProperty('checked', true);
    expect(within(dialog).getByText('Tag Primary source created and selected')).toBeTruthy();
    expect(changes(fetch, 'POST')).toEqual([['/api/v1/me/tags', { name: 'Primary source' }]]);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Discard' }));
    expect(onClose).toHaveBeenCalledWith('discarded');
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(false);
  });

  it('keeps focus on Add, pressed by keyboard, while the tag is made and after', async () => {
    plainMode();
    const made: UserTag = { id: 'M0000000-0000-4000-8000-000000000000', name: 'Primary source' };
    let answer: (tag: UserTag) => void = () => {};
    server({ 'POST /api/v1/me/tags': () => new Promise<UserTag>((resolve) => (answer = resolve)) }, [berlin]);
    newNote();
    const dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'New tag name' }), 'Primary source');
    const add = within(dialog).getByRole('button', { name: 'Add' });
    add.focus();
    await userEvent.keyboard('{Enter}');
    await waitFor(() => expect(add.getAttribute('aria-disabled')).toBe('true'));
    // Not disabled outright, which would send its focus to the page's body.
    expect(add).toHaveProperty('disabled', false);
    expect(document.activeElement).toBe(add);
    answer(made);
    expect(await within(dialog).findByRole('checkbox', { name: 'Primary source' })).toHaveProperty('checked', true);
    expect(document.activeElement).toBe(add);
  });

  it('says an empty tag list in the app’s words', async () => {
    server({}, []);
    newNote();
    const dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    expect(await within(dialog).findByText('No tags yet — add one below.')).toBeTruthy();
  });

  it('inserts a summary’s text after a blank line, as the app’s Insert into note, and Remove from note only unticks it', async () => {
    plainMode();
    const first = summary({ id: 'S1000000-0000-4000-8000-000000000000', responseText: 'First summary.' });
    const second = summary({ id: 'S2000000-0000-4000-8000-000000000000', responseText: 'Second summary.', authorship: 'aiGenerated', editable: false });
    const fetch = server({
      [notePath]: note({ id: noteId, bodyText: 'My note' }),
      [documentPaths.summaries]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [first, second] },
      [`PUT ${notePath}`]: note({ id: noteId }),
    });
    editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    const section = await within(dialog).findByRole('region', { name: 'Generated Summaries' });
    const rows = within(section).getAllByRole('listitem');
    expect(rows.map((row) => row.querySelector('p')?.textContent)).toEqual(['First summary.', 'Second summary.']);
    await userEvent.click(within(rows[1]!).getByRole('button', { name: 'Insert into note' }));
    expect((within(dialog).getByRole('textbox', { name: 'Research note body' }) as HTMLTextAreaElement).value).toBe('My note\n\nSecond summary.');
    await userEvent.click(within(rows[0]!).getByRole('button', { name: 'Insert into note' }));
    await userEvent.click(within(rows[1]!).getByRole('button', { name: 'Remove from note' }));
    expect(within(rows[1]!).getByRole('button', { name: 'Insert into note' })).toBeTruthy();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(changes(fetch, 'PUT')).toHaveLength(1));
    expect(changes(fetch, 'PUT')[0]?.[1]).toEqual({
      bodyText: 'My note\n\nSecond summary.\n\nFirst summary.',
      runs: null,
      userTagIds: [],
      projectIds: [],
      selectedSummaryIds: [first.id],
    });
  });

  it('inserts a summary into the formatted text, keeping its formatting, the web’s own', async () => {
    const only = summary({ id: 'S1000000-0000-4000-8000-000000000000', responseText: 'A summary.' });
    const fetch = server({
      [notePath]: note({ id: noteId, bodyText: 'Bold', runs: [{ text: 'Bold', bold: true, italic: false, underline: false }] }),
      [documentPaths.summaries]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [only] },
      [`PUT ${notePath}`]: note({ id: noteId }),
    });
    editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await within(dialog).findByTestId('formatted');
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Insert into note' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(changes(fetch, 'PUT')).toHaveLength(1));
    expect(changes(fetch, 'PUT')[0]?.[1]).toMatchObject({
      bodyText: 'Bold\n\nA summary.',
      runs: [{ text: 'Bold', bold: true }, { text: '\n\nA summary.', bold: false }],
      selectedSummaryIds: [only.id],
    });
  });

  it('inserts a summary into a formatted note while the formatting editor is still loading, keeping its formatting', async () => {
    let loaded: () => void = () => {};
    fake.loading = new Promise<void>((resolve) => (loaded = resolve));
    const only = summary({ id: 'S1000000-0000-4000-8000-000000000000', responseText: 'A summary.' });
    const fetch = server({
      [notePath]: note({ id: noteId, bodyText: 'Bold', runs: [{ text: 'Bold', bold: true, italic: false, underline: false }] }),
      [documentPaths.summaries]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [only] },
      [`PUT ${notePath}`]: note({ id: noteId }),
    });
    editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(await within(dialog).findByText('Loading the editor…')).toBeTruthy();
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Insert into note' }));
    // Once it has loaded, the editor opens on the note with the summary, formatted as it was.
    await act(async () => loaded());
    expect((await within(dialog).findByLabelText('Research note body')).textContent).toBe('Bold\n\nA summary.');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(changes(fetch, 'PUT')).toHaveLength(1));
    expect(changes(fetch, 'PUT')[0]?.[1]).toEqual({
      bodyText: 'Bold\n\nA summary.',
      runs: [
        { text: 'Bold\n\n', bold: true, italic: false, underline: false },
        { text: 'A summary.', bold: false, italic: false, underline: false },
      ],
      userTagIds: [],
      projectIds: [],
      selectedSummaryIds: [only.id],
    });
  });

  it('starts from the note as the server has it now, not from a copy an earlier opening left', async () => {
    const fetch = server({ [notePath]: note({ id: noteId, bodyText: 'Changed elsewhere' }), [`PUT ${notePath}`]: note({ id: noteId }) });
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    client.setQueryData(noteQuery(noteId).queryKey, note({ id: noteId, bodyText: 'As it was', userTagIds: [revisit.id] }));
    render(
      <QueryClientProvider client={client}>
        <NoteEditor volumeId="frus1961-63v06" documentId="d1" note={{ id: noteId, volumeId: 'frus1961-63v06', documentId: 'd1' }} onClose={vi.fn()} />
      </QueryClientProvider>,
    );
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect((await within(dialog).findByLabelText('Research note body')).textContent).toBe('Changed elsewhere');
    expect(await within(dialog).findByRole('checkbox', { name: 'Revisit' })).toHaveProperty('checked', false);
    await userEvent.click(within(dialog).getByRole('checkbox', { name: 'Berlin' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(changes(fetch, 'PUT')).toHaveLength(1));
    expect(changes(fetch, 'PUT')[0]?.[1]).toEqual({ userTagIds: [berlin.id], projectIds: [], selectedSummaryIds: [] });
  });

  it('says a note deleted elsewhere is gone though an earlier opening left a copy, and lets the copy go when a save is refused', async () => {
    const refusal = () => new ProblemAnswer(404, 'NOTE_NOT_FOUND', 'You have no note with the id N0000000.');
    server({ [notePath]: refusal() });
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    client.setQueryData(noteQuery(noteId).queryKey, note({ id: noteId, bodyText: 'As it was' }));
    render(
      <QueryClientProvider client={client}>
        <NoteEditor volumeId="frus1961-63v06" documentId="d1" note={{ id: noteId, volumeId: 'frus1961-63v06', documentId: 'd1' }} onClose={vi.fn()} />
      </QueryClientProvider>,
    );
    let dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect((await within(dialog).findByRole('alert')).textContent).toBe('You have no note with the id N0000000.');
    expect(within(dialog).queryByRole('button', { name: 'Save' })).toBeNull();
    cleanup();

    // Deleted after the editor read it: the save is refused, and the note's copy goes with it.
    let gone = false;
    server({
      [notePath]: () => (gone ? refusal() : note({ id: noteId, bodyText: 'Text' })),
      [`PUT ${notePath}`]: () => {
        gone = true;
        return refusal();
      },
    });
    const { client: other } = renderWithClient(
      <NoteEditor volumeId="frus1961-63v06" documentId="d1" note={{ id: noteId, volumeId: 'frus1961-63v06', documentId: 'd1' }} onClose={vi.fn()} />,
    );
    dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await within(dialog).findByLabelText('Research note body');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect((await within(dialog).findByRole('alert')).textContent).toBe('You have no note with the id N0000000.');
    await waitFor(() => expect(other.getQueryData(noteQuery(noteId).queryKey)).toBeUndefined());
  });

  it('deletes a note it edits from Delete, asking nothing, as the app’s editor does', async () => {
    const fetch = server({ [notePath]: note({ id: noteId }), [`DELETE ${notePath}`]: null });
    const onClose = editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledWith('deleted'));
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(changes(fetch, 'DELETE')).toEqual([[notePath, undefined]]);
  });

  it('discards on Escape, from the dialog and from the formatted text, and sends nothing', async () => {
    const fetch = server({ [notePath]: note({ id: noteId }) });
    let onClose = editNote();
    let dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await within(dialog).findByTestId('formatted');
    fireEvent(dialog, new Event('cancel', { cancelable: true }));
    expect(onClose).toHaveBeenCalledWith('discarded');
    cleanup();
    onClose = editNote();
    dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Escape in the text' }));
    expect(onClose).toHaveBeenCalledWith('discarded');
    expect(fetch.mock.calls.some(([, init]) => init?.method && init.method !== 'GET')).toBe(false);
  });

  it('says why a save was refused, and reads the tags and the note again when a tag has gone', async () => {
    plainMode();
    const fetch = server({
      [notePath]: note({ id: noteId }),
      [`PUT ${notePath}`]: new ProblemAnswer(404, 'TAG_NOT_FOUND', 'You have no tag with the id B0000000-0000-4000-8000-000000000000.'),
    });
    const onClose = editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    await userEvent.click(await within(dialog).findByRole('checkbox', { name: 'Berlin' }));
    const reads = () => fetch.mock.calls.filter(([url, init]) => !init?.method && (String(url) === '/api/v1/me/tags' || String(url) === notePath)).length;
    const before = reads();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect((await within(dialog).findByRole('alert')).textContent).toBe('You have no tag with the id B0000000-0000-4000-8000-000000000000.');
    await waitFor(() => expect(reads()).toBeGreaterThanOrEqual(before + 2));
    expect(onClose).not.toHaveBeenCalled();
  });

  it('says a note deleted elsewhere is gone', async () => {
    server({ [notePath]: new ProblemAnswer(404, 'NOTE_NOT_FOUND', 'You have no note with the id N0000000.') });
    editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect((await within(dialog).findByRole('alert')).textContent).toBe('You have no note with the id N0000000.');
    expect(within(dialog).queryByRole('button', { name: 'Save' })).toBeNull();
  });

  it('opens a note plain, with a sentence, when its formatting cannot be shown or the editor cannot be loaded', async () => {
    fake.unreadable = true;
    server({ [notePath]: note({ id: noteId, bodyText: 'Text', runs: [{ text: 'Text', bold: true, italic: false, underline: false }] }) });
    editNote();
    let dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(
      await within(dialog).findByText(
        'This note could not be shown with its formatting, so it is open as plain text. Its formatting is kept until its text is changed here.',
      ),
    ).toBeTruthy();
    expect((within(dialog).getByRole('textbox', { name: 'Research note body' }) as HTMLTextAreaElement).value).toBe('Text');
    expect(within(dialog).getByRole('switch', { name: 'Formatting' })).toHaveProperty('disabled', true);
    // The preference stays as it was.
    expect(window.localStorage.getItem('frus.notes.editor.richText')).toBeNull();
    cleanup();

    // A plain note has no formatting to keep: what cannot be shown is its line breaks, a CR among them.
    server({ [notePath]: note({ id: noteId, bodyText: 'One\r\nTwo' }) });
    editNote();
    dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(await within(dialog).findByText('This note’s line breaks cannot be shown in the formatting editor, so it is open as plain text.')).toBeTruthy();
    expect(within(dialog).queryByText(/formatting is kept/)).toBeNull();
    cleanup();
    fake.unreadable = false;
    fake.fail = true;
    vi.spyOn(console, 'error').mockImplementation(() => {});
    editNote();
    dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(await within(dialog).findByText('The formatting editor could not be loaded, so this note is open as plain text.')).toBeTruthy();
    expect(within(dialog).getByRole('textbox', { name: 'Research note body' })).toBeTruthy();
  });

  it('says a note’s formatting is kept until its text is changed when the editor cannot be loaded for a note that has some', async () => {
    const failedFormatted =
      'The formatting editor could not be loaded, so this note is open as plain text. Its formatting is kept until its text is changed here.';
    fake.fail = true;
    vi.spyOn(console, 'error').mockImplementation(() => {});
    server({ [notePath]: note({ id: noteId, bodyText: 'Text', runs: [{ text: 'Text', bold: true, italic: false, underline: false }] }) });
    editNote();
    let dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(await within(dialog).findByText(failedFormatted)).toBeTruthy();
    cleanup();

    // Formatting the server keeps but cannot give is formatting all the same.
    server({ [notePath]: note({ id: noteId, bodyText: 'Mac text', formattingKept: true }) });
    editNote();
    dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(await within(dialog).findByText(failedFormatted)).toBeTruthy();
    cleanup();

    // Runs that carry none have none to lose.
    server({ [notePath]: note({ id: noteId, bodyText: 'Plain', runs: [{ text: 'Plain', bold: false, italic: false, underline: false }] }) });
    editNote();
    dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(await within(dialog).findByText('The formatting editor could not be loaded, so this note is open as plain text.')).toBeTruthy();
    cleanup();

    // An editor that fails after formatting was made in it: the formatting made here is kept too.
    fake.fail = false;
    server();
    newNote();
    dialog = await screen.findByRole('dialog', { name: 'New Research Note' });
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Format' }));
    fake.fail = true;
    await userEvent.click(within(dialog).getByRole('button', { name: 'Format' }));
    expect(await within(dialog).findByText(failedFormatted)).toBeTruthy();
    expect((within(dialog).getByRole('textbox', { name: 'Research note body' }) as HTMLTextAreaElement).value).toBe('Bold words');
  });

  it('says a note’s formatting is kept when the server cannot give it, until its text is changed', async () => {
    server({ [notePath]: note({ id: noteId, bodyText: 'Mac text', formattingKept: true }) });
    editNote();
    const dialog = await screen.findByRole('dialog', { name: 'Edit Note' });
    expect(await within(dialog).findByText('This note’s formatting cannot be shown here. It is kept until the note’s text is changed here.')).toBeTruthy();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Format' }));
    expect(within(dialog).queryByText(/It is kept until/)).toBeNull();
  });
});
