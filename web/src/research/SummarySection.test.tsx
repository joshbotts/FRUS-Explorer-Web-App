import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail, Summary } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { documentPaths, me, sent, summary } from '../test/notes';
import { coverage, ready, renderAt, stubServer } from '../test/renderRoute';

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

function reader(answers: Record<string, unknown>) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
    '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    '/api/v1/me': me,
    '/api/v1/me/volumes/frus1961-63v06/documents/d1/tags': { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    '/api/v1/me/volumes/frus1961-63v06/documents/d1/highlights': { volumeId: 'frus1961-63v06', documentId: 'd1', renderingVersion: 'v1', items: [] },
    [documentPaths.notes]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [documentPaths.summaries]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    ...answers,
  });
}

const documentSummaries = (items: Summary[]) => ({ volumeId: 'frus1961-63v06', documentId: 'd1', items });

/** The rail's Summary section, once it is drawn. */
async function section() {
  const rail = await screen.findByRole('complementary', { name: 'Research' });
  return { rail, region: () => rail.querySelector<HTMLElement>('#research-summary')! };
}

beforeEach(() => {
  resetPreferences();
  window.localStorage.clear();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('the rail’s Summary', () => {
  it('shows the newest summary, its label by who wrote it and its prompt while the user has it, and the Mac’s history control', async () => {
    reader({
      [documentPaths.summaries]: documentSummaries([
        summary({ id: 'A', responseText: 'The newest, edited.', authorship: 'aiEdited', promptName: 'Meeting Record', editable: false }),
        summary({ id: 'B', responseText: 'Mine.', authorship: 'userWritten' }),
        summary({ id: 'C', responseText: '{"summary": "The model’s."}', authorship: 'aiGenerated', responseFormat: 'structured', editable: false }),
      ]),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { region } = await section();
    await within(region()).findByText('The newest, edited.');
    const header = () => region().querySelector('.summary-header')!;
    expect(header().querySelector('.summary-label')?.textContent).toBe('AI · edited');
    expect(header().querySelector('.summary-prompt')?.textContent).toBe('· Meeting Record');
    const older = within(region()).getByRole('button', { name: 'Older summary' });
    const newer = within(region()).getByRole('button', { name: 'Newer summary' });
    expect([older.title, newer.title]).toEqual(['Show older summary', 'Show newer summary']);
    expect(header().textContent).toContain('1/3');
    expect(within(region()).getByText('Summary 1 of 3').className).toBe('visually-hidden');
    expect(newer.getAttribute('aria-disabled')).toBe('true');
    // Not the user's own: nothing to change.
    expect(within(region()).queryByRole('button', { name: 'Edit…' })).toBeNull();

    await userEvent.click(older);
    expect(within(region()).getByText('Mine.')).toBeTruthy();
    expect(header().querySelector('.summary-label')?.textContent).toBe('Yours');
    expect(header().querySelector('.summary-prompt')).toBeNull();
    expect(within(region()).getByRole('button', { name: 'Edit…' })).toBeTruthy();
    await userEvent.click(older);
    // A structured summary's text is shown raw, as the app shows it.
    expect(within(region()).getByText('{"summary": "The model’s."}')).toBeTruthy();
    expect(header().querySelector('.summary-label')?.textContent).toBe('AI summary');
    expect(older.getAttribute('aria-disabled')).toBe('true');
    await userEvent.click(older);
    expect(header().textContent).toContain('3/3');
    expect(document.activeElement).toBe(older);
  });

  it('says a summary from a research database is one, in its prompt’s place, read-only (S16e)', async () => {
    reader({
      [documentPaths.summaries]: documentSummaries([
        summary({
          id: 'R',
          promptId: '0EB00000-0000-4000-8000-000000000002',
          responseText: 'The newest summary the index kept.',
          authorship: 'aiGenerated',
          editable: false,
          fromResearchDatabase: true,
        }),
      ]),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { region } = await section();
    await within(region()).findByText('The newest summary the index kept.');
    const header = region().querySelector('.summary-header')!;
    expect(header.querySelector('.summary-label')?.textContent).toBe('AI summary');
    expect([...header.querySelectorAll('.summary-prompt')].map((part) => part.textContent)).toEqual(['· From a research database']);
    expect(within(region()).queryByRole('button', { name: 'Edit…' })).toBeNull();
  });

  it('previews the summary shown in its header when it is closed, and shows no control for one summary', async () => {
    reader({ [documentPaths.summaries]: documentSummaries([summary({ id: 'A', responseText: `  ${'Long words '.repeat(10)}` })]) });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { rail, region } = await section();
    await within(region()).findByText(/Long words/);
    expect(within(region()).queryByRole('button', { name: 'Older summary' })).toBeNull();
    await userEvent.click(within(rail).getByRole('button', { name: 'Summary' }));
    const preview = `${'Long words '.repeat(10).trim().slice(0, 80)}…`;
    const header = within(rail).getByRole('button', { name: `Summary, ${preview}` });
    expect(header.querySelector('.disclosure-preview')?.textContent).toBe(preview);
  });

  it('writes the researcher’s own summary, the web’s own, and shows the newest after it', async () => {
    let items: Summary[] = [summary({ id: 'OLD', responseText: 'Older.', authorship: 'aiGenerated', editable: false })];
    const fetch = reader({
      [documentPaths.summaries]: () => documentSummaries(items),
      [`POST ${documentPaths.summaries}`]: (_: URL, init?: RequestInit) => {
        const made = summary({ id: 'NEW', responseText: sent(init).body.responseText });
        items = [made, ...items];
        return made;
      },
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { region } = await section();
    await within(region()).findByText('Older.');
    const write = within(region()).getByRole('button', { name: 'Write a Summary' });
    await userEvent.click(write);
    const dialog = await screen.findByRole('dialog', { name: 'Write a Summary' });
    const field = within(dialog).getByRole('textbox', { name: 'Write a Summary' });
    expect(document.activeElement).toBe(field);
    // Nothing but spaces and line breaks is no summary.
    await userEvent.type(field, '  {Enter} ');
    expect(within(dialog).getByRole('button', { name: 'Save' }).getAttribute('aria-disabled')).toBe('true');
    await userEvent.clear(field);
    await userEvent.type(field, 'My reading of it.');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(await within(region()).findByText('My reading of it.')).toBeTruthy();
    expect(region().querySelector('.summary-label')?.textContent).toBe('Yours');
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'POST').map(([url, init]) => [String(url), sent(init).body])).toEqual([
      [documentPaths.summaries, { responseText: 'My reading of it.' }],
    ]);
    await waitFor(() => expect(document.activeElement).toBe(within(region()).getByRole('button', { name: 'Write a Summary' })));
  });

  it('edits and deletes the researcher’s own, Delete… asking first with Cancel first', async () => {
    let items: Summary[] = [summary({ id: 'MINE', responseText: 'First draft.' })];
    const fetch = reader({
      [documentPaths.summaries]: () => documentSummaries(items),
      'PUT /api/v1/me/summaries/MINE': (_: URL, init?: RequestInit) => {
        items = [summary({ id: 'MINE', responseText: sent(init).body.responseText })];
        return items[0];
      },
      'DELETE /api/v1/me/summaries/MINE': () => {
        items = [];
        return null;
      },
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { rail, region } = await section();
    await userEvent.click(await within(region()).findByRole('button', { name: 'Edit…' }));
    let dialog = await screen.findByRole('dialog', { name: 'Edit Summary' });
    const field = within(dialog).getByRole('textbox');
    expect((field as HTMLTextAreaElement).value).toBe('First draft.');
    await userEvent.clear(field);
    await userEvent.type(field, 'Second draft.');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await within(region()).findByText('Second draft.')).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(within(region()).getByRole('button', { name: 'Edit…' })));

    await userEvent.click(within(region()).getByRole('button', { name: 'Delete…' }));
    dialog = await screen.findByRole('alertdialog', { name: 'Delete Summary?' });
    expect(within(dialog).getByText('This summary will be permanently deleted.')).toBeTruthy();
    expect(document.activeElement).toBe(within(dialog).getByRole('button', { name: 'Cancel' }));
    fireEvent(dialog, new Event('cancel', { cancelable: true }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(screen.getByRole('complementary', { name: 'Research' })).toBe(rail);
    await userEvent.click(within(region()).getByRole('button', { name: 'Delete…' }));
    dialog = await screen.findByRole('alertdialog', { name: 'Delete Summary?' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(within(region()).queryByText('Second draft.')).toBeNull());
    await waitFor(() => expect(document.activeElement).toBe(within(region()).getByRole('button', { name: 'Write a Summary' })));
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'PUT' || init?.method === 'DELETE').map(([url, init]) => [init?.method, String(url), sent(init).body])).toEqual([
      ['PUT', '/api/v1/me/summaries/MINE', { responseText: 'Second draft.' }],
      ['DELETE', '/api/v1/me/summaries/MINE', undefined],
    ]);
  });

  it('shows at most the 20 newest, as the app’s rail does', async () => {
    reader({
      [documentPaths.summaries]: documentSummaries(Array.from({ length: 25 }, (_, index) => summary({ id: `S${index}`, responseText: `Summary ${index}` }))),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const { region } = await section();
    await within(region()).findByText('Summary 0');
    expect(region().querySelector('.summary-header')?.textContent).toContain('1/20');
  });
});
