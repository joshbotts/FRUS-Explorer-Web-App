// The note editor's rule for its question before work is lost, as the app's view model has had it since
// FRUS-Explorer#1941 (L19): whether leaving without saving would lose something the reader did here
// (`ResearchNoteEditorViewModel.hasChanges`), over what the editor opened with and what it holds now,
// the app's `opening` and `current`. FRUSParityTests' NoteViewParityTests reads this file and the
// app's source and holds each to the other.
import type { NoteRun } from '../api/types';
import { canonicalRuns } from '../editor/runs';

/** What the note editor holds that Save writes, as it opened and as it stands: the app's `Snapshot`, in the web's terms. */
export interface NoteSnapshot {
  /** The note's text. */
  text: string;
  /** Its formatting: the stored note's runs, or a formatted edit's; null for none, or for an edit typed with formatting off. */
  runs: readonly NoteRun[] | null;
  /** Whether the text was changed here, which is when Save writes the text and its formatting in place of the stored ones. */
  edited: boolean;
  /** Whether the note opened with formatting the server keeps as it is, which no runs say and any edit replaces. */
  formattingKept: boolean;
  userTagIds: readonly string[];
  projectIds: readonly string[];
  selectedSummaryIds: readonly string[];
}

/** The ids as a set, in any letter case, as the app compares its sets of UUIDs: a tag taken off and put back is no change. */
function sameIds(a: readonly string[], b: readonly string[]): boolean {
  const left = new Set(a.map((id) => id.toUpperCase()));
  const right = new Set(b.map((id) => id.toUpperCase()));
  return left.size === right.size && [...left].every((id) => right.has(id));
}

/** Whether two formattings are one: none and none, or the same runs, in their canonical form. */
function sameRuns(a: readonly NoteRun[] | null, b: readonly NoteRun[] | null): boolean {
  if (a === null || b === null) return a === b;
  const left = canonicalRuns(a);
  const right = canonicalRuns(b);
  return (
    left.length === right.length &&
    left.every((run, index) => {
      const other = right[index]!;
      return (
        run.text === other.text &&
        run.bold === other.bold &&
        run.italic === other.italic &&
        run.underline === other.underline &&
        run.colorHex === other.colorHex &&
        run.linkURL === other.linkURL
      );
    })
  );
}

/**
 * `hasChanges`: the text, the projects, the tags and the inserted summaries against what the editor opened with, and the
 * formatting only while there is text to carry it. The app compares the formatted copy Save would store, which its
 * editor writes afresh at each edit; the web's Save stores formatting only for an edit, as its runs or, typed with
 * formatting off, as none, so the formatting counts where an edit's is another than the note opened with, or replaces
 * formatting the server keeps as it is.
 */
export function holdsChanges(opening: NoteSnapshot, current: NoteSnapshot): boolean {
  if (
    current.text !== opening.text ||
    !sameIds(current.projectIds, opening.projectIds) ||
    !sameIds(current.userTagIds, opening.userTagIds) ||
    !sameIds(current.selectedSummaryIds, opening.selectedSummaryIds)
  ) {
    return true;
  }
  return current.text !== '' && current.edited && (opening.formattingKept || !sameRuns(current.runs, opening.runs));
}
