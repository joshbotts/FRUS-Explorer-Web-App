// Source Explorer (PLAN's S22d): a document's source note resolved on the server by the kit's
// `SourceExplorerResolution`, with the app's panels built from it, and the archival neighbours of a document,
// a Sources row, a collection or a class, in the app's three scopes. The words the kit writes come in the
// answers; the words the app's views write themselves are copy.ts's.
import { queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';
import type { NARASearch } from './nara';

const segment = encodeURIComponent;

/** A link the answer names, with the kit's words for it when it writes any. */
export interface SourceLink {
  url: string;
  label?: string;
}

/** A catalog record a panel names: NARA's title, its dates, its address and the label above it. */
export interface SourceRecord {
  label?: string;
  title: string;
  dates?: string;
  catalogURL?: string;
}

/** A digitized scan, a decimal file range or a Numerical File roll (`DigitizedScanPresentation`). */
export interface SourceScan {
  title: string;
  objectCount: number;
  imageCountLabel?: string;
  pdf?: SourceLink;
  catalogURL?: string;
  /** One of several ranges that hold the file, shown with the app's "Possible" chip. */
  candidate: boolean;
}

export interface CuratedSeriesRow {
  title: string;
  catalogURL: string;
  entryNumber?: string;
  dateRange?: string;
}

/** A curated lot outcome, or the series NARA divided a lot across. */
export interface CuratedOutcome {
  kind: 'possible' | 'candidates' | 'referral';
  series: CuratedSeriesRow[];
  rationale: string;
  creatorName?: string;
  seeAllURL?: string;
  guidance?: string;
  seriesCount?: number;
  entryNumberRange?: string;
  browseURL?: string;
}

/** A lot's one bundled NARA series, with NARA's facts about it. */
export interface BundledLot {
  title: string;
  seriesTitle?: string;
  creator?: string;
  accessStatus?: string;
  accessRestrictions?: string[];
  useStatus?: string;
  useRestrictions?: string[];
  years?: string;
  extent?: string;
  heldAt?: string;
  findingAids?: string[];
  entryNumbers?: string[];
  seriesEntryNumbers?: string[];
  catalogURL: string;
}

/** The presidential-library catalogue's answer, in the kit's words. */
export interface LibraryOutcome {
  sectionTitle: string;
  collection?: SourceRecord;
  resolvedSeries?: SourceRecord;
  caveat?: string;
  candidates: SourceRecord[];
  provenanceNote: string;
}

/** The repository that holds what NARA does not, in the kit's words. */
export interface RepositoryGuidance {
  name: string;
  formerName?: string;
  citedAsLabel: string;
  holdings: string;
  link?: SourceLink;
}

/** A row of the full table of filing periods. */
export interface FilingPeriodRow {
  id: string;
  label: string;
  url: string;
  manuals: SourceLink[];
}

/** The kinds of the provenance section's panels, each one of the app's sections. */
export type PanelKind =
  | 'subjectNumeric'
  | 'centralFiles'
  | 'numericalFile'
  | 'filingPeriod'
  | 'parisPeace'
  | 'digitizedScans'
  | 'cfpf'
  | 'lotFile'
  | 'naraCollection'
  | 'curatedLot'
  | 'bundledLot'
  | 'naraCatalog'
  | 'cia'
  | 'presidentialLibrary'
  | 'curatedLibrary'
  | 'offlineLibrary'
  | 'outsideNARA'
  | 'namedFileSeries'
  | 'namedSeriesRouting'
  | 'foreignArchive'
  | 'previouslyPublished'
  | 'unrecognized';

/** One of the provenance section's panels: its kind, and the facts that kind shows. */
export interface SourcePanel {
  kind: PanelKind;
  recordGroup?: string;
  /** The provenance chip's source beside a lot's record group. */
  recordGroupSource?: string;
  fileIdentifier?: string;
  lotNumber?: string;
  series?: string;
  lotFile?: string;
  box?: string;
  jobNumber?: string;
  library?: string;
  libraryCollection?: string;
  seriesName?: string;
  description?: string;
  citation?: string;
  postRecords?: boolean;
  explainer?: string;
  link?: SourceLink;
  links?: SourceLink[];
  designation?: string;
  block?: string;
  handbooks?: SourceLink[];
  period?: SourceLink;
  manual?: SourceLink;
  periods?: FilingPeriodRow[];
  scans?: SourceScan[];
  scanState?: 'resolved' | 'multiple' | 'classOnly';
  rangeCount?: number;
  caveat?: string;
  title?: string;
  notes?: string[];
  records?: SourceRecord[];
  findingAidsTitle?: string;
  findingAids?: SourceRecord[];
  outcome?: CuratedOutcome;
  lot?: BundledLot;
  libraryOutcome?: LibraryOutcome;
  guidance?: RepositoryGuidance;
  /**
   * The NARA Catalog query the app's `load()` runs for the note, which the NARA proxy runs (PLAN's S22e): its
   * search, and how far its answer is tied to the citation (`CatalogQueryEvidence`).
   */
  catalogQuery?: {
    route?: string;
    manualSearchURL?: string;
    search?: NARASearch;
    evidence?: { sectionTitle: string; caveat?: string; isVerified: boolean };
  };
  rationale?: string;
  /** A previously published citation the grammar recognizes: its publication and what to look for. */
  publication?: string;
  publicationDesignation?: string;
}

export interface CountrySeriesHome {
  category: string;
  confidence: string;
  confidenceLevel: 'high' | 'medium';
  chiefOfMission: boolean;
  part?: string;
  rationale: string;
  rolls: SourceRecord[];
}

export interface SourcesNeighbour {
  volumeId: string;
  documentId: string;
  number?: string;
  title: string;
  dateline?: string;
}

export interface UnprintedRow {
  id: string;
  title: string;
  spokenTitle: string;
  clause?: string;
  repeatNote?: string;
  sameLotNote?: string;
  fileId?: string;
  inherited: boolean;
  source: string;
  record?: { id: string; name: string; volumeCount: number };
}

/** A document's Source Explorer, as the app's view shows it before any NARA Catalog search. */
export interface SourceExplorer {
  volumeId: string;
  documentId: string;
  documentTitle: string;
  rawSourceNote: string;
  hasSourceNote: boolean;
  parsed: { kind: string; fields: Record<string, string> };
  classificationMarking?: string;
  dateline?: string;
  year?: number;
  provenance: SourcePanel[];
  countrySeries?: {
    serial?: { title: string; caption: string };
    enclosureNote?: string;
    homes: CountrySeriesHome[];
  };
  noSourceNote?: {
    state: 'notChecked' | 'notApplicable' | 'noMatch';
    reason?: string;
    message?: string;
    predictedSeries?: 'diplomatic' | 'numerical';
  };
  neighbours: {
    documents: SourcesNeighbour[];
    totalCount: number;
    basis?: string;
    emptyState?: 'noNeighbors' | 'subjectNumericNoNeighbors' | 'subjectNumericUnkeyed' | 'unmatched';
    matchKey?: string;
  };
  collection?: { id: string; name: string; volumeCount: number };
  unprinted?: { rows: UnprintedRow[]; footer: string };
}

export function sourceExplorerQuery(volumeId: string, documentId: string) {
  return queryOptions({
    queryKey: ['sources', volumeId, documentId],
    queryFn: ({ signal }) =>
      getJSON<SourceExplorer>(`/api/v1/volumes/${segment(volumeId)}/documents/${segment(documentId)}/sources`, undefined, signal),
    staleTime: 5 * 60_000,
    retry: false,
  });
}

/** A scope of the neighbours' picker. */
export type NeighbourScope = 'volume' | 'subseries' | 'all';

/** What an Archival Neighbors page lists: a document's neighbours, a Sources row's, a collection's or a class's. */
export interface NeighboursRequest {
  volumeId?: string;
  documentId?: string;
  year?: number;
  collection?: string;
  lotFile?: string;
  recordGroup?: string;
  series?: string;
  repository?: string;
  decimalClass?: string;
  jobNumber?: string;
  aliasLot?: string;
  aliasName?: string[];
  /** The authority's record whose lot and names the matcher tries when a Sources row's keys match nothing. */
  aliasCollection?: string;
  anchor?: string;
  scope?: NeighbourScope;
}

export interface ArchivalNeighbours {
  /** The scopes the picker offers, in its order; empty when it shows none. */
  scopes: NeighbourScope[];
  scope: NeighbourScope;
  anchorVolumeId?: string;
  documents: { volumeId: string; documentId: string; title: string; dateline?: string }[];
  totalCount: number;
  basis?: string;
}

/** The query string a request names, each value in the order the API reads them. */
export function neighboursParams(request: NeighboursRequest): URLSearchParams {
  const params = new URLSearchParams();
  for (const [name, value] of Object.entries(request)) {
    if (value === undefined || value === '') continue;
    if (Array.isArray(value)) for (const each of value) params.append(name, String(each));
    else params.set(name, String(value));
  }
  return params;
}

export function archivalNeighboursQuery(request: NeighboursRequest) {
  const params = neighboursParams(request);
  return queryOptions({
    queryKey: ['archivalNeighbours', params.toString()],
    queryFn: ({ signal }) => getJSON<ArchivalNeighbours>('/api/v1/archival-neighbors', params, signal),
    staleTime: 5 * 60_000,
    retry: false,
  });
}

/** One record of the collection authority, as the app's collection page shows it. */
export interface ArchivalCollection {
  id: string;
  name: string;
  repository?: string;
  recordGroup?: string;
  lotFileNorm?: string;
  aliases: string[];
  /** The documents of this server's index that cite it, and their volumes. */
  documentCount: number;
  volumeCount: number;
  /** The volumes across the series that cite it, each with the catalogue's title. */
  volumes: { volumeId: string; title?: string }[];
  children: { name: string; decimalClass?: string; volumeCount: number }[];
  /** How many rows each capped list shows before Show all, the kit's `CollectionRelations.previewRowCap`. */
  previewRowCap: number;
  /** The NARA Catalog link, where the central files do not mark the record's NAID as a mis-resolution. */
  catalog?: { url: string; naId?: string };
  /** Related Collections, best first; absent where the page shows no such section, empty where none is related. */
  related?: RelatedCollection[];
  /** Cited Over Time, where the citing volumes reach two or more coverage eras. */
  timeline?: { eras: CoverageEra[]; narrative: string };
  /** Divided at NARA, where NARA divided the record's lot across several series. */
  divided?: {
    claimants: LotClaimant[];
    /** Whether the record's own NAID, the catalogue link's, is one of them. */
    includesRecordsNAID: boolean;
    /** How many lots the bundled index lists, each claimed by more than one series. */
    dividedLots: number;
  };
  /** Pointed At, Not Printed, where editors' footnotes point at unprinted material in the record. */
  pointers?: { total: number; volumes: { volumeId: string; title?: string; count: number }[] };
}

/** A collection cited alongside another in the same volumes' source lists (`RelatedCollection`). */
export interface RelatedCollection {
  id: string;
  name: string;
  repository?: string;
  recordGroup?: string;
  /** The volumes that cite both. */
  sharedVolumeCount: number;
  /** The overlap coefficient the list is ranked by, in 0 to 1. */
  overlap: number;
}

/** A coverage era's count of citing volumes (`CollectionEraCount`), with the era's two labels. */
export interface CoverageEra {
  /** The axis's form, ’61–63. */
  shortLabel: string;
  /** The prose and the table's form, 1961–1963. */
  fullLabel: string;
  volumeCount: number;
}

/** A NARA series that claims a lot NARA divided (`LotClaimant`). */
export interface LotClaimant {
  naId: string;
  title: string;
  recordGroup?: string;
  entryNumbers?: string[];
  dateRange?: string;
  catalogURL?: string;
}

export function archivalCollectionQuery(id: string) {
  return queryOptions({
    queryKey: ['archivalCollection', id],
    queryFn: ({ signal }) => getJSON<ArchivalCollection>('/api/v1/archival-collection', new URLSearchParams({ id }), signal),
    staleTime: 5 * 60_000,
    retry: false,
  });
}

/** One row of a volume's Sources section (`VolumeSourceEntry`), with what the app's view draws for it. */
export interface OutlineRow {
  /** About These Sources, Archival Collections or Published Sources. */
  kind: 'prose' | 'item' | 'bibliography';
  /** An outline row's depth, 0 for a top-level collection. */
  depth: number;
  /** A major named collection, which the view sets in bold. */
  isHeading: boolean;
  text: string;
  /** The editors' description of an outline row's collection, where the volume writes it apart. */
  note?: string;
  /** The catalogue record an outline row resolves to. */
  catalogURL?: string;
  /** The file series the resolved record sits in, when the record is a file unit. */
  seriesTitle?: string;
  /** The resolved record's HMS/MLR entry numbers, or, where it carries none, its series'. */
  entryNumbers?: string[];
  seriesEntryNumbers?: string[];
  /** The Archival Neighbors button, for a row with a key the neighbour queries match on. */
  neighbours?: OutlineNeighbours;
  /** The collection authority's record the row resolves to, which its Collection link opens. */
  collection?: { id: string; volumeCount: number };
  /** The volumes citing a heading the authority has no record for, where more than one does. */
  crossVolume?: { volumeId: string; title?: string }[];
  /** How many series NARA divides the row's lot across, where the row resolves to no catalogue record. */
  dividedSeriesCount?: number;
}

/** A Sources row's Archival Neighbors button (`VolumeSourceNeighborsTarget`): its keys and its count. */
export interface OutlineNeighbours {
  lotFile?: string;
  recordGroup?: string;
  series?: string;
  repository?: string;
  decimalClass?: string;
  jobNumber?: string;
  /** The record whose lot and names the neighbours' matcher tries when the row's own keys match nothing. */
  aliasCollection?: string;
  /** The indexed documents the row's keys match; absent while unknown, when the button is drawn plain. */
  count?: number;
}

/** A volume's Sources section, as the app's `VolumeSourcesView` lists it: its rows in the volume's order. */
export interface VolumeSourcesOutline {
  volumeId: string;
  rows: OutlineRow[];
}

export function volumeSourcesQuery(volumeId: string) {
  return queryOptions({
    queryKey: ['volumeSources', volumeId],
    queryFn: ({ signal }) => getJSON<VolumeSourcesOutline>(`/api/v1/volumes/${segment(volumeId)}/sources`, undefined, signal),
    staleTime: 5 * 60_000,
    retry: false,
  });
}
