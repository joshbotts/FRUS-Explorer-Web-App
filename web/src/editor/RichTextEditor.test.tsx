import type { Editor } from '@tiptap/core';
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createRef, startTransition } from 'react';
import { createRoot } from 'react-dom/client';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { NoteRun } from '../api/types';
import { framesAtOnce } from '../test/frames';
import { darkThemeColor } from './noteExtensions';
import RichTextEditor, { type RichTextEditorHandle } from './RichTextEditor';

afterEach(() => cleanup());

const plain = { bold: false, italic: false, underline: false };
const run = (text: string, format: Partial<NoteRun> = {}): NoteRun => ({ text, ...plain, ...format });

function editorFor({ runs = null, text, onDiscard = vi.fn(), onUnreadable = vi.fn() }: { runs?: NoteRun[] | null; text?: string; onDiscard?: () => void; onUnreadable?: () => void }) {
  const onChange = vi.fn<(runs: NoteRun[]) => void>();
  const handle = createRef<RichTextEditorHandle>();
  render(
    <RichTextEditor
      ref={handle}
      id="note-body"
      label="Research note body"
      runs={runs}
      text={text ?? (runs ?? []).map((part) => part.text).join('')}
      autoFocus={false}
      onChange={onChange}
      onDiscard={onDiscard}
      onUnreadable={onUnreadable}
    />,
  );
  const body = screen.getByRole('textbox', { name: 'Research note body' });
  const editor = (body as HTMLElement & { editor: Editor }).editor;
  const last = () => onChange.mock.calls.at(-1)?.[0];
  return { body, editor, onChange, last, handle, onDiscard, onUnreadable };
}

const toolbar = () => screen.getByRole('toolbar', { name: 'Text formatting' });
// A colour input has no role of its own; its name is its label.
const control = (name: string) => (name === 'Text Color' ? within(toolbar()).getByLabelText(name) : within(toolbar()).getByRole('button', { name }));

/** A paste of `html`, as a browser's clipboard gives it, with its text as the plain copy. */
function pasteHTML(body: HTMLElement, html: string) {
  const paste = new Event('paste', { bubbles: true, cancelable: true });
  Object.defineProperty(paste, 'clipboardData', {
    value: { types: ['text/html', 'text/plain'], getData: (type: string) => (type === 'text/html' ? html : html.replace(/<[^>]*>/g, '')) },
  });
  act(() => {
    body.dispatchEvent(paste);
  });
}

/** A paste of plain text alone. */
function pasteText(body: HTMLElement, text: string) {
  const paste = new Event('paste', { bubbles: true, cancelable: true });
  Object.defineProperty(paste, 'clipboardData', { value: { types: ['text/plain'], getData: (type: string) => (type === 'text/plain' ? text : '') } });
  act(() => {
    body.dispatchEvent(paste);
  });
}

/** The runs an empty note has once `html` is pasted into it. */
function pasted(html: string) {
  const { body, editor, last } = editorFor({ runs: [run('')] });
  select(editor, 1, 1);
  pasteHTML(body, html);
  const runs = last();
  cleanup();
  return runs;
}

function select(editor: Editor, from: number, to: number) {
  act(() => {
    editor.commands.setTextSelection({ from, to });
  });
}

describe('the note editor’s text', () => {
  it('is a multi-line text box named Research note body, under the app’s formatting bar, which controls it', () => {
    const { body } = editorFor({ runs: [run('Text')] });
    expect(body.getAttribute('aria-multiline')).toBe('true');
    expect(body.id).toBe('note-body');
    expect(toolbar().getAttribute('aria-controls')).toBe('note-body');
    const controls = [...toolbar().querySelectorAll('button, input')];
    expect(controls.map((element) => element.getAttribute('aria-label') ?? element.textContent?.replace(/^(B|I|U|Link)/, ''))).toEqual([
      'Bold',
      'Italic',
      'Underline',
      'Text Color',
      'Link selected text to a URL',
    ]);
    // One Tab stop, the arrow keys between.
    expect(controls.map((element) => (element as HTMLElement).tabIndex)).toEqual([0, -1, -1, -1, -1]);
  });

  it('shows a note’s runs as written: bold, a colour drawn through the CSSOM under data-color, and a link', () => {
    const { body } = editorFor({
      runs: [run('bold', { bold: true }), run('blue', { colorHex: '0000FF' }), run('link', { linkURL: 'https://history.state.gov/' }), run('mac', { linkURL: 'javascript:void(0)' })],
    });
    expect(body.querySelector('strong')?.textContent).toBe('bold');
    const blue = body.querySelector<HTMLElement>('span[data-color]');
    expect(blue?.dataset.color).toBe('0000FF');
    expect(blue?.style.getPropertyValue('--note-color')).toBe('#0000FF');
    const links = [...body.querySelectorAll('a')];
    expect(links.map((link) => [link.textContent, link.getAttribute('href')])).toEqual([
      ['link', 'https://history.state.gov/'],
      // A Mac link the page will not follow is drawn as linked text with no address.
      ['mac', null],
    ]);
  });

  it('presses Bold by the selection’s start and turns it off or on over the whole selection, as the app’s bar converges', async () => {
    const { editor, last } = editorFor({ runs: [run('ab', { bold: true }), run('cd')] });
    select(editor, 2, 4);
    await waitFor(() => expect(control('Bold').getAttribute('aria-pressed')).toBe('true'));
    await userEvent.click(control('Bold'));
    expect(last()).toEqual([run('a', { bold: true }), run('bcd')]);
    select(editor, 3, 5);
    await waitFor(() => expect(control('Bold').getAttribute('aria-pressed')).toBe('false'));
    await userEvent.click(control('Bold'));
    expect(last()).toEqual([run('a', { bold: true }), run('b'), run('cd', { bold: true })]);
  });

  it('reads a selection from a line’s end by its line break, which has the formatting of the text before it, as the app’s "\\n" does', async () => {
    // "abc" then "def" bold: the selection starts with the break after "abc", which is plain.
    let shown = editorFor({ runs: [run('abc\n'), run('def', { bold: true })] });
    select(shown.editor, 4, 9);
    await waitFor(() => expect(control('Bold').getAttribute('aria-pressed')).toBe('false'));
    await userEvent.click(control('Bold'));
    // Bold over the whole selection, as the app's toggle makes it: "def" stays bold.
    expect(shown.body.querySelector('strong')?.textContent).toBe('def');
    expect(shown.last()).toBeUndefined();
    cleanup();

    // From an empty line after bold text, the break is bold, and Bold takes it off the selection.
    shown = editorFor({ runs: [run('abc\n\n', { bold: true }), run('def')] });
    select(shown.editor, 6, 11);
    await waitFor(() => expect(control('Bold').getAttribute('aria-pressed')).toBe('true'));
    cleanup();

    // A break after linked, coloured text has its link and its colour.
    shown = editorFor({ runs: [run('abc', { linkURL: 'https://history.state.gov/', colorHex: '0000FF' }), run('\ndef')] });
    select(shown.editor, 4, 9);
    await waitFor(() => expect(control('Link selected text to a URL').getAttribute('aria-pressed')).toBe('true'));
    expect((control('Text Color') as HTMLInputElement).value).toBe('#0000ff');
    await userEvent.click(control('Link selected text to a URL'));
    const dialog = await screen.findByRole('dialog', { name: 'Link selection to URL' });
    expect((within(dialog).getByRole('textbox') as HTMLInputElement).value).toBe('https://history.state.gov/');
    expect(within(dialog).getByRole('button', { name: 'Remove Link' })).toBeTruthy();
  });

  it('takes ⌘B, ⌘I and ⌘U, as Ctrl off a Mac, by the same rule', async () => {
    const { editor, body, last } = editorFor({ runs: [run('ab', { italic: true }), run('cd')] });
    select(editor, 2, 4);
    fireEvent.keyDown(body, { key: 'i', ctrlKey: true });
    expect(last()).toEqual([run('a', { italic: true }), run('bcd')]);
    fireEvent.keyDown(body, { key: 'u', ctrlKey: true });
    expect(last()).toEqual([run('a', { italic: true }), run('bc', { underline: true }), run('d')]);
    fireEvent.keyDown(body, { key: 'b', ctrlKey: true });
    expect(last()).toEqual([run('a', { italic: true }), run('bc', { bold: true, underline: true }), run('d')]);
  });

  it('applies a colour picked, once, and takes it off for near-black, which the app reads as none', () => {
    const { editor, last } = editorFor({ runs: [run('colour me')] });
    select(editor, 1, 7);
    const input = control('Text Color') as HTMLInputElement;
    expect(input.value).toBe('#000000');
    fireEvent.input(input, { target: { value: '#0000ff' } });
    expect(last()).toBeUndefined();
    fireEvent.change(input, { target: { value: '#0000ff' } });
    expect(last()).toEqual([run('colour', { colorHex: '0000FF' }), run(' me')]);
    select(editor, 2, 3);
    expect(input.value).toBe('#0000ff');
    select(editor, 1, 7);
    fireEvent.change(input, { target: { value: '#131313' } });
    expect(last()).toEqual([run('colour me')]);
  });

  it('offers Link only over a selection, and ⌘K opens it there and nowhere else', async () => {
    const { editor, body } = editorFor({ runs: [run('the archive')] });
    select(editor, 1, 1);
    await waitFor(() => expect(control('Link selected text to a URL').getAttribute('aria-disabled')).toBe('true'));
    await userEvent.click(control('Link selected text to a URL'));
    fireEvent.keyDown(body, { key: 'k', ctrlKey: true });
    expect(screen.queryByRole('dialog')).toBeNull();
    select(editor, 5, 12);
    await waitFor(() => expect(control('Link selected text to a URL').getAttribute('aria-disabled')).toBe('false'));
    fireEvent.keyDown(body, { key: 'k', ctrlKey: true });
    expect(await screen.findByRole('dialog', { name: 'Link selection to URL' })).toBeTruthy();
  });

  it('links the selection from the dialog, refuses an address the page cannot follow, and removes a link', async () => {
    const { editor, last } = editorFor({ runs: [run('See the archive.')] });
    select(editor, 5, 16);
    await userEvent.click(control('Link selected text to a URL'));
    let dialog = await screen.findByRole('dialog', { name: 'Link selection to URL' });
    const field = within(dialog).getByRole('textbox', { name: 'Link selection to URL' });
    expect(document.activeElement).toBe(field);
    expect(field.getAttribute('placeholder')).toBe('https://…');
    expect(within(dialog).queryByRole('button', { name: 'Remove Link' })).toBeNull();
    await userEvent.type(field, 'example.com{Enter}');
    expect((await within(dialog).findByRole('alert')).textContent).toBe('A link here starts with http://, https:// or mailto:.');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    await userEvent.clear(field);
    await userEvent.type(field, '  https://history.state.gov/frus ');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Apply' }));
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(last()).toEqual([run('See '), run('the archive', { linkURL: 'https://history.state.gov/frus' }), run('.')]);

    // Over the link, the dialog starts with it and offers Remove Link; an empty Apply removes it too.
    select(editor, 6, 8);
    await waitFor(() => expect(control('Link selected text to a URL').getAttribute('aria-pressed')).toBe('true'));
    await userEvent.click(control('Link selected text to a URL'));
    dialog = await screen.findByRole('dialog', { name: 'Link selection to URL' });
    expect((within(dialog).getByRole('textbox') as HTMLInputElement).value).toBe('https://history.state.gov/frus');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Remove Link' }));
    expect(last()).toEqual([run('See '), run('t', { linkURL: 'https://history.state.gov/frus' }), run('he'), run(' archive', { linkURL: 'https://history.state.gov/frus' }), run('.')]);
    select(editor, 5, 16);
    await userEvent.click(control('Link selected text to a URL'));
    dialog = await screen.findByRole('dialog', { name: 'Link selection to URL' });
    await userEvent.clear(within(dialog).getByRole('textbox'));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Apply' }));
    expect(last()).toEqual([run('See the archive.')]);

    // Cancel, as Escape is, changes nothing.
    select(editor, 5, 16);
    await userEvent.click(control('Link selected text to a URL'));
    dialog = await screen.findByRole('dialog', { name: 'Link selection to URL' });
    const calls = last();
    fireEvent(dialog, new Event('cancel', { cancelable: true }));
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(last()).toBe(calls);
  });

  it('moves among its controls with the arrow keys, Home and End', async () => {
    editorFor({ runs: [run('x')] });
    control('Bold').focus();
    await userEvent.keyboard('{ArrowRight}');
    expect(document.activeElement).toBe(control('Italic'));
    await userEvent.keyboard('{End}');
    expect(document.activeElement).toBe(control('Link selected text to a URL'));
    await userEvent.keyboard('{ArrowRight}');
    expect(document.activeElement).toBe(control('Bold'));
    await userEvent.keyboard('{ArrowLeft}{ArrowLeft}');
    expect(document.activeElement).toBe(control('Text Color'));
    expect(control('Text Color').tabIndex).toBe(0);
  });

  it('discards on Escape in the text, which the editor would otherwise keep from the dialog', () => {
    const { body, onDiscard } = editorFor({ runs: [run('x')] });
    expect(fireEvent.keyDown(body, { key: 'Escape' })).toBe(false);
    expect(onDiscard).toHaveBeenCalledTimes(1);
  });

  it('says when it cannot show the note as its text reads, so the note opens plain', async () => {
    const shown = editorFor({ runs: [run('a')], text: 'a' });
    // The check runs when Tiptap tells the editor made, a timer after it is mounted, and it is
    // marked made just after: until then, a call not made says nothing.
    await waitFor(() => expect(shown.editor.isInitialized).toBe(true));
    expect(shown.onUnreadable).not.toHaveBeenCalled();
    cleanup();
    const differs = editorFor({ runs: null, text: 'a\r\nb' });
    await waitFor(() => expect(differs.onUnreadable).toHaveBeenCalled());
  });

  it('adds a summary at the end after a blank line, or alone in an empty note, keeping the formatting', () => {
    const { handle, last } = editorFor({ runs: [run('Mine', { bold: true })] });
    act(() => handle.current?.insertSummary('One\nTwo'));
    expect(last()).toEqual([run('Mine\n\n', { bold: true }), run('One\nTwo')]);
    cleanup();
    const empty = editorFor({ runs: [] });
    act(() => empty.handle.current?.insertSummary('<b>raw</b> & {"json": 1}'));
    expect(empty.last()).toEqual([run('<b>raw</b> & {"json": 1}')]);
  });

  it('pastes plain text a paragraph for each line, blank lines kept, controls made spaces', () => {
    const { body, editor, last } = editorFor({ runs: [run('ab')] });
    select(editor, 2, 2);
    const paste = new Event('paste', { bubbles: true, cancelable: true });
    Object.defineProperty(paste, 'clipboardData', {
      value: { types: ['text/plain'], getData: (type: string) => (type === 'text/plain' ? 'one\r\n\r\ntwo\u{000B}x' : '') },
    });
    act(() => {
      body.dispatchEvent(paste);
    });
    expect(last()).toEqual([run('aone\n\ntwo xb')]);
  });

  it('pastes HTML without its styles, keeping bold, italic, underline and links', () => {
    const { body, editor, last } = editorFor({ runs: [run('')] });
    select(editor, 1, 1);
    const html = '<style>b{color:red}</style><span style="color:#ff0000">red</span> <b>bold</b> <a href="https://example.com/" style="color:blue">link</a>';
    const paste = new Event('paste', { bubbles: true, cancelable: true });
    Object.defineProperty(paste, 'clipboardData', {
      value: { types: ['text/html', 'text/plain'], getData: (type: string) => (type === 'text/html' ? html : 'red bold link') },
    });
    act(() => {
      body.dispatchEvent(paste);
    });
    expect(last()).toEqual([run('red '), run('bold', { bold: true }), run(' '), run('link', { linkURL: 'https://example.com/' })]);
  });

  it('pastes a line for each line break the HTML draws, a <br> or a new line in <pre>, but none for a break that ends its block', () => {
    // The reader's own lines, a dateline and a signature, with the spaces a source puts about them.
    expect(pasted('<p>Embassy Moscow<br>\n  Telegram 1234<br><br>Secret</p>')).toEqual([run('Embassy Moscow\nTelegram 1234\n\nSecret')]);
    expect(pasted('<p>a <b>bold<br>still bold</b></p>')).toEqual([run('a '), run('bold\nstill bold', { bold: true })]);
    // A trailing <br> draws no line of its own; two draw one.
    expect(pasted('<p>a<br></p><p>b<br><br></p>')).toEqual([run('a\nb\n')]);
    // Apple Mail's blank line, and Google Docs' Shift+Return.
    expect(pasted('<div>a</div><div><br></div><div>b</div>')).toEqual([run('a\n\nb')]);
    expect(pasted('<p><span>one</span><br><span>two</span></p>')).toEqual([run('one\ntwo')]);
    // Preformatted text keeps its lines and its spaces; the new line after <pre> is the markup's.
    expect(pasted('<pre>\nline one\n  indented\n</pre>')).toEqual([run('line one\n  indented')]);
    // Between blocks, a <br> draws a line of its own, as Google Docs writes an empty paragraph.
    expect(pasted('<p>a</p><br><p>b</p>')).toEqual([run('a\n\nb')]);
  });

  it('pastes no line for the <br>s ProseMirror’s clipboard ignores: a browser’s where a copy starts or ends at a paragraph’s edge, and one that ends the copy', () => {
    // Chrome's and Safari's copy of a paragraph chosen with a triple click, from the reader say.
    expect(pasted('<p>a</p><br class="Apple-interchange-newline">')).toEqual([run('a')]);
    expect(pasted('<br class="Apple-interchange-newline"><p>a</p>')).toEqual([run('a')]);
    expect(pasted('<br class="Apple-interchange-newline"><span>a</span><br class="Apple-interchange-newline">')).toEqual([run('a')]);
    // Windows' clipboard ends its fragment with a comment.
    expect(pasted('<p>a</p><br><!--EndFragment-->\n')).toEqual([run('a')]);
  });

  it('splits only the lines a paste’s markup broke, so the text’s own characters are kept wherever they are pasted from', () => {
    // Private-use characters, as a PDF's text and icon fonts give, and the noncharacters the marks are.
    const own = 'a\u{E000}b\u{E001}c\u{FDD0}d\u{FDD1}e';
    const plainPaste = editorFor({ runs: [run('')] });
    select(plainPaste.editor, 1, 1);
    pasteText(plainPaste.body, own);
    expect(plainPaste.last()).toEqual([run(own)]);
    cleanup();
    expect(pasted('<p>a\u{E000}b<br>c</p>')).toEqual([run('a\u{E000}b\nc')]);
    // Markup that holds a mark already keeps it, its breaks read as spaces, as the parser reads them.
    expect(pasted('<p>a\u{FDD0}b<br>c</p>')).toEqual([run('a\u{FDD0}b c')]);
    // A drag within the note is put down as it was taken up, never read as markup.
    const { editor } = editorFor({ runs: [run(own)] });
    const taken = editor.state.doc.slice(1, 1 + own.length);
    let dropped = taken;
    editor.view.someProp('transformPasted', (transform) => {
      dropped = transform(dropped, editor.view, false);
    });
    expect(dropped.eq(taken)).toBe(true);
  });

  it('pastes the bold, italic and underline a style gives, as Google Docs’ spans carry them, and takes bold off where a style says normal', () => {
    const { body, editor, last } = editorFor({ runs: [run('')] });
    select(editor, 1, 1);
    pasteHTML(
      body,
      '<meta charset="utf-8"><b style="font-weight:normal;" id="docs-internal-guid-x"><p dir="ltr" style="line-height:1.38"><span style="font-size:11pt;font-weight:700;color:#000000">Key</span><span style="font-weight:400"> </span><span style="font-style:italic;text-decoration:underline">point</span></p><p><b>Bold <span style="font-weight:normal">not</span></b></p></b>',
    );
    // The line break has the formatting of the text before it.
    expect(last()).toEqual([run('Key', { bold: true }), run(' '), run('point\n', { italic: true, underline: true }), run('Bold ', { bold: true }), run('not')]);
  });

  it('pastes Word’s bold as bold, though its style says a weight of normal for right-to-left text', () => {
    const word =
      '<html xmlns:o="urn:schemas-microsoft-com:office:office"><head><style>p.MsoNormal { margin: 0in }</style></head><body lang=EN-US style=\'tab-interval:.5in\'><!--StartFragment--><p class=MsoNormal><b style=\'mso-bidi-font-weight:normal\'><span lang=EN-US style=\'font-size:12.0pt\'>Secret</span></b><span lang=EN-US> cable, <b>sent</b> today<o:p></o:p></span></p><!--EndFragment--></body></html>';
    expect(pasted(word)).toEqual([run('Secret', { bold: true }), run(' cable, '), run('sent', { bold: true }), run(' today')]);
  });

  it('writes a pasted link’s address as the link dialog writes a typed one, and pastes one it cannot follow as text', () => {
    const { body, editor, last } = editorFor({ runs: [run('')] });
    select(editor, 1, 1);
    const html = '<a href="https://example.com/?q={x} y">query</a> <a href="https://de.wikipedia.org/wiki/Außenpolitik">accent</a> <a href="javascript:alert(1)">script</a> <a href="/relative">relative</a>';
    const paste = new Event('paste', { bubbles: true, cancelable: true });
    Object.defineProperty(paste, 'clipboardData', {
      value: { types: ['text/html', 'text/plain'], getData: (type: string) => (type === 'text/html' ? html : 'query accent script relative') },
    });
    act(() => {
      body.dispatchEvent(paste);
    });
    expect(last()).toEqual([
      run('query', { linkURL: 'https://example.com/?q=%7Bx%7D%20y' }),
      run(' '),
      run('accent', { linkURL: 'https://de.wikipedia.org/wiki/Au%C3%9Fenpolitik' }),
      run(' script relative'),
    ]);
  });
});

// Node's, with which React's scheduler queues its tasks here, as it posts a message in a browser.
const { setImmediate } = globalThis as unknown as { setImmediate: (callback: () => void) => void };

/** The next task, after those React's scheduler has queued. */
const nextTask = () => new Promise<void>((done) => setImmediate(done));

/** A sibling as slow to render as the editor is on a slow machine, past the 5 ms after which React pauses a render it time-slices. */
function Slow() {
  const end = performance.now() + 10;
  while (performance.now() < end);
  return null;
}

describe('a new note’s text', () => {
  it('takes focus once React has placed it in the dialog, though React paused after making it and Tiptap’s first timer and a frame came first', async () => {
    framesAtOnce();
    // Tiptap's timers run when the test says, in the order Chromium ran them when the browser suite
    // failed: the first in the pause, the second only once React's effects had cleared it.
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] });
    const environment = globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean };
    const actEnvironment = environment.IS_REACT_ACT_ENVIRONMENT;
    // React's own scheduler, which act would replace with renders it never pauses.
    environment.IS_REACT_ACT_ENVIRONMENT = false;
    // The note editor's dialog, its heading focused as it opens.
    const dialog = document.body.appendChild(document.createElement('dialog'));
    const heading = dialog.appendChild(document.createElement('h2'));
    heading.tabIndex = -1;
    const container = dialog.appendChild(document.createElement('div'));
    dialog.showModal();
    heading.focus();
    const root = createRoot(container);
    try {
      // A render React time-slices, as it does the retry that shows the editor once its code has come.
      startTransition(() =>
        root.render(
          <>
            <RichTextEditor id="note-body" label="Research note body" runs={null} text="" autoFocus onChange={vi.fn()} onDiscard={vi.fn()} onUnreadable={vi.fn()} />
            <Slow />
            <p />
          </>,
        ),
      );
      while (vi.getTimerCount() === 0) await nextTask();
      // React has made the editor and paused before placing it; Tiptap's first timer comes, and the frame it asks for.
      expect(container.querySelector('.ProseMirror')).toBeNull();
      vi.advanceTimersToNextTimer();
      await Promise.resolve();
      while (!container.querySelector('.ProseMirror')) await nextTask();
      // React's effects, in the task after it placed the editor.
      await nextTask();
      vi.runOnlyPendingTimers();
      await nextTask();
      expect(document.activeElement).toBe(screen.getByRole('textbox', { name: 'Research note body' }));
    } finally {
      root.unmount();
      // The editor's destruction, which Tiptap times too.
      vi.runOnlyPendingTimers();
      vi.useRealTimers();
      dialog.remove();
      environment.IS_REACT_ACT_ENVIRONMENT = actEnvironment;
    }
  });
});

describe('a note’s colour on the dark theme', () => {
  const contrast = (hex: string) => {
    const luminance = (value: string) => {
      const [r = 0, g = 0, b = 0] = [0, 2, 4].map((at) => {
        const channel = Number.parseInt(value.slice(at, at + 2), 16) / 255;
        return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
      });
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };
    return (luminance(hex.replace('#', '')) + 0.05) / (luminance('1C1C1E') + 0.05);
  };

  it('is the note’s own where it reads at 4.5:1 on the dark page, and lightened just enough where it does not', () => {
    expect(darkThemeColor('FFCC00')).toBe('#FFCC00');
    for (const hex of ['0000FF', '141414', '8B0000', '006400']) {
      const shown = darkThemeColor(hex);
      expect(contrast(shown), hex).toBeGreaterThanOrEqual(4.5);
      expect(contrast(`#${hex}`), hex).toBeLessThan(4.5);
    }
    // The e2e's blue, 2:1 on the dark page as it is, mixed with 45% white, where 44% would not do.
    expect(darkThemeColor('0000FF')).toBe('#7373FF');
    expect(contrast('#7070FF')).toBeLessThan(4.5);
  });

  it('is set beside the note’s own colour by its view, for app.css to draw on the dark theme', () => {
    const { body } = editorFor({ runs: [run('blue', { colorHex: '0000FF' })] });
    const blue = body.querySelector<HTMLElement>('span[data-color]');
    expect(blue?.style.getPropertyValue('--note-color')).toBe('#0000FF');
    expect(blue?.style.getPropertyValue('--note-color-dark')).toBe(darkThemeColor('0000FF'));
  });
});
