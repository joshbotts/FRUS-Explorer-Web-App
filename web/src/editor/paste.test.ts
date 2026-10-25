import { describe, expect, it } from 'vitest';
import { pastedHTML } from './paste';

describe('pastedHTML', () => {
  it('drops every style block and style attribute, quoted or not, keeping the rest of each tag', () => {
    const html =
      '<style>p { color: red }</style><p class=MsoNormal style=\'margin:0;font-family:"Times"\'><span STYLE="color:#f00" data-color="0000FF">red</span> <a href="https://example.com/" style=color:blue>link</a></p><STYLE type="text/css">x{}</STYLE>';
    expect(pastedHTML(html)).toBe('<p class=MsoNormal><span data-color="0000FF">red</span> <a href="https://example.com/">link</a></p>');
  });

  it('makes Google Docs’ wrapper, a <b> that is not bold, a span, and keeps a bold one bold', () => {
    const docs = '<meta charset="utf-8"><b style="font-weight:normal;" id="docs-internal-guid-1"><p><b>bold</b> plain</p></b>';
    expect(pastedHTML(docs)).toBe('<meta charset="utf-8"><span id="docs-internal-guid-1"><p><b>bold</b> plain</p></span>');
  });

  it('takes a <b> for the wrapper by its own weight alone, so Word’s bold, which names a weight for right-to-left text, stays bold', () => {
    expect(pastedHTML("<b style='mso-bidi-font-weight:normal'>x</b>")).toBe('<b>x</b>');
    // No end tag is moved: the last <b> keeps its own.
    expect(pastedHTML("<p class=MsoNormal><b style='mso-bidi-font-weight:normal'><span lang=EN-US>Secret</span></b> and <b>more</b></p>")).toBe(
      '<p class=MsoNormal><b><span lang=EN-US>Secret</span></b> and <b>more</b></p>',
    );
    expect(pastedHTML('<b style="FONT-WEIGHT: Normal">x</b>')).toBe('<span>x</span>');
  });

  it('leaves no style in a tag it could not read whole, nor in a namespaced one', () => {
    expect(pastedHTML('<v:shape style="width:1pt"></v:shape>')).toBe('<v:shape></v:shape>');
    expect(pastedHTML('<span title=a"b style="color:red">x</span>')).not.toMatch(/style/);
  });

  it('keeps what a style says of bold, italic and underline, and nothing else, outside any style attribute', () => {
    expect(pastedHTML('<span style="font-size:11pt;font-weight:700;color:#000000;font-style:italic;text-decoration:underline">x</span>')).toBe(
      '<span data-pasted-style="font-weight:700;font-style:italic;text-decoration:underline">x</span>',
    );
    expect(pastedHTML("<p style='TEXT-DECORATION-LINE: underline; font-family: \"Times\"'>x</p><br style=font-weight:bold>")).toBe(
      '<p data-pasted-style="text-decoration-line:underline">x</p><br data-pasted-style="font-weight:bold">',
    );
  });

  it('leaves text that only mentions a style alone', () => {
    expect(pastedHTML('<p>set style = "plain" here</p>')).toBe('<p>set style = "plain" here</p>');
  });
});
