// The server's JSON, as Sources/FRUSLightAPI's Codable types write it. Written by hand until the
// server publishes /api/v1/openapi.json; the end-to-end test catches drift.

export interface Problem {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance: string;
  code: string;
  searchError?: string;
}

export type ReadinessStep =
  | 'waiting_for_export'
  | 'copying_export'
  | 'checking_format'
  | 'checking_versions'
  | 'checking_writing'
  | 'checking_integrity'
  | 'installing_index'
  | 'opening_index'
  | 'index_version_mismatch'
  | 'ready';

export interface Readiness {
  ready: boolean;
  step: ReadinessStep;
  detail: string;
  progress?: number;
}

export interface Coverage {
  indexedVolumes: number;
  indexedDocuments: number;
  manifestVolumes: number;
  indexVersion?: number;
}

export interface DateRange {
  earliest?: string;
  latest?: string;
}

export interface Volume {
  volumeId: string;
  filename: string;
  subseries: string;
  title: string;
  dateRange: DateRange;
  publicationDate?: string;
  status: 'published' | 'partiallyPublished' | 'planned';
  editors: string[];
  generalEditor?: string;
  sizeBytes: number;
  tags: string[];
  indexed: boolean;
  indexedDocuments: number;
  teiAvailable: boolean;
}

export interface VolumeList {
  total: number;
  limit: number;
  offset: number;
  items: Volume[];
  coverage: Coverage;
}

export interface DocumentEntry {
  documentId: string;
  volumeId: string;
  documentNumber?: string;
  header: string;
  dateline?: string;
  sourceNote?: string;
  dateISO?: string;
  isEditorialNote: boolean;
  inIndex: boolean;
}

export interface Neighbour {
  documentId: string;
  header: string;
  inIndex: boolean;
}

export interface DocumentDetail {
  document: DocumentEntry;
  canonicalURL: string;
  previous?: Neighbour;
  next?: Neighbour;
  teiAvailable: boolean;
}

export type DocumentType = 'all' | 'documentsOnly' | 'editorialNotesOnly';

export interface SearchItem {
  volumeId: string;
  documentId: string;
  documentNumber?: string;
  header: string;
  dateline?: string;
  sourceNote?: string;
  dateISO?: string;
  /** The document's text around the matches, with <b> and </b> marking them; otherwise plain text. */
  snippet: string;
  bm25Score: number;
  isEditorialNote: boolean;
  isFrontMatter: boolean;
  subjectTagIds: string[];
  userTagIds: string[];
}

export interface SearchResultList {
  total: number;
  countBasis: 'exact' | 'atLeast';
  limit: number;
  offset: number;
  retainedLimit: number;
  items: SearchItem[];
  coverage: Coverage;
}

export type CitationStyleName = 'historyAtState' | 'chicago' | 'turabian';

export interface CitationStyle {
  style: CitationStyleName;
  name: string;
  shortName: string;
}

export interface DocumentCitation {
  volumeId: string;
  documentId: string;
  style: CitationStyleName;
  /**
   * The formatter's text, with Markdown emphasis: _…_ around the series title in the
   * history.state.gov style, *…* around the whole volume title in Chicago and Turabian.
   */
  citation: string;
  /** What Copy writes. */
  plainText: string;
  canonicalURL: string;
  documentNumber?: string;
  documentLabel: string;
  /** Where documentNumber came from; absent when there is none. */
  numberSource?: 'index' | 'tei' | 'documentId';
  publicationYearSource: 'manifest';
  styles: CitationStyle[];
}
