// The shell behind a proxy that signs people in (PLAN's S14e): its header names the user, and its
// footer says that whoever runs the instance can read what it keeps for them, as SPEC's Privacy
// asks; a server with no sign-in, whose one user runs it, shows neither.
import { act, cleanup, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { copy } from '../copy';
import { me } from '../test/notes';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

/** Lets the stubbed server's answers settle. */
const settle = () => act(() => new Promise<void>((resolve) => setTimeout(resolve, 20)));

describe('the shell', () => {
  it('names the user the proxy signed in, and says that whoever runs the instance can read what it keeps for them', async () => {
    stubServer({ '/readyz': ready, '/api/v1/me': { ...me, userId: 'alice@example.org', displayName: 'alice@example.org', auth: 'header', roles: ['reader'] } });
    renderAt('/no-such-page');
    const banner = await screen.findByRole('banner');
    expect(await within(banner).findByText('Signed in as alice@example.org')).toBeTruthy();
    expect(within(screen.getByRole('contentinfo')).getByText(copy.app.operatorReads)).toBeTruthy();
    expect(within(screen.getByRole('contentinfo')).getByText(copy.app.footer)).toBeTruthy();
  });

  it('names no one on a server with no sign-in, or when the server names no one', async () => {
    for (const answer of [me, new ProblemAnswer(403, 'NOT_SIGNED_IN', 'This request named no one.')]) {
      const fetch = stubServer({ '/readyz': ready, '/api/v1/me': answer });
      renderAt('/no-such-page');
      await waitFor(() => expect(fetch.mock.calls.map(([url]) => String(url))).toContain('/api/v1/me'));
      await settle();
      expect(screen.queryByText(/^Signed in as/)).toBeNull();
      expect(screen.queryByText(copy.app.operatorReads)).toBeNull();
      expect(within(screen.getByRole('contentinfo')).getByText(copy.app.footer)).toBeTruthy();
      cleanup();
      vi.unstubAllGlobals();
    }
  });
});
