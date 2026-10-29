// S19b's done-when (docs/PLAN.md, S11c's): Playwright uses the Research page on Chromium, by keyboard and
// pointer, with no axe violations: the categories with the counts the server gives; All Research
// Documents, a tag's, a collection's and a colour's lists and Contains Notes, each row as the app's and
// opening its document; All Notes and History from their rows, and back; Changed by an update's line;
// and a narrow window's stack, the categories, then a list, and the way back. Against the image's store,
// which the specs before this one leave holding the import's research, so the test makes a tag, a note,
// a highlight and a collection of its own, and deletes them after.
import type { Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';
import { getJSON, send } from './notes';

const volume = 'frus1961-63v06';
const d1Header = '1. Telegram From the Embassy in the Soviet Union';
const d2Header = '2. Memorandum of Conversation';
const documentPath = (document: string) => `api/v1/me/volumes/${volume}/documents/${document}`;

interface Made {
  tag: string;
  note: string;
  highlight: { id: string; selectedText: string };
  collection: string;
}

/** The test's own research: d2 tagged and collected, and d1 with a note and a green highlight. */
async function made(page: Page): Promise<Made> {
  const tag = (await send(page, 'POST', 'api/v1/me/tags', { name: 'Research page tag' })) as { id: string };
  await send(page, 'PUT', `${documentPath('d2')}/tags`, { tagIds: [tag.id] });
  const note = (await send(page, 'POST', `${documentPath('d1')}/notes`, {
    bodyText: 'Research page note.',
    runs: null,
    userTagIds: [],
    projectIds: [],
    selectedSummaryIds: [],
  })) as { id: string };
  const html = await page.request.get(`api/v1/volumes/${volume}/documents/d1/html`);
  const highlight = (await send(page, 'POST', `${documentPath('d1')}/highlights`, {
    startOffset: 0,
    endOffset: 40,
    colorTag: 'green',
    renderingVersion: html.headers()['x-frus-rendering-version'],
  })) as { id: string; selectedText: string };
  const collection = (await send(page, 'POST', 'api/v1/me/collections', { name: 'Research page collection' })) as { id: string };
  await send(page, 'POST', `api/v1/me/collections/${collection.id}/documents`, { documents: [{ volumeId: volume, documentId: 'd2' }] });
  return { tag: tag.id, note: note.id, highlight, collection: collection.id };
}

async function remove(page: Page, research: Made): Promise<void> {
  await send(page, 'DELETE', `api/v1/me/collections/${research.collection}`);
  await send(page, 'DELETE', `api/v1/me/highlights/${research.highlight.id}`);
  await send(page, 'DELETE', `api/v1/me/notes/${research.note}`);
  await send(page, 'DELETE', `api/v1/me/tags/${research.tag}`);
}

interface Counts {
  allAnnotated: number;
  hasNotes: number;
  notes: number;
}

test('lists the annotated documents by category, by keyboard and pointer, each row opening its document', async ({ page }) => {
  await page.goto('browse');
  const research = await made(page);
  try {
    // The header's Research, whose link keeps focus as the header's links do: the categories counted
    // as the server counts them.
    await page.getByRole('navigation', { name: 'Main' }).getByRole('link', { name: 'Research' }).click();
    await expect(page).toHaveURL(/\/research$/);
    await expect(page.getByRole('heading', { level: 1, name: 'Research' })).toBeVisible();
    const categories = page.getByRole('navigation', { name: 'Categories' });
    const counts = await getJSON<Counts>(page, 'api/v1/me/research');
    const grouped = (count: number) => count.toLocaleString('en-US');
    await expect(categories.getByRole('link', { name: /^All Research Documents/ })).toHaveText(
      `All Research Documents, ${grouped(counts.allAnnotated)}`,
    );
    await expect(categories.getByRole('link', { name: /^Contains Notes/ })).toHaveText(`Contains Notes, ${grouped(counts.hasNotes)}`);
    await expect(categories.getByRole('link', { name: /^All Notes/ })).toHaveText(`All Notes, ${grouped(counts.notes)}`);
    await expect(categories.getByRole('link', { name: 'Research page tag' })).toHaveText('Research page tag, 1');
    await expect(categories.getByRole('link', { name: 'Research page collection' })).toHaveText('Research page collection, 1');
    // Changed by an update says why it lists nothing here, and is no link.
    await expect(categories.getByText(/^Documents an update changed after you annotated them wait for a review/)).toBeVisible();
    await expect(categories.getByRole('link', { name: /Changed by an update/ })).toHaveCount(0);

    // All Research Documents, shown until another is chosen: d1's row, the note and the highlight just made.
    const all = page.getByRole('region', { name: 'All Research Documents' });
    await expect(categories.getByRole('link', { name: /^All Research Documents/ })).toHaveAttribute('aria-current', 'page');
    const d1 = all.getByRole('listitem').filter({ has: page.getByRole('link', { name: d1Header, exact: true }) });
    await expect(d1.locator('.research-note')).toHaveText('Research page note.');
    await expect(d1.locator('.research-highlight').first()).toHaveText(`Green highlight: ${research.highlight.selectedText}`);
    await expect(all.getByRole('link', { name: d2Header, exact: true })).toBeVisible();
    await axeCheck(page);

    // The tag's list, by keyboard: its title takes focus, and the address names it.
    await tabTo(page, categories.getByRole('link', { name: 'Research page tag' }));
    await page.keyboard.press('Enter');
    const tagged = page.getByRole('region', { name: 'Research page tag' });
    await expect(tagged.getByRole('heading', { level: 2, name: 'Research page tag' })).toBeFocused();
    await expect(page).toHaveURL(new RegExp(`/research\\?group=tag\\.${research.tag}$`, 'i'));
    await expect(tagged.locator('li.research-document')).toHaveCount(1);
    const d2 = tagged.locator('li.research-document').first();
    await expect(d2.getByRole('link', { name: d2Header, exact: true })).toBeVisible();
    await expect(d2.locator('.research-footer')).toContainText('Tag: Research page tag');
    await expect(d2.locator('.research-footer')).toContainText('Collection: Research page collection');
    await axeCheck(page);

    // Its row opens the document, by keyboard, and Back returns to the list.
    await tabTo(page, d2.getByRole('link', { name: d2Header, exact: true }));
    await page.keyboard.press('Enter');
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(d2Header);
    await page.goBack();
    await expect(tagged.getByRole('heading', { level: 2, name: 'Research page tag' })).toBeVisible();

    // The collection's and the colour's lists, and Contains Notes, by pointer.
    await categories.getByRole('link', { name: 'Research page collection' }).click();
    const collected = page.getByRole('region', { name: 'Research page collection' });
    await expect(collected.getByRole('heading', { level: 2 })).toBeFocused();
    await expect(collected.locator('li.research-document')).toHaveCount(1);
    await expect(collected.getByRole('link', { name: d2Header, exact: true })).toBeVisible();
    await categories.getByRole('link', { name: /^Green/ }).click();
    const green = page.getByRole('region', { name: 'Green Highlights' });
    await expect(green.getByRole('heading', { level: 2 })).toBeFocused();
    await expect(green.getByRole('link', { name: d1Header, exact: true })).toBeVisible();
    await categories.getByRole('link', { name: /^Contains Notes/ }).click();
    const noted = page.getByRole('region', { name: 'Contains Notes' });
    await expect(noted.getByRole('heading', { level: 2 })).toBeFocused();
    await expect(noted.getByRole('link', { name: d1Header, exact: true })).toBeVisible();
    await axeCheck(page);
    await noted.getByRole('link', { name: d1Header, exact: true }).click();
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(d1Header);

    // All Notes and History from their rows, and the page again from Research's screens.
    await page.goto('research');
    await page.getByRole('navigation', { name: 'Categories' }).getByRole('link', { name: /^All Notes/ }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'All Notes' })).toBeFocused();
    const screens = page.getByRole('navigation', { name: 'Research', exact: true });
    await screens.getByRole('link', { name: 'History', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'History' })).toBeFocused();
    await backTabTo(page, screens.getByRole('link', { name: 'Research', exact: true }));
    await page.keyboard.press('Enter');
    await expect(page.getByRole('heading', { level: 1, name: 'Research' })).toBeFocused();
    await expect(page).toHaveURL(/\/research$/);
  } finally {
    await remove(page, research);
  }
});

test('stacks the categories and a list in a narrow window, with the way back', async ({ page }) => {
  await page.setViewportSize({ width: 600, height: 900 });
  await page.goto('research');
  const research = await made(page);
  try {
    await page.reload();
    const categories = page.getByRole('navigation', { name: 'Categories' });
    await expect(categories.getByRole('link', { name: 'Research page tag' })).toBeVisible();
    // The categories alone, as the iPhone's root, none chosen until one is.
    await expect(page.locator('section.research-list')).toHaveCount(1);
    await expect(page.locator('section.research-list')).toBeHidden();
    await expect(categories.getByRole('link', { name: /^All Research Documents/ })).not.toHaveAttribute('aria-current', 'page');
    await axeCheck(page);

    await tabTo(page, categories.getByRole('link', { name: 'Research page tag' }));
    await page.keyboard.press('Enter');
    const tagged = page.getByRole('region', { name: 'Research page tag' });
    await expect(tagged.getByRole('heading', { level: 2 })).toBeFocused();
    await expect(page.locator('nav.research-categories')).toHaveCount(1);
    await expect(categories).toBeHidden();
    await expect(tagged.getByRole('link', { name: d2Header, exact: true })).toBeVisible();
    await expect(tagged.getByRole('link', { name: 'Categories', exact: true })).not.toHaveAttribute('aria-current', 'page');
    await axeCheck(page);

    // The way back, to the category left.
    await backTabTo(page, tagged.getByRole('link', { name: 'Categories', exact: true }));
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/\/research$/);
    await expect(categories.getByRole('link', { name: 'Research page tag' })).toBeFocused();
    await expect(categories.getByRole('link', { name: 'Research page tag' })).toBeInViewport();

    // Back from a list in the browser shows the categories again, focus on the category it left.
    await categories.getByRole('link', { name: 'Research page collection' }).click();
    await expect(page.getByRole('region', { name: 'Research page collection' }).getByRole('heading', { level: 2 })).toBeFocused();
    await page.goBack();
    await expect(categories).toBeVisible();
    await expect(categories.getByRole('link', { name: 'Research page collection' })).toBeFocused();
  } finally {
    await remove(page, research);
  }
});
