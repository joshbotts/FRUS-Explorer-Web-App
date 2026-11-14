// A volume's Sources outline (PLAN's S22d) on Browse's page for its Sources section, over a stubbed server
// answering with the server's own outline for frus1961-63v06 (sourcesFixtures.ts): the app's three groups in its
// order and words, the outline rebuilt from the rows' depths as the app rebuilds it, every branch open at first,
// Expand All and Collapse All, each disclosure by keyboard, the catalogue links and the entry numbers; and the
// empty state, a flat outline and the lines the fixture's rows do not reach.
import { cleanup, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { OutlineRow, VolumeSourcesOutline } from '../api/sources';
import type { VolumeSectionPage } from '../api/types';
import { ready, renderAt, stubServer } from '../test/renderRoute';
import { outline } from './sourcesFixtures';
import { buildTree, expandableIDs } from './VolumeSourcesOutline';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const v06 = 'frus1961-63v06';

const page: VolumeSectionPage = {
  volumeId: v06,
  volumeTitle: 'Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges',
  section: {
    sectionId: 'sources',
    divType: 'sources',
    title: 'List of Sources',
    documentIds: [],
    subsections: [],
    documentCount: 0,
    indexedDocumentCount: 0,
    isFrontMatter: true,
    canReadDirectly: false,
    readable: false,
    hasOwnText: false,
  },
  path: [{ sectionId: 'front-1', title: 'Front Matter' }],
  documents: [],
  structureSource: 'index',
};

/** Opens the Sources section's page, the server answering with `answer` for the volume's outline. */
async function open(answer: VolumeSourcesOutline) {
  stubServer({
    '/readyz': ready,
    [`/api/v1/volumes/${v06}/sections/sources`]: page,
    [`/api/v1/volumes/${v06}/sources`]: answer,
  });
  renderAt(`/browse/${v06}/sources`);
  await screen.findByRole('heading', { level: 1, name: 'List of Sources' });
}

/** Whether a row is on show: no list above it is closed. */
const shown = (element: HTMLElement) => element.closest('[hidden]') === null;

const item = (depth: number, text: string, extra: Partial<OutlineRow> = {}): OutlineRow => ({ kind: 'item', depth, isHeading: false, text, ...extra });

describe('the outline’s rule', () => {
  it('nests the rows by their depths, as the app rebuilds them, and keeps a row deeper than its place', () => {
    const items = outline.rows.filter((row) => row.kind === 'item');
    const tree = buildTree(items);
    expect(tree.map((node) => node.row.text)).toEqual([
      'Department of State',
      'John F. Kennedy Library, Boston, Massachusetts',
      'Lyndon B. Johnson Library, Austin, Texas',
    ]);
    const lots = tree[0]!.children![1]!;
    expect(lots.row.text.startsWith('Lot Files:')).toBe(true);
    expect(lots.children!.map((node) => node.row.text)).toEqual(['Presidential Correspondence: Lot 66 D 204', 'Presidential Correspondence: Lot 77 D 163']);
    // Every row with rows beneath it, at any depth: the three headings, Lot Files, the two lots, and the two files.
    expect(expandableIDs(tree).size).toBe(8);
    // An orphan two levels below its parent is kept beneath it, not dropped.
    const orphan = buildTree([item(0, 'Repository'), item(2, 'Orphan'), item(1, 'Series')]);
    expect(orphan[0]!.children!.map((node) => node.row.text)).toEqual(['Orphan', 'Series']);
    expect(expandableIDs(buildTree([item(0, 'One'), item(0, 'Two')])).size).toBe(0);
  });
});

describe('a volume’s Sources outline', () => {
  it('shows the app’s three groups in its order, each row’s catalogue link and entry numbers, every branch open', async () => {
    await open(outline);
    const headings = (await screen.findAllByRole('heading', { level: 2 })).map((heading) => heading.textContent);
    expect(headings).toEqual(['About These Sources', 'Archival Collections', 'Published Sources']);
    const about = screen.getByRole('region', { name: 'About These Sources' });
    expect(within(about).getByText('Unpublished Sources')).toBeTruthy();
    const published = screen.getByRole('region', { name: 'Published Sources' });
    expect(within(published).getAllByRole('listitem')).toHaveLength(10);
    // Published works are plain rows: no link, no disclosure.
    expect(within(published).queryByRole('link')).toBeNull();

    const collections = screen.getByRole('region', { name: 'Archival Collections' });
    const links = within(collections).getAllByRole('link', { name: 'View in National Archives Catalog' });
    expect(links.map((link) => link.getAttribute('href'))).toEqual(
      ['2538452', '622626', '1164', '1154', '567979'].map((naId) => `https://catalog.archives.gov/id/${naId}`),
    );
    expect(links[0]!.getAttribute('title')).toBe('View this collection in the National Archives Catalog');
    expect(links[0]!.getAttribute('target')).toBe('_blank');
    expect(within(collections).getByText('HMS/MLR Entry: A1 1590')).toBeTruthy();
    expect(within(collections).getByText('HMS/MLR Entry: A1 5196')).toBeTruthy();
    // A major named collection in bold.
    expect(within(collections).getByText('Department of State').className).toContain('vs-heading');
    // Every branch open at first, so the lots' descriptions show.
    expect(shown(within(collections).getByText(/^Correspondence of Presidents Kennedy and Johnson/))).toBe(true);
    for (const disclosure of within(collections).getAllByRole('button', { expanded: true })) {
      expect(disclosure.getAttribute('aria-controls')).toBeTruthy();
    }
    expect(within(collections).getAllByRole('button', { expanded: true })).toHaveLength(8);
  });

  it('collapses and expands every branch, and each by keyboard, named by its row', async () => {
    const user = userEvent.setup();
    await open(outline);
    const collections = await screen.findByRole('region', { name: 'Archival Collections' });
    await user.click(within(collections).getByRole('button', { name: 'Collapse All' }));
    expect(within(collections).queryByRole('button', { expanded: true })).toBeNull();
    // The top-level rows stay; what is beneath them is hidden.
    expect(shown(within(collections).getByText('John F. Kennedy Library, Boston, Massachusetts'))).toBe(true);
    expect(shown(within(collections).getByText('National Security Files'))).toBe(false);
    expect(within(collections).queryByRole('link', { name: 'View in National Archives Catalog' })).toBeNull();

    // One branch by keyboard: its disclosure is named by its row.
    const kennedy = within(collections).getByRole('button', { name: 'John F. Kennedy Library, Boston, Massachusetts', expanded: false });
    kennedy.focus();
    await user.keyboard('{Enter}');
    expect(kennedy.getAttribute('aria-expanded')).toBe('true');
    expect(shown(within(collections).getByText('National Security Files'))).toBe(true);
    // Its own branches keep the state they had: closed.
    expect(shown(within(collections).getByText(/^Countries Series, USSR/))).toBe(false);
    await user.keyboard(' ');
    expect(kennedy.getAttribute('aria-expanded')).toBe('false');

    await user.click(within(collections).getByRole('button', { name: 'Expand All' }));
    expect(within(collections).queryByRole('button', { expanded: false })).toBeNull();
    expect(shown(within(collections).getByText(/^Countries Series, USSR/))).toBe(true);
    expect(within(collections).getByRole('button', { name: 'Collapse All' })).toBeTruthy();
  });

  it('offers no Expand All for a flat outline, and shows the lines the fixture’s rows do not reach', async () => {
    await open({
      volumeId: v06,
      rows: [
        item(0, 'Defense Department, Washington National Records Center', {
          note: 'Records of the Office of the Secretary of Defense.',
          catalogURL: 'https://catalog.archives.gov/id/1',
          seriesTitle: 'Subject Files',
          seriesEntryNumbers: ['UD 1', 'UD 2'],
        }),
        item(0, 'Lot 62 D 430'),
      ],
    });
    const collections = await screen.findByRole('region', { name: 'Archival Collections' });
    expect(within(collections).queryByRole('button')).toBeNull();
    expect(within(collections).getByText('Records of the Office of the Secretary of Defense.')).toBeTruthy();
    expect(within(collections).getByText('File Series: Subject Files')).toBeTruthy();
    expect(within(collections).getByText('HMS/MLR Entry (series): UD 1, UD 2')).toBeTruthy();
    expect(screen.queryByRole('region', { name: 'About These Sources' })).toBeNull();
    expect(screen.queryByRole('region', { name: 'Published Sources' })).toBeNull();
  });

  it('says so when the index lists no sources for the volume', async () => {
    await open({ volumeId: v06, rows: [] });
    expect(await screen.findByRole('heading', { level: 2, name: 'No Sources Listed' })).toBeTruthy();
    expect(screen.getByText('Index this volume to load its archival sources list.')).toBeTruthy();
  });
});
