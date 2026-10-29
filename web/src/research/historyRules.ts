// The History screen's rules (PLAN's S17f), the app's `HistoryPaneSnapshot`, mirrored: its search
// field narrows the page loaded, a visit by its title and both its ids, a search by its text with the
// kit's typographic double quotation marks read as U+0022 on both sides, an export by its title and
// both spellings of its format, each as Foundation's `localizedStandardContains` reads it, whatever the
// case and the accents; and "Showing N of M" over a section when the page holds less than the scope.
// ProjectHistoryParityTests holds it to the app's and the kit's source.
import { copy } from '../copy';
import type { DocumentVisit, ExportRecord, SearchRun } from '../api/research';

/**
 * The marks the kit's `FTS5InlineQueryParser.normalizingQuotationMarks(_:)` folds to U+0022: “ ” „ ‟
 * ＂ « », and no other.
 */
export const typographicDoubleQuotationMarks = ['\u201C', '\u201D', '\u201E', '\u201F', '\uFF02', '\u00AB', '\u00BB'];

/** `text` with each of those marks as U+0022, one for one. */
export function normalizingQuotationMarks(text: string): string {
  let folded = text;
  for (const mark of typographicDoubleQuotationMarks) folded = folded.split(mark).join('"');
  return folded;
}

/** Text as `localizedStandardContains` compares it: no case, and no accent. */
function fold(text: string): string {
  return text.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase('en-US');
}

function holds(text: string, term: string): boolean {
  return fold(text).includes(fold(term));
}

/** `trimmingCharacters(in: .whitespaces)`: the tab and every space separator. */
const whitespaces = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;

/** The term the search field gives, trimmed of its whitespaces; an empty one matches every row. */
function trimmed(term: string): string {
  return term.replace(whitespaces, '');
}

/** Whether the screen narrows its rows, a project chosen or a term typed (`HistoryView.isFiltering`). */
export function isFiltering(scope: string, query: string): boolean {
  return scope !== 'all' || trimmed(query) !== '';
}

export function visitMatches(row: DocumentVisit, raw: string): boolean {
  const term = trimmed(raw);
  return term === '' || holds(row.title, term) || holds(row.volumeId, term) || holds(row.documentId, term);
}

export function searchMatches(row: SearchRun, raw: string): boolean {
  const term = trimmed(raw);
  return term === '' || holds(normalizingQuotationMarks(row.queryText), normalizingQuotationMarks(term));
}

export function exportMatches(row: ExportRecord, raw: string): boolean {
  const term = trimmed(raw);
  return term === '' || holds(row.title, term) || holds(row.format, term) || holds(row.formatName, term);
}

/** "Showing 500 of 12,904", or nothing when the page is everything (`HistoryPaneSnapshot.showingCount`). */
export function showingCount(shown: number, total: number): string | undefined {
  return shown < total ? copy.history.showing(shown, total) : undefined;
}
