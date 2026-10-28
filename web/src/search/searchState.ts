// A search, as the app's URL holds it: the API's own parameter names, defaults left out, and the
// app's own, which the API never sees: whether the facet panel is open, a subject filter's name, and
// the reading the results are shown in, with the timeline's mode and the concordance's order, so
// Back to a search from a document it opened shows it as it was, as the Mac's window stays. Since
// S17d it holds Search in, the three scopes the Mac's chips choose, and the user's tags it filters by;
// since S17e the working corpus it runs inside, and the phrase, prefix and excluded terms a recalled
// saved search can carry, which the Mac's Advanced fields set.
import type { FormValue } from '../api/form';
import type { ConcordanceOrder, DocumentType, SearchChange, SortOrder } from '../api/types';

export interface SearchState {
  /** The search box's text, exactly as typed; absent until a search is made. */
  keywords?: string;
  /** A phrase, a prefix and terms left out, beside the box's text, as a recalled saved search can carry them. */
  phrase?: string;
  prefixWildcard?: string;
  excludedTerms?: string[];
  /** Absent for every type of document. */
  documentType?: Exclude<DocumentType, 'all'>;
  dateRangeEarliest?: string;
  dateRangeLatest?: string;
  /** Absent, front matter included; false leaves it out. */
  includeFrontMatter?: false;
  /** Search in, as the Mac's three chips choose it: absent, each is searched; false leaves it out. */
  includeDocumentText?: false;
  includeNotes?: false;
  includeSummaries?: false;
  /** The user's tags, every one of which a document must carry; absent for no tag filter. */
  userTagIds?: string[];
  /** The user's working corpus the search runs inside, by its id; absent for none. */
  workingCorpusId?: string;
  volumeIds?: string[];
  /** The years an Apply in the facet panel chose; the empty list matches nothing. */
  yearKeys?: string[];
  /** A person's rollup in the served index, as a People row narrows to it, and the name it shows. */
  personRollupId?: string;
  personLabel?: string;
  /** A subject's place in the subject vocabulary, and its durable name, as a Subjects row narrows to it. */
  subjectBucket?: string;
  subjectBucketKey?: string;
  /** The subject's name, kept from the row that set it, since the kit's vocabulary is internal. Not sent. */
  subjectLabel?: string;
  /** `facets` while the facet panel is open. Not sent. */
  panel?: 'facets';
  /** The reading the results are shown in, as the Mac's Reading picker chooses it; absent for the list. Not sent. */
  reading?: Exclude<Reading, 'list'>;
  /** `list` while the timeline shows its List mode; absent for its chart. Not sent. */
  timelineMode?: 'list';
  /** The concordance's order, the kit's KWICSort, as its Align by chooses it; absent for the left context. Not sent. */
  align?: Exclude<ConcordanceOrder, 'leftContext'>;
  /** The order the results are paged in; absent by relevance. */
  sort?: Exclude<SortOrder, 'relevance'>;
  /** Absent for the default page size. */
  limit?: number;
  /** Absent for the first page. */
  offset?: number;
}

/**
 * The ways the results can be read, in the order of the Mac's Reading picker (`ResultReading`): the
 * list, the timeline, and the concordance. Collocates, the Mac's fourth, arrive in phase 4.
 */
export const readings = ['list', 'timeline', 'concordance'] as const;
export type Reading = (typeof readings)[number];

/**
 * Whether a reading shows one page of the results, and so pages with the pager, as the Mac's
 * `ResultReading.isPaged` has it: the list and the concordance do; the timeline covers every result
 * the search keeps.
 */
export function isPaged(reading: Reading): boolean {
  return reading !== 'timeline';
}

export const pageSizes = [10, 20, 50, 100] as const;
export const defaultLimit = 20;
/** How many of a search's results the Mac keeps, and so how far the pages reach. */
export const retainedLimit = 7_500;

/**
 * Whether what the app keeps of a search is only part of its match: the Mac's `isPartialEvidence`
 * for a keyword search, true once the match reaches the 7,500 results it keeps. A figure computed
 * over what was kept, rather than over the whole match, is then partly a statement about the
 * ranking that chose it.
 */
export function isPartialEvidence(total: number): boolean {
  return total >= retainedLimit;
}
export const documentTypes: readonly DocumentType[] = ['all', 'documentsOnly', 'editorialNotesOnly'];

const isoDate = /^\d{4}-\d{2}-\d{2}$/;
const uuid = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const year = /^\d{4}$/;
const wholeNumber = /^\d{1,10}$/;

function single(value: unknown): string | undefined {
  if (typeof value === 'string') return value;
  if (Array.isArray(value) && typeof value[0] === 'string') return value[0];
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return undefined;
}

function list(value: unknown): string[] {
  return (Array.isArray(value) ? value : [value]).filter((item): item is string => typeof item === 'string');
}

/**
 * The year filter: absent when the URL has none, the empty list for one empty value, which matches
 * nothing, and otherwise its years; a value that is no year is dropped, and a filter of nothing but
 * such values with it.
 */
function yearKeys(value: unknown): string[] | undefined {
  if (value === undefined) return undefined;
  const values = list(value);
  if (values.every((item) => item === '')) return [];
  const years = values.filter((item) => year.test(item));
  return years.length > 0 ? years : undefined;
}

function number(value: unknown): string | undefined {
  const text = single(value);
  return text !== undefined && wholeNumber.test(text) ? text : undefined;
}

/**
 * A search from the URL's raw fields, every value checked; what does not fit is dropped. Every
 * field is returned, undefined when dropped, because the router lays the result over the raw
 * fields: a field left out would keep the URL's unchecked string.
 */
export function validateSearch(raw: Record<string, unknown>): SearchState {
  const keywords = single(raw.keywords);
  const type = single(raw.documentType);
  const earliest = single(raw.dateRangeEarliest);
  const latest = single(raw.dateRangeLatest);
  const volumes = list(raw.volumeIds).filter((volume) => volume !== '');
  const tags = [...new Set(list(raw.userTagIds).filter((tag) => tag !== ''))];
  const excluded = list(raw.excludedTerms).filter((term) => term !== '');
  const corpus = single(raw.workingCorpusId);
  const rawLimit = Number(single(raw.limit));
  const limit = (pageSizes as readonly number[]).includes(rawLimit) && rawLimit !== defaultLimit ? rawLimit : undefined;
  const offset = clampOffset(Number(single(raw.offset)), limit ?? defaultLimit);
  const personRollupId = number(raw.personRollupId);
  const subjectBucket = number(raw.subjectBucket);
  const subjectBucketKey = single(raw.subjectBucketKey) || undefined;
  const subject = subjectBucket !== undefined || subjectBucketKey !== undefined;
  const sort = single(raw.sort);
  const reading = single(raw.reading);
  const align = single(raw.align);
  return {
    keywords,
    phrase: single(raw.phrase) || undefined,
    prefixWildcard: single(raw.prefixWildcard) || undefined,
    excludedTerms: excluded.length > 0 ? excluded : undefined,
    documentType: type === 'documentsOnly' || type === 'editorialNotesOnly' ? type : undefined,
    dateRangeEarliest: earliest && isoDate.test(earliest) ? earliest : undefined,
    dateRangeLatest: latest && isoDate.test(latest) ? latest : undefined,
    includeFrontMatter: single(raw.includeFrontMatter) === 'false' ? false : undefined,
    includeDocumentText: single(raw.includeDocumentText) === 'false' ? false : undefined,
    includeNotes: single(raw.includeNotes) === 'false' ? false : undefined,
    includeSummaries: single(raw.includeSummaries) === 'false' ? false : undefined,
    userTagIds: tags.length > 0 ? tags : undefined,
    workingCorpusId: corpus && uuid.test(corpus) ? corpus.toUpperCase() : undefined,
    volumeIds: volumes.length > 0 ? volumes : undefined,
    yearKeys: yearKeys(raw.yearKeys),
    personRollupId,
    personLabel: personRollupId !== undefined ? single(raw.personLabel) || undefined : undefined,
    subjectBucket,
    subjectBucketKey,
    subjectLabel: subject ? single(raw.subjectLabel) || undefined : undefined,
    panel: single(raw.panel) === 'facets' ? 'facets' : undefined,
    reading: reading === 'timeline' || reading === 'concordance' ? reading : undefined,
    timelineMode: single(raw.timelineMode) === 'list' ? 'list' : undefined,
    align: align === 'rightContext' || align === 'date' || align === 'volume' ? align : undefined,
    sort: sort === 'dateAscending' || sort === 'dateDescending' ? sort : undefined,
    limit,
    offset: offset > 0 ? offset : undefined,
  };
}

/** An offset on a page boundary, within the results a search keeps. */
export function clampOffset(offset: number, limit: number): number {
  if (!Number.isFinite(offset) || offset <= 0) return 0;
  const last = retainedLimit - limit;
  return Math.min(Math.floor(offset / limit) * limit, last);
}

/**
 * The API's fields for what a search matches, without its page: an empty volume list and absent
 * dates are left out, and an empty year list is kept, since it matches nothing.
 */
export function filterFields(state: SearchState): Record<string, FormValue> {
  return {
    keywords: state.keywords,
    phrase: state.phrase,
    prefixWildcard: state.prefixWildcard,
    excludedTerms: state.excludedTerms && state.excludedTerms.length > 0 ? state.excludedTerms : undefined,
    documentType: state.documentType,
    dateRangeEarliest: state.dateRangeEarliest,
    dateRangeLatest: state.dateRangeLatest,
    includeFrontMatter: state.includeFrontMatter,
    includeDocumentText: state.includeDocumentText,
    includeNotes: state.includeNotes,
    includeSummaries: state.includeSummaries,
    userTagIds: state.userTagIds && state.userTagIds.length > 0 ? state.userTagIds : undefined,
    workingCorpusId: state.workingCorpusId,
    volumeIds: state.volumeIds && state.volumeIds.length > 0 ? state.volumeIds : undefined,
    yearKeys: state.yearKeys,
    personRollupId: state.personRollupId,
    personLabel: state.personLabel,
    subjectBucket: state.subjectBucket,
    subjectBucketKey: state.subjectBucketKey,
  };
}

/** The API's fields for a search and its page, in the order chosen. */
export function searchFields(state: SearchState): Record<string, FormValue> {
  return { ...filterFields(state), sort: state.sort, limit: state.limit ?? defaultLimit, offset: state.offset ?? 0 };
}

/**
 * The search a change from the server makes of this one, as a facet narrows it: each field it
 * names set to its values, or left out for null, then checked as the URL's fields are. It starts at
 * its first page, keeps the order, the page size, the panel and the reading as it is shown, and keeps
 * the subject's name only while it has a subject.
 */
export function applySearchChange(state: SearchState, change: SearchChange): SearchState {
  const raw: Record<string, unknown> = {};
  for (const [name, value] of Object.entries(filterFields(state))) {
    if (value !== undefined) raw[name] = Array.isArray(value) ? (value.length > 0 ? value : ['']) : String(value);
  }
  for (const [name, values] of Object.entries(change)) {
    if (values === null) delete raw[name];
    else raw[name] = values;
  }
  raw.subjectLabel = state.subjectLabel;
  return {
    ...validateSearch(raw),
    panel: state.panel,
    reading: state.reading,
    timelineMode: state.timelineMode,
    align: state.align,
    sort: state.sort,
    limit: state.limit,
    offset: undefined,
  };
}

/** The three places Search in chooses among, as the Mac's chips name them, in their order. */
export const scopes = ['documents', 'notes', 'summaries'] as const;
export type Scope = (typeof scopes)[number];

const scopeField = { documents: 'includeDocumentText', notes: 'includeNotes', summaries: 'includeSummaries' } as const;

/** Whether the search reads `scope`, which it does unless the reader turned it off. */
export function searches(state: SearchState, scope: Scope): boolean {
  return state[scopeField[scope]] !== false;
}

/** The change that turns `scope` on or off: on is the default, which the URL leaves out. */
export function scopeChange(scope: Scope, on: boolean): Partial<SearchState> {
  return { [scopeField[scope]]: on ? undefined : false };
}

/**
 * Whether the search reads anywhere at all: with all three of Search in off there is nothing to
 * search, and the Mac's window says so rather than searching (`MacSearchError.emptyScope`).
 */
export function searchesAnywhere(state: SearchState): boolean {
  return scopes.some((scope) => searches(state, scope));
}

/** How many pages a search's count gives, within the results it keeps. */
export function pageCount(total: number, limit: number): number {
  return Math.max(1, Math.ceil(Math.min(total, retainedLimit) / limit));
}

/**
 * The search a saved search recalls, from its query fields, inside the working corpus applied now, as
 * the Mac's window runs a recalled search inside its applied corpus and under no gate of its own
 * (`SearchParameters.runningInside(workingCorpus:)`): it starts at its first page, keeps the order,
 * the page size and the reading shown, and closes the facet panel, as a new search does.
 */
export function recalledSearch(search: Record<string, string[]>, current: SearchState): SearchState {
  return {
    ...validateSearch(search),
    workingCorpusId: current.workingCorpusId,
    reading: current.reading,
    timelineMode: current.timelineMode,
    align: current.align,
    sort: current.sort,
    limit: current.limit,
    offset: undefined,
  };
}
