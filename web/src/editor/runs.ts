// A research note's formatting as the server sends and takes it (PLAN's S15d): runs, each a stretch
// of text with one formatting, as the app's `ProseFormattedSpan` reads its RTF, whose texts
// concatenated are the note's plain `bodyText`. The editor holds the same note as ProseMirror's JSON,
// one paragraph for each line of the app's text, since every Return the Mac's editor takes is one
// "\n"; this file turns one into the other, with no editor, so the browser never parses or writes
// HTML or RTF of its own. Runs go out in one canonical form, which the server writes in too: a "\n"
// takes the formatting of the text before it (none at the start), neighbours with the same
// formatting are one run, and no run is empty, so an empty formatted note is `[]`.
import type { NoteRun } from '../api/types';

/** A run's formatting, without its text. */
export type Formatting = Omit<NoteRun, 'text'>;

const plain: Formatting = { bold: false, italic: false, underline: false };

/** The marks of the editor's schema, in its order: Link first, by its priority, then the rest as listed. */
export type MarkJSON =
  | { type: 'link'; attrs: { href: string } }
  | { type: 'bold' }
  | { type: 'italic' }
  | { type: 'underline' }
  | { type: 'noteColor'; attrs: { hex: string } };

export interface TextJSON {
  type: 'text';
  text: string;
  marks?: MarkJSON[];
}

export interface ParagraphJSON {
  type: 'paragraph';
  content?: TextJSON[];
}

export interface DocJSON {
  type: 'doc';
  content: ParagraphJSON[];
}

/** A node as the editor's `getJSON()` gives it, read loosely: its marks may carry attributes the runs ignore. */
export interface LooseNode {
  type?: string;
  text?: string;
  content?: LooseNode[];
  marks?: { type: string; attrs?: Record<string, unknown> | null }[];
}

/** Every way of ending a line that the app's text can hold: each starts a paragraph in the editor. */
export const lineBreak = /\r\n|[\n\r\u{0085}\u{2029}]/u;

/**
 * Text as a formatted edit sends it: a CRLF, a CR, U+0085 and U+2029 are each the app's "\n", and
 * any other control character but a tab is a space, as the server refuses them in runs (DEL with
 * them). U+2028, the Mac's line break inside a paragraph, is kept.
 */
export function cleanText(text: string): string {
  // Every control character (Unicode's Cc) but a tab and a line break.
  return text.replace(/\r\n|[\r\u{0085}\u{2029}]/gu, '\n').replace(/[^\P{Cc}\t\n]/gu, ' ');
}

/** The note's plain text: its runs' texts, concatenated. */
export function runsText(runs: readonly NoteRun[]): string {
  return runs.map((run) => run.text).join('');
}

/** Whether every channel is at most 0x13, the near-black that reads as no colour (the app's `hex`). */
export function nearBlack(hex: string): boolean {
  return [0, 2, 4].every((at) => Number.parseInt(hex.slice(at, at + 2), 16) <= 0x13);
}

/** Whether a link's scheme is one the page may follow: http, https or mailto. */
export function followableScheme(url: unknown): url is string {
  return typeof url === 'string' && /^(?:https?|mailto):/i.test(url);
}

/**
 * The address the link dialog applies for what was typed: a followable one, as the URL parser
 * writes it, with what the RTF writer cannot hold escaped; null for anything else, or past 2,048
 * characters.
 */
export function followableLink(typed: string): string | null {
  let url: URL;
  try {
    url = new URL(typed.trim());
  } catch {
    return null;
  }
  if (!['http:', 'https:', 'mailto:'].includes(url.protocol)) return null;
  let href: string;
  try {
    href = url.href.replace(/[^\u{0021}-\u{007E}]|["\\{}]/gu, (character) => encodeURIComponent(character));
  } catch {
    return null;
  }
  return href.length <= 2_048 ? href : null;
}

function formatting(run: Formatting): Formatting {
  const kept: Formatting = { bold: run.bold, italic: run.italic, underline: run.underline };
  if (run.colorHex && /^[0-9A-F]{6}$/.test(run.colorHex) && !nearBlack(run.colorHex)) kept.colorHex = run.colorHex;
  if (run.linkURL) kept.linkURL = run.linkURL;
  return kept;
}

function sameFormatting(a: Formatting, b: Formatting): boolean {
  return a.bold === b.bold && a.italic === b.italic && a.underline === b.underline && a.colorHex === b.colorHex && a.linkURL === b.linkURL;
}

/** Runs in the canonical form, from any runs whose texts hold the same text. */
export function canonicalRuns(runs: readonly NoteRun[]): NoteRun[] {
  const out: NoteRun[] = [];
  let before = plain;
  const push = (text: string, format: Formatting) => {
    const last = out.at(-1);
    if (last && sameFormatting(last, format)) last.text += text;
    else out.push({ text, ...format });
  };
  for (const run of runs) {
    const format = formatting(run);
    for (const part of run.text.split(/(\n)/)) {
      if (part === '') continue;
      if (part === '\n') {
        push(part, before);
      } else {
        push(part, format);
        before = format;
      }
    }
  }
  return out;
}

function marks(format: Formatting): MarkJSON[] | undefined {
  const list: MarkJSON[] = [];
  if (format.linkURL) list.push({ type: 'link', attrs: { href: format.linkURL } });
  if (format.bold) list.push({ type: 'bold' });
  if (format.italic) list.push({ type: 'italic' });
  if (format.underline) list.push({ type: 'underline' });
  if (format.colorHex) list.push({ type: 'noteColor', attrs: { hex: format.colorHex } });
  return list.length > 0 ? list : undefined;
}

function paragraph(content: TextJSON[]): ParagraphJSON {
  return content.length > 0 ? { type: 'paragraph', content } : { type: 'paragraph' };
}

/**
 * The editor's document for a note's runs: a paragraph for each line, the text of each run in it
 * with the run's marks, and never an empty text node, which the schema refuses.
 */
export function runsToDoc(runs: readonly NoteRun[]): DocJSON {
  const paragraphs: ParagraphJSON[] = [];
  let line: TextJSON[] = [];
  for (const run of runs) {
    const runMarks = marks(formatting(run));
    run.text.split(lineBreak).forEach((part, index) => {
      if (index > 0) {
        paragraphs.push(paragraph(line));
        line = [];
      }
      if (part !== '') line.push(runMarks ? { type: 'text', text: part, marks: runMarks } : { type: 'text', text: part });
    });
  }
  paragraphs.push(paragraph(line));
  return { type: 'doc', content: paragraphs };
}

/** The editor's document for a note with no formatting: its text, a paragraph for each line. */
export function textToDoc(text: string): DocJSON {
  return runsToDoc(text === '' ? [] : [{ text, ...plain }]);
}

function markFormatting(nodeMarks: LooseNode['marks']): Formatting {
  const format: Formatting = { ...plain };
  for (const mark of nodeMarks ?? []) {
    if (mark.type === 'bold') format.bold = true;
    else if (mark.type === 'italic') format.italic = true;
    else if (mark.type === 'underline') format.underline = true;
    else if (mark.type === 'noteColor' && typeof mark.attrs?.hex === 'string') format.colorHex = mark.attrs.hex.toUpperCase();
    else if (mark.type === 'link' && typeof mark.attrs?.href === 'string' && mark.attrs.href !== '') format.linkURL = mark.attrs.href;
  }
  return format;
}

/** The runs of the editor's document, canonical, with its text cleaned as a formatted edit sends it. */
export function docToRuns(doc: LooseNode): NoteRun[] {
  const pieces: NoteRun[] = [];
  (doc.content ?? []).forEach((block, index) => {
    // The line break between two paragraphs; canonicalRuns gives it the text's formatting before it.
    if (index > 0) pieces.push({ text: '\n', ...plain });
    for (const node of block.content ?? []) {
      if (node.type === 'text' && node.text) pieces.push({ text: cleanText(node.text), ...markFormatting(node.marks) });
    }
  });
  return canonicalRuns(pieces);
}

/**
 * A summary's text as paragraphs to add at the end of a note: one for each of its lines, plain; when
 * the note is not empty, an empty one first, so the note's text gains "\n\n" and the summary, as the
 * app's Insert into note writes it.
 */
export function summaryParagraphs(text: string, noteIsEmpty: boolean): ParagraphJSON[] {
  const lines = runsToDoc(text === '' ? [] : [{ text: cleanText(text), ...plain }]).content;
  return noteIsEmpty ? lines : [{ type: 'paragraph' }, ...lines];
}

/**
 * A note's runs with a summary's text added at the end, as `summaryParagraphs` adds it to the
 * editor's document, for a note whose editor has not loaded yet: plain, after a blank line unless
 * the note is empty. A note with no runs is its plain text, cleaned as a formatted edit sends it.
 */
export function withSummary(runs: readonly NoteRun[] | null, text: string, summary: string): NoteRun[] {
  const before = runs ?? [{ text: cleanText(text), ...plain }];
  const separator = runsText(before) === '' ? '' : '\n\n';
  return canonicalRuns([...before, { text: separator + cleanText(summary), ...plain }]);
}
