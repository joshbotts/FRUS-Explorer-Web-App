import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { InspectedTerm, QueryInspection, SearchInspection, SearchItem, SearchOperand, SearchResultList } from '../api/types';
import { coverage, ProblemAnswer, ready, renderAt, sortChoices, stubServer } from '../test/renderRoute';
import { countLine } from './QueryInspector';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function operand(text: string, fields: Partial<SearchOperand> = {}): SearchOperand {
  return { text, rendered: `"${text}"`, kind: 'word', isNegated: false, isExact: false, isExactApplied: false, source: 'typed', ...fields };
}

function term(text: string, fields: Partial<InspectedTerm> = {}, marks: Partial<SearchOperand> = {}): InspectedTerm {
  return { operand: operand(text, marks), isStemBroadening: false, showsStructuredTag: false, ...fields };
}

function inspection(fields: Partial<QueryInspection>): QueryInspection {
  return {
    operands: [],
    notApplied: [],
    indexedVolumeCount: 2,
    isFilterOnly: false,
    isApproximate: false,
    isRefused: false,
    showsStrip: true,
    showsApproximateCaption: false,
    showsTermRows: true,
    hasOperands: true,
    hasUncountedOperands: false,
    ...fields,
  };
}

const negotiating = term('negotiating', { stem: 'negoti', isStemBroadening: true, corpusDocumentFrequency: 2, corpusOccurrences: 2, corpusOccurrencesPerDocument: 1 });
const canal = term('canal', { stem: 'canal', corpusDocumentFrequency: 1, corpusOccurrences: 1, corpusOccurrencesPerDocument: 1 }, { isNegated: true });

/** The inspector's account of `negotiating -canal`, before and after its scoped counts. */
const cheap: SearchInspection = {
  inspection: inspection({ expression: { corpus: '"negotiating" NOT "canal"', displayed: '"negotiating" NOT "canal"', expressionsDiffer: false }, operands: [negotiating, canal], hasUncountedOperands: true }),
};
const counted: SearchInspection = {
  inspection: inspection({ ...cheap.inspection, operands: [{ ...negotiating, scopedCount: 2 }, canal], hasUncountedOperands: false }),
};

function results(total: number, items: SearchItem[] = []): SearchResultList {
  return { total, countBasis: 'exact', limit: 20, offset: 0, retainedLimit: 7500, sort: 'relevance', sortChoices, coverage, items };
}

const telegram: SearchItem = {
  volumeId: 'frus1961-63v06',
  documentId: 'd1',
  header: 'Telegram',
  displayTitle: 'Telegram',
  documentLabel: 'Doc 1',
  headerRepeatsNumber: false,
  snippet: 'the <b>negotiating</b>',
  bm25Score: -1,
  isEditorialNote: false,
  isFrontMatter: false,
  subjectTagIds: [],
  userTagIds: [],
};

/** A promise of an answer, and the function that settles it, for an answer a test holds back. */
function heldBack<T>(): { promise: Promise<T>; settle: (value: T) => void } {
  let settle: (value: T) => void = () => undefined;
  const promise = new Promise<T>((resolve) => {
    settle = resolve;
  });
  return { promise, settle };
}

function server(inspect: (url: URL) => unknown) {
  return stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/search': results(0),
    '/api/v1/search/inspect': inspect,
  });
}

const inspectRequests = (fetch: ReturnType<typeof server>) =>
  fetch.mock.calls.map(([url]) => new URL(String(url), 'http://localhost')).filter((url) => url.pathname === '/api/v1/search/inspect');

const blameRequests = (fetch: ReturnType<typeof server>) =>
  inspectRequests(fetch).filter((url) => url.searchParams.get('emptyConjuncts') === 'true');

describe('the Query Inspector', () => {
  it('follows the text as it is typed, and gives its terms’ detail, then their counts in scope, on request', async () => {
    const fetch = server((url) => (url.searchParams.get('scopedCounts') === 'true' ? counted : cheap));
    renderAt('/search');
    const box = await screen.findByRole('searchbox', { name: 'Search the documents' });
    expect(screen.queryByRole('region', { name: 'Query Inspector' })).toBeNull();
    await userEvent.type(box, '  negotiating -canal ');
    const strip = await screen.findByRole('region', { name: 'Query Inspector' });
    expect(strip.textContent).toContain('MATCH "negotiating" NOT "canal"');
    // Asked once typing settled, for the text trimmed, as the Mac reads its field; no page, no search made.
    const asked = inspectRequests(fetch);
    expect(asked).toHaveLength(1);
    expect(asked[0]?.searchParams.get('keywords')).toBe('negotiating -canal');
    expect(['limit', 'offset', 'sort', 'scopedCounts'].some((name) => asked[0]?.searchParams.has(name))).toBe(false);
    expect(fetch.mock.calls.some(([url]) => String(url).startsWith('/api/v1/search?'))).toBe(false);

    // The term detail is closed until asked for.
    expect(within(strip).queryByRole('list')).toBeNull();
    const toggle = within(strip).getByRole('button', { name: 'Show term detail' });
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    await userEvent.click(toggle);
    expect(within(strip).getByRole('button', { name: 'Hide term detail' }).getAttribute('aria-expanded')).toBe('true');
    const [first, second] = within(strip).getAllByRole('listitem');
    expect(first?.textContent).toBe(
      'negotiating 2 across everything this server has indexed ⚠ negotiating is searched as negoti — other words with that root match too',
    );
    expect(second?.textContent).toBe('canal EXCLUDED excluded — documents containing this are removed wherever the expression above applies it');
    expect(strip.textContent).toContain('Counts are over the 2 volumes indexed on this server — not the whole published series.');

    // Each term counted within the filters: the offer goes, and focus stays in the strip.
    await userEvent.click(within(strip).getByRole('button', { name: 'Count each term in scope…' }));
    await waitFor(() => expect(first?.textContent).toContain('2 in your current scope · 2 across everything this server has indexed'));
    expect(within(strip).queryByRole('button', { name: 'Count each term in scope…' })).toBeNull();
    expect(document.activeElement).toBe(within(strip).getByRole('button', { name: 'Hide term detail' }));
    expect(inspectRequests(fetch).filter((url) => url.searchParams.get('scopedCounts') === 'true')).toHaveLength(1);
  });

  it('drops the counts when the text changes, and offers them again for the same text', async () => {
    const canalx: SearchInspection = {
      inspection: inspection({ ...cheap.inspection, expression: { corpus: '"negotiating" NOT "canalx"', displayed: '"negotiating" NOT "canalx"', expressionsDiffer: false } }),
    };
    const fetch = server((url) =>
      url.searchParams.get('scopedCounts') === 'true' ? counted : url.searchParams.get('keywords') === 'negotiating -canalx' ? canalx : cheap,
    );
    renderAt('/search');
    const box = await screen.findByRole('searchbox', { name: 'Search the documents' });
    await userEvent.type(box, 'negotiating -canal');
    const strip = await screen.findByRole('region', { name: 'Query Inspector' });
    await userEvent.click(within(strip).getByRole('button', { name: 'Show term detail' }));
    await userEvent.click(within(strip).getByRole('button', { name: 'Count each term in scope…' }));
    await waitFor(() => expect(strip.textContent).toContain('2 in your current scope'));
    await userEvent.type(box, 'x');
    await waitFor(() => expect(strip.textContent).toContain('NOT "canalx"'));
    expect(strip.textContent).not.toContain('in your current scope');
    // Back to the text counted, whose account is kept: its counts were dropped with the change.
    await userEvent.type(box, '{Backspace}');
    await waitFor(() => expect(strip.textContent).toContain('NOT "canal"'));
    expect(strip.textContent).not.toContain('in your current scope');
    expect(within(strip).getByRole('button', { name: 'Count each term in scope…' })).toBeTruthy();
    // Counted once, when asked, and not again on the way back.
    expect(inspectRequests(fetch).filter((url) => url.searchParams.get('scopedCounts') === 'true')).toHaveLength(1);
  });

  it('shows nothing from before the box was emptied while the next query’s account is asked for', async () => {
    const war = heldBack<SearchInspection>();
    const expression = (text: string): SearchInspection => ({
      inspection: inspection({ expression: { corpus: `"${text}"`, displayed: `"${text}"`, expressionsDiffer: false }, operands: [term(text)] }),
    });
    const fetch = server((url) => (url.searchParams.get('keywords') === 'war' ? war.promise : expression('cold')));
    renderAt('/search');
    const box = await screen.findByRole('searchbox', { name: 'Search the documents' });
    await userEvent.type(box, 'cold');
    expect((await screen.findByRole('region', { name: 'Query Inspector' })).textContent).toContain('MATCH "cold"');
    await userEvent.clear(box);
    await waitFor(() => expect(screen.queryByRole('region', { name: 'Query Inspector' })).toBeNull());
    await userEvent.type(box, 'war');
    await waitFor(() => expect(inspectRequests(fetch).some((url) => url.searchParams.get('keywords') === 'war')).toBe(true));
    expect(screen.queryByRole('region', { name: 'Query Inspector' })).toBeNull();
    war.settle(expression('war'));
    expect((await screen.findByRole('region', { name: 'Query Inspector' })).textContent).toContain('MATCH "war"');
  });

  it('says in one line why a query has no expression, and lists what the search leaves out', async () => {
    const answers: Record<string, SearchInspection> = {
      '-korea': { inspection: inspection({ isRefused: true, hasOperands: false, showsTermRows: false }) },
      'NEAR(cold OR war)': { inspection: inspection({ isRefused: true, malformedProximity: 'NEAR(cold OR war)', showsTermRows: false }) },
      '': { inspection: inspection({ isFilterOnly: true, hasOperands: false, showsTermRows: false }) },
      'cold OR -korea': {
        inspection: inspection({
          expression: { corpus: '"cold"', displayed: '"cold"', expressionsDiffer: false },
          operands: [term('cold', { corpusDocumentFrequency: 9, corpusOccurrences: 30, corpusOccurrencesPerDocument: 30 / 9 })],
          notApplied: [operand('korea', { isNegated: true })],
          isApproximate: true,
          showsApproximateCaption: true,
        }),
      },
      'lone': { inspection: inspection({ showsStrip: false }) },
    };
    const fetch = server((url) => answers[url.searchParams.get('keywords') ?? ''] ?? new ProblemAnswer(400, 'INVALID_PARAMETER', 'unexpected'));
    const lines: Record<string, string> = {
      '/search?keywords=-korea':
        'No expression — this query cannot run: nothing is left to search for once its exclusions apply, or its parentheses nest more than 32 deep.',
      '/search?keywords=NEAR(cold+OR+war)':
        'No expression — NEAR(cold OR war) holds something a NEAR cannot: a boolean, a minus sign, a nested group, or a distance that is not a whole number. The query was refused rather than run as an ordinary boolean search.',
      '/search?keywords=&personRollupId=1&personLabel=Khrushchev': 'No text search — this query is filters only, so there is no expression to show.',
    };
    for (const [href, line] of Object.entries(lines)) {
      renderAt(href);
      const strip = await screen.findByRole('region', { name: 'Query Inspector' });
      expect(strip.textContent).toContain(line);
      expect(strip.textContent).not.toContain('MATCH');
      cleanup();
    }

    renderAt('/search?keywords=cold+OR+-korea');
    const strip = await screen.findByRole('region', { name: 'Query Inspector' });
    expect(strip.textContent).toContain(
      'Narrower than typed: part of this query only excludes terms, and a search needs something to find, so that part was left out.',
    );
    await userEvent.click(within(strip).getByRole('button', { name: 'Show term detail' }));
    expect(within(strip).getAllByRole('listitem').map((item) => item.textContent)).toEqual([
      'cold 9 across everything this server has indexed · 30 occurrences, 3.3 per document',
      'korea NOT APPLIED not searched — this part of the query only excludes, and a search needs something to find, so it was left out',
    ]);
    cleanup();

    // Nothing to say, nothing shown.
    renderAt('/search?keywords=lone');
    await waitFor(() => expect(inspectRequests(fetch).some((url) => url.searchParams.get('keywords') === 'lone')).toBe(true));
    expect(screen.queryByRole('region', { name: 'Query Inspector' })).toBeNull();
  });
});

describe('a term’s count line', () => {
  it('gives occurrences only where they come to 1.5 a document, and says when a term has no single index form', () => {
    expect(countLine(term('cold', { corpusDocumentFrequency: 10, corpusOccurrences: 14, corpusOccurrencesPerDocument: 1.4 }))).toBe(
      '10 across everything this server has indexed',
    );
    expect(countLine(term('cold', { scopedCount: 1234, corpusDocumentFrequency: 2000, corpusOccurrences: 3000, corpusOccurrencesPerDocument: 1.5 }))).toBe(
      '1,234 in your current scope · 2,000 across everything this server has indexed · 3,000 occurrences, 1.5 per document',
    );
    // Half to even, as the Mac's formatter rounds: 9 in 4 documents is 2.2 a document, 11 in 4 is 2.8.
    expect(countLine(term('cold', { corpusDocumentFrequency: 4, corpusOccurrences: 9, corpusOccurrencesPerDocument: 2.25 }))).toBe(
      '4 across everything this server has indexed · 9 occurrences, 2.2 per document',
    );
    expect(countLine(term('cold', { corpusDocumentFrequency: 4, corpusOccurrences: 11, corpusOccurrencesPerDocument: 2.75 }))).toBe(
      '4 across everything this server has indexed · 11 occurrences, 2.8 per document',
    );
    expect(countLine(term('"cold war"', {}, { kind: 'phrase' }))).toBe('no corpus count — this term has no single index form');
    expect(countLine(term('"cold war"', { scopedCount: 4 }, { kind: 'phrase' }))).toBe('4 in your current scope');
  });
});

describe('a search that found nothing', () => {
  it('names the term that matched nothing in the reader’s scope, or says the combination is what matches nothing', async () => {
    const blame: Record<string, SearchInspection> = {
      'negotiating formosa': { inspection: inspection({}), emptyConjuncts: [operand('formosa')] },
      'formosa zanzibar': { inspection: inspection({}), emptyConjuncts: [operand('formosa'), operand('zanzibar')] },
      'negotiating canal': { inspection: inspection({}), emptyConjuncts: [] },
      '"': { inspection: inspection({ hasOperands: false }), emptyConjuncts: [] },
    };
    const fetch = server((url) =>
      url.searchParams.get('emptyConjuncts') === 'true'
        ? (blame[url.searchParams.get('keywords') ?? ''] ?? new ProblemAnswer(400, 'INVALID_PARAMETER', 'unexpected'))
        : { inspection: inspection({ showsStrip: false }) },
    );
    const messages: Record<string, string> = {
      'negotiating+formosa': 'formosa matches no document in your current scope. The rest of your query is not the problem.',
      'formosa+zanzibar': 'formosa, zanzibar match no document in your current scope.',
      'negotiating+canal': 'Each of your terms matches something on its own — it is the combination that appears in no single document.',
      '%22': 'Try different keywords or adjust your filters.',
      'unknown': 'Try different keywords or adjust your filters.',
    };
    for (const [keywords, message] of Object.entries(messages)) {
      renderAt(`/search?keywords=${keywords}&volumeIds=frus1961-63v06`);
      const heading = await screen.findByRole('heading', { name: 'No Results' });
      const view = heading.parentElement as HTMLElement;
      await waitFor(() => expect(view.textContent).toContain(message));
      // The denominator comes with the inspector's answer; a failure to ask has none.
      if (keywords === 'unknown') expect(view.textContent).not.toContain('0 here means 0');
      else expect(view.textContent).toContain('0 here means 0 in what this server has indexed — 2 volumes.');
      cleanup();
    }
    // Each asked for the search that ran, with its filters.
    const asked = inspectRequests(fetch).filter((url) => url.searchParams.get('emptyConjuncts') === 'true');
    expect(asked.map((url) => url.searchParams.get('keywords'))).toEqual(['negotiating formosa', 'formosa zanzibar', 'negotiating canal', '"', 'unknown']);
    expect(asked.every((url) => url.searchParams.get('volumeIds') === 'frus1961-63v06')).toBe(true);
  });

  it('waits for the search shown to be the one made before it says why that one found nothing', async () => {
    const next = heldBack<SearchResultList>();
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/search': (url: URL) => (url.searchParams.get('keywords') === 'negotiating' ? next.promise : results(0)),
      '/api/v1/search/inspect': (url: URL) =>
        url.searchParams.get('emptyConjuncts') === 'true'
          ? { inspection: inspection({}), emptyConjuncts: [operand('formosa')] }
          : { inspection: inspection({ showsStrip: false }) },
    });
    renderAt('/search?keywords=negotiating+formosa');
    expect(await screen.findByText(/^formosa matches no document/)).toBeTruthy();
    const box = screen.getByRole('searchbox', { name: 'Search the documents' });
    await userEvent.clear(box);
    await userEvent.type(box, 'negotiating{Enter}');
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).startsWith('/api/v1/search?keywords=negotiating&'))).toBe(true));
    // While the last search's page stands in for this one's, nothing is said of either.
    expect(screen.queryByRole('heading', { name: 'No Results' })).toBeNull();
    expect(blameRequests(fetch).map((url) => url.searchParams.get('keywords'))).toEqual(['negotiating formosa']);
    next.settle(results(1, [telegram]));
    expect(await screen.findByRole('link', { name: 'Telegram' })).toBeTruthy();
    expect(blameRequests(fetch)).toHaveLength(1);
  });

  it('asks again why a search found nothing when the same search is made again', async () => {
    const fetch = server((url) =>
      url.searchParams.get('emptyConjuncts') === 'true'
        ? { inspection: inspection({}), emptyConjuncts: [operand('formosa')] }
        : { inspection: inspection({ showsStrip: false }) },
    );
    renderAt('/search?keywords=negotiating+formosa');
    await screen.findByText(/^formosa matches no document/);
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search the documents' }), '{Enter}');
    await waitFor(() => expect(blameRequests(fetch)).toHaveLength(2));
  });

  it('says only that nothing matched when the search had no text', async () => {
    server(() => ({ inspection: inspection({ showsStrip: false }) }));
    renderAt('/search?keywords=&volumeIds=frus1961-63v06');
    expect(await screen.findByText('No documents match.')).toBeTruthy();
    expect(screen.queryByRole('heading', { name: 'No Results' })).toBeNull();
  });
});
