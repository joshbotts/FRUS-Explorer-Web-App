import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { NoteList } from '../api/types';
import { exportContents, me, noteSummary } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const noNotes: NoteList = { total: 0, items: [] };

/** What the browser is handed to save: each file's address and name, its bytes by address. */
function savedFiles() {
  const files = new Map<string, Blob>();
  const saved: { name: string; file: Blob | undefined }[] = [];
  // jsdom has no object URLs: the page's are these.
  URL.createObjectURL = vi.fn((file: Blob) => {
    const address = `blob:export-${files.size}`;
    files.set(address, file);
    return address;
  });
  URL.revokeObjectURL = vi.fn();
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
    saved.push({ name: this.download, file: files.get(this.getAttribute('href') ?? '') });
  });
  return saved;
}

describe('Settings ▸ Data', () => {
  it('is a pane beside Tags, offering the app’s Markdown export of every note, counted, as a download of the server’s ZIP', async () => {
    const items = Array.from({ length: 1204 }, (_, index) => noteSummary({ id: `N${index}` }));
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': exportContents(), '/api/v1/me/notes': { total: items.length, items } });
    renderAt('/settings/data');
    expect(await screen.findByRole('heading', { level: 1, name: 'Data' })).toBeTruthy();
    const panes = screen.getByRole('navigation', { name: 'Settings' });
    expect(within(panes).getAllByRole('link').map((link) => [link.textContent, link.getAttribute('aria-current')])).toEqual([
      ['Tags', null],
      ['Projects', null],
      ['Research Sessions', null],
      ['Reading', null],
      ['Data', 'page'],
    ]);
    const download = await screen.findByRole('link', { name: 'Export Notes as Markdown (1,204)' });
    expect(download.getAttribute('href')).toBe('/api/v1/me/notes/export');
    expect(download.hasAttribute('download')).toBe(true);
    expect(
      screen.getByText('One Markdown file per research note, with a citation and link back to the source document. Compatible with Obsidian and similar note-taking tools.'),
    ).toBeTruthy();
    expect(document.title).toBe('Data – FRUS Explorer Light');
  });

  it('counts what an export carries as the app’s Contents does, in its order and words, a row of tags with their assignments', async () => {
    const contents = exportContents({
      ResearchNote: 31,
      UserTag: 12,
      DocumentTagAssignment: 1188,
      DocumentHighlight: 9,
      Collection: 3,
      CollectionEntry: 40,
      SummarizationPrompt: 2,
      Project: 4,
      ArchiveVisitPlan: 1,
      ArchiveVisitDocument: 5,
      SavedSearch: 6,
      SyncedPreferences: 1,
      ReadingHistoryEntry: 2500,
      SearchHistoryEntry: 12,
      GeneratedSummary: 4321,
    });
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': contents, '/api/v1/me/notes': noNotes });
    renderAt('/settings/data');
    const region = await screen.findByRole('region', { name: 'Contents' });
    const table = await within(region).findByRole('table', { name: 'Contents' });
    const rows = within(table)
      .getAllByRole('row')
      .map((row) => [...row.querySelectorAll('th, td')].map((cell) => cell.textContent));
    // Each count as the app's sheet interpolates it, no digit grouped.
    expect(rows).toEqual([
      ['Research Notes', '31'],
      ['Tags & Assignments', '1200'],
      ['Highlights', '9'],
      ['Collections', '3'],
      ['Custom Prompts', '2'],
      ['Projects', '4'],
      ['Archives Visits', '1'],
      ['Saved Searches', '6'],
      ['Working Corpora', '0'],
      ['Volume Scopes', '0'],
      ['Classification Corrections', '0'],
      ['Person Corrections', '0'],
      ['Reviewed Changes', '0'],
      ['Suggested Next Leads', '0'],
      ['Synced Settings', '1'],
      ['Documents Visited', '2500'],
      ['Searches Executed', '12'],
      ['Collections Exported', '0'],
    ]);
    expect(within(table).getAllByRole('rowheader')).toHaveLength(18);
    // The switch's footer is a localized string, which groups them.
    expect(screen.getByText('Adds all 4,321 generated summaries to the JSON export. Off by default since AI output can be large.')).toBeTruthy();
  });

  it('saves the server’s JSON file, with every summary once the app’s switch is on, and says what the file holds', async () => {
    const saved = savedFiles();
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/export/contents': exportContents({ GeneratedSummary: 1 }),
      '/api/v1/me/notes': noNotes,
      '/api/v1/me/export': (url: URL) => ({ formatVersion: 7, summaries: url.search === '?includeGeneratedSummaries=true' ? [{}] : [] }),
    });
    const user = userEvent.setup();
    renderAt('/settings/data');
    const action = await screen.findByRole('button', { name: 'Export as JSON' });
    const toggle = screen.getByRole('checkbox', { name: 'Include AI-Generated Summaries' });
    expect((toggle as HTMLInputElement).checked).toBe(false);
    await user.click(action);
    await waitFor(() => expect(saved).toHaveLength(1));
    expect(saved[0]!.name).toBe('frus-research-export.json');
    expect(JSON.parse(await saved[0]!.file!.text())).toEqual({ formatVersion: 7, summaries: [] });
    await user.click(toggle);
    await user.click(action);
    await waitFor(() => expect(saved).toHaveLength(2));
    expect(JSON.parse(await saved[1]!.file!.text())).toEqual({ formatVersion: 7, summaries: [{}] });
    expect(fetch.mock.calls.map(([url]) => String(url)).filter((url) => url.startsWith('/api/v1/me/export?') || url === '/api/v1/me/export')).toEqual([
      '/api/v1/me/export',
      '/api/v1/me/export?includeGeneratedSummaries=true',
    ]);
    expect(screen.getByText(/^One JSON file with your notes, tags, highlights, collections, custom prompts, projects, archive visit plans/)).toBeTruthy();
    expect(screen.getByText('Adds all 1 generated summaries to the JSON export. Off by default since AI output can be large.')).toBeTruthy();
    expect(screen.queryByRole('alert')).toBeNull();
  });

  it('says it is preparing the export while the server writes it, and why it could not, in the app’s words', async () => {
    const saved = savedFiles();
    let release: ((answer: unknown) => void) | null = null;
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/export/contents': exportContents(),
      '/api/v1/me/notes': noNotes,
      '/api/v1/me/export': () => new Promise((resolve) => (release = resolve)),
    });
    const user = userEvent.setup();
    renderAt('/settings/data');
    const action = await screen.findByRole('button', { name: 'Export as JSON' });
    await user.click(action);
    await waitFor(() => expect(release).not.toBeNull());
    expect(action.hasAttribute('disabled')).toBe(true);
    expect(screen.getAllByRole('status').map((status) => status.textContent)).toContain('Preparing export…');
    release!(new ProblemAnswer(500, 'EXPORT_FAILED', 'The export could not be written: the row of notes holds a project_ids that is not a UUID.'));
    expect((await screen.findByRole('alert')).textContent).toBe(
      'Couldn’t prepare the export: The export could not be written: the row of notes holds a project_ids that is not a UUID.',
    );
    expect(action.hasAttribute('disabled')).toBe(false);
    expect(saved).toHaveLength(0);
  });

  it('says the export is being prepared while it is counted, and that there are no notes to export without one', async () => {
    let release: ((list: NoteList) => void) | null = null;
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/export/contents': exportContents(),
      '/api/v1/me/notes': () => new Promise((resolve) => (release = resolve)),
    });
    renderAt('/settings/data');
    await screen.findByRole('table', { name: 'Contents' });
    expect(screen.getAllByRole('status').map((status) => status.textContent)).toContain('Preparing export…');
    expect(screen.queryByRole('link', { name: /Export Notes/ })).toBeNull();
    await waitFor(() => expect(release).not.toBeNull());
    release!(noNotes);
    expect(await screen.findByText('No research notes to export.')).toBeTruthy();
    expect(screen.queryByRole('link', { name: /Export Notes/ })).toBeNull();
  });

  it('says why the export cannot be counted, and offers the notes’ export still', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/export/contents': new ProblemAnswer(500, 'EXPORT_FAILED', 'The export could not be written.'),
      '/api/v1/me/notes': { total: 1, items: [noteSummary({ id: 'N1' })] },
    });
    renderAt('/settings/data');
    const region = await screen.findByRole('region', { name: 'Contents' });
    expect((await within(region).findByRole('alert')).textContent).toBe('The export could not be written.');
    expect(await screen.findByRole('link', { name: 'Export Notes as Markdown (1)' })).toBeTruthy();
  });

  it('says that a server keeping no user data keeps nothing to export, and asks it for nothing', async () => {
    const fetch = stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    renderAt('/settings/data');
    expect(await screen.findByText('This server keeps no tags or other research data of yours: it is read-only.')).toBeTruthy();
    expect(fetch.mock.calls.some(([url]) => String(url).startsWith('/api/v1/me/'))).toBe(false);
  });
});
