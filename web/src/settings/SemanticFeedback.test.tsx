// Settings ▸ Data's Semantic Match Feedback (PLAN's S26d), over a stubbed server: the app's screen as a section of the
// pane, the summary's counts and each era's, the footer naming where the file goes, Download Feedback File the server's
// file, and Clear Recorded Feedback after the app's question; both unavailable while no verdict is recorded.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SemanticFeedbackSummary } from '../api/semanticFeedback';
import { exportContents, me } from '../test/notes';
import { ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const summary: SemanticFeedbackSummary = {
  total: 3,
  helpful: 2,
  byEra: [
    { era: '0', label: 'Before 1900', count: 1 },
    { era: '2', label: '1945–1990', count: 2 },
  ],
  address: 'feedback@frusexplorer.app',
  fileName: 'frus-semantic-feedback.json',
};
const none: SemanticFeedbackSummary = { ...summary, total: 0, helpful: 0, byEra: [] };
const base = { '/readyz': ready, '/api/v1/me': me, '/api/v1/me/export/contents': exportContents(), '/api/v1/me/notes': { total: 0, items: [] } };

describe('Semantic Match Feedback', () => {
  it('lists the verdicts as the app’s screen does, offers their file, and clears them after the app’s question', async () => {
    let cleared = false;
    const fetch = stubServer({
      ...base,
      '/api/v1/me/semantic-feedback': () => (cleared ? none : summary),
      'DELETE /api/v1/me/semantic-feedback': () => {
        cleared = true;
        return { removed: 3 };
      },
    });
    const user = userEvent.setup();
    renderAt('/settings/data');
    const section = (await screen.findByRole('heading', { level: 2, name: 'Semantic Match Feedback' })).closest('section')!;
    for (const header of ['About this experiment', 'How to give feedback', 'Recorded with your account']) {
      expect(within(section).getByRole('heading', { level: 3, name: header })).toBeTruthy();
    }
    expect(within(section).getByText(/^Open the Feedback menu of any related document that shows a Semantic match score/)).toBeTruthy();
    const counts = await within(section).findByText('Verdicts recorded');
    const rows = [...counts.closest('dl')!.querySelectorAll('div')].map((row) => row.textContent);
    expect(rows).toEqual(['Verdicts recorded3', 'Marked helpful2', 'Before 19001', '1945–19902']);
    expect(within(section).getByText(/then send the file to feedback@frusexplorer\.app\.$/)).toBeTruthy();
    const file = within(section).getByRole('link', { name: 'Download Feedback File' });
    expect(file.getAttribute('href')).toBe('/api/v1/me/semantic-feedback/file');
    expect(file.getAttribute('download')).toBe('frus-semantic-feedback.json');

    const clear = within(section).getByRole('button', { name: 'Clear Recorded Feedback' });
    await user.click(clear);
    const ask = within(screen.getByRole('alertdialog', { name: 'Delete every recorded verdict on this server?' }));
    // Cancel first, and it deletes nothing.
    expect(document.activeElement).toBe(ask.getByRole('button', { name: 'Cancel' }));
    await user.click(ask.getByRole('button', { name: 'Cancel' }));
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(false);
    expect(document.activeElement).toBe(clear);
    await user.click(clear);
    await user.click(within(screen.getByRole('alertdialog')).getByRole('button', { name: 'Delete Feedback' }));
    await waitFor(() => expect(within(section).getByText('Every recorded verdict was deleted.')).toBeTruthy());
    await waitFor(() => expect((within(section).getByRole('button', { name: 'Clear Recorded Feedback' }) as HTMLButtonElement).disabled).toBe(true));
    expect((within(section).getByRole('button', { name: 'Download Feedback File' }) as HTMLButtonElement).disabled).toBe(true);
    expect(document.activeElement).toBe(within(section).getByRole('heading', { level: 2, name: 'Semantic Match Feedback' }));
  });

  it('offers neither the file nor Clear while no verdict is recorded', async () => {
    stubServer({ ...base, '/api/v1/me/semantic-feedback': none });
    renderAt('/settings/data');
    const section = (await screen.findByRole('heading', { level: 2, name: 'Semantic Match Feedback' })).closest('section')!;
    await within(section).findByText('Verdicts recorded');
    expect((within(section).getByRole('button', { name: 'Download Feedback File' }) as HTMLButtonElement).disabled).toBe(true);
    expect((within(section).getByRole('button', { name: 'Clear Recorded Feedback' }) as HTMLButtonElement).disabled).toBe(true);
  });
});
