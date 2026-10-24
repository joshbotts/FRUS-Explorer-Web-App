import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail, DocumentTags, Me, UserTag } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { coverage, ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

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

export const me: Me = {
  userId: 'owner',
  displayName: 'Owner',
  auth: 'none',
  roles: ['reader', 'curator', 'admin'],
  userData: true,
  csrfToken: 'token-1',
};

const berlin: UserTag = { id: 'B0000000-0000-4000-8000-000000000000', name: 'Berlin' };
const revisit: UserTag = { id: 'R0000000-0000-4000-8000-000000000000', name: 'Revisit' };
const tagsPath = '/api/v1/me/volumes/frus1961-63v06/documents/d1/tags';

function documentTags(items: UserTag[]): DocumentTags {
  return { volumeId: 'frus1961-63v06', documentId: 'd1', items };
}

/** The reader's answers, with the user's and the document's tags as given. */
function reader(answers: Record<string, unknown>) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
    '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    '/api/v1/me': me,
    ...answers,
  });
}

/** What a change sent: its body as JSON, and its token. */
function sent(init?: RequestInit) {
  const headers = init?.headers as Record<string, string>;
  return { body: init?.body ? JSON.parse(String(init.body)) : undefined, token: headers['X-CSRF-Token'], type: headers['Content-Type'] };
}

beforeEach(() => {
  resetPreferences();
  window.localStorage.removeItem('frus.research.tags');
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('the Research rail', () => {
  it('opens from its toggle, with its Tags section closed until it is opened, and then as it was left', async () => {
    reader({ [tagsPath]: documentTags([berlin]) });
    renderAt('/doc/frus1961-63v06/d1');
    const toggle = await screen.findByRole('button', { name: 'Research' });
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    await userEvent.click(toggle);
    const rail = await screen.findByRole('complementary', { name: 'Research' });
    expect(within(rail).getByRole('heading', { name: 'Research' })).toBe(document.activeElement);
    // The section's badge counts the document's tags, as the app's does, before it is opened.
    const section = await within(rail).findByRole('button', { name: 'Tags, 1 tag' });
    expect(section.getAttribute('aria-expanded')).toBe('false');
    expect(within(rail).queryByRole('button', { name: 'Remove Berlin' })).toBeNull();
    await userEvent.click(section);
    expect(section.getAttribute('aria-expanded')).toBe('true');
    expect(within(rail).getByRole('button', { name: 'Remove Berlin' })).toBeTruthy();
    expect(window.localStorage.getItem('frus.research.tags')).toBe('open');

    await userEvent.click(within(rail).getByRole('button', { name: 'Close' }));
    expect(screen.queryByRole('complementary', { name: 'Research' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Research' }));
  });

  it('is not offered by a server that keeps no user data', async () => {
    reader({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await screen.findByRole('button', { name: 'Cite' });
    await waitFor(() => expect(screen.queryByRole('complementary', { name: 'Research' })).toBeNull());
    expect(screen.queryByRole('button', { name: 'Research' })).toBeNull();
  });

  it('takes a tag off the document with its ×, as the app’s chip does', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    const fetch = reader({
      [tagsPath]: documentTags([berlin, revisit]),
      [`DELETE ${tagsPath}/${berlin.id}`]: documentTags([revisit]),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    const remove = await screen.findByRole('button', { name: 'Remove Berlin' });
    await userEvent.click(remove);
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Remove Berlin' })).toBeNull());
    expect(screen.getByRole('button', { name: 'Remove Revisit' })).toBeTruthy();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Add Tag' }));
    const call = fetch.mock.calls.find(([, init]) => init?.method === 'DELETE');
    expect(sent(call?.[1]).token).toBe('token-1');
  });

  it('tags the document in the picker: a new tag is made, switched on and listed first, and Done gives the document the tags switched on', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    const primary: UserTag = { id: 'P0000000-0000-4000-8000-000000000000', name: 'Primary source' };
    let all = [berlin, revisit];
    const fetch = reader({
      [tagsPath]: documentTags([berlin]),
      '/api/v1/me/tags': () => ({ total: all.length, items: all }),
      'POST /api/v1/me/tags': (_: URL, init?: RequestInit) => {
        expect(sent(init)).toEqual({ body: { name: 'Primary source' }, token: 'token-1', type: 'application/json' });
        all = [berlin, primary, revisit];
        return primary;
      },
      [`PUT ${tagsPath}`]: (_: URL, init?: RequestInit) => documentTags(all.filter((tag) => sent(init).body.tagIds.includes(tag.id))),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Add Tag' }));
    const picker = await screen.findByRole('dialog', { name: 'Tags — Doc 1' });
    const field = within(picker).getByRole('textbox', { name: 'New tag name' });
    expect(document.activeElement).toBe(field);
    expect(within(picker).getByRole('button', { name: 'Add' })).toHaveProperty('disabled', true);
    await within(picker).findByRole('checkbox', { name: 'Berlin' });
    expect(within(picker).getByRole('checkbox', { name: 'Berlin' })).toHaveProperty('checked', true);
    expect(within(picker).getByRole('checkbox', { name: 'Revisit' })).toHaveProperty('checked', false);

    await userEvent.type(field, '  Primary source {Enter}');
    const made = await within(picker).findByRole('checkbox', { name: /^Primary source\b/ });
    expect(made).toHaveProperty('checked', true);
    expect(made.closest('label')?.querySelector('.badge')?.textContent).toBe(', New');
    await waitFor(() => expect(document.activeElement).toBe(made));
    expect(within(picker).getAllByRole('checkbox').map((box) => box.closest('label')?.textContent?.trim())).toEqual([
      'Primary source, New',
      'Berlin',
      'Revisit',
    ]);
    expect(within(picker).getByRole('status').textContent).toBe('Tag Primary source created and selected');

    await userEvent.click(within(picker).getByRole('checkbox', { name: 'Berlin' }));
    await userEvent.click(within(picker).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    const put = fetch.mock.calls.find(([, init]) => init?.method === 'PUT');
    expect(sent(put?.[1]).body).toEqual({ tagIds: [primary.id] });
    expect(await screen.findByRole('button', { name: 'Remove Primary source' })).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Remove Berlin' })).toBeNull();
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Add Tag' }));
  });

  it('deletes the tags made in the picker when it is cancelled, as the app’s Cancel does', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    const made: UserTag = { id: 'N0000000-0000-4000-8000-000000000000', name: 'Draft' };
    const fetch = reader({
      [tagsPath]: documentTags([]),
      '/api/v1/me/tags': { total: 0, items: [] },
      'POST /api/v1/me/tags': made,
      [`DELETE /api/v1/me/tags/${made.id}`]: null,
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Add Tag' }));
    const picker = await screen.findByRole('dialog');
    expect(within(picker).getByText('No user tags yet. Type a name above to create one.')).toBeTruthy();
    await userEvent.type(within(picker).getByRole('textbox', { name: 'New tag name' }), 'Draft');
    await userEvent.click(within(picker).getByRole('button', { name: 'Add' }));
    await within(picker).findByRole('checkbox', { name: /^Draft\b/ });
    await userEvent.click(within(picker).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.some(([url, init]) => init?.method === 'DELETE' && String(url).endsWith(`/api/v1/me/tags/${made.id}`))).toBe(true);
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'PUT')).toBe(false);
  });

  it('asks for a new token and sends the change once more when the server no longer knows the one it has', async () => {
    window.localStorage.setItem('frus.research.tags', 'open');
    let tokens = 0;
    const fetch = reader({
      '/api/v1/me': () => ({ ...me, csrfToken: `token-${++tokens}` }),
      [tagsPath]: documentTags([berlin]),
      [`DELETE ${tagsPath}/${berlin.id}`]: (_: URL, init?: RequestInit) =>
        sent(init).token === 'token-2' ? documentTags([]) : new ProblemAnswer(403, 'CSRF_TOKEN_INVALID', 'No longer current.'),
    });
    renderAt('/doc/frus1961-63v06/d1?rail=research');
    await userEvent.click(await screen.findByRole('button', { name: 'Remove Berlin' }));
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Remove Berlin' })).toBeNull());
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'DELETE').map(([, init]) => sent(init).token)).toEqual(['token-1', 'token-2']);
    expect(screen.queryByRole('alert')).toBeNull();
  });
});
