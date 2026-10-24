import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { HighlightColor } from '../api/types';
import type { SelectionRect } from './readerMessages';
import { SelectionBar } from './SelectionBar';

const rect: SelectionRect = { x: 200, y: 100, w: 100, h: 20 };

let iframe: HTMLIFrameElement;

/** A frame at (100, 50), 600 by 400 inside a border of 2 by 3, as the bar measures it. */
beforeEach(() => {
  iframe = document.createElement('iframe');
  document.body.append(iframe);
  vi.spyOn(iframe, 'getBoundingClientRect').mockReturnValue({ left: 100, top: 50, width: 604, height: 406 } as DOMRect);
  Object.defineProperties(iframe, {
    clientLeft: { value: 2 },
    clientTop: { value: 3 },
    clientWidth: { value: 600 },
    clientHeight: { value: 400 },
  });
  // The bar's own size, 160 by 40.
  vi.spyOn(HTMLElement.prototype, 'offsetWidth', 'get').mockReturnValue(160);
  vi.spyOn(HTMLElement.prototype, 'offsetHeight', 'get').mockReturnValue(40);
});
afterEach(() => {
  cleanup();
  iframe.remove();
});

function bar({
  at = rect,
  focusRequest = 0,
  frame = { current: iframe },
  onChoose = vi.fn<(color: HighlightColor) => void>(),
  onDismiss = vi.fn<() => void>(),
}: {
  at?: SelectionRect;
  focusRequest?: number;
  frame?: { current: HTMLIFrameElement | null };
  onChoose?: (color: HighlightColor) => void;
  onDismiss?: () => void;
} = {}) {
  return <SelectionBar rect={at} frame={frame} focusRequest={focusRequest} onChoose={onChoose} onDismiss={onDismiss} />;
}

const dots = () => within(screen.getByRole('toolbar', { name: 'Highlight Selection' })).getAllByRole('button');
const dot = (color: string) => screen.getByRole('button', { name: `Highlight ${color}` });

describe('the selection bar', () => {
  it('is a toolbar named Highlight Selection with the four colours, as VoiceOver reads the app’s dots, in its order', () => {
    render(bar());
    expect(dots().map((button) => button.getAttribute('aria-label'))).toEqual([
      'Highlight Yellow',
      'Highlight Green',
      'Highlight Blue',
      'Highlight Pink',
    ]);
    expect(dots().map((button) => button.title)).toEqual(['Yellow', 'Green', 'Blue', 'Pink']);
    // One stop in the Tab order: the first dot.
    expect(dots().map((button) => button.tabIndex)).toEqual([0, -1, -1, -1]);
  });

  it('moves among its dots with the arrow keys, Home and End, round from either end, keeping the dot it is on in the Tab order', async () => {
    render(bar({ focusRequest: 1 }));
    expect(document.activeElement).toBe(dot('Yellow'));
    const steps: [string, string][] = [
      ['{ArrowRight}', 'Green'],
      ['{ArrowDown}', 'Blue'],
      ['{ArrowUp}', 'Green'],
      ['{ArrowLeft}', 'Yellow'],
      ['{ArrowLeft}', 'Pink'],
      ['{ArrowRight}', 'Yellow'],
      ['{End}', 'Pink'],
      ['{Home}', 'Yellow'],
    ];
    for (const [key, color] of steps) {
      await userEvent.keyboard(key);
      expect(document.activeElement).toBe(dot(color));
      expect(dots().filter((button) => button.tabIndex === 0)).toEqual([dot(color)]);
    }
  });

  it('keeps its keys from the page: an arrow, Home and End move no caret, and other keys are left alone', () => {
    render(bar({ focusRequest: 1 }));
    for (const key of ['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp', 'Home', 'End']) {
      expect(fireEvent.keyDown(document.activeElement!, { key })).toBe(false);
    }
    expect(fireEvent.keyDown(document.activeElement!, { key: 'a' })).toBe(true);
    expect(fireEvent.keyDown(document.activeElement!, { key: 'Tab' })).toBe(true);
  });

  it('makes a dot focused another way, as by pointer, its Tab stop', () => {
    render(bar());
    fireEvent.focus(dot('Blue'));
    expect(dots().map((button) => button.tabIndex)).toEqual([-1, -1, 0, -1]);
  });

  it('chooses a colour by click, by Return and by Space', async () => {
    const onChoose = vi.fn<(color: HighlightColor) => void>();
    render(bar({ onChoose }));
    await userEvent.click(dot('Green'));
    expect(onChoose).toHaveBeenLastCalledWith('green');
    await userEvent.keyboard('{ArrowRight}{Enter}');
    expect(onChoose).toHaveBeenLastCalledWith('blue');
    await userEvent.keyboard('{End} ');
    expect(onChoose).toHaveBeenLastCalledWith('pink');
    expect(onChoose).toHaveBeenCalledTimes(3);
  });

  it('is put away by Escape, which goes no further: not to the page and not to the rail around it', () => {
    const onDismiss = vi.fn<() => void>();
    const around = vi.fn<() => void>();
    render(
      <div onKeyDown={around}>
        {bar({ focusRequest: 1, onDismiss })}
      </div>,
    );
    expect(fireEvent.keyDown(document.activeElement!, { key: 'Escape' })).toBe(false);
    expect(onDismiss).toHaveBeenCalledTimes(1);
    expect(around).not.toHaveBeenCalled();
    // Another key goes on up.
    fireEvent.keyDown(document.activeElement!, { key: 'a' });
    expect(around).toHaveBeenCalledTimes(1);
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });

  it('takes focus to its first dot each time the keyboard asks for it, and not before', async () => {
    const { rerender } = render(bar());
    expect(document.activeElement).toBe(document.body);
    rerender(bar({ focusRequest: 1 }));
    expect(document.activeElement).toBe(dot('Yellow'));
    await userEvent.keyboard('{End}');
    expect(document.activeElement).toBe(dot('Pink'));
    // A new request comes back to the first dot, which becomes the Tab stop again.
    rerender(bar({ focusRequest: 2 }));
    expect(document.activeElement).toBe(dot('Yellow'));
    expect(dots().map((button) => button.tabIndex)).toEqual([0, -1, -1, -1]);
    // The same request again leaves focus where it is.
    await userEvent.keyboard('{ArrowRight}');
    rerender(bar({ focusRequest: 2 }));
    expect(document.activeElement).toBe(dot('Green'));
  });

  it('is placed centred 8 px above the selection, measured from the frame’s content box, and moves with it', () => {
    const { rerender } = render(bar());
    const toolbar = screen.getByRole('toolbar');
    // The selection's centre is at 100 + 2 + 200 + 50 = 352, its top at 50 + 3 + 100 = 153.
    expect(toolbar.style.left).toBe('272px');
    expect(toolbar.style.top).toBe('105px');
    expect(toolbar.style.visibility).toBe('');
    // Near the frame's top it goes below the selection instead: 53 + 10 + 20 + 8.
    rerender(bar({ at: { x: 200, y: 10, w: 100, h: 20 } }));
    expect(toolbar.style.left).toBe('272px');
    expect(toolbar.style.top).toBe('91px');
  });

  it('stays hidden while there is no frame to place it over', () => {
    render(bar({ frame: { current: null } }));
    const toolbar = screen.getByRole('toolbar', { hidden: true });
    expect(toolbar.style.visibility).toBe('hidden');
    expect(toolbar.style.left).toBe('');
  });
});
