// The focus subjects editor's rules (PLAN's S25c), the app's `ProjectFocusSubjectsEditor`, mirrored:
// its Focus subjects, the vocabulary's subjects the project chose, in the vocabulary's order, which
// is Project Home's filter too (`ProjectHomeView.focusSubjectsSection`); when Suggested from your
// volumes shows; All subjects under the search field (`filteredSubjects`); a row's two captions; and
// the toggle, which saves the whole list. ProjectHistoryParityTests holds them to the app's source.
import { copy } from '../copy';
import type { FocusSubject } from '../api/research';

/** How many subjects All subjects lists while nothing is searched for, so that it never draws the vocabulary whole. */
export const unsearchedSubjectLimit = 50;

/** `trimmingCharacters(in: .whitespaces)`. */
const whitespaces = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;

/** The subjects `chosen` names, in the vocabulary's order; a ref the vocabulary does not name shows nothing. */
export function chosenSubjects(subjects: readonly FocusSubject[], chosen: readonly string[]): FocusSubject[] {
  return subjects.filter((subject) => chosen.includes(subject.ref));
}

/** Whether Suggested from your volumes shows: while the search field holds nothing at all, and something is suggested. */
export function showsSuggestions(search: string, suggestions: readonly FocusSubject[]): boolean {
  return search === '' && suggestions.length > 0;
}

/**
 * All subjects' rows: the vocabulary's first fifty while the search field, trimmed, is empty; else
 * every subject whose name, category or subcategory holds the words, whatever their case.
 */
export function filteredSubjects(subjects: readonly FocusSubject[], search: string): FocusSubject[] {
  const query = search.replace(whitespaces, '').toLowerCase();
  if (query === '') return subjects.slice(0, unsearchedSubjectLimit);
  return subjects.filter(
    (subject) =>
      subject.name.toLowerCase().includes(query) ||
      subject.category.toLowerCase().includes(query) ||
      subject.subcategory.toLowerCase().includes(query),
  );
}

/** A row's second line, "category · subcategory". */
export function subjectKind(subject: Pick<FocusSubject, 'category' | 'subcategory'>): string {
  return `${subject.category} · ${subject.subcategory}`;
}

/** A row's reach, "1 volume" or "N volumes". */
export function subjectReach(subject: Pick<FocusSubject, 'volumeCount'>): string {
  return subject.volumeCount === 1 ? copy.projectHome.volumeCountOne : copy.projectHome.volumeCountOther(subject.volumeCount);
}

/** The project's refs after a row's toggle: without `ref` where they held it, else with it at their end. */
export function toggledSubjects(refs: readonly string[], ref: string): string[] {
  const index = refs.indexOf(ref);
  return index >= 0 ? [...refs.slice(0, index), ...refs.slice(index + 1)] : [...refs, ref];
}
