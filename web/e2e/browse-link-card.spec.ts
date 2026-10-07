// S9b's done-when (docs/PLAN.md): Playwright browses to a volume, opens a document, follows a link
// inside it and opens a person card, by keyboard alone, with no axe violations. Against the image,
// with the synthetic export imported and fixtures/tei mounted.
import { axeCheck } from './axe';
import { d1Text, d2Header, d2Text, khrushchev, v06Compilation, v06Title } from './expected';
import { expect, test } from './fixtures';
import { tabTo } from './keyboard';

test('browses to a volume, opens a document, follows a link in it and opens a person card, by keyboard alone', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/\/browse$/);
  const heading = page.getByRole('heading', { level: 1 });

  // The skip link comes first, and leads past the header.
  await page.keyboard.press('Tab');
  const skip = page.getByRole('link', { name: 'Skip to content' });
  await expect(skip).toBeFocused();
  await expect(skip).toBeInViewport();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('main')).toBeFocused();

  // The catalogue: narrow it to the volume, then open it.
  await tabTo(page, page.getByRole('searchbox', { name: 'Title or volume number' }));
  await page.keyboard.type('Kennedy-Khrushchev');
  const volumes = page.getByRole('list', { name: 'All Volumes' });
  await expect(volumes.getByRole('listitem')).toHaveCount(1);
  await expect(page.getByRole('status').filter({ hasText: 'Showing' })).toHaveText('Showing 1 of 553 volumes');
  await axeCheck(page);
  await tabTo(page, volumes.getByRole('link', { name: v06Title }));
  await page.keyboard.press('Enter');

  // The volume: its sections, from its TEI, counted against the index.
  await expect(page).toHaveURL(/\/browse\/frus1961-63v06$/);
  await expect(heading).toHaveText(v06Title);
  await expect(heading).toBeFocused();
  await expect(page.getByText('2 of 120 documents indexed on this server').first()).toBeVisible();
  await axeCheck(page);
  await tabTo(page, page.getByRole('link', { name: v06Compilation }));
  await page.keyboard.press('Enter');

  // The section: its documents in order, the index's two named by it.
  await expect(page).toHaveURL(/\/browse\/frus1961-63v06\/comp1$/);
  await expect(heading).toHaveText(v06Compilation);
  await expect(heading).toBeFocused();
  await expect(page.getByRole('heading', { name: 'Documents (120)' })).toBeVisible();
  await axeCheck(page);
  await tabTo(page, page.getByRole('link', { name: d2Header }));
  await page.keyboard.press('Enter');

  // The reader: d2, whose footnote names Document 1.
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d2$/);
  await expect(heading).toHaveText(d2Header);
  await expect(heading).toBeFocused();
  const frame = page.frameLocator('iframe.reader-frame');
  await expect(frame.getByText(d2Text)).toBeVisible();
  const reader = await axeCheck(page);
  // The kit's light palette is still under 4.5:1 here; with the dark reader's check in the third
  // test, each of axe.ts's known ids is shown to be still needed. When a pin move fixes one, both
  // the id and its check go.
  expect([...reader.frameViolations]).toEqual(['color-contrast']);

  // Follow the link: Enter on it in the frame, and the reader goes forward to d1.
  await tabTo(page, frame.getByRole('link', { name: 'Document 1' }));
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d1$/);
  await expect(heading).toHaveText('1. Telegram From the Embassy in the Soviet Union');
  await expect(heading).toBeFocused();
  await expect(frame.getByText(d1Text)).toBeVisible();

  // Open the person card from d1's heading.
  const link = frame.locator('a[href="frusexplorer://person/p_KNS2"]');
  await tabTo(page, link);
  await page.keyboard.press('Enter');
  const card = page.getByRole('dialog', { name: khrushchev.name });
  await expect(card).toBeVisible();
  await expect(card).toContainText(khrushchev.description);
  await expect(card.getByRole('heading', { name: khrushchev.name })).toBeFocused();
  await axeCheck(page);

  // Escape closes it, and focus is back on the link it came from.
  await page.keyboard.press('Escape');
  await expect(card).toHaveCount(0);
  await expect(link).toBeFocused();

  // Back returns to d2, the document the link was in, with its own text; the next Back leaves the
  // reader, since following a link added one entry to the history and the frame none.
  await page.goBack();
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d2$/);
  await expect(heading).toHaveText(d2Header);
  await expect(frame.getByText(d2Text)).toBeVisible();
  await page.goBack();
  await expect(page).toHaveURL(/\/browse\/frus1961-63v06\/comp1$/);
});

test('a note in another document lands in its list of footnotes, and a volume not on the server says so', async ({ page }) => {
  await page.goto('/doc/frus1961-63v06/d21');
  const frame = page.frameLocator('iframe.reader-frame');
  await frame.getByRole('link', { name: /footnote 2, Document/ }).click();
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d16\?note=fnote-x-d16fn2$/);
  await expect(page.locator('iframe.reader-frame')).toHaveAttribute('src', /#fnote-x-d16fn2$/);
  // The note is in view and has focus, so the next Tab continues from it.
  await expect(frame.locator('#fnote-x-d16fn2')).toBeInViewport();
  await expect(frame.locator('#fnote-x-d16fn2')).toBeFocused();

  await page.goto('/doc/frus1961-63v06/d7');
  await page.frameLocator('iframe.reader-frame').getByRole('link', { name: 'Document 28' }).click();
  const notice = page.getByRole('status').filter({ hasText: 'isn’t on this server' });
  await expect(notice).toContainText('Volume V');
  await expect(notice.getByRole('link', { name: 'Open on history.state.gov' })).toHaveAttribute(
    'href',
    'https://history.state.gov/historicaldocuments/frus1961-63v05/d28',
  );
  await expect(page).toHaveURL(/\/doc\/frus1961-63v06\/d7$/);
});

test('the app’s own markup passes axe on Search, the reader, Cite, its narrow sheet and a card, and on Browse and the reader in dark', async ({ page }) => {
  await page.goto('/search?keywords=treaties');
  await expect(page.getByRole('list', { name: 'Results' }).getByRole('listitem')).toHaveCount(2);
  await axeCheck(page);

  await page.goto('/doc/frus1961-63v06/d1?rail=cite');
  await expect(page.getByRole('complementary', { name: 'Cite' }).locator('.citation')).toBeVisible();
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  await axeCheck(page);

  // Below 900 px the rail is a sheet over the toolbar and the text, which are set aside while it is open.
  await page.setViewportSize({ width: 800, height: 900 });
  await expect(page.locator('.reader-body')).toHaveAttribute('inert', '');
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('complementary', { name: 'Cite' })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Cite' })).toBeFocused();
  await expect(page.locator('.reader-body')).not.toHaveAttribute('inert', '');

  await page.setViewportSize({ width: 1280, height: 900 });
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('/doc/frus1961-63v06/d1');
  await expect(page.locator('iframe.reader-frame')).toHaveAttribute('src', /colorScheme=dark/);
  await expect(page.frameLocator('iframe.reader-frame').getByText(d1Text)).toBeVisible();
  // In dark the kit's links pass 4.5:1 but differ from the text around them by colour alone.
  const dark = await axeCheck(page);
  expect([...dark.frameViolations]).toEqual(['link-in-text-block']);
  const card = page.getByRole('dialog', { name: khrushchev.name });
  await page.frameLocator('iframe.reader-frame').locator('a[href="frusexplorer://person/p_KNS2"]').click();
  await expect(card).toBeVisible();
  await axeCheck(page);
  await card.getByRole('button', { name: 'Done' }).click();
  for (const screen of ['/browse', '/browse/frus1961-63v06', '/browse/frus1961-63v06/comp1']) {
    await page.goto(screen);
    await expect(page.getByRole('heading', { level: 1 })).not.toHaveAttribute('data-loading', 'true');
    await expect(page.getByRole('status').or(page.getByRole('heading', { level: 2 })).first()).toBeVisible();
    await axeCheck(page);
  }
});
