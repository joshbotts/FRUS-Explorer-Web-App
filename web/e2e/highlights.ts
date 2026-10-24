// What the highlights specs share: the frame's highlight registry, read in the frame, a selection
// made by dragging over a phrase, the user's highlights through the API, and a store left with none,
// since the suite runs twice on one store.
import type { Page } from '@playwright/test';
import { expect } from './fixtures';

export const documentPath = 'doc/frus1961-63v06/d1';
const listPath = 'api/v1/me/volumes/frus1961-63v06/documents/d1/highlights';

/** How many ranges the frame's registry holds under each of the kit's names, as its renderer drew them. */
export function drawn(page: Page): Promise<Record<string, number>> {
  return page
    .frameLocator('iframe.reader-frame')
    .locator('.frus-document')
    .evaluate(() => {
      const names: Record<string, number> = {};
      CSS.highlights.forEach((highlight, name) => {
        names[name] = highlight.size;
      });
      return names;
    });
}

/**
 * Where `phrase`, inside one text node of the page under `within`, is drawn in the app's viewport:
 * its first and last glyph.
 */
export async function phraseBox(page: Page, phrase: string, within = '.frus-document') {
  const frame = page.locator('iframe.reader-frame');
  const box = (await frame.boundingBox())!;
  const border = await frame.evaluate((element) => ({ left: element.clientLeft, top: element.clientTop }));
  const glyphs = await page
    .frameLocator('iframe.reader-frame')
    .locator(within)
    .evaluate((root, text) => {
      const walker = root.ownerDocument.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        const at = node.nodeValue!.indexOf(text);
        if (at < 0) continue;
        const range = root.ownerDocument.createRange();
        range.setStart(node, at);
        range.setEnd(node, at + text.length);
        const rects = [...range.getClientRects()];
        const first = rects[0];
        const last = rects[rects.length - 1];
        return { x0: first.left + 1, y0: first.top + first.height / 2, x1: last.right - 1, y1: last.top + last.height / 2 };
      }
      return null;
    }, phrase);
  expect(glyphs, `${phrase} is in the page`).not.toBeNull();
  const at = (x: number, y: number) => ({ x: box.x + border.left + x, y: box.y + border.top + y });
  return { start: at(glyphs!.x0, glyphs!.y0), end: at(glyphs!.x1, glyphs!.y1) };
}

/**
 * Selects `phrase` with the pointer: pressed just inside its first glyph and dragged to its last. A
 * press on a link would drag the link, so the phrase is plain text.
 */
export async function dragOver(page: Page, phrase: string, { within }: { within?: string } = {}) {
  const { start, end } = await phraseBox(page, phrase, within);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  await page.mouse.move(end.x, end.y, { steps: 10 });
  await page.mouse.up();
}

interface Highlight {
  id: string;
  startOffset: number;
  endOffset: number;
  colorTag: string;
  selectedText: string;
  isStale?: boolean;
}

/** The document's highlights, as the server lists them. */
export async function listed(page: Page): Promise<Highlight[]> {
  const response = await page.request.get(listPath);
  expect(response.ok()).toBe(true);
  return ((await response.json()) as { items: Highlight[] }).items;
}

/** The flat text between two offsets, as the kit's offset engine built it from the page. */
export function flatText(page: Page, start: number, end: number): Promise<string> {
  return page
    .frameLocator('iframe.reader-frame')
    .locator('.frus-document')
    .evaluate(
      (_, [from, to]) => (window as unknown as { FRUSOffsets: { flatText: string } }).FRUSOffsets.flatText.slice(from, to),
      [start, end],
    );
}

/** Removes every highlight the user has, from a page of the app, with the token a change carries. */
export async function removeAll(page: Page): Promise<void> {
  await page.evaluate(async () => {
    const base = document.baseURI;
    const me = (await (await fetch(new URL('api/v1/me', base))).json()) as { csrfToken: string };
    const all = (await (await fetch(new URL('api/v1/me/highlights', base))).json()) as { items: { id: string }[] };
    for (const highlight of all.items) {
      await fetch(new URL(`api/v1/me/highlights/${highlight.id}`, base), { method: 'DELETE', headers: { 'X-CSRF-Token': me.csrfToken } });
    }
  });
}
