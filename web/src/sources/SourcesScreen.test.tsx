// Source Explorer's pages (PLAN's S22d) over a stubbed server answering with the server's own answers for
// fixture documents (sourcesFixtures.ts): a document's sections in the app's order and words, each panel kind
// the fixtures reach, the chips and what a screen reader hears of them, the neighbours' picker and states, and
// a collection's record.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ArchivalNeighbours, SourceExplorer } from '../api/sources';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { collection, neighbours, sources } from './sourcesFixtures';
import { confirmedDay, curatedSubtitle, publishedLinkStale, statusValue } from './sourcesRules';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

function document(volumeId: string, documentId: string, displayTitle: string) {
  return {
    document: { volumeId, documentId, displayTitle, inIndex: true },
    canonicalURL: `https://history.state.gov/historicaldocuments/${volumeId}/${documentId}`,
    teiAvailable: true,
  };
}

/** Opens a fixture document's Source Explorer, the server answering with `answer`. */
async function open(answer: SourceExplorer) {
  const { volumeId, documentId } = answer;
  stubServer({
    '/readyz': ready,
    [`/api/v1/volumes/${volumeId}/documents/${documentId}`]: document(volumeId, documentId, answer.documentTitle),
    [`/api/v1/volumes/${volumeId}/documents/${documentId}/sources`]: answer,
  });
  const rendered = renderAt(`/sources/${volumeId}/${documentId}`);
  await screen.findByRole('heading', { level: 1, name: 'Source Explorer' });
  await screen.findByRole('heading', { level: 2, name: 'Archival Neighbors' });
  return rendered;
}

/** A section by its heading's name. */
function section(name: string): HTMLElement {
  return screen.getByRole('region', { name });
}

/** The value of a section's row, by its label. */
function row(within: HTMLElement, label: string): string | undefined {
  const term = Array.from(within.querySelectorAll('dt')).find((dt) => dt.textContent === label);
  return term?.nextElementSibling?.textContent ?? undefined;
}

describe('Source Explorer', () => {
  it('shows a lot file’s sections in the app’s order: the note, Provenance, the bundled series, NARA Catalog, the neighbours and the collection', async () => {
    await open(sources.lot!);
    const headings = screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent);
    expect(headings).toEqual(['Source Note', 'Provenance', 'NARA Catalog Record', 'NARA Catalog', 'Archival Neighbors', 'Archival Collection']);
    expect(screen.getByRole('link', { name: /^Back to / })).toBeTruthy();
    const provenance = section('Provenance');
    expect(row(provenance, 'Type')).toBe('State Dept. Lot File');
    expect(row(provenance, 'Lot Number')).toBe(sources.lot!.provenance[0]!.lotNumber);
    // The record group's provenance chip, the parser's when nothing curated answers: FRUS's own words.
    expect(within(provenance).getByRole('img', { name: 'Source: the FRUS volumes only.' })).toBeTruthy();
    const bundled = section('NARA Catalog Record');
    expect(within(bundled).getByRole('link', { name: 'Open Series in NARA Catalog' }).getAttribute('target')).toBe('_blank');
    expect(within(bundled).getByText(/^Resolved from the bundled index/)).toBeTruthy();
    // No NARA Catalog search runs here yet; the app's manual search does.
    const catalog = section('NARA Catalog');
    expect(within(catalog).getByText('This server does not search the NARA Catalog yet.')).toBeTruthy();
    expect(within(catalog).getByRole('link', { name: 'Search NARA Catalog Manually' })).toBeTruthy();
    // The neighbours: the kit's line, the rows, the count, the match and the way to their three scopes.
    const neighbours = section('Archival Neighbors');
    expect(within(neighbours).getByText(sources.lot!.neighbours.basis!)).toBeTruthy();
    expect(within(neighbours).getByText(String(sources.lot!.neighbours.totalCount))).toBeTruthy();
    expect(within(neighbours).getByText(`Matching archival source: ${sources.lot!.neighbours.matchKey}`)).toBeTruthy();
    const first = sources.lot!.neighbours.documents[0]!;
    expect(within(neighbours).getByRole('link', { name: new RegExp(first.title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')) }).getAttribute('href')).toBe(
      `/doc/${first.volumeId}/${first.documentId}`,
    );
    const all = within(neighbours).getByRole('link', { name: 'Archival Neighbors…' });
    expect(all.getAttribute('href')).toContain('/archival-neighbors?');
    expect(all.getAttribute('href')).toContain('documentId=d3');
    const collection = section('Archival Collection');
    expect(within(collection).getByRole('link', { name: sources.lot!.collection!.name }).getAttribute('href')).toContain('/archival-collection?id=');
    expect(within(collection).getByText(`Cited in ${sources.lot!.collection!.volumeCount} volumes across the series`)).toBeTruthy();
    expect(within(collection).getByText('Matched against the bundled cross-volume collection authority.')).toBeTruthy();
  });

  it('gives the classification chip its words for a screen reader', async () => {
    await open(sources.lot!);
    const marking = sources.lot!.classificationMarking!;
    expect(within(section('Source Note')).getByRole('img', { name: `Classification markings: ${marking}` }).textContent).toBe(marking);
  });

  it('shows a Subject-Numeric citation its own panel, the era’s page and its one handbook', async () => {
    await open(sources.subjectNumeric!);
    const provenance = section('Provenance');
    expect(row(provenance, 'Type')).toBe('State Dept. Subject-Numeric File (February 1963–1973)');
    expect(row(provenance, 'File Designation')).toBe('POL Libya-U.S');
    expect(row(provenance, 'File Years')).toBe('1970–73');
    const period = section('NARA Finding Aids by Period');
    expect(row(period, 'Filing Period')).toBe('February 1963–1973 (Subject-Numeric File)');
    expect(within(period).getByRole('link', { name: 'Open NARA Finding Aids for This Period' })).toBeTruthy();
    expect(within(period).getByRole('link', { name: 'Filing Manual for This Period (PDF)' })).toBeTruthy();
  });

  it('shows a central-files citation its filing period, its finding aids and its manual', async () => {
    await open(sources.centralFiles!);
    expect(row(section('Provenance'), 'Type')).toBe('State Dept. Central Files (RG 59)');
    const period = section('NARA Finding Aids by Period');
    expect(row(period, 'Filing Period')).toBe('1960–January 1963');
    expect(within(period).getByRole('link', { name: 'Filing Manual for This Period (PDF)' })).toBeTruthy();
  });

  it('shows a pre-1906 document the series it was likely filed in, with its confidence and its rolls', async () => {
    await open(sources.pre1906!);
    expect(screen.queryByRole('region', { name: 'Source Note' })).toBeNull();
    const series = section('Digitized Department of State Records (pre-1906)');
    expect(within(series).getByText(/^This document predates the 1906 Numerical File/)).toBeTruthy();
    expect(within(series).getByRole('img', { name: 'Confidence: Likely' })).toBeTruthy();
    expect(within(series).getByRole('img', { name: 'Source: FRUS joined to the National Archives catalog.' })).toBeTruthy();
    const roll = sources.pre1906!.countrySeries!.homes[0]!.rolls[0]!;
    expect(within(series).getByRole('link', { name: roll.title }).getAttribute('href')).toBe(roll.catalogURL);
  });

  it('says why no roll was found for a document with no note, and the era’s likely series', async () => {
    await open(sources.noNote!);
    const source = section('Archival Source');
    expect(within(source).getByText(/couldn’t be predicted from its dateline and FRUS chapter\.$/)).toBeTruthy();
    expect(within(source).getByText(/country-arranged diplomatic series/)).toBeTruthy();
  });

  it('says of a repository outside NARA’s custody that the catalogue has no record, and where the papers are', async () => {
    await open(sources.outside!);
    const finding = section('Finding Aid');
    expect(within(finding).getByRole('link', { name: 'Henry A. Kissinger Papers, Part I' })).toBeTruthy();
    const catalog = section('NARA Catalog');
    expect(within(catalog).getByText(/^Library of Congress is not a National Archives repository/)).toBeTruthy();
    expect(within(catalog).getByRole('link', { name: 'Open Library of Congress, Manuscript Division' })).toBeTruthy();
  });

  it('shows the bundled library catalogue’s answer, and each unprinted pointer as the volume prints it and as it is said', async () => {
    await open(sources.library!);
    const offline = sources.library!.provenance.find((panel) => panel.kind === 'offlineLibrary')!.libraryOutcome!;
    expect(screen.getByText(offline.caveat!)).toBeTruthy();
    const unprinted = section('Unprinted Material');
    const rows = within(unprinted).getAllByRole('listitem');
    expect(rows).toHaveLength(sources.library!.unprinted!.rows.length);
    expect(within(rows[0]!).getByText('Footnote 3, 711.11-KE')).toBeTruthy();
    expect(within(rows[1]!).getByText('Carried from the previous note')).toBeTruthy();
    expect(within(unprinted).getAllByRole('img', { name: "Source: FRUS joined to the State Department's decimal classification schedule." })).toHaveLength(2);
    expect(within(unprinted).getByText(sources.library!.unprinted!.footer)).toBeTruthy();
  });

  it('shows a CFPF citation its research resources, a CIA citation CREST, and a named series its explainer', async () => {
    await open(sources.cfpf!);
    expect(row(section('Provenance'), 'Type')).toBe('State Dept. Central Foreign Policy File (1973–1979)');
    expect(within(section('Research Resources')).getByRole('link', { name: 'Search AAD Electronic Telegrams Database' })).toBeTruthy();
    cleanup();
    vi.unstubAllGlobals();
    await open(sources.cia!);
    expect(row(section('Provenance'), 'Repository')).toBe('Central Intelligence Agency');
    expect(within(section('CIA Research')).getByRole('link', { name: /CREST/ })).toBeTruthy();
    cleanup();
    vi.unstubAllGlobals();
    await open(sources.named!);
    const named = sources.named!.provenance[0]!;
    expect(row(section('Provenance'), 'File Series')).toBe(named.seriesName);
    if (named.explainer) expect(screen.getByText(named.explainer)).toBeTruthy();
  });

  it('says the index is starting, or the server’s refusal', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes/frus1961-63v06/documents/d3': document('frus1961-63v06', 'd3', 'Memorandum'),
      '/api/v1/volumes/frus1961-63v06/documents/d3/sources': new ProblemAnswer(503, 'INDEX_NOT_READY', 'The index is starting.'),
    });
    renderAt('/sources/frus1961-63v06/d3');
    expect(await screen.findByText('Preparing your index…')).toBeTruthy();
    cleanup();
    vi.unstubAllGlobals();
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes/frus1961-63v06/documents/front': document('frus1961-63v06', 'front', 'Preface'),
      '/api/v1/volumes/frus1961-63v06/documents/front/sources': new ProblemAnswer(404, 'DOCUMENT_NOT_FOUND', 'The index holds no document front in frus1961-63v06.'),
    });
    renderAt('/sources/frus1961-63v06/front');
    expect((await screen.findByRole('alert')).textContent).toContain('The index holds no document front');
  });
});

describe('Archival Neighbors', () => {
  const path = '/api/v1/archival-neighbors';

  it('lists a document’s neighbours under the kit’s line, with the picker on All volumes', async () => {
    stubServer({ '/readyz': ready, [path]: neighbours });
    renderAt('/archival-neighbors?volumeId=frus1961-63v06&documentId=d3');
    expect(await screen.findByRole('heading', { level: 1, name: 'Archival Neighbors' })).toBeTruthy();
    expect(await screen.findByText(neighbours.basis!)).toBeTruthy();
    expect((screen.getByRole('radio', { name: 'All volumes' }) as HTMLInputElement).checked).toBe(true);
    expect(screen.getByRole('radio', { name: 'This volume' })).toBeTruthy();
    expect(screen.getByRole('radio', { name: 'This subseries' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Back to Source Explorer' }).getAttribute('href')).toBe('/sources/frus1961-63v06/d3');
    const more = neighbours.totalCount - neighbours.documents.length;
    expect(screen.getByText(`${more} more share this source — open Source Explorer to see them all.`)).toBeTruthy();
  });

  it('lists the scope chosen, and says a scope with none should be widened', async () => {
    const fetch = stubServer({
      '/readyz': ready,
      [path]: (url: URL) => {
        const scope = (url.searchParams.get('scope') ?? 'all') as ArchivalNeighbours['scope'];
        return scope === 'volume' ? { ...neighbours, scope, documents: [], totalCount: 0 } : { ...neighbours, scope };
      },
    });
    const user = userEvent.setup();
    const { router } = renderAt('/archival-neighbors?volumeId=frus1961-63v06&documentId=d3');
    await screen.findByText(neighbours.basis!);
    await user.click(screen.getByRole('radio', { name: 'This volume' }));
    await waitFor(() => expect(router.state.location.search).toMatchObject({ scope: 'volume' }));
    await waitFor(() => expect(fetch.mock.calls.some(([url]) => String(url).includes('scope=volume'))).toBe(true));
    expect(await screen.findByRole('heading', { level: 2, name: 'No Archival Neighbors' })).toBeTruthy();
    expect(screen.getByText(/^No documents in this scope cite this archival source/)).toBeTruthy();
  });

  it('opens the default scope for a scope these neighbours are not offered, so the picker comes back', async () => {
    stubServer({
      '/readyz': ready,
      [path]: (url: URL) =>
        url.searchParams.get('scope') === 'subseries'
          ? new ProblemAnswer(400, 'SCOPE_NOT_OFFERED', 'These neighbours have no subseries scope.')
          : { ...neighbours, scopes: ['volume', 'all'] },
    });
    const { router } = renderAt('/archival-neighbors?volumeId=frus1961-63v06&documentId=d3&scope=subseries');
    await waitFor(() => expect(router.state.location.search).not.toHaveProperty('scope'));
    expect(((await screen.findByRole('radio', { name: 'All volumes' })) as HTMLInputElement).checked).toBe(true);
  });

  it('shows no picker for a collection’s neighbours, which are all volumes’', async () => {
    stubServer({ '/readyz': ready, [path]: { ...neighbours, scopes: [], scope: 'all', anchorVolumeId: undefined } });
    renderAt('/archival-neighbors?collection=lot%3A66D204');
    await screen.findByText(neighbours.basis!);
    expect(screen.queryByRole('radio')).toBeNull();
    expect(screen.getByRole('link', { name: 'Back to the collection' }).getAttribute('href')).toContain('/archival-collection?id=');
  });
});

describe('An archival collection’s record', () => {
  const path = '/api/v1/archival-collection';

  it('shows the record’s names, its local counts and neighbours, five citing volumes and then all of them', async () => {
    stubServer({ '/readyz': ready, [path]: collection });
    const user = userEvent.setup();
    renderAt('/archival-collection?id=lot%3A66D204');
    expect(await screen.findByRole('heading', { level: 1, name: 'Collection' })).toBeTruthy();
    const overview = await screen.findByRole('region', { name: 'Archival Collection' });
    expect(within(overview).getByText(collection.name)).toBeTruthy();
    expect(row(overview, 'Lot File')).toBe('66D204');
    // Six aliases, then how many more.
    expect(within(overview).getAllByRole('listitem')).toHaveLength(6);
    expect(within(overview).getByText(`${collection.aliases.length - 6} more variant forms`)).toBeTruthy();
    const local = section('In Your Library');
    expect(within(local).getByText(`${collection.documentCount} documents in ${collection.volumeCount} of your indexed volumes cite this collection.`)).toBeTruthy();
    expect(within(local).getByRole('link', { name: 'Show Archival Neighbors' }).getAttribute('href')).toContain('collection=lot%3A66D204');
    const cited = screen.getByRole('region', { name: /^Cited Across the Series/ });
    expect(within(cited).getAllByRole('link')).toHaveLength(5);
    await user.click(within(cited).getByRole('button', { name: `Show all ${collection.volumes.length} volumes` }));
    expect(within(cited).getAllByRole('link')).toHaveLength(collection.volumes.length);
    expect(within(cited).getByRole('button', { name: 'Show fewer' })).toBeTruthy();
  });

  it('says a record is unavailable for an address that names none, asking the server nothing, and that the index is starting', async () => {
    const fetch = stubServer({ '/readyz': ready, [path]: collection });
    renderAt('/archival-collection');
    expect(await screen.findByRole('heading', { level: 1, name: 'Collection Unavailable' })).toBeTruthy();
    expect(fetch.mock.calls.some(([url]) => String(url).includes(path))).toBe(false);
    cleanup();
    vi.unstubAllGlobals();
    stubServer({ '/readyz': ready, [path]: new ProblemAnswer(503, 'INDEX_NOT_READY', 'The index is starting.') });
    renderAt('/archival-collection?id=lot%3A66D204');
    expect(await screen.findByText('Preparing your index…')).toBeTruthy();
    expect(screen.queryByRole('alert')).toBeNull();
  });

  it('says a record the authority does not hold is unavailable', async () => {
    stubServer({ '/readyz': ready, [path]: new ProblemAnswer(404, 'COLLECTION_NOT_FOUND', 'The collection authority has no record x.') });
    renderAt('/archival-collection?id=x');
    expect(await screen.findByRole('heading', { level: 1, name: 'Collection Unavailable' })).toBeTruthy();
    expect(screen.getByText('This collection is not in the bundled archival authority.')).toBeTruthy();
  });
});

describe('Source Explorer’s rules', () => {
  it('writes an access row, a candidate’s subtitle, and the guidance link’s freshness as the app does', () => {
    expect(statusValue('Restricted - Partly', ['FOIA (b)(1)', 'Donor restrictions'])).toBe('Restricted - Partly — FOIA (b)(1), Donor restrictions');
    expect(statusValue('Unrestricted', [])).toBe('Unrestricted');
    expect(curatedSubtitle({ entryNumber: 'A1 1590', dateRange: '1953–1961' })).toBe('A1 1590 · 1953–1961');
    expect(curatedSubtitle({})).toBeUndefined();
    expect(confirmedDay()).toBe('Aug 28, 2026');
    expect(publishedLinkStale(Date.UTC(2026, 10, 14))).toBe(false);
    expect(publishedLinkStale(Date.UTC(2027, 1, 25))).toBe(true);
  });
});
