// The editors' annotations in Browse (FRUS-Explorer#1860 to #1862): a volume page's section, the axis's
// matrix, a layer's page and a list, as the router, the queries and the shell show them over the
// server's answers.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AnnotationDrill, AnnotationLayerPage, AnnotationsAxis, VolumeAnnotationsSection } from '../api/annotations';
import type { Volume } from '../api/types';
import { coverage, ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function volume(volumeId: string, title: string, fields: Partial<Volume> = {}): Volume {
  return {
    volumeId,
    filename: `${volumeId}.xml`,
    subseries: '1961-63',
    title,
    dateRange: {},
    status: 'published',
    editors: [],
    sizeBytes: 1,
    tags: [],
    indexed: false,
    indexedDocuments: 0,
    teiAvailable: false,
    ...fields,
  };
}

const kennedy = volume('frus1961-63v06', 'Kennedy-Khrushchev Exchanges', { indexed: true, teiAvailable: true });
const papers1890 = volume('frus1890', 'Papers Relating to the Foreign Relations of the United States, 1890');
const carter = volume('frus1977-80v27', 'Western Europe');
const catalogue = { total: 3, limit: 1000, offset: 0, items: [kennedy, papers1890, carter], coverage };

const era1955 = { id: '1955-1968', firstYear: 1955, lastYear: 1968 };
const eras = [
  { id: '1861-1898', firstYear: 1861, lastYear: 1898 },
  era1955,
  { id: 'retrospective' },
];

const section1890: VolumeAnnotationsSection = {
  volumeId: 'frus1890',
  groups: [
    { family: 'named', rows: [{ layer: 'correspondents', parts: [{ kind: 'documents', count: 502 }] }] },
    { family: 'provenance', rows: [{ layer: 'despatch', parts: [{ kind: 'documents', count: 347 }] }] },
    {
      family: 'connects',
      rows: [
        {
          layer: 'printedAids',
          parts: [
            { kind: 'aid', aid: 'list-of-papers' },
            { kind: 'aid', aid: 'index' },
          ],
        },
      ],
    },
  ],
  absent: [
    { id: 'people', layer: 'people', onset: era1955 },
    { id: 'referencesToDocuments', layer: 'crossReferences', onset: era1955 },
  ],
};

const axis: AnnotationsAxis = {
  total: 553,
  eras,
  groups: [
    {
      family: 'named',
      layers: [
        {
          layer: 'people',
          carrying: 288,
          total: 553,
          onset: era1955,
          bands: [
            { era: '1861-1898', carrying: 0, total: 62 },
            { era: '1955-1968', carrying: 114, total: 114 },
            { era: 'retrospective', carrying: 9, total: 9 },
          ],
        },
      ],
    },
    {
      family: 'provenance',
      layers: [
        {
          layer: 'despatch',
          carrying: 147,
          total: 553,
          peak: eras[0],
          bands: [
            { era: '1861-1898', carrying: 55, total: 62 },
            { era: '1955-1968', carrying: 0, total: 114 },
            { era: 'retrospective', carrying: 0, total: 9 },
          ],
        },
      ],
    },
  ],
};

const peoplePage: AnnotationLayerPage = {
  reach: axis.groups[0]!.layers[0]!,
  eras,
  drills: [
    { id: 'with', count: 288 },
    { id: 'without', count: 265 },
  ],
};

const without: AnnotationDrill = {
  layer: 'people',
  drill: 'without',
  rule: 'layer',
  count: 265,
  total: 553,
  volumes: [
    { volumeId: 'frus1977-80v27', unlinked: 'persons', from: true },
    { volumeId: 'frus1890' },
    // A volume the catalogue does not list is left out.
    { volumeId: 'frus-not-listed' },
  ],
};

describe('a volume page’s Editors’ Annotations', () => {
  it('lists what the volume carries in its groups, each row opening its layer with this volume marked, and the standard layers it lacks behind a disclosure', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes/frus1890': papers1890,
      '/api/v1/volumes/frus1890/annotations': section1890,
    });
    renderAt('/browse/frus1890');
    const section = await screen.findByRole('region', { name: 'Editors’ Annotations' });
    expect(within(section).getAllByRole('heading', { level: 3 }).map((heading) => heading.textContent)).toEqual([
      'Who is named',
      'Where it came from',
      'How it connects',
    ]);
    const despatch = within(section).getByRole('link', { name: 'Despatch numbers: 347 documents.' });
    expect(despatch.getAttribute('href')).toBe('/browse/annotations/despatch?from=frus1890');
    expect(despatch.getAttribute('title')).toBe('Opens what the editors did, and the volumes that carry it.');
    expect(within(section).getByRole('link', { name: 'Printed aids: List of Papers; Index.' }).textContent).toBe('Printed aidsList of Papers · Index');

    // Collapsed at first, as the app's disclosure is.
    const disclosure = within(section).getByText('Not in this volume (2)').closest('details')!;
    expect(disclosure.open).toBe(false);
    await userEvent.click(within(section).getByText('Not in this volume (2)'));
    expect(disclosure.open).toBe(true);
    const people = within(section).getByRole('link', {
      name: 'Not in this volume: People tagged. Standard in the volumes covering 1955 on. Search the names instead.',
    });
    expect(people.getAttribute('href')).toBe('/browse/annotations/people?from=frus1890');
    // References to documents opens the layer that holds them.
    expect(within(section).getByRole('link', { name: /^Not in this volume: References to documents\./ }).getAttribute('href')).toBe(
      '/browse/annotations/crossReferences?from=frus1890',
    );
  });

  it('shows nothing for a volume the file does not hold', async () => {
    // The answer waits until the test gives it, so the page is looked at once it has been read.
    let answer: (problem: ProblemAnswer) => void = () => {};
    const fetch = stubServer({
      '/readyz': ready,
      '/api/v1/volumes/frus1890': papers1890,
      '/api/v1/volumes/frus1890/annotations': () => new Promise<ProblemAnswer>((resolve) => (answer = resolve)),
    });
    renderAt('/browse/frus1890');
    await screen.findByText('Neither an index nor the TEI on this server gives this volume’s contents.');
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).endsWith('/frus1890/annotations'))).toBe(true));
    answer(new ProblemAnswer(404, 'VOLUME_ANNOTATIONS_NOT_FOUND', 'Nothing.'));
    const response = await fetch.mock.results.find((result, at) => String(fetch.mock.calls[at]?.[0]).endsWith('/annotations'))?.value;
    expect(response.status).toBe(404);
    // A tick for the query to take the answer and the page to draw it.
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(screen.queryByRole('region', { name: 'Editors’ Annotations' })).toBeNull();
    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe(papers1890.title);
  });
});

describe('Browse’s Editors’ Annotations', () => {
  it('draws each group as the app’s matrix: a layer’s row opens its page, a cell its era’s volumes, and an empty cell is read but opens nothing', async () => {
    stubServer({ '/readyz': ready, '/api/v1/annotations': axis });
    renderAt('/browse/annotations');
    expect(await screen.findByText(/^What the editors of 553 volumes annotated, layer by layer\./)).toBeTruthy();
    const named = screen.getByRole('table', { name: 'Who is named' });
    expect(within(named).getAllByRole('columnheader').map((header) => header.textContent)).toEqual(['1861', '1955', 'Retro.']);
    const people = within(named).getByRole('link', { name: 'People tagged: 288 of 553 volumes. Standard in the volumes covering 1955 on.' });
    expect(people.getAttribute('href')).toBe('/browse/annotations/people');
    const cell = within(named).getByRole('link', { name: 'People tagged, 1955–1968: 114 of 114 volumes' });
    expect(cell.getAttribute('href')).toBe('/browse/annotations/people/era/1955-1968');
    expect(cell.getAttribute('style')).toContain('--fill: 100%');
    const empty = within(named).getByRole('link', { name: 'People tagged, 1861–1898: 0 of 62 volumes' });
    expect(empty.getAttribute('aria-disabled')).toBe('true');
    expect(empty.getAttribute('href')).toBeNull();
    expect(within(named).getByRole('link', { name: 'People tagged, Late retrospectives: 9 of 9 volumes' })).toBeTruthy();
    // A practice no era made standard names the era where it is most common.
    const provenance = screen.getByRole('table', { name: 'Where it came from' });
    expect(
      within(provenance).getByRole('link', {
        name: 'Despatch numbers: 147 of 553 volumes. No era made it standard. It is most common in the volumes covering 1861–1898.',
      }),
    ).toBeTruthy();
    const axes = screen.getByRole('navigation', { name: 'Browse by' });
    expect(within(axes).getByRole('link', { name: 'Editors’ Annotations' }).getAttribute('aria-current')).toBe('page');
    // All Volumes' path is a prefix of this one, and it is still not the current page.
    expect(within(axes).getByRole('link', { name: 'All Volumes' }).getAttribute('aria-current')).toBeNull();
  });

  it('opens a layer’s page with what the editors did, when it became standard, its eras and its lists, keeping the volume it came from', async () => {
    stubServer({ '/readyz': ready, '/api/v1/annotations/people': peoplePage });
    renderAt('/browse/annotations/people?from=frus1977-80v27');
    expect((await screen.findByRole('heading', { level: 1 })).textContent).toBe('People tagged');
    await screen.findByText('288 of 553 volumes');
    expect(screen.getByText('A volume counts when at least half its documents link a name to its List of Persons.')).toBeTruthy();
    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'What the editors did',
      'Era by era',
      'In the app',
      'Volumes',
    ]);
    expect(screen.getByText('Standard in the volumes covering 1955 on.')).toBeTruthy();
    expect(screen.getByText('1955–1968: 114 of 114 volumes')).toBeTruthy();
    expect(screen.getByText('The reader opens a linked person’s entry. Where a volume does not link its names, search for them instead.')).toBeTruthy();
    const withIt = screen.getByRole('link', { name: 'Volumes with it: 288 volumes' });
    expect(withIt.getAttribute('href')).toBe('/browse/annotations/people/with?from=frus1977-80v27');
    expect(screen.getByRole('link', { name: 'Volumes without it: 265 volumes' })).toBeTruthy();
    const crumbs = screen.getByRole('navigation', { name: 'Breadcrumb' });
    expect(within(crumbs).getByRole('link', { name: 'Editors’ Annotations' }).getAttribute('href')).toBe('/browse/annotations');
  });

  it('lists a drill’s volumes by the catalogue’s titles, each with its count and its amber line, the one it came from first', async () => {
    stubServer({ '/readyz': ready, '/api/v1/volumes': catalogue, '/api/v1/annotations/people/drills/without': without });
    renderAt('/browse/annotations/people/without?from=frus1977-80v27');
    await waitFor(() => expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Without: People tagged'));
    expect(screen.getByText('265 of 553 volumes. A volume counts when at least half its documents link a name to its List of Persons.')).toBeTruthy();
    const list = screen.getByRole('list', { name: 'Without: People tagged' });
    expect(within(list).getAllByRole('link').map((link) => link.textContent)).toEqual([carter.title, papers1890.title]);
    expect(
      within(list).getByText('Prints a List of Persons, but none of its documents links a name to it. You came here from this volume.'),
    ).toBeTruthy();
    const crumbs = screen.getByRole('navigation', { name: 'Breadcrumb' });
    expect(within(crumbs).getByRole('link', { name: 'People tagged' }).getAttribute('href')).toBe('/browse/annotations/people?from=frus1977-80v27');
    // Only the last crumb is the current page, though the others' paths lead to it.
    expect(within(crumbs).getAllByRole('link').map((link) => link.getAttribute('aria-current'))).toEqual([null, null]);
    expect(within(crumbs).getAllByRole('listitem').at(-1)?.getAttribute('aria-current')).toBe('page');
  });

  it('says so, in the app’s title, when the server cannot read the bundled file', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/annotations': new ProblemAnswer(503, 'ANNOTATIONS_UNAVAILABLE', 'volume-annotations-index.json is missing.'),
    });
    renderAt('/browse/annotations');
    expect(await screen.findByRole('heading', { name: 'Editors’ Annotations Unavailable' })).toBeTruthy();
    expect(screen.getByText('The bundled annotation data could not be loaded.')).toBeTruthy();
    expect(screen.getByText('volume-annotations-index.json is missing.')).toBeTruthy();
  });
});
