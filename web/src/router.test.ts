import { createMemoryHistory, createRouter } from '@tanstack/react-router';
import { describe, expect, it } from 'vitest';
import { parseSearch, routeTree, stringifySearch } from './router';

async function routerAt(href: string) {
  const router = createRouter({ routeTree, parseSearch, stringifySearch, history: createMemoryHistory({ initialEntries: [href] }) });
  await router.load();
  return router;
}

function searchOf(router: Awaited<ReturnType<typeof routerAt>>): Record<string, unknown> {
  return router.state.matches.at(-1)?.search as Record<string, unknown>;
}

describe('the router', () => {
  it('replaces every raw search field with its checked value', async () => {
    const router = await routerAt('/search?keywords=treaty&limit=20&offset=-5&dateRangeEarliest=&documentType=all');
    const search = searchOf(router);
    expect(search.keywords).toBe('treaty');
    for (const field of ['limit', 'offset', 'dateRangeEarliest', 'documentType']) expect(search[field], field).toBeUndefined();
  });

  it('pages from a URL written with the default page size', async () => {
    const router = await routerAt('/search?keywords=treaty&limit=20');
    await router.navigate({ to: '/search', search: (previous) => ({ ...previous, offset: 20 }) });
    expect(router.state.location.searchStr).toBe('?keywords=treaty&offset=20');
  });

  it('opens the rail only for a known value', async () => {
    const router = await routerAt('/doc/frus1961-63v06/d1?rail=other');
    expect(searchOf(router).rail).toBeUndefined();
  });
});
