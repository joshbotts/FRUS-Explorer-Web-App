// The user's tags in a search, as the Mac's search window names them (S17d): a result row's chips,
// `UserTag.chips(for:among:)`, one for each id the user's tags name, in the row's order, each once,
// of which the row draws three (`SearchResultRow`); and the Tags token's value, `tagFilterLabel`.
// App code, mirrored here and held to the app's source by FRUSParityTests' SearchViewParityTests.
import type { UserTag } from '../api/types';
import { copy } from '../copy';

/** A tag's id with its ASCII letters in upper case: the kit reads a row's ids so, and matches a filter's in any case. */
export function caseFolded(id: string): string {
  return id.replace(/[a-z]/g, (letter) => letter.toUpperCase());
}

/**
 * The chips a row shows for `tagIds`, the ids the kit gives it: one for each id `tags` names, in the
 * row's order, each once. An id no tag names gets no chip, as the Mac's row gives none (#1591).
 */
export function tagChips(tagIds: readonly string[], tags: readonly UserTag[]): UserTag[] {
  const byId = new Map(tags.map((tag) => [caseFolded(tag.id), tag]));
  const seen = new Set<string>();
  const chips: UserTag[] = [];
  for (const id of tagIds) {
    const key = caseFolded(id);
    const tag = byId.get(key);
    if (tag === undefined || seen.has(key)) continue;
    seen.add(key);
    chips.push(tag);
  }
  return chips;
}

/** How many chips a row draws, as the Mac's draws `chips.prefix(3)`. */
export const rowChipLimit = 3;

/**
 * The Tags token's value, as the Mac's `tagFilterLabel` gives it: one tag by its name, or "1 tag"
 * while the list does not name it, and several by how many.
 */
export function tagFilterLabel(tagIds: readonly string[], tags: readonly UserTag[] | undefined): string {
  const [only] = tagIds;
  if (tagIds.length !== 1 || only === undefined) return copy.search.tagsToken.count(tagIds.length);
  const key = caseFolded(only);
  return tags?.find((tag) => caseFolded(tag.id) === key)?.name ?? copy.search.tagsToken.unresolved;
}
