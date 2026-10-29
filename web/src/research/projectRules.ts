// Project Home's and the project picker's rules (PLAN's S17f), the app's, mirrored: the header's date
// focus (`ProjectHomeView.dateFocusText`), the "Working on:" line's question
// (`WorkingOnBanner.resolvedQuestion`), and a lead's context line (`leadContext`). ProjectHistoryParityTests
// holds them to the app's source.
import { copy } from '../copy';
import type { ProjectLead } from '../api/research';
import type { Project } from '../api/types';

/** A date's year in this browser's calendar and time zone, as the app reads one in the device's. */
function year(date: string | undefined): number | undefined {
  if (!date) return undefined;
  const time = new Date(date);
  return Number.isNaN(time.getTime()) ? undefined : time.getFullYear();
}

/** The header's date focus from the project's range: "1969–1973", "From 1969" or "Through 1973", or none. */
export function dateFocusText(project: Pick<Project, 'defaultDateRangeStart' | 'defaultDateRangeEnd'>): string | undefined {
  const start = year(project.defaultDateRangeStart);
  const end = year(project.defaultDateRangeEnd);
  if (start !== undefined && end !== undefined) return `${start}–${end}`;
  if (start !== undefined) return copy.projectHome.dateFrom(start);
  if (end !== undefined) return copy.projectHome.dateTo(end);
  return undefined;
}

/** `trimmingCharacters(in: .whitespacesAndNewlines)`. */
const whitespacesAndNewlines = /^[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+|[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+$/gu;

/** A research question as the app saves and shows one: trimmed of its whitespaces and newlines. */
export function trimmedQuestion(text: string): string {
  return text.replace(whitespacesAndNewlines, '');
}

/**
 * The question "Working on:" shows: the active project's research question, trimmed, or none for
 * Global Context, a project the list no longer holds, or a question that is empty.
 */
export function workingOnQuestion(activeProjectId: string | undefined, projects: readonly Project[]): string | undefined {
  if (!activeProjectId) return undefined;
  const project = projects.find((item) => item.id.toUpperCase() === activeProjectId.toUpperCase());
  const question = trimmedQuestion(project?.researchQuestion ?? '');
  return question === '' ? undefined : question;
}

/** "Related to N of your documents", and "· Editorial note" for one. */
export function leadContext(lead: Pick<ProjectLead, 'relatedCount' | 'isEditorialNote'>): string {
  const related = lead.relatedCount === 1 ? copy.projectHome.relatedOne : copy.projectHome.relatedMany(lead.relatedCount);
  return lead.isEditorialNote ? `${related} · ${copy.projectHome.editorialNote}` : related;
}
