// A search, as the app's URL holds it: the API's own parameter names, defaults left out.
import type { FormValue } from '../api/form';
import type { DocumentType } from '../api/types';

export interface SearchState {
  /** The search box's text, exactly as typed; absent until a search is made. */
  keywords?: string;
  /** Absent for every type of document. */
  documentType?: Exclude<DocumentType, 'all'>;
  dateRangeEarliest?: string;
  dateRangeLatest?: string;
  /** Absent, front matter included; false leaves it out. */
  includeFrontMatter?: false;
  volumeIds?: string[];
  /** Absent for the default page size. */
  limit?: number;
  /** Absent for the first page. */
  offset?: number;
}

export const pageSizes = [10, 20, 50, 100] as const;
export const defaultLimit = 20;
/** How many of a search's results the Mac keeps, and so how far the pages reach. */
export const retainedLimit = 7_500;
export const documentTypes: readonly DocumentType[] = ['all', 'documentsOnly', 'editorialNotesOnly'];

const isoDate = /^\d{4}-\d{2}-\d{2}$/;

function single(value: unknown): string | undefined {
  if (typeof value === 'string') return value;
  if (Array.isArray(value) && typeof value[0] === 'string') return value[0];
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return undefined;
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
  const volumes = (Array.isArray(raw.volumeIds) ? raw.volumeIds : [raw.volumeIds]).filter(
    (volume): volume is string => typeof volume === 'string' && volume !== '',
  );
  const rawLimit = Number(single(raw.limit));
  const limit = (pageSizes as readonly number[]).includes(rawLimit) && rawLimit !== defaultLimit ? rawLimit : undefined;
  const offset = clampOffset(Number(single(raw.offset)), limit ?? defaultLimit);
  return {
    keywords,
    documentType: type === 'documentsOnly' || type === 'editorialNotesOnly' ? type : undefined,
    dateRangeEarliest: earliest && isoDate.test(earliest) ? earliest : undefined,
    dateRangeLatest: latest && isoDate.test(latest) ? latest : undefined,
    includeFrontMatter: single(raw.includeFrontMatter) === 'false' ? false : undefined,
    volumeIds: volumes.length > 0 ? volumes : undefined,
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

/** The API's fields for a search: an empty volume list and absent dates are left out. */
export function searchFields(state: SearchState): Record<string, FormValue> {
  return {
    keywords: state.keywords,
    documentType: state.documentType,
    dateRangeEarliest: state.dateRangeEarliest,
    dateRangeLatest: state.dateRangeLatest,
    includeFrontMatter: state.includeFrontMatter,
    volumeIds: state.volumeIds && state.volumeIds.length > 0 ? state.volumeIds : undefined,
    limit: state.limit ?? defaultLimit,
    offset: state.offset ?? 0,
  };
}

/** How many pages a search's count gives, within the results it keeps. */
export function pageCount(total: number, limit: number): number {
  return Math.max(1, Math.ceil(Math.min(total, retainedLimit) / limit));
}
