// The app's own routes at an address, with the server's answers stubbed by path, so a test sees a
// screen as the router, its queries and the shell give it.
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createMemoryHistory, createRouter, RouterProvider } from '@tanstack/react-router';
import { render } from '@testing-library/react';
import { vi } from 'vitest';
import type { Coverage, Readiness } from '../api/types';
import { parseSearch, routeTree, stringifySearch } from '../router';

/** A server with an index served. */
export const ready: Readiness = { ready: true, step: 'ready', detail: '' };

export const coverage: Coverage = { indexedVolumes: 1, indexedDocuments: 2, manifestVolumes: 553, indexVersion: 69 };

/** Answers each request with the JSON `answers` holds for its path; any other path is a 404 problem. */
export function stubServer(answers: Record<string, unknown>): void {
  vi.stubGlobal(
    'fetch',
    vi.fn(async (input: string) => {
      const path = new URL(input, 'http://localhost').pathname;
      if (!(path in answers)) {
        const problem = { type: 'about:blank', title: 'Not Found', status: 404, detail: `No answer for ${path}.`, instance: path, code: 'NOT_FOUND' };
        return new Response(JSON.stringify(problem), { status: 404, headers: { 'content-type': 'application/problem+json' } });
      }
      return new Response(JSON.stringify(answers[path]), { headers: { 'content-type': 'application/json' } });
    }),
  );
}

/** Renders the app at `href`, with nothing cached. */
export function renderAt(href: string) {
  const router = createRouter({ routeTree, parseSearch, stringifySearch, history: createMemoryHistory({ initialEntries: [href] }) });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
}
