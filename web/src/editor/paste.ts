// What the note editor makes of a paste (PLAN's S15d), in three steps. HTML from elsewhere is first
// changed as a string, before the editor's clipboard reads it, since the page's policy refuses a
// style attribute or a <style> element in any document the page makes, the inert one a paste is read
// in included: the style blocks go, and each style attribute goes too, kept as `data-pasted-style`
// only for what it says of bold, italic and underline, so a colour or size from elsewhere is dropped;
// and Google Docs' wrapper, a <b> whose own weight is normal, becomes a span. Then, as the editor
// reads the markup, those three are given back to each element through the CSSOM, which the policy
// allows, so that Tiptap's own rules read them as they read any page's style: Google Docs marks bold,
// italic and underline in its spans' styles alone. And each line break, a <br> or a new line in
// preformatted text, is marked in the text, since the note's schema has no break of its own; the
// <br>s ProseMirror's clipboard ignores are dropped instead, the one Chrome and Safari add where a
// copy starts or ends at a paragraph's edge and one that ends the copy. Last, each line so marked
// becomes a paragraph, as the app's text has one "\n" for each line and the Mac's paste keeps each
// break; only a paste whose markup was marked is split, so plain text, and a drag within the note,
// keep every character they hold. Plain text keeps one paragraph for each line, as the app's text has
// one "\n" for each Return, its blank lines included.
import { DOMParser, Fragment, type Node as ProseMirrorNode, type ParseOptions, type Schema, Slice } from '@tiptap/pm/model';
import type { EditorProps } from '@tiptap/pm/view';

/** A start tag and its attributes, each value quoted or not, as a browser's copy writes them. */
const startTag = /<([a-zA-Z][a-zA-Z0-9:_-]*)((?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)(\s*\/?)>/g;
const attribute = /\s+([^\s"'>/=]+)(?:\s*=\s*("[^"]*"|'[^']*'|[^\s"'=<>`]+))?/g;

/** The properties of a style that the note's formatting has: bold, italic and underline. */
const formattingProperties = new Set(['font-weight', 'font-style', 'text-decoration', 'text-decoration-line']);

/** A style attribute's value, quoted or not, cut to its declarations of bold, italic and underline. */
function formattingDeclarations(style: string): string {
  return style
    .replace(/^(["'])([\s\S]*)\1$/, '$2')
    .split(';')
    .flatMap((declaration) => {
      const colon = declaration.indexOf(':');
      const name = declaration.slice(0, colon).trim().toLowerCase();
      const value = declaration.slice(colon + 1).trim();
      return colon > 0 && value !== '' && formattingProperties.has(name) ? [`${name}:${value}`] : [];
    })
    .join(';')
    .replace(/"/g, '&quot;');
}

/**
 * Pasted HTML with no style element or attribute left, each style's bold, italic and underline kept
 * as `data-pasted-style`, and Google Docs' wrapper made a span.
 */
export function pastedHTML(html: string): string {
  let wrappers = 0;
  const rewritten = html
    .replace(/<style\b[^>]*>[\s\S]*?<\/style\s*>/gi, '')
    .replace(startTag, (_tag, name: string, attributes: string, end: string) => {
      let style = '';
      const kept = attributes.replace(attribute, (whole, attributeName: string, value: string | undefined) => {
        if (attributeName.toLowerCase() !== 'style') return whole;
        style = value ?? '';
        return '';
      });
      // By the property itself: Word's bold is a <b> whose style says `mso-bidi-font-weight:normal`.
      if (name.toLowerCase() === 'b' && formattingDeclarations(style).split(';').some((declaration) => /^font-weight:normal$/i.test(declaration))) {
        wrappers += 1;
        return `<span${kept}${end}>`;
      }
      const formatting = formattingDeclarations(style);
      return `<${name}${kept}${formatting ? ` data-pasted-style="${formatting}"` : ''}${end}>`;
    });
  // A wrapper encloses the copy, so its end tag is the last of the <b>s'.
  let result = rewritten;
  for (let left = wrappers; left > 0; left--) {
    const at = result.toLowerCase().lastIndexOf('</b>');
    if (at < 0) break;
    result = `${result.slice(0, at)}</span>${result.slice(at + 4)}`;
  }
  // A tag the pattern could not read keeps no style either: a copy escapes every < in its text, so
  // each one left opens markup.
  return result.replace(/(<[a-zA-Z][^>]*?)\s+style\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, '$1');
}

/**
 * A <br>, marked in the text the editor reads: the spaces about it fold away, as a browser draws it.
 * Each mark is a noncharacter, which Unicode keeps for a program's own use, so text from elsewhere
 * should hold none; `prepare` marks nothing in a copy that does.
 */
const lineBreakMark = '\u{FDD0}';
/** A line break in preformatted text, whose spaces are kept. */
const preformattedBreakMark = '\u{FDD1}';
const breakMark = /[\u{FDD0}\u{FDD1}]/u;
const breakMarks = /([\u{FDD0}\u{FDD1}])/u;

/** Whether nothing but white space and comments follows `node`, as the end of a copy's markup. */
function endsParent(node: Node): boolean {
  for (let next = node.nextSibling; next; next = next.nextSibling) {
    if (next.nodeType === Node.COMMENT_NODE) continue;
    if (next.nodeType !== Node.TEXT_NODE || /[^ \t\r\n\f]/.test(next.nodeValue ?? '')) return false;
  }
  return true;
}

/**
 * Pasted markup made ready for the editor's parser: each element's bold, italic and underline set
 * through the CSSOM from its `data-pasted-style`, a weight of normal as Tiptap's 400, which it reads
 * as not bold; and each line break marked in the text, a <br> as one and a new line in <pre> as the
 * other, which the parser would otherwise read as a space. The <br>s ProseMirror's clipboard ignores
 * go, as it would drop them: Chrome's and Safari's `Apple-interchange-newline`, which says a copy
 * started or ended at a paragraph's edge, and a <br> that ends the copy, after its last block. Says
 * whether it marked a break.
 */
function prepare(root: Element): boolean {
  const document = root.ownerDocument;
  for (const element of root.querySelectorAll('[data-pasted-style]')) {
    const { style } = element as Partial<ElementCSSInlineStyle>;
    if (!style) continue;
    for (const declaration of (element.getAttribute('data-pasted-style') ?? '').split(';')) {
      const colon = declaration.indexOf(':');
      if (colon <= 0) continue;
      const name = declaration.slice(0, colon);
      const value = declaration.slice(colon + 1);
      // The longhand as the shorthand, which Underline's rule reads.
      if (name === 'text-decoration-line') style.setProperty('text-decoration', value);
      else style.setProperty(name, name === 'font-weight' && value.toLowerCase() === 'normal' ? '400' : value);
    }
  }
  // A copy that holds a mark already is read as the parser reads any, its breaks as spaces, so that
  // none of its own characters is taken for one.
  if (breakMark.test(root.textContent ?? '')) return false;
  let marked = false;
  for (const pre of root.querySelectorAll('pre')) {
    const texts = document.createTreeWalker(pre, NodeFilter.SHOW_TEXT);
    for (let text = texts.nextNode(); text; text = texts.nextNode()) {
      const value = text.nodeValue ?? '';
      const lines = value.replace(/\r\n|[\r\n]/g, preformattedBreakMark);
      if (lines === value) continue;
      text.nodeValue = lines;
      marked = true;
    }
  }
  for (const lineBreak of root.querySelectorAll('br')) {
    if (lineBreak.classList.contains('Apple-interchange-newline') || (lineBreak.parentNode === root && endsParent(lineBreak))) {
      lineBreak.remove();
      continue;
    }
    lineBreak.replaceWith(document.createTextNode(lineBreak.closest('pre') ? preformattedBreakMark : lineBreakMark));
    marked = true;
  }
  return marked;
}

/** ProseMirror's parser, from the schema's own rules, reading pasted markup once `prepare` has. */
class PastedMarkupParser extends DOMParser {
  /** Whether the markup it read last had a line break marked, until the paste it made is split. */
  marked = false;

  override parseSlice(dom: Node, options?: ParseOptions): Slice {
    this.marked = dom.nodeType === Node.ELEMENT_NODE && prepare(dom as Element);
    return super.parseSlice(dom, options);
  }
}

/**
 * How the note editor reads a paste or a drop, for its schema: pasted markup with the parser here,
 * and then a paragraph for each line that markup broke. A paste of plain text, which the editor's
 * own text parser reads, and a drag within the note are never read as markup, so are never split.
 */
export function pasteProps(schema: Schema): Pick<EditorProps, 'clipboardParser' | 'transformPasted'> {
  const parser = new PastedMarkupParser(schema, DOMParser.fromSchema(schema).rules);
  return {
    clipboardParser: parser,
    transformPasted: (slice) => {
      const { marked } = parser;
      parser.marked = false;
      return marked ? pastedLines(slice) : slice;
    },
  };
}

/** Drops the spaces at a line's start: those after a <br>. */
function trimStart(content: ProseMirrorNode[]) {
  while (content[0]?.isText) {
    const text = content[0].text ?? '';
    const spaces = /^ */.exec(text)![0].length;
    if (spaces < text.length) {
      if (spaces > 0) content[0] = content[0].cut(spaces);
      return;
    }
    content.shift();
  }
}

/** Drops the spaces at a line's end: those before a <br>. */
function trimEnd(content: ProseMirrorNode[]) {
  while (content.at(-1)?.isText) {
    const last = content.at(-1)!;
    const text = last.text ?? '';
    const spaces = / *$/.exec(text)![0].length;
    if (spaces < text.length) {
      if (spaces > 0) content[content.length - 1] = last.cut(0, text.length - spaces);
      return;
    }
    content.pop();
  }
}

/**
 * A paragraph whose text marks line breaks, as a paragraph for each line, each piece of text with
 * its own formatting. A break that ends the paragraph is a browser's placeholder, as in Apple Mail's
 * blank line `<div><br></div>`, or a trailing <br>, which draws no line of its own and makes none.
 */
function lines(block: ProseMirrorNode): ProseMirrorNode[] {
  const found: { content: ProseMirrorNode[]; before?: string; after?: string }[] = [{ content: [] }];
  block.forEach((child) => {
    if (!child.isText) {
      found.at(-1)!.content.push(child);
      return;
    }
    (child.text ?? '').split(breakMarks).forEach((part, index) => {
      if (index % 2 === 1) {
        found.at(-1)!.after = part;
        found.push({ content: [], before: part });
      } else if (part !== '') {
        found.at(-1)!.content.push(child.type.schema.text(part, child.marks));
      }
    });
  });
  for (const line of found) {
    if (line.before === lineBreakMark) trimStart(line.content);
    if (line.after === lineBreakMark) trimEnd(line.content);
  }
  if (found.length > 1 && found.at(-1)!.content.length === 0) found.pop();
  return found.map((line) => block.copy(Fragment.from(line.content)));
}

/** A paste with a paragraph for each line its markup broke, and no break mark left in its text. */
function pastedLines(slice: Slice): Slice {
  let marked = false;
  slice.content.descendants((node) => {
    if (node.isText && breakMark.test(node.text ?? '')) marked = true;
    return !marked;
  });
  const first = slice.content.firstChild;
  if (!marked || !first) return slice;
  if (first.isTextblock) {
    const paragraphs: ProseMirrorNode[] = [];
    slice.content.forEach((block) => paragraphs.push(...(block.isTextblock ? lines(block) : [block])));
    return new Slice(Fragment.from(paragraphs), slice.openStart, slice.openEnd);
  }
  // Text alone, which goes into the line pasted in: lines open at both ends.
  const paragraph = first.type.schema.nodes.paragraph!.create(null, slice.content);
  return new Slice(Fragment.from(lines(paragraph)), 1, 1);
}
