// The few lines of the app's view code that the browser app's notes mirror (PLAN's S15d, and its
// rule for view code: "mirrored with a parity test that reads the app's source at the pin"), until
// S17b moves All Notes' rules into the kit. FRUSParityTests' NoteViewParityTests reads this file and
// the app's source, and holds each to the other: All Notes' rows and filters to `NotesPaneSnapshot`
// and `AllNotesScreen`, and the rail's note rows and summary preview to `ResearchRailView`. A
// character is a grapheme, as a Swift `Character` is, and lines and spaces are Foundation's sets.
import type { NoteSummary } from '../api/types';
import { copy } from '../copy';

/** `CharacterSet.newlines`, which `components(separatedBy: .newlines)` splits on; a CRLF is one break. */
const newlines = /\r\n|[\n\v\f\r\u{0085}\u{2028}\u{2029}]/u;
/** `trimmingCharacters(in: .whitespaces)`: tabs and the space separators. */
const whitespaces = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;
/** `trimmingCharacters(in: .whitespacesAndNewlines)`. */
const whitespacesAndNewlines = /^[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+|[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+$/gu;

const segmenter = new Intl.Segmenter('en-US', { granularity: 'grapheme' });

/** A text's characters, as Swift counts them. */
function graphemes(text: string): string[] {
  return Array.from(segmenter.segment(text), (part) => part.segment);
}

/** `NotesPaneSnapshot.Row.titleLimit`: how many characters of the first line a row shows. */
export const titleLimit = 90;

/**
 * A row's title, as `NotesPaneSnapshot.Row.title`: the note's first line with anything in it,
 * trimmed, cut at 90 characters, trimmed again and ended with "…"; else Empty note.
 */
export function noteTitle(bodyText: string): string {
  const firstLine = bodyText
    .split(newlines)
    .map((line) => line.replace(whitespaces, ''))
    .find((line) => line !== '') ?? '';
  if (firstLine === '') return copy.allNotes.emptyNote;
  const characters = graphemes(firstLine);
  if (characters.length <= titleLimit) return firstLine;
  return characters.slice(0, titleLimit).join('').replace(whitespaces, '') + '…';
}

/**
 * A row's second line, as `NotesPaneSnapshot.Row.detail`: where the note is, then its projects'
 * names and its tags', in the order the note holds their ids, an id with no name left out.
 */
export function noteDetail(note: NoteSummary, projectNames: ReadonlyMap<string, string>, tagNames: ReadonlyMap<string, string>): string {
  const named = (ids: readonly string[], names: ReadonlyMap<string, string>) =>
    ids.flatMap((id) => {
      const name = names.get(id.toUpperCase());
      return name === undefined ? [] : [name];
    });
  return [`${note.volumeId} / ${note.documentId}`, ...named(note.projectIds, projectNames), ...named(note.userTagIds, tagNames)].join(' · ');
}

const abbreviated = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

/** A row's date, `formatted(date: .abbreviated, time: .omitted)`, as "Oct 24, 2026"; none without one. */
export function noteDate(lastModified: string | null | undefined): string | null {
  if (!lastModified) return null;
  const date = new Date(lastModified);
  return Number.isNaN(date.getTime()) ? null : abbreviated.format(date);
}

/** All Notes' filters: a project's id or `unfiled`, a tag's id, and the search field's text. */
export interface NotesFilter {
  project?: string;
  tag?: string;
  query?: string;
}

/**
 * The rows `AllNotesScreen` shows: those in the project, where Not in a project is a note with no
 * project id at all, so one whose only project is gone is in neither; carrying the tag; and holding
 * the search field's text, trimmed of spaces and tabs, in its text, its volume's id or its document's,
 * whatever the case, and an accent typed as one character or as a letter and a mark alike, as
 * Foundation's search without `.literal` takes them.
 */
export function filterNotes(notes: readonly NoteSummary[], filter: NotesFilter): NoteSummary[] {
  const project = filter.project?.toUpperCase();
  const tag = filter.tag?.toUpperCase();
  const fold = (text: string) => text.normalize('NFC').toLocaleLowerCase('en-US');
  const query = fold((filter.query ?? '').replace(whitespaces, ''));
  const holds = (text: string) => fold(text).includes(query);
  return notes.filter((note) => {
    const inProject =
      project === undefined ||
      (project === 'UNFILED' ? note.projectIds.length === 0 : note.projectIds.some((id) => id.toUpperCase() === project));
    const tagged = tag === undefined || note.userTagIds.some((id) => id.toUpperCase() === tag);
    const found = query === '' || holds(note.bodyText) || holds(note.volumeId) || holds(note.documentId);
    return inProject && tagged && found;
  });
}

/** "1 note" or "1,204 notes", the app's `ResearchItemCounts.notesPhrase`, its number grouped. */
export function noteCount(count: number): string {
  const grouped = count.toLocaleString('en-US');
  return count === 1 ? copy.allNotes.noteOne(grouped) : copy.allNotes.noteMany(grouped);
}

/** The count line, `NotesPaneSnapshot.showingCount`: of every note, when the filters show fewer. */
export function countLine(shown: number, total: number): string {
  return shown < total ? copy.allNotes.showing(shown, noteCount(total)) : noteCount(total);
}

/** A rail row's text, as the app's: the note's text as it is, or Empty note when it has none at all. */
export function railText(bodyText: string): string {
  return bodyText === '' ? copy.notes.emptyNote : bodyText;
}

/** The Summary section's header when it is closed: the summary shown, trimmed, its first 80 characters and "…". */
export function summaryPreview(responseText: string): string {
  return graphemes(responseText.replace(whitespacesAndNewlines, '')).slice(0, 80).join('') + '…';
}

const units = [
  ['year', 365 * 86_400],
  ['month', 30 * 86_400],
  ['week', 7 * 86_400],
  ['day', 86_400],
  ['hour', 3_600],
  ['minute', 60],
  ['second', 1],
] as const;

/**
 * The time since a note changed, in its two largest units, "2 hours, 23 minutes", the web's own
 * reading of the app's relative time; a note with no time reads as changed now, as the app's.
 */
export function timeSince(lastModified: string | null | undefined, now: number): string {
  const then = lastModified ? new Date(lastModified).getTime() : now;
  const seconds = Math.floor(Math.abs(now - (Number.isNaN(then) ? now : then)) / 1000);
  const largest = units.findIndex(([, size]) => seconds >= size);
  if (largest < 0) return copy.notes.elapsed([copy.notes.unit(0, 'second')]);
  const [unit, size] = units[largest]!;
  const count = Math.floor(seconds / size);
  const parts = [copy.notes.unit(count, unit)];
  // The next unit down, unless there is none of it.
  const next = units[largest + 1];
  const more = next ? Math.floor((seconds - count * size) / next[1]) : 0;
  if (next && more > 0) parts.push(copy.notes.unit(more, next[0]));
  return copy.notes.elapsed(parts);
}
