// The app's own routes at an address, with the server's answers stubbed by path, so a test sees a
// screen as the router, its queries and the shell give it.
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createMemoryHistory, createRouter, RouterProvider } from '@tanstack/react-router';
import { render } from '@testing-library/react';
import { vi } from 'vitest';
import { sessionQuery } from '../api/auth';
import type { Choice, Coverage, Readiness } from '../api/types';
import { parseSearch, routeTree, stringifySearch } from '../router';

/** A server with an index served. */
export const ready: Readiness = { ready: true, step: 'ready', detail: '' };

export const coverage: Coverage = { indexedVolumes: 1, indexedDocuments: 2, manifestVolumes: 553, indexVersion: 69 };

/** The orders a search offers, by the kit's labels, as every list of results carries them. */
export const sortChoices: Choice[] = [
  { value: 'relevance', title: 'Relevance' },
  { value: 'dateAscending', title: 'Date ↑' },
  { value: 'dateDescending', title: 'Date ↓' },
];

/**
 * An answer: JSON to send, a problem to send with its status, or a function of the request's URL
 * giving either, or a promise of either, which a test settles when it chooses.
 */
export type Answer = unknown;

/** Whether the browser is signed in, as a server with no sign-in answers it (S20b). */
export const signedInWithoutAccounts = { auth: 'none', signedIn: true };

/** A problem the server sends, as RFC 9457 problem details. */
export class ProblemAnswer {
  constructor(
    readonly status: number,
    readonly code: string,
    readonly detail: string,
  ) {}
}

/**
 * Answers each request with what `answers` holds for it: under `METHOD /path` for any method, or
 * under its path alone for a GET. An answer is JSON, a `ProblemAnswer`, `null` for 204 No Content,
 * a `Response` as it is, or a function of the request's URL and its init that gives one, at once or
 * by a promise. Whether the browser is signed in, which the shell asks first (S20b), is answered as a
 * server with no sign-in answers it unless `answers` holds it. Any other request is a 404 problem.
 * Returns the stub, whose calls name the URLs asked for and how.
 */
export function stubServer(answers: Record<string, Answer>) {
  const fetch = vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input, 'http://localhost');
    const method = init?.method ?? 'GET';
    const key = `${method} ${url.pathname}`;
    const answer =
      key in answers
        ? answers[key]
        : method === 'GET' && url.pathname in answers
          ? answers[url.pathname]
          : method === 'GET' && url.pathname === '/api/v1/auth/session'
            ? signedInWithoutAccounts
            : new ProblemAnswer(404, 'NOT_FOUND', `No answer for ${key}.`);
    const given: unknown = await (typeof answer === 'function' ? (answer as (url: URL, init?: RequestInit) => Answer)(url, init) : answer);
    // A file, with its headers, as a collection's export answers (S18e).
    if (given instanceof Response) return given;
    if (given instanceof ProblemAnswer) {
      const problem = { type: 'about:blank', title: 'Problem', status: given.status, detail: given.detail, instance: url.pathname, code: given.code };
      return new Response(JSON.stringify(problem), { status: given.status, headers: { 'content-type': 'application/problem+json' } });
    }
    if (given === null) return new Response(null, { status: 204 });
    return new Response(JSON.stringify(given), { headers: { 'content-type': 'application/json' } });
  });
  vi.stubGlobal('fetch', fetch);
  return fetch;
}

/**
 * Renders the app at `href`, with nothing cached but the session as a server with no sign-in gives it,
 * so that a screen opens as soon as it did before the shell asked (S20b), unless `askSession` has the
 * shell ask the stubbed server; the router says where the app has gone since.
 */
export function renderAt(href: string, { askSession = false }: { askSession?: boolean } = {}) {
  const router = createRouter({ routeTree, parseSearch, stringifySearch, history: createMemoryHistory({ initialEntries: [href] }) });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  if (!askSession) client.setQueryData(sessionQuery.queryKey, signedInWithoutAccounts);
  const rendered = render(
    <QueryClientProvider client={client}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
  return { ...rendered, router };
}
