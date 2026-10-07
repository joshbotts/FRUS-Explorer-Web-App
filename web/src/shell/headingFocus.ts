// A new screen takes focus at its heading, so a screen reader announces where it arrived; but only
// once the heading says it, not while it still holds an id waiting for its title. The shell asks
// for the focus when the router has rendered a new screen, and a screen whose heading waits for
// data marks it `data-loading` and says when it is ready.
import { useEffect } from 'react';

let requested = false;

/** Moves focus to the heading if one was asked for and the heading is ready. */
function focusHeadingIfReady(): void {
  if (!requested) return;
  const active = document.activeElement;
  // Focus the reader moved elsewhere in the meantime, as into the frame, stays where it is.
  if (active && active !== document.body && active.tagName !== 'MAIN') {
    requested = false;
    return;
  }
  const heading = document.querySelector<HTMLElement>('main h1');
  if (!heading || heading.dataset.loading === 'true') return;
  requested = false;
  heading.focus({ preventScroll: true });
}

/** Called by the shell when the router has rendered a new screen. */
export function requestHeadingFocus(): void {
  requested = true;
  focusHeadingIfReady();
}

/** A screen whose heading waits for data calls this with whether it has its text. */
export function useHeadingReady(ready: boolean): void {
  useEffect(() => {
    if (ready) focusHeadingIfReady();
  }, [ready]);
}
