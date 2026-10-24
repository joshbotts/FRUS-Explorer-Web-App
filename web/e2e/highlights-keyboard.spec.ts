// S15c's done-when (docs/PLAN.md), by keyboard: Playwright selects text in the reader's frame with
// caret browsing, as Chromium's F7 turns it on, highlights it with Ctrl+Shift+H, the app's ⇧⌘H for
// Highlight Selection ▸ Yellow, highlights more from the selection bar by Alt+F10 and the arrow keys,
// recolours one in the Research rail's Highlights section, reloads, and removes both with Remove…,
// on Chromium with no axe violations. Against the image, whose user store starts with no highlights,
// and which the test leaves with none.
import { axeCheck } from './axe';
import { d1Text } from './expected';
import { expect, test } from './fixtures';
import { documentPath, drawn, flatText, listed, removeAll } from './highlights';
import { backTabTo, tabTo } from './keyboard';

// Caret browsing, in a worker of its own. Chromium keeps only the last --blink-settings, so the
// switch repeats the hover and pointer settings Playwright's headless launch passes.
test.use({
  launchOptions: {
    args: ['--blink-settings=primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4,caretBrowsingEnabled=true'],
  },
});

test.afterEach(async ({ page }) => {
  await removeAll(page);
});

test('highlights by keyboard alone, recolours, reloads and removes', async ({ page }) => {
  await page.goto(documentPath);
  const frame = page.frameLocator('iframe.reader-frame');
  await expect(frame.getByText(d1Text)).toBeVisible();
  expect(await listed(page)).toEqual([]);
  const selection = () => frame.locator('body').evaluate(() => getSelection()?.toString() ?? '');

  // Into the text by Tab, to Kennedy's name in the first paragraph, then a caret and a selection of
  // three words.
  await tabTo(page, frame.locator('p.body').getByRole('link', { name: 'Kennedy' }));
  await page.keyboard.press('ArrowRight');
  for (let word = 0; word < 3; word++) await page.keyboard.press('Control+Shift+ArrowRight');
  await expect.poll(selection).not.toBe('');
  const first = await selection();

  // Ctrl+Shift+H: yellow at once, as the app's ⇧⌘H.
  await page.keyboard.press('Control+Shift+H');
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1 });
  const [yellow] = await listed(page);
  expect(yellow.selectedText).toBe(first);
  expect(await flatText(page, yellow.startOffset, yellow.endOffset)).toBe(first);
  // The selection went with it, and a second press makes nothing.
  await expect.poll(selection).toBe('');
  await page.keyboard.press('Control+Shift+H');
  await page.waitForTimeout(300);
  expect(await listed(page)).toHaveLength(1);

  // More words, then Alt+F10 to the bar, on Yellow; the arrows to Blue, and Return.
  for (let word = 0; word < 2; word++) await page.keyboard.press('Control+Shift+ArrowRight');
  await expect.poll(selection).not.toBe('');
  await page.keyboard.press('Alt+F10');
  const bar = page.getByRole('toolbar', { name: 'Selection' });
  await expect(bar.getByRole('button', { name: 'Highlight Yellow' })).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowRight');
  await expect(bar.getByRole('button', { name: 'Highlight Blue' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1, 'frus-blue': 1 });
  await expect(bar).toBeHidden();

  // The Research rail's Highlights section, from the toolbar: the blue one recoloured to Pink.
  const toggle = page.getByRole('button', { name: 'Research' });
  await backTabTo(page, toggle);
  await page.keyboard.press('Enter');
  const rail = page.getByRole('complementary', { name: 'Research' });
  await expect(rail.getByRole('heading', { name: 'Research' })).toBeFocused();
  const section = rail.getByRole('button', { name: /^Highlights/ });
  await tabTo(page, section);
  await page.keyboard.press('Enter');
  await expect(section).toHaveAttribute('aria-expanded', 'true');
  // The Highlights section's rows: the Notes section above it has rows of its own.
  const rows = rail.locator('#research-highlights').getByRole('listitem');
  await expect(rows).toHaveCount(2);
  const blue = (await listed(page)).find((highlight) => highlight.colorTag === 'blue')!;
  const blueRow = rows.filter({ hasText: blue.selectedText.trim() });
  await tabTo(page, blueRow.getByRole('button', { name: 'Pink', exact: true }));
  await page.keyboard.press('Enter');
  await expect(blueRow.getByRole('button', { name: 'Pink', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1, 'frus-pink': 1 });
  await axeCheck(page);

  // A reload keeps both, and the rail as it was left.
  await page.reload();
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  await expect.poll(() => drawn(page)).toEqual({ 'frus-yellow': 1, 'frus-pink': 1 });
  await expect(rows).toHaveCount(2);

  // Remove… asks, Cancel first; Remove removes, and focus goes on to the next row's Remove….
  const removes = rail.getByRole('button', { name: 'Remove…' });
  await tabTo(page, removes.first());
  await page.keyboard.press('Enter');
  const question = page.getByRole('alertdialog', { name: 'Remove Highlight' });
  await expect(question.getByRole('button', { name: 'Cancel' })).toBeFocused();
  await axeCheck(page);
  // Escape is the question's Cancel, and leaves the rail open.
  await page.keyboard.press('Escape');
  await expect(question).toBeHidden();
  await expect(rail).toBeVisible();
  await expect(removes.first()).toBeFocused();
  await page.keyboard.press('Enter');
  await page.keyboard.press('Tab');
  await expect(question.getByRole('button', { name: 'Remove', exact: true })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(rows).toHaveCount(1);
  await expect(removes.first()).toBeFocused();
  await page.keyboard.press('Enter');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(rows).toHaveCount(0);
  await expect(section).toBeFocused();
  await expect.poll(() => drawn(page)).toEqual({});
  expect(await listed(page)).toEqual([]);
});
