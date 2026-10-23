import { cleanup, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail, DocumentList, Section, Volume, VolumeSectionPage } from '../api/types';
import { coverage, ready, renderAt, stubServer } from '../test/renderRoute';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const section: Section = {
  sectionId: 'comp1',
  divType: 'compilation',
  title: 'Kennedy-Khrushchev Exchanges',
  documentIds: ['d2', 'd3'],
  subsections: [],
  documentCount: 2,
  indexedDocumentCount: 1,
  isFrontMatter: false,
  canReadDirectly: false,
  readable: false,
  hasOwnText: false,
};

const page: VolumeSectionPage = {
  volumeId: 'frus1961-63v06',
  volumeTitle: 'Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges',
  section,
  path: [],
  structureSource: 'tei',
  documents: [
    { documentId: 'd2', header: 'Editorial Note', displayTitle: 'Editorial Note 2', documentNumber: '2', isEditorialNote: true, inIndex: true, readable: true },
    { documentId: 'd3', header: 'Document 3', displayTitle: 'Document 3', documentNumber: '3', isEditorialNote: false, inIndex: false, readable: false },
  ],
};

const d2: DocumentDetail = {
  document: {
    documentId: 'd2',
    volumeId: 'frus1961-63v06',
    documentNumber: '2',
    header: 'Editorial Note',
    displayTitle: 'Editorial Note 2',
    isEditorialNote: true,
    inIndex: true,
  },
  canonicalURL: 'https://history.state.gov/historicaldocuments/frus1961-63v06/d2',
  teiAvailable: true,
};

describe('display titles in Browse and the reader', () => {
  it('names a section’s documents by the titles the server gives them, not their stored heads', async () => {
    stubServer({ '/readyz': ready, '/api/v1/volumes/frus1961-63v06/sections/comp1': page });
    renderAt('/browse/frus1961-63v06/comp1');
    const note = await screen.findByRole('link', { name: 'Editorial Note 2' });
    expect(note.getAttribute('href')).toBe('/doc/frus1961-63v06/d2');
    expect(screen.queryByRole('link', { name: 'Editorial Note' })).toBeNull();
    // One the reader cannot open is named, not linked.
    expect(screen.getByText('Document 3').tagName).toBe('SPAN');
  });

  it('names a volume’s reading order by the same titles, where neither the index nor the TEI gives its sections', async () => {
    const volume: Volume = {
      volumeId: 'frus1961-63v06',
      filename: 'frus1961-63v06.xml',
      subseries: '1961-63',
      title: page.volumeTitle,
      dateRange: {},
      status: 'published',
      editors: [],
      sizeBytes: 1,
      tags: [],
      indexed: true,
      indexedDocuments: 1,
      teiAvailable: false,
    };
    const order: DocumentList = { total: 1, limit: 1000, offset: 0, items: [d2.document], coverage };
    stubServer({ '/readyz': ready, '/api/v1/volumes/frus1961-63v06': volume, '/api/v1/volumes/frus1961-63v06/documents': order });
    renderAt('/browse/frus1961-63v06');
    expect((await screen.findByRole('link', { name: 'Editorial Note 2' })).getAttribute('href')).toBe('/doc/frus1961-63v06/d2');
  });

  it('heads the reader with the same title as the row that opened it', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/volumes/frus1961-63v06/documents/d2': d2,
      '/api/v1/volumes/frus1961-63v06/documents/d2/html': '',
    });
    renderAt('/doc/frus1961-63v06/d2');
    await waitFor(() => expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Editorial Note 2'));
    await waitFor(() => expect(document.title).toBe('Editorial Note 2 – FRUS Explorer Light'));
  });
});

describe('a section’s own text, as the app’s Browse lists it', () => {
  const v01 = 'frus1969-76v01';
  const v01Title = 'Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972';
  const leaf = (sectionId: string, title: string): Section => ({
    sectionId,
    divType: 'chapter',
    title,
    documentIds: [],
    subsections: [],
    documentCount: 0,
    indexedDocumentCount: 0,
    isFrontMatter: false,
    canReadDirectly: true,
    readable: true,
    hasOwnText: false,
  });
  const meeting: Section = { ...leaf('ch1', 'First Meeting'), documentIds: ['d1'], documentCount: 1, indexedDocumentCount: 1, canReadDirectly: false, hasOwnText: true };
  const treaties: Section = { ...leaf('comp2', 'Treaties'), divType: 'compilation', canReadDirectly: false, subsections: [leaf('t1', 'Treaty One')], hasOwnText: true };
  const row = (documentId: string, header: string, readable?: boolean) => ({
    documentId,
    header,
    displayTitle: header,
    isEditorialNote: false,
    inIndex: true,
    ...(readable === undefined ? {} : { readable }),
  });
  const note = 'The text this section prints outside the documents and sections it holds.';

  it('lists the row first, above the documents, named Read and the section’s title over the app’s sentence', async () => {
    const page: VolumeSectionPage = {
      volumeId: v01,
      volumeTitle: v01Title,
      section: meeting,
      path: [],
      structureSource: 'index',
      ownText: row('ch1', 'First Meeting', true),
      documents: [row('d1', '1. Minutes', true)],
    };
    stubServer({ '/readyz': ready, [`/api/v1/volumes/${v01}/sections/ch1`]: page });
    renderAt(`/browse/${v01}/ch1`);
    const own = await screen.findByRole('link', { name: 'Read First Meeting', description: note });
    expect(own.getAttribute('href')).toBe(`/doc/${v01}/ch1`);
    const documents = screen.getByRole('heading', { name: 'Documents (1)' });
    expect(own.compareDocumentPosition(documents) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.getByText('1 of 1 document indexed on this server')).toBeTruthy();
  });

  it('lists it above the sections of a section that holds only sections, with no count of documents it has none of', async () => {
    const page: VolumeSectionPage = {
      volumeId: v01,
      volumeTitle: v01Title,
      section: treaties,
      path: [],
      structureSource: 'index',
      ownText: row('comp2', 'Treaties', true),
      documents: [],
    };
    stubServer({ '/readyz': ready, [`/api/v1/volumes/${v01}/sections/comp2`]: page });
    renderAt(`/browse/${v01}/comp2`);
    const own = await screen.findByRole('link', { name: 'Read Treaties' });
    const sections = screen.getByRole('heading', { name: 'Sections' });
    expect(own.compareDocumentPosition(sections) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Treaty One' }).getAttribute('href')).toBe(`/doc/${v01}/t1`);
    expect(screen.queryByText(/documents? indexed on this server/)).toBeNull();
    expect(screen.queryByRole('heading', { name: /^Documents/ })).toBeNull();
  });

  it('names a row the reader cannot open, and lists none where the index holds none', async () => {
    const unreadable: VolumeSectionPage = {
      volumeId: v01,
      volumeTitle: v01Title,
      section: meeting,
      path: [],
      structureSource: 'index',
      ownText: row('ch1', 'First Meeting', false),
      documents: [row('d1', '1. Minutes', false)],
    };
    stubServer({ '/readyz': ready, [`/api/v1/volumes/${v01}/sections/ch1`]: unreadable });
    renderAt(`/browse/${v01}/ch1`);
    expect((await screen.findByText('Read First Meeting')).tagName).toBe('SPAN');
    expect(screen.queryByRole('link', { name: 'Read First Meeting' })).toBeNull();
    cleanup();

    stubServer({ '/readyz': ready, '/api/v1/volumes/frus1961-63v06/sections/comp1': page });
    renderAt('/browse/frus1961-63v06/comp1');
    await screen.findByRole('link', { name: 'Editorial Note 2' });
    expect(screen.queryByText(/^Read /)).toBeNull();
    expect(screen.queryByText(note)).toBeNull();
  });

  it('opens from the volume’s contents a section whose only documents are its own text’s, on its page', async () => {
    const volume: Volume = {
      volumeId: v01,
      filename: `${v01}.xml`,
      subseries: '1969-76',
      title: v01Title,
      dateRange: {},
      status: 'published',
      editors: [],
      sizeBytes: 1,
      tags: [],
      indexed: true,
      indexedDocuments: 4,
      teiAvailable: true,
      structure: [treaties, { ...leaf('comp3', 'Conventions'), divType: 'compilation', canReadDirectly: false, readable: false, subsections: [leaf('t3', 'Convention One')] }],
      structureSource: 'index',
      documentCount: 0,
      indexedDocumentCount: 0,
    };
    stubServer({ '/readyz': ready, [`/api/v1/volumes/${v01}`]: volume });
    renderAt(`/browse/${v01}`);
    expect((await screen.findByRole('link', { name: 'Treaties' })).getAttribute('href')).toBe(`/browse/${v01}/comp2`);
    // One with no row of its own is named, and its prose opens in the reader.
    expect(screen.queryByRole('link', { name: 'Conventions' })).toBeNull();
    expect(screen.getByRole('link', { name: 'Convention One' }).getAttribute('href')).toBe(`/doc/${v01}/t3`);
  });
});
