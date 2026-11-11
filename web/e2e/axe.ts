// The axe check (SPEC, check 11): WCAG 2.2 AA and axe's best practices, over the app and the
// reader's frame together, since some rules weigh the frame against the page around it.
import AxeBuilder from '@axe-core/playwright';
import type { Page } from '@playwright/test';
import { expect } from './fixtures';

const tags = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

/**
 * A failure the kit's own page is known to have on one page the reader serves, which the app's reader
 * shows alike: violations of `rule` in the frame whose target matches `target` are allowed there, and
 * at least one must occur, so that the allowance fails, and is dropped, once a pin move brings the
 * kit's fix.
 */
export interface KitKnownFailure {
  rule: string;
  target: RegExp;
  /** Why it is the kit's, and where its fix belongs. */
  why: string;
}

/**
 * Scans the page as it is: neither the app's own markup nor the kit's page in the reader's frame
 * may violate a rule, but for a failure the kit is known to have on this page (`kitKnown`). The kit's
 * page has met WCAG 2.2 AA since joshbotts/FRUS-Explorer#1578; until then its known failures were
 * allowed in the frame.
 */
export async function axeCheck(page: Page, kitKnown?: KitKnownFailure): Promise<void> {
  let results = await new AxeBuilder({ page }).withTags(tags).analyze();
  // A collection's live preview builds its page again a second after a change (S18e), and a scan that
  // meets its frame between two pages cannot reach it: the scan is made again once the frame holds its
  // next page (S18f). A frame that stays out of reach still fails below.
  if (results.incomplete.some((result) => result.id === 'frame-tested') && (await page.locator('iframe.preview-frame').count()) > 0) {
    await settledPreview(page);
    results = await new AxeBuilder({ page }).withTags(tags).analyze();
  }
  // A node in the frame has a target path through it: the iframe's selector, then its own.
  const lines = (inFrame: boolean) =>
    results.violations.flatMap((violation) =>
      violation.nodes
        .filter((node) => node.target.length > 1 === inFrame)
        .map((node) => `${violation.id} (${violation.impact}): ${node.target.join(' >>> ')}`),
    );
  expect(lines(false), 'violations in the app’s own markup').toEqual([]);
  const known = (line: string) => kitKnown !== undefined && line.startsWith(`${kitKnown.rule} `) && kitKnown.target.test(line);
  expect(lines(true).filter((line) => !known(line)), 'violations in the reader’s frame').toEqual([]);
  if (kitKnown) expect(lines(true).some(known), `the kit no longer fails ${kitKnown.rule} here: drop the allowance (${kitKnown.why})`).toBe(true);
  // A frame axe could not reach is reported as incomplete, not as a violation; none may be.
  expect(results.incomplete.filter((result) => result.id === 'frame-tested')).toEqual([]);
}

/**
 * Once the preview has built what the last change asks: no page on its way, then the second the preview
 * waits for edits to settle and a little more, then none on its way again.
 */
async function settledPreview(page: Page): Promise<void> {
  const idle = () => page.waitForFunction(() => !document.querySelector('.preview-surface[aria-busy="true"]'));
  await idle();
  await page.waitForTimeout(1_500);
  await idle();
}
