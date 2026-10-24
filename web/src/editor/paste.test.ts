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

  it('leaves no style in a tag it could not read whole, nor in a namespaced one', () => {
    expect(pastedHTML('<v:shape style="width:1pt"></v:shape>')).toBe('<v:shape></v:shape>');
    expect(pastedHTML('<span title=a"b style="color:red">x</span>')).not.toMatch(/style/);
  });

  it('leaves text that only mentions a style alone', () => {
    expect(pastedHTML('<p>set style = "plain" here</p>')).toBe('<p>set style = "plain" here</p>');
  });
});
