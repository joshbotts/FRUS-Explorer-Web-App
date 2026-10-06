// A result's snippet: the document's text with the server's <b> markers around each match. Only
// those markers become elements; everything else, angle brackets included, stays text.
import type { ReactNode } from 'react';

/** The snippet's pieces: text, and the marked matches, in order. A marker left unclosed stays text. */
export function snippetParts(text: string): { text: string; match: boolean }[] {
  const parts: { text: string; match: boolean }[] = [];
  let rest = text;
  for (;;) {
    const open = rest.indexOf('<b>');
    const close = open < 0 ? -1 : rest.indexOf('</b>', open + 3);
    if (open < 0 || close < 0) {
      if (rest) parts.push({ text: rest, match: false });
      return parts;
    }
    if (open > 0) parts.push({ text: rest.slice(0, open), match: false });
    parts.push({ text: rest.slice(open + 3, close), match: true });
    rest = rest.slice(close + 4);
  }
}

export function Snippet({ text }: { text: string }) {
  const nodes: ReactNode[] = snippetParts(text).map((part, index) =>
    part.match ? <mark key={index}>{part.text}</mark> : part.text,
  );
  return <>{nodes}</>;
}
