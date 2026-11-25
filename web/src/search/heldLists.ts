// Search Within These Results' held lists (S27e), kept in the browser's memory for the session, as the app holds a list
// for its session and saves none (the owner's decision 4): the search a list was found by, as the screen showed it; the
// rows Checklist Mode hid when it was held, which no layer searches; and the trail's anchor its own search left, which a
// layer sets aside and leaving gives back (the app's rule 5). The address names a list by its search alone (`within`), so
// that Back to a layer from a document it opened holds the list again, and so do a reload and a link, with no row hidden,
// as Checklist Mode has none then.
import type { SearchAnchor } from '../api/research';
import { formDecode, formEncode } from '../api/form';
import { filterFields, type SearchState, validateSearch } from './searchState';

/** A list held this session. */
export interface HeldList {
  /** The search the list was found by, as the screen showed it, which leaving shows again. */
  base: SearchState;
  /** The rows Checklist Mode hid when it was held, by `volumeId/documentId`, sorted. */
  reviewed: readonly string[];
  /** The trail's anchor of the list's own search, set aside while a layer runs. */
  anchor?: SearchAnchor;
  /** Whether a swap held it, before its search was seen to find anything. */
  fromSwap?: boolean;
  /** The digest of its members the server gave, which names it from then on, so that a list built again otherwise is refused. */
  members?: string;
}

const kept = new Map<string, HeldList>();

/** The address's name for a list held from `base`: its search's fields, its order, its engine and a browse's shown name. */
export function withinOf(base: SearchState): string {
  return formEncode({ ...filterFields(base), sort: base.sort, by: base.by, label: base.subjectLabel }).toString();
}

/**
 * Holds the list `base` shows, with the rows Checklist Mode hides now, and answers the address's name for it; `fromSwap`
 * for a swap's new list, which holds nothing if its search finds nothing, as the app's swap then ends.
 */
export function holdList(base: SearchState, reviewed: readonly string[], anchor?: SearchAnchor, fromSwap = false): string {
  const within = withinOf(base);
  kept.set(within, { base: { ...base, offset: undefined }, reviewed: [...reviewed].sort(), anchor, fromSwap });
  return within;
}

/** The list the address names: as held this session, or from its name alone, with no row hidden. */
export function heldList(within: string): HeldList {
  const held = kept.get(within);
  if (held) return held;
  const raw: Record<string, unknown> = {};
  for (const [name, values] of formDecode(within)) raw[name] = values.length === 1 ? values[0] : values;
  const base = validateSearch({ ...raw, subjectLabel: raw.label });
  return { base: { ...base, keywords: base.keywords ?? '' }, reviewed: [] };
}

/** What a held list's answers are kept by: its name, with the rows its checklist hid. */
export function withinKey(within: string | undefined): string | undefined {
  if (within === undefined) return undefined;
  const { reviewed } = heldList(within);
  return reviewed.length > 0 ? `${within}&${formEncode({ reviewed }).toString()}` : within;
}

/** What the server reads a held list by (`within`): its key, with the digest of its members once the server has given it. */
export function withinField(within: string | undefined): string | undefined {
  const key = withinKey(within);
  if (within === undefined || key === undefined) return undefined;
  const { members } = heldList(within);
  return members !== undefined ? `${key}&${formEncode({ members }).toString()}` : key;
}

/** Keeps the digest of the held list's members, the first time the server gives it. */
export function keepMembers(within: string, members: string): void {
  const held = kept.get(within);
  if (held && held.members === undefined) kept.set(within, { ...held, members });
}

/** Keeps `anchor` as the trail's anchor of the held list's own search, as a swap learns it once its new list is recorded. */
export function keepAnchor(within: string, anchor: SearchAnchor | undefined): void {
  const held = kept.get(within);
  if (held) kept.set(within, { ...held, anchor });
}

/** Forgets every list held, for tests. */
export function resetHeldLists(): void {
  kept.clear();
}
