// S15c's done-when (docs/PLAN.md), by pointer: Playwright highlights a phrase from the selection bar,
// recolours it in the Research rail's Highlights section, reloads, and removes it with a tap on it and
// the app's Remove Highlight question, on Chromium with no axe violations. By keyboard, it is
// highlights-keyboard.spec.ts. Against the image, whose user store starts with no highlights, and
// which each test leaves with none.
import { axeCheck } from './axe';
import { d1Text, khrushchev } from './expected';
import { expect, test } from './fixtures';
import { documentPath, dragOver, drawn, flatText, listed, phraseBox, removeAll } from './highlights';

const phrase = 'no insurmountable obstacles';

test.afterEach(async ({ page }) => {
  await removeAll(page);
});

test('highlights a phrase, recolours it, reloads and removes it, by pointer', async ({ page }) => {
  await page.goto(documentPath);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  expect(await listed(page)).toEqual([]);

  // The bar comes with a selection in the text: the four colours, then Excerpt and Note, in the app's order.
  await dragOver(page, phrase);
  const bar = page.getByRole('toolbar', { name: 'Selection' });
  await expect(bar).toBeVisible();
  await expect(bar.getByRole('button')).toHaveCount(6);
  for (const [index, name] of ['Highlight Yellow', 'Highlight Green', 'Highlight Blue', 'Highlight Pink', 'Excerpt', 'Note'].entries()) {
    await expect(bar.getByRole('button').nth(index)).toHaveAccessibleName(name);
  }
  // It sits over the frame, as the Mac's sits over its web view.
  const frameBox = (await page.locator('iframe.reader-frame').boundingBox())!;
  const barBox = (await bar.boundingBox())!;
  expect(barBox.y).toBeGreaterThanOrEqual(frameBox.y);
  expect(barBox.y + barBox.height).toBeLessThanOrEqual(frameBox.y + frameBox.height);
  await axeCheck(page);

  await bar.getByRole('button', { name: 'Highlight Yellow' }).click();
  await expect(bar).toBeHidden();
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1 });
  const [made] = await listed(page);
  expect(made.colorTag).toBe('yellow');
  expect(made.selectedText).toBe(phrase);
  expect(await flatText(page, made.startOffset, made.endOffset)).toBe(phrase);
  expect(made.isStale).toBe(false);

  // Another colour, in the Research rail's Highlights section, keeps the highlight.
  await page.getByRole('button', { name: 'Research' }).click();
  const rail = page.getByRole('complementary', { name: 'Research' });
  await rail.getByRole('button', { name: 'Highlights' }).click();
  const row = rail.locator('#research-highlights').getByRole('listitem').filter({ hasText: phrase });
  await expect(row.getByRole('button', { name: 'Yellow', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await row.getByRole('button', { name: 'Green', exact: true }).click();
  await expect(row.getByRole('button', { name: 'Green', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await expect.poll(() => drawn(page)).toEqual({ 'frus-green': 1 });
  expect((await listed(page)).map(({ id, colorTag }) => ({ id, colorTag }))).toEqual([{ id: made.id, colorTag: 'green' }]);
  await axeCheck(page);

  // A reload draws it again.
  await page.reload();
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  await expect.poll(() => drawn(page)).toEqual({ 'frus-green': 1 });

  // A tap on it asks, as the app's does, and Remove removes it.
  const { start, end } = await phraseBox(page, phrase);
  await page.mouse.click((start.x + end.x) / 2, start.y);
  const question = page.getByRole('alertdialog', { name: 'Remove Highlight' });
  await expect(question).toBeVisible();
  await expect(question).toContainText('This highlight will be permanently removed.');
  await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  await question.getByRole('button', { name: 'Remove', exact: true }).click();
  await expect(question).toBeHidden();
  await expect.poll(() => drawn(page)).toEqual({});
  expect(await listed(page)).toEqual([]);
});

test('a selection in a footnote offers no colour, and a link inside a highlight is followed, not removed', async ({ page }) => {
  await page.goto(documentPath);
  const frame = page.frameLocator('iframe.reader-frame');
  await expect(frame.getByText(d1Text)).toBeVisible();

  // In the list of footnotes, the kit's bridge has no offsets: none of the colours applies, so the
  // bar offers Note alone (notes.spec.ts follows it).
  await frame.locator('.footnotes-section').scrollIntoViewIfNeeded();
  await dragOver(page, 'American Foreign Policy', { within: '.footnotes-section' });
  await expect.poll(() => frame.locator('body').evaluate(() => getSelection()?.toString() ?? '')).toBe('American Foreign Policy');
  const footnoteBar = page.getByRole('toolbar', { name: 'Selection' });
  await expect(footnoteBar).toBeVisible();
  await expect(footnoteBar.getByRole('button')).toHaveCount(1);
  await expect(footnoteBar.getByRole('button')).toHaveAccessibleName('Note');

  // Khrushchev's name in the heading is a reader link, to his card. Highlighted, from the words
  // after it back to its first letter, so the press is not on the link, a click on it opens the card,
  // and does not ask to remove the highlight.
  await frame.locator('.frus-document h2').scrollIntoViewIfNeeded();
  const after = await phraseBox(page, 'to President-elect', '.frus-document h2');
  const name = await phraseBox(page, 'Khrushchev', '.frus-document h2');
  await page.mouse.move(after.start.x, after.start.y);
  await page.mouse.down();
  await page.mouse.move(name.start.x, name.start.y, { steps: 10 });
  await page.mouse.up();
  const bar = page.getByRole('toolbar', { name: 'Selection' });
  await expect(bar).toBeVisible();
  await bar.getByRole('button', { name: 'Highlight Pink' }).click();
  await expect.poll(() => drawn(page)).toEqual({ 'frus-pink': 1 });
  expect((await listed(page))[0].selectedText).toMatch(/^Khrushchev ?$/);
  await frame.locator('a[href="frusexplorer://person/p_KNS2"]').click();
  await expect(page.getByRole('dialog', { name: khrushchev.name })).toBeVisible();
  await expect(page.getByRole('alertdialog', { name: 'Remove Highlight' })).toHaveCount(0);
});
