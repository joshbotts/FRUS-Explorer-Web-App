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
