import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Me, UserTag } from '../api/types';
import { ready, renderAt, stubServer } from '../test/renderRoute';

const me: Me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const berlin: UserTag = { id: 'B0000000-0000-4000-8000-000000000000', name: 'Berlin' };
const cold: UserTag = { id: 'C0000000-0000-4000-8000-000000000000', name: 'Cold War' };

/** The server's answers, with a list of tags the test changes as the server would. */
function settings(initial: UserTag[], answers: Record<string, unknown> = {}) {
  const state = { tags: initial };
  const fetch = stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/tags': () => ({ total: state.tags.length, items: state.tags }),
    ...answers,
  });
  return { fetch, state };
}

function body(init?: RequestInit): unknown {
  return init?.body ? JSON.parse(String(init.body)) : undefined;
}

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('Settings ▸ Tags', () => {
  it('opens at its one pane, and lists the tags with New Tag… after them and the app’s footer', async () => {
    settings([berlin, cold]);
    const { router } = renderAt('/settings');
    expect(await screen.findByRole('heading', { level: 1, name: 'Tags' })).toBeTruthy();
    expect(router.state.location.pathname).toBe('/settings/tags');
    expect(within(screen.getByRole('navigation', { name: 'Settings' })).getByRole('link', { name: 'Tags' }).getAttribute('aria-current')).toBe('page');
    const list = await screen.findByRole('list', { name: 'Tags' });
    const rows = within(list).getAllByRole('button').filter((button) => button.classList.contains('settings-row'));
    expect(rows.map((row) => row.textContent)).toEqual(['Berlin›', 'Cold War›']);
    // Each row's Move commands, those that would move it (S17f).
    expect(within(list).getAllByRole('button', { name: /^Move/ }).map((button) => button.getAttribute('aria-label'))).toEqual([
      'Move Down: Berlin',
      'Move to Top: Cold War',
      'Move Up: Cold War',
    ]);
    expect(screen.getByRole('button', { name: 'New Tag…' })).toBeTruthy();
    expect(screen.getByText('Tags are global labels you apply to research notes and documents. They are not scoped to a project.')).toBeTruthy();
  });

  it('says where tags come from when there are none, and that a read-only server keeps none', async () => {
    settings([]);
    renderAt('/settings/tags');
    expect(await screen.findByText(/^No tags yet\. Tags are the labels you apply/)).toBeTruthy();
    cleanup();
    stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    renderAt('/settings/tags');
    expect(await screen.findByText('This server keeps no tags or other research data of yours: it is read-only.')).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'New Tag…' })).toBeNull();
  });

  it('renames a tag in its editor, trimmed, and leaves it as it was when the name is unchanged', async () => {
    const { fetch, state } = settings([berlin, cold], {
      [`PATCH /api/v1/me/tags/${cold.id}`]: (_: URL, init?: RequestInit) => {
        const renamed = { ...cold, name: (body(init) as { name: string }).name };
        state.tags = [berlin, renamed];
        return renamed;
      },
    });
    renderAt('/settings/tags');
    const row = await screen.findByRole('button', { name: 'Cold War' });
    await userEvent.click(row);
    const editor = await screen.findByRole('dialog', { name: 'Edit Tag' });
    const field = within(editor).getByRole('textbox', { name: 'Tag name' }) as HTMLInputElement;
    expect(document.activeElement).toBe(field);
    expect(field.value).toBe('Cold War');
    expect(within(editor).getByText(/^Merging re-tags everything here/)).toBeTruthy();
    await userEvent.clear(field);
    expect(within(editor).getByRole('button', { name: 'Save' })).toHaveProperty('disabled', true);
    await userEvent.type(field, ' Cold war ');
    await userEvent.click(within(editor).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => body(init))).toEqual([{ name: 'Cold war' }]);
    expect(await screen.findByRole('button', { name: 'Cold war' })).toBe(document.activeElement);
  });

  it('deletes a tag after asking, in the app’s words, and focus goes to the pane’s heading', async () => {
    const { fetch, state } = settings([berlin, cold], {
      [`DELETE /api/v1/me/tags/${berlin.id}`]: () => {
        state.tags = [cold];
        return null;
      },
    });
    renderAt('/settings/tags');
    await userEvent.click(await screen.findByRole('button', { name: 'Berlin' }));
    const editor = await screen.findByRole('dialog', { name: 'Edit Tag' });
    await userEvent.click(within(editor).getByRole('button', { name: 'Delete Tag' }));
    const confirm = await screen.findByRole('alertdialog', { name: 'Delete Tag?' });
    expect(within(confirm).getByText(/^Deleting removes this tag from every note and document/)).toBeTruthy();
    expect(document.activeElement).toBe(within(confirm).getByRole('button', { name: 'Cancel' }));
    await userEvent.click(within(confirm).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(true);
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Berlin' })).toBeNull());
    expect(document.activeElement).toBe(screen.getByRole('heading', { level: 1, name: 'Tags' }));
  });

  it('closes only the confirmation on its Escape, and focus goes back to Delete Tag', async () => {
    const { fetch } = settings([berlin, cold]);
    renderAt('/settings/tags');
    await userEvent.click(await screen.findByRole('button', { name: 'Berlin' }));
    const editor = await screen.findByRole('dialog', { name: 'Edit Tag' });
    await userEvent.click(within(editor).getByRole('button', { name: 'Delete Tag' }));
    const confirm = await screen.findByRole('alertdialog', { name: 'Delete Tag?' });
    // Escape, as the browser sends it to the dialog on top.
    fireEvent(confirm, new Event('cancel', { cancelable: true }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(screen.getByRole('dialog', { name: 'Edit Tag' })).toBeTruthy();
    await waitFor(() => expect(document.activeElement).toBe(within(editor).getByRole('button', { name: 'Delete Tag' })));
    expect(fetch.mock.calls.some(([, init]) => init?.method === 'DELETE')).toBe(false);
  });

  it('makes one tag however often New Tag… is pressed while it is made', async () => {
    let release: (tag: unknown) => void = () => {};
    const { fetch } = settings([], { 'POST /api/v1/me/tags': () => new Promise((resolve) => (release = resolve)) });
    renderAt('/settings/tags');
    const button = await screen.findByRole('button', { name: 'New Tag…' });
    await userEvent.click(button);
    await userEvent.click(button);
    release({ id: 'N0000000-0000-4000-8000-000000000000', name: 'New Tag' });
    await screen.findByRole('dialog', { name: 'Edit Tag' });
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'POST')).toHaveLength(1);
  });

  it('merges a tag into another chosen in Merge Tag, which it opens from the editor', async () => {
    const { fetch, state } = settings([berlin, cold], {
      [`POST /api/v1/me/tags/${cold.id}/merge`]: () => {
        state.tags = [berlin];
        return berlin;
      },
    });
    renderAt('/settings/tags');
    await userEvent.click(await screen.findByRole('button', { name: 'Cold War' }));
    await userEvent.click(within(await screen.findByRole('dialog', { name: 'Edit Tag' })).getByRole('button', { name: 'Merge into Another Tag…' }));
    const merge = await screen.findByRole('dialog', { name: 'Merge Tag' });
    expect(within(merge).getByRole('group', { name: 'Merge ‘Cold War’ into:' })).toBeTruthy();
    expect(within(merge).getAllByRole('radio').map((radio) => radio.closest('label')?.textContent?.trim())).toEqual(['Berlin']);
    expect(within(merge).getByRole('button', { name: 'Merge' })).toHaveProperty('disabled', true);
    await userEvent.click(within(merge).getByRole('radio', { name: 'Berlin' }));
    await userEvent.click(within(merge).getByRole('button', { name: 'Merge' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'POST').map(([, init]) => body(init))).toEqual([{ into: berlin.id }]);
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Cold War' })).toBeNull());
  });

  it('makes a tag named New Tag from New Tag…, and opens it to be named, with nothing to merge or delete yet', async () => {
    const made: UserTag = { id: 'N0000000-0000-4000-8000-000000000000', name: 'New Tag' };
    const { fetch, state } = settings([berlin], {
      'POST /api/v1/me/tags': () => {
        state.tags = [berlin, made];
        return made;
      },
    });
    renderAt('/settings/tags');
    await userEvent.click(await screen.findByRole('button', { name: 'New Tag…' }));
    const editor = await screen.findByRole('dialog', { name: 'Edit Tag' });
    expect((within(editor).getByRole('textbox', { name: 'Tag name' }) as HTMLInputElement).value).toBe('New Tag');
    expect(within(editor).queryByRole('button', { name: 'Delete Tag' })).toBeNull();
    expect(within(editor).queryByRole('button', { name: 'Merge into Another Tag…' })).toBeNull();
    expect(fetch.mock.calls.filter(([, init]) => init?.method === 'POST').map(([, init]) => body(init))).toEqual([{ name: 'New Tag' }]);
  });

  it('offers no merge with a single tag, and says why', async () => {
    settings([berlin]);
    renderAt('/settings/tags');
    await userEvent.click(await screen.findByRole('button', { name: 'Berlin' }));
    const editor = await screen.findByRole('dialog', { name: 'Edit Tag' });
    expect(within(editor).getByRole('button', { name: 'Merge into Another Tag…' })).toHaveProperty('disabled', true);
    expect(within(editor).getByText(/^Merging needs a second tag to merge into\./)).toBeTruthy();
  });
});
