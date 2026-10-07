// The axe check (SPEC, check 11): WCAG 2.2 AA and axe's best practices, over the app and the
// reader's frame together, since some rules weigh the frame against the page around it.
import AxeBuilder from '@axe-core/playwright';
import type { Page } from '@playwright/test';
import { expect } from './fixtures';

const tags = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

/**
 * Scans the page as it is: neither the app's own markup nor the kit's page in the reader's frame
 * may violate a rule. The kit's page has met WCAG 2.2 AA since joshbotts/FRUS-Explorer#1578; until
 * then its known failures were allowed in the frame.
 */
export async function axeCheck(page: Page): Promise<void> {
  const results = await new AxeBuilder({ page }).withTags(tags).analyze();
  // A node in the frame has a target path through it: the iframe's selector, then its own.
  const lines = (inFrame: boolean) =>
    results.violations.flatMap((violation) =>
      violation.nodes
        .filter((node) => node.target.length > 1 === inFrame)
        .map((node) => `${violation.id} (${violation.impact}): ${node.target.join(' >>> ')}`),
    );
  expect(lines(false), 'violations in the app’s own markup').toEqual([]);
  expect(lines(true), 'violations in the reader’s frame').toEqual([]);
  // A frame axe could not reach is reported as incomplete, not as a violation; none may be.
  expect(results.incomplete.filter((result) => result.id === 'frame-tested')).toEqual([]);
}
