// The cross-reference graph's page (PLAN's S23e) over a stubbed server, its canvas stubbed too, since
// jsdom draws no canvas: the banner, the toolbar and its note, the keyboard's walk through the nodes and
// what Enter does, the details, the reference list, and the degree in the address.
import { cleanup, fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { DocumentGraph } from '../api/graph';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

vi.mock('./GraphCanvas', () => ({
  GraphCanvas: (props: { nodes: { id: string }[]; activeNode?: string; selectedNode?: string }) => (
    <div
      data-testid="canvas"
      data-nodes={props.nodes.map((node) => node.id).join(' ')}
      data-active={props.activeNode}
      data-selected={props.selectedNode}
    />
  ),
}));

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const path = '/api/v1/volumes/frus1961-63v06/documents/d1/graph';
const anchor = '/api/v1/volumes/frus1961-63v06/documents/d1';
const document = {
  document: { volumeId: 'frus1961-63v06', documentId: 'd1', displayTitle: 'Telegram to Moscow', inIndex: true },
  canonicalURL: 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1',
  teiAvailable: true,
};

function answer(fields: Partial<DocumentGraph> = {}): DocumentGraph {
  const central = 'frus1961-63v06/d1';
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    centralKey: central,
    degree: 2,
    widened: true,
    layout: 'network',
    timelineEligible: false,
    hasUndownloadedSources: true,
    undownloadedCitingVolumeIds: ['frus1952-54v02p1', 'frus1955-57v24'],
    undownloadedCitingCount: 3,
    expandedClusters: [],
    nodes: [
      {
        id: central,
        kind: 'central',
        degree: 0,
        isDownloaded: true,
        label: 'Telegram to Moscow',
        rowTitle: 'Telegram to Moscow',
        isPageNode: false,
        opens: true,
        header: 'Telegram to Moscow',
        volumeId: 'frus1961-63v06',
        documentId: 'd1',
      },
      {
        id: 'frus1961-63v06/d2',
        kind: 'inbound',
        degree: 1,
        isDownloaded: true,
        label: 'Inbound: Memorandum of Conversation',
        title: 'Doc. 2',
        rowTitle: 'Memorandum of Conversation',
        rowNumber: '2',
        dateLabel: 'Jan 3, 1961',
        isPageNode: false,
        opens: true,
        header: '2. Memorandum of Conversation',
        dateline: 'Washington, January 3, 1961',
        volumeId: 'frus1961-63v06',
        documentId: 'd2',
        documentNumber: '2',
        connectionCount: 4,
      },
      {
        id: 'cluster/inbound/frus1952-54v02p1',
        kind: 'clusterInbound',
        degree: 1,
        isDownloaded: false,
        label: '31 inbound documents from volume frus1952-54v02p1',
        title: '31 docs',
        rowTitle: 'cluster/inbound/frus1952-54v02p1',
        isPageNode: false,
        opens: false,
        volumeId: 'frus1952-54v02p1',
        count: 31,
      },
      {
        id: 'frus1955-57v24/pg_12',
        kind: 'extended',
        degree: 2,
        isDownloaded: false,
        label: 'Degree 2: 1955–57, vol. XXIV, p. 12',
        title: 'p. 12',
        rowTitle: '1955–57, vol. XXIV, p. 12',
        isPageNode: true,
        opens: false,
        header: '1955–57, vol. XXIV, p. 12',
        volumeId: 'frus1955-57v24',
        documentId: 'pg_12',
        citedPage: 12,
      },
      {
        id: 'unit/frus1961-63v06/d2/c9',
        kind: 'unit',
        degree: 1,
        isDownloaded: true,
        label: 'Unprinted archival material: Lot 59 D 95. Opens the collection record.',
        rowTitle: 'unit/frus1961-63v06/d2/c9',
        isPageNode: false,
        opens: false,
        collectionId: 'c9',
        name: 'Lot 59 D 95',
      },
    ],
    edges: [
      {
        id: `frus1961-63v06/d2->${central}`,
        source: 'frus1961-63v06/d2',
        target: central,
        referenceType: 'footnote',
        contexts: ['See Document 1.'],
        referenceCount: 2,
        degree: 1,
      },
      {
        id: `cluster/inbound/frus1952-54v02p1->${central}`,
        source: 'cluster/inbound/frus1952-54v02p1',
        target: central,
        referenceType: 'footnote',
        contexts: [],
        referenceCount: 31,
        degree: 1,
      },
      {
        id: 'frus1961-63v06/d2->frus1955-57v24/pg_12',
        source: 'frus1961-63v06/d2',
        target: 'frus1955-57v24/pg_12',
        referenceType: 'footnote',
        contexts: [],
        referenceCount: 1,
        degree: 2,
      },
      {
        id: 'frus1961-63v06/d2->unit/frus1961-63v06/d2/c9',
        source: 'frus1961-63v06/d2',
        target: 'unit/frus1961-63v06/d2/c9',
        referenceType: 'footnote',
        contexts: [],
        referenceCount: 1,
        degree: 1,
      },
    ],
    referenceList: { inbound: ['frus1961-63v06/d2', 'cluster/inbound/frus1952-54v02p1'], outbound: [], extended: ['frus1955-57v24/pg_12'] },
    ...fields,
  };
}

describe('the cross-reference graph', () => {
  it('shows the banner, the toolbar with its note, the legend and the reference list', async () => {
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer() });
    renderAt('/graph/frus1961-63v06/d1');
    expect(await screen.findByRole('heading', { level: 1, name: 'Cross-References' })).toBeTruthy();
    expect(await screen.findByRole('link', { name: 'Back to Telegram to Moscow' })).toBeTruthy();
    expect(
      await screen.findByText('3 documents in 2 volumes this server does not hold also cite this one. They are shown without titles.'),
    ).toBeTruthy();
    // The picker shows the degree the reader chose, one, and the note says the graph was widened.
    expect((screen.getByRole('radio', { name: '1 hop' }) as HTMLInputElement).checked).toBe(true);
    expect(screen.getByText('Few direct references — showing 2 hops')).toBeTruthy();
    // Too few dates for a timeline: the layout picker is set aside.
    expect(screen.getByRole('radio', { name: 'Timeline' }).matches(':disabled')).toBe(true);
    const legend = screen.getByRole('list', { name: 'Graph legend' });
    expect(within(legend).getByText('Not printed')).toBeTruthy();
    // The reference list's sections, each row its number and title, its date, volume and count.
    expect(screen.getByRole('heading', { level: 2, name: 'Cites This Document' })).toBeTruthy();
    expect(screen.getByRole('heading', { level: 2, name: 'Further Hops' })).toBeTruthy();
    expect(screen.queryByRole('heading', { level: 2, name: 'Cited By This Document' })).toBeNull();
    const row = screen.getByRole('button', { name: 'Inbound: Memorandum of Conversation' });
    expect(row.textContent).toContain('2.Memorandum of Conversation');
    expect(row.textContent).toContain('Jan 3, 1961');
    expect(row.textContent).toContain('×2');
    expect(row.textContent).toContain('See Document 1.');
    expect(within(row.closest('li')!).getByRole('link', { name: 'Open document' }).getAttribute('href')).toBe('/doc/frus1961-63v06/d2');
    // A page, which opens nothing, has its Open set aside.
    const page = screen.getByRole('button', { name: 'Degree 2: 1955–57, vol. XXIV, p. 12' });
    expect((within(page.closest('li')!).getByRole('button', { name: 'Open document' }) as HTMLButtonElement).disabled).toBe(true);
    expect(screen.getByText('Select a document in the graph or the list below to see its details.')).toBeTruthy();
  });

  it('walks every node by keyboard, in the order of the reference list, and Enter shows a document’s details', async () => {
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer() });
    const user = userEvent.setup();
    renderAt('/graph/frus1961-63v06/d1');
    const nodes = await screen.findByRole('listbox', { name: 'Cross-reference graph' });
    const spoken = () => {
      const id = nodes.getAttribute('aria-activedescendant');
      return id ? window.document.getElementById(id)?.textContent : undefined;
    };
    nodes.focus();
    expect(spoken()).toBe('Telegram to Moscow');
    const heard: (string | null | undefined)[] = [spoken()];
    for (let step = 0; step < 5; step++) {
      await user.keyboard('{ArrowDown}');
      heard.push(spoken());
    }
    // The central document, the two that cite it, the page further out, then the archival unit; the walk
    // stops at the end.
    expect(heard).toEqual([
      'Telegram to Moscow',
      'Inbound: Memorandum of Conversation',
      '31 inbound documents from volume frus1952-54v02p1',
      'Degree 2: 1955–57, vol. XXIV, p. 12',
      'Unprinted archival material: Lot 59 D 95. Opens the collection record.',
      'Unprinted archival material: Lot 59 D 95. Opens the collection record.',
    ]);
    expect(within(nodes).getByRole('group', { name: 'Inbound References' })).toBeTruthy();
    expect(within(nodes).getByRole('group', { name: 'Archival material' })).toBeTruthy();
    await user.keyboard('{Home}{ArrowDown}');
    expect(screen.getByTestId('canvas').getAttribute('data-active')).toBe('frus1961-63v06/d2');
    await user.keyboard('{Enter}');
    const details = await screen.findByRole('region', { name: '2. Memorandum of Conversation' });
    expect(within(details).getByText('Washington, January 3, 1961')).toBeTruthy();
    expect(within(details).getByText('Referenced in')).toBeTruthy();
    expect(within(details).getByText('See Document 1.')).toBeTruthy();
    expect(within(details).getByRole('link', { name: 'View Document' }).getAttribute('href')).toBe('/doc/frus1961-63v06/d2');
    expect(within(details).getByRole('link', { name: 'Recenter' }).getAttribute('href')).toBe('/graph/frus1961-63v06/d2');
    expect(nodes.querySelector('[aria-selected="true"]')?.textContent).toBe('Inbound: Memorandum of Conversation');
    expect(window.document.activeElement).toBe(nodes);
    // Escape closes the details.
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('region', { name: '2. Memorandum of Conversation' })).toBeNull();
    // The archival unit's details open its collection's record (PLAN's S22d).
    await user.keyboard('{End}{Enter}');
    const unit = await screen.findByRole('region', { name: /Lot 59 D 95/ });
    expect(within(unit).getByRole('link', { name: 'View Collection' }).getAttribute('href')).toBe('/archival-collection?id=c9');
  });

  it('expands a cluster on Enter, with the cluster in the address', async () => {
    const fetch = stubServer({ '/readyz': ready, [anchor]: document, [path]: answer() });
    const user = userEvent.setup();
    const { router } = renderAt('/graph/frus1961-63v06/d1');
    const nodes = await screen.findByRole('listbox', { name: 'Cross-reference graph' });
    nodes.focus();
    await user.keyboard('{ArrowDown}{ArrowDown}{Enter}');
    await waitFor(() => expect(router.state.location.search).toEqual({ expand: 'cluster/inbound/frus1952-54v02p1' }));
    await waitFor(() =>
      expect(fetch.mock.calls.some(([url]) => String(url).includes('expand=cluster%2Finbound%2Ffrus1952-54v02p1'))).toBe(true),
    );
  });

  it('loads the degree chosen, kept in the address, and shows a refusal as the app’s error', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      [anchor]: document,
      [path]: (url: URL) => answer({ chosenDegree: Number(url.searchParams.get('degree') ?? 0) || undefined, widened: false }),
    });
    const user = userEvent.setup();
    const { router } = renderAt('/graph/frus1961-63v06/d1');
    await screen.findByRole('listbox', { name: 'Cross-reference graph' });
    await user.click(screen.getByRole('radio', { name: '3 hops' }));
    await waitFor(() => expect(router.state.location.search).toEqual({ degree: '3' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes('degree=3'))).toBe(true));
    expect(screen.queryByText('Few direct references — showing 2 hops')).toBeNull();
    cleanup();
    stubServer({ '/readyz': ready, [anchor]: document, [path]: new ProblemAnswer(503, 'INDEX_NOT_READY', 'No index is served yet.') });
    renderAt('/graph/frus1961-63v06/d1');
    const alert = await screen.findByRole('alert');
    expect(within(alert).getByRole('heading', { name: 'Graph Error' })).toBeTruthy();
    expect(alert.textContent).toContain('No index is served yet.');
  });

  it('selects a document from its row, as the app’s list pins it', async () => {
    stubServer({ '/readyz': ready, [anchor]: document, [path]: answer() });
    renderAt('/graph/frus1961-63v06/d1');
    const row = await screen.findByRole('button', { name: 'Inbound: Memorandum of Conversation' });
    fireEvent.click(row);
    expect(row.getAttribute('aria-pressed')).toBe('true');
    expect(screen.getByTestId('canvas').getAttribute('data-selected')).toBe('frus1961-63v06/d2');
    const close = screen.getByRole('button', { name: 'Close details' });
    fireEvent.click(close);
    expect(row.getAttribute('aria-pressed')).toBe('false');
  });
});
