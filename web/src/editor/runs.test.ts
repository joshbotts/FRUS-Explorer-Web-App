import { getSchema } from '@tiptap/core';
import { describe, expect, it } from 'vitest';
import type { NoteRun } from '../api/types';
import { schemaExtensions } from './noteExtensions';
import {
  canonicalRuns,
  cleanText,
  type DocJSON,
  docToRuns,
  followableLink,
  followableScheme,
  nearBlack,
  runsText,
  runsToDoc,
  summaryParagraphs,
  textToDoc,
  withSummary,
} from './runs';

// The note editor's own schema, which every document built here must satisfy: an empty text node,
// a mark out of place or an unknown one would make Tiptap load an empty note instead.
const schema = getSchema(schemaExtensions());

/** The document as the editor would hold it, checked against its schema, and as its getJSON gives it. */
function loaded(doc: DocJSON) {
  const node = schema.nodeFromJSON(doc);
  node.check();
  return node;
}

/** The editor's text, as getText({ blockSeparator: '\n' }) gives it. */
function editorText(doc: DocJSON): string {
  const node = loaded(doc);
  const lines: string[] = [];
  node.forEach((paragraph) => lines.push(paragraph.textContent));
  return lines.join('\n');
}

const plain = { bold: false, italic: false, underline: false };
const run = (text: string, format: Partial<NoteRun> = {}): NoteRun => ({ text, ...plain, ...format });

describe('runs and the editor’s document', () => {
  const cases: [string, NoteRun[]][] = [
    ['an empty note', []],
    ['one plain line', [run('Key turning point.')]],
    ['a line break', [run('one\ntwo')]],
    ['blank lines, leading and trailing', [run('\n\nmiddle\n\n\n')]],
    ['a line break alone', [run('\n')]],
    ['each formatting, and all at once', [run('b', { bold: true }), run('i', { italic: true }), run('u', { underline: true }), run('all', { bold: true, italic: true, underline: true, colorHex: '0000FF', linkURL: 'https://history.state.gov/' })]],
    ['bold inside a link', [run('See ', { linkURL: 'https://history.state.gov/frus' }), run('the archive', { bold: true, linkURL: 'https://history.state.gov/frus' }), run('.')]],
    ['a colour across a line break', [run('red\nstill red', { colorHex: 'B00020' }), run(' plain')]],
    ['a Mac link the page does not follow', [run('there', { linkURL: 'javascript:void(0)' })]],
    ['a tab, U+2028, accents, CJK and emoji', [run('\tcafé — “quoted”\u{2028}日本語 🇺🇸 👩🏽‍🔬')]],
  ];

  for (const [name, runs] of cases) {
    it(`round-trips ${name}, in the schema, with the note’s text`, () => {
      const doc = runsToDoc(runs);
      const node = loaded(doc);
      expect(editorText(doc)).toBe(runsText(runs));
      expect(docToRuns(node.toJSON())).toEqual(canonicalRuns(runs));
    });
  }

  it('builds one paragraph for each line, with no empty text node and the marks in the schema’s order', () => {
    expect(runsToDoc([run('a\n'), run('', { bold: true }), run('b', { bold: true, colorHex: '0000FF', linkURL: 'mailto:a@example.com' })])).toEqual({
      type: 'doc',
      content: [
        { type: 'paragraph', content: [{ type: 'text', text: 'a' }] },
        {
          type: 'paragraph',
          content: [
            {
              type: 'text',
              text: 'b',
              marks: [{ type: 'link', attrs: { href: 'mailto:a@example.com' } }, { type: 'bold' }, { type: 'noteColor', attrs: { hex: '0000FF' } }],
            },
          ],
        },
      ],
    });
    expect(runsToDoc([])).toEqual({ type: 'doc', content: [{ type: 'paragraph' }] });
  });

  it('starts a paragraph at a CRLF, a CR, U+0085 and U+2029 too, so the content check sees their text differ', () => {
    for (const text of ['a\r\nb', 'a\rb', 'a\u{0085}b', 'a\u{2029}b']) {
      const doc = textToDoc(text);
      expect(doc.content).toHaveLength(2);
      expect(editorText(doc)).toBe('a\nb');
    }
  });
});

describe('the canonical runs', () => {
  it('give a line break the formatting of the text before it, none at the start, and merge equal neighbours', () => {
    expect(canonicalRuns([run('\n'), run('a', { bold: true }), run('\n'), run('b', { bold: true }), run('\n\nc')])).toEqual([
      run('\n'),
      run('a\nb\n\n', { bold: true }),
      run('c'),
    ]);
  });

  it('send no empty run, an empty formatted note as none, and no colour for near-black', () => {
    expect(canonicalRuns([run(''), run('', { bold: true })])).toEqual([]);
    expect(canonicalRuns([run('x', { colorHex: '131313' }), run('y', { colorHex: '141414' })])).toEqual([run('x'), run('y', { colorHex: '141414' })]);
  });

  it('are what the editor’s document gives, its paragraphs joined by line breaks, its text cleaned', () => {
    const doc = {
      type: 'doc',
      content: [
        { type: 'paragraph', content: [{ type: 'text', text: 'bold', marks: [{ type: 'bold' }] }] },
        { type: 'paragraph' },
        {
          type: 'paragraph',
          content: [
            { type: 'text', text: 'link', marks: [{ type: 'link', attrs: { href: 'https://example.com/', target: null, rel: 'noopener', class: null, title: null } }] },
            { type: 'text', text: ' red\u{000B}x', marks: [{ type: 'noteColor', attrs: { hex: 'b00020' } }] },
          ],
        },
      ],
    };
    expect(docToRuns(doc)).toEqual([run('bold\n\n', { bold: true }), run('link', { linkURL: 'https://example.com/' }), run(' red x', { colorHex: 'B00020' })]);
  });
});

describe('cleanText', () => {
  it('makes each kind of line ending the app’s "\\n", any other control character a space, and keeps tabs and U+2028', () => {
    expect(cleanText('a\r\nb\rc\u{0085}d\u{2029}e')).toBe('a\nb\nc\nd\ne');
    expect(cleanText('\u{0000}\u{0007}\u{001F}\u{007F}\u{0090}')).toBe('     ');
    expect(cleanText('\tx\u{2028}y')).toBe('\tx\u{2028}y');
    // U+FFFD goes, as the app's RTF reader drops it, which the server's rules for runs follow.
    expect(cleanText('a\u{FFFD}b')).toBe('ab');
  });
});

describe('colours and links', () => {
  it('reads near-black as every channel at most 0x13, as the writer’s midpoint of 0x14 reads back as a colour', () => {
    expect(nearBlack('000000')).toBe(true);
    expect(nearBlack('131313')).toBe(true);
    expect(nearBlack('141313')).toBe(false);
    expect(nearBlack('0000FF')).toBe(false);
  });

  it('follows http, https and mailto only, as the page draws a link', () => {
    expect(['https://a.example', 'HTTP://a.example', 'mailto:a@example.com'].every(followableScheme)).toBe(true);
    expect(['javascript:alert(1)', 'example.com', 'ftp://a.example', 'data:text/html,x', undefined].some(followableScheme)).toBe(false);
  });

  it('applies what the dialog was given as the URL parser writes it, escaping what the RTF writer cannot hold', () => {
    expect(followableLink('  https://history.state.gov/frus  ')).toBe('https://history.state.gov/frus');
    expect(followableLink('https://example.com/a b?q={x}"y"')).toBe('https://example.com/a%20b?q=%7Bx%7D%22y%22');
    expect(followableLink('https://example.com/é')).toBe('https://example.com/%C3%A9');
    expect(followableLink('mailto:someone@example.com')).toBe('mailto:someone@example.com');
    expect(followableLink('example.com')).toBeNull();
    expect(followableLink('javascript:alert(1)')).toBeNull();
    expect(followableLink(`https://example.com/${'a'.repeat(2_100)}`)).toBeNull();
  });
});

describe('summaryParagraphs', () => {
  it('adds a summary after a blank line, a paragraph for each of its lines, or alone in an empty note, as the app writes it', () => {
    const body = runsToDoc([run('My note', { bold: true })]);
    const added = { ...body, content: [...body.content, ...summaryParagraphs('First line\r\nSecond', false)] };
    expect(editorText(added)).toBe('My note\n\nFirst line\nSecond');
    // The blank line takes the note's formatting before it, as every line break does.
    expect(docToRuns(loaded(added).toJSON())).toEqual([run('My note\n\n', { bold: true }), run('First line\nSecond')]);
    const alone: DocJSON = { type: 'doc', content: summaryParagraphs('{"field": "<value> & more"}', true) };
    expect(editorText(alone)).toBe('{"field": "<value> & more"}');
  });
});

describe('withSummary', () => {
  it('adds a summary to a note’s runs as summaryParagraphs adds it to the editor’s document, for an editor not loaded yet', () => {
    const body = runsToDoc([run('My note', { bold: true })]);
    const added = { ...body, content: [...body.content, ...summaryParagraphs('First line\r\nSecond', false)] };
    expect(withSummary([run('My note', { bold: true })], 'My note', 'First line\r\nSecond')).toEqual(docToRuns(loaded(added).toJSON()));
    // A note with no runs is its plain text, cleaned; an empty one takes the summary alone.
    expect(withSummary(null, 'Plain\r\nnote', 'A summary.')).toEqual([run('Plain\nnote\n\nA summary.')]);
    expect(withSummary([], '', 'A summary.')).toEqual([run('A summary.')]);
    expect(withSummary(null, '', 'A summary.')).toEqual([run('A summary.')]);
  });
});
