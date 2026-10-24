// Reaching a control by keyboard alone: Tab, or Shift+Tab, until it has focus, in the app or the
// reader's frame.
import type { Locator, Page } from '@playwright/test';

/** Presses Tab until `target` has focus, its document included; fails after `limit` presses. */
export async function tabTo(page: Page, target: Locator, limit = 40, key = 'Tab'): Promise<number> {
  for (let presses = 1; presses <= limit; presses++) {
    await page.keyboard.press(key);
    const focused = await target
      .evaluate((element) => element === element.ownerDocument.activeElement && element.ownerDocument.hasFocus(), undefined, {
        timeout: 1_000,
      })
      .catch(() => false);
    if (focused) return presses;
  }
  throw new Error(`${key} never reached ${target.toString()} in ${limit} presses`);
}

/** Presses Shift+Tab until `target` has focus, as `tabTo` presses Tab. */
export function backTabTo(page: Page, target: Locator, limit = 40): Promise<number> {
  return tabTo(page, target, limit, 'Shift+Tab');
}
