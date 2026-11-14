// The People screen's rules, the app's (`Browser/PersonIndexView.swift`, `Browser/PersonCorrectionsView.swift`,
// app code), mirrored: the list's filter, a row's spoken line, the merge picker's filter, and the merge's question
// with its warning when the two records match different entries of the name authority.
import type { PeopleList, PersonRow } from '../api/people';
import { copy } from '../copy';

/** `PersonIndexView.displaySections`: the rows whose name holds the query, case aside, by letter, empty letters left out. */
export function displaySections(list: PeopleList, query: string): PeopleList['sections'] {
  if (!query) return list.sections;
  const q = query.toLowerCase();
  return list.sections
    .map((section) => ({ letter: section.letter, people: section.people.filter((row) => row.name.toLowerCase().includes(q)) }))
    .filter((section) => section.people.length > 0);
}

/** `PersonIndexRow.accessibilityLabelText`: the name, the line, the mentions and the suggestion, one stop. */
export function rowLabel(row: PersonRow): string {
  const parts = [row.name];
  if (row.subtitle) parts.push(row.subtitle);
  if (row.mentionCount > 0) parts.push(copy.people.mentionCountSpoken(row.mentionCount));
  if (row.possibleDuplicate) parts.push(copy.people.possibleDuplicate);
  return parts.join(', ');
}

/**
 * The merge picker's line, the app's `PersonEntry.roleEraSubtitle` (`PersonMergePickerSheet`): the row's line without
 * the volume count `PersonIndexRow.subtitle` adds to it past one volume.
 */
export function roleEraLine(row: PersonRow): string | null {
  const line = row.subtitle ?? null;
  if (line == null || row.volumeCount <= 1) return line;
  const count = `${row.volumeCount} volumes`;
  if (line === count) return null;
  return line.endsWith(` · ${count}`) ? line.slice(0, line.length - count.length - 3) : line;
}

/** `PersonMergePickerSheet.filter`'s folding: case and diacritics aside. */
export function folded(text: string): string {
  return text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase();
}

/** `PersonMergePickerSheet`: every other identity, by the list's order, whose folded name holds the folded query. */
export function pickerRows(list: PeopleList, excluding: number, query: string): PersonRow[] {
  const rows = list.sections.flatMap((section) => section.people).filter((row) => row.rollupId !== excluding);
  if (!query) return rows;
  const q = folded(query);
  return rows.filter((row) => folded(row.name).includes(q));
}

/** `PersonIndexDetailSheet.mergeConfirmMessage`: both names, the transitive union, and the authorities' warning. */
export function mergeQuestion(target: { name: string; authorityId?: number | null }, current: { name: string; authorityId?: number | null }): string {
  let message = copy.people.mergeConfirmMessage(target.name, current.name);
  if (current.authorityId != null && target.authorityId != null && current.authorityId !== target.authorityId) {
    message += `\n\n${copy.people.mergeAuthorityWarning}`;
  }
  return message;
}

/** A correction's row, as the app's Corrections sheet titles it. */
export function correctionTitle(item: { kind: 'merge' | 'split'; nameA: string; nameB?: string | null }): string {
  return item.kind === 'merge' ? copy.people.correctionMerged(item.nameA, item.nameB ?? '') : copy.people.correctionSeparated(item.nameA);
}
