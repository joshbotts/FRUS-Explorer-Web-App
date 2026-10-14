import { cleanup, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { SearchItem } from '../api/types';
import { coverage, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function item(fields: Partial<SearchItem>): SearchItem {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    header: '',
    displayTitle: '',
    documentLabel: 'Doc 1',
    headerRepeatsNumber: false,
    snippet: 'the <b>treaties</b>',
    bm25Score: -1,
    isEditorialNote: false,
    isFrontMatter: false,
    subjectTagIds: [],
    userTagIds: [],
    ...fields,
  };
}

describe('SearchScreen', () => {
  it('names each result as the server says the Mac’s search window names it, and withholds a label its title repeats', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search': {
        total: 2,
        countBasis: 'exact',
        limit: 20,
        offset: 0,
        retainedLimit: 7500,
        coverage,
        items: [
          item({
            documentNumber: '1',
            header: '1. Telegram From the Embassy Source: Department of State, Central Files',
            displayTitle: '1. Telegram From the Embassy',
            headerRepeatsNumber: true,
          }),
          item({ documentId: 'd2', header: 'Memorandum of Conversation', displayTitle: 'Memorandum of Conversation', documentLabel: 'Doc 2' }),
        ],
      },
    });
    renderAt('/search?keywords=treaties');
    const rows = within(await screen.findByRole('list', { name: 'Results' })).getAllByRole('listitem');
    expect(rows.map((row) => within(row).getByRole('link').textContent)).toEqual(['1. Telegram From the Embassy', 'Memorandum of Conversation']);
    expect(rows[0]?.querySelector('.meta')?.textContent).toBe('frus1961-63v06');
    expect(rows[1]?.querySelector('.meta')?.textContent).toBe('frus1961-63v06 · Doc 2');
  });
});
