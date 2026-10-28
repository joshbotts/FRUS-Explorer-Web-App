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
  | 'stripping_writing'
  | 'checking_integrity'
  | 'moving_writing'
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
  /**
   * Whether the index holds a row of the text it prints outside the documents and sections it holds,
   * which its page lists first: the kit's VolumeSection.ownTextEntry(among:).
   */
  hasOwnText: boolean;
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
  /** The row of the text the section prints outside the documents and sections it holds, which Browse lists first. */
  ownText?: SectionDocument;
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
  /** The user's tags on the document, each once, its id in upper case, as the kit reads them; none for no one. */
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
  /** In Checklist Mode (S17e), how many of the results kept the pages leave out as reviewed. */
  hidden?: number;
  coverage: Coverage;
}

/** A document in a year of the timeline, named as its row in the results names it, with its label. */
export interface TimelineDocument {
  volumeId: string;
  documentId: string;
  displayTitle: string;
  documentLabel: string;
  headerRepeatsNumber: boolean;
}

/**
 * A search's timeline (GET /search/timeline): how many of the results the app keeps of it fall in
 * each year, by the kit's Years facet over them.
 */
export interface SearchTimeline {
  retainedLimit: number;
  /** The results it counts: those the app keeps, the whole match up to retainedLimit; /search counts the match. */
  retainedCount: number;
  /** The order of each year's documents. */
  sort: SortOrder;
  /** The years that hold a result, earliest first, each by the kit's key: four digits. */
  years: { year: string; count: number; documents?: TimelineDocument[] }[];
  /** The results kept that carry no date, and so are in no year. */
  undatedCount: number;
  coverage: Coverage;
}

/** The kit's KWICSort: how a concordance's lines are ordered. */
export type ConcordanceOrder = 'leftContext' | 'rightContext' | 'date' | 'volume';

/** One occurrence, with the text either side of it: the kit's KWICLine. */
export interface ConcordanceLine {
  volumeId: string;
  documentId: string;
  header: string;
  /** What the document's row in the results names it by. */
  displayTitle: string;
  dateISO?: string;
  left: string;
  /** The occurrence as the document spells it. */
  keyword: string;
  right: string;
  characterOffset: number;
}

/** The concordance of one page of a search's results (GET /search/concordance), as the kit builds it. */
export interface SearchConcordance {
  /** The page the lines are of; /search counts the match it is a page of. */
  limit: number;
  offset: number;
  retainedLimit: number;
  sort: SortOrder;
  documentsOnPage: number;
  items: ConcordanceLine[];
  /** Each of the kit's orders, as positions in items. */
  orders: Record<ConcordanceOrder, number[]>;
  /** The orders, with the kit's label for each; the first is the Mac's. */
  orderChoices: Choice[];
  /** Occurrences the kit's bound on one document's lines left out. */
  omittedCount: number;
  documentsWithLines: number;
  documentsWithoutLines: number;
  /** That bound, when it left any out. */
  linesPerDocumentLimit?: number;
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

/** A volume of the published catalogue, as `manifest.json` describes it (the kit's `VolumeManifestEntry`). */
export interface VolumeManifestEntry {
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
}

/** How the kit's matcher made a match, by the draft's names. */
export type MatchStrategy =
  | 'exactDocumentNumber'
  | 'pageRange'
  | 'sharedPage'
  | 'superimposedDocumentNumber'
  | 'titleFragmentMatch'
  | 'manifestOnly'
  | 'bestGuess';

/** A candidate the kit's matcher gives, by the draft's `CitationMatch`. */
export interface CitationLookupMatch {
  /** Empty for a row that names a volume and no document. */
  documentId: string;
  volumeId: string;
  rank: number;
  matchStrategy: MatchStrategy;
  /** The kit's label, which the app shows above the result. */
  confidenceLabel: string;
  correctionNote: string | null;
  /** The volume is not one the served index holds. */
  requiresDownload: boolean;
  awaitingIndex: boolean;
  volumeManifestEntry: VolumeManifestEntry | null;
  sharedPageTotal: number | null;
  volumeIsBestGuess: boolean;
  isBestGuess: boolean;
  bestGuessExplanation: string | null;
  sharedPageDocuments: number | null;
}

export type CitationLookupMode = 'paste' | 'structured' | 'batch';

/** The Parsed Fields, by the API's names. */
export interface CitationFields {
  subseries: string;
  volumeNumber: string;
  partNumber: string;
  documentNumber: string;
  pageNumber: string;
}

/** `GET /api/v1/citation-lookup/fields`: the kit's form, its fields and Look Up's gate. */
export interface CitationLookupForm extends CitationFields {
  mode: CitationLookupMode;
  actionable: boolean;
}

export type BatchOutcome = 'resolved' | 'bestGuess' | 'ambiguous' | 'missing' | 'failed';

/** A row of Batch's triage table. */
export interface CitationBatchRow {
  /** Its place in the paste, from 1. */
  index: number;
  /** The footnote's number as printed, or null. */
  marker: string | null;
  text: string;
  outcome: BatchOutcome;
  /** How many documents an ambiguous row may be. */
  count: number | null;
  /** Why a failed row could not be looked up. */
  reason: string | null;
  /** The kit's order for Needs work first. */
  triageOrder: number;
  /** The label a row shows in place of a count. */
  loneCandidateLabel: string | null;
  matches: CitationLookupMatch[];
}

/** `POST /api/v1/citation-lookup/batch`. */
export interface CitationBatch {
  /** The kit's summary of the rows. */
  summary: string;
  items: CitationBatchRow[];
}

/** `GET /api/v1/me`: who the server takes the browser to be, and the token its changes carry. */
export interface Me {
  userId: string;
  displayName: string;
  /** `FRUS_AUTH`: `none` for a server with no sign-in, `header` behind a proxy that signs people in. */
  auth: string;
  roles: ('reader' | 'curator' | 'admin')[];
  /** False when the server keeps no user data (`FRUS_USER_DATA=off`), and refuses all of it. */
  userData: boolean;
  csrfToken: string;
}

/** One of the user's tags. */
export interface UserTag {
  id: string;
  name: string;
  createdAt?: string;
  lastModified?: string;
}

export interface TagList {
  total: number;
  items: UserTag[];
}

/**
 * The user's tags, in the tag list's order, each with how many documents of a search's results carry
 * it (GET /me/search/tags), as the Mac's My Tags toggles count them.
 */
export interface SearchTagCounts {
  items: (UserTag & { count: number })[];
  coverage: Coverage;
}

/** The tags one document carries, in the tag list's order. */
export interface DocumentTags {
  volumeId: string;
  documentId: string;
  items: UserTag[];
}

/** A highlight's colour, as the app's `HighlightColor` names it. */
export type HighlightColor = 'yellow' | 'green' | 'blue' | 'pink';

/** The four, in the order the app's selection bar offers them (`HighlightColor.allCases`). */
export const highlightColors: readonly HighlightColor[] = ['yellow', 'green', 'blue', 'pink'];

/** One of the user's highlights, with the fields of the Mac's export. */
export interface Highlight {
  id: string;
  volumeId: string;
  documentId: string;
  /** UTF-16 offsets into the document's flat text, the first included and the last not. */
  startOffset: number;
  endOffset: number;
  /** One of the four colours for a highlight made here; an imported one keeps the Mac's. */
  colorTag: string;
  noteId?: string;
  selectedText: string;
  renderingVersion: string;
  createdAt?: string;
  /** In a document's list only: whether its text has changed since, by the kit's rule. */
  isStale?: boolean;
}

export interface HighlightList {
  total: number;
  items: Highlight[];
}

/**
 * A document's highlights, in the order the app's reader draws them, with the document's current
 * rendering version, absent when the server cannot render the document.
 */
export interface DocumentHighlights {
  volumeId: string;
  documentId: string;
  renderingVersion?: string;
  items: Highlight[];
}

/**
 * A stretch of a note's text with one formatting, as the app's `ProseFormattedSpan` carries it and
 * FRUSRichText's `RichTextRun` encodes it: the runs of a note, concatenated, are its `bodyText`, and
 * a "\n" in one is a line break, the app's Return. `colorHex` is uppercase `RRGGBB` and absent for
 * no colour (near-black included); `linkURL` is absent for no link.
 */
export interface NoteRun {
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  colorHex?: string;
  linkURL?: string;
}

/** A research note in a list, with the fields of the Mac's export (`ResearchNoteExport`) but its formatting. */
export interface NoteSummary {
  id: string;
  volumeId: string;
  documentId: string;
  /** The plain text, which is canonical: what every list, search and export reads. */
  bodyText: string;
  projectIds: string[];
  userTagIds: string[];
  selectedSummaryIds: string[];
  /** The highlights whose note this is, as the highlights' own `noteId` says. */
  linkedHighlightIds: string[];
  createdAt?: string | null;
  lastModified?: string | null;
  /**
   * A document's note block from a research database the Mac exported with the owner's writing,
   * which joins the document's notes into one.
   */
  fromResearchDatabase: boolean;
}

/** One note, with its formatting as runs, the codec's reading of the RTF the store keeps. */
export interface Note extends NoteSummary {
  /** Null for a note with no formatting, or one whose stored formatting the server keeps but cannot give. */
  runs: NoteRun[] | null;
  /** True when the store holds formatting it cannot give as runs: it is kept until the text is next edited. */
  formattingKept: boolean;
}

export interface NoteList {
  total: number;
  items: NoteSummary[];
}

/** A document's notes, the last changed first. */
export interface DocumentNotes {
  volumeId: string;
  documentId: string;
  items: NoteSummary[];
}

/** A summary's authorship, as the kit's `SummaryAuthorship` names it; the store's null reads as AI. */
export type SummaryAuthorship = 'aiGenerated' | 'aiEdited' | 'userWritten';

/** A summary of a document: one the researcher wrote here, or one imported from the Mac. */
export interface Summary {
  id: string;
  volumeId: string;
  documentId: string;
  promptId: string;
  /** The name of the prompt that made it, only while the user's prompts hold that prompt. */
  promptName: string | null;
  /** The text, raw: a structured summary's JSON as the app shows it. */
  responseText: string;
  responseFormat: 'general' | 'structured' | 'unknown';
  wasChunked: boolean;
  authorship: SummaryAuthorship;
  /**
   * A collection's headnote draft, which the app keeps out of a document's own summaries: never in
   * a document's list, so only a read by its id can give one.
   */
  isHeadnoteDraft: boolean;
  projectId: string | null;
  createdAt?: string | null;
  lastModified?: string | null;
  /** Whether the researcher may change it: only one written here is theirs to change. */
  editable: boolean;
  /** Whether the researcher may delete it: one written here, or one from a research database. */
  deletable: boolean;
  /** A document's newest summary from a research database the Mac exported with the owner's writing. */
  fromResearchDatabase: boolean;
}

/** A document's summaries, drafts left out, the newest first by the app's `ranksAbove`. */
export interface DocumentSummaries {
  volumeId: string;
  documentId: string;
  items: Summary[];
}

/** One of the user's projects, which only an import fills until S17f. */
export interface Project {
  id: string;
  name: string;
}

export interface ProjectList {
  total: number;
  items: Project[];
}

/** The app's model types, as an import's report names them (PLAN's S16c). */
export type ResearchType =
  | 'ResearchNote'
  | 'DocumentHighlight'
  | 'UserTag'
  | 'DocumentTagAssignment'
  | 'Collection'
  | 'CollectionEntry'
  | 'Project'
  | 'ProjectLeadEntry'
  | 'SavedSearch'
  | 'WorkingCorpus'
  | 'CustomVolumeScope'
  | 'ReadingHistoryEntry'
  | 'SearchHistoryEntry'
  | 'ExportHistoryEntry'
  | 'ArchiveVisitPlan'
  | 'ArchiveVisitDocument'
  | 'ArchiveVisitTarget'
  | 'GeneratedSummary'
  | 'SummarizationPrompt'
  | 'AnnotationReview'
  | 'SyncedPreferences'
  | 'PersonClusterOverride'
  | 'DocumentClassificationOverride';

/** What became of one model type's records in an import. */
export interface ImportTypeCount {
  type: ResearchType;
  /** Whether a file of the export's format version can carry the type. */
  carried: boolean;
  inFile: number;
  /** Records the store did not hold, now written. */
  added: number;
  /** Records of which the store held an older copy, now the file's. */
  replaced: number;
  /** Records of which the store held a copy as new or newer, kept. */
  kept: number;
  /** Synced settings after the earliest, and an instance's corrections for a user who is no curator. */
  setAside: number;
  /** Records whose id the file already gave: one copy written, the newest. */
  repeated: number;
}

/** A collection that names a saved search the user does not hold. */
export interface UnlinkedCollection {
  id: string;
  name: string;
}

/** What a Mac JSON export brought to the user's store. */
export interface ResearchImportReport {
  formatVersion: number;
  exportedAt: string;
  /** Each of the 23 model types, in the store's order. */
  types: ImportTypeCount[];
  formattedNotes: number;
  /** Notes whose RTF this server cannot show, kept as it came: they open plain until edited here. */
  formattingKept: number;
  headnoteDrafts: number;
  summariesWithoutAuthorship: number;
  /** A version-6 file's collection entries with no document, kept as the app keeps an unknown kind. */
  inertEntries: number;
  unlinkedCollections: UnlinkedCollection[];
  searchableDocuments: number;
}

/** How many records of one model type an export carries (PLAN's S16d). */
export interface ExportTypeCount {
  type: ResearchType;
  count: number;
}

/** What an export of the user's would carry, for Settings ▸ Data's Contents. */
export interface ExportContents {
  /** The format version the export writes, the kit's. */
  formatVersion: number;
  /** Each of the 23 model types, in the store's order: the summaries as with the switch on. */
  types: ExportTypeCount[];
}

/** An import of a Mac JSON export, as a job: queued, running, then succeeded or failed. */
export interface ImportStatus {
  /** A UUID, new for each import, so an id from before a restart names none. */
  id: string;
  state: 'queued' | 'running' | 'succeeded' | 'failed';
  formatVersion: number;
  report: ResearchImportReport | null;
  problem: { code: string; detail: string } | null;
}
