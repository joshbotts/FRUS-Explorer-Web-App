import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ExportContents } from '../api/types';
import { exportContents, me } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('Settings ▸ Data', () => {
  it('is a pane beside Tags, offering the app’s Markdown export of every note, counted, as a download of the server’s ZIP', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': exportContents({ ResearchNote: 1204 }) });
    renderAt('/settings/data');
    expect(await screen.findByRole('heading', { level: 1, name: 'Data' })).toBeTruthy();
    const panes = screen.getByRole('navigation', { name: 'Settings' });
    expect(within(panes).getAllByRole('link').map((link) => [link.textContent, link.getAttribute('aria-current')])).toEqual([
      ['Tags', null],
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
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': contents });
    renderAt('/settings/data');
    const region = await screen.findByRole('region', { name: 'Contents' });
    const table = await within(region).findByRole('table', { name: 'Contents' });
    const rows = within(table)
      .getAllByRole('row')
      .map((row) => [...row.querySelectorAll('th, td')].map((cell) => cell.textContent));
    expect(rows).toEqual([
      ['Research Notes', '31'],
      ['Tags & Assignments', '1,200'],
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
      ['Documents Visited', '2,500'],
      ['Searches Executed', '12'],
      ['Collections Exported', '0'],
    ]);
    expect(within(table).getAllByRole('rowheader')).toHaveLength(18);
    expect(screen.getByText('Adds all 4,321 generated summaries to the JSON export. Off by default since AI output can be large.')).toBeTruthy();
  });

  it('exports the server’s JSON file, with every summary once the app’s switch is on, and says what the file holds', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': exportContents({ GeneratedSummary: 1 }) });
    const user = userEvent.setup();
    renderAt('/settings/data');
    const action = await screen.findByRole('link', { name: 'Export as JSON' });
    expect(action.getAttribute('href')).toBe('/api/v1/me/export');
    expect(action.hasAttribute('download')).toBe(true);
    const toggle = screen.getByRole('checkbox', { name: 'Include AI-Generated Summaries' });
    expect((toggle as HTMLInputElement).checked).toBe(false);
    await user.click(toggle);
    expect(action.getAttribute('href')).toBe('/api/v1/me/export?includeGeneratedSummaries=true');
    await user.click(toggle);
    expect(action.getAttribute('href')).toBe('/api/v1/me/export');
    expect(screen.getByText(/^One JSON file with your notes, tags, highlights, collections, custom prompts, projects, archive visit plans/)).toBeTruthy();
    expect(screen.getByText('Adds all 1 generated summaries to the JSON export. Off by default since AI output can be large.')).toBeTruthy();
  });

  it('says the export is being prepared while it is counted, and that there are no notes to export without one', async () => {
    let release: ((contents: ExportContents) => void) | null = null;
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': () => new Promise((resolve) => (release = resolve)) });
    renderAt('/settings/data');
    expect((await screen.findByRole('status')).textContent).toBe('Preparing export…');
    expect(screen.getAllByText('Preparing export…')).toHaveLength(1);
    expect(screen.queryByRole('link', { name: /Export Notes/ })).toBeNull();
    await waitFor(() => expect(release).not.toBeNull());
    release!(exportContents());
    expect(await screen.findByText('No research notes to export.')).toBeTruthy();
    expect(screen.queryByRole('link', { name: /Export Notes/ })).toBeNull();
    expect(screen.getByRole('link', { name: 'Export as JSON' })).toBeTruthy();
  });

  it('says why the export cannot be counted', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/export/contents': new ProblemAnswer(500, 'EXPORT_FAILED', 'The export could not be written.'),
    });
    renderAt('/settings/data');
    const region = await screen.findByRole('region', { name: 'Contents' });
    expect((await within(region).findByRole('alert')).textContent).toBe('The export could not be written.');
    expect(screen.queryByRole('link', { name: /Export Notes/ })).toBeNull();
  });

  it('says that a server keeping no user data keeps nothing to export, and asks it for nothing', async () => {
    const fetch = stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    renderAt('/settings/data');
    expect(await screen.findByText('This server keeps no tags or other research data of yours: it is read-only.')).toBeTruthy();
    expect(fetch.mock.calls.some(([url]) => String(url).startsWith('/api/v1/me/'))).toBe(false);
  });
});
