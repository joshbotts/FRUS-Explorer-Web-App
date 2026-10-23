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
  /** What the list calls it: the kit's DocumentDisplayTitle, its rule for naming a document in a list. */
  displayTitle: string;
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
  /** What a list calls it, and the reader's heading: the kit's DocumentDisplayTitle. */
  displayTitle: string;
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
  kind: 'person' | 'gloss' | 'document' | 'page' | 'volume' | 'external' | 'unresolved' | 'brokenReference';
  href: string;
  ref?: string;
  person?: { ref: string; name: string; description?: string; role?: string; eraText?: string };
  /** For a person the volume's list has, how many indexed documents mention them; absent with no index. */
  mentionCount?: number;
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
  /** For a page reference: the page and its volume; `destination` is the document the kit's PageLink lands on, if any. */
  page?: number;
  pageVolumeId?: string;
  /**
   * The volume the link opens: a whole volume's, or a page's when PageLink can name no document on
   * it without the volume; `volume` is absent for one outside the catalogue.
   */
  volumeId?: string;
  /** Where that volume opens, as the kit's WholeVolumeLink sends it: its page in Browse, or on history.state.gov (`url`). */
  wholeVolumeLink?: 'browse' | 'web';
  /** For `external`, its address; for a link that opens a volume, the volume's page on history.state.gov. */
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
  /** What the row names it by, as the Mac's search window draws it: the header, less a leaked source note. */
  displayTitle: string;
  /** Its label beside the volume, "Doc 12" or "Unnumbered (d710a-1)". */
  documentLabel: string;
  /** Whether the header opens with the document's number, so the row withholds the label. */
  headerRepeatsNumber: boolean;
  dateline?: string;
  sourceNote?: string;
  dateISO?: string;
  /** The row's last day: the end of a section's span, which the index dates by its documents. */
  dateISOMax?: string;
  datePrecision?: 'day' | 'month' | 'year';
  /** The kit's words for the row's date, which a row with no dateline draws: "August 21, 1945 – January 22, 1946". */
  drawnDate?: string;
  /** The document's text around the matches, with <b> and </b> marking them; otherwise plain text. */
  snippet: string;
  bm25Score: number;
  isEditorialNote: boolean;
  isFrontMatter: boolean;
  subjectTagIds: string[];
  userTagIds: string[];
}

/** The kit's SearchSortOrder: relevance, or the date, oldest or most recent first. */
export type SortOrder = 'relevance' | 'dateAscending' | 'dateDescending';

/** A choice a control offers, by its value and the kit's title for it. */
export interface Choice {
  value: string;
  title: string;
}

export interface SearchResultList {
  total: number;
  countBasis: 'exact' | 'atLeast';
  limit: number;
  offset: number;
  retainedLimit: number;
  /** The order the page is cut from. */
  sort: SortOrder;
  /** The three orders, with the kit's label for each. */
  sortChoices: Choice[];
  items: SearchItem[];
  coverage: Coverage;
}

/** One of a query's searchable units, as the kit's parser reports it. */
export interface SearchOperand {
  text: string;
  rendered: string;
  kind: 'word' | 'phrase' | 'prefix' | 'proximity';
  isNegated: boolean;
  /** The `=` as typed, and whether the search filters on it. */
  isExact: boolean;
  isExactApplied: boolean;
  /** Typed into the search box, or from a structured field. */
  source: 'typed' | 'structured';
}

/** The kit's InspectedOperand: a term, with what the index knows of it. */
export interface InspectedTerm {
  operand: SearchOperand;
  /** The index term its word resolves to; absent for a phrase, a prefix or a proximity search. */
  stem?: string;
  /** Its count within the search's filters, once counted. */
  scopedCount?: number;
  /** Over the whole index, unfiltered: the documents that hold the stem, and its occurrences. */
  corpusDocumentFrequency?: number;
  corpusOccurrences?: number;
  corpusOccurrencesPerDocument?: number;
  isStemBroadening: boolean;
  /** Whether it came from a structured field: the ADVANCED tag. */
  showsStructuredTag: boolean;
}

/** The kit's QueryInspection: what the Query Inspector shows of a search. */
export interface QueryInspection {
  expression?: { corpus?: string; userContent?: string; displayed?: string; expressionsDiffer: boolean };
  operands: InspectedTerm[];
  /** What the query typed that the search leaves out. */
  notApplied: SearchOperand[];
  /** How many volumes the served index holds: what every count is out of. */
  indexedVolumeCount: number;
  isFilterOnly: boolean;
  isApproximate: boolean;
  isRefused: boolean;
  /** The NEAR(…) that refused the query, as typed. */
  malformedProximity?: string;
  showsStrip: boolean;
  showsApproximateCaption: boolean;
  showsTermRows: boolean;
  hasOperands: boolean;
  hasUncountedOperands: boolean;
}

/** What the kit compiles for a search, and the Query Inspector's account of it (GET /search/inspect). */
export interface SearchInspection {
  /** The inspector's account; absent while no index is served. */
  inspection?: QueryInspection;
  /** With emptyConjuncts=true: the terms that match nothing on their own under the search's filters. */
  emptyConjuncts?: SearchOperand[];
}

/** How one search becomes another: each query field that changes, with its new values, or null for one left out. */
export type SearchChange = Record<string, string[] | null>;

/** The six ways a search's facets break its match down, in the panel's order. */
export type FacetSectionName = 'years' | 'volumes' | 'people' | 'documentType' | 'provenance' | 'subjects';

/** One section of a search's facets (GET /search/facets): a page of its rows, as the kit cuts it. */
export interface SearchFacetSection {
  section: FacetSectionName;
  /** Staged rows are chosen, then applied; an immediate row narrows on a click; descriptive rows only describe. */
  selection: 'staged' | 'immediate' | 'descriptive';
  matchCount: number;
  rows: { key: string; label: string; count: number; narrowing?: SearchChange }[];
  page: { matchingCount: number; totalCount: number; pageIndex: number; pageCount: number; firstRowNumber: number };
  display: { sort: string; pageSize: string; page: number; filter: string };
  sortChoices: { value: string; title: string }[];
  pageSizeChoices: { value: string; title: string }[];
  bound?: { shown: number; total: number; isTruncated: boolean };
  undatedCount?: number;
  topVolumeShare?: number;
  provenanceCoverage?: { parsed: number; withRecordGroup: number; matchCount: number };
  subjectCoverage?: number;
  subjectsPrepared?: boolean;
  coverage: Coverage;
}

/** What a staged selection narrows the search to (GET /search/facets/selection). */
export interface SearchFacetSelection {
  section: 'years' | 'volumes';
  /** The keys the selection resolves to; absent when nothing is chosen. */
  keys?: string[];
  change: SearchChange;
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
  /** The year the citation and the records name, or "n.d.". */
  publicationYear: string;
  /** Where the year came from: the volume's TEI header, else the manifest; absent for "n.d.". */
  publicationYearSource?: 'tei' | 'manifest';
  /** The kit's BibTeX @incollection record, as Copy BibTeX writes it. */
  bibtex: string;
  /** The kit's RIS record, as Copy RIS writes it. */
  ris: string;
  styles: CitationStyle[];
}
