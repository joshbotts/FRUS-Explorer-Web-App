import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SecretList, SecretName } from '../api/secrets';
import { me } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const key = 'P9NiFoyLeZu2bZNvvuQPDWsd';

/** A promise and what settles it, for an answer a test holds back. */
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((settle) => (resolve = settle));
  return { promise, resolve };
}

/** A server that keeps the user's keys as the routes do: by name, answering only whether each is set. */
function keepingKeys(initial: SecretName[] = [], instance: SecretName[] = [], answers: Record<string, unknown> = {}) {
  const stored = new Map<SecretName, string>(initial.map((name) => [name, 'kept-before']));
  const list = (): SecretList => ({
    secrets: (['nara', 'zotero'] as SecretName[]).map((name) =>
      stored.has(name) ? { name, set: true, updatedAt: '2026-10-24T00:00:00.000Z' } : { name, set: false },
    ),
    instance,
  });
  const set = (name: SecretName) => (_url: URL, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body)) as { value: string };
    stored.set(name, body.value);
    return { name, set: true, updatedAt: '2026-10-24T00:00:00.000Z' };
  };
  const remove = (name: SecretName) => () => {
    stored.delete(name);
    return null;
  };
  const fetch = stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/me/secrets': () => list(),
    'PUT /api/v1/me/secrets/nara': set('nara'),
    'PUT /api/v1/me/secrets/zotero': set('zotero'),
    'DELETE /api/v1/me/secrets/nara': remove('nara'),
    'DELETE /api/v1/me/secrets/zotero': remove('zotero'),
    ...answers,
  });
  return { stored, fetch, set, remove };
}

const puts = (fetch: ReturnType<typeof stubServer>) => fetch.mock.calls.filter(([, init]) => init?.method === 'PUT');

describe('Settings ▸ Keys', () => {
  it('is a pane beside Data that says, for NARA Catalog and Zotero, whether a key is stored, in the app’s words', async () => {
    keepingKeys(['zotero'], ['nara']);
    renderAt('/settings/keys');
    expect(await screen.findByRole('heading', { level: 1, name: 'Keys' })).toBeTruthy();
    const panes = screen.getByRole('navigation', { name: 'Settings' });
    expect(within(panes).getAllByRole('link').map((link) => [link.textContent, link.getAttribute('aria-current')])).toEqual([
      ['Tags', null],
      ['Projects', null],
      ['Research Sessions', null],
      ['Reading', null],
      ['Data', null],
      ['Keys', 'page'],
    ]);
    const nara = await screen.findByRole('region', { name: 'NARA Catalog' });
    expect(
      screen.getByText(
        'Nothing on this server uses these keys yet: Source Explorer’s archival search and Send to Zotero Library, which will, are still to come.',
      ),
    ).toBeTruthy();
    expect(within(nara).getByText('No key stored')).toBeTruthy();
    expect(within(nara).getByText('This server has a NARA Catalog key of its own, which serves you while you have none.')).toBeTruthy();
    expect(
      within(nara).getByText(
        'A free key from the National Archives Catalog. Source Explorer needs it to search lot files and Presidential Library records; everything else in the app works without it.',
      ),
    ).toBeTruthy();
    const getKey = within(nara).getByRole('link', { name: 'Get a free key from NARA' });
    expect(getKey.getAttribute('href')).toBe('https://www.archives.gov/research/catalog/help/api');
    expect(getKey.getAttribute('rel')).toBe('noopener noreferrer');
    expect(within(nara).getByRole('button', { name: 'Add Key…' })).toBeTruthy();
    expect(within(nara).queryByRole('button', { name: 'Remove Key' })).toBeNull();

    const zotero = screen.getByRole('region', { name: 'Zotero' });
    expect(within(zotero).getByText('Key stored')).toBeTruthy();
    expect(within(zotero).queryByText('This server has a NARA Catalog key of its own, which serves you while you have none.')).toBeNull();
    expect(
      within(zotero).getByText(
        'Send to Zotero Library sends FRUS documents to your Zotero library with your tags and research notes attached, and Zotero syncs them to all your devices.',
      ),
    ).toBeTruthy();
    expect(within(zotero).getByRole('link', { name: 'Create a Zotero API key' }).getAttribute('href')).toBe(
      'https://www.zotero.org/settings/keys/new?name=FRUS%20Explorer&library_access=1&notes_access=1&write_access=1',
    );
    expect(within(zotero).getByRole('button', { name: 'Replace Key…' })).toBeTruthy();
    expect(within(zotero).getByRole('button', { name: 'Remove Key' })).toBeTruthy();
    expect(
      screen.getByText(
        'Each key is kept on this server, encrypted, and is never shown again once it is saved: the server alone uses it, to reach the service for you. Whoever runs this server holds the key file that opens them.',
      ),
    ).toBeTruthy();
    expect(document.title).toBe('Keys – FRUS Explorer Light');
  });

  it('takes a key in a field that shows none of it and empties as the key is sent, with the token, keeping no copy', async () => {
    const user = userEvent.setup();
    const held = deferred<unknown>();
    const { stored, fetch, set } = keepingKeys();
    const answer = set('nara');
    const original = fetch.getMockImplementation()!;
    fetch.mockImplementation(async (input: string, init?: RequestInit) => {
      if (init?.method === 'PUT') {
        await held.promise;
        answer(new URL(input, 'http://localhost'), init);
        return new Response(JSON.stringify({ name: 'nara', set: true, updatedAt: '2026-10-24T00:00:00.000Z' }), {
          headers: { 'content-type': 'application/json' },
        });
      }
      return original(input, init);
    });
    renderAt('/settings/keys');
    const nara = await screen.findByRole('region', { name: 'NARA Catalog' });
    await user.click(within(nara).getByRole('button', { name: 'Add Key…' }));
    const field = within(nara).getByLabelText('NARA Catalog key') as HTMLInputElement;
    expect(document.activeElement).toBe(field);
    expect(field.type).toBe('password');
    expect(field.getAttribute('autocomplete')).toBe('new-password');
    expect(field.getAttribute('placeholder')).toBe('Paste your key');
    expect(within(nara).getByRole('button', { name: 'Save' }).hasAttribute('disabled')).toBe(true);
    await user.type(field, `  ${key}  `);
    expect(field.getAttribute('value') ?? '').not.toContain(key);
    await user.click(within(nara).getByRole('button', { name: 'Save' }));

    // While the answer is held back: the field is empty, and the page holds the key nowhere.
    await waitFor(() => expect(puts(fetch)).toHaveLength(1));
    expect(field.value).toBe('');
    expect(document.body.innerHTML).not.toContain(key);
    expect(within(nara).getByRole('button', { name: 'Save' }).hasAttribute('disabled')).toBe(true);
    held.resolve(null);

    expect(await within(nara).findByText('Key stored')).toBeTruthy();
    expect(within(nara).getByRole('status').textContent).toBe('Saved');
    const replace = within(nara).getByRole('button', { name: 'Replace Key…' });
    await waitFor(() => expect(document.activeElement).toBe(replace));
    expect(within(nara).queryByLabelText('NARA Catalog key')).toBeNull();
    expect(stored.get('nara')).toBe(key);
    const [url, init] = puts(fetch)[0] ?? [];
    expect(url).toBe('/api/v1/me/secrets/nara');
    expect(JSON.parse(String(init?.body))).toEqual({ value: key });
    expect((init?.headers as Record<string, string>)['X-CSRF-Token']).toBe('token-1');
    expect(document.body.innerHTML).not.toContain(key);

    // Replace Key… opens an empty field again, and Escape puts it away, with nothing sent.
    await user.click(replace);
    const again = within(nara).getByLabelText('NARA Catalog key') as HTMLInputElement;
    expect(again.value).toBe('');
    await user.keyboard('another{Escape}');
    expect(within(nara).queryByLabelText('NARA Catalog key')).toBeNull();
    expect(document.activeElement).toBe(within(nara).getByRole('button', { name: 'Replace Key…' }));
    expect(puts(fetch)).toHaveLength(1);
  });

  it('sends the key again with a new token when the server no longer knows the first, as after a restart', async () => {
    const user = userEvent.setup();
    let tokens = 0;
    const { stored, fetch, set } = keepingKeys();
    const keep = set('zotero');
    const original = fetch.getMockImplementation()!;
    fetch.mockImplementation(async (input: string, init?: RequestInit) => {
      const path = new URL(input, 'http://localhost').pathname;
      if (path === '/api/v1/me') {
        tokens += 1;
        return new Response(JSON.stringify({ ...me, csrfToken: `token-${tokens}` }), { headers: { 'content-type': 'application/json' } });
      }
      if (init?.method === 'PUT') {
        const token = (init.headers as Record<string, string>)['X-CSRF-Token'];
        if (token === 'token-1') {
          const problem = { type: 'about:blank', title: 'Forbidden', status: 403, detail: 'stale', instance: path, code: 'CSRF_TOKEN_INVALID' };
          return new Response(JSON.stringify(problem), { status: 403, headers: { 'content-type': 'application/problem+json' } });
        }
        return new Response(JSON.stringify(keep(new URL(input, 'http://localhost'), init)), { headers: { 'content-type': 'application/json' } });
      }
      return original(input, init);
    });
    renderAt('/settings/keys');
    const zotero = await screen.findByRole('region', { name: 'Zotero' });
    await user.click(within(zotero).getByRole('button', { name: 'Add Key…' }));
    await user.type(within(zotero).getByLabelText('Zotero API key'), `${key}{Enter}`);
    expect(await within(zotero).findByText('Key stored')).toBeTruthy();
    expect(puts(fetch).map(([, init]) => (init?.headers as Record<string, string>)['X-CSRF-Token'])).toEqual(['token-1', 'token-2']);
    expect(stored.get('zotero')).toBe(key);
  });

  it('asks before it removes a key, as the app does, and Cancel keeps it', async () => {
    const user = userEvent.setup();
    const { stored } = keepingKeys(['zotero']);
    renderAt('/settings/keys');
    const zotero = await screen.findByRole('region', { name: 'Zotero' });
    const remove = within(zotero).getByRole('button', { name: 'Remove Key' });
    await user.click(remove);
    let question = screen.getByRole('alertdialog', { name: 'Remove the stored key?' });
    expect(within(question).getByText('The server forgets it, for every browser you sign in from. Nothing you’ve already saved is affected.')).toBeTruthy();
    expect(document.activeElement).toBe(within(question).getByRole('button', { name: 'Cancel' }));
    await user.click(within(question).getByRole('button', { name: 'Cancel' }));
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(document.activeElement).toBe(remove);
    expect(stored.has('zotero')).toBe(true);

    await user.click(remove);
    question = screen.getByRole('alertdialog', { name: 'Remove the stored key?' });
    await user.click(within(question).getByRole('button', { name: 'Remove' }));
    expect(await within(zotero).findByText('No key stored')).toBeTruthy();
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(within(zotero).getByRole('status').textContent).toBe('Removed');
    expect(document.activeElement).toBe(within(zotero).getByRole('button', { name: 'Add Key…' }));
    expect(stored.has('zotero')).toBe(false);
  });

  // Escape is the question's Cancel in a browser (shell/Modal.tsx), which jsdom's dialog does not send: the
  // Cancel button stands for both here.
  it('keeps the question while a removal is sent, Cancel waiting for it, and says why one failed', async () => {
    const user = userEvent.setup();
    const held = deferred<unknown>();
    keepingKeys(['nara'], [], {
      'DELETE /api/v1/me/secrets/nara': async () => {
        await held.promise;
        return new ProblemAnswer(503, 'STORE_UNAVAILABLE', 'The user store could not be written.');
      },
    });
    renderAt('/settings/keys');
    const nara = await screen.findByRole('region', { name: 'NARA Catalog' });
    await user.click(within(nara).getByRole('button', { name: 'Remove Key' }));
    const question = screen.getByRole('alertdialog', { name: 'Remove the stored key?' });
    const confirm = within(question).getByRole('button', { name: 'Remove' });
    await user.click(confirm);
    await waitFor(() => expect(confirm.getAttribute('aria-disabled')).toBe('true'));
    await user.click(within(question).getByRole('button', { name: 'Cancel' }));
    expect(screen.getByRole('alertdialog', { name: 'Remove the stored key?' })).toBe(question);
    held.resolve(null);
    expect((await within(question).findByRole('alert')).textContent).toBe('The user store could not be written.');
    expect(confirm.getAttribute('aria-disabled')).toBe('false');
    expect(within(nara).getByText('Key stored')).toBeTruthy();
    await user.click(within(question).getByRole('button', { name: 'Cancel' }));
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(document.activeElement).toBe(within(nara).getByRole('button', { name: 'Remove Key' }));
  });

  it('says why a key was refused, and keeps the field, empty, to try again', async () => {
    const user = userEvent.setup();
    stubServer({
      '/readyz': ready,
      '/api/v1/me': me,
      '/api/v1/me/secrets': { secrets: [{ name: 'nara', set: false }, { name: 'zotero', set: false }], instance: [] },
      'PUT /api/v1/me/secrets/zotero': new ProblemAnswer(
        400,
        'INVALID_FIELD',
        'value: A key holds letters, digits and punctuation alone, with no spaces: paste it as the service gave it.',
      ),
    });
    renderAt('/settings/keys');
    const zotero = await screen.findByRole('region', { name: 'Zotero' });
    await user.click(within(zotero).getByRole('button', { name: 'Add Key…' }));
    const field = within(zotero).getByLabelText('Zotero API key') as HTMLInputElement;
    expect(field.getAttribute('placeholder')).toBe('Paste your Zotero API key…');
    await user.type(field, 'two words');
    // From the button, so that focus has left the field when the answer comes.
    await user.click(within(zotero).getByRole('button', { name: 'Save' }));
    expect((await within(zotero).findByRole('alert')).textContent).toBe(
      'value: A key holds letters, digits and punctuation alone, with no spaces: paste it as the service gave it.',
    );
    await waitFor(() => expect(document.activeElement).toBe(field));
    expect(field.value).toBe('');
    expect(within(zotero).getByText('No key stored')).toBeTruthy();

    // Cancel puts the field and its failure away.
    await user.click(within(zotero).getByRole('button', { name: 'Cancel' }));
    expect(within(zotero).queryByRole('alert')).toBeNull();
    expect(document.activeElement).toBe(within(zotero).getByRole('button', { name: 'Add Key…' }));
  });

  it('keeps the keys on the screen when a later reading of them fails', async () => {
    let readings = 0;
    const { fetch } = keepingKeys(['zotero']);
    const original = fetch.getMockImplementation()!;
    fetch.mockImplementation(async (input: string, init?: RequestInit) => {
      if (new URL(input, 'http://localhost').pathname === '/api/v1/me/secrets' && (readings += 1) > 1) {
        return new Response(JSON.stringify({ code: 'UNAVAILABLE', detail: 'down' }), { status: 503, headers: { 'content-type': 'application/problem+json' } });
      }
      return original(input, init);
    });
    const { router } = renderAt('/settings/keys');
    const zotero = await screen.findByRole('region', { name: 'Zotero' });
    expect(within(zotero).getByText('Key stored')).toBeTruthy();
    // As when the reader comes back from the tab "Get a free key" opened: React Query reads the list again.
    window.dispatchEvent(new Event('visibilitychange'));
    await waitFor(() => expect(readings).toBeGreaterThan(1));
    expect(screen.getByRole('region', { name: 'Zotero' })).toBeTruthy();
    expect(screen.queryByRole('alert')).toBeNull();
    expect(router.state.location.pathname).toBe('/settings/keys');
  });

  it('says so on a server that keeps no user data, and asks for no keys', async () => {
    const fetch = stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userData: false } });
    renderAt('/settings/keys');
    expect(await screen.findByText('This server keeps no keys or other data of yours: it is read-only.')).toBeTruthy();
    expect(fetch.mock.calls.map(([url]) => url)).not.toContain('/api/v1/me/secrets');
  });
});
