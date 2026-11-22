// The lines that read the user's own summaries, Related Documents' rows (FRUS-Explorer#1907), Chronology's rows (#1927)
// and Project Home's Suggested Next leads (#1902), are read again once a summary is written, and once research is
// imported or erased, so that none shows a summary the reader has changed or removed.

import { QueryClient } from '@tanstack/react-query';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { me, summary } from '../test/notes';
import { stubServer } from '../test/renderRoute';
import { createSummary, researchImported } from './userData';

/** One answer of each, as the browser keeps them. */
const lines = [
  ['related', 'frus1961-63v06', 'd2', 'all', ''],
  ['chronology', 'from=1960-11-01&to=1960-11-30'],
  ['projectHome', '5C25C000-0000-4000-8000-000000000001'],
];

function holding() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  for (const key of lines) client.setQueryData(key, {});
  return client;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('the lines that read the user’s summaries', () => {
  it('are read again once a summary is written', async () => {
    stubServer({ '/api/v1/me': me, 'POST /api/v1/me/volumes/frus1961-63v06/documents/d1/summaries': summary({ id: 'S1' }) });
    const client = holding();
    await createSummary(client, 'frus1961-63v06', 'd1', 'A summary.');
    for (const key of lines) expect(client.getQueryState(key)?.isInvalidated, key[0]).toBe(true);
  });

  it('are read again once research is imported or erased', () => {
    const client = holding();
    researchImported(client);
    for (const key of lines) expect(client.getQueryState(key)?.isInvalidated, key[0]).toBe(true);
  });
});
