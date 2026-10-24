import { cleanup, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { me, noteSummary } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('Settings ▸ Data', () => {
  it('is a pane beside Tags, offering the app’s Markdown export of every note, counted, as a download of the server’s ZIP', async () => {
    const items = Array.from({ length: 1204 }, (_, index) => noteSummary({ id: `N${index}` }));
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/notes': { total: items.length, items } });
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

  it('says the export is being prepared while the notes are counted, and that there is nothing to export without one', async () => {
    let release: ((list: unknown) => void) | null = null;
    stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/notes': () => new Promise((resolve) => (release = resolve)) });
    renderAt('/settings/data');
    expect(await screen.findByText('Preparing export…')).toBeTruthy();
    await waitFor(() => expect(release).not.toBeNull());
    release!({ total: 0, items: [] });
    expect(await screen.findByText('No research notes to export.')).toBeTruthy();
    expect(screen.queryByRole('link', { name: /Export Notes/ })).toBeNull();
  });

  it('says that a server keeping no user data keeps nothing to export, and asks it for nothing', async () => {
    const fetch = stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    renderAt('/settings/data');
    expect(await screen.findByText('This server keeps no tags or other research data of yours: it is read-only.')).toBeTruthy();
    expect(fetch.mock.calls.some(([url]) => String(url).startsWith('/api/v1/me/'))).toBe(false);
  });
});
