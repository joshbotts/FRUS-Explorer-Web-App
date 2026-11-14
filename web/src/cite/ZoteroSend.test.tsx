// Send to Zotero Library (PLAN's S22e) over a stubbed server: Cite offers it while the user has a Zotero key, as
// the app's menu does while an account is connected, sends the document through the server and says what was
// added in the app's words, with View in Zotero, or why it was not, in the server's.
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, cleanup, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SecretList } from '../api/secrets';
import { meQuery } from '../api/userData';
import { me } from '../test/notes';
import { ProblemAnswer, stubServer } from '../test/renderRoute';
import { CiteZoteroSend } from './ZoteroSend';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const sendPath = '/api/v1/me/volumes/frus1961-63v06/documents/d3/zotero';

const keys = (zotero: boolean): SecretList => ({
  secrets: [
    { name: 'nara', set: false },
    { name: 'zotero', set: zotero, ...(zotero && { updatedAt: '2026-11-14T00:00:00.000Z' }) },
  ],
  instance: [],
});

function open(answers: Record<string, unknown>) {
  const fetch = stubServer({ '/api/v1/me': me, ...answers });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const rendered = render(
    <QueryClientProvider client={client}>
      <CiteZoteroSend volumeId="frus1961-63v06" documentId="d3" />
    </QueryClientProvider>,
  );
  return { fetch, client, ...rendered };
}

describe('Cite’s Send to Zotero Library', () => {
  it('is offered only while the user has a Zotero key, and on a server that keeps user data', async () => {
    const { fetch, container } = open({ '/api/v1/me/secrets': keys(false) });
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).endsWith('/api/v1/me/secrets'))).toBe(true));
    expect(container.textContent).toBe('');
    cleanup();
    const readOnly = open({ '/api/v1/me': { ...me, userData: false } });
    // Once the server has said it keeps no user data, and the row has drawn again with that answer.
    await waitFor(() => expect(readOnly.client.getQueryData(meQuery.queryKey)).toBeDefined());
    await act(async () => {});
    expect(readOnly.fetch.mock.calls.some(([url]) => String(url).endsWith('/secrets'))).toBe(false);
    expect(readOnly.container.textContent).toBe('');
  });

  it('sends the document and says what was added, with View in Zotero, or why it was not', async () => {
    let refuse = false;
    const { fetch } = open({
      '/api/v1/me/secrets': keys(true),
      [`POST ${sendPath}`]: () =>
        refuse
          ? new ProblemAnswer(409, 'ZOTERO_KEY_REJECTED', 'That Zotero API key was rejected. Check it and try again.')
          : { addedItems: 1, failedItems: 0, addedNotes: 2, webURL: 'https://www.zotero.org/frus-stub/library' },
    });
    const send = await screen.findByRole('button', { name: 'Send to Zotero Library' });
    // Its caption is its description, the Mac popover's.
    expect(send.getAttribute('aria-describedby')).toBeTruthy();
    expect(screen.getByText('Adds this document — with your tags and research notes — straight to your Zotero library.')).toBeTruthy();
    await userEvent.click(send);
    const status = screen.getAllByRole('status').find((each) => each.className === 'zotero-result')!;
    await waitFor(() => expect(status.textContent).toBe('Sent to Zotero. Added 1 document and 2 notes to Zotero. View in Zotero'));
    expect(within(status).getByRole('link', { name: 'View in Zotero' }).getAttribute('href')).toBe('https://www.zotero.org/frus-stub/library');
    expect(fetch.mock.calls.filter(([url, init]) => String(url).endsWith(sendPath) && init?.method === 'POST')).toHaveLength(1);
    expect(document.activeElement).toBe(send);

    refuse = true;
    await userEvent.click(send);
    expect((await screen.findByRole('alert')).textContent).toBe('Couldn’t Send to Zotero. That Zotero API key was rejected. Check it and try again.');
    expect(status.textContent).toBe('');
  });
});
