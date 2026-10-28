// A browser at its quickest, for where focus goes once a dialog has gone: each animation frame comes
// as soon as the task that asked for it is done, before React's next task, and focus sent outside
// an open modal dialog is refused, the page around it being inert. jsdom has neither: its frames come
// long after React's work, and it leaves no part of the page inert.
import { vi } from 'vitest';

/** From now until the test ends, frames come at once, and the page behind a modal dialog is inert. */
export function framesAtOnce(): void {
  if (vi.isMockFunction(window.requestAnimationFrame)) return;
  vi.spyOn(window, 'requestAnimationFrame').mockImplementation((callback) => {
    queueMicrotask(() => callback(performance.now()));
    return 0;
  });
  const focus = HTMLElement.prototype.focus;
  vi.spyOn(HTMLElement.prototype, 'focus').mockImplementation(function (this: HTMLElement, options?: FocusOptions) {
    const top = [...document.querySelectorAll('dialog[open]')].at(-1);
    if (top && !top.contains(this)) return;
    focus.call(this, options);
  });
}
