// How the collection editor carries a change through (S18d's review): focus back to what opened a
// sheet, and kept on a row Move Down moves; a second Move Down worked out from where the first left
// the row; a switch shown as it was turned, before the server answers, and a second press read from
// it; a refused title kept and sent again; the picker's add made once however fast it is pressed; a
// collection opened by its id in lower case; and a note block the formatting editor cannot show
// edited plain.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { CollectionDetail, CollectionEntry } from '../api/collections';
import type { NoteRun } from '../api/types';
import { renderWithClient, sent } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { CollectionPicker } from './CollectionPicker';

// The formatting editor stands in here, as in the note editor's tests: it shows its text, and reports
// the text unreadable when asked to.
const fake = vi.hoisted(() => ({ unreadable: false }));
vi.mock('../editor/RichTextEditor', async () => {
  const React = await import('react');
  function FakeEditor(props: { runs: NoteRun[] | null; text: string; label: string; onUnreadable: () => void }) {
    const { onUnreadable } = props;
    React.useEffect(() => {
      if (fake.unreadable) onUnreadable();
    }, [onUnreadable]);
    return React.createElement('p', { 'aria-label': props.label }, props.text);
  }
  return { default: FakeEditor };
});

beforeEach(() => {
  fake.unreadable = false;
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader'], userData: true, csrfToken: 't' };
const berlinId = 'C0110000-0000-4000-8000-000000000001';
const path = `/api/v1/me/collections/${berlinId}`;

function entry(fields: Partial<CollectionEntry> & Pick<CollectionEntry, 'id' | 'kind'>): CollectionEntry {
  return {
    sortOrder: 0,
    level: 1,
    depth: 0,
    documentId: '',
    volumeId: '',
    formattingKept: false,
    selectedNoteIds: [],
    selectedHighlightIds: [],
    canIndent: false,
    canOutdent: false,
    leftOut: false,
    isDuplicate: false,
    ...fields,
  };
}

const documentEntry = (id: string, documentId: string) => entry({ id, kind: 'document', volumeId: 'frus1961-63v06', documentId });

function detail(fields: Partial<CollectionDetail> = {}): CollectionDetail {
  return {
    id: berlinId,
    name: 'Berlin',
    listName: 'Berlin',
    introductionFormattingKept: false,
    includeColophon: false,
    includeProjectProvenance: false,
    includeMethodAppendix: false,
    projectIds: [],
    takesHandAddedEntries: true,
    defaultBodyDepth: 'full',
    includeFootnotes: true,
    includeSourceNote: false,
    tocStyle: 'citation',
    applyHighlights: false,
    includeNotes: true,
    includeWordCloud: false,
    defaultIncludeHeadnote: false,
    summariesAvailable: false,
    bodyDepths: ['full', 'index'],
    presets: [],
    prompts: [],
    documentCount: 0,
    volumesNotHeld: [],
    entries: [],
    ...fields,
  };
}

const server = (answers: Record<string, unknown>) =>
  stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/projects': { items: [] }, '/api/v1/me/preferences': {}, ...answers });

/** An answer the test gives when it says, in the order the requests came. */
function held() {
  const waiting: ((value: unknown) => void)[] = [];
  return { answer: () => new Promise((resolve) => waiting.push(resolve)), waiting };
}

describe('the collection editor', () => {
  it('sends focus back to what opened a sheet when the sheet closes', async () => {
    server({ [path]: detail({ entries: [documentEntry('E1', 'd1')] }) });
    renderAt(`/collections/${berlinId}`);
    const settings = await screen.findByRole('button', { name: 'Collection settings' });
    await userEvent.click(settings);
    await userEvent.click(within(screen.getByRole('dialog', { name: 'Collection settings' })).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(document.activeElement).toBe(settings));
    const add = screen.getByRole('button', { name: 'Add Documents…' });
    await userEvent.click(add);
    await userEvent.click(within(screen.getByRole('dialog', { name: 'Add Documents' })).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(document.activeElement).toBe(add));
  });

  it('keeps focus on a row Move Down moves, and works a second Move Down out from where the first left it', async () => {
    const moves = held();
    const fetch = server({ [path]: detail({ entries: [documentEntry('E1', 'd1'), documentEntry('E2', 'd2'), documentEntry('E3', 'd3')] }), [`POST ${path}/move`]: moves.answer });
    renderAt(`/collections/${berlinId}`);
    const actions = await screen.findByRole('button', { name: 'Actions: d1' });
    for (let press = 0; press < 2; press++) {
      await userEvent.click(actions);
      await userEvent.click(within(screen.getByRole('menu')).getByRole('menuitem', { name: 'Move Down' }));
    }
    await waitFor(() => expect(moves.waiting).toHaveLength(1));
    moves.waiting[0]!(detail({ entries: [documentEntry('E2', 'd2'), documentEntry('E1', 'd1'), documentEntry('E3', 'd3')] }));
    await waitFor(() => expect(moves.waiting).toHaveLength(2));
    moves.waiting[1]!(detail({ entries: [documentEntry('E2', 'd2'), documentEntry('E3', 'd3'), documentEntry('E1', 'd1')] }));
    const bodies = () => fetch.mock.calls.filter(([url]) => String(url).endsWith('/move')).map(([, init]) => sent(init).body);
    await waitFor(() => expect(bodies()).toEqual([{ entryId: 'E1', before: 'E3' }, { entryId: 'E1', before: null }]));
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Actions: d1' })));
  });

  it('shows a switch as it was turned before the server answers, and a second press turns it back', async () => {
    const patches = held();
    const fetch = server({ [path]: detail(), [`PATCH ${path}`]: patches.answer });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Collection settings' }));
    const colophon = within(screen.getByRole('dialog', { name: 'Collection settings' })).getByRole('switch', { name: 'Include colophon' }) as HTMLInputElement;
    await userEvent.click(colophon);
    expect(colophon.checked).toBe(true);
    await userEvent.click(colophon);
    expect(colophon.checked).toBe(false);
    // The first answer comes while the second press waits its turn: the second press still shows.
    await waitFor(() => expect(patches.waiting).toHaveLength(1));
    patches.waiting[0]!(detail({ includeColophon: true }));
    await waitFor(() => expect(patches.waiting).toHaveLength(2));
    expect(colophon.checked).toBe(false);
    patches.waiting[1]!(detail({ includeColophon: false }));
    const bodies = fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => sent(init).body);
    expect(bodies).toEqual([{ includeColophon: true }, { includeColophon: false }]);
    await waitFor(() => expect(colophon.checked).toBe(false));
  });

  it('keeps a title the server refused, and sends it again when the field is left', async () => {
    const heading = entry({ id: 'E1', kind: 'heading', text: 'Europe', depth: 1, sectionEnd: 1 });
    let refused = false;
    const fetch = server({
      [path]: detail({ entries: [heading] }),
      [`PATCH ${path}/entries/E1`]: (_url: URL, init?: RequestInit) => {
        if (!refused) {
          refused = true;
          return new ProblemAnswer(503, 'STORE_BUSY', 'The store is busy.');
        }
        return detail({ entries: [{ ...heading, text: sent(init).body.text }] });
      },
    });
    renderAt(`/collections/${berlinId}`);
    const title = (await screen.findByRole('textbox', { name: 'Section heading' })) as HTMLInputElement;
    await userEvent.type(title, ' 1961');
    expect(await screen.findByRole('alert', {}, { timeout: 2000 })).toBeTruthy();
    await userEvent.tab();
    const patches = () => fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => sent(init).body);
    await waitFor(() => expect(patches()).toEqual([{ text: 'Europe 1961' }, { text: 'Europe 1961' }]));
    expect(title.value).toBe('Europe 1961');
  });

  it('follows a collection opened by its id in lower case', async () => {
    const heading = entry({ id: 'E9', kind: 'heading', text: '', depth: 1, sectionEnd: 1 });
    server({ [`/api/v1/me/collections/${berlinId.toLowerCase()}`]: detail(), [`POST ${path}/blocks`]: { collection: detail({ entries: [heading] }), entryIds: ['E9'] } });
    renderAt(`/collections/${berlinId.toLowerCase()}`);
    await userEvent.click(await screen.findByRole('button', { name: /Add documents, a section heading/ }));
    await userEvent.click(within(screen.getByRole('menu')).getByRole('menuitem', { name: 'Add Section Heading' }));
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('textbox', { name: 'Section heading' })));
  });

  it('opens a note block the formatting editor cannot show as plain text, and saves its text plain', async () => {
    fake.unreadable = true;
    const prose = entry({ id: 'E3', kind: 'prose', text: 'Read these together.' });
    const fetch = server({
      [path]: detail({ entries: [prose] }),
      [`PATCH ${path}/entries/E3`]: (_url: URL, init?: RequestInit) => detail({ entries: [{ ...prose, text: sent(init).body.text }] }),
    });
    renderAt(`/collections/${berlinId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Edit: Note block' }));
    const plain = (await screen.findByRole('textbox', { name: 'Note block' })) as HTMLTextAreaElement;
    expect(screen.getByText(/could not be shown with its formatting, so it is open as plain text/)).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(plain));
    await userEvent.type(plain, ' Then the reply.');
    await userEvent.click(screen.getByRole('button', { name: 'Done' }));
    await waitFor(() =>
      expect(fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => sent(init).body).at(-1)).toEqual({
        text: 'Read these together. Then the reply.',
        runs: null,
      }),
    );
  });
});

describe('the Add to Collection picker', () => {
  it('adds the document once, however fast its row is pressed', async () => {
    const adds = held();
    const fetch = server({
      '/api/v1/me/collections': { total: 1, items: [{ id: berlinId, name: 'Berlin', listName: 'Berlin', documentCount: 0, isSmart: false, projectIds: [] }] },
      [`POST ${path}/document`]: adds.answer,
    });
    renderWithClient(<CollectionPicker document={{ volumeId: 'frus1961-63v06', documentId: 'd1' }} onClose={() => {}} />);
    const row = await screen.findByRole('button', { name: /^Berlin/ });
    await userEvent.dblClick(row);
    await userEvent.click(row);
    adds.waiting[0]?.({ added: true, collection: { id: berlinId, name: 'Berlin', listName: 'Berlin', documentCount: 1, isSmart: false, projectIds: [] } });
    expect(await screen.findByText('Added')).toBeTruthy();
    expect(fetch.mock.calls.filter(([url]) => String(url).endsWith('/document'))).toHaveLength(1);
  });
});
