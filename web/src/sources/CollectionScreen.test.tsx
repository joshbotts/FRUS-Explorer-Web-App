// A collection's record (PLAN's S22d's follow-up) over a stubbed server answering with the server's own records,
// lot 66 D 204's and lot 64 D 563's (sourcesFixtures.ts): the app's sections in its order, the NARA Catalog link,
// Related Collections with each row's record, shared volumes and overlap, Cited Over Time's chart, caption and
// table, Divided at NARA's series, and Pointed At, Not Printed's volumes, each capped list at the kit's cap the
// server sends until Show all; and the rules the rows are written by, as the app's view writes them.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ArchivalCollection } from '../api/sources';
import { ready, renderAt, stubServer } from '../test/renderRoute';
import { collection, dividedCollection } from './sourcesFixtures';
import { claimantCaption, neighboursLabel, overlapMeterWidth, overlapPercent, relatedCaption } from './sourcesRules';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

const path = '/api/v1/archival-collection';

/** Opens the record `id` names, the server answering each record by its id. */
async function open(id: string, records: ArchivalCollection[] = [collection, dividedCollection], query = '') {
  stubServer({
    '/readyz': ready,
    [path]: (url: URL) => records.find((record) => record.id === url.searchParams.get('id')) ?? records[0],
  });
  const rendered = renderAt(`/archival-collection?id=${encodeURIComponent(id)}${query}`);
  await screen.findByRole('region', { name: 'Archival Collection' });
  return rendered;
}

const section = (name: string | RegExp) => screen.getByRole('region', { name });

describe('a collection’s record, every section', () => {
  it('draws the app’s sections in its order, with the NARA Catalog link and its NAID', async () => {
    await open(collection.id);
    const headings = screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent);
    expect(headings).toEqual([
      'Archival Collection',
      'NARA Catalog',
      'In Your Library',
      'Related Collections',
      'Cited Over Time',
      ...(collection.divided ? ['Divided at NARA'] : []),
      ...(collection.pointers ? ['Pointed At, Not Printed'] : []),
      `Cited Across the Series (${collection.volumes.length} volumes)`,
      'Sub-Series',
    ]);
    const catalog = section('NARA Catalog');
    const link = within(catalog).getByRole('link', { name: 'View in National Archives Catalog' });
    expect(link.getAttribute('href')).toBe(collection.catalog!.url);
    expect(link.getAttribute('title')).toBe('View this collection in the National Archives Catalog');
    expect(link.getAttribute('target')).toBe('_blank');
    expect(within(catalog).getByText(`NAID ${collection.catalog!.naId} — resolved offline from the bundled index; no API key required.`)).toBeTruthy();
    expect(within(catalog).getByRole('img', { name: 'Source: FRUS joined to the National Archives catalog.' })).toBeTruthy();
  });

  it('lists the related collections at the cap, each opening its own record, and all of them on Show all', async () => {
    const user = userEvent.setup();
    const { router } = await open(dividedCollection.id);
    const related = section('Related Collections');
    const all = dividedCollection.related!;
    const cap = dividedCollection.previewRowCap;
    expect(all.length).toBeGreaterThan(cap);
    const links = within(related).getAllByRole('link');
    expect(links).toHaveLength(cap);
    // A row says its name, its record's repository and group, its shared volumes and, to a screen reader, its
    // overlap, which its meter shows.
    const first = all[0]!;
    const target = new URL(links[0]!.getAttribute('href')!, 'http://localhost');
    expect(target.pathname).toBe('/archival-collection');
    expect(target.searchParams.get('id')).toBe(first.id);
    expect(links[0]!.textContent).toContain(first.name);
    expect(links[0]!.textContent).toContain(`${first.sharedVolumeCount} shared vols`);
    expect(links[0]!.textContent).toContain(`Overlap ${overlapPercent(first.overlap)}`);
    const meter = links[0]!.querySelector('.se-meter');
    expect(meter?.getAttribute('aria-hidden')).toBe('true');
    expect((meter?.firstElementChild as HTMLElement).style.width).toBe(`${overlapMeterWidth(first.overlap)}px`);
    expect(within(related).getByText(/^These collections appear alongside this one/)).toBeTruthy();
    await user.click(within(related).getByRole('button', { name: `Show all ${all.length} related collections` }));
    expect(within(related).getAllByRole('link')).toHaveLength(all.length);
    expect(within(related).getByRole('button', { name: 'Show fewer', expanded: true })).toBeTruthy();
    // The list shown whole is in the address, so Back to the record returns it so.
    expect(router.state.location.search).toEqual({ id: dividedCollection.id, all: 'related' });
    // Another record opens with its lists at the cap, and its heading takes the focus, though the path is the same.
    await user.click(within(section('Related Collections')).getAllByRole('link')[0]!);
    expect(router.state.location.search).toEqual({ id: first.id });
    await screen.findByText(collection.name, { selector: '.se-record-title' });
    expect(within(section('Related Collections')).getAllByRole('link')).toHaveLength(collection.previewRowCap);
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('heading', { level: 1, name: 'Collection' })));
    // The way back returns to the first record, its list still shown whole, and the heading takes the focus again.
    await user.click(screen.getByRole('button', { name: /Back$/ }));
    await screen.findByText(dividedCollection.name, { selector: '.se-record-title' });
    expect(within(section('Related Collections')).getAllByRole('link')).toHaveLength(all.length);
    await waitFor(() => expect(document.activeElement).toBe(screen.getByRole('heading', { level: 1, name: 'Collection' })));
  });

  it('shows whole the lists the address names, as Back from a citing volume finds them', async () => {
    await open(dividedCollection.id, undefined, '&all=volumes&all=pointers');
    const cited = section(/^Cited Across the Series/);
    expect(within(cited).getAllByRole('link')).toHaveLength(dividedCollection.volumes.length);
    expect(within(cited).getByRole('button', { name: 'Show fewer', expanded: true })).toBeTruthy();
    expect(within(section('Pointed At, Not Printed')).getAllByRole('listitem')).toHaveLength(dividedCollection.pointers!.volumes.length);
    expect(within(section('Related Collections')).getAllByRole('link')).toHaveLength(dividedCollection.previewRowCap);
  });

  it('says so where no collection is cited alongside in two or more volumes, and shows no section for one volume', async () => {
    await open('one', [{ ...collection, id: 'one', related: [] }]);
    expect(within(section('Related Collections')).getByText('No other collection is cited alongside this one in two or more volumes.')).toBeTruthy();
    cleanup();
    vi.unstubAllGlobals();
    const single: ArchivalCollection = { ...collection, id: 'single' };
    delete single.related;
    delete single.timeline;
    await open('single', [single]);
    expect(screen.queryByRole('region', { name: 'Related Collections' })).toBeNull();
    expect(screen.queryByRole('region', { name: 'Cited Over Time' })).toBeNull();
  });

  it('draws Cited Over Time as a chart named and described, a column for each era with volumes, and its table', async () => {
    const user = userEvent.setup();
    await open(collection.id);
    const timeline = section('Cited Over Time');
    const eras = collection.timeline!.eras;
    const chart = within(timeline).getByRole('img', { name: `${collection.name} — cited over time` });
    // The kit's reading, in the app's caption, the last of the figure the chart is drawn in, which it names.
    const figure = chart.closest('figure')!;
    expect(figure.lastElementChild?.tagName).toBe('FIGCAPTION');
    expect(figure.lastElementChild?.textContent).toBe(
      `Citing volumes by coverage era (the citing-volume list × the manifest’s date ranges). ${collection.timeline!.narrative}`,
    );
    expect(chart.querySelectorAll('path.chart-column')).toHaveLength(eras.filter((era) => era.volumeCount > 0).length);
    expect(within(timeline).getByText(eras[0]!.shortLabel)).toBeTruthy();
    await user.click(within(timeline).getByText('View as table'));
    const table = within(timeline).getByRole('table', { name: `${collection.name} — cited over time` });
    expect(within(table).getAllByRole('columnheader').map((cell) => cell.textContent)).toEqual(['Coverage era', 'Citing volumes']);
    expect(within(table).getAllByRole('rowheader').map((cell) => cell.textContent)).toEqual(eras.map((era) => era.fullLabel));
    expect(within(table).getAllByRole('cell').map((cell) => cell.textContent)).toEqual(eras.map((era) => String(era.volumeCount)));
  });

  it('keeps an era with no citing volume in the middle: its label and its row, and no column', async () => {
    const eras = [
      { shortLabel: '’51–54', fullLabel: '1951–1954', volumeCount: 1 },
      { shortLabel: '’55–57', fullLabel: '1955–1957', volumeCount: 0 },
      { shortLabel: '’58–60', fullLabel: '1958–1960', volumeCount: 2 },
    ];
    await open('gapped', [{ ...collection, id: 'gapped', timeline: { eras, narrative: 'A narrative.' } }]);
    const timeline = section('Cited Over Time');
    expect(timeline.querySelectorAll('path.chart-column')).toHaveLength(2);
    for (const era of eras) expect(within(timeline).getByText(era.shortLabel)).toBeTruthy();
    const table = within(timeline).getByRole('table');
    expect(within(table).getAllByRole('cell').map((cell) => cell.textContent)).toEqual(['1', '0', '2']);
  });

  it('lists the series NARA divided the lot across, each with NARA’s caption, entries and its View, and the footer', async () => {
    await open(dividedCollection.id);
    const divided = section('Divided at NARA');
    const answer = dividedCollection.divided!;
    expect(within(divided).getByText(`NARA later distributed material cited as this lot across ${answer.claimants.length} catalog series.`)).toBeTruthy();
    expect(!!within(divided).queryByText(/^The NARA Catalog link above points to one of them/)).toBe(answer.includesRecordsNAID);
    const rows = within(divided).getAllByRole('listitem');
    expect(rows).toHaveLength(answer.claimants.length);
    const first = answer.claimants[0]!;
    expect(within(rows[0]!).getByText(first.title)).toBeTruthy();
    expect(within(rows[0]!).getByText(claimantCaption(first))).toBeTruthy();
    if (first.entryNumbers?.length) expect(within(rows[0]!).getByText(`Entry ${first.entryNumbers.join(', ')}`)).toBeTruthy();
    // The app's View, told which series it opens.
    const view = within(rows[0]!).getByRole('link', { name: 'View' });
    expect(view.getAttribute('href')).toBe(first.catalogURL);
    expect(document.getElementById(view.getAttribute('aria-describedby')!)?.textContent).toBe(first.title);
    expect(
      within(divided).getByText(
        `From the bundled lot-claimants index — ${answer.dividedLots} lots series-wide are claimed by more than one NARA series. Offline; no API key required.`,
      ),
    ).toBeTruthy();
    expect(within(divided).getByRole('img', { name: 'Source: FRUS joined to the National Archives catalog.' })).toBeTruthy();
  });

  it('counts the footnotes that point at the record, five volumes with their counts, then all of them', async () => {
    const user = userEvent.setup();
    await open(dividedCollection.id);
    const pointers = section('Pointed At, Not Printed');
    const answer = dividedCollection.pointers!;
    expect(
      within(pointers).getByText(`FRUS editors point at unprinted material here ${answer.total} times, across ${answer.volumes.length} volumes.`),
    ).toBeTruthy();
    const cap = dividedCollection.previewRowCap;
    const rows = within(pointers).getAllByRole('listitem');
    expect(rows).toHaveLength(Math.min(cap, answer.volumes.length));
    const first = answer.volumes[0]!;
    const link = within(rows[0]!).getByRole('link', { name: first.title ?? first.volumeId });
    expect(link.getAttribute('href')).toBe(`/browse/${first.volumeId}`);
    expect(link.getAttribute('title')).toBe('Opens this volume in the browser');
    expect(within(rows[0]!).getByText(first.count.toLocaleString('en-US'))).toBeTruthy();
    expect(within(pointers).getByText(/^Counted from editors’ footnotes naming material FRUS did not print\./)).toBeTruthy();
    await user.click(within(pointers).getByRole('button', { name: `Show all ${answer.volumes.length} volumes` }));
    expect(within(pointers).getAllByRole('listitem')).toHaveLength(answer.volumes.length);
  });

  it('shows no catalogue link, division or pointers where the server gives none', async () => {
    const bare: ArchivalCollection = { ...dividedCollection };
    delete bare.catalog;
    delete bare.divided;
    delete bare.pointers;
    await open(bare.id, [bare]);
    expect(screen.queryByRole('region', { name: 'NARA Catalog' })).toBeNull();
    expect(screen.queryByRole('region', { name: 'Divided at NARA' })).toBeNull();
    expect(screen.queryByRole('region', { name: 'Pointed At, Not Printed' })).toBeNull();
  });
});

describe('the record’s and the outline’s rules', () => {
  it('writes a related row, a claiming series and the neighbours’ name as the app does', () => {
    expect(relatedCaption({ repository: 'Department of State', recordGroup: '59' })).toBe('Department of State · RG 59');
    expect(relatedCaption({ recordGroup: '59' })).toBe('RG 59');
    expect(relatedCaption({})).toBeUndefined();
    // Foundation's percent rounds a half to the even, from the shortest decimal that is the double: measured in
    // swift:6.4-noble's Foundation, `formatted(.percent.precision(.fractionLength(0)))` gives each of these.
    expect([1, 0.625, 0.375, 0.125, 2 / 3, 0.835, 0.845, 0.005, 0.015].map(overlapPercent)).toEqual([
      '100%', '62%', '38%', '12%', '67%', '84%', '84%', '0%', '2%',
    ]);
    expect(overlapMeterWidth(0.5)).toBe(28);
    expect(overlapMeterWidth(0)).toBe(2);
    expect(overlapMeterWidth(1.5)).toBe(56);
    expect(claimantCaption({ naId: '4682721', recordGroup: '59', dateRange: '1948–1961' })).toBe('NAID 4682721 · RG 59 · 1948–1961');
    expect(claimantCaption({ naId: '4682721' })).toBe('NAID 4682721');
    expect(neighboursLabel(undefined)).toBe('Archival Neighbors');
    expect(neighboursLabel(0)).toBe(
      'Archival Neighbors — no documents in your indexed volumes cite this collection; indexing more volumes may surface some',
    );
    expect(neighboursLabel(1234)).toBe('Archival Neighbors — 1234 indexed documents');
  });
});
