// What the note editor makes of a paste (PLAN's S15d). HTML from elsewhere is changed as a string,
// before the editor's clipboard reads it, since the page's policy refuses a style attribute or a
// <style> element in any document the page makes, the inert one a paste is read in included: the
// style blocks and attributes go, so a colour or size from elsewhere is dropped, and Google Docs'
// wrapper, a <b> that is not bold, becomes a span. Plain text keeps one paragraph for each line, as
// the app's text has one "\n" for each Return, its blank lines included.

/** A start tag and its attributes, each value quoted or not, as a browser's copy writes them. */
const startTag = /<([a-zA-Z][a-zA-Z0-9:_-]*)((?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)(\s*\/?)>/g;
const attribute = /\s+([^\s"'>/=]+)(?:\s*=\s*("[^"]*"|'[^']*'|[^\s"'=<>`]+))?/g;

/** Pasted HTML with no style element or attribute left, and Google Docs' wrapper made a span. */
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
      if (name.toLowerCase() === 'b' && /font-weight\s*:\s*normal/i.test(style)) {
        wrappers += 1;
        return `<span${kept}${end}>`;
      }
      return `<${name}${kept}${end}>`;
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
