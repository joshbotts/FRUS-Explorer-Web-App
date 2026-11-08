// The sign-in page of a server with accounts of its own (PLAN's S20b): shown in place of any page until
// someone signs in, asking nothing of a user before; a sign-in opens the page that was asked for, the
// header naming the user with Sign Out; a refusal is said in the server's words, with the password
// cleared; a sign-out shows the page again and forgets the user; and a session that ends while a page is
// open sends the browser back to it.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Me } from '../api/types';
import { copy } from '../copy';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  window.sessionStorage.clear();
});

const alice: Me = { userId: 'alice', displayName: 'Alice Liddell', auth: 'local', roles: ['reader'], userData: true, csrfToken: 'token-a' };
const signedOut = { auth: 'local', signedIn: false };
const signedIn = { auth: 'local', signedIn: true };

/** The URLs asked for, by path. */
const asked = (fetch: ReturnType<typeof stubServer>) => fetch.mock.calls.map(([url]) => new URL(String(url), 'http://localhost').pathname);

/** What a POST sent, as JSON. */
const posted = (fetch: ReturnType<typeof stubServer>, path: string) =>
  fetch.mock.calls.filter(([url, init]) => String(url) === path && init?.method === 'POST').map(([, init]) => JSON.parse(String(init?.body ?? 'null')));

describe('signing in with an account', () => {
  it('shows the sign-in page at any address until someone signs in, asking nothing of a user', async () => {
    const fetch = stubServer({ '/readyz': ready, '/api/v1/auth/session': signedOut });
    renderAt('/research/notes', { askSession: true });
    expect(await screen.findByRole('heading', { level: 1, name: copy.signIn.title })).toBeTruthy();
    expect(document.activeElement).toBe(document.body);
    expect(screen.getByLabelText(copy.signIn.name)).toBeTruthy();
    expect((screen.getByLabelText(copy.signIn.password) as HTMLInputElement).type).toBe('password');
    expect(screen.queryByRole('navigation', { name: copy.app.navigation })).toBeNull();
    expect(within(screen.getByRole('contentinfo')).getByText(copy.app.operatorReads)).toBeTruthy();
    expect(asked(fetch).filter((path) => path.startsWith('/api/v1/me'))).toEqual([]);
    expect(document.title).toBe(copy.app.title(copy.signIn.title));
  });

  it('signs in, opens the page asked for, and names the user with Sign Out', async () => {
    let session = signedOut;
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/auth/session': () => session,
      'POST /api/v1/auth/sign-in': () => {
        session = signedIn;
        return alice;
      },
      '/api/v1/me': alice,
      '/api/v1/me/notes': { items: [], total: 0, projects: [] },
      '/api/v1/me/tags': { items: [], total: 0 },
      '/api/v1/me/projects': { items: [], total: 0 },
    });
    window.sessionStorage.setItem('someone-before', 'theirs');
    renderAt('/no-such-page', { askSession: true });
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText(copy.signIn.name), 'alice');
    await user.type(screen.getByLabelText(copy.signIn.password), 'correct horse battery staple{Enter}');
    const arrived = await screen.findByRole('heading', { level: 1, name: copy.notFound.title });
    await waitFor(() => expect(document.activeElement).toBe(arrived));
    expect(posted(fetch, '/api/v1/auth/sign-in')).toEqual([{ name: 'alice', password: 'correct horse battery staple' }]);
    const banner = screen.getByRole('banner');
    expect(within(banner).getByText(copy.app.signedInAs('Alice Liddell'))).toBeTruthy();
    expect(within(banner).getByRole('button', { name: copy.app.signOut })).toBeTruthy();
    expect(within(banner).getByRole('navigation', { name: copy.app.navigation })).toBeTruthy();
    expect(within(screen.getByRole('contentinfo')).getByText(copy.app.operatorReads)).toBeTruthy();
    expect(window.sessionStorage.getItem('someone-before')).toBeNull();
  });

  it('says a refusal in the server’s words and clears the password', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/auth/session': signedOut,
      'POST /api/v1/auth/sign-in': new ProblemAnswer(403, 'SIGN_IN_FAILED', 'The name or the password is not right.'),
    });
    renderAt('/browse', { askSession: true });
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText(copy.signIn.name), 'alice');
    const password = screen.getByLabelText(copy.signIn.password) as HTMLInputElement;
    await user.type(password, 'a wrong guess{Enter}');
    expect((await screen.findByRole('alert')).textContent).toBe('The name or the password is not right.');
    expect(password.value).toBe('');
    expect(document.activeElement).toBe(password);
    expect(screen.getByRole('heading', { level: 1, name: copy.signIn.title })).toBeTruthy();
    expect(asked(fetch).filter((path) => path.startsWith('/api/v1/me'))).toEqual([]);
  });

  it('signs out, back to the sign-in page, and forgets the user', async () => {
    let session = signedIn;
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/auth/session': () => session,
      '/api/v1/me': alice,
      'POST /api/v1/auth/sign-out': () => {
        session = signedOut;
        return null;
      },
    });
    renderAt('/no-such-page', { askSession: true });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: copy.app.signOut }));
    const page = await screen.findByRole('heading', { level: 1, name: copy.signIn.title });
    await waitFor(() => expect(document.activeElement).toBe(page));
    expect(screen.queryByText(copy.app.signedInAs('Alice Liddell'))).toBeNull();
    expect(screen.queryByRole('button', { name: copy.app.signOut })).toBeNull();
    expect(asked(fetch).filter((path) => path === '/api/v1/auth/sign-out')).toHaveLength(1);
  });

  it('stays signed in, and says so, when the server could not be told', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/auth/session': signedIn,
      '/api/v1/me': alice,
      'POST /api/v1/auth/sign-out': new ProblemAnswer(502, 'BAD_GATEWAY', 'The proxy could not reach the server.'),
    });
    renderAt('/no-such-page', { askSession: true });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: copy.app.signOut }));
    expect((await screen.findByRole('alert')).textContent).toBe(copy.app.signOutFailed);
    expect(screen.getByText(copy.app.signedInAs('Alice Liddell'))).toBeTruthy();
  });

  it('returns to the sign-in page when a session ends while a page is open', async () => {
    let sessions = 0;
    stubServer({
      '/readyz': ready,
      // Signed in when the page opened, and no longer once the screen's request is refused.
      '/api/v1/auth/session': () => (sessions++ === 0 ? signedIn : signedOut),
      '/api/v1/me': alice,
      '/api/v1/me/tags': new ProblemAnswer(403, 'NOT_SIGNED_IN', 'This request carries no session that is current: sign in.'),
    });
    renderAt('/settings/tags', { askSession: true });
    expect(await screen.findByRole('heading', { level: 1, name: copy.signIn.title })).toBeTruthy();
    expect(sessions).toBe(2);
  });
});
