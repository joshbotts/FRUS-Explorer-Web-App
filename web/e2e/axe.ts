// The axe check (SPEC, check 11): WCAG 2.2 AA and axe's best practices, over the app and the
// reader's frame together, since some rules weigh the frame against the page around it.
import AxeBuilder from '@axe-core/playwright';
import type { Page } from '@playwright/test';
import { expect } from './fixtures';

const tags = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

/**
 * What the kit's reader page fails today, inside the frame only: its light palette's link, marker
 * and secondary colours are under 4.5:1, and its person and cross-reference links differ from the
 * text around them by colour alone. joshbotts/FRUS-Explorer#1578 fixes both; when the pin moves
 * past it, this list empties, and the suite's checks that each id is still needed fail until it does.
 */
export const kitKnown = new Set(['color-contrast', 'link-in-text-block']);

export interface AxeOutcome {
  /** The rule ids violated inside the reader's frame. */
  frameViolations: Set<string>;
}

/** Scans the page as it is: none of the app's own markup may violate a rule, and the frame only the kit's known list. */
export async function axeCheck(page: Page): Promise<AxeOutcome> {
  const results = await new AxeBuilder({ page }).withTags(tags).analyze();
  // A node in the frame has a target path through it: the iframe's selector, then its own.
  const lines = (inFrame: boolean) =>
    results.violations.flatMap((violation) =>
      violation.nodes
        .filter((node) => node.target.length > 1 === inFrame)
        .map((node) => `${violation.id} (${violation.impact}): ${node.target.join(' >>> ')}`),
    );
  expect(lines(false), 'violations in the app’s own markup').toEqual([]);
  expect(lines(true).filter((line) => !kitKnown.has(line.split(' ')[0] ?? '')), 'violations in the reader’s frame').toEqual([]);
  // A frame axe could not reach is reported as incomplete, not as a violation; none may be.
  expect(results.incomplete.filter((result) => result.id === 'frame-tested')).toEqual([]);
  const frameViolations = new Set(
    results.violations.filter((violation) => violation.nodes.some((node) => node.target.length > 1)).map((violation) => violation.id),
  );
  return { frameViolations };
}
