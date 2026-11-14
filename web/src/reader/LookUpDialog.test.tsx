// Look Up in NARA Catalog (PLAN's S22e) over a stubbed server: the sheet in the app's order and words, opened on
// the strategy the server gives, a reading filling the search, Search refused without a key with the app's
// warning, a search through the server's proxy with its records, a change of strategy clearing them, the filing
// periods for Central files identifier, a refusal in the server's words, and Escape.
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { LookUpAnswer, LookUpSelection, NARAStatus } from '../api/nara';
import { me, sent } from '../test/notes';
import { ProblemAnswer, stubServer } from '../test/renderRoute';
import { LookUpDialog } from './LookUpDialog';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const lookUpPath = '/api/v1/volumes/frus1961-63v06/documents/d3/lookup';

/** The server's answer for d3's source note, as `LookUpRoutes.answer` writes it. */
const sheet: LookUpAnswer = {
  candidates: [
    {
      id: 'lotFileRG59|66 D 204',
      label: 'Lot 66 D 204',
      query: '66 D 204',
      strategy: 'lotFileRG59',
      origin: 'selection',
      resolution: { naId: '1234567', title: 'Presidential Correspondence', catalogURL: 'https://catalog.archives.gov/id/1234567' },
    },
    { id: 'keyword|Khrushchev Correspondence', label: 'Kennedy Library, Khrushchev Correspondence', query: 'Khrushchev Correspondence', strategy: 'keyword', origin: 'context' },
  ],
  strategy: 'lotFileRG59',
  strategies: [
    { id: 'lotFileRG59', name: 'Lot file — RG 59 (State Dept.)', hint: 'Use for D-designator lot numbers.', searches: true },
    { id: 'lotFileRG84', name: 'Lot file — RG 84 (Post Records)', hint: 'Use for F-designator lot numbers.', searches: true },
    { id: 'keywordRG59', name: 'Keywords in RG 59', hint: 'Restricts results to RG 59.', searches: true },
    { id: 'keywordRG84', name: 'Keywords in RG 84', hint: 'Restricts results to RG 84.', searches: true },
    { id: 'centralURL', name: 'Central files identifier (no API key)', hint: 'Opens a pre-filtered NARA Catalog search.', searches: false },
    { id: 'keyword', name: 'General keyword search', hint: 'General free-text search.', searches: true },
  ],
  periods: [
    { id: '1910-1963', label: '1910–January 1963', url: 'https://www.archives.gov/research/1910-1963', manuals: [{ url: 'https://www.archives.gov/files/manual.pdf', label: 'Filing Manual (PDF)' }] },
  ],
};

const selection: LookUpSelection = { text: '  Lot 66 D 204 ', blockText: 'Source: Department of State, Presidential Correspondence: Lot 66 D 204.' };

function open(status: NARAStatus, answers: Record<string, unknown> = {}, onClose = () => {}) {
  const fetch = stubServer({ '/api/v1/me': me, '/api/v1/nara': status, [`POST ${lookUpPath}`]: sheet, ...answers });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={client}>
      <LookUpDialog volumeId="frus1961-63v06" documentId="d3" selection={selection} onClose={onClose} />
    </QueryClientProvider>,
  );
  return fetch;
}

const searches = (fetch: ReturnType<typeof stubServer>) =>
  fetch.mock.calls.filter(([url, init]) => init?.method === 'POST' && String(url).endsWith('/api/v1/nara/search')).map(([, init]) => sent(init).body);

describe('Look Up in NARA Catalog', () => {
  it('opens on the selection and the readings of the passage, in the app’s order and words, and fills the search from one', async () => {
    const fetch = open({ key: 'user', offline: false });
    const dialog = screen.getByRole('dialog', { name: 'Look Up in NARA Catalog' });
    expect(document.activeElement).toBe(within(dialog).getByRole('heading', { name: 'Look Up in NARA Catalog' }));
    const field = within(dialog).getByRole('textbox', { name: 'Search Text' });
    expect((field as HTMLInputElement).value).toBe('Lot 66 D 204');
    expect(field.getAttribute('placeholder')).toBe('Lot number, file identifier, or keywords');
    expect(within(dialog).getByText('Edit the selected text before searching if needed.')).toBeTruthy();

    const detected = await within(dialog).findByRole('region', { name: 'Detected in This Passage' });
    // The selection and its footnote, as the reader sent them.
    const asked = fetch.mock.calls.find(([url]) => String(url).endsWith(lookUpPath));
    expect(sent(asked?.[1]).body).toEqual(selection);
    const readings = within(detected).getAllByRole('button');
    expect(readings.map((button) => button.textContent)).toEqual([
      'Lot 66 D 204Presidential CorrespondenceNAID 1234567 — from the bundled index; no API key needed',
      'Kennedy Library, Khrushchev Correspondence',
    ]);
    expect(readings[0]!.getAttribute('aria-description') ?? readings[0]!.getAttribute('aria-describedby')).toBeTruthy();
    expect(within(detected).getByText('Archival citations found in the selected text and around it — select one to fill the search.')).toBeTruthy();
    // The strategy the server says the sheet opens on, with its hint; the kit's six, in its order.
    const strategies = within(dialog).getByRole('group', { name: 'Query Strategy' });
    expect(within(strategies).getAllByRole('radio').map((radio) => radio.closest('label')?.textContent?.trim())).toEqual(sheet.strategies.map((each) => each.name));
    expect((within(strategies).getByRole('radio', { name: 'Lot file — RG 59 (State Dept.)' }) as HTMLInputElement).checked).toBe(true);
    expect(within(strategies).getByText('Use for D-designator lot numbers.')).toBeTruthy();

    // The second reading fills the search with its query and its strategy; nothing is searched by a tap.
    await userEvent.click(readings[1]!);
    expect((field as HTMLInputElement).value).toBe('Khrushchev Correspondence');
    expect((within(strategies).getByRole('radio', { name: 'General keyword search' }) as HTMLInputElement).checked).toBe(true);
    expect(searches(fetch)).toEqual([]);
  });

  it('searches nothing without a key, with the app’s warning naming the web’s place for keys', async () => {
    const fetch = open({ offline: false });
    const dialog = screen.getByRole('dialog', { name: 'Look Up in NARA Catalog' });
    expect(
      await within(dialog).findByText(
        'A NARA Catalog API key is required for this strategy. Add your key in Settings ▸ Keys. The “Central files identifier” strategy does not require a key.',
      ),
    ).toBeTruthy();
    const search = within(dialog).getByRole('button', { name: 'Search' });
    expect(search.getAttribute('aria-disabled')).toBe('true');
    await userEvent.click(search);
    await userEvent.type(within(dialog).getByRole('textbox', { name: 'Search Text' }), '{Enter}');
    expect(searches(fetch)).toEqual([]);
    // Central files identifier needs no key: its filing periods, and no Search.
    await userEvent.click(within(dialog).getByRole('radio', { name: 'Central files identifier (no API key)' }));
    const periods = within(dialog).getByRole('region', { name: 'NARA Finding Aids by Period' });
    expect(within(periods).getByRole('link', { name: '1910–January 1963' }).getAttribute('href')).toBe('https://www.archives.gov/research/1910-1963');
    expect(within(periods).getByRole('link', { name: 'Filing Manual (PDF)' })).toBeTruthy();
    expect(within(dialog).queryByRole('button', { name: 'Search' })).toBeNull();
    expect(within(dialog).queryByText(/A NARA Catalog API key is required/)).toBeNull();
  });

  it('searches through the server by Search or Return, lists the records, and clears them for another strategy', async () => {
    const record = { naId: '4567', title: 'Records Relating to Lot 66D204', catalogURL: 'https://catalog.archives.gov/id/4567', scopeNote: 'Subject files.', dateRange: '1961–1963' };
    const fetch = open({ key: 'instance', quota: { used: 0, limit: 100 }, offline: false }, { 'POST /api/v1/nara/search': { results: [record], cached: false } });
    const dialog = screen.getByRole('dialog', { name: 'Look Up in NARA Catalog' });
    await within(dialog).findByRole('region', { name: 'Detected in This Passage' });
    const field = within(dialog).getByRole('textbox', { name: 'Search Text' });
    await userEvent.type(field, '{Enter}');
    const results = await within(dialog).findByRole('region', { name: 'NARA Catalog Results' });
    await within(results).findByText('Records Relating to Lot 66D204');
    expect(searches(fetch)).toEqual([{ strategy: 'lotFileRG59', query: 'Lot 66 D 204' }]);
    expect(within(results).getByRole('status').textContent).toBe('1 record found.');
    expect(within(results).getByText('Subject files.')).toBeTruthy();
    expect(within(results).getByText('1961–1963')).toBeTruthy();
    expect(within(results).getByRole('link', { name: 'View in NARA Catalog' }).getAttribute('href')).toBe(record.catalogURL);
    // Another strategy clears the results; Search runs it.
    await userEvent.click(within(dialog).getByRole('radio', { name: 'Keywords in RG 59' }));
    expect(within(dialog).queryByRole('region', { name: 'NARA Catalog Results' })).toBeNull();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Search' }));
    await waitFor(() => expect(searches(fetch)).toHaveLength(2));
    expect(searches(fetch)[1]).toEqual({ strategy: 'keywordRG59', query: 'Lot 66 D 204' });
  });

  it('says what the server says of a refused search, and none found in the app’s words; Escape closes it', async () => {
    let refuse = true;
    const onClose = vi.fn<() => void>();
    open(
      { key: 'user', offline: false },
      {
        'POST /api/v1/nara/search': () =>
          refuse
            ? new ProblemAnswer(409, 'NARA_KEY_REJECTED', 'NARA Catalog API key was rejected (HTTP 403). Check the key in Settings ▸ Keys.')
            : { results: [], cached: true },
      },
      onClose,
    );
    const dialog = screen.getByRole('dialog', { name: 'Look Up in NARA Catalog' });
    await within(dialog).findByRole('region', { name: 'Detected in This Passage' });
    await userEvent.click(within(dialog).getByRole('button', { name: 'Search' }));
    expect((await within(dialog).findByRole('alert')).textContent).toBe(
      'NARA Catalog API key was rejected (HTTP 403). Check the key in Settings ▸ Keys.',
    );
    refuse = false;
    await userEvent.click(within(dialog).getByRole('button', { name: 'Search' }));
    expect(
      await within(dialog).findByText('No matching records found. Try editing the search text or selecting a different strategy.'),
    ).toBeTruthy();
    // Escape, which the browser sends the dialog as its cancel.
    fireEvent(dialog, new Event('cancel', { cancelable: true }));
    expect(onClose).toHaveBeenCalled();
  });
});
