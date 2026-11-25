import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ClusterDocuments, ClustersIndex } from '../api/clusters';
import { clusterSections } from '../api/clusters';
import type { WorkingCorpus } from '../api/searchSets';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { sent } from '../test/notes';
import { barHeight } from './ClustersScreen';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const layout = '89481b18:2026-10-15:314616';

const index: ClustersIndex = {
  layoutIdentity: layout,
  clusterCount: 140,
  documentCount: 314_616,
  unclusteredCount: 88_059,
  clusters: [
    {
      id: 3,
      label: 'nanking · shanghai · chinese · tientsin',
      documentCount: 37_899,
      eras: [
        { era: 0, count: 2_633, isPeak: false },
        { era: 1, count: 26_227, isPeak: true },
        { era: 2, count: 9_039, isPeak: true },
        { era: 3, count: 0, isPeak: false },
      ],
    },
    {
      id: 115,
      label: 'edc · nato · nuclear · soviet',
      documentCount: 10_914,
      eras: [
        { era: 0, count: 0, isPeak: false },
        { era: 1, count: 36, isPeak: true },
        { era: 2, count: 10_878, isPeak: true },
        { era: 3, count: 0, isPeak: false },
      ],
    },
  ],
};

type Section = ClusterDocuments['sections'][number];

function named(volumeId: string, ids: string[]): Section {
  return { volumeId, title: `Volume ${volumeId}`, indexed: false, documents: ids.map((documentId) => ({ volumeId, documentId })) };
}

const served: Section = {
  volumeId: 'frus1961-63v06',
  title: 'Kennedy-Khrushchev Exchanges',
  indexed: true,
  documents: [
    { volumeId: 'frus1961-63v06', documentId: 'd1', displayTitle: '1. Telegram From the Embassy in the Soviet Union', dateISO: '1960-11-09' },
    { volumeId: 'frus1961-63v06', documentId: 'd2', displayTitle: '2. Memorandum of Conversation', dateISO: '1960-11-10' },
  ],
};

/** A region of 1,100 members: three pages, the second finishing the volume the first page's boundary split. */
function page(shown: number, after: number): ClusterDocuments {
  const sections =
    after === 0
      ? [named('frus1952-54v01', ['d1', 'd2']), served]
      : after === 500
        ? [{ ...served, documents: [...served.documents, { volumeId: 'frus1961-63v06', documentId: 'd40' }] }, named('frus1961-63v10', ['d7'])]
        : [named('frus1964-68v12', ['d3', 'd4'])];
  return {
    id: 115,
    label: 'edc · nato · nuclear · soviet',
    name: 'edc nato nuclear',
    layoutIdentity: layout,
    documentCount: 10_914,
    eraRows: [
      { label: '1900–1944', count: '36' },
      { label: '1945–1990', count: '10,878' },
    ],
    total: 1_100,
    coverage: { indexedCount: 79, totalCount: 1_100, missingVolumeIds: ['frus1952-54v01'], isComplete: false },
    shown,
    after,
    sections,
  };
}

function documents(url: URL): ClusterDocuments {
  return page(Number(url.searchParams.get('shown')), Number(url.searchParams.get('after') ?? '0'));
}

const server = (answers: Record<string, unknown> = {}) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/clusters': index,
    '/api/v1/clusters/115': documents,
    '/api/v1/me/working-corpora': { total: 0, items: [] },
    ...answers,
  });

describe('Browse’s Clusters', () => {
  it('is an axis of Browse on every server, after All Volumes, as the Mac’s sidebar lists it before Editors’ Annotations', async () => {
    server({ '/api/v1/me': { ...me, userData: false } });
    renderAt('/browse/clusters');
    const axes = await screen.findByRole('navigation', { name: 'Browse by' });
    expect(within(axes).getAllByRole('link').map((link) => [link.textContent, link.getAttribute('aria-current')])).toEqual([
      ['All Volumes', null],
      ['Clusters', 'page'],
      ['Editors’ Annotations', null],
      ['People', null],
    ]);
  });

  it('lists the regions largest first under the kit’s caption, each its terms, its count and its eras’ histogram', async () => {
    server();
    renderAt('/browse/clusters');
    expect((await screen.findByRole('heading', { level: 1 })).textContent).toBe('Clusters');
    await screen.findByText(
      "140 clusters computed from document text. Labels are the most distinctive sampled terms, not subject headings. 88,059 documents (28.0%) belong to no cluster and cannot be reached from this list. Era bars reflect each volume's coverage era, not document dates.",
    );
    const rows = within(screen.getByRole('list', { name: 'Clusters' })).getAllByRole('listitem');
    expect(rows).toHaveLength(2);
    const first = within(rows[0]!).getByRole('link', { name: 'nanking · shanghai · chinese · tientsin, 37,899 documents' });
    expect(first.title).toBe('Browse this cluster’s documents, grouped by volume');
    expect(first.getAttribute('href')).toBe(`/browse/clusters/3?layout=${encodeURIComponent(layout)}`);
    expect(within(first).getByText('37,899 documents')).toBeTruthy();
    // The histogram: a bar an era, the shortest for an empty one, the two largest accented, read by no one.
    const histogram = first.querySelector('.cluster-histogram')!;
    expect(histogram.getAttribute('aria-hidden')).toBe('true');
    const bars = [...histogram.querySelectorAll<HTMLElement>('.cluster-bar')];
    expect(bars.map((bar) => bar.classList.contains('peak'))).toEqual([false, true, true, false]);
    expect(bars.map((bar) => parseFloat(bar.style.height))).toEqual([2, 18, (18 * 9_039) / 26_227, 2]);
    expect(within(rows[1]!).getByRole('link').getAttribute('aria-label')).toBe('edc · nato · nuclear · soviet, 10,914 documents');
  });

  it('draws a bar as the app does: its count against the largest, never under two pixels', () => {
    expect(barHeight(26_227, 26_227)).toBe(18);
    expect(barHeight(2_633, 26_227)).toBe(2);
    expect(barHeight(0, 26_227)).toBe(2);
    expect(barHeight(0, 0)).toBe(2);
    expect(barHeight(13_000, 26_000)).toBe(9);
  });

  it('says why there is no list, in the server’s words', async () => {
    server({
      '/api/v1/clusters': new ProblemAnswer(503, 'CLUSTERS_UNAVAILABLE', 'The cluster data and the semantic vectors come from different releases, so the list is not shown.'),
    });
    renderAt('/browse/clusters');
    const alert = await screen.findByRole('alert');
    expect(within(alert).getByRole('heading', { level: 2 }).textContent).toBe('Clusters Unavailable');
    expect(within(alert).getByText('The cluster data and the semantic vectors come from different releases, so the list is not shown.')).toBeTruthy();
  });
});

describe('A cluster’s documents', () => {
  it('opens with its count, its eras, what this server holds of it, the app’s account of a cluster and its first page', async () => {
    server();
    renderAt(`/browse/clusters/115?layout=${encodeURIComponent(layout)}`);
    expect((await screen.findByRole('heading', { level: 1, name: 'edc · nato · nuclear · soviet' })).getAttribute('data-loading')).toBeNull();
    const crumbs = screen.getByRole('navigation', { name: 'Breadcrumb' });
    expect(within(crumbs).getByRole('link', { name: 'Clusters' }).getAttribute('href')).toBe('/browse/clusters');
    const facts = document.querySelector('.cluster-facts')!;
    expect([...facts.querySelectorAll('dt')].map((term) => term.textContent)).toEqual(['Documents in the series', '1900–1944', '1945–1990']);
    expect([...facts.querySelectorAll('dd')].map((value) => value.textContent)).toEqual(['10,914', '36', '10,878']);
    expect(screen.getByText('79 of 1,100 documents indexed on this server').className).toBe('count warning');
    expect(screen.getByText(/^A cluster is a grouping detected by an AI model that the corpus fell into on its own\./)).toBeTruthy();
    // See on the semantic map: the map opened on the region, in the layout its id was minted in.
    const map = screen.getByRole('link', { name: 'See on the semantic map' });
    expect(map.getAttribute('href')).toBe(`/analytics/semantic?region=115&layout=${encodeURIComponent(layout)}`);
    // Its documents in volume order, a section a volume: those this server holds open, the rest are named.
    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'Volume frus1952-54v01',
      'Kennedy-Khrushchev Exchanges',
    ]);
    const telegram = screen.getByRole('link', { name: '1. Telegram From the Embassy in the Soviet Union' });
    expect(telegram.getAttribute('href')).toBe('/doc/frus1961-63v06/d1');
    expect(screen.getByText('frus1952-54v01 · d1').closest('li')?.textContent).toBe('frus1952-54v01 · d1Not indexed on this server');
    // The save's live region is there, empty, before any save, so that its line is said when it comes.
    expect(document.querySelector('.manage + p[role="status"]')?.textContent).toBe('');
    expect(screen.getByText('Showing the first 500 of 1,100 documents, in volume order.').getAttribute('role')).toBe('status');
  });

  it('shows 500 more at each Show more, the volume a page boundary split given whole, and the keyboard kept until the last', async () => {
    const fetch = server();
    renderAt(`/browse/clusters/115?layout=${encodeURIComponent(layout)}`);
    const more = await screen.findByRole('button', { name: 'Show more' });
    await userEvent.click(more);
    await screen.findByText('Showing the first 1,000 of 1,100 documents, in volume order.');
    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'Volume frus1952-54v01',
      'Kennedy-Khrushchev Exchanges',
      'Volume frus1961-63v10',
    ]);
    const exchanges = screen.getByRole('heading', { level: 2, name: 'Kennedy-Khrushchev Exchanges' }).closest('section')!;
    expect(within(exchanges).getAllByRole('link').map((link) => link.textContent)).toEqual([
      '1. Telegram From the Embassy in the Soviet Union',
      '2. Memorandum of Conversation',
      'd40',
    ]);
    expect(screen.getByRole('button', { name: 'Show more' })).toBe(more);
    expect(more.hasAttribute('disabled')).toBe(false);
    // The last page takes the button away: the keyboard goes to the first section it listed.
    more.focus();
    await userEvent.keyboard('{Enter}');
    const last = await screen.findByRole('heading', { level: 2, name: 'Volume frus1964-68v12' });
    await waitFor(() => expect(document.activeElement).toBe(last));
    expect(screen.queryByRole('button', { name: 'Show more' })).toBeNull();
    const asked = fetch.mock.calls.map(([url]) => new URL(String(url), 'http://localhost')).filter((url) => url.pathname === '/api/v1/clusters/115');
    expect(asked.map((url) => url.search)).toEqual([
      `?shown=500&layout=${encodeURIComponent(layout)}`,
      `?shown=1000&after=500&layout=${encodeURIComponent(layout)}`,
      `?shown=1100&after=1000&layout=${encodeURIComponent(layout)}`,
    ]);
  });

  it('merges the pages’ sections, a later page’s section replacing an earlier one of its volume where it stands', () => {
    expect(clusterSections([page(500, 0), page(1_000, 500), page(1_100, 1_000)]).map((section) => [section.volumeId, section.documents.length])).toEqual([
      ['frus1952-54v01', 2],
      ['frus1961-63v06', 3],
      ['frus1961-63v10', 1],
      ['frus1964-68v12', 2],
    ]);
  });

  it('saves the cluster as a working corpus, as the app’s 7,500 with the whole count said', async () => {
    const corpus: WorkingCorpus = {
      id: 'C0',
      name: 'edc nato nuclear — Oct 24, 2026 at 8:00 PM',
      documentCount: 7_500,
      sourceDescription: 'Semantic cluster, browsed',
      wasTruncatedAtCapture: true,
      totalMatchCountAtCapture: 10_914,
      isMeaningCapture: false,
      truncationWarns: true,
    };
    let body: unknown;
    let token: string | undefined;
    server({
      'POST /api/v1/me/working-corpora/cluster': (_url: URL, init?: RequestInit) => {
        ({ body, token } = sent(init));
        return corpus;
      },
    });
    renderAt(`/browse/clusters/115?layout=${encodeURIComponent(layout)}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Save as Working Corpus' }));
    const line = await screen.findByText('Saved “edc nato nuclear — Oct 24, 2026 at 8:00 PM” with the first 7,500 of 10,914 documents.');
    expect(line.getAttribute('role')).toBe('status');
    expect(line.className).toBe('note warning');
    expect(token).toBe('t');
    expect(body).toEqual({ cluster: 115, layout, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone });
  });

  it('says a whole capture plainly, and offers no save where the server keeps no user data', async () => {
    server({
      'POST /api/v1/me/working-corpora/cluster': {
        id: 'C1',
        name: 'edc nato nuclear — Oct 24, 2026 at 8:00 PM',
        documentCount: 1_100,
        wasTruncatedAtCapture: false,
        totalMatchCountAtCapture: 1_100,
        isMeaningCapture: false,
        truncationWarns: false,
      },
    });
    renderAt(`/browse/clusters/115?layout=${encodeURIComponent(layout)}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Save as Working Corpus' }));
    expect((await screen.findByText('Saved “edc nato nuclear — Oct 24, 2026 at 8:00 PM”.')).className).toBe('note');
    cleanup();
    server({ '/api/v1/me': { ...me, userData: false } });
    renderAt(`/browse/clusters/115?layout=${encodeURIComponent(layout)}`);
    await screen.findByRole('link', { name: 'See on the semantic map' });
    expect(screen.queryByRole('button', { name: 'Save as Working Corpus' })).toBeNull();
  });

  it('refuses a link from another layout, and says when a cluster cannot be loaded', async () => {
    server({ '/api/v1/clusters/115': new ProblemAnswer(409, 'LAYOUT_CHANGED', 'Cluster 115 was named in another layout of the map.') });
    renderAt('/browse/clusters/115?layout=00000000%3A2026-01-01%3A1');
    expect((await screen.findByRole('heading', { level: 1, name: 'Clusters Unavailable' })).textContent).toBe('Clusters Unavailable');
    const alert = screen.getByRole('alert');
    expect(alert.textContent).toBe('This link names a cluster of another release of the semantic map, which this server no longer draws. Clusters');
    expect(within(alert).getByRole('link', { name: 'Clusters' }).getAttribute('href')).toBe('/browse/clusters');
    cleanup();
    server({ '/api/v1/clusters/999': new ProblemAnswer(404, 'CLUSTER_NOT_FOUND', 'The map has no cluster 999.') });
    renderAt('/browse/clusters/999');
    expect((await screen.findByRole('alert')).textContent).toBe('This cluster’s data could not be loaded.');
  });
});
