// The few lines of the app's `ResearchView` that the Research page (PLAN's S19b) mirrors in the
// browser app: a category's key, as `ResearchSidebarItem.rowAccessibilityIdentifier` names its row; a
// list's title, as `listTitle(for:)` gives it; and what a list says of no documents. The groups, their
// counts and their rows are the server's (`Research.swift`), the kit's aggregation and the view's lines
// mirrored there. FRUSParityTests' ResearchPageParityTests reads this file and the pinned source, and
// holds each to the other.
import type { HighlightColor } from '../api/types';
import { highlightColors } from '../api/types';
import { copy } from '../copy';

/** A category whose documents the page lists, or Changed by an update, which waits for phase 3. */
export type ResearchGroup =
  | { kind: 'allAnnotated' }
  | { kind: 'hasNotes' }
  | { kind: 'updated' }
  | { kind: 'tag'; id: string }
  | { kind: 'collection'; id: string }
  | { kind: 'highlightColor'; color: HighlightColor };

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The category a key names, as the app's row identifiers spell them, or none for any other text. */
export function parseGroup(key: string): ResearchGroup | undefined {
  if (key === 'allAnnotated' || key === 'hasNotes' || key === 'updated') return { kind: key };
  const dot = key.indexOf('.');
  if (dot < 0) return undefined;
  const [kind, rest] = [key.slice(0, dot), key.slice(dot + 1)];
  if ((kind === 'tag' || kind === 'collection') && uuid.test(rest)) return { kind, id: rest };
  if (kind === 'highlightColor') {
    const color = highlightColors.find((name) => name === rest);
    if (color) return { kind, color };
  }
  return undefined;
}

/** A category's key: `allAnnotated`, `tag.{id}` and the rest. */
export function groupKey(group: ResearchGroup): string {
  switch (group.kind) {
    case 'tag':
    case 'collection':
      return `${group.kind}.${group.id}`;
    case 'highlightColor':
      return `highlightColor.${group.color}`;
    default:
      return group.kind;
  }
}

/** Whether two keys name one category, an id in either case. */
export function sameGroup(a: string, b: string): boolean {
  return a.toUpperCase() === b.toUpperCase();
}

/**
 * A list's title, as `listTitle(for:)` gives it: a tag's name, or Tag for one the user has none of; the
 * name a collection's row prints; and a colour's name before Highlights. `name` is the tag's or the
 * collection's, once known.
 */
export function listTitle(group: ResearchGroup, name: string | undefined): string | undefined {
  switch (group.kind) {
    case 'allAnnotated':
      return copy.researchPage.allAnnotated;
    case 'hasNotes':
      return copy.researchPage.hasNotes;
    case 'tag':
      return name ?? copy.researchPage.unknownTag;
    case 'collection':
      return name;
    case 'highlightColor':
      return copy.researchPage.highlightList(copy.highlights.colors[group.color]);
    case 'updated':
      return copy.researchPage.updated;
  }
}

/** What a category's list says of no documents, as the app's empty state describes it. */
export function emptyDescription(group: ResearchGroup): string {
  switch (group.kind) {
    case 'allAnnotated':
      return copy.researchPage.emptyAllAnnotated;
    case 'hasNotes':
      return copy.researchPage.emptyHasNotes;
    case 'tag':
      return copy.researchPage.emptyTag;
    case 'collection':
      return copy.researchPage.emptyCollection;
    case 'highlightColor':
      return copy.researchPage.emptyHighlight;
    case 'updated':
      return copy.researchPage.updatedWaits;
  }
}

/** How many highlights a row shows; "and N more" counts the rest. */
export const shownHighlights = 3;

/** The line under a row's highlights, "and N more", for a document with more than the row shows. */
export function moreHighlights(count: number): string | undefined {
  return count > shownHighlights ? copy.researchPage.moreHighlights(count - shownHighlights) : undefined;
}

/** Whether a row has its footer, of tags, notes or collections: its note count only past one, as the app's. */
export function hasFooter(row: { tags: readonly unknown[]; noteCount: number; collections: readonly unknown[] }): boolean {
  return row.tags.length > 0 || row.noteCount > 1 || row.collections.length > 0;
}
