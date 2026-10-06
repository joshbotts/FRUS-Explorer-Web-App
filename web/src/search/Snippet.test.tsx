import { render } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { Snippet, snippetParts } from './Snippet';

describe('Snippet', () => {
  it('marks only the server’s <b> pairs', () => {
    expect(snippetParts('the <b>treaties</b> came and <b>treaty</b>')).toEqual([
      { text: 'the ', match: false },
      { text: 'treaties', match: true },
      { text: ' came and ', match: false },
      { text: 'treaty', match: true },
    ]);
  });

  it('keeps an unclosed marker as text', () => {
    expect(snippetParts('a <b>b')).toEqual([{ text: 'a <b>b', match: false }]);
  });

  it('puts the document’s own angle brackets into the page as text', () => {
    const { container } = render(<Snippet text={'<script>alert(1)</script> and <b>x</b> <img src=y onerror=z>'} />);
    expect(container.querySelector('script')).toBeNull();
    expect(container.querySelector('img')).toBeNull();
    expect(container.querySelectorAll('mark')).toHaveLength(1);
    expect(container.textContent).toBe('<script>alert(1)</script> and x <img src=y onerror=z>');
  });
});
