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
  /** On /volumes/{v} alone: its sections, from the index or, failing that, the TEI. */
  structure?: Section[];
  structureSource?: 'index' | 'tei';
  documentCount?: number;
  indexedDocumentCount?: number;
}

/** A section of a volume, with the kit's flags for it. */
export interface Section {
  sectionId: string;
  divType: string;
  title: string;
  documentIds: string[];
  subsections: Section[];
  documentCount: number;
  indexedDocumentCount: number;
  isFrontMatter: boolean;
  canReadDirectly: boolean;
  /** Whether the reader can open it as a document; absent without the TEI. */
  readable?: boolean;
}

/** A document in a section's list, from the index or, failing that, the TEI. */
export interface SectionDocument {
  documentId: string;
  header: string;
  documentNumber?: string;
  dateline?: string;
  isEditorialNote: boolean;
  inIndex: boolean;
  readable?: boolean;
}

export interface VolumeSectionPage {
  volumeId: string;
  volumeTitle: string;
  section: Section;
  /** The sections above it, outermost first. */
  path: { sectionId: string; title: string }[];
  documents: SectionDocument[];
  structureSource: 'index' | 'tei';
}

export interface DocumentList {
  total: number;
  limit: number;
  offset: number;
  items: DocumentEntry[];
  coverage: Coverage;
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
  /** Whether the reader can open it; absent without the TEI. */
  readable?: boolean;
}

/** What a link in the reader's page leads to (GET …/documents/{d}/link). */
export interface ReaderLinkTarget {
  kind: 'person' | 'gloss' | 'document' | 'page' | 'external' | 'unresolved' | 'brokenReference';
  href: string;
  ref?: string;
  person?: { ref: string; name: string; description?: string; role?: string; eraText?: string };
  term?: { ref: string; term: string; definition?: string };
  target?: string;
  destination?: {
    volumeId: string;
    documentId: string;
    footnoteAnchor?: string;
    footnoteElementId?: string;
    canonicalURL: string;
  };
  inPlace?: boolean;
  volume?: { title: string; teiAvailable: boolean; indexed: boolean };
  page?: number;
  pageVolumeId?: string;
  url?: string;
  brokenReference?: { target: string; reason: string; resolvedVolume?: string; resolvedAnchor?: string };
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
